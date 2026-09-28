-- Summon engine tests with stubbed Hyprland (`hl`) and Omarchy (`o`) globals.
-- Run from the repo root: lua5.4 roles/omarchy/tests/test_summon.lua
local ROLE = "roles/omarchy/files/hypr/"

local fx -- fixture state for the current case

local function window(address, class, workspace_id, focus_history_id, extra)
  local w = {
    address = address,
    class = class,
    initial_class = class,
    mapped = true,
    monitor = { name = "eDP-1" },
    workspace = { id = workspace_id, name = tostring(workspace_id) },
    focus_history_id = focus_history_id,
    stable_id = focus_history_id,
  }
  for k, v in pairs(extra or {}) do w[k] = v end
  return w
end

local function find_window(address)
  for _, w in ipairs(fx.windows) do
    if w.address == address then return w end
  end
end

hl = {
  dsp = {
    focus = function(args) return { kind = "focus", args = args } end,
    submap = function(name) return { kind = "submap", name = name } end,
    window = {
      move = function(args) return { kind = "move", args = args } end,
    },
    send_key_state = function(args) return { kind = "key", args = args } end,
  },
  dispatch = function(d)
    fx.log[#fx.log + 1] = d
    if d.kind == "submap" then fx.submap = (d.name == "reset") and "" or d.name end
  end,
  get_windows = function() return fx.windows end,
  get_window = function(selector)
    return find_window(string.match(selector, "^address:(.*)$"))
  end,
  get_active_window = function() return fx.active end,
  get_active_monitor = function() return fx.monitor end,
  get_active_workspace = function() return fx.workspace end,
  get_current_submap = function() return fx.submap end,
  exec_cmd = function(cmd) fx.exec[#fx.exec + 1] = cmd end,
  timer = function(fn, opts) fx.timers[#fx.timers + 1] = { fn = fn, opts = opts } end,
  on = function(event, fn) fx.events[#fx.events + 1] = { event = event, fn = fn } end,
  bind = function(keys, handler, opts)
    fx.binds[#fx.binds + 1] = { keys = keys, handler = handler, opts = opts or {}, submap = fx.defining }
  end,
  define_submap = function(name, fn)
    fx.defining = name
    fn()
    fx.defining = nil
  end,
}

o = {
  bind = function(keys, description, dispatcher, options)
    local opts = options or {}
    opts.description = description
    hl.bind(keys, dispatcher, opts)
  end,
  cmd_present = function(cmd) return fx.present[cmd] == true end,
  launch = function(cmd) return "uwsm-app -- " .. cmd end,
  notify = function(msg) return "notify: " .. msg end,
}

local function fresh_engine(setup)
  fx = {
    windows = {},
    active = nil,
    monitor = { name = "eDP-1" },
    workspace = { id = 1, name = "1" },
    submap = "",
    present = {},
    log = {},
    exec = {},
    timers = {},
    events = {},
    binds = {},
    defining = nil,
  }
  if setup then setup(fx) end
  package.loaded["hypr.dotfiles.summon_apps"] = nil
  package.preload["hypr.dotfiles.summon_apps"] = function()
    return dofile(ROLE .. "summon_apps.lua")
  end
  return dofile(ROLE .. "summon.lua")
end

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

local function last_dispatch()
  return fx.log[#fx.log]
end

local function expect_focus(d, address, what)
  if not d or d.kind ~= "focus" then fail(what .. ": expected a focus dispatch") end
  eq(d.args.window, "address:" .. address, what)
end

local function expect_move(d, address, workspace, follow, what)
  if not d or d.kind ~= "move" then fail(what .. ": expected a move dispatch") end
  eq(d.args.window, "address:" .. address, what .. " window")
  eq(d.args.workspace, workspace, what .. " workspace")
  eq(d.args.follow, follow, what .. " follow")
end

local function find_bind(keys, submap)
  for _, b in ipairs(fx.binds) do
    if b.keys == keys and b.submap == submap then return b end
  end
end

local function case(name, fn)
  current_case = name
  fn()
  print("ok - " .. name)
end

local brave = window("0xb", "brave-browser", 1, 0)
local foot_old = window("0xf3", "foot", 1, 3)
local foot_recent = window("0xf1", "foot", 1, 1)

local M -- engine shared by cases 1 and 2 (toggle back relies on state from case 1)

case("focus most recent terminal on the active workspace", function()
  M = fresh_engine(function(f)
    f.windows = { brave, foot_old, foot_recent }
    f.active = brave
  end)
  M.summon("terminal")
  expect_focus(last_dispatch(), "0xf1", "focused window")
  eq(M._state.return_to.terminal, "0xb", "return_to.terminal")
end)

case("summoning the active app toggles back", function()
  fx.active = foot_recent
  fx.log = {}
  M.summon("terminal")
  expect_focus(last_dispatch(), "0xb", "focused window")
end)

case("launch fallback when no window exists", function()
  M = fresh_engine(function(f)
    f.windows = { brave }
    f.active = brave
    f.present = { ["xdg-terminal-exec"] = true }
  end)
  M.summon("terminal")
  eq(#fx.exec, 1, "exec count")
  eq(fx.exec[1], "uwsm-app -- xdg-terminal-exec", "exec command")
  if not M._state.pending.terminal then fail("pending.terminal not set") end
end)

case("summon-launched window moves to its home workspace", function()
  local new_foot = window("0xnew", "foot", 7, 0)
  fx.windows[#fx.windows + 1] = new_foot
  M.place_pending(new_foot)
  eq(#fx.log, 2, "dispatch count")
  expect_move(fx.log[1], "0xnew", "1", true, "placement move")
  expect_focus(fx.log[2], "0xnew", "placement focus")
  eq(M._state.pending.terminal, nil, "pending.terminal")
end)

case("bring moves the window to the current workspace", function()
  local files = window("0xn", "org.gnome.Nautilus", 3, 2)
  M = fresh_engine(function(f)
    f.windows = { brave, files }
    f.active = brave
  end)
  M.summon("files")
  eq(#fx.log, 2, "dispatch count")
  expect_move(fx.log[1], "0xn", "1", false, "bring move")
  expect_focus(fx.log[2], "0xn", "bring focus")
end)

case("leader cycles idle -> summon -> macro -> summon (Hammerspoon parity)", function()
  M = fresh_engine()
  local leader = find_bind("code:66", nil)
  if not leader then fail("code:66 leader not bound") end
  eq(leader.opts.submap_universal, true, "submap_universal")
  local seen = {}
  for _ = 1, 3 do
    leader.handler()
    seen[#seen + 1] = fx.submap
  end
  eq(table.concat(seen, ","), "summon,summon_macro,summon", "submap sequence")
  eq(fx.timers[#fx.timers].opts.timeout, 1000, "leader timeout ms")
end)

case("uppercase key binds as SHIFT + letter", function()
  M = fresh_engine()
  if not find_bind("SHIFT + c", "summon") then fail("SHIFT + c not bound in summon submap") end
  if not find_bind("SHIFT + o", "summon") then fail("SHIFT + o not bound in summon submap") end
end)

-- macOS-only Hammerspoon targets with no Omarchy equivalent.
local MACOS_ONLY = { G = "Grok Bot", h = "Screen Sharing", w = "AWS WorkSpaces" }

case("summon keys match the Hammerspoon registry", function()
  M = fresh_engine()
  local hs_apps = dofile("roles/hammerspoon/files/config/apps.lua")
  local hs_keys = {}
  for name, app in pairs(hs_apps) do
    hs_keys[app.summon] = name
    if not MACOS_ONLY[app.summon] then
      local spec = string.match(app.summon, "^%u$") and ("SHIFT + " .. string.lower(app.summon)) or app.summon
      if not find_bind(spec, "summon") then fail("Hammerspoon " .. name .. " key " .. app.summon .. " not bound") end
    end
  end
  for _, app in ipairs(dofile(ROLE .. "summon_apps.lua")) do
    if app.key and not hs_keys[app.key] then fail("summon key " .. app.key .. " (" .. app.name .. ") not in Hammerspoon") end
  end
end)

case("macro keys match the Hammerspoon macro modal", function()
  M = fresh_engine()
  for _, key in ipairs({ "a", "s", "e", "b", "t", "g", "escape", "CTRL + c" }) do
    if not find_bind(key, "summon_macro") then fail("macro key " .. key .. " not bound") end
  end
  for _, key in ipairs({ "escape", "CTRL + c" }) do
    if not find_bind(key, "summon") then fail("summon cancel key " .. key .. " not bound") end
  end
end)

case("browser macro focuses the browser, then sends the chord", function()
  M = fresh_engine(function(f)
    f.windows = { window("0xb", "brave-browser", 2, 1), window("0xf1", "foot", 1, 0) }
    f.active = f.windows[2]
  end)
  M.browser_shortcut("CTRL SHIFT", "A")
  expect_focus(last_dispatch(), "0xb", "browser focus")
  local t = fx.timers[#fx.timers]
  eq(t.opts.timeout, 150, "chord delay")
  t.fn()
  local d = last_dispatch()
  eq(d.kind, "key", "chord dispatch")
  eq(d.args.mods, "CTRL SHIFT", "chord mods")
  eq(d.args.key, "A", "chord key")
  eq(d.args.state, "down", "chord state")
end)

case("browser macro only launches when no browser is open", function()
  M = fresh_engine(function(f) f.present = { ["omarchy-launch-browser"] = true } end)
  M.browser_shortcut("CTRL SHIFT", "O")
  eq(fx.exec[1], "uwsm-app -- omarchy-launch-browser", "browser launch")
  eq(#fx.timers, 0, "no chord timer")
end)

print("all summon tests passed")
