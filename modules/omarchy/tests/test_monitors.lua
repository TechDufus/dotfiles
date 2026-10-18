-- Desk monitor config tests with stubbed Hyprland (`hl`) and EDID reads (`io.popen`).
-- Run from modules/omarchy: lua5.4 tests/test_monitors.lua (mise run test:omarchy does this)
local real_popen = io.popen

-- Descriptions shaped like the desk's panels (made-up serials); Hyprland matches a `desc:` selector as a prefix.
local MAIN_DESC = "Acer Technologies VG281K 0x00000001"
local SIDE_DESC = "HP Inc. HP P224 CNK0000001"

-- EDID blobs: binary, with the model name in an ASCII descriptor.
local function edid(model) return "\0\255\255\255\255\255\255\0" .. string.rep("\0", 40) .. "\252\0" .. model .. "\n" .. string.rep("\0", 30) end
local EDIDS = {
  main = edid("VG281K"),
  side = edid("HP P224"),
  laptop = edid("NE160QDM-NZ2"),
}

local fx -- stubs and recorded calls for the current case

local function load_config(connected)
  fx = { monitors = {}, config = {}, rules = {}, handlers = {} }
  fx.connected = connected
  hl = {
    monitor = function(spec) fx.monitors[#fx.monitors + 1] = spec end,
    config = function(tbl) fx.config = tbl end,
    workspace_rule = function(spec) fx.rules[#fx.rules + 1] = spec end,
    on = function(event, fn) fx.handlers[event] = fn end,
  }
  io.popen = function()
    local blob = table.concat(fx.connected, "")
    return { read = function() return blob end, close = function() return true end }
  end
  dofile("hypr/monitors.lua")
end

local function fail(msg)
  io.popen = real_popen
  io.stderr:write("FAIL: " .. msg .. "\n")
  os.exit(1)
end

local function expect(cond, msg) if not cond then fail(msg) end end

-- A selector as Hyprland resolves it: `desc:` + prefix of the monitor description.
local function selector_matches(selector, description)
  local prefix = selector:match("^desc:(.+)$")
  return prefix ~= nil and description:sub(1, #prefix) == prefix
end

local function rules_by_workspace()
  local by = {}
  for _, rule in ipairs(fx.rules) do
    expect(by[rule.workspace] == nil, "workspace " .. rule.workspace .. " bound twice")
    by[rule.workspace] = rule
  end
  return by
end

-- Desk connected at load -----------------------------------------------------------------------------------

do
  load_config({ EDIDS.laptop, EDIDS.side, EDIDS.main })
  local by = rules_by_workspace()

  expect(next(by) ~= nil, "no workspace bindings with the desk connected")
  local defaults = {}
  for ws, rule in pairs(by) do
    local on_main = selector_matches(rule.monitor, MAIN_DESC)
    local on_side = selector_matches(rule.monitor, SIDE_DESC)
    expect(on_main ~= on_side, "workspace " .. ws .. " not bound to exactly one desk screen: " .. tostring(rule.monitor))
    if rule.default then defaults[rule.monitor] = (defaults[rule.monitor] or 0) + 1 end
  end
  for selector, n in pairs(defaults) do expect(n == 1, n .. " default workspaces on " .. selector) end
  local main_selector, side_selector
  for _, rule in pairs(by) do
    if selector_matches(rule.monitor, MAIN_DESC) then main_selector = rule.monitor else side_selector = rule.monitor end
  end
  expect(defaults[main_selector] == 1 and defaults[side_selector] == 1, "each desk screen needs one default workspace")
  expect(by["1"] and by["1"].default and by["1"].monitor == main_selector, "workspace 1 must be the main screen's default")
  expect(selector_matches(fx.config.cursor.default_monitor, MAIN_DESC), "login cursor must start on the main screen")
  for _, spec in ipairs(fx.monitors) do
    expect(selector_matches(spec.output, MAIN_DESC) or selector_matches(spec.output, SIDE_DESC),
      "monitor rule outside the desk screens: " .. tostring(spec.output))
  end
end

-- Not the desk: bindings would strand a laptop on workspace 6 -----------------------------------------------

for name, connected in pairs({
  laptop_only = { EDIDS.laptop },
  main_only = { EDIDS.laptop, EDIDS.main },
  side_only = { EDIDS.side },
  nothing = {},
}) do
  load_config(connected)
  expect(#fx.rules == 0, name .. ": workspace rules declared without both desk screens")
end

-- Desk completing after login -------------------------------------------------------------------------------

do
  load_config({ EDIDS.laptop, EDIDS.main })
  expect(#fx.rules == 0, "rules declared before the second desk screen appeared")
  expect(fx.handlers["monitor.added"], "no monitor.added handler to catch a late desk")

  fx.handlers["monitor.added"]({ name = "DP-1", description = SIDE_DESC })
  expect(#fx.rules == 0, "rules declared while the side screen is still not connected")

  fx.connected = { EDIDS.laptop, EDIDS.main, EDIDS.side }
  fx.handlers["monitor.added"]({ name = "DP-1", description = SIDE_DESC })
  local declared = #fx.rules
  expect(declared > 0, "late desk got no workspace bindings")

  fx.handlers["monitor.added"]({ name = "HDMI-A-1", description = MAIN_DESC })
  expect(#fx.rules == declared, "repeated monitor.added declared the bindings again")
end

io.popen = real_popen
print("all monitors tests passed")
