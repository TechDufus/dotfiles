-- Cells engine tests with stubbed Hyprland (`hl`) and Omarchy (`o`) globals.
-- Run from modules/omarchy: lua5.4 tests/test_cells.lua (mise run test:omarchy does this)
local ROLE = "hypr/"
local CELLS = "lua:cells"

local fx -- fixture state for the current case
local tmp_dirs = {}

local function sh_quote(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end

local function mktemp()
  local p = io.popen("mktemp -d")
  local dir = p:read("l")
  p:close()
  tmp_dirs[#tmp_dirs + 1] = dir
  return dir
end

local function file_exists(path)
  local f = io.open(path, "r")
  if f then f:close() end
  return f ~= nil
end

local function read_file(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local s = f:read("a")
  f:close()
  return s
end

-- Monitors -------------------------------------------------------------------------------------------------

local function builtin_monitor()
  return { name = "eDP-1", x = 0, y = 0, width = 1920, height = 1200, scale = 1, transform = 0,
           reserved = { top = 30, right = 0, bottom = 0, left = 0 }, active_workspace = { id = 1, name = "1" } }
end

local function dp1()
  return { name = "DP-1", x = 1920, y = 0, width = 5120, height = 1440, scale = 1, transform = 0,
           reserved = { top = 30, right = 0, bottom = 0, left = 0 }, active_workspace = { id = 2, name = "2" } }
end

-- Scaled and rotated: 2160x3840 physical px at 1.5 scale, transform 1 -> 2560x1440 logical.
local function dp2_rotated()
  return { name = "DP-2", x = 7040, y = 100, width = 2160, height = 3840, scale = 1.5, transform = 1,
           reserved = { top = 30, right = 0, bottom = 0, left = 0 }, active_workspace = { id = 3, name = "3" } }
end

local function logical_size(mon)
  local w, h = mon.width / mon.scale, mon.height / mon.scale
  if mon.transform % 2 == 1 then w, h = h, w end
  return w, h
end

-- Usable area of a monitor (what Hyprland hands the layout as ctx.area).
local function usable(mon)
  local w, h = logical_size(mon)
  local r = mon.reserved
  return { x = mon.x + r.left, y = mon.y + r.top, w = w - r.left - r.right, h = h - r.top - r.bottom }
end

-- Stubs ----------------------------------------------------------------------------------------------------

hl = {
  dsp = {
    window = {
      float = function(a) return { kind = "float", args = a } end,
      resize = function(a) return { kind = "resize", args = a } end,
      move = function(a) return { kind = "move", args = a } end,
      cycle_next = function(a) return { kind = "cycle_next", args = a } end,
      bring_to_top = function(a) return { kind = "bring_to_top", args = a } end,
      alter_zorder = function(a) return { kind = "alter_zorder", args = a } end,
    },
    focus = function(a) return { kind = "focus", args = a } end,
    layout = function(msg) return { kind = "layout", msg = msg } end,
  },
  dispatch = function(d)
    fx.log[#fx.log + 1] = d
    if d.kind == "layout" and d.msg == "cyclenext" and fx.on_cyclenext then fx.on_cyclenext() end
  end,
  layout = { register = function(name, provider) fx.provider = provider; fx.layout_name = name end },
  config = function(t) fx.config = t end,
  window_rule = function(r) fx.window_rules[#fx.window_rules + 1] = r end,
  workspace_rule = function(r)
    local rule = { spec = r, enabled = true }
    function rule:set_enabled(v)
      self.enabled = v
      self.enabled_calls = (self.enabled_calls or 0) + (v and 1 or 0)
    end
    fx.workspace_rules[#fx.workspace_rules + 1] = rule
    return rule
  end,
  get_monitor_at = function(x, y)
    for _, m in ipairs(fx.monitors) do
      local w, h = logical_size(m)
      if x >= m.x and x < m.x + w and y >= m.y and y < m.y + h then return m end
    end
  end,
  get_monitors = function() return fx.monitors end,
  get_workspaces = function() return fx.workspaces or {} end,
  get_windows = function() return fx.windows end,
  get_workspace_windows = function(id)
    local out = {}
    for _, w in ipairs(fx.windows) do
      if w.workspace and w.workspace.id == id then out[#out + 1] = w end
    end
    return out
  end,
  get_window = function(selector)
    local address = selector:match("^address:(.*)$")
    for _, w in ipairs(fx.windows) do
      if w.address == address then return w end
    end
  end,
  get_active_window = function() return fx.active_window end,
  get_active_workspace = function() return fx.active_workspace end,
  get_active_special_workspace = function() return fx.special_workspace end,
  get_active_monitor = function() return fx.active_monitor end,
  get_config = function(key) return fx.options[key] end,
  exec_scheduled_prop_refresh_immediately = function()
    fx.prop_refreshes = fx.prop_refreshes + 1
    if fx.on_prop_refresh then fx.on_prop_refresh() end
  end,
  timer = function(fn, opts) fx.timers[#fx.timers + 1] = { fn = fn, opts = opts } end,
  on = function(event, fn)
    fx.events[event] = fx.events[event] or {}
    table.insert(fx.events[event], fn)
  end,
  bind = function() end,
  unbind = function(keys)
    fx.unbinds[#fx.unbinds + 1] = keys
    fx.key_ops[#fx.key_ops + 1] = { kind = "unbind", keys = keys }
  end,
  exec_cmd = function(cmd) fx.exec[#fx.exec + 1] = cmd end,
}

o = {
  bind = function(keys, description, handler)
    fx.binds[keys] = { description = description, handler = handler }
    fx.key_ops[#fx.key_ops + 1] = { kind = "bind", keys = keys }
  end,
  notify = function(msg) return "notify: " .. msg end,
  shell_quote = sh_quote,
}

local function window(address, class, extra)
  local w = {
    address = address,
    class = class,
    initial_class = class,
    floating = false,
    mapped = true,
    monitor = dp1(),
    workspace = { id = 1, name = "1", tiled_layout = CELLS },
  }
  for k, v in pairs(extra or {}) do w[k] = v end
  return w
end

-- Load cells.lua with a fresh fixture. opts: monitors, windows, saved (workspace ids with a saved Omarchy
-- layout), layouts (replaces layouts.lua), active_workspace, active_monitor, active_window, special_workspace,
-- state_home / runtime_dir (reuse a previous load's directories to simulate a config reload).
local real_getenv = os.getenv
local function load_cells(opts)
  opts = opts or {}
  local state_home = opts.state_home or mktemp()
  local runtime_dir = opts.runtime_dir or mktemp()
  fx = {
    monitors = opts.monitors or { builtin_monitor(), dp1() },
    windows = opts.windows or {},
    active_workspace = opts.active_workspace,
    active_monitor = opts.active_monitor,
    active_window = opts.active_window,
    special_workspace = opts.special_workspace,
    log = {}, exec = {}, timers = {}, events = {}, binds = {}, unbinds = {}, key_ops = {}, prop_refreshes = 0,
    options = opts.options or {},
    window_rules = {}, workspace_rules = {},
    state_home = state_home,
    runtime_dir = runtime_dir,
  }
  os.getenv = function(name)
    if name == "XDG_RUNTIME_DIR" then return runtime_dir end
    if name == "HYPRLAND_INSTANCE_SIGNATURE" then return "test" end
    return real_getenv(name)
  end
  if opts.saved then
    os.execute("mkdir -p " .. sh_quote(state_home .. "/omarchy/workspace-layouts"))
    for _, id in ipairs(opts.saved) do
      local f = io.open(state_home .. "/omarchy/workspace-layouts/" .. id .. ".lua", "w")
      f:write('hl.workspace_rule({ workspace = "' .. id .. '", layout = "scrolling" })\n')
      f:close()
    end
  end
  for _, name in ipairs({ "registry", "summon_apps", "layouts", "cells" }) do
    package.loaded["hypr.dotfiles." .. name] = nil
  end
  package.loaded["default.hypr.paths"] = nil
  package.preload["default.hypr.paths"] = function() return { state_home = state_home } end
  package.preload["hypr.dotfiles.summon_apps"] = function() return dofile(ROLE .. "summon_apps.lua") end
  package.preload["hypr.dotfiles.registry"] = function() return dofile(ROLE .. "registry.lua") end
  package.preload["hypr.dotfiles.layouts"] = function()
    return opts.layouts or dofile(ROLE .. "layouts.lua")
  end
  return dofile(ROLE .. "cells.lua")
end

-- Test helpers ---------------------------------------------------------------------------------------------

local current_case = "?"

local function fail(msg)
  io.stderr:write("FAIL [" .. current_case .. "]: " .. msg .. "\n")
  os.exit(1)
end

local function eq(actual, expected, what)
  if actual ~= expected then
    fail(what .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
  end
end

local function near(actual, expected, what)
  if type(actual) ~= "number" or math.abs(actual - expected) > 1e-6 then
    fail(what .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
  end
end

local function box_eq(box, x, y, w, h, what)
  if not box then fail(what .. ": no placement") end
  near(box.x, x, what .. " x")
  near(box.y, y, what .. " y")
  near(box.w, w, what .. " w")
  near(box.h, h, what .. " h")
end

local function contains(s, sub) return s:find(sub, 1, true) ~= nil end

local function emit(event, win)
  for _, fn in ipairs(fx.events[event] or {}) do fn(win) end
end

-- Runs the cells layout provider over windows; returns the target list with `.box` set by place().
local function layout_pass(area, wins)
  local targets = {}
  for i, w in ipairs(wins) do
    targets[i] = { window = w, place = function(self, box) self.box = box end }
  end
  fx.provider.recalculate({ area = area, targets = targets })
  return targets
end

local function dispatches(kind)
  local out = {}
  for _, d in ipairs(fx.log) do
    if d.kind == kind then out[#out + 1] = d end
  end
  return out
end

local function notifications()
  local out = {}
  for _, cmd in ipairs(fx.exec) do
    if cmd:sub(1, 8) == "notify: " then out[#out + 1] = cmd:sub(9) end
  end
  return out
end

-- Expect the exact float enable + resize + move dispatch of a snapped window.
local function expect_snap(address, x, y, w, h, what)
  eq(#fx.log, 3, what .. " dispatch count")
  local sel = "address:" .. address
  local f, r, m = fx.log[1], fx.log[2], fx.log[3]
  eq(f.kind, "float", what .. " first dispatch")
  eq(f.args.window, sel, what .. " float target")
  eq(f.args.action, "enable", what .. " float action")
  eq(r.kind, "resize", what .. " second dispatch")
  eq(r.args.window, sel, what .. " resize target")
  eq(r.args.x, w, what .. " resize w")
  eq(r.args.y, h, what .. " resize h")
  eq(m.kind, "move", what .. " third dispatch")
  eq(m.args.window, sel, what .. " move target")
  eq(m.args.x, x, what .. " move x")
  eq(m.args.y, y, what .. " move y")
end

local function workspace_rules_for(id)
  local out = {}
  for _, rule in ipairs(fx.workspace_rules) do
    if rule.spec.workspace == id then out[#out + 1] = rule end
  end
  return out
end

local function case(name, fn)
  current_case = name
  fn()
  for _, cmd in ipairs(fx.exec) do
    if contains(cmd, "Cells error") then fail("engine raised: " .. cmd) end
  end
  print("ok - " .. name)
end

-- Cases ----------------------------------------------------------------------------------------------------

case("builtin screen is monocle: a monocle rule at load and no cell placement", function()
  local M = load_cells()
  local found
  for _, rule in ipairs(workspace_rules_for("m[eDP-1] s[0]")) do found = rule end
  if not found then fail("no regular-workspace monocle rule for eDP-1") end
  eq(found.spec.layout, "monocle", "m[eDP-1] layout")
  eq(#workspace_rules_for("m[DP-1] s[0]"), 0, "DP-1 monocle rules")

  local edp = usable(builtin_monitor())
  local term = window("0xa", "ghostty", { monitor = builtin_monitor() })
  local only = layout_pass(edp, { term })
  box_eq(only[1].box, 0, 30, 1920, 1170, "single window gets the whole area")

  local brave = window("0xb", "brave-browser", { monitor = builtin_monitor() })
  local two = layout_pass(edp, { term, brave })
  box_eq(two[1].box, 0, 30, 960, 1170, "first stacked window")
  box_eq(two[2].box, 960, 30, 960, 1170, "second stacked window")

  local spot = window("0xc", "spotify", { monitor = builtin_monitor(), workspace = { id = 5, name = "5", tiled_layout = CELLS } })
  emit("window.open", spot)
  eq(#fx.log, 0, "window.open dispatches on a monocle screen")
  local mono_ws = window("0xd", "spotify", { monitor = builtin_monitor(), workspace = { id = 5, name = "5", tiled_layout = "monocle" } })
  emit("window.open", mono_ws)
  eq(#fx.log, 0, "window.open dispatches on a monocle workspace")
end)

case("a connected non-builtin monitor uses the standard layout", function()
  local M = load_cells()
  local area = usable(dp1())
  local t = layout_pass(area, { window("0xb", "brave-browser") })
  box_eq(t[1].box, 1920, 30, 2048, 1410, "browser fills the standard browser cell")
  local spot = window("0xs", "spotify")
  emit("window.open", spot)
  eq(#dispatches("float"), 1, "overlay app floats on a standard screen")
end)

case("tiled targets land in their cells regardless of target order", function()
  local M = load_cells()
  local area = usable(dp1())
  local function boxes(order)
    local wins = { terminal = window("0xt", "ghostty"), browser = window("0xb", "brave-browser") }
    local list = {}
    for _, k in ipairs(order) do list[#list + 1] = wins[k] end
    local out = layout_pass(area, list)
    local by = {}
    for i, k in ipairs(order) do by[k] = out[i].box end
    return by
  end
  for _, order in ipairs({ { "terminal", "browser" }, { "browser", "terminal" } }) do
    local by = boxes(order)
    local label = table.concat(order, ",")
    box_eq(by.browser, 1920, 30, 2048, 1410, "browser box (" .. label .. ")")
    box_eq(by.terminal, 3968, 30, 3072, 1410, "terminal box (" .. label .. ")")
  end
end)

case("windows sharing a cell each open over the whole cell", function()
  local M = load_cells()
  local out = layout_pass(usable(dp1()), { window("0xt1", "ghostty"), window("0xb", "brave-browser"), window("0xt2", "foot") })
  box_eq(out[1].box, 3968, 30, 3072, 1410, "first terminal")
  box_eq(out[3].box, 3968, 30, 3072, 1410, "second terminal")
  box_eq(out[2].box, 1920, 30, 2048, 1410, "browser unaffected")
end)

case("a new window opens at its cell box, then floats there on open", function()
  local M = load_cells()
  local area = usable(dp1())
  local browser = window("0xb", "brave-browser")
  local spot = window("0xs", "spotify")
  fx.windows = { browser, spot }
  local out = layout_pass(area, { browser, spot })
  box_eq(out[1].box, 1920, 30, 2048, 1410, "browser opens at its cell")
  box_eq(out[2].box, 2560, 171, 3840, 1128, "overlay box")
  eq(#fx.timers, 0, "no deferred placement before the window opened")
  eq(#fx.log, 0, "layout passes dispatch nothing")

  emit("window.open", spot)
  expect_snap("0xs", 2560, 171, 3840, 1128, "window.open snap")
  eq(#fx.timers, 0, "no timers after open")

  fx.log = {}
  emit("window.open", browser)
  expect_snap("0xb", 1920, 30, 2048, 1410, "browser snaps into its cell on open")
end)

case("floating cells are inset by Hyprland gaps and border like tiles", function()
  local options = { ["general.gaps_in"] = 5, ["general.gaps_out"] = 10, ["general.border_size"] = 2 }
  local M = load_cells({ options = options })
  local function open(address, class)
    fx.log = {}
    emit("window.open", window(address, class))
  end
  open("0xb", "brave-browser")
  expect_snap("0xb", 1932, 42, 2029, 1386, "browser at the left and top edges")
  open("0xt", "ghostty")
  expect_snap("0xt", 3975, 42, 3053, 1386, "terminal at the right and top edges")
  open("0xs", "spotify")
  expect_snap("0xs", 2567, 178, 3826, 1114, "overlay away from every edge")

  load_cells({ options = {
    ["general.gaps_in"] = 5, ["general.border_size"] = 2,
    ["general.gaps_out"] = { top = 20, right = 10, bottom = 10, left = 10 },
  } })
  open("0xb", "brave-browser")
  expect_snap("0xb", 1932, 52, 2029, 1376, "per-side gaps_out")
end)

case("two windows of one app stack in its cell", function()
  local M = load_cells()
  local first, second = window("0xt1", "ghostty"), window("0xt2", "foot")
  fx.windows = { first, second }
  emit("window.open", first)
  expect_snap("0xt1", 3968, 30, 3072, 1410, "first terminal")
  fx.log = {}
  emit("window.open", second)
  expect_snap("0xt2", 3968, 30, 3072, 1410, "second terminal")
  fx.log = {}
  emit("window.close", first)
  eq(#fx.log, 0, "closing one does not resize the other")
end)

case("overlay geometry uses monitor offset, reserved space, scale and transform", function()
  local M = load_cells({ monitors = { builtin_monitor(), dp1(), dp2_rotated() } })
  local spot = window("0xs", "spotify", { monitor = dp2_rotated() })
  emit("window.open", spot)
  -- usable: x 7040, y 130, 2560x1410 -> overlay x+320, y+141, 1920x1128
  expect_snap("0xs", 7360, 271, 1920, 1128, "rotated scaled monitor snap")

  fx.log = {}
  local out = layout_pass(usable(dp2_rotated()), { window("0xb", "brave-browser", { monitor = dp2_rotated() }) })
  box_eq(out[1].box, 7040, 130, 1024, 1410, "browser cell on the rotated monitor")
end)

case("a window that opened floating (dialog) is left alone", function()
  local M = load_cells()
  local dialog = window("0xd", "some-dialog", { floating = true })
  emit("window.open", dialog)
  eq(#fx.log, 0, "dialog dispatches")
  local spot_dialog = window("0xe", "spotify", { floating = true })
  emit("window.open", spot_dialog)
  emit("window.move_to_workspace", spot_dialog)
  eq(#fx.log, 0, "floating overlay-app dispatches")
end)

local function run_timers()
  local pending = fx.timers
  fx.timers = {}
  for _, t in ipairs(pending) do t.fn() end
end

case("floated then tiled again (Super+T) tiles across the area and is not re-floated", function()
  local M = load_cells()
  local area = usable(dp1())
  local browser = window("0xb", "brave-browser")
  local spot = window("0xs", "spotify")
  fx.windows = { browser, spot }
  emit("window.open", spot)
  eq(#dispatches("float"), 1, "initial float")
  fx.log = {}

  spot.floating = false -- the user tiled it again
  local out = layout_pass(area, { browser, spot })
  box_eq(out[1].box, 1920, 30, 2048, 1410, "browser at its cell")
  box_eq(out[2].box, 1920, 30, 5120, 1410, "spotify tiled across the area")

  emit("window.move_to_workspace", spot)
  emit("window.open", spot)
  run_timers()
  eq(#fx.log, 0, "events and deferred placement after tiling again")
  local again = layout_pass(area, { browser, spot })
  box_eq(again[2].box, 1920, 30, 5120, 1410, "still tiled across the area")
  run_timers()
  eq(#fx.log, 0, "deferred placement after another layout pass")
end)

case("a tiled overlay-app window moved onto a cells workspace is floated into its overlay box", function()
  local M = load_cells()
  local files = window("0xn", "org.gnome.Nautilus", { workspace = { id = 3, name = "3", tiled_layout = CELLS } })
  fx.windows = { files }
  emit("window.move_to_workspace", files)
  eq(#fx.log, 0, "nothing is dispatched inside the event")
  emit("window.move_to_workspace", files)
  eq(#fx.timers, 1, "placement is queued once")
  run_timers()
  expect_snap("0xn", 2560, 171, 3840, 1128, "snap after the move")

  -- Moved to a workspace that does not use cells: left alone.
  local other = window("0xo", "org.gnome.Nautilus", { workspace = { id = 6, name = "6", tiled_layout = "dwindle" } })
  fx.windows = { other }
  fx.log = {}
  emit("window.move_to_workspace", other)
  run_timers()
  eq(#fx.log, 0, "non-cells workspace dispatches")
end)

local function home_rule_dirs() return { state_home = fx.state_home, runtime_dir = fx.runtime_dir } end

case("a config reload keeps user-tiled windows tiled and Super+U overrides, and forgets closed windows", function()
  local M = load_cells()
  local area = usable(dp1())
  local spot = window("0xs", "spotify")
  local gone = window("0xgone", "spotify")
  local term = window("0xt", "ghostty")
  fx.windows = { spot, gone, term }
  emit("window.open", spot)
  emit("window.open", gone)
  spot.floating, gone.floating = true, true -- cells floated them
  spot.floating, gone.floating = false, false -- Super+T tiled them again
  layout_pass(area, { spot, gone })
  M.assign("0xt", "standard", 3) -- Super+U: terminal into the overlay cell
  term.floating = true
  local dirs = home_rule_dirs()

  M = load_cells({ windows = { spot, term }, state_home = dirs.state_home, runtime_dir = dirs.runtime_dir })
  local out = layout_pass(area, { spot })
  box_eq(out[1].box, 1920, 30, 5120, 1410, "user-tiled window stays tiled across the area after the reload")
  run_timers()
  eq(#dispatches("float"), 0, "no re-float after the reload")
  for _, d in ipairs(fx.log) do
    if d.args.window == "address:0xs" then fail("user-tiled window touched after the reload") end
  end
  eq(M.cell_for(term, term.monitor, "standard", M.config.layouts.standard), "standard_utility_overlay", "override survives the reload")

  -- A window that no longer exists is forgotten: a new window reusing its address floats normally.
  emit("window.open", window("0xgone", "spotify"))
  eq(#dispatches("float"), 1, "reused address floats like any new window")
end)

case("Super+U choices survive a logout", function()
  local M = load_cells()
  local term = window("0xt", "ghostty")
  fx.windows = { term }
  M.assign("0xt", "standard", 3)
  local state_home = fx.state_home
  eq(file_exists(state_home .. "/dotfiles/cells.lua"), true, "choices file written")

  M = load_cells({ windows = { term }, state_home = state_home, runtime_dir = mktemp() })
  eq(M.cell_for(term, term.monitor, "standard", M.config.layouts.standard), "standard_utility_overlay", "override survives the logout")
  eq(next(M._state.user_tiled), nil, "no window state from the old session")
end)

case("a config reload re-snaps floated windows to the new gaps", function()
  load_cells({ options = { ["general.gaps_in"] = 5, ["general.gaps_out"] = 10, ["general.border_size"] = 2 } })
  local browser = window("0xb", "brave-browser")
  emit("window.open", browser)
  browser.floating = true
  local dirs = { state_home = fx.state_home, runtime_dir = fx.runtime_dir }

  load_cells({
    windows = { browser }, state_home = dirs.state_home, runtime_dir = dirs.runtime_dir,
    options = { ["general.gaps_in"] = 2, ["general.gaps_out"] = 4, ["general.border_size"] = 2 },
  })
  run_timers()
  eq(#fx.log, 2, "already floating: resize and move only")
  eq(fx.log[1].kind, "resize", "first dispatch")
  eq(fx.log[1].args.x, 2038, "resize w")
  eq(fx.log[1].args.y, 1398, "resize h")
  eq(fx.log[2].kind, "move", "second dispatch")
  eq(fx.log[2].args.x, 1926, "move x")
  eq(fx.log[2].args.y, 36, "move y")
end)

case("a window that opened floating and is tiled with Super+T tiles across the area and stays there", function()
  local M = load_cells()
  local area = usable(dp1())
  local spot = window("0xs", "spotify", { floating = true })
  fx.windows = { spot }
  emit("window.open", spot)
  eq(#fx.log, 0, "floating at open")
  spot.floating = false
  local out = layout_pass(area, { spot })
  box_eq(out[1].box, 1920, 30, 5120, 1410, "tiled across the area")
  run_timers()
  layout_pass(area, { spot })
  run_timers()
  eq(#fx.log, 0, "never re-floated")

  -- Same for a window that was already floating when the config loaded.
  local pre = window("0xp", "spotify", { floating = true })
  M = load_cells({ windows = { pre } })
  pre.floating = false
  out = layout_pass(area, { pre })
  box_eq(out[1].box, 1920, 30, 5120, 1410, "tiled across the area after load")
  run_timers()
  eq(#fx.log, 0, "never re-floated after load")
end)

case("grouped windows are left to Hyprland: not floated, not assigned, tiled across the area", function()
  local grouped = window("0xg", "spotify", { group = { "0xg", "0xh" } })
  local browser = window("0xb", "brave-browser")
  local M = load_cells({ active_window = grouped })
  fx.windows = { browser, grouped }
  emit("window.open", grouped)
  emit("window.move_to_workspace", grouped)
  run_timers()
  eq(#fx.log, 0, "events dispatch")
  local out = layout_pass(usable(dp1()), { browser, grouped })
  box_eq(out[1].box, 1920, 30, 2048, 1410, "browser at its cell")
  box_eq(out[2].box, 1920, 30, 5120, 1410, "grouped window tiled across the area")
  eq(#fx.timers, 0, "no deferred placement")
  M.assign("0xg", "standard", 1)
  eq(#fx.log, 0, "assign dispatches")
  eq(M.cell_for(grouped, grouped.monitor, "standard", M.config.layouts.standard), "standard_utility_overlay", "no override stored")
  M.pick()
  eq(#fx.exec, 1, "picker notifies instead of opening")
  if not contains(fx.exec[1], "group") then fail("pick on a grouped window: " .. fx.exec[1]) end
end)

case("undock: overlays cells floated return to tiling off a cells screen", function()
  local M = load_cells()
  local spot = window("0xs", "spotify")
  local other = window("0xo", "spotify", { workspace = { id = 2, name = "2", tiled_layout = CELLS } })
  local native = window("0xn", "spotify", { floating = true, workspace = { id = 1, name = "1", tiled_layout = CELLS } })
  local keeper = window("0xk", "ghostty", { monitor = builtin_monitor() })
  fx.windows = { spot, other, native, keeper }
  emit("window.open", spot)
  emit("window.open", other)
  emit("window.open", native)
  spot.floating, other.floating = true, true
  fx.active_window = keeper
  fx.log = {}

  -- Workspace 1 moves to the laptop panel.
  spot.monitor = builtin_monitor()
  native.monitor = builtin_monitor()
  emit("workspace.move_to_monitor", spot.workspace)
  eq(#fx.log, 0, "nothing dispatched inside the event")
  local poke = workspace_rules_for("name:dotfiles-cells-refresh")
  eq(#poke, 1, "refresh rule registered")
  eq(poke[1].enabled_calls, 1, "refresh rule re-enabled")
  eq(#fx.timers, 1, "only the cells-floated window of that workspace is queued")
  run_timers()
  eq(#fx.log, 2, "dispatch count")
  eq(fx.log[1].kind, "float", "dispatch kind")
  eq(fx.log[1].args.window, "address:0xs", "float target")
  eq(fx.log[1].args.action, "disable", "float action")
  eq(fx.log[2].kind, "focus", "last dispatch hands focus back")
  eq(fx.log[2].args.window, "address:0xk", "focus target is the window active when the event fired")

  -- A cells-floated window whose workspace is no longer a cells workspace tiles too.
  fx.log = {}
  fx.active_window = nil
  other.workspace = { id = 2, name = "2", tiled_layout = "dwindle" }
  emit("window.move_to_workspace", other)
  run_timers()
  eq(#fx.log, 1, "dwindle workspace dispatch count")
  eq(fx.log[1].args.window, "address:0xo", "dwindle float target")
  eq(fx.log[1].args.action, "disable", "dwindle float action")
  run_timers()
  emit("window.move_to_workspace", other)
  run_timers()
  eq(#fx.log, 1, "already tiled: nothing more")
end)

case("a monitor layout change re-places overlays cells floated and leaves app-floated windows alone", function()
  local M = load_cells()
  local spot = window("0xs", "spotify")
  local native = window("0xd", "spotify", { floating = true })
  local keeper = window("0xk", "ghostty")
  fx.windows = { spot, native, keeper }
  emit("window.open", spot)
  emit("window.open", native)
  spot.floating = true
  fx.active_window = keeper
  local moved = dp1()
  moved.x = 0
  spot.monitor, native.monitor = moved, moved
  fx.log = {}
  emit("monitor.layout_changed")
  eq(#fx.log, 0, "nothing dispatched inside the event")
  eq(#fx.timers, 1, "one deferred placement")
  run_timers()
  eq(#fx.log, 3, "resize + move on an already floating window, then focus")
  eq(fx.log[1].kind, "resize", "first dispatch")
  eq(fx.log[1].args.window, "address:0xs", "resize target")
  eq(fx.log[1].args.x, 3840, "resize w")
  eq(fx.log[1].args.y, 1128, "resize h")
  eq(fx.log[2].kind, "move", "second dispatch")
  eq(fx.log[2].args.x, 640, "move x on the new monitor position")
  eq(fx.log[2].args.y, 171, "move y")
  eq(fx.log[3].kind, "focus", "focus handed back")
  eq(fx.log[3].args.window, "address:0xk", "focus target")

  -- The previously focused window closing before the timer fires is not refocused.
  fx.log = {}
  emit("monitor.layout_changed")
  fx.windows = { spot, native }
  run_timers()
  eq(#dispatches("focus"), 0, "no focus for a window that is gone")
  eq(#fx.log, 2, "overlay still re-placed")
end)

case("docked: a classless window cells floated into the default cell still moves home when its class arrives", function()
  local M = load_cells()
  local late = window("0xl", nil)
  local dialog = window("0xd", nil, { floating = true })
  fx.windows = { late, dialog }
  emit("window.open", late)
  expect_snap("0xl", 2560, 171, 3840, 1128, "classless window floats into layout.default")
  emit("window.open", dialog)
  eq(#fx.log, 3, "a window that opened floating is not placed")
  late.floating = true -- cells floated it
  fx.log = {}

  late.class, late.initial_class = "spotify", "spotify"
  emit("window.class", late)
  eq(#fx.log, 1, "dispatch count")
  eq(fx.log[1].kind, "move", "dispatch kind")
  eq(fx.log[1].args.window, "address:0xl", "move target")
  eq(fx.log[1].args.workspace, "5", "home workspace")

  fx.log = {}
  emit("window.class", late)
  eq(#fx.log, 2, "second class event only re-snaps")
  eq(fx.log[1].kind, "resize", "re-snap resize")
  eq(fx.log[2].kind, "move", "re-snap move")
  eq(fx.log[2].args.workspace, nil, "no second workspace move")

  dialog.class, dialog.initial_class = "spotify", "spotify"
  fx.log = {}
  emit("window.class", dialog)
  eq(#fx.log, 0, "a dialog that opened floating stays with its parent")
end)

case("a window whose class arrives late is sent to its app's home workspace once", function()
  local M = load_cells()
  local function panel_window(address, extra)
    local w = window(address, nil, { monitor = builtin_monitor(), workspace = { id = 1, name = "1", tiled_layout = "monocle" } })
    for k, v in pairs(extra or {}) do w[k] = v end
    fx.windows[#fx.windows + 1] = w
    return w
  end
  local function class_arrives(w, class)
    w.class, w.initial_class = class, class
    emit("window.class", w)
  end

  local late = panel_window("0xl")
  emit("window.open", late)
  eq(#fx.log, 0, "nothing to place before the class is known")
  class_arrives(late, "spotify")
  eq(#fx.log, 1, "dispatch count")
  eq(fx.log[1].kind, "move", "dispatch kind")
  eq(fx.log[1].args.window, "address:0xl", "move target")
  eq(fx.log[1].args.workspace, "5", "home workspace")
  fx.log = {}
  emit("window.class", late)
  eq(#fx.log, 0, "a second class event does not move again")

  local home = panel_window("0xh", { workspace = { id = 5, name = "5", tiled_layout = "monocle" } })
  emit("window.open", home)
  class_arrives(home, "spotify")
  local dialog = panel_window("0xd", { floating = true })
  emit("window.open", dialog)
  class_arrives(dialog, "spotify")
  local nohome = panel_window("0xf")
  emit("window.open", nohome)
  class_arrives(nohome, "org.gnome.Nautilus")
  local matched = panel_window("0xm", { class = "spotify", initial_class = "spotify" })
  emit("window.open", matched)
  emit("window.class", matched)
  eq(#fx.log, 0, "already home, floating, no home workspace, or matched at open: left alone")
end)

case("an already-opened tiled overlay-app window gets one deferred float", function()
  local spot = window("0xs", "spotify")
  local M = load_cells({ windows = { spot } })
  local area = usable(dp1())
  local out = layout_pass(area, { spot })
  box_eq(out[1].box, 2560, 171, 3840, 1128, "overlay box")
  eq(#fx.timers, 1, "timer count")
  eq(fx.timers[1].opts.timeout, 1, "timer delay")
  eq(fx.timers[1].opts.type, "oneshot", "timer type")
  eq(#fx.log, 0, "layout pass dispatches")

  layout_pass(area, { spot })
  eq(#fx.timers, 1, "repeat pass does not queue another")

  fx.timers[1].fn()
  expect_snap("0xs", 2560, 171, 3840, 1128, "deferred snap")
end)

case("home workspace rules: one per app with a workspace, case-insensitive class regex, tiled only", function()
  local M = load_cells()
  local apps = dofile(ROLE .. "summon_apps.lua")
  local by_name = {}
  for _, r in ipairs(fx.window_rules) do by_name[r.name] = r end
  local expected = 0
  for _, app in ipairs(apps) do
    local rule = by_name["dotfiles-home-" .. app.name]
    if app.workspace then
      expected = expected + 1
      if not rule then fail("no home rule for " .. app.name) end
      eq(rule.workspace, app.workspace, app.name .. " workspace")
      eq(rule.match.float, false, app.name .. " float match")
      eq(rule.match.title, "negative:(.*is sharing.*|Picture.?in.?[Pp]icture|Meet - .+)", app.name .. " title match")
      local inner = rule.match.class:match("^%(%?i%)%((.*)%)$")
      if not inner then fail(app.name .. " class regex shape: " .. rule.match.class) end
      local got = {}
      -- split on unescaped |
      for alt in (inner .. "|"):gmatch("(.-[^\\])|") do got[#got + 1] = alt:gsub("\\(.)", "%1"):lower() end
      eq(#got, #app.classes, app.name .. " alternatives")
      for i, cls in ipairs(app.classes) do eq(got[i], cls:lower(), app.name .. " class " .. i) end
    elseif rule then
      fail("unexpected home rule for " .. app.name)
    end
  end
  eq(#fx.window_rules, expected, "home rule count")
  eq(by_name["dotfiles-home-terminal"].match.class, "(?i)(com\\.mitchellh\\.ghostty|ghostty|foot)", "terminal regex")
  eq(by_name["dotfiles-home-obsidian"].match.class, "(?i)(md\\.obsidian\\.Obsidian|obsidian)", "obsidian regex")
end)

case("Super+L on a full-screen screen leaves the workspace alone and says so", function()
  local ws = { id = 1, name = "1", tiled_layout = "monocle" }
  local M = load_cells({ active_workspace = ws, active_monitor = builtin_monitor() })
  local base = #workspace_rules_for("1")
  local file = fx.state_home .. "/omarchy/workspace-layouts/1.lua"

  fx.binds["SUPER + L"].handler()
  eq(#workspace_rules_for("1"), base, "no rule registered")
  eq(file_exists(file), false, "no saved layout")
  local notes = notifications()
  eq(#notes, 1, "notification count")
  if not contains(notes[1], "is full screen on this screen") then fail("not explained: " .. notes[1]) end
end)

case("Super+L returning to the screen layout replaces a saved layout Omarchy loaded at startup", function()
  local ws = { id = 1, name = "1", tiled_layout = "scrolling" }
  local M = load_cells({ saved = { "1" }, active_workspace = ws, active_monitor = builtin_monitor() })
  local file = fx.state_home .. "/omarchy/workspace-layouts/1.lua"
  eq(file_exists(file), true, "saved layout present before")
  local base = #workspace_rules_for("1")
  fx.binds["SUPER + L"].handler()
  eq(file_exists(file), false, "saved layout removed")
  local rules = workspace_rules_for("1")
  eq(#rules, base + 1, "rule registered")
  eq(rules[#rules].spec.layout, "monocle", "screen layout rule")

  ws.tiled_layout = "monocle"
  fx.binds["SUPER + L"].handler()
  eq(#workspace_rules_for("1"), base + 1, "a press on full screen adds no rule")
  eq(file_exists(file), false, "and no saved layout")
  local notes = notifications()
  if not contains(notes[#notes], "is full screen") then fail("not explained: " .. notes[#notes]) end
end)

-- Models Hyprland's monocle: one window of the stack is visible (accepts_input); `cyclenext` shows the next one.
local function monocle_stack(count, visible, focused)
  local ws = { id = 1, name = "1", tiled_layout = "monocle", windows = count }
  local wins = {}
  for i = 1, count do
    wins[i] = window("0x" .. i, "ghostty", { monitor = builtin_monitor(), workspace = ws })
  end
  local shown = visible
  local function sync()
    for i, w in ipairs(wins) do w.accepts_input = (i == shown) end
  end
  sync()
  return ws, wins, wins[focused], function() shown = shown % count + 1; sync() end
end

case("entering monocle with Super+L brings the focused window into view", function()
  local ws, wins, focused, advance = monocle_stack(3, 3, 2)
  ws.tiled_layout = "scrolling"
  local M = load_cells({ windows = wins, active_workspace = ws, active_monitor = builtin_monitor(), active_window = focused })
  fx.on_cyclenext = advance
  fx.on_prop_refresh = function() ws.tiled_layout = "monocle" end
  fx.binds["SUPER + L"].handler()
  eq(fx.prop_refreshes, 1, "properties refreshed before aligning")
  eq(#fx.log, 2, "cyclenext dispatches (3 -> 1 -> 2)")
  for i, d in ipairs(fx.log) do
    eq(d.kind, "layout", "dispatch kind " .. i)
    eq(d.msg, "cyclenext", "dispatch msg " .. i)
  end
  eq(focused.accepts_input, true, "focused window is visible")
end)

case("monocle alignment on config.props_refreshed cycles only when the focused window is hidden", function()
  local ws, wins, focused, advance = monocle_stack(3, 3, 1)
  local M = load_cells({ windows = wins, active_workspace = ws, active_monitor = builtin_monitor(), active_window = focused })
  fx.on_cyclenext = advance
  emit("workspace.move_to_monitor", ws)
  eq(#fx.log, 0, "a monitor change dispatches nothing to align")
  eq(#fx.timers, 0, "and schedules no alignment")
  emit("config.props_refreshed")
  eq(#fx.log, 1, "cyclenext dispatches (3 -> 1)")
  eq(fx.log[1].kind, "layout", "dispatch kind")
  eq(fx.log[1].msg, "cyclenext", "dispatch msg")
  eq(focused.accepts_input, true, "focused window is visible")

  fx.log = {}
  emit("config.props_refreshed")
  eq(#fx.log, 0, "already visible: no dispatch")
end)

case("monocle alignment leaves non-monocle workspaces and floating windows alone", function()
  local ws, wins, focused, advance = monocle_stack(3, 3, 1)
  ws.tiled_layout = "dwindle"
  local M = load_cells({ windows = wins, active_workspace = ws, active_monitor = builtin_monitor(), active_window = focused })
  fx.on_cyclenext = advance
  emit("config.props_refreshed")
  eq(#fx.log, 0, "non-monocle workspace")

  ws.tiled_layout = "monocle"
  focused.floating = true
  emit("config.props_refreshed")
  eq(#fx.log, 0, "floating focused window")
end)

case("Super+L on a cells screen goes cells -> monocle and wraps back to cells", function()
  local ws = { id = 2, name = "2", tiled_layout = CELLS }
  local M = load_cells({ active_workspace = ws, active_monitor = dp1() })
  local term = window("0xt", "ghostty", { workspace = ws })
  fx.windows = { term }
  emit("window.open", term)
  term.floating = true -- cells floated it
  local press = fx.binds["SUPER + L"].handler
  local seq = {}
  for i = 1, 4 do
    press()
    local rules = workspace_rules_for("2")
    local last = rules[#rules]
    local saved = read_file(fx.state_home .. "/omarchy/workspace-layouts/2.lua")
    seq[#seq + 1] = saved and last.spec.layout or "cells"
    ws.tiled_layout = saved and last.spec.layout or CELLS
    if i == 1 then
      eq(#fx.timers, 1, "the cells-floated window is queued")
      fx.log = {}
      run_timers()
      eq(fx.log[1].kind, "float", "full screen tiles the window: dispatch kind")
      eq(fx.log[1].args.window, "address:0xt", "float target")
      eq(fx.log[1].args.action, "disable", "float action")
    end
  end
  eq(table.concat(seq, ","), "monocle,cells,monocle,cells", "toggle order")
end)

local NEXT_LAYOUT, RESET_LAYOUT, PICK_LAYOUT =
  "SUPER + CTRL + ALT + SHIFT + code:47", "SUPER + CTRL + ALT + SHIFT + code:48", "SUPER + CTRL + ALT + SHIFT + P"

local function last_rule(selector)
  local rules = workspace_rules_for(selector)
  return rules[#rules]
end

case("Hyper+; cycles the focused screen through the order and re-places its cell windows", function()
  local ws = { id = 2, name = "2", tiled_layout = CELLS }
  local M = load_cells({ active_workspace = ws, active_monitor = dp1() })
  local term = window("0xt", "ghostty")
  fx.windows = { term }
  emit("window.open", term)
  term.floating = true -- cells floated it
  fx.workspaces = { { id = 2, name = "2", monitor = dp1() } }
  local saved = fx.state_home .. "/omarchy/workspace-layouts/2.lua"
  fx.binds["SUPER + L"].handler() -- workspace 2 is now full screen
  eq(last_rule("2").spec.layout, "monocle", "Super+L rule")
  eq(file_exists(saved), true, "Super+L saved layout")
  local press = fx.binds[NEXT_LAYOUT].handler

  fx.log = {}
  press()
  eq(M.layout_for(dp1()), "fourk", "first press")
  local notes = notifications()
  eq(notes[#notes], "DP-1 layout: 4K Workspace", "notification")
  eq(last_rule("2").spec.layout, CELLS, "the Super+L toggle ends")
  eq(file_exists(saved), false, "saved Omarchy layout removed")
  eq(#fx.log, 0, "nothing dispatched inside the call")
  run_timers()
  eq(#fx.log, 2, "re-placed dispatch count")
  eq(fx.log[1].kind, "resize", "resize")
  eq(fx.log[1].args.x, 3328, "resize w")
  eq(fx.log[1].args.y, 1410, "resize h")
  eq(fx.log[2].kind, "move", "move")
  eq(fx.log[2].args.x, 1920, "move x")
  eq(fx.log[2].args.y, 30, "move y")

  press()
  eq(M.layout_for(dp1()), "hd", "second press")
  run_timers()
  fx.log = {}
  press()
  eq(M.layout_for(dp1()), "fullscreen", "third press")
  eq(last_rule("m[DP-1] s[0]").spec.layout, "monocle", "screen rule goes full screen")
  run_timers()
  eq(fx.log[1].kind, "float", "full screen tiles the window: dispatch kind")
  eq(fx.log[1].args.window, "address:0xt", "float target")
  eq(fx.log[1].args.action, "disable", "float action")

  local before = #workspace_rules_for("m[DP-1] s[0]")
  press()
  eq(M.layout_for(dp1()), "standard", "fourth press wraps")
  eq(#workspace_rules_for("m[DP-1] s[0]"), before + 1, "screen rule goes back to cells")
  eq(last_rule("m[DP-1] s[0]").spec.layout, CELLS, "screen rule layout")
end)

case("Hyper+' returns the screen to its default", function()
  local M = load_cells({ active_monitor = dp1() })
  M.choose_layout("DP-1", 2)
  eq(M.layout_for(dp1()), "fourk", "chosen layout")
  fx.binds[RESET_LAYOUT].handler()
  eq(M.layout_for(dp1()), "standard", "default again")
  local notes = notifications()
  eq(notes[#notes], "DP-1 layout: Standard Dev (default)", "notification")
  local choices = dofile(fx.state_home .. "/dotfiles/cells.lua")
  eq(choices.screen_layouts["DP-1"], nil, "choice forgotten")
end)

case("Hyper+P lists layouts in order with the current one marked", function()
  local M = load_cells({ active_monitor = dp1() })
  fx.binds[PICK_LAYOUT].handler()
  eq(#fx.exec, 1, "exec count")
  local cmd = fx.exec[1]
  for _, want in ipairs({
    "omarchy-menu-select", "'Layout for DP-1'", "'1  Standard Dev  (current)'", "'2  4K Workspace'",
    "'3  HD Workspace'", "'4  Fullscreen'", "'0  reset to Standard Dev'", '_G.dotfiles_cells.choose_layout("DP-1", ',
  }) do
    if not contains(cmd, want) then fail("picker missing " .. want .. " in: " .. cmd) end
  end
end)

case("screen layout choices survive a logout, keyed by monitor description", function()
  local M = load_cells({ active_monitor = dp1() })
  M.choose_layout("DP-1", 3)
  M = load_cells({ state_home = fx.state_home, runtime_dir = mktemp() })
  eq(M.layout_for(dp1()), "hd", "choice restored after the logout")

  local panel = builtin_monitor()
  panel.description = "Sharp 0x146A"
  M = load_cells({ monitors = { panel, dp1() } })
  eq(M.layout_for(panel), "fullscreen", "panel default")
  M.set_screen_layout(panel, "standard")
  eq(last_rule("m[eDP-1] s[0]").spec.layout, CELLS, "panel rule follows the choice")
  M = load_cells({ monitors = { panel, dp1() }, state_home = fx.state_home, runtime_dir = mktemp() })
  eq(M.layout_for(panel), "standard", "description-keyed choice restored")
  eq(last_rule("m[eDP-1] s[0]").spec.layout, CELLS, "panel rule after the logout")
  local other = builtin_monitor()
  other.description = "Another 0x1"
  eq(M.layout_for(other), "fullscreen", "another panel keeps the default")
end)

case("lilHyper+O / Hyper+O / Cmd+O / Cmd+Shift+O move the focused window to the next / previous screen into its cell", function()
  local function setup(monitors)
    local term = window("0xt", "ghostty", {
      monitor = builtin_monitor(), workspace = { id = 1, name = "1", tiled_layout = "monocle" },
    })
    local M = load_cells({ monitors = monitors, windows = { term }, active_window = term, active_monitor = builtin_monitor() })
    return term
  end
  local all = function() return { builtin_monitor(), dp1(), dp2_rotated() } end

  for _, pair in ipairs({
    { "SUPER + CTRL + ALT + O", "SUPER + CTRL + ALT + SHIFT + O" },
    { "SUPER + O", "SUPER + SHIFT + O" },
  }) do
    local NEXT, PREV = pair[1], pair[2]
    local term = setup(all())
    -- Omarchy binds both Super keys too and Hyprland fires every bind on a key: they must be unbound first.
    if NEXT == "SUPER + O" then
      for _, keys in ipairs(pair) do
        local unbound, bound
        for i, op in ipairs(fx.key_ops) do
          if op.keys == keys and op.kind == "unbind" then unbound = unbound or i end
          if op.keys == keys and op.kind == "bind" then bound = bound or i end
        end
        if not unbound or not bound or unbound > bound then fail(keys .. " must be unbound before it is bound") end
      end
    end
    fx.binds[NEXT].handler()
    eq(#fx.log, 1, NEXT .. " dispatch count")
    eq(fx.log[1].kind, "move", NEXT .. " dispatch kind")
    eq(fx.log[1].args.window, "address:0xt", NEXT .. " move target")
    eq(fx.log[1].args.workspace, "2", NEXT .. " next screen's workspace")
    eq(fx.log[1].args.follow, true, NEXT .. " focus follows")
    eq(#fx.timers, 1, NEXT .. " placement queued once")
    term.monitor = dp1()
    term.workspace = { id = 2, name = "2", tiled_layout = CELLS }
    fx.log = {}
    run_timers()
    eq(#fx.log, 4, NEXT .. " placement dispatch count")
    eq(fx.log[1].kind, "float", NEXT .. " float first")
    eq(fx.log[1].args.action, "enable", NEXT .. " float action")
    eq(fx.log[2].kind, "resize", NEXT .. " resize")
    eq(fx.log[2].args.x, 3072, NEXT .. " resize w")
    eq(fx.log[2].args.y, 1410, NEXT .. " resize h")
    eq(fx.log[3].kind, "move", NEXT .. " move")
    eq(fx.log[3].args.x, 3968, NEXT .. " move x")
    eq(fx.log[3].args.y, 30, NEXT .. " move y")
    eq(fx.log[4].kind, "alter_zorder", NEXT .. " raised")

    setup(all())
    fx.binds[PREV].handler()
    eq(fx.log[1].args.workspace, "3", PREV .. " previous screen wraps to the last")
    eq(#fx.timers, 1, PREV .. " placement queued")

    setup({ builtin_monitor() })
    fx.binds[NEXT].handler()
    fx.binds[PREV].handler()
    eq(#fx.log, 0, "one screen: no dispatch")
    eq(#fx.timers, 0, "one screen: no placement")
  end
end)

case("moving a window to another screen: a native float keeps its relative box, cells windows snap to their cell, fullscreen only moves", function()
  local NEXT = "SUPER + O"
  local function screens() return { builtin_monitor(), dp1(), dp2_rotated() } end
  local function ws2() return { id = 2, name = "2", tiled_layout = CELLS } end
  -- dp1 usable area: 1920,30 5120x1410; dp2 (rotated, scaled) usable area: 7040,130 2560x1410.
  local dialog = window("0xd", "some-dialog", { floating = true, workspace = ws2(),
    at = { x = 1920 + 512, y = 30 + 705 }, size = { x = 2560, y = 705 } })
  local M = load_cells({ monitors = screens(), windows = { dialog }, active_window = dialog, active_monitor = dp1() })
  emit("window.open", dialog)
  fx.log = {}
  fx.binds[NEXT].handler()
  eq(#fx.log, 1, "dispatch count before the tick")
  eq(fx.log[1].kind, "move", "workspace move")
  eq(fx.log[1].args.workspace, "3", "next screen's workspace")
  dialog.monitor, dialog.workspace = dp2_rotated(), { id = 3, name = "3", tiled_layout = CELLS }
  fx.log = {}
  run_timers()
  eq(#fx.log, 2, "relative placement dispatch count")
  eq(fx.log[1].kind, "resize", "resize first")
  eq(fx.log[1].args.window, "address:0xd", "resize target")
  eq(fx.log[1].args.x, 1280, "width keeps half the screen")
  eq(fx.log[1].args.y, 705, "height keeps half the screen")
  eq(fx.log[2].kind, "move", "then move")
  eq(fx.log[2].args.x, 7040 + 256, "x keeps its relative offset")
  eq(fx.log[2].args.y, 130 + 705, "y keeps its relative offset")
  eq(#dispatches("float"), 0, "a native float stays a native float")

  local term = window("0xt", "ghostty", { workspace = ws2(), floating = false,
    at = { x = 0, y = 0 }, size = { x = 100, y = 100 } })
  M = load_cells({ monitors = screens(), windows = { term }, active_window = term, active_monitor = dp1() })
  emit("window.open", term)
  term.floating = true -- cells floated it
  fx.log = {}
  fx.timers = {}
  fx.binds[NEXT].handler()
  term.monitor, term.workspace = dp2_rotated(), { id = 3, name = "3", tiled_layout = CELLS }
  fx.log = {}
  run_timers()
  eq(fx.log[1].kind, "resize", "cells window resize")
  eq(fx.log[1].args.x, 1536, "cells window takes its cell on the new screen: w")
  eq(fx.log[1].args.y, 1410, "cells window cell h")
  eq(fx.log[2].kind, "move", "cells window move")
  eq(fx.log[2].args.x, 7040 + 1024, "cells window cell x")
  eq(fx.log[2].args.y, 130, "cells window cell y")

  local full = window("0xf", "ghostty", { workspace = ws2(), fullscreen = 2 })
  M = load_cells({ monitors = screens(), windows = { full }, active_window = full, active_monitor = dp1() })
  fx.binds[NEXT].handler()
  eq(#fx.log, 1, "fullscreen window: only the workspace move")
  eq(#fx.timers, 0, "fullscreen window: no placement")
end)

case("Super+O takes a window you tiled (Super+T) back into its cell on the other screen", function()
  local spot = window("0xs", "spotify")
  local M = load_cells({ monitors = { builtin_monitor(), dp1(), dp2_rotated() }, windows = { spot },
    active_window = spot, active_monitor = dp1() })
  emit("window.open", spot) -- cells floats it
  spot.floating = false -- the user tiled it again
  layout_pass(usable(dp1()), { spot })
  eq(M._state.user_tiled["0xs"], true, "tiled by the user")
  fx.log = {}

  fx.binds["SUPER + O"].handler()
  eq(fx.log[1].args.workspace, "3", "next screen's workspace")
  eq(M._state.user_tiled["0xs"], nil, "the move opts back into cells")
  spot.monitor, spot.workspace = dp2_rotated(), { id = 3, name = "3", tiled_layout = CELLS }
  -- dp2 usable area 7040,130 2560x1410: spotify's standard cell is the utility overlay.
  local out = layout_pass(usable(dp2_rotated()), { spot })
  box_eq(out[1].box, 7360, 271, 1920, 1128, "opens over its cell, not across the area")
  fx.log = {}
  run_timers()
  local raise = table.remove(fx.log) -- it followed the move, so it is focused and comes to the top
  eq(raise.kind, "alter_zorder", "focused window raised")
  expect_snap("0xs", 7360, 271, 1920, 1128, "snapped into its cell")
end)

case("Super+U choices are per screen: two screens on one layout keep separate cells and each survives a reload", function()
  local function screens()
    local a, b = dp1(), dp2_rotated()
    a.description, b.description = "Vendor A 0x1", "Vendor B 0x2"
    return { a, b }
  end
  local on_a = window("0xa", "ghostty", { monitor = screens()[1] })
  local on_b = window("0xb", "ghostty", { monitor = screens()[2], workspace = { id = 3, name = "3", tiled_layout = CELLS } })
  local standard = function(M) return M.config.layouts.standard end
  local M = load_cells({ monitors = screens(), windows = { on_a, on_b } })

  M.assign("0xa", "standard", 3) -- overlay on A only
  eq(M.cell_for(on_a, on_a.monitor, "standard", standard(M)), "standard_utility_overlay", "A override")
  eq(M.cell_for(on_b, on_b.monitor, "standard", standard(M)), "standard_terminal_right", "B keeps the configured cell")

  fx.log = {}
  M.assign("0xb", "standard", 1) -- browser cell on B
  eq(fx.log[2].args.x, 1024, "B snaps into its own cell: w")
  eq(fx.log[3].args.x, 7040, "B cell x")
  eq(fx.log[3].args.y, 130, "B cell y")
  eq(M.cell_for(on_a, on_a.monitor, "standard", standard(M)), "standard_utility_overlay", "A untouched by B's choice")

  M = load_cells({ monitors = screens(), windows = { on_a, on_b }, state_home = fx.state_home, runtime_dir = mktemp() })
  eq(M.cell_for(on_a, on_a.monitor, "standard", standard(M)), "standard_utility_overlay", "A survives the reload")
  eq(M.cell_for(on_b, on_b.monitor, "standard", standard(M)), "standard_browser_left", "B survives the reload")

  M.assign("0xa", "standard", 0) -- A back to its configured cell
  eq(M.cell_for(on_a, on_a.monitor, "standard", standard(M)), "standard_terminal_right", "A reset")
  eq(M.cell_for(on_b, on_b.monitor, "standard", standard(M)), "standard_browser_left", "B keeps its choice")
  M = load_cells({ monitors = screens(), windows = { on_a, on_b }, state_home = fx.state_home, runtime_dir = mktemp() })
  eq(M.cell_for(on_a, on_a.monitor, "standard", standard(M)), "standard_terminal_right", "A reset survives the reload")
end)

case("a choices file from before per-screen overrides loads without error and its overrides are ignored", function()
  local M = load_cells()
  local dir = fx.state_home .. "/dotfiles"
  os.execute("mkdir -p " .. sh_quote(dir))
  local f = io.open(dir .. "/cells.lua", "w")
  f:write('return { overrides = { standard = { terminal = "standard_utility_overlay" } },'
    .. ' screen_layouts = { ["DP-1"] = "hd" } }')
  f:close()

  local term = window("0xt", "ghostty")
  M = load_cells({ windows = { term }, state_home = fx.state_home, runtime_dir = mktemp() })
  eq(M.cell_for(term, term.monitor, "standard", M.config.layouts.standard), "standard_terminal_right",
    "the old layout -> app override is not applied to any screen")
  eq(M.layout_for(dp1()), "hd", "screen layouts still restore")
  eq(next(M._state.overrides), nil, "nothing kept from the old shape")
end)

case("screens match by description prefix: the HP side screen is full screen, other screens standard", function()
  local hp, acer, lookalike = dp1(), dp2_rotated(), dp2_rotated()
  hp.description = "HP Inc. HP P224 CNK0000001"
  acer.description = "Acer Technologies VG281K 0x00000001"
  lookalike.description = "HP IncX HP P224 CNK0000001" -- would match "HP Inc. HP P224" as a pattern
  local M = load_cells({ monitors = { hp, acer } })
  eq(M.layout_for(hp), "fullscreen", "HP layout")
  eq(M.layout_for(acer), "standard", "Acer layout")
  eq(M.layout_for(lookalike), "standard", "the prefix is plain text, not a pattern")
  local rule = last_rule("m[DP-1] s[0]")
  eq(rule and rule.spec.layout, "monocle", "HP workspace rule")
  eq(last_rule("m[DP-2] s[0]"), nil, "Acer keeps the default cells rule")

  local other = dp1()
  other.description = "Rebrand HP Inc. HP P224 CNK0000001"
  eq(M.layout_for(other), "standard", "the description must start with the prefix")

  local sibling = dp1() -- another unit of the same model
  sibling.description = "HP Inc. HP P224 CNK0000000"
  eq(M.layout_for(sibling), "fullscreen", "any unit of the model")
end)

case("a fullscreen window is left alone by placement and lands in its cell when it leaves fullscreen", function()
  local term = window("0xt", "ghostty", { fullscreen = 2 })
  local M = load_cells({ windows = { term } })
  M.place(term)
  eq(#fx.log, 0, "fullscreen window dispatches")

  term.fullscreen = 1
  emit("window.fullscreen", term)
  eq(#fx.timers, 0, "no placement while it is still maximized")
  term.fullscreen = 2
  emit("window.fullscreen", term)
  eq(#fx.timers, 0, "no placement while it is fullscreen")

  term.fullscreen = 0
  emit("window.fullscreen", term)
  eq(#fx.timers, 1, "placement queued on leaving fullscreen")
  run_timers()
  expect_snap("0xt", 3968, 30, 3072, 1410, "cell after leaving fullscreen")
end)

case("Super+U assign snaps a floated window into the chosen cell and raises it when focused", function()
  local M = load_cells()
  local spot = window("0xs", "spotify")
  fx.windows = { spot }
  emit("window.open", spot)
  spot.floating = true -- cells floated it
  fx.active_window = spot
  fx.log = {}

  M.assign("0xs", "standard", 1)
  eq(#fx.log, 3, "dispatch count")
  eq(fx.log[1].kind, "resize", "first dispatch")
  eq(fx.log[1].args.window, "address:0xs", "resize target")
  eq(fx.log[1].args.x, 2048, "resize w")
  eq(fx.log[1].args.y, 1410, "resize h")
  eq(fx.log[2].kind, "move", "second dispatch")
  eq(fx.log[2].args.x, 1920, "move x")
  eq(fx.log[2].args.y, 30, "move y")
  eq(fx.log[3].kind, "alter_zorder", "third dispatch")
  eq(fx.log[3].args.window, "address:0xs", "raise target")
  eq(fx.log[3].args.mode, "top", "raise mode")
end)

case("Super+U assign: tiled window into a cell snaps it; index 0 restores the configured cell", function()
  local M = load_cells()
  local term = window("0xt", "ghostty")
  fx.windows = { term }
  local layout = M.config.layouts.standard

  M.assign("0xt", "standard", 3)
  expect_snap("0xt", 2560, 171, 3840, 1128, "snap into the overlay cell")
  eq(M.cell_for(term, term.monitor, "standard", layout), "standard_utility_overlay", "override cell")

  term.floating = true
  fx.log = {}
  M.assign("0xt", "standard", 0)
  eq(M.cell_for(term, term.monitor, "standard", layout), "standard_terminal_right", "configured cell restored")
  eq(#fx.log, 2, "dispatch count")
  eq(fx.log[1].kind, "resize", "first dispatch")
  eq(fx.log[1].args.x, 3072, "resize w")
  eq(fx.log[1].args.y, 1410, "resize h")
  eq(fx.log[2].kind, "move", "second dispatch")
  eq(fx.log[2].args.x, 3968, "move x")
  eq(fx.log[2].args.y, 30, "move y")
end)

case("Super+U pick offers the layout's cells with the current one marked", function()
  local term = window("0xt", "ghostty")
  local M = load_cells({ active_window = term })
  M.pick()
  eq(#fx.exec, 1, "exec count")
  local cmd = fx.exec[1]
  if not contains(cmd, "omarchy-menu-select") then fail("picker not launched: " .. cmd) end
  for _, want in ipairs({ "'1  browser left'", "'2  terminal right  (current)'", "'3  utility overlay'", "'0  reset to terminal right'" }) do
    if not contains(cmd, want) then fail("picker missing " .. want .. " in: " .. cmd) end
  end
  if not contains(cmd, "0xt") or not contains(cmd, "standard") then fail("callback lacks address/layout: " .. cmd) end
end)

case("Alt+Tab walks every window of a monocle workspace, otherwise cycles and raises", function()
  local ws, wins = monocle_stack(3, 1, 1)
  local M = load_cells({ windows = wins, active_workspace = ws, active_monitor = builtin_monitor() })
  local function press(keys, active)
    fx.active_window = active
    fx.log = {}
    fx.binds[keys].handler()
  end
  local function expect_focus_raise(address, what)
    eq(#fx.log, 2, what .. " dispatch count")
    eq(fx.log[1].kind, "focus", what .. " first dispatch")
    eq(fx.log[1].args.window, "address:" .. address, what .. " target")
    eq(fx.log[2].kind, "bring_to_top", what .. " raise")
  end

  press("ALT + TAB", wins[1]); expect_focus_raise("0x2", "forward")
  press("ALT + TAB", wins[3]); expect_focus_raise("0x1", "forward wraps")
  press("ALT + SHIFT + TAB", wins[2]); expect_focus_raise("0x1", "backward")
  press("ALT + SHIFT + TAB", wins[1]); expect_focus_raise("0x3", "backward wraps")

  wins[2].hidden = true
  press("ALT + TAB", wins[1]); expect_focus_raise("0x3", "hidden window skipped")
  wins[2].hidden = false
  wins[2].mapped = false
  press("ALT + SHIFT + TAB", wins[3]); expect_focus_raise("0x1", "unmapped window skipped")
  wins[2].mapped = true

  wins[1].floating = true
  press("ALT + TAB", wins[1]); expect_focus_raise("0x2", "floating window on monocle")
  wins[1].floating = false

  wins[2].hidden, wins[3].hidden = true, true
  press("ALT + TAB", wins[1])
  eq(#fx.log, 0, "a lone window has nothing to switch to")

  local plain = window("0xc", "ghostty")
  press("ALT + TAB", plain)
  eq(#fx.log, 2, "plain dispatch count")
  eq(fx.log[1].kind, "cycle_next", "plain cycle")
  eq(fx.log[1].args.tiled, nil, "plain cycle is not tiled-only")
  eq(fx.log[1].args.next, true, "plain cycle forward")
  eq(fx.log[2].kind, "bring_to_top", "raise")

  press("ALT + SHIFT + TAB", plain)
  eq(fx.log[1].args.next, false, "plain backward")
  eq(fx.log[2].kind, "bring_to_top", "raise after backward")

  press("ALT + TAB", nil)
  eq(fx.log[1].kind, "cycle_next", "no active window still cycles")
end)

case("Alt+Tab on monocle skips inactive group tabs and floats that cannot take focus", function()
  local ws, wins = monocle_stack(4, 1, 1)
  local M = load_cells({ windows = wins, active_workspace = ws, active_monitor = builtin_monitor() })
  local function press(keys, active)
    fx.active_window = active
    fx.log = {}
    fx.binds[keys].handler()
  end
  local function expect_focus(address, what)
    eq(#fx.log, 2, what .. " dispatch count")
    eq(fx.log[1].kind, "focus", what .. " first dispatch")
    eq(fx.log[1].args.window, "address:" .. address, what .. " target")
    eq(fx.log[2].kind, "bring_to_top", what .. " raise")
  end

  wins[2].group = { current = { address = "0x4" } } -- a hidden tab of a group showing 0x4
  wins[3].floating, wins[3].accepts_input = true, false -- a float Hyprland will not focus
  wins[4].group = { current = wins[4] }
  press("ALT + TAB", wins[1]); expect_focus("0x4", "forward skips the inactive tab and the unfocusable float")
  press("ALT + SHIFT + TAB", wins[1]); expect_focus("0x4", "backward skips them too")
  press("ALT + TAB", wins[4]); expect_focus("0x1", "forward wraps over them")

  wins[3].accepts_input = true
  press("ALT + TAB", wins[1]); expect_focus("0x3", "a focusable float is kept")
end)

case("a persisted Super+U override naming a removed region is dropped on reload", function()
  local function standard(extra_region)
    local regions = {
      left = { x = 0, y = 0, w = 0.4, h = 1 },
      right = { x = 0.4, y = 0, w = 0.6, h = 1 },
      over = { x = 0.1, y = 0.1, w = 0.5, h = 0.5 },
    }
    local cells = { "left", "right", "over" }
    if extra_region then
      regions.extra = { x = 0.2, y = 0.2, w = 0.2, h = 0.2 }
      cells[#cells + 1] = "extra"
    end
    return {
      regions = regions,
      layouts = { std = { cells = cells, default = "over", apps = { terminal = "right" } } },
      order = { "std" },
      screens = { { layout = "std" } },
    }
  end
  local term = window("0xt", "ghostty")
  local M = load_cells({ windows = { term }, layouts = standard(true) })
  M.assign("0xt", "std", 4) -- Super+U: terminal into "extra"
  eq(M.cell_for(term, term.monitor, "std", M.config.layouts.std), "extra", "override applied")
  local dirs = home_rule_dirs()

  -- Same layouts: the override survives.
  M = load_cells({ windows = { term }, layouts = standard(true), state_home = dirs.state_home, runtime_dir = dirs.runtime_dir })
  eq(M.cell_for(term, term.monitor, "std", M.config.layouts.std), "extra", "override survives a reload")

  -- "extra" removed from the config: the stale override is dropped.
  M = load_cells({ windows = { term }, layouts = standard(false), state_home = dirs.state_home, runtime_dir = dirs.runtime_dir })
  eq(M.cell_for(term, term.monitor, "std", M.config.layouts.std), "right", "falls back to the configured cell")
  fx.log = {}
  term.floating = true
  M.place(term)
  eq(#fx.log, 2, "dispatch count")
  eq(fx.log[1].kind, "resize", "first dispatch")
  eq(fx.log[1].args.x, 3072, "resize w")
  eq(fx.log[1].args.y, 1410, "resize h")
  eq(fx.log[2].kind, "move", "second dispatch")
  eq(fx.log[2].args.x, 3968, "terminal lands in its configured cell x")
  eq(fx.log[2].args.y, 30, "move y")
end)

case("Super+J toggles the split only on dwindle workspaces", function()
  local ws = { id = 1, name = "1", tiled_layout = "dwindle" }
  local M = load_cells({ active_workspace = ws, active_monitor = dp1() })
  local press = fx.binds["SUPER + J"].handler

  press()
  eq(#fx.log, 1, "dwindle dispatch count")
  eq(fx.log[1].kind, "layout", "dwindle dispatch kind")
  eq(fx.log[1].msg, "togglesplit", "dwindle dispatch msg")

  for _, layout in ipairs({ "monocle", CELLS, "scrolling" }) do
    ws.tiled_layout = layout
    fx.log = {}
    press()
    eq(#fx.log, 0, layout .. " dispatches")
  end
end)

case("layout messages follow the open special workspace", function()
  local ws = { id = 1, name = "1", tiled_layout = "dwindle" }
  local special = { id = -98, name = "special:scratchpad", special = true, tiled_layout = "monocle" }
  local M = load_cells({ active_workspace = ws, special_workspace = special, active_monitor = dp1() })
  local press = fx.binds["SUPER + J"].handler

  press()
  eq(#fx.log, 0, "monocle special workspace over dwindle: no togglesplit")

  special.tiled_layout = "dwindle"
  ws.tiled_layout = "monocle"
  press()
  eq(#fx.log, 1, "dwindle special workspace over monocle: togglesplit")
  eq(fx.log[1].msg, "togglesplit", "dispatch msg")
end)

case("validate: unknown regions and layouts notify; the shipped config does not", function()
  load_cells()
  eq(#notifications(), 0, "shipped config notifications")

  load_cells({ layouts = {
    regions = { left = { x = 0, y = 0, w = 1, h = 1 } },
    layouts = { bad = { cells = { "left" }, default = "missing", apps = {} } },
    order = { "bad" },
    screens = { { layout = "bad" }, { layout = "nope" } },
  } })
  local notes = notifications()
  eq(#notes, 1, "unknown-region notifications")
  if not contains(notes[1], "unknown region missing") then fail("unknown region not reported: " .. notes[1]) end
  if not contains(notes[1], "unknown layout nope") then fail("unknown layout not reported: " .. notes[1]) end

  load_cells({ layouts = {
    regions = { left = { x = 0, y = 0, w = 1, h = 1 } },
    layouts = {
      bad = { cells = { "left" }, default = "left", apps = {} },
      other = { cells = { "left" }, default = "left", apps = {} },
    },
    order = { "bad", "ghost", "bad" },
    screens = { { layout = "bad" } },
  } })
  notes = notifications()
  eq(#notes, 1, "order notifications")
  if not contains(notes[1], "order[2]: unknown layout ghost") then fail("unknown order entry not reported: " .. notes[1]) end
  if not contains(notes[1], "order: bad listed twice") then fail("duplicate not reported: " .. notes[1]) end
  if not contains(notes[1], "order: layout other missing") then fail("missing layout not reported: " .. notes[1]) end
end)

for _, dir in ipairs(tmp_dirs) do os.execute("rm -rf " .. sh_quote(dir)) end
print("all cells tests passed")
