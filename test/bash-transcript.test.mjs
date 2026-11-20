import assert from 'node:assert/strict';
import { test } from 'node:test';
import { bashTranscript } from '../bash-transcript.mjs';

const call = (title, status = 'pending') => ({
  sessionUpdate: 'tool_call', toolCallId: 'bash-1', title, kind: 'execute', status,
  content: [{ type: 'terminal', terminalId: 'bash-1' }],
  _meta: { terminal_info: { terminal_id: 'bash-1', cwd: '/' } },
});

test('Bash exposes the streamed command and output as expandable ACP content', async () => {
  const apply = bashTranscript();
  const start = call('bash');
  assert.equal(await apply('a', start), true);
  assert.equal(start.title, 'Bash');
  assert.equal(start.kind, 'other');
  assert.deepEqual(start.content, []);
  await apply('a', { sessionUpdate: 'tool_call_update', toolCallId: 'bash-1', title: 'echo ```', status: 'in_progress' });
  const partial = { sessionUpdate: 'tool_call_update', toolCallId: 'bash-1', _meta: { terminal_output: { data: 'line 1\n' } } };
  await apply('a', partial);
  const end = { sessionUpdate: 'tool_call_update', toolCallId: 'bash-1', status: 'completed', _meta: { terminal_output: { data: 'line 2' }, terminal_exit: { exit_code: 0 } } };
  await apply('a', end);
  assert.equal(end._meta, undefined);
  assert.match(end.content[0].content.text, /Command:\necho ```\n\nOutput:/);
  assert.match(end.content[0].content.text, /line 1\nline 2/);
});

test('resumed Bash without output still exposes the recorded command', async () => {
  const apply = bashTranscript(async () => 'git status --short');
  const replay = call('bash', 'completed');
  await apply('a', replay);
  assert.match(replay.content[0].content.text, /git status --short/);
  const untouched = { sessionUpdate: 'tool_call', toolCallId: 'read-1', title: 'read', kind: 'read' };
  assert.equal(await apply('a', untouched), false);
  assert.equal(untouched.content, undefined);
});
