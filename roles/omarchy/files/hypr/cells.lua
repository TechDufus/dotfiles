-- Cells: deterministic window placement on top of Omarchy's Hyprland. Managed by ~/.dotfiles roles/omarchy.
-- Ports the Hammerspoon/Plasma model: every app has a home workspace (summon_apps.lua) and, in each screen
-- layout (layouts.lua), a cell. Tiled cells are the "lua:cells" tiling layout, floating cells are overlays
-- placed when a window opens, and monocle screens (the laptop panel) use Hyprland's monocle layout.
local registry = require("hypr.dotfiles.registry")
local config = require("hypr.dotfiles.layouts")
local paths = require("default.hypr.paths")

local CELLS, MONOCLE = "lua:cells", "monocle"
local ALTERNATES = { MONOCLE, "dwindle", "scrolling" } -- Super+L cycles a screen's own layout through these
-- What Super+L's notification calls each layout.
local LABELS = { [CELLS] = "cells", [MONOCLE] = "full screen", dwindle = "tiles", scrolling = "columns" }
-- Monitors appear after the config loads, so laptop panels get their monocle rule up front. Rules made here
-- precede Omarchy's saved per-workspace layouts (default/hypr/toggles.lua loads later), so those still win.
local BUILTIN_OUTPUTS = { "eDP-1", "eDP-2", "LVDS-1", "DSI-1" }
local SAVED_LAYOUTS = paths.state_home .. "/omarchy/workspace-layouts"
-- Window state survives config reloads (theme switches, toggles) but not the Hyprland session.
local STATE_FILE = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/dotfiles-cells-"
  .. (os.getenv("HYPRLAND_INSTANCE_SIGNATURE") or "session") .. ".lua"
-- Browser windows Omarchy hides or pins by title (apps/browser.lua, apps/pip.lua) keep their own placement.
local NOT_OMARCHY_EXTRAS = "negative:(.*is sharing.*|Picture.?in.?[Pp]icture|Meet - .+)"

