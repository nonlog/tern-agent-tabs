// Rewrites each individual ACP tool card title with clear present-tense verbs
// while running ("Running ...", "Checking ...", "Editing ...") and past-tense
// verbs once finished ("Ran ...", "Checked ...", "Edited ...", "Used ..."),
// without merging cards into a single block.

const MAX_DETAIL = 72;

function oneLine(text, maxLen = MAX_DETAIL) {
  if (typeof text !== 'string') return '';
  const clean = text.replace(/\s+/g, ' ').trim();
  if (clean.length <= maxLen) return clean;
  return clean.slice(0, maxLen - 1) + '…';
}

function extractText(content) {
  if (!Array.isArray(content)) return '';
  for (const item of content) {
    if (item?.type === 'content' && item.content?.type === 'text' && typeof item.content.text === 'string') {
      return item.content.text;
    }
    if (item?.type === 'text' && typeof item.text === 'string') {
      return item.text;
    }
  }
  return '';
}

function extractBashCommand(text) {
  if (!text) return '';
  const m = text.match(/^Command:\n([^\n]+)/);
  return m ? m[1].trim() : '';
}

function extractTarget(rawInput) {
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

function classify(rec) {
  const lower = (rec.name || '').toLowerCase();
  const kind = (rec.kind || '').toLowerCase();
  if (rec.isBash || lower === 'bash' || lower === 'shell' || lower === 'exec' || lower === 'terminal' || kind === 'execute') {
    return 'command';
  }
  if (lower === 'grep' || lower === 'glob' || lower.includes('search') || kind === 'search') {
    return 'search';
  }
  if (lower === 'read' || lower === 'cat' || lower === 'view' || lower === 'ls' || lower === 'list' || lower === 'find' || kind === 'read') {
    return 'check';
  }
  if (lower === 'edit' || lower === 'write' || lower === 'patch' || lower === 'multiedit' || kind === 'edit') {
    return 'edit';
  }
  return 'tool';
}

function formatTitle(rec) {
  const cat = classify(rec);
  const running = rec.status === 'in_progress' || rec.status === 'pending';
  const failed = rec.status === 'failed';
  const detail = rec.command
    ? oneLine(rec.command)
    : rec.target
      ? (cat === 'check' || cat === 'edit' ? shortPath(rec.target) : oneLine(rec.target))
      : '';

  if (cat === 'command') {
    if (running) return detail ? `Running ${detail}` : 'Running command';
    if (failed) return detail ? `Failed: ${detail}` : 'Command failed';
    return detail ? `Ran ${detail}` : 'Ran command';
  }
  if (cat === 'search') {
    if (running) return detail ? `Searching ${detail}` : `Searching (${rec.name})`;
    if (failed) return detail ? `Search failed: ${detail}` : `Search failed (${rec.name})`;
    return detail ? `Searched ${detail}` : `Searched (${rec.name})`;
  }
  if (cat === 'check') {
    if (running) return detail ? `Checking ${detail}` : `Checking ${rec.name}`;
    if (failed) return detail ? `Failed checking ${detail}` : `Failed checking ${rec.name}`;
    return detail ? `Checked ${detail}` : `Checked ${rec.name}`;
  }
  if (cat === 'edit') {
    if (running) return detail ? `Editing ${detail}` : `Editing ${rec.name}`;
    if (failed) return detail ? `Failed editing ${detail}` : `Failed editing ${rec.name}`;
    return detail ? `Edited ${detail}` : `Edited ${rec.name}`;
  }
  const name = rec.name || 'tool';
  if (running) return detail ? `Running ${name}: ${detail}` : `Running ${name}`;
  if (failed) return detail ? `Failed ${name}: ${detail}` : `Failed ${name}`;
  return detail ? `Used ${name}: ${detail}` : `Used ${name}`;
}

function isInteractive(update) {
  const id = String(update?.toolCallId ?? '');
  const title = String(update?.title ?? '').toLowerCase();
  return id.startsWith('pi-ui-') || title.includes('ask_user_question');
}

export function toolTitles() {
  const calls = new Map();
  return {
    resetSession(sessionId) {
      const prefix = `${sessionId}:`;
      for (const key of calls.keys()) {
        if (key.startsWith(prefix)) calls.delete(key);
      }
    },
    apply(sessionId, update) {
      if (!sessionId || !update || typeof update !== 'object') return false;
      if (update.sessionUpdate !== 'tool_call' && update.sessionUpdate !== 'tool_call_update') return false;
      if (!update.toolCallId || isInteractive(update)) return false;

      const key = `${sessionId}:${update.toolCallId}`;
      let rec = calls.get(key);
      if (!rec) {
        const rawTitle = typeof update.title === 'string' ? update.title.trim() : '';
        rec = {
          name: rawTitle || 'tool',
          kind: update.kind || 'other',
          isBash: rawTitle === 'Bash' || update.kind === 'execute',
          command: '',
          target: '',
          status: update.status || 'in_progress',
        };
        calls.set(key, rec);
      } else {
        const rawTitle = typeof update.title === 'string' ? update.title.trim() : '';
        if (rawTitle && rec.name === 'tool') rec.name = rawTitle;
        if (update.kind && rec.kind === 'other') rec.kind = update.kind;
        if (update.status) rec.status = update.status;
      }

      const rawTarget = extractTarget(update.rawInput);
      if (rawTarget) {
        if (rec.isBash) rec.command = rawTarget;
        else if (!rec.target) rec.target = rawTarget;
      }

      const contentText = extractText(update.content);
      if (contentText) {
        const cmd = extractBashCommand(contentText);
        if (cmd) {
          rec.isBash = true;
          rec.command = cmd;
        }
      }

      const nextTitle = formatTitle(rec);
      const changed = update.title !== nextTitle;
      update.title = nextTitle;
      if (rec.status === 'completed' || rec.status === 'failed') {
        calls.delete(key);
      }
      return changed;
    },
  };
}
