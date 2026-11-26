--!strict
-- Agent Tab Marks (agent-tabs)
--
-- 1. Agent tab icons: 28 coding agent SVG marks (herdr-radar set + droid) rendered crisply at
--    full size (16px, transparent background, no dark card/mask) on both vertical sidebar and
--    horizontal tab rows, without affecting ordinary shell tabs.
-- 2. ACP tab titles use the actual session name, with a folder fallback for unnamed chats.
-- 3. Vertical-sidebar top bar: when vertical sidebar tabs are enabled (html.tabs-v), shows the
--    active tab's agent icon, title, and current/total tab count centered in #tabbar .tb-sp.

local POLL_MS = 1500

type AgentSpec = {
	display: string,
	color: string?,
}

-- 28 supported coding agents (27 from hhdebb/herdr-radar + Factory Droid).
local AGENTS: { [string]: AgentSpec } = {
	claude = { display = "Claude Code", color = "#d97757" },
	codex = { display = "Codex" },
	opencode = { display = "OpenCode" },
	omp = { display = "Oh My Pi" },
	pi = { display = "Pi" },
	droid = { display = "Droid" },
	cline = { display = "Cline", color = "#7c91a3" },
	mastracode = { display = "Mastra" },
	kimi = { display = "Kimi", color = "#1783ff" },
	kilo = { display = "Kilo", color = "#c8c528" },
	maki = { display = "Maki" },
	hermes = { display = "Hermes" },
	cursor = { display = "Cursor" },
	copilot = { display = "Copilot" },
	deepseek = { display = "DeepSeek", color = "#4d6bfe" },
	gemini = { display = "Gemini", color = "#4285f4" },
	gpt = { display = "GPT" },
	qwen = { display = "Qwen", color = "#7b76f5" },
	grok = { display = "Grok" },
	agy = { display = "Antigravity" },
	kiro = { display = "Kiro", color = "#a466ff" },
	amp = { display = "Amp" },
	devin = { display = "Devin" },
	qodercli = { display = "Qoder" },
	glm = { display = "GLM" },
	kimchi = { display = "Kimchi", color = "#ff521d" },
	muse = { display = "Muse", color = "#2b95ff" },
	crush = { display = "Crush", color = "#ff4d97" },
}

local ALIASES: { [string]: string } = {
	["claude-code"] = "claude",
	["claude-agent-acp"] = "claude",
	["pi-acp"] = "pi",
	["oh-my-pi"] = "omp",
	["antigravity"] = "agy",
	["qoder"] = "qodercli",
	["mastra"] = "mastracode",
	["factory"] = "droid",
	["github-copilot"] = "copilot",
}

local GENERIC_SHELLS: { [string]: boolean } = {
	pwsh = true,
	powershell = true,
	cmd = true,
	bash = true,
	zsh = true,
	sh = true,
	fish = true,
	dash = true,
	ksh = true,
	nu = true,
	nushell = true,
	wsl = true,
	tern = true,
}

local V_ROW = ".nav-group.g-sp-cur .nav-items > div > button.nav-row:nth-of-type(%d)"
local H_ROW = "#tabbar .tb-tabs > button.tt:nth-of-type(%d)"

-- Lazy cache of tinted base64 data URLs for icons/<key>.svg.
local icon_cache: { [string]: string } = {}

local function tint_svg(raw: string, fill_color: string): string
	local style_tag = "<style>path,circle,rect,polygon,polyline,ellipse{fill:" .. fill_color .. ";}</style>"
	local out, count = string.gsub(raw, "<style>.-</style>", style_tag)
	if count == 0 then
		out = string.gsub(raw, "currentColor", fill_color)
	end
	return out
end

local function icon_data_url(key: string): string?
	local cached = icon_cache[key]
	if cached then
		return if cached == "" then nil else cached
	end
	local path = "icons/" .. key .. ".svg"
	local ok, raw = pcall(tern.fs.read, path)
	if not ok or type(raw) ~= "string" or raw == "" then
		icon_cache[key] = ""
		return nil
	end
	local spec = AGENTS[key]
	local fill = if spec and spec.color then spec.color else "#e9e9f0"
	local tinted = tint_svg(raw, fill)
	local url = "data:image/svg+xml;base64," .. tern.base64.encode(tinted)
	icon_cache[key] = url
	return url
