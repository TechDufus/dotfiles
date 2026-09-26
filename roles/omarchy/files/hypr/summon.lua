-- CapsLock summon leader for Omarchy/Hyprland. Managed by ~/.dotfiles roles/omarchy.
local apps = require("hypr.dotfiles.summon_apps")

local LEADER = "code:66" -- CapsLock keycode; kb_options caps:none makes it a VoidSymbol key.
local SUMMON, MACRO = "summon", "summon_macro"
local TIMEOUT_MS = 2000
local PENDING_SECONDS = 10

local M = {}
local state = { seq = 0, return_to = {}, last = {}, pending = {} }
M._state = state

local function lower(s) return string.lower(s or "") end

local function app_matches(app, win)
  if not win then return false end
  local class, initial = lower(win.class), lower(win.initial_class)
  for _, cls in ipairs(app.classes) do
    local want = lower(cls)
    if class == want or initial == want then return true end
  end
  return false
end

local function find_app(name)
  for _, app in ipairs(apps) do
    if app.name == name then return app end
  end
end

local function app_for_window(win)
  for _, app in ipairs(apps) do
    if app_matches(app, win) then return app end
  end
end

local function is_special(win)
  return win.workspace ~= nil and string.sub(win.workspace.name or "", 1, 8) == "special:"
end

local function exists(address)
  return address ~= nil and hl.get_window("address:" .. address) ~= nil
end

local function focus(address)
  hl.dispatch(hl.dsp.focus({ window = "address:" .. address }))
end

local function move(address, workspace, follow)
  hl.dispatch(hl.dsp.window.move({ window = "address:" .. address, workspace = workspace, follow = follow }))
end

local function app_windows(app)
  local out = {}
  for _, w in ipairs(hl.get_windows({})) do
    if w.mapped and app_matches(app, w) then out[#out + 1] = w end
  end
  return out
end

-- Plasma bestWindow: remembered window, else active output +1000, active workspace +100, not hidden +10, then most recently focused.
local function best_window(app, wins)
  for _, w in ipairs(wins) do
    if w.address == state.last[app.name] then return w end
  end
  local mon, ws = hl.get_active_monitor(), hl.get_active_workspace()
  local best, best_score = nil, -1
  for _, w in ipairs(wins) do
    local score = 0
    if mon and w.monitor and w.monitor.name == mon.name then score = score + 1000 end
    if ws and w.workspace and w.workspace.id == ws.id then score = score + 100 end
    if not is_special(w) then score = score + 10 end
    if score > best_score or (score == best_score and w.focus_history_id < best.focus_history_id) then
      best, best_score = w, score
    end
  end
  return best
end

local function launch(app)
  for _, cmd in ipairs(app.exec) do
    if o.cmd_present(string.match(cmd, "^%S+")) then
      if app.workspace then state.pending[app.name] = os.time() + PENDING_SECONDS end
      hl.exec_cmd(o.launch(cmd))
      return
    end
  end
  hl.exec_cmd(o.notify("Summon: no launcher found for " .. app.name))
end

function M.summon(name)
  local app = find_app(name)
  if not app then return end
  local active = hl.get_active_window()
  if active and app_matches(app, active) then
    local back = state.return_to[app.name]
    if exists(back) then focus(back) end
    return
  end
  if active then state.return_to[app.name] = active.address end
  local wins = app_windows(app)
  if #wins == 0 then
    launch(app)
    return
  end
  local target = best_window(app, wins)
  state.last[app.name] = target.address
  local here = hl.get_active_workspace()
  local on_here = here and target.workspace and target.workspace.id == here.id
  if app.bring and here and not on_here then
    move(target.address, tostring(here.id), false)
  elseif is_special(target) then
    move(target.address, app.workspace or tostring(here.id), false)
  end
  focus(target.address)
end

function M.cycle_same_app()
  local active = hl.get_active_window()
  if not active then return end
  local app = app_for_window(active)
  local wins = {}
  for _, w in ipairs(hl.get_windows({})) do
    local same
    if app then same = app_matches(app, w) else same = (w.class == active.class) end
    if w.mapped and same then wins[#wins + 1] = w end
  end
  if #wins < 2 then return end
  table.sort(wins, function(a, b) return a.stable_id < b.stable_id end)
  for i, w in ipairs(wins) do
    if w.address == active.address then
      local nxt = wins[(i % #wins) + 1]
      if app then state.last[app.name] = nxt.address end
      focus(nxt.address)
      return
    end
  end
end

function M.place_pending(win)
  if not win or not win.address then return end
  local now = os.time()
  for _, app in ipairs(apps) do
    local expires = state.pending[app.name]
    if expires and expires < now then
      state.pending[app.name] = nil
    elseif expires and app_matches(app, win) then
      state.pending[app.name] = nil
      state.last[app.name] = win.address
      move(win.address, app.workspace, true)
      focus(win.address)
      return
    end
  end
end

local function set_submap(name) hl.dispatch(hl.dsp.submap(name)) end

local function arm_timeout()
  state.seq = state.seq + 1
  local seq = state.seq
  hl.timer(function()
    local current = hl.get_current_submap()
    if seq == state.seq and (current == SUMMON or current == MACRO) then set_submap("reset") end
  end, { timeout = TIMEOUT_MS, type = "oneshot" })
end

-- Single universal bind (see Hyprland discussion #14733): idle -> summon -> macro -> idle.
function M.leader()
  local current = hl.get_current_submap()
  if current == SUMMON then
    set_submap(MACRO)
    arm_timeout()
  elseif current == MACRO then
    set_submap("reset")
  else
    set_submap(SUMMON)
    arm_timeout()
  end
end

local function run(fn)
  return function()
    set_submap("reset")
    local ok, err = pcall(fn)
    if not ok then hl.exec_cmd(o.notify("Summon error: " .. tostring(err))) end
  end
end

local function key_spec(key)
  if string.match(key, "^%u$") then return "SHIFT + " .. string.lower(key) end
  return key
end

o.bind(LEADER, "Summon leader (CapsLock)", M.leader, { submap_universal = true })
o.bind("SUPER + H", "Hide window to scratchpad", hl.dsp.window.move({ workspace = "special:scratchpad", follow = false }))

hl.define_submap(SUMMON, function()
  for _, app in ipairs(apps) do
    if app.key then
      o.bind(key_spec(app.key), "Summon " .. app.name, run(function() M.summon(app.name) end))
    end
  end
  hl.bind("escape", hl.dsp.submap("reset"))
end)

hl.define_submap(MACRO, function()
  o.bind("a", "Cycle windows of the active app", run(M.cycle_same_app))
  o.bind("s", "Screenshot region to clipboard", run(function() hl.exec_cmd("omarchy-capture-screenshot region copy") end))
  o.bind("e", "Emoji picker", run(function() hl.exec_cmd("omarchy-shell shell toggle omarchy.emojis") end))
  hl.bind("escape", hl.dsp.submap("reset"))
end)

hl.on("window.open", M.place_pending)
hl.on("window.class", M.place_pending)

_G.dotfiles_summon = M
return M
