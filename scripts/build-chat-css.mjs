import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const dir = dirname(dirname(fileURLToPath(import.meta.url)));

function svgUrl(name, fill) {
  const raw = readFileSync(join(dir, 'icons', name + '.svg'), 'utf8');
  const styleTag = '<style>path,circle,rect,polygon,polyline,ellipse{fill:' + fill + ';}</style>';
  let out = raw.replace(/<style>[\s\S]*?<\/style>/, styleTag);
  if (out === raw) out = raw.replace(/currentColor/g, fill);
  return 'url("data:image/svg+xml;base64,' + Buffer.from(out, 'utf8').toString('base64') + '")';
}

const DARK_MONO = '#e9e9f0';
const LIGHT_MONO = '#1f2328';

const MODELS = [
  { icon: 'gpt', color: null, titles: ['GPT', 'OpenAI', 'o1', 'o3', 'o4', 'Codex'] },
  { icon: 'claude', color: '#d97757', titles: ['Claude'] },
  { icon: 'gemini', color: '#4285f4', titles: ['Gemini'] },
  { icon: 'glm', color: null, titles: ['GLM'] },
  { icon: 'deepseek', color: '#4d6bfe', titles: ['DeepSeek'] },
  { icon: 'kimi', color: '#1783ff', titles: ['Kimi'] },
  { icon: 'qwen', color: '#7b76f5', titles: ['Qwen'] },
  { icon: 'grok', color: null, titles: ['Grok'] },
  { icon: 'muse', color: '#2b95ff', titles: ['Muse'] },
];

// Built-in Tern data-program keys for remote/mobile tab & header icons.
// 'agent' covers custom ACP agents (Pi by default; desktop window.luau still overrides per-tab).
const PROGRAMS = [
  { program: 'agent', icon: 'pi', color: null },
  { program: 'omp', icon: 'omp', color: null },
  { program: 'claude', icon: 'claude', color: '#d97757' },
  { program: 'codex', icon: 'codex', color: null },
  { program: 'opencode', icon: 'opencode', color: null },
  { program: 'gemini', icon: 'gemini', color: '#4285f4' },
  { program: 'copilot', icon: 'copilot', color: null },
  { program: 'cursor-agent', icon: 'cursor', color: null },
];

const parts = [];
parts.push('/* Manifest CSS travels to remote clients (mobile/web). Artwork is inline because remote sync sends CSS, not icon files. */');

parts.push([
  '.sf-dock.sf-chat-reader[data-surface="omp.session"] [data-role="omp.composer.mode"] {',
  '\talign-self: flex-start !important;',
  '\theight: 28px !important;',
  '\tmargin-top: 0 !important;',
  '\tpadding: 0 10px !important;',
  '}',
  '',
  '.sf-main[data-surface="omp.session"] .sf-tool.collapsed > .sf-tool-body,',
  '.sf-main[data-surface="omp.session"] .sf-tool.collapsed > .sf-tool-more,',
  '.sf-main[data-surface="omp.session"] .sf-tool.collapsed > .sf-tool-head .sf-tool-target {',
  '\tdisplay: none !important;',
  '}',
  '',
  '/* Timeline mode: visually demote process steps & intermediate progress notes into a quiet left-bordered log, keeping final answer crisp */',
  '.sf-main[data-surface="omp.session"] [data-role="omp.assistant"] > .sf-tool {',
  '\tborder-left: 2px solid var(--l2) !important;',
  '\tpadding-left: 10px !important;',
  '\tmargin: 1px 0 !important;',
  '}',
  '',
  '.sf-main[data-surface="omp.session"] [data-role="omp.assistant"] > .sf-tool.collapsed > .sf-tool-head {',
  '\tmin-height: 22px !important;',
  '\tpadding-top: 1px !important;',
  '\tpadding-bottom: 1px !important;',
  '\tfont-size: 12.5px !important;',
  '\tcolor: var(--t3) !important;',
  '}',
  '',
  '.sf-main[data-surface="omp.session"] [data-role="omp.assistant"] > [data-role="omp.thinking"] {',
  '\tborder-left: 2px solid var(--l2) !important;',
  '\tpadding-left: 10px !important;',
  '\tmargin: 1px 0 !important;',
  '\tfont-size: 12px !important;',
  '\tcolor: var(--t3) !important;',
  '\topacity: 0.85 !important;',
  '}',
  '',
  '.sf-main[data-surface="omp.session"] [data-role="omp.assistant"] > .sf-tool + .sf-md,',
  '.sf-main[data-surface="omp.session"] [data-role="omp.assistant"] > [data-role="omp.thinking"] + .sf-md {',
  '\tmargin-top: 10px !important;',
  '}',
  '',
  '.sf-main[data-surface="omp.session"] [data-role="omp.assistant"] > .sf-md:has(+ .sf-tool) {',
  '\tfont-size: 12.5px !important;',
  '\tline-height: 1.45 !important;',
  '\tcolor: var(--t3) !important;',
  '\tborder-left: 2px solid var(--l2) !important;',
  '\tpadding-left: 10px !important;',
  '\tmargin: 2px 0 !important;',
  '\topacity: 0.85 !important;',
  '}',
  '',
  '.sf-main[data-surface="omp.session"] [data-role="omp.assistant"] > .sf-md:has(+ [data-role="omp.thinking"]) {',
  '\tfont-size: 12.5px !important;',
  '\tline-height: 1.45 !important;',
  '\tcolor: var(--t3) !important;',
  '\tborder-left: 2px solid var(--l2) !important;',
  '\tpadding-left: 10px !important;',
  '\tmargin: 2px 0 !important;',
  '\topacity: 0.85 !important;',
  '}',
  '',
  '.sf-main[data-surface="omp.session"] [data-role="omp.assistant"]:has(+ [data-role="omp.assistant"]) > .sf-md {',
  '\tfont-size: 12.5px !important;',
  '\tline-height: 1.45 !important;',
  '\tcolor: var(--t3) !important;',
  '\tborder-left: 2px solid var(--l2) !important;',
  '\tpadding-left: 10px !important;',
  '\tmargin: 2px 0 !important;',
  '\topacity: 0.85 !important;',
  '}',
].join('\n'));

