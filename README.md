# tern-agent-tabs (Agent Tab Marks)

A [Tern](https://tern.sh) window plugin that enhances tabs for coding agents and vertical sidebar workflows.

## Features

1. **Full Agent Tab Icons (28 Coding Agents, `herdr-radar` style)**
   - Renders crisp, full-size (16px), bare SVG marks with transparent backgrounds (no dark card/shadow overlay) in both the **vertical sidebar** and **horizontal tab bar**, covering both shell-hosted agent sessions and native ACP agent tabs without affecting ordinary shell tabs.
   - Supports 28 agents (27 marks from [herdr-radar](https://github.com/hhdebb/herdr-radar) + Factory Droid):
     `claude`, `codex`, `pi`, `droid`, `opencode`, `omp`, `gemini`, `cursor`, `copilot`, `cline`, `hermes`, `deepseek`, `qwen`, `kimi`, `kilo`, `kiro`, `grok`, `gpt`, `glm`, `agy` (Antigravity), `amp`, `devin`, `qodercli`, `mastracode`, `maki`, `kimchi`, `muse`, `crush`.
   - Applies authentic brand hues for branded agents and clean light ink for monochrome marks.

2. **Automatic ACP Tab Session Titles**
   - Detects ACP and agent panes whose title falls back to a raw executable path (e.g. `C:\Program Files\PowerShell\7\pwsh.exe`) or empty string, and formats them as `<Agent> · <session title>` by reading the ACP surface title or first user prompt (falling back to `<Agent> · <folder>` before the first message).
   - Preserves user-renamed tabs and titles set dynamically by the agent itself, and triggers `tern.chrome.refresh()` automatically whenever computed titles change.

3. **Top Bar Active Tab Icon, Title & Tab Count (Vertical Sidebar Mode)**
   - When vertical sidebar tabs are enabled (`tabs = "Vertical"`, `html.tabs-v`), displays the active tab's agent icon, title, and current/total tab count badge (`pos / total`) centered in the top bar (`#tabbar .tb-sp`), updating immediately on tab focus, creation, close, title, and cwd changes.
   - Leaves horizontal tab mode (`html.tabs-h`) completely untouched.

## Installation

### From GitHub
```bash
tern plugin install github.com/nonlog/tern-agent-tabs
```

### Local Development (Link)
```bash
git clone https://github.com/nonlog/tern-agent-tabs.git
tern plugin link ./tern-agent-tabs
```

After editing `window.luau`, reload in place with:
```bash
tern plugin reload agent-tabs
```

## License

MIT — see [LICENSE](LICENSE) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
