// Groups consecutive ACP tool calls between assistant messages into a single
// Codex-style collapsible step summary (present tense while running, past tense
// once finished, expandable to inspect every command/tool in the phase).

const MAX_INLINE_CMD = 84;
const MAX_STEP_OUTPUT = 1200;
const MAX_TOTAL_BODY = 24 * 1024;

function oneLine(text, maxLen = MAX_INLINE_CMD) {
  if (typeof text !== 'string') return '';
  const clean = text.replace(/\s+/g, ' ').trim();
  if (clean.length <= maxLen) return clean;
  return clean.slice(0, maxLen - 1) + '…';
}

function extractText(content) {
  if (!Array.isArray(content)) return '';
  const chunks = [];
  for (const item of content) {
    if (item?.type === 'content' && item.content?.type === 'text' && typeof item.content.text === 'string') {
      chunks.push(item.content.text);
    } else if (item?.type === 'text' && typeof item.text === 'string') {
      chunks.push(item.text);
    }
  }
  return chunks.join('\n').trim();
}

function extractBashCommandFromContent(text) {
  if (!text) return '';
  const m = text.match(/^Command:\n([^\n]+)/);
  return m ? m[1].trim() : '';
}

function extractTargetFromRawInput(rawInput) {
  if (!rawInput || typeof rawInput !== 'object') return '';
  for (const key of ['command', 'cmd', 'path', 'file_path', 'filePath', 'pattern', 'query', 'url', 'target']) {
    if (typeof rawInput[key] === 'string' && rawInput[key].trim()) {
      return rawInput[key].trim();
    }
  }
  return '';
}

function shortPath(p) {
  if (!p) return '';
  const parts = p.replace(/\\/g, '/').split('/').filter(Boolean);
  return parts.length ? parts[parts.length - 1] : p;
}

function classifyTool(step) {
  const name = (step.name || '').trim();
  const lower = name.toLowerCase();
  const kind = (step.kind || '').toLowerCase();

  if (lower === 'bash' || lower === 'shell' || lower === 'exec' || lower === 'terminal' || kind === 'execute' || step.isBash) {
    return { cat: 'command', label: 'command', plural: 'commands' };
  }
  if (
    lower === 'read' || lower === 'cat' || lower === 'view' || lower === 'ls' || lower === 'list' ||
    lower === 'find' || lower === 'grep' || lower === 'glob' || lower.includes('search') ||
    kind === 'read' || kind === 'search'
  ) {
    return { cat: 'check', label: lower.includes('search') || lower === 'grep' ? 'search' : 'file', plural: 'files' };
  }
  if (lower === 'edit' || lower === 'write' || lower === 'patch' || lower === 'multiedit' || kind === 'edit') {
    return { cat: 'edit', label: 'file', plural: 'files' };
  }
  return { cat: 'tool', label: name || 'tool', plural: name || 'tools' };
}

function stepDetail(step) {
  if (step.command) return oneLine(step.command);
  if (step.target) {
    const cls = classifyTool(step);
    return cls.cat === 'check' || cls.cat === 'edit' ? shortPath(step.target) : oneLine(step.target);
  }
  return '';
}

function presentTitleForStep(step) {
  const cls = classifyTool(step);
  const detail = stepDetail(step);
  if (cls.cat === 'command') return detail ? `Running ${detail}` : 'Running command';
  if (cls.cat === 'check') return detail ? `Checking ${detail}` : `Checking ${step.name || 'files'}`;
  if (cls.cat === 'edit') return detail ? `Editing ${detail}` : `Editing ${step.name || 'files'}`;
  return detail ? `Running ${step.name}: ${detail}` : `Running ${step.name || 'tool'}`;
}

function pastTitleForSingle(step) {
  const cls = classifyTool(step);
  const detail = stepDetail(step);
  const failed = step.status === 'failed';
  if (cls.cat === 'command') {
    if (failed) return detail ? `Command failed (${detail})` : 'Command failed';
    return detail ? `Ran ${detail}` : 'Ran command';
  }
  if (cls.cat === 'check') return detail ? `Checked ${detail}` : `Checked ${step.name || 'files'}`;
  if (cls.cat === 'edit') return detail ? `Edited ${detail}` : `Edited ${step.name || 'files'}`;
  return detail ? `Used ${step.name}: ${detail}` : `Used ${step.name || 'tool'}`;
}

function capitalize(s) {
  return s ? s[0].toUpperCase() + s.slice(1) : s;
}

function buildGroupTitle(group) {
  const steps = group.steps;
  if (!steps.length) return 'Working';

  const running = [...steps].reverse().find((s) => s.status === 'in_progress' || s.status === 'pending');
  if (running) {
    const lead = presentTitleForStep(running);
    return steps.length > 1 ? `${lead} (${steps.length} steps)` : lead;
  }

  if (steps.length === 1) {
    return pastTitleForSingle(steps[0]);
  }

  let cmds = 0;
  let checks = 0;
  let edits = 0;
  let failed = 0;
  const toolCounts = new Map();
  for (const s of steps) {
    if (s.status === 'failed') failed++;
    const cls = classifyTool(s);
    if (cls.cat === 'command') cmds++;
    else if (cls.cat === 'check') checks++;
    else if (cls.cat === 'edit') edits++;
    else {
      const label = s.name || 'tool';
      toolCounts.set(label, (toolCounts.get(label) ?? 0) + 1);
    }
  }

  const phrases = [];
  for (const [name, count] of toolCounts.entries()) {
    phrases.push(count > 1 ? `used ${name} (${count})` : `used ${name}`);
  }
  if (checks > 0) phrases.push(checks === 1 ? 'checked 1 file' : `checked ${checks} files`);
  if (edits > 0) phrases.push(edits === 1 ? 'edited 1 file' : `edited ${edits} files`);
  if (cmds > 0) phrases.push(cmds === 1 ? 'ran 1 command' : `ran ${cmds} commands`);

  let summary = capitalize(phrases.join(', '));
  if (failed > 0) summary += ` · ${failed} failed`;
  return summary;
}

