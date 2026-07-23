local get_current_session = ya.sync(function()
	local tabs = cx.tabs
	local session = {
		active_idx = tabs.idx,
		tabs = {},
	}

	for idx, tab in ipairs(tabs) do
		session.tabs[idx] = {
			cwd = tostring(tab.current.cwd):gsub("\\", "/"),
			hovered = tab.current.hovered and tostring(tab.current.hovered.url) or nil,
			sort = {
				by = tab.pref.sort_by,
				sensitive = tab.pref.sort_sensitive,
				reverse = tab.pref.sort_reverse,
				dir_first = tab.pref.sort_dir_first,
				translit = tab.pref.sort_translit,
			},
			linemode = tab.pref.linemode,
			show_hidden = tab.pref.show_hidden and "show" or "hide",
		}
	end

	return session
end)

local function session_event(cwd)
	local first, second = 0, 0
	local path = tostring(cwd)

	for index = 1, #path do
		local byte = string.byte(path, index)
		first = (first * 31 + byte) % 2147483647
		second = (second * 131 + byte) % 2147483629
	end

	return string.format("@autosession-cursor-%08x-%08x", first, second)
end

local save_and_quit = ya.sync(function(state)
	ps.pub_to(0, state.event, get_current_session())
	ya.emit("quit", {})
end)

local restore_session = ya.sync(function(state)
	for idx, tab in ipairs(state.session.tabs) do
		if idx == 1 then
			ya.emit("cd", { tab.cwd })
		else
			ya.emit("tab_create", { tab.cwd })
		end
		ya.emit("sort", tab.sort)
		ya.emit("linemode", { tab.linemode })
		ya.emit("hidden", { tab.show_hidden })
		if tab.hovered then
			ya.emit("reveal", { tab.hovered })
		end
	end

	ya.emit("tab_switch", { state.session.active_idx - 1 })
	state.restored = true
end)

return {
	setup = function(state)
		state.restored = false
		state.event = session_event(os.getenv("PWD") or ".")

		ps.sub_remote(state.event, function(session)
			if not state.restored then
				state.session = session
				restore_session()
			end
		end)
	end,

	entry = function(_, job)
		if job.args[1] == "save-and-quit" then
			save_and_quit()
		end
	end,
}