end

local function basename(path: string): string
	local name = string.match(path, "([^\\/]+)[\\/]*$")
	return name or path
end

local function strip_exe(name: string): string
	local lower = string.lower(name)
	local stripped = string.match(lower, "^(.+)%.exe$") or string.match(lower, "^(.+)%.com$") or string.match(lower, "^(.+)%.cmd$") or lower
	return stripped
end

local function css_escape(s: string): string
	local cleaned = string.gsub(s, "[\r\n\t]+", " ")
	cleaned = string.gsub(cleaned, "\\", "\\\\")
	cleaned = string.gsub(cleaned, '"', '\\"')
	return cleaned
end

local function absolute_path(path: string): boolean
	return string.sub(path, 1, 1) == "/" or string.sub(path, 1, 2) == "\\\\"
		or string.match(path, "^%a:[/\\]") ~= nil
end

local function match_command(text: string?): string?
	if not text or text == "" then
		return nil
	end
	local lower = string.lower(text)
	local best_key: string? = nil
	local best_len = 0

	for alias, canonical in pairs(ALIASES) do
		local pat = "%f[%w%-]" .. string.gsub(alias, "%-", "%%-") .. "%f[^%w%-]"
		local s, e = string.find(lower, pat)
		if s and e and (e - s + 1) > best_len then
			best_key = canonical
			best_len = e - s + 1
		end
	end
	for key in pairs(AGENTS) do
		local s, e = string.find(lower, "%f[%w]" .. key .. "%f[%W]")
		if s and e and (e - s + 1) > best_len then
			best_key = key
			best_len = e - s + 1
		end
	end
	return best_key
end

