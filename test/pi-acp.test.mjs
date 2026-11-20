import assert from 'node:assert/strict';
import { test } from 'node:test';
import { adaptForTern } from '../pi-acp.mjs';

const model = {
  type: 'select', category: 'model', id: 'model', currentValue: 'www/gpt-6.2-sol',
  options: [{ value: 'www/gpt-6.2-sol', name: 'www/GPT-6.2 Sol' }],
};
const thinking = (levels) => ({
  type: 'select', category: 'thought_level', id: 'thought_level', currentValue: 'high',
  options: levels.map((value) => ({ value, name: `Thinking: ${value}` })),
});

test('Pi uses one dynamic Mode picker and keeps the model and config IDs', () => {
  const result = {
    configOptions: [model, thinking(['off', 'low', 'high', 'max'])],
    models: { currentModelId: model.currentValue, availableModels: [{ modelId: model.currentValue, name: 'www/GPT-6.2 Sol' }] },
    modes: { availableModes: [{ id: 'off' }], currentModeId: 'off' },
  };
  adaptForTern({ result });
  assert.equal(result.modes, undefined);
  assert.deepEqual(result.configOptions[0].options[0], { value: 'www/gpt-6.2-sol', name: 'GPT-6.2 Sol' });
  assert.deepEqual(result.models.availableModels[0], { modelId: 'www/gpt-6.2-sol', name: 'GPT-6.2 Sol' });
  assert.equal(result.configOptions[1].category, 'mode');
  assert.equal(result.configOptions[1].id, 'thought_level');

  const update = { sessionUpdate: 'config_option_update', configOptions: [thinking(['low', 'medium', 'high', 'xhigh', 'max'])] };
  adaptForTern({ method: 'session/update', params: { update } });
  assert.equal(update.configOptions[0].category, 'mode');
  assert.deepEqual(update.configOptions[0].options, ['low', 'medium', 'high', 'xhigh', 'max'].map((value) => ({ value, name: value })));
});

test('session titles and unrelated config options pass through unchanged', () => {
  const title = { method: 'session/update', params: { update: { sessionUpdate: 'session_info_update', title: '真实会话标题' } } };
  const result = { modes: { currentModeId: 'edit' }, configOptions: [{ category: 'mode', id: 'agent_mode' }] };
  const before = structuredClone({ title, result });
  adaptForTern(title);
  adaptForTern({ result });
  assert.deepEqual({ title, result }, before);
});