function buildGroupContent(group) {
  const blocks = [];
  let totalLen = 0;
  for (const s of group.steps) {
    const icon = s.status === 'failed' ? '✗' : (s.status === 'completed' ? '✓' : '⏳');
    const detail = stepDetail(s);
    const label = detail ? `${s.name}: ${detail}` : (s.name || 'tool');
    let line = `${icon} ${label}`;
    if (s.output) {
      const trimmed = s.output.length > MAX_STEP_OUTPUT
        ? s.output.slice(0, MAX_STEP_OUTPUT) + '\n…(truncated)'
        : s.output;
      line += '\n' + trimmed.split('\n').map((l) => '  ' + l).join('\n');
    }
    if (totalLen + line.length > MAX_TOTAL_BODY && blocks.length > 0) {
      blocks.push('…(additional steps omitted)');
      break;
    }
    blocks.push(line);
    totalLen += line.length;
  }
  return blocks.length
    ? [{ type: 'content', content: { type: 'text', text: blocks.join('\n\n') } }]
    : [];
}

function isInteractiveTool(update) {
  const id = String(update?.toolCallId ?? '');
  const title = String(update?.title ?? '').toLowerCase();
  return id.startsWith('pi-ui-') || title.includes('ask_user_question');
}

export function toolGroups() {
  let seq = 0;
  const activeBySession = new Map();
  const callToGroup = new Map();

  function closeActive(sessionId) {
    if (sessionId) activeBySession.delete(sessionId);
  }

  return {
    closeSessionGroup(sessionId) {
      closeActive(sessionId);
    },
    resetSession(sessionId) {
      closeActive(sessionId);
      const prefix = `${sessionId}:`;
      for (const key of callToGroup.keys()) {
        if (key.startsWith(prefix)) callToGroup.delete(key);
      }
    },
    apply(sessionId, update) {
      if (!sessionId || !update || typeof update !== 'object') return false;
      const kind = update.sessionUpdate;

      // Any visible assistant or user message ends the current tool batch,
      // so the next batch starts cleanly under that progress message.
      if (kind === 'agent_message_chunk' || kind === 'user_message_chunk') {
        const text = update.content?.type === 'text' ? update.content.text : '';
        if (typeof text === 'string' && text.trim().length > 0) {
          closeActive(sessionId);
        }
        return false;
      }

      if (kind !== 'tool_call' && kind !== 'tool_call_update') return false;
      if (!update.toolCallId || isInteractiveTool(update)) return false;

      const callKey = `${sessionId}:${update.toolCallId}`;
      let group = callToGroup.get(callKey);
      let isNewGroup = false;

      if (!group) {
        group = activeBySession.get(sessionId);
        if (!group) {
          group = {
            id: `grp-${++seq}`,
            steps: [],
            stepById: new Map(),
          };
          activeBySession.set(sessionId, group);
          isNewGroup = true;
        }
        callToGroup.set(callKey, group);
      }

      let step = group.stepById.get(update.toolCallId);
      if (!step) {
        step = {
          id: update.toolCallId,
          name: typeof update.title === 'string' && update.title.trim() ? update.title.trim() : 'tool',
          kind: update.kind || 'other',
          isBash: update.title === 'Bash' || update.kind === 'execute',
          command: '',
          target: '',
          status: update.status || 'in_progress',
          output: '',
        };
        group.stepById.set(update.toolCallId, step);
        group.steps.push(step);
      } else {
        if (typeof update.title === 'string' && update.title.trim()) {
          if (step.name === 'tool' || (step.name === 'Bash' && update.title !== 'Bash')) {
            step.name = update.title.trim();
          }
        }
        if (update.kind && step.kind === 'other') step.kind = update.kind;
        if (update.status) step.status = update.status;
      }

      const rawTarget = extractTargetFromRawInput(update.rawInput);
      if (rawTarget) {
        if (step.isBash) step.command = rawTarget;
        else if (!step.target) step.target = rawTarget;
      }

      const contentText = extractText(update.content);
      if (contentText) {
        const bashCmd = extractBashCommandFromContent(contentText);
        if (bashCmd) {
          step.isBash = true;
          step.command = bashCmd;
        }
        // Keep output excerpt (strip duplicate Command: header if already shown on step line)
        let body = contentText;
        if (bashCmd) {
          body = body.replace(/^Command:\n[^\n]+(?:\n\n)?/, '').trim();
        }
        if (body) step.output = body;
      }

      const anyRunning = group.steps.some((s) => s.status === 'in_progress' || s.status === 'pending');
      const allFailed = !anyRunning && group.steps.every((s) => s.status === 'failed');
      const groupStatus = anyRunning ? 'in_progress' : (allFailed ? 'failed' : 'completed');

      update.sessionUpdate = isNewGroup ? 'tool_call' : 'tool_call_update';
      update.toolCallId = group.id;
      update.kind = 'other';
      update.status = groupStatus;
      update.title = buildGroupTitle(group);
      update.content = buildGroupContent(group);
      delete update.rawInput;
      delete update.rawOutput;
      delete update.locations;
      return true;
    },
  };
}