local function match_title(title: string?): string?
	if not title or title == "" then
		return nil
	end
	if string.sub(title, 1, 2) == "\207\128" then
		return "pi"
	end
	local lower = string.lower(title)
	local trimmed = string.match(lower, "^[^%w]*(.*)$") or lower

	local first_word = string.match(trimmed, "^([%w%-]+)")
	if first_word then
		if ALIASES[first_word] then
			return ALIASES[first_word]
		end
		if AGENTS[first_word] then
			local rest = string.sub(trimmed, #first_word + 1)
			if rest == "" or string.match(rest, "^[%s%-%(%)%·/:]") then
				return first_word
			end
		end
	end

	if string.find(trimmed, "^claude%s+code") then
		return "claude"
	end
	if string.find(trimmed, "^oh%s+my%s+pi") then
		return "omp"
	end
	return nil
end

local function from_program(title: string?): boolean
	if not title or title == "" then
		return true
	end
	if string.find(title, "[\\/]") ~= nil then
		return true
	end
	local lower = string.lower(title)
	if string.match(lower, "%.exe$") ~= nil or string.match(lower, "%.com$") ~= nil then
		return true
	end
	if GENERIC_SHELLS[lower] then
		return true
	end
	return false
end

local function detect_pane_agent(pane: PaneInfo, acp_agents: { [number]: string }): string?
	local from_acp = acp_agents[pane.pane]
	if from_acp then
		return from_acp
	end
	if pane.program and pane.program ~= "" then
		local prog = strip_exe(basename(pane.program))
		if not GENERIC_SHELLS[prog] then
			local m = match_command(prog)
			if m then
				return m
			end
		end
	end
	if pane.running and pane.running.line and pane.running.line ~= "" then
		local m = match_command(pane.running.line)
		if m then
			return m
		end
	end
	if pane.last and pane.last.line and pane.last.line ~= "" and from_program(pane.title) then
		local m = match_command(pane.last.line)
		if m then
			return m
		end
	end
	return match_title(pane.title)
end

local function acp_session_title(pane: PaneInfo?, agent_key: string): string?
	local raw = if pane and pane.title then string.match(pane.title, "^%s*(.-)%s*$") else nil
	if not raw or raw == "" or absolute_path(raw) then
		return nil
	end
	local lower = string.lower(raw)
	if lower == agent_key or lower == string.lower(AGENTS[agent_key].display) or GENERIC_SHELLS[strip_exe(lower)] then
		return nil
	end
	if pane and pane.program and lower == string.lower(pane.program) then
		return nil
	end
	return raw
end

local function format_agent_title(agent_key: string, session_title: string?, cwd: string?): string
	local spec = AGENTS[agent_key]
	local label = if spec then spec.display else agent_key
	if session_title and session_title ~= "" then
		local prefix = label .. " \194\183 "
		return if string.sub(session_title, 1, #prefix) == prefix then session_title else prefix .. session_title
	end
	local folder = if cwd and cwd ~= "" then basename(cwd) else nil
	if folder and folder ~= "" then
		return label .. " \194\183 " .. folder
	end
	return label
end

-- Shared state read by tern.chrome.tab_title formatter.
local agent_of_pane: { [number]: string } = {}
local title_of_tab: { [number]: string } = {}
local last_title_sig = ""
local installed_icon_css = ""
local installed_topbar_css = ""

tern.chrome.tab_title(function(tab: TabInfo): string?
	if tab.name and tab.name ~= "" then
		return nil
	end
	local planned = title_of_tab[tab.id]
	if planned then
		return planned
	end
	if not from_program(tab.title) then
		return nil
	end
	local agent = agent_of_pane[tab.pane]
	if agent then
		return format_agent_title(agent, nil, tab.cwd)
	end
	return nil
end)

local function build_icon_rule(position: number, agent_key: string): string
	local url = icon_data_url(agent_key)
	if not url then
		return ""
	end
	local v = string.format(V_ROW, position)
	local h = string.format(H_ROW, position)

	return table.concat({
		-- Hide Tern's default glyph/tile children inside .tn-dk-c and horizontal .tn-face
		string.format(
			"%s .tn-dk-c > *, %s .tn-dk-c > *, %s .fc .tn-face > * { opacity: 0 !important; }",
			v,
			h,
			h
		),
		-- Crisp, bare, full-size SVG mark (herdr-radar style: no dark square card, no shadow, no mask)
		string.format(
			'%s .tn-dk-c, %s .tn-dk-c { left: 0 !important; top: 0 !important; width: 18px !important; height: 18px !important; border-radius: 0 !important; box-shadow: none !important; background: transparent !important; background-image: url("%s") !important; background-size: 16px 16px !important; background-repeat: no-repeat !important; background-position: center !important; }',
			v,
			h,
			url
		),
		string.format(
			'%s .fc .tn-face { background-image: url("%s") !important; background-size: 15px 15px !important; background-repeat: no-repeat !important; background-position: center !important; }',
			h,
			url
		),
	}, "\n")
end

local function build_topbar_css(title: string, active_pos: number, total_tabs: number, agent_key: string?): string
	if total_tabs <= 0 then
		return ""
	end
	local safe_title = css_escape(title)
	local count_text = string.format("%d / %d", active_pos, total_tabs)
	local icon_css = ""
	if agent_key then
		local url = icon_data_url(agent_key)
		if url then
			icon_css = string.format(
				[[
	padding-left: 22px;
	background-image: url("%s");
	background-size: 15px 15px;
	background-repeat: no-repeat;
	background-position: left center;
]],
				url
			)
		end
	end
	return string.format(
		[[
html.tabs-v #tabbar .tb-sp {
	display: flex !important;
	align-items: center;
	justify-content: center;
	gap: 8px;
	min-width: 0;
	overflow: hidden;
	padding: 0 12px;
}
html.tabs-v #tabbar .tb-sp::before {
	content: "%s";
	color: var(--t2);
	font-size: 12.5px;
	font-weight: 500;
	line-height: 16px;
	overflow: hidden;
	text-overflow: ellipsis;
	white-space: nowrap;
	min-width: 0;
	pointer-events: none;
%s}
html.tabs-v #tabbar .tb-sp::after {
	content: "%s";
	flex: none;
	color: var(--t3);
	background: var(--l1);
	border-radius: 999px;
	padding: 2px 7px;
	font-size: 11px;
	font-weight: 500;
	font-variant-numeric: tabular-nums;
	line-height: 1.2;
	white-space: nowrap;
	pointer-events: none;
}
]],
		safe_title,
		icon_css,
		count_text
	)
