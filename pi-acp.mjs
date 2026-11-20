import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { createReadStream, unwatchFile, watchFile } from 'node:fs';
import { readFile, stat } from 'node:fs/promises';
import { homedir } from 'node:os';
import { join, resolve } from 'node:path';
import { createInterface } from 'node:readline';
import { pathToFileURL } from 'node:url';
import { bashTranscript } from './bash-transcript.mjs';

function removeProvider(option, id) {
  const slash = typeof id === 'string' ? id.indexOf('/') : -1;
  if (slash > 0 && option.name?.startsWith(id.slice(0, slash + 1))) {
    option.name = option.name.slice(slash + 1);
  }
}

// Tern 0.9.28 opens a picker for ACP's mode category, but cycles thought_level on click.
export function adaptForTern(frame) {
  const payload = frame.result ?? frame.params?.update;
  if (!payload) return frame;
  for (const model of payload.models?.availableModels ?? []) removeProvider(model, model.modelId);
  for (const config of payload.configOptions ?? []) {
    if (config.type !== 'select') continue;
    for (const option of config.options ?? []) {
      if (config.category === 'model') {
        for (const item of option.options ?? [option]) removeProvider(item, item.value);
      }
    }
    if (config.category !== 'thought_level' || config.id !== 'thought_level') continue;
    config.category = 'mode';
    for (const option of config.options ?? []) option.name = option.name.replace(/^Thinking:\s*/, '');
    delete payload.modes;
  }
  return frame;
}

function parse(line) {
  try { return JSON.parse(line); } catch { return undefined; }
}

async function readSavedBashCommands(sessionMap, sessionId) {
  const commands = new Map();
  const entry = parse(await readFile(sessionMap, 'utf8'))?.sessions?.[sessionId];
  if (entry?.sessionId !== sessionId || !entry.sessionFile?.endsWith('.jsonl')) return commands;
  const lines = createInterface({ input: createReadStream(entry.sessionFile), crlfDelay: Infinity });
  for await (const line of lines) {
    if (!line.includes('"toolCall"') || !line.includes('"bash"')) continue;
    const message = parse(line)?.message;
    if (message?.role !== 'assistant' || !Array.isArray(message.content)) continue;
    for (const part of message.content) {
      if (part.type === 'toolCall' && part.name === 'bash' && typeof part.arguments?.command === 'string') {
        commands.set(part.id, part.arguments.command);
      }
    }
  }
  return commands;
}

function bridge(adapter, args) {
  const child = spawn(process.execPath, [adapter, ...args], { stdio: ['pipe', 'pipe', 'inherit'], windowsHide: true });
  const requests = new Map();
  const input = createInterface({ input: process.stdin, crlfDelay: Infinity });
  process.stdin.pipe(child.stdin);
  child.stdin.on('error', () => input.close());
  child.on('error', (error) => console.error(`agent-tabs Pi ACP: ${error.message}`));
  child.on('close', (code) => {
    input.close();
    process.stdin.unpipe(child.stdin);
    process.stdin.pause();
    process.exitCode = code ?? 1;
  });
  process.on('exit', () => child.kill());

  let activeSession;
  let titleState;
  let titleRead = Promise.resolve();
  let usesConfigMode = false;
  const sessionMap = join(homedir(), '.pi', 'pi-acp', 'session-map.json');
  let savedCommands;
  const adaptBash = bashTranscript(async (sessionId, toolCallId) => {
    if (![...requests.values()].some((r) => r.method === 'session/load' && r.sessionId === sessionId)) return;
    savedCommands ??= readSavedBashCommands(sessionMap, sessionId).catch(() => new Map());
    return (await savedCommands).get(toolCallId);
  });

  function queueTitle(sessionId, reopening = false) {
    titleRead = titleRead.then(() => {
      if (reopening && titleState) {
        unwatchFile(titleState.file);
        titleState = undefined;
      }
      return publishTitle(sessionId);
    }).catch(() => {});
  }

  // Pi's JSONL is append-only. Watch it for names generated asynchronously by extensions.
  async function publishTitle(sessionId) {
    if (sessionId !== activeSession) return;
    if (titleState?.sessionId !== sessionId) {
      const entry = parse(await readFile(sessionMap, 'utf8'))?.sessions?.[sessionId];
      if (entry?.sessionId !== sessionId || !entry.sessionFile?.endsWith('.jsonl')) return;
      titleState = { sessionId, file: entry.sessionFile, offset: 0 };
      watchFile(entry.sessionFile, { interval: 1500, persistent: false }, (current, previous) => {
        if (current.size !== previous.size) queueTitle(sessionId);
      });
    }
    const state = titleState;
    const { size } = await stat(state.file);
    if (size < state.offset) state.offset = 0;
    if (size === state.offset) return;
    let title;
    const lines = createInterface({
      input: createReadStream(state.file, { start: state.offset, end: size - 1 }), crlfDelay: Infinity,
    });
    for await (const line of lines) {
      if (!line.includes('"session_info"')) continue;
      const entry = parse(line);
      if (entry?.type === 'session_info' && typeof entry.name === 'string' && entry.name.trim()) title = entry.name.trim();
    }
    state.offset = size;
    if (sessionId !== activeSession || !title || title === state.sent) return;
    state.sent = title;
    process.stdout.write(JSON.stringify({
      jsonrpc: '2.0', method: 'session/update', params: { sessionId, update: { sessionUpdate: 'session_info_update', title } },
    }) + '\n');
  }

  input.on('line', (line) => {
    const request = parse(line);
    if (request?.id != null && ['session/new', 'session/load', 'session/prompt'].includes(request.method)) {
      requests.set(request.id, { method: request.method, sessionId: request.params?.sessionId });
    }
  });

  const output = createInterface({ input: child.stdout, crlfDelay: Infinity });
  void (async () => {
    for await (const line of output) {
      const frame = parse(line);
      const rawOptions = frame?.result?.configOptions ?? frame?.params?.update?.configOptions;
      if (Array.isArray(rawOptions)) usesConfigMode = rawOptions.some((o) => o.category === 'thought_level' && o.id === 'thought_level');
      if (usesConfigMode && frame?.method === 'session/update' && frame.params?.update?.sessionUpdate === 'current_mode_update') continue;
      // Tern can consume the session_info_update only after the new/load response.
      const adjusted = Array.isArray(rawOptions) || frame?.result?.models;
      if (adjusted) adaptForTern(frame);
      const update = frame?.params?.update;
      const bashAdjusted = update?.toolCallId && await adaptBash(frame.params.sessionId, update);
      if (!process.stdout.write((adjusted || bashAdjusted ? JSON.stringify(frame) : line) + '\n')) await once(process.stdout, 'drain');
      const request = requests.get(frame?.id);
      if (!request || frame.method) continue;
      requests.delete(frame.id);
      if (request.method === 'session/load') savedCommands = undefined;
      const sessionId = frame.result?.sessionId ?? request.sessionId;
      if (!frame.result || typeof sessionId !== 'string') continue;
      const reopening = request.method !== 'session/prompt';
      if (reopening) activeSession = sessionId;
      // A new session can have no JSONL yet. The watcher and next prompt will retry.
      queueTitle(sessionId, reopening);
    }
  })().catch((error) => {
    console.error(`agent-tabs Pi ACP: ${error.message}`);
    child.kill();
  });
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const [, , adapter, ...args] = process.argv;
  if (!adapter) throw new Error('Usage: node pi-acp.mjs /path/to/pi-acp/dist/index.js');
  bridge(adapter, args);
}
