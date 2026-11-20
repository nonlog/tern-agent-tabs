import { stripVTControlCharacters } from 'node:util';

const OUTPUT_LIMIT = 256 * 1024;

function consoleText(text) {
  return stripVTControlCharacters(text).replace(/\r\n?/g, '\n');
}

// pi-acp sends Bash output as terminal metadata. Tern needs ACP content for a collapsible body.
export function bashTranscript(findSavedCommand = async () => undefined) {
  const calls = new Map();
  return async function apply(sessionId, update) {
    if (!update?.toolCallId) return false;
    const key = `${sessionId}:${update.toolCallId}`;
    let call = calls.get(key);
    if (update.sessionUpdate === 'tool_call' && update.kind === 'execute' && update._meta?.terminal_info) {
      call = { command: undefined, output: '', truncated: false };
      calls.set(key, call);
    }
    if (!call) return false;
    if (update.kind === 'execute') update.kind = 'other'; // Tern routes execute cards to its terminal-only renderer.
    const command = update.title;
    if (typeof command === 'string' && command.trim() && !/^bash$/i.test(command)) call.command = command;
    if (command) update.title = 'Bash';
    const { terminal_info, terminal_output, terminal_exit, ...metadata } = update._meta ?? {};
    if (terminal_info || terminal_output || terminal_exit) {
      if (Object.keys(metadata).length) update._meta = metadata;
      else delete update._meta;
    }
    if (typeof terminal_output?.data === 'string') {
      const remaining = OUTPUT_LIMIT - call.output.length;
      call.output += terminal_output.data.slice(0, remaining);
      call.truncated ||= terminal_output.data.length > remaining;
    }
    if (!call.command && (update.status === 'completed' || update.status === 'failed')) {
      call.command = await findSavedCommand(sessionId, update.toolCallId);
    }
    const parts = [];
    if (call.command) parts.push(`Command:\n${consoleText(call.command)}`);
    else if (terminal_exit) parts.push('Command was not recorded.');
    if (call.output) parts.push(`Output:\n${consoleText(call.output)}${call.truncated ? '\n(Additional output omitted.)' : ''}`);
    if (typeof terminal_exit?.exit_code === 'number') parts.push(`Exit code: ${terminal_exit.exit_code}`);
    if (parts.length) {
      update.content = [{ type: 'content', content: { type: 'text', text: parts.join('\n\n') } }];
    } else if (terminal_info) update.content = [];
    if (terminal_exit) calls.delete(key);
    return true;
  };
}