end

local hide_finished_steps = true
local installed_finished_steps = false
local function set_finished_steps(hidden: boolean)
	if hidden == installed_finished_steps then return end
	tern.css("finished-steps", if hidden then [[
.tn-pane.on .sf-main[data-surface="omp.session"] [data-role="omp.assistant"] > .sf-tool,
.tn-pane.on .sf-main[data-surface="omp.session"] [data-role="omp.assistant"] > [data-role="omp.thinking"] {
	display: none !important;
}
.tn-pane.on .sf-main[data-surface="omp.session"] [data-role="omp.assistant"] > .sf-md:has(+ .sf-tool) {
	display: none !important;
}
.tn-pane.on .sf-main[data-surface="omp.session"] [data-role="omp.assistant"] > .sf-md:has(+ [data-role="omp.thinking"]) {
	display: none !important;
}
.tn-pane.on .sf-main[data-surface="omp.session"] [data-role="omp.assistant"]:has(+ [data-role="omp.assistant"]) {
	display: none !important;
}
]] else "")
	installed_finished_steps = hidden
end

local WORKSPACE_ROOT = "D:\\Workspace"
local unseen_done: { [number]: boolean } = {}
local installed_status_css = ""

local STATUS_PRIORITY: { [string]: number } = {
	unread = 1,
	working = 2,
	waiting = 3,
}

local STATUS_KEYFRAMES = [[
@keyframes atStatusPulse {
	0%, 100% { opacity: 1; transform: scale(1); }
	50% { opacity: 0.45; transform: scale(0.82); }
}
]]

local function build_status_rule(pos: number, status: string): string
	local v = string.format(V_ROW, pos)
	local h = string.format(H_ROW, pos)
	local color = if status == "waiting" then "#f59e0b" elseif status == "working" then "#38bdf8" else "#a78bfa"
	local anim = if status == "unread" then "none" else "atStatusPulse 1.6s ease-in-out infinite"
	return string.format(
		'%s .lbl::before, %s .lbl::before { content: ""; display: inline-block; width: 6px; height: 6px; border-radius: 50%%; margin-right: 6px; vertical-align: middle; background: %s; animation: %s; }',
		v,
		h,
		color,
		anim
	)
end

local function build_agents_widget_rules(agent_keys: { string }): { string }
	local rules: { string } = {}
	for i, key in ipairs(agent_keys) do
		local url = icon_data_url(key)
		if url then
			local sel = string.format('.wg[data-widget="agents"] .wg-agents-tiles > .wg-agents-tile:nth-of-type(%d)', i)
			table.insert(rules, string.format('%s { background: transparent !important; box-shadow: none !important; border-radius: 0 !important; }', sel))
			table.insert(rules, string.format('%s .wg-agents-art { background-image: url("%s") !important; background-size: 14px 14px !important; background-repeat: no-repeat !important; background-position: center !important; }', sel, url))
			table.insert(rules, string.format('%s .wg-agents-art > svg { opacity: 0 !important; }', sel))
		end
	end
	return rules
end

