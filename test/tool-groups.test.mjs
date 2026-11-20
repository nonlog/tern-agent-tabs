import test from 'node:test';
import assert from 'node:assert/strict';
import { toolGroups } from '../tool-groups.mjs';

test('groups consecutive tool calls into one collapsible card with running -> past-tense summary', () => {
  const g = toolGroups();
  const s = 'sess-1';

  const u1 = { sessionUpdate: 'tool_call', toolCallId: 'c1', kind: 'other', status: 'in_progress', title: 'codemode' };
  assert.equal(g.apply(s, u1), true);
  assert.equal(u1.sessionUpdate, 'tool_call');
  assert.equal(u1.toolCallId, 'grp-1');
  assert.equal(u1.status, 'in_progress');
  assert.equal(u1.title, 'Running codemode');

  const u1Done = { sessionUpdate: 'tool_call_update', toolCallId: 'c1', status: 'completed' };
  assert.equal(g.apply(s, u1Done), true);
  assert.equal(u1Done.sessionUpdate, 'tool_call_update');
  assert.equal(u1Done.toolCallId, 'grp-1');
  assert.equal(u1Done.status, 'completed');
  assert.equal(u1Done.title, 'Used codemode');

  const u2 = {
    sessionUpdate: 'tool_call',
    toolCallId: 'c2',
    kind: 'other',
    status: 'in_progress',
    title: 'Bash',
    content: [{ type: 'content', content: { type: 'text', text: 'Command:\nssh wa docker ps' } }],
  };
  assert.equal(g.apply(s, u2), true);
  assert.equal(u2.sessionUpdate, 'tool_call_update');
  assert.equal(u2.toolCallId, 'grp-1');
  assert.equal(u2.status, 'in_progress');
  assert.equal(u2.title, 'Running ssh wa docker ps (2 steps)');

  const u2Done = {
    sessionUpdate: 'tool_call_update',
    toolCallId: 'c2',
    status: 'completed',
    content: [{ type: 'content', content: { type: 'text', text: 'Command:\nssh wa docker ps\n\nOutput:\nCONTAINER ID' } }],
  };
  assert.equal(g.apply(s, u2Done), true);
  assert.equal(u2Done.toolCallId, 'grp-1');
  assert.equal(u2Done.status, 'completed');
  assert.equal(u2Done.title, 'Used codemode, ran 1 command');
  assert.match(u2Done.content[0].content.text, /✓ codemode/);
  assert.match(u2Done.content[0].content.text, /✓ Bash: ssh wa docker ps/);
});

test('assistant progress message closes current group and starts a new group after it', () => {
  const g = toolGroups();
  const s = 'sess-2';

  const u1 = { sessionUpdate: 'tool_call', toolCallId: 'a1', kind: 'read', status: 'completed', title: 'Read', rawInput: { path: 'D:/Workspace/settings.json' } };
  g.apply(s, u1);
  assert.equal(u1.toolCallId, 'grp-1');
  assert.equal(u1.title, 'Checked settings.json');

  const msg = { sessionUpdate: 'agent_message_chunk', content: { type: 'text', text: '初步结果很明确，接着确认配置。' } };
  assert.equal(g.apply(s, msg), false);

  const u2 = { sessionUpdate: 'tool_call', toolCallId: 'a2', kind: 'other', status: 'in_progress', title: 'Bash', rawInput: { command: 'ls -la' } };
  g.apply(s, u2);
  assert.equal(u2.sessionUpdate, 'tool_call');
  assert.equal(u2.toolCallId, 'grp-2');
  assert.equal(u2.title, 'Running ls -la');
});

test('interactive ask_user_question tool calls bypass grouping', () => {
  const g = toolGroups();
  const u = { sessionUpdate: 'tool_call', toolCallId: 'pi-ui-1', kind: 'other', status: 'pending', title: 'ask_user_question' };
  assert.equal(g.apply('sess-3', u), false);
  assert.equal(u.toolCallId, 'pi-ui-1');
});