const progList = PROGRAMS.map((p) => '[data-program="' + p.program + '"]').join(',\n\t');
parts.push([
  '/* Tab and mobile header agent icons (syncs to remote/mobile clients where window.luau does not run) */',
  ':is(.tn-dk-c, .tn-face):is(',
  '\t' + progList,
  ') {',
  '\tbackground-color: transparent !important;',
  '\tbackground-size: 86% 86% !important;',
  '\tbackground-position: center !important;',
  '\tbackground-repeat: no-repeat !important;',
  '\tbox-shadow: none !important;',
  '\tborder-radius: 0 !important;',
  '}',
  '',
  '.tn-dk-c:is(',
  '\t' + progList,
  ') {',
  '\tleft: 0 !important;',
  '\ttop: 0 !important;',
  '\twidth: 100% !important;',
  '\theight: 100% !important;',
  '}',
  '',
  ':is(.tn-dk-c, .tn-face):is(',
  '\t' + progList,
  ') > .tn-dk-g,',
  ':is(.tn-dk-c, .tn-face):is(',
  '\t' + progList,
  ') > svg {',
  '\topacity: 0 !important;',
  '}',
].join('\n'));

for (const p of PROGRAMS) {
  if (p.color) {
    parts.push(':is(.tn-dk-c, .tn-face)[data-program="' + p.program + '"] {\n\tbackground-image: ' + svgUrl(p.icon, p.color) + ' !important;\n}');
  } else {
    parts.push(':is(.tn-dk-c, .tn-face)[data-program="' + p.program + '"] {\n\tbackground-image: ' + svgUrl(p.icon, DARK_MONO) + ' !important;\n}');
    parts.push(':root:not([data-theme="dark"]) :is(.tn-dk-c, .tn-face)[data-program="' + p.program + '"] {\n\tbackground-image: ' + svgUrl(p.icon, LIGHT_MONO) + ' !important;\n}');
  }
}

const allTitleSels = MODELS.flatMap((m) => m.titles.flatMap((t) => ['[title^="Model: ' + t + '"]', '[title^="Model: www/' + t + '"]']));
parts.push([
  '/* Composer model button icons */',
  '.sf-dock[data-surface="omp.session"] [data-role="omp.composer.model"]:is(',
  '\t' + allTitleSels.join(',\n\t'),
  ') > .sf-icon:first-child {',
  '\tbackground-size: contain !important;',
  '\tbackground-position: center !important;',
  '\tbackground-repeat: no-repeat !important;',
  '\tcolor: transparent !important;',
  '}',
].join('\n'));

for (const m of MODELS) {
  const sels = m.titles.flatMap((t) => ['[title^="Model: ' + t + '"]', '[title^="Model: www/' + t + '"]']).join(', ');
  if (m.color) {
    parts.push('.sf-dock[data-surface="omp.session"] [data-role="omp.composer.model"]:is(' + sels + ') > .sf-icon:first-child {\n\tbackground-image: ' + svgUrl(m.icon, m.color) + ' !important;\n}');
  } else {
    parts.push('.sf-dock[data-surface="omp.session"] [data-role="omp.composer.model"]:is(' + sels + ') > .sf-icon:first-child {\n\tbackground-image: ' + svgUrl(m.icon, DARK_MONO) + ' !important;\n}');
    parts.push(':root:not([data-theme="dark"]) .sf-dock[data-surface="omp.session"] [data-role="omp.composer.model"]:is(' + sels + ') > .sf-icon:first-child {\n\tbackground-image: ' + svgUrl(m.icon, LIGHT_MONO) + ' !important;\n}');
  }
}

const out = parts.join('\n\n') + '\n';
writeFileSync(join(dir, 'chat.css'), out, 'utf8');
console.log('Generated chat.css:', out.length, 'bytes');