local function refresh(cx: WindowCx)
	-- 1. Collect ACP / registered agents from cx.agents:list().
	local focused_pane = cx.session:focused()
	local focused_pi_idle = false
	local acp_agents: { [number]: string } = {}
	local agent_state_of_pane: { [number]: string } = {}
	local ordered_agent_keys: { string } = {}
	for _, info in ipairs(cx.agents:list()) do
		agent_state_of_pane[info.pane] = info.state
		if info.state == "working" or info.state == "waiting_input" then
			unseen_done[info.pane] = nil
		end
		local key = match_command(info.command)
		if key then
			acp_agents[info.pane] = key
			table.insert(ordered_agent_keys, key)
		else
			table.insert(ordered_agent_keys, "")
		end
		if info.pane == focused_pane and key == "pi" then
			focused_pi_idle = info.state == "idle"
		end
	end
	if focused_pane then
		unseen_done[focused_pane] = nil
	end
	set_finished_steps(hide_finished_steps and focused_pi_idle)

	-- 2. Detect agent per pane across all panes (ACP + shell-hosted + direct agent binaries).
	local next_agent_of_pane: { [number]: string } = {}
	local pane_by_id: { [number]: PaneInfo } = {}
	for _, pane in ipairs(cx.session:panes()) do
		pane_by_id[pane.pane] = pane
		local key = detect_pane_agent(pane, acp_agents)
		if key then
			next_agent_of_pane[pane.pane] = key
		end
	end
	for pane_id, key in pairs(acp_agents) do
		if not next_agent_of_pane[pane_id] then
			next_agent_of_pane[pane_id] = key
		end
	end
	agent_of_pane = next_agent_of_pane

	-- 3. Identify active tab & current session.
	local active_tab_id = if focused_pane then cx.session:tab_of(focused_pane) else nil
	local tabs = cx.session:tabs()
	local current_session: number? = nil
	local active_tab: TabInfo? = nil

	for _, tab in ipairs(tabs) do
		if tab.id == active_tab_id then
			current_session = tab.session
			active_tab = tab
			break
		end
	end
	if not current_session then
		for _, sess in ipairs(cx.session:sessions()) do
			if sess.current then
				current_session = sess.id
				break
			end
		end
	end
	if not active_tab then
		for _, tab in ipairs(tabs) do
			if not current_session or tab.session == current_session then
				active_tab = tab
				current_session = tab.session
				break
			end
		end
	end

	-- 4. Compute ACP/agent tab titles and per-tab icon CSS for the current session.
	local next_title_of_tab: { [number]: string } = {}
	local agent_of_tab: { [number]: string } = {}
	local title_sig_parts: { string } = {}
	for pane_id in pairs(unseen_done) do
		if not pane_by_id[pane_id] then
			unseen_done[pane_id] = nil
		end
	end

	local icon_rules: { string } = {}
	local status_rules: { string } = {}
	local session_tab_count = 0

	for _, tab in ipairs(tabs) do
		local agent = next_agent_of_pane[tab.pane]
		local agent_pane = if agent then tab.pane else nil
		if not agent then
			for pane_id, key in pairs(next_agent_of_pane) do
				local p = pane_by_id[pane_id]
				if p and p.tab == tab.id then
					agent = key
					agent_pane = pane_id
					break
				end
			end
		end

		if agent then
			agent_of_tab[tab.id] = agent
		end

		if agent and agent_pane and (not tab.name or tab.name == "") then
			local is_acp = acp_agents[agent_pane] ~= nil
			local name = if is_acp then acp_session_title(pane_by_id[agent_pane], agent) else nil
			if is_acp or from_program(tab.title) then
				local formatted = format_agent_title(agent, name, tab.cwd)
				next_title_of_tab[tab.id] = formatted
				table.insert(title_sig_parts, tostring(tab.id) .. "=" .. formatted)
			end
		end

		if tab.session == current_session then
			session_tab_count += 1
			if agent then
				local rule = build_icon_rule(tab.position, agent)
				if rule ~= "" then
					table.insert(icon_rules, rule)
				end
			end

			local tab_status: string? = nil
			local best_prio = 0
			local function consider_pane(pid: number?)
				if not pid then return end
				if tab.id == active_tab_id then
					unseen_done[pid] = nil
				end
				local st = agent_state_of_pane[pid]
				local mapped: string? = nil
				if st == "waiting_input" then
					mapped = "waiting"
				elseif st == "working" then
					mapped = "working"
				elseif unseen_done[pid] and tab.id ~= active_tab_id then
					mapped = "unread"
				end
				if mapped then
					local prio = STATUS_PRIORITY[mapped] or 0
					if prio > best_prio then
						best_prio = prio
						tab_status = mapped
					end
				end
			end
			consider_pane(tab.pane)
			for pane_id, p in pairs(pane_by_id) do
				if p.tab == tab.id and pane_id ~= tab.pane then
					consider_pane(pane_id)
				end
			end
			if tab_status then
				table.insert(status_rules, build_status_rule(tab.position, tab_status))
			end
		end
	end

	title_of_tab = next_title_of_tab
	table.sort(title_sig_parts)
	local title_sig = table.concat(title_sig_parts, "|")
	if title_sig ~= last_title_sig then
		last_title_sig = title_sig
		tern.chrome.refresh()
	end

	for _, r in ipairs(build_agents_widget_rules(ordered_agent_keys)) do
		table.insert(icon_rules, r)
	end
	local icon_css = table.concat(icon_rules, "\n")
	if icon_css ~= installed_icon_css then
		tern.css("icons", icon_css)
		installed_icon_css = icon_css
	end

	local status_css = if #status_rules > 0 then (STATUS_KEYFRAMES .. "\n" .. table.concat(status_rules, "\n")) else ""
	if status_css ~= installed_status_css then
		tern.css("status", status_css)
		installed_status_css = status_css
	end

	-- 5. Compute top bar CSS for vertical sidebar mode (html.tabs-v).
	local topbar_css = ""
	if active_tab and session_tab_count > 0 then
		local display_title = ""
		if active_tab.name and active_tab.name ~= "" then
			display_title = active_tab.name
		elseif next_title_of_tab[active_tab.id] then
			display_title = next_title_of_tab[active_tab.id]
		elseif active_tab.title and active_tab.title ~= "" then
			display_title = active_tab.title
		elseif active_tab.cwd and active_tab.cwd ~= "" then
			display_title = basename(active_tab.cwd)
		else
			display_title = "Tab " .. tostring(active_tab.position)
		end
		topbar_css = build_topbar_css(display_title, active_tab.position, session_tab_count, agent_of_tab[active_tab.id])
	end
	if topbar_css ~= installed_topbar_css then
		tern.css("topbar", topbar_css)
		installed_topbar_css = topbar_css
	end
