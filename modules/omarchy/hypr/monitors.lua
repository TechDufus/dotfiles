-- This desk's screens. Managed by ~/.dotfiles modules/omarchy.
-- desc: selectors follow the panels to any port and match nothing on other machines. This file loads after
-- ~/.config/hypr/monitors.lua and Hyprland uses the last matching rule, so change the arrangement here
-- (Omarchy's monitor-scaling keys only last until the next reload for these panels).
-- model: the name in the panel's EDID, used to spot the desk before Hyprland has added its monitors.
local MAIN = { desc = "desc:Acer Technologies VG281K", model = "VG281K" } -- 4K, scale 1.5 = 2560x1440 logical
local SIDE = { desc = "desc:HP Inc. HP P224", model = "HP P224" } -- 1080p, left of MAIN, top-aligned

hl.monitor({ output = SIDE.desc, mode = "preferred", position = "0x0", scale = 1 })
hl.monitor({ output = MAIN.desc, mode = "preferred", position = "1920x0", scale = 1.5 })

-- Login puts the cursor, and so focus, on the main screen.
hl.config({ cursor = { default_monitor = MAIN.desc } })

-- Home workspaces of summon_apps.lua, each pinned to a desk monitor. Bound only while both desk
-- monitors are connected: Hyprland skips workspaces bound to another monitor when it picks a screen's first
-- workspace, so unconditional bindings would start a laptop on workspace 6.
local BINDINGS = {
  { workspace = "1", monitor = MAIN.desc, default = true },
  { workspace = "2", monitor = MAIN.desc },
  { workspace = "3", monitor = MAIN.desc },
  { workspace = "4", monitor = SIDE.desc, default = true },
  { workspace = "5", monitor = SIDE.desc },
}

-- Hyprland adds monitors after loading the config, so hl.get_monitors() is still empty here; connected outputs'
-- EDIDs are read from the kernel instead.
local function desk_connected()
  local pipe = io.popen("cat /sys/class/drm/card*-*/edid 2>/dev/null")
  if not pipe then return false end
  local edids = pipe:read("a") or ""
  pipe:close()
  return edids:find(MAIN.model, 1, true) ~= nil and edids:find(SIDE.model, 1, true) ~= nil
end

local bound = false
local function bind_workspaces()
  if bound or not desk_connected() then return end
  bound = true
  for _, rule in ipairs(BINDINGS) do hl.workspace_rule(rule) end
end

bind_workspaces()
-- A desk that powers on after login still gets its bindings.
hl.on("monitor.added", bind_workspaces)
