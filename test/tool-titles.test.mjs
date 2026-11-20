import test from 'node:test';
import assert from 'node:assert/strict';
import { toolTitles } from '../tool-titles.mjs';

test('formats Bash card titles as Running -> Ran without merging cards', () => {
  const t = toolTitles();
  const u1 = {
    sessionUpdate: 'tool_call',
    toolCallId: 'b1',
    kind: 'other',
    status: 'in_progress',
    title: 'Bash',
    content: [{ type: 'content', content: { type: 'text', text: 'Command:\nssh wa docker ps' } }],
  };
  assert.equal(t.apply('s1', u1), true);
  assert.equal(u1.toolCallId, 'b1');
  assert.equal(u1.title, 'Running ssh wa docker ps');

  const u2 = { sessionUpdate: 'tool_call_update', toolCallId: 'b1', status: 'completed' };
  assert.equal(t.apply('s1', u2), true);
  assert.equal(u2.toolCallId, 'b1');
  assert.equal(u2.title, 'Ran ssh wa docker ps');
});

test('formats Read, Edit, and MCP tool titles cleanly', () => {
  const t = toolTitles();
  const r = { sessionUpdate: 'tool_call', toolCallId: 'r1', kind: 'read', status: 'completed', title: 'Read', rawInput: { path: 'D:/Workspace/settings.json' } };
  t.apply('s1', r);
  assert.equal(r.title, 'Checked settings.json');

  const e = { sessionUpdate: 'tool_call', toolCallId: 'e1', kind: 'edit', status: 'in_progress', title: 'Edit', rawInput: { file_path: 'C:/a/b/window.luau' } };
  t.apply('s1', e);
  assert.equal(e.title, 'Editing window.luau');

  const m = { sessionUpdate: 'tool_call', toolCallId: 'm1', kind: 'other', status: 'completed', title: 'codemode' };
  t.apply('s1', m);
  assert.equal(m.title, 'Used codemode');
});

test('skips ask_user_question interactive calls', () => {
  const t = toolTitles();
  const q = { sessionUpdate: 'tool_call', toolCallId: 'pi-ui-1', status: 'pending', title: 'ask_user_question' };
  assert.equal(t.apply('s1', q), false);
  assert.equal(q.title, 'ask_user_question');
});