end

local function prompt_custom_pi_folder(cx: WindowCx, default_cwd: string)
	cx:prompt({ value = default_cwd, placeholder = "Folder for the new Pi chat", action = "open new chat" })
		:next(function(input, _, window)
			if not input or not window then return end
			local path = string.match(input, "^%s*(.-)%s*$") or ""
			if not absolute_path(path) then
				window:toast("warn", "Enter an absolute folder path")
				return
			end
			tern.process.run({ "node", "-e", "if (!require('node:fs').statSync(process.argv[1], { throwIfNoEntry: false })?.isDirectory()) process.exitCode = 1", "--", path },
				{ timeout_ms = 3000 }, function(result, fresh)
					if not fresh then return end
					if result.status ~= 0 then
						fresh:toast("warn", "Folder not found or unavailable", path)
						return
					end
					fresh.layout:new_tab({ cwd = path, command = "tern acp pi" })
				end)
		end)
end

local function normalize_win_path(path: string): string
	local normalized = string.gsub(path, "/", "\\")
	normalized = string.gsub(normalized, "\\+$", "")
	return normalized
end

tern.command({
	id = "pi-in-folder",
	title = "Pi ACP: New Chat in Folder",
	icon = "folder",
	run = function(cx: WindowCx)
		local focused = cx.session:focused()
		local pane = if focused then cx.session:pane(focused) else nil
		local current_cwd = if pane and pane.cwd and pane.cwd ~= "" then normalize_win_path(pane.cwd) else ""
		local list_script = "const fs=require('node:fs');const root=process.argv[1];let dirs=[];try{dirs=fs.readdirSync(root,{withFileTypes:true}).filter(d=>d.isDirectory()&&!d.name.startsWith('.')).map(d=>d.name).sort((a,b)=>{if(a==='General')return -1;if(b==='General')return 1;return a.localeCompare(b,undefined,{sensitivity:'base'});});}catch{}process.stdout.write(JSON.stringify(dirs));"
		tern.process.run({ "node", "-e", list_script, "--", WORKSPACE_ROOT }, { timeout_ms = 3000 }, function(result, fresh)
			if not fresh then return end
			local items: { PickItem } = {}
			local seen: { [string]: boolean } = {}
			if current_cwd ~= "" and absolute_path(current_cwd) then
				local key = string.lower(current_cwd)
				seen[key] = true
				table.insert(items, {
					label = basename(current_cwd),
					detail = current_cwd,
					group = "Current",
					icon = "folder-open",
					current = true,
					path = current_cwd,
				})
			end
			if result.status == 0 and result.stdout and result.stdout ~= "" then
				local ok, decoded = pcall(tern.json.decode, result.stdout)
				if ok and type(decoded) == "table" then
					for _, name in ipairs(decoded) do
						if type(name) == "string" and name ~= "" then
							local full = WORKSPACE_ROOT .. "\\" .. name
							local key = string.lower(full)
							if not seen[key] then
								seen[key] = true
								table.insert(items, {
									label = name,
									detail = full,
									group = WORKSPACE_ROOT,
									icon = "folder",
									path = full,
								})
							end
						end
					end
				end
			end
			table.insert(items, {
				label = "Custom folder path...",
				detail = "Enter any absolute folder path",
				group = "Other",
				icon = "folder-plus",
				custom = true,
			})
			fresh:pick({
				placeholder = "Pick a folder for new Pi chat...",
				icon = "folder",
				action = "open Pi chat",
				items = items,
			}):next(function(chosen, _, win)
				if not chosen or not win then return end
				if chosen.custom then
					prompt_custom_pi_folder(win, current_cwd)
					return
				end
				local target = chosen.path
				if type(target) == "string" and target ~= "" then
					win.layout:new_tab({ cwd = target, command = "tern acp pi" })
				end
			end)
		end)
	end,
})

