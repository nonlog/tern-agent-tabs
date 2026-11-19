--!strict
-- Agent Tab Marks (agent-tabs)
--
-- 1. Agent tab icons: 28 coding agent SVG marks (herdr-radar set + droid) rendered crisply at
--    full size (16px, transparent background, no dark card/mask) on both vertical sidebar and
--    horizontal tab rows, without affecting ordinary shell tabs.
-- 2. ACP tab session titles: replaces raw program-path titles (e.g. pwsh.exe) on ACP/agent tabs
--    with "<Agent> · <session title>" (from ACP surface title or first user prompt, falling back
--    to "<Agent> · <folder>" for brand-new sessions) and refreshes chrome automatically.
-- 3. Vertical-sidebar top bar: when vertical sidebar tabs are enabled (html.tabs-v), shows the
--    active tab's agent icon, title, and current/total tab count centered in #tabbar .tb-sp.

local POLL_MS = 1500
local SESSION_TITLE_MAX_CHARS = 28

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
	droid = { display = "Droid", color = "#ef6f2e" },
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

-- UTF-8 safe truncation by Unicode codepoints.
local function utf8_truncate(s: string, max_chars: number): string
	local count = 0
	local byte_pos = 1
	local len = #s
	while byte_pos <= len do
		local b = string.byte(s, byte_pos)
		local char_len = 1
		if b >= 240 then
			char_len = 4
		elseif b >= 224 then
			char_len = 3
		elseif b >= 192 then
			char_len = 2
		end
		count += 1
		if count > max_chars then
			return string.sub(s, 1, byte_pos - 1) .. "\226\128\166"
		end
		byte_pos += char_len
	end
	return s
end

-- Clean a raw user prompt / session title into a compact single-line tab label.
local function clean_session_summary(raw: string): string?
	local s = string.gsub(raw, "[\r\n\t]+", " ")
	-- Strip leading Windows or Unix file paths (e.g. pasted clipboard images) and [Image #N] markers
	while true do
		local next_s = string.gsub(s, "^%s*[A-Za-z]:[/\\][^%s]+%s*", "")
		next_s = string.gsub(next_s, "^%s*/[^%s]+%s*", "")
		next_s = string.gsub(next_s, "^%s*%[Image #%d+%]%s*", "")
		if next_s == s then
			break
		end
		s = next_s
	end
	s = string.gsub(s, "%s+", " ")
	s = string.match(s, "^%s*(.-)%s*$") or ""
	if s == "" then
		return nil
	end
	return utf8_truncate(s, SESSION_TITLE_MAX_CHARS)
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

-- Extract a readable session title for an ACP/agent pane from its TSP surface:
-- 1) surface.title if it carries a real session title (not just the bare agent name)
-- 2) first omp.user message text in surface.main
local function extract_acp_session_title(cx: WindowCx, pane_id: number, agent_key: string): string?
	local ok, tree = pcall(function()
		return cx.session:surface(pane_id, { depth = 2, nodes = 16, max_chars = 600 })
	end)
	if not ok or type(tree) ~= "table" then
		return nil
	end

	local spec = AGENTS[agent_key]
	local display_lower = string.lower(if spec then spec.display else agent_key)
	local sf = (tree :: any).surface
	if type(sf) == "table" and type(sf.title) == "string" and sf.title ~= "" then
		local sf_lower = string.lower(sf.title)
		if sf_lower ~= display_lower and sf_lower ~= agent_key and not from_program(sf.title) then
			local cleaned = clean_session_summary(sf.title)
			if cleaned then
				return cleaned
			end
		end
	end

	local main_node = (tree :: any).main
	if type(main_node) == "table" and type(main_node.c) == "table" then
		for _, child in ipairs(main_node.c) do
			if type(child) == "table" and type(child.p) == "table" and child.p.role == "omp.user" then
				if type(child.c) == "table" then
					for _, sub in ipairs(child.c) do
						if type(sub) == "table" and type(sub.p) == "table" and type(sub.p.text) == "string" and sub.p.text ~= "" then
							local cleaned = clean_session_summary(sub.p.text)
							if cleaned then
								return cleaned
							end
						end
					end
				end
			end
		end
	end
	return nil
end

local function format_agent_title(agent_key: string, session_title: string?, cwd: string?): string
	local spec = AGENTS[agent_key]
	local label = if spec then spec.display else agent_key
	if session_title and session_title ~= "" then
		return label .. " \194\183 " .. session_title
	end
	local folder = if cwd and cwd ~= "" then basename(cwd) else nil
	if folder and folder ~= "" then
		return label .. " \194\183 " .. folder
	end
	return label
end

-- Shared state read by tern.chrome.tab_title formatter.
local agent_of_pane: { [number]: string } = {}
local session_title_of_pane: { [number]: string } = {}
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
		return format_agent_title(agent, session_title_of_pane[tab.pane], tab.cwd)
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

local function refresh(cx: WindowCx)
	-- 1. Collect ACP / registered agents from cx.agents:list().
	local acp_agents: { [number]: string } = {}
	for _, info in ipairs(cx.agents:list()) do
		local key = match_command(info.command)
		if key then
			acp_agents[info.pane] = key
		end
	end

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

	-- Prune stale cached ACP session titles for closed panes.
	for pane_id in pairs(session_title_of_pane) do
		if not next_agent_of_pane[pane_id] then
			session_title_of_pane[pane_id] = nil
		end
	end

	-- 3. Identify active tab & current session.
	local focused_pane = cx.session:focused()
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
	local icon_rules: { string } = {}
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

		if agent and agent_pane and (not tab.name or tab.name == "") and from_program(tab.title) then
			local st = session_title_of_pane[agent_pane]
			if not st and acp_agents[agent_pane] then
				st = extract_acp_session_title(cx, agent_pane, agent)
				if st then
					session_title_of_pane[agent_pane] = st
				end
			end
			local formatted = format_agent_title(agent, st, tab.cwd)
			next_title_of_tab[tab.id] = formatted
			table.insert(title_sig_parts, tostring(tab.id) .. "=" .. formatted)
		end

		if tab.session == current_session then
			session_tab_count += 1
			if agent then
				local rule = build_icon_rule(tab.position, agent)
				if rule ~= "" then
					table.insert(icon_rules, rule)
				end
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

	local icon_css = table.concat(icon_rules, "\n")
	if icon_css ~= installed_icon_css then
		tern.css("icons", icon_css)
		installed_icon_css = icon_css
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
}
for _, ev_name in ipairs(EVENTS) do
	tern.on(ev_name, function(a: any, b: any)
		local cx: WindowCx? = if ev_name == "window_start" then a else b
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