local M = { config = config }
local state = {
  opened = {},        -- address -> true: window.open already ran (or the window predates this config)
  floated = {},       -- address -> true: cells floated it into a floating cell
  native_float = {},  -- address -> true: it opened floating on its own (dialogs, Omarchy's floats)
  user_tiled = {},    -- address -> true: you tiled it after it floated (Super+T); it lives in layout.tile
  unmatched = {},     -- address -> true: opened without a registry class (it may arrive later)
  queued = {},        -- address -> true: placement deferred out of a layout pass or event
  overrides = {},     -- layout key -> app key -> region (Super+U)
  monocle_rules = {}, -- output -> workspace rule
}
M._state = state

local function notify(msg) hl.exec_cmd(o.notify(msg)) end

local function guarded(fn)
  return function(...)
    local ok, err = pcall(fn, ...)
    if not ok then notify("Cells error: " .. tostring(err)) end
  end
end

local function round(n) return math.floor(n + 0.5) end

local function serialize(v)
  if type(v) == "table" then
    local parts = {}
    for k, x in pairs(v) do parts[#parts + 1] = "[" .. string.format("%q", k) .. "]=" .. serialize(x) end
    return "{" .. table.concat(parts, ",") .. "}"
  end
  if type(v) == "string" then return string.format("%q", v) end
  return tostring(v)
end

local function save()
  local file = io.open(STATE_FILE, "w")
  if not file then return end
  file:write("return " .. serialize({ floated = state.floated, user_tiled = state.user_tiled, overrides = state.overrides }))
  file:close()
end

local function is_builtin(mon)
  local name = mon and mon.name or ""
  return name:find("^eDP") ~= nil or name:find("^LVDS") ~= nil or name:find("^DSI") ~= nil
end

-- Layout key and table for a monitor: the first matching `screens` entry.
function M.layout_for(mon)
  for _, screen in ipairs(config.screens) do
    local by_name = screen.name == nil or (mon ~= nil and screen.name == mon.name)
    local by_panel = screen.builtin == nil or screen.builtin == is_builtin(mon)
    if by_name and by_panel then return screen.layout, config.layouts[screen.layout] end
  end
end

local function monocle_screen(mon)
  local _, layout = M.layout_for(mon)
  return layout ~= nil and layout.monocle == true
end

-- Layout messages go to the open special workspace if there is one, else the active workspace.
local function current_workspace()
  return hl.get_active_special_workspace() or hl.get_active_workspace()
end

local function app_key(win)
  local app = registry.for_window(win)
  if app then return app.name, app end
  return "class:" .. string.lower(win.class or ""), nil
end

-- Region name for a window: Super+U override, else the layout's cell for its app, else layout.default.
function M.cell_for(win, key, layout)
  local id, app = app_key(win)
  local override = state.overrides[key] and state.overrides[key][id]
  if override and config.regions[override] then return override end
  return (app and layout.apps and layout.apps[app.name]) or layout.default
end

local function scaled(area, r)
  return { x = area.x + area.w * r.x, y = area.y + area.h * r.y, w = area.w * r.w, h = area.h * r.h }
end

-- Windows sharing a cell split it evenly along its longer side, in layout order.
local function slice(box, i, n)
  if box.w >= box.h then
    local w = box.w / n
    return { x = box.x + w * (i - 1), y = box.y, w = w, h = box.h }
  end
  local h = box.h / n
  return { x = box.x, y = box.y + h * (i - 1), w = box.w, h = h }
end

-- Monitor area minus reserved space (Waybar), in global logical pixels.
local function usable_area(mon)
  local scale = (mon.scale or 0) > 0 and mon.scale or 1
  local w, h = mon.width / scale, mon.height / scale
  if (mon.transform or 0) % 2 == 1 then w, h = h, w end
  local r = mon.reserved or {}
  local top, right, bottom, left = r.top or 0, r.right or 0, r.bottom or 0, r.left or 0
  return { x = mon.x + left, y = mon.y + top, w = w - left - right, h = h - top - bottom }
end

local function snap(win, region)
  local box = scaled(usable_area(win.monitor), region)
  local sel = "address:" .. win.address
  state.floated[win.address] = true
  state.user_tiled[win.address] = nil
  save()
  if not win.floating then hl.dispatch(hl.dsp.window.float({ window = sel, action = "enable" })) end
  hl.dispatch(hl.dsp.window.resize({ window = sel, x = round(box.w), y = round(box.h) }))
  hl.dispatch(hl.dsp.window.move({ window = sel, x = round(box.x), y = round(box.y) }))
end

local function unfloat(address)
  state.floated[address] = nil
  save()
  hl.dispatch(hl.dsp.window.float({ window = "address:" .. address, action = "disable" }))
end

-- Put a window into its cell. On a cells workspace, floating cells get float + exact geometry and a window cells
-- floated whose cell is now tiled goes back to tiling. Anywhere else (the laptop panel after undocking, a dwindle
-- workspace), a window cells floated goes back to tiling. Grouped windows, windows that opened floating (dialogs,
-- Omarchy's own floats) and windows you tiled yourself (Super+T) are left alone.
function M.place(win)
  if not win or not win.address or not win.workspace or win.group then return end
  local address = win.address
  local key, layout = M.layout_for(win.monitor)
  if win.workspace.tiled_layout ~= CELLS or not layout or layout.monocle then
    if win.floating and state.floated[address] then unfloat(address) end
    return
  end
  local region = config.regions[M.cell_for(win, key, layout)]
  if not region then return end
  if region.float then
    if state.user_tiled[address] or (win.floating and not state.floated[address]) then return end
    snap(win, region)
  elseif win.floating and state.floated[address] then
    unfloat(address)
  end
end

-- Layout passes must not dispatch, and Hyprland positions a moved window after its event fires, so those
-- placements run on the next tick.
local function place_later(address)
  if state.queued[address] then return end
  state.queued[address] = true
  hl.timer(guarded(function()
    state.queued[address] = nil
    M.place(hl.get_window("address:" .. address))
  end), { timeout = 1, type = "oneshot" })
end

-- Re-place windows cells floated after their screen changed, then give focus back: un-floating them into a
-- monocle stack makes the last one visible and input-blocks (unfocuses) the window you were using.
local function replace_floated(addresses)
  if #addresses == 0 then return end
  local focused = hl.get_active_window()
  local keep = focused and focused.address
  hl.timer(guarded(function()
    for _, address in ipairs(addresses) do M.place(hl.get_window("address:" .. address)) end
    if keep and hl.get_window("address:" .. keep) then hl.dispatch(hl.dsp.focus({ window = "address:" .. keep })) end
  end), { timeout = 1, type = "oneshot" })
end

local function recalculate(ctx)
  local area, targets = ctx.area, ctx.targets
  local mon = hl.get_monitor_at(area.x + area.w / 2, area.y + area.h / 2) or hl.get_active_monitor()
  local key, layout = M.layout_for(mon)
  if not layout or layout.monocle then
    for i, target in ipairs(targets) do target:place(slice(area, i, #targets)) end
    return
  end
  local buckets, order = {}, {}
  for _, target in ipairs(targets) do
    local win = target.window
    local name = layout.tile
    if win then
      name = M.cell_for(win, key, layout)
      local region = config.regions[name]
      if region and region.float then
        local address = win.address
        if win.group then
          name = layout.tile -- floating a group target would float every window in it
        else
          if state.floated[address] or state.native_float[address] then
            -- It floated (cells or the app itself) and you tiled it (Super+T): it stays tiled, in layout.tile.
            state.floated[address], state.native_float[address] = nil, nil
            state.user_tiled[address] = true
            save()
          end
          if state.user_tiled[address] then
            name = layout.tile
          else
            -- Floats next (window.open, or the deferred pass); open it over its overlay so tiled cells never reflow.
            target:place(scaled(area, region))
            if state.opened[address] then place_later(address) end
            name = nil
          end
        end
      end
    end
    if name then
      local list = buckets[name]
      if not list then
        list = {}
        buckets[name] = list
        order[#order + 1] = name
      end
      list[#list + 1] = target
    end
  end
  for _, name in ipairs(order) do
    local region = config.regions[name]
    local cell = region and scaled(area, region) or area
    local list = buckets[name]
    for i, target in ipairs(list) do target:place(slice(cell, i, #list)) end
  end
end

-- Hyprland's monocle shows the last window handed to it when a workspace switches into it (Super+L, a reload,
-- a monitor change), not the focused one; step the stack until the focused window is the visible one.
local function align_monocle()
  local win, ws = hl.get_active_window(), current_workspace()
  if not win or win.floating or not ws or ws.tiled_layout ~= MONOCLE or not win.workspace or win.workspace.id ~= ws.id then
    return
  end
  for _ = 1, ws.windows do
    local current = hl.get_window("address:" .. win.address)
    if not current or current.accepts_input then return end
    hl.dispatch(hl.dsp.layout("cyclenext"))
  end
end

-- Re-enabling a workspace rule makes Hyprland re-pick every workspace's layout and re-run the visible ones.
-- Hyprland only does that itself when a workspace or rule changes, not when a workspace changes monitor.
local function relayout()
  state.poke = state.poke or hl.workspace_rule({ workspace = "name:dotfiles-cells-refresh" })
  state.poke:set_enabled(true)
end

-- Re-run the cells layout on a tiled window's workspace after its cell changed.
local function refresh(win)
  if not win or win.floating or not win.workspace or win.workspace.tiled_layout ~= CELLS then return end
  local ws = current_workspace()
  if ws and ws.id == win.workspace.id then
    hl.dispatch(hl.dsp.layout("refresh"))
  else
    relayout()
  end
end

-- Regular workspaces only: the scratchpad keeps splitting on the laptop panel.
local function ensure_monocle(output)
  if state.monocle_rules[output] then return end
  state.monocle_rules[output] = hl.workspace_rule({ workspace = "m[" .. output .. "] s[0]", layout = MONOCLE })
end

local function saved_layout(id) return SAVED_LAYOUTS .. "/" .. id .. ".lua" end

-- Super+L: the screen's own layout (cells or monocle) -> monocle/dwindle/scrolling -> back. Alternates persist
-- in Omarchy's format, so default/hypr/workspace-layouts.lua restores them after a reload. Hyprland merges
-- rules that share a selector, so this only sets the layout of the workspace's rule (until the next reload it
-- keeps that layout even if the workspace changes screens).
function M.cycle_layout()
  local ws = hl.get_active_workspace()
  if not ws or ws.special then return end
  local own = monocle_screen(hl.get_active_monitor()) and MONOCLE or CELLS
  local order = { own }
  for _, name in ipairs(ALTERNATES) do
    if name ~= own then order[#order + 1] = name end
  end
  local next_layout = order[1]
  for i, name in ipairs(order) do
    if name == ws.tiled_layout then
      next_layout = order[i % #order + 1]
      break
    end
  end
  local id = tostring(ws.id)
  hl.workspace_rule({ workspace = id, layout = next_layout })
  if next_layout == own then
    os.remove(saved_layout(id))
  else
    os.execute("mkdir -p " .. o.shell_quote(SAVED_LAYOUTS))
    local file = io.open(saved_layout(id), "w")
    if file then
      file:write(string.format('hl.workspace_rule({ workspace = "%s", layout = "%s" })\n', id, next_layout))
      file:close()
    end
  end
  hl.exec_scheduled_prop_refresh_immediately()
  align_monocle()
  notify("Workspace " .. id .. " layout: " .. LABELS[next_layout])
end

local function pretty(region, key)
  local name = region:gsub("^" .. key .. "_", "")
  return (name:gsub("_", " "))
end

-- Super+U (Hammerspoon cmd+u, Plasma window mover): pick a cell for the focused window's app on this screen
-- layout. "0" returns the app to its configured cell. Choices last until you log out.
function M.pick()
  local win = hl.get_active_window()
  if not win then return end
  local key, layout = M.layout_for(win.monitor)
  if not layout or layout.monocle or not win.workspace or win.workspace.tiled_layout ~= CELLS then
    notify("Cells: this workspace isn't using cells (Super+L cycles layouts)")
    return
  end
  if win.group then
    notify("Cells: take the window out of its group first (Super+Alt+G)")
    return
  end
  local id = app_key(win)
  local current = M.cell_for(win, key, layout)
  local options = {}
  for i, region in ipairs(layout.cells or {}) do
    local label = string.format("%d  %s", i, pretty(region, key))
    if region == current then label = label .. "  (current)" end
    options[#options + 1] = o.shell_quote(label)
  end
  options[#options + 1] = o.shell_quote("0  reset to " .. pretty((layout.apps or {})[id] or layout.default, key))
  local callback = string.format("_G.dotfiles_cells.assign(%q, %q, ", win.address, key)
  hl.exec_cmd("choice=$(omarchy-menu-select " .. o.shell_quote("Move " .. id .. " to") .. " "
    .. table.concat(options, " ") .. ") || exit 0; n=${choice%%[!0-9]*}; [ -n \"$n\" ] && hyprctl eval "
    .. o.shell_quote(callback) .. "\"$n)\"")
end

function M.assign(address, key, index)
  local win = hl.get_window("address:" .. address)
  local layout = config.layouts[key]
  if not win or win.group or not layout or layout.monocle then return end
  local id = app_key(win)
  state.overrides[key] = state.overrides[key] or {}
  local cell = (layout.cells or {})[index]
  if index == 0 then
    state.overrides[key][id] = nil
  elseif cell then
    state.overrides[key][id] = cell
  else
    return
  end
  state.user_tiled[address], state.native_float[address] = nil, nil
  save()
  local region = config.regions[M.cell_for(win, key, layout)]
  if not region then return end
  if region.float then
    snap(win, region)
  elseif win.floating then
    unfloat(address)
  else
    refresh(win)
  end
end

-- Alt+Tab. Monocle input-blocks the stacked windows, so plain cycling skips them and Hyprland's tiled cycling
-- skips floating ones; there, walk every window on the workspace (focusing a stacked one brings it forward).
local function cycle_windows(forward)
  return function()
    local win = hl.get_active_window()
    local ws = win and win.workspace
    if not ws or ws.tiled_layout ~= MONOCLE then
      hl.dispatch(hl.dsp.window.cycle_next({ next = forward }))
      hl.dispatch(hl.dsp.window.bring_to_top())
      return
    end
    local wins = {}
    for _, w in ipairs(hl.get_workspace_windows(ws.id)) do
      -- Skip hidden group tabs (focus can't switch tabs) and floats Hyprland won't focus (no_focus, X11 menus).
      local shown_tab = not w.group or (w.group.current ~= nil and w.group.current.address == w.address)
      if w.mapped and not w.hidden and shown_tab and (not w.floating or w.accepts_input) then wins[#wins + 1] = w end
    end
    for i, w in ipairs(wins) do
      if w.address == win.address and #wins > 1 then
        local target = wins[(forward and i or i - 2) % #wins + 1]
        hl.dispatch(hl.dsp.focus({ window = "address:" .. target.address }))
        hl.dispatch(hl.dsp.window.bring_to_top())
        return
      end
    end
  end
end

local function overlaps(a, b)
  local e = 0.0001
  return a.x < b.x + b.w - e and b.x < a.x + a.w - e and a.y < b.y + b.h - e and b.y < a.y + a.h - e
end

local function validate()
  local problems = {}
  local function problem(msg) problems[#problems + 1] = msg end
  for key, layout in pairs(config.layouts) do
    if not layout.monocle then
      local tiled = {}
      local function check(name, where)
        local region = config.regions[name]
        if not region then return problem(key .. "." .. where .. ": unknown region " .. tostring(name)) end
        if not region.float then tiled[name] = region end
      end
      check(layout.default, "default")
      check(layout.tile, "tile")
      if config.regions[layout.tile] and config.regions[layout.tile].float then problem(key .. ".tile must not float") end
      for i, name in ipairs(layout.cells or {}) do check(name, "cells[" .. i .. "]") end
      for app, name in pairs(layout.apps or {}) do check(name, "apps." .. app) end
      for a, ra in pairs(tiled) do
        for b, rb in pairs(tiled) do
          if a < b and overlaps(ra, rb) then problem(key .. ": tiled regions " .. a .. " and " .. b .. " overlap") end
        end
      end
    end
  end
  for i, screen in ipairs(config.screens) do
    if not config.layouts[screen.layout] then problem("screens[" .. i .. "]: unknown layout " .. tostring(screen.layout)) end
  end
  if #problems > 0 then notify("Cells config: " .. table.concat(problems, "; ")) end
end

-- RE2 (full match) for an app's classes, case-insensitive like registry.matches.
local function class_regex(app)
  local parts = {}
  for _, cls in ipairs(app.classes) do
    parts[#parts + 1] = (cls:gsub("[%^%$%(%)%.%[%]%*%+%?%{%}|\\]", "\\%0"))
  end
  return "(?i)(" .. table.concat(parts, "|") .. ")"
end

validate()

-- Home workspaces apply to every new window of the app, however it was launched. Windows that open floating
-- (dialogs) stay with their parent.
for _, app in ipairs(registry.apps) do
  if app.workspace then
    hl.window_rule({
      name = "dotfiles-home-" .. app.name,
      match = { class = class_regex(app), title = NOT_OMARCHY_EXTRAS, float = false },
      workspace = app.workspace,
    })
  end
end

hl.layout.register("cells", {
  recalculate = recalculate,
  layout_msg = function(_, msg)
    if msg == "refresh" then return true end
  end,
})
hl.config({ general = { layout = CELLS } })

for _, output in ipairs(BUILTIN_OUTPUTS) do
  if monocle_screen({ name = output }) then ensure_monocle(output) end
end
for _, screen in ipairs(config.screens) do
  local layout = config.layouts[screen.layout]
  if screen.name and layout and layout.monocle then ensure_monocle(screen.name) end
end
for _, mon in ipairs(hl.get_monitors()) do
  if monocle_screen(mon) then ensure_monocle(mon.name) end
end

-- Pick up state from before a config reload, for windows that still exist.
local live = {}
for _, win in ipairs(hl.get_windows({})) do live[win.address] = win end
local ok, saved = pcall(dofile, STATE_FILE)
if ok and type(saved) == "table" then
  for _, set in ipairs({ "floated", "user_tiled" }) do
    for address in pairs(saved[set] or {}) do
      if live[address] then state[set][address] = true end
    end
  end
  -- Drop Super+U choices that name a layout or region since removed from layouts.lua.
  for key, apps in pairs(type(saved.overrides) == "table" and saved.overrides or {}) do
    if config.layouts[key] and type(apps) == "table" then
      for id, region in pairs(apps) do
        if config.regions[region] then
          state.overrides[key] = state.overrides[key] or {}
          state.overrides[key][id] = region
        end
      end
    end
  end
end
for address, win in pairs(live) do
  state.opened[address] = true
  if win.floating and not state.floated[address] then state.native_float[address] = true end
end
save()

hl.on("window.open", guarded(function(win)
  if not win or not win.address then return end
  local address = win.address
  state.opened[address] = true
  if win.floating then state.native_float[address] = true end
  if not registry.for_window(win) then state.unmatched[address] = true end
  M.place(win)
end))
hl.on("window.class", guarded(function(win)
  if not win or not win.address then return end
  local address = win.address
  if state.unmatched[address] then
    local app = registry.for_window(win)
    if app then
      state.unmatched[address] = nil
      -- The class arrived after mapping (e.g. Spotify under XWayland), so the home workspace rule never matched.
      -- Dialogs that opened floating stay with their parent; a window cells floated as an unknown app still moves.
      if app.workspace and not state.native_float[address] and win.workspace and win.workspace.name ~= app.workspace then
        hl.dispatch(hl.dsp.window.move({ window = "address:" .. address, workspace = app.workspace }))
        return
      end
    end
  end
  M.place(win)
  refresh(win)
end))
hl.on("window.move_to_workspace", guarded(function(win)
  if win and win.address then place_later(win.address) end
end))
hl.on("window.close", function(win)
  if not win or not win.address then return end
  local address = win.address
  local persisted = state.floated[address] or state.user_tiled[address]
  for _, set in ipairs({ "opened", "floated", "native_float", "user_tiled", "unmatched" }) do state[set][address] = nil end
  if persisted then save() end
end)
hl.on("monitor.added", guarded(function(mon)
  if monocle_screen(mon) then ensure_monocle(mon.name) end
  relayout()
end))
hl.on("monitor.removed", guarded(relayout))
-- Hyprland only shifts floating windows by the monitor offset, so overlays cells placed are re-placed on the new
-- screen (or handed back to tiling on the laptop panel).
hl.on("workspace.move_to_monitor", guarded(function(ws)
  relayout()
  local addresses = {}
  for _, win in ipairs(hl.get_workspace_windows(ws.id)) do
    if state.floated[win.address] then addresses[#addresses + 1] = win.address end
  end
  replace_floated(addresses)
end))
hl.on("monitor.layout_changed", guarded(function()
  local addresses = {}
  for address in pairs(state.floated) do addresses[#addresses + 1] = address end
  replace_floated(addresses)
end))
hl.on("config.props_refreshed", guarded(align_monocle))

hl.unbind("SUPER + L")
o.bind("SUPER + L", "Cycle workspace layout (cells or full screen, tiles, columns)", guarded(M.cycle_layout))
o.bind("SUPER + U", "Move window to a cell", guarded(M.pick))
hl.unbind("ALT + TAB")
o.bind("ALT + TAB", "Focus on next window", guarded(cycle_windows(true)))
hl.unbind("ALT + SHIFT + TAB")
o.bind("ALT + SHIFT + TAB", "Focus on previous window", guarded(cycle_windows(false)))
-- Only dwindle understands togglesplit; anywhere else Hyprland raises a config error bar.
hl.unbind("SUPER + J")
o.bind("SUPER + J", "Toggle window split", guarded(function()
  local ws = current_workspace()
  if ws and ws.tiled_layout == "dwindle" then hl.dispatch(hl.dsp.layout("togglesplit")) end
end))

_G.dotfiles_cells = M
return M