local last_error: string? = nil

local function safe_refresh(cx: WindowCx?)
	if not cx then
		return
	end
	local ok, err = pcall(refresh, cx)
	if not ok and tostring(err) ~= last_error then
		last_error = tostring(err)
		error(err, 0)
	end
end

local function toggle_finished_steps(cx: WindowCx)
	hide_finished_steps = not hide_finished_steps
	safe_refresh(cx)
	tern.chrome.refresh()
	cx:toast("info", if hide_finished_steps then "Finished chat steps hidden automatically" else "Finished chat steps shown")
end

tern.command({
	id = "toggle-chat-steps",
	title = "Pi ACP: Toggle Finished Steps",
	icon = "list",
	run = toggle_finished_steps,
})

tern.chrome.widget("pi-steps", {
	name = "Pi Steps",
	icon = "list",
	render = function(pane: StatusPaneInfo?)
		if not pane or agent_of_pane[pane.pane] ~= "pi" then
			return nil
		end
		local hidden = hide_finished_steps
		return {
			text = "",
			tone = if hidden then "muted" else "accent",
			title = if hidden then "Show Pi finished steps" else "Hide Pi finished steps",
			command = "plugin.agent-tabs.toggle-chat-steps",
			card = {
				{
					id = "steps",
					text = if hidden then "Process steps hidden after reply" else "All process steps visible",
					actions = {
						{ id = "toggle", label = if hidden then "Show steps" else "Hide steps" },
					},
				},
			},
		}
	end,
})

tern.on("widget_action", function(ev: WidgetActionEvent, cx: WindowCx)
	if ev.widget == "pi-steps" and ev.act == "toggle" then
		toggle_finished_steps(cx)
		return true
	end
	return false
end)

local EVENTS = {
	"window_start",
	"focus",
	"tab_created",
	"tab_closed",
	"pane_created",
	"pane_closed",
	"title",
	"cwd",
	"agent_state",
	"agent_finished",
}
for _, ev_name in ipairs(EVENTS) do
	tern.on(ev_name, function(a: any, b: any)
		local cx: WindowCx? = if ev_name == "window_start" then a else b
		if ev_name == "agent_finished" and type(a) == "table" and type(a.pane) == "number" and a.result == "done" and cx then
			local focused = cx.session:focused()
			if focused ~= a.pane then
				unseen_done[a.pane] = true
			end
		elseif ev_name == "agent_state" and type(a) == "table" and type(a.pane) == "number" then
			if a.new == "working" or a.new == "waiting_input" then
				unseen_done[a.pane] = nil
			end
		elseif ev_name == "focus" and type(a) == "table" and type(a.pane) == "number" then
			unseen_done[a.pane] = nil
		end
		safe_refresh(cx)
	end)
end

local function poll(cx: WindowCx?)
	local ok, err = true, nil
	if cx then
		ok, err = pcall(refresh, cx)
	end
	tern.timer(POLL_MS, poll)
	if not ok and tostring(err) ~= last_error then
		last_error = tostring(err)
		error(err, 0)
	end
end

tern.timer(0, poll)
