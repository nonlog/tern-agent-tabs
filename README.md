# tern-agent-tabs (Agent Tab Marks)

A [Tern](https://tern.sh) window plugin that enhances tabs for coding agents and vertical sidebar workflows.

## Features

1. **Full Agent Tab Icons (28 Coding Agents, `herdr-radar` style)**
   - Renders crisp, full-size (16px), bare SVG marks with transparent backgrounds (no dark card/shadow overlay) in both the **vertical sidebar** and **horizontal tab bar**, covering both shell-hosted agent sessions and native ACP agent tabs without affecting ordinary shell tabs.
   - Supports 28 agents (27 marks from [herdr-radar](https://github.com/hhdebb/herdr-radar) + Factory Droid):
     `claude`, `codex`, `pi`, `droid`, `opencode`, `omp`, `gemini`, `cursor`, `copilot`, `cline`, `hermes`, `deepseek`, `qwen`, `kimi`, `kilo`, `kiro`, `grok`, `gpt`, `glm`, `agy` (Antigravity), `amp`, `devin`, `qodercli`, `mastracode`, `maki`, `kimchi`, `muse`, `crush`.
   - Applies authentic brand hues for branded agents and clean light ink for monochrome marks.

2. **Automatic ACP Tab Session Titles**
   - Formats ACP tabs as `<Agent> · <session title>` using the name supplied by the agent. An unnamed chat shows `<Agent> · <folder>`. User messages are never used as titles.
   - Preserves manually renamed tabs and updates the sidebar and centered title when the agent reports a new session name.

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

## Pi ACP composer (Tern 0.9.28, pi-acp 0.0.34)

The plugin adds model family icons to the model button. To also hide provider prefixes, use a single model-aware Thinking picker, and show Pi's saved session titles, wrap the Pi ACP command with the included Node script. In Tern's `settings.json`, edit only the Pi entry under `agents.custom`:

```json
{
  "id": "pi",
  "name": "Pi",
  "command": "node",
  "args": ["/absolute/path/to/agent-tabs/pi-acp.mjs", "/absolute/path/to/pi-acp/dist/index.js"]
}
```

Open or resume a Pi ACP chat after changing the command. The bridge adjusts ACP display metadata only: it does not change model IDs, thinking values, provider settings, or session files. To undo it, set `"command": "pi-acp", "args": []` again.

To work in another folder, run **Pi ACP: New Chat in Folder** from Tern's command palette and enter an absolute path. This opens a new tab and keeps the original chat open; native ACP cannot change a live Pi session's working directory in place.

In the transcript, collapsed tool cards show just their headers. Click a header to see its details; Bash includes the command and output reported by Pi. When the focused Pi chat goes idle, tool and thinking rows are hidden and assistant replies remain visible. Run **Pi ACP: Toggle Finished Steps** from the command palette to show or hide the completed work. Bash display changes need a freshly started bridge; existing chats can be reopened with `tern acp pi --sessions`.

The manifest publishes `chat.css` to connected Tern clients. It contains the model icons, reader composer alignment and collapsed tool-card styles and does not require the window script on the client. Dynamic tab chrome and the finished-steps toggle still run in the local window script. A phone may use different composer controls from the desktop; the stylesheet only affects controls the client renders.

Run the regression tests with `node --test` from the plugin folder.

## License

MIT — see [LICENSE](LICENSE) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
