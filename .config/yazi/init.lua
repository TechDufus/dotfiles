local function setup_plugin(name, opts)
	local ok, plugin = pcall(require, name)
	if ok then
		pcall(function()
			plugin:setup(opts)
		end)
	end
end

setup_plugin("sshfs", {
	custom_hosts_file = os.getenv("HOME") .. "/.config/yazi/sshfs.list",
	mount_dir = os.getenv("HOME") .. "/SSHFS",
	sshfs_options = {
		"reconnect",
		"ConnectTimeout=5",
		"compression=no",
		"ServerAliveInterval=15",
		"ServerAliveCountMax=3",
		"cache=yes",
		"cache_timeout=5",
		"entry_timeout=5",
		"attr_timeout=5",
		"negative_timeout=1",
	},
})
setup_plugin("zoxide-track")
setup_plugin("autosession-cursor")

function Linemode:size_and_mtime()
	local year = os.date("%Y")
	local time = (self._file.cha.mtime or 0) // 1

	if time > 0 and os.date("%Y", time) == year then
		time = os.date("%b %d %H:%M", time)
	else
		time = time and os.date("%b %d  %Y", time) or ""
	end

	local size = self._file:size()
	return ui.Line(string.format(" %s %s ", size and ya.readable_size(size) or "-", time))
end

Status:children_add(function(self)
	local h = self._current.hovered
	if h and h.link_to then
		return " -> " .. tostring(h.link_to)
	else
		return ""
	end
end, 3300, Status.LEFT)
