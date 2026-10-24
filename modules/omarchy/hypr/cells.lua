-- Cells: deterministic window placement on top of Omarchy's Hyprland. Managed by ~/.dotfiles modules/omarchy.
-- Ports the Hammerspoon model: every app has a home workspace (summon_apps.lua) and, in each screen
-- layout (layouts.lua), a floating cell. Windows sharing a cell overlap, the focused one on top, and nothing
-- resizes when windows open or close. Monocle screens (the laptop panel) use Hyprland's monocle layout.
local registry = require("hypr.dotfiles.registry")
local config = require("hypr.dotfiles.layouts")
local paths = require("default.hypr.paths")

local CELLS, MONOCLE = "lua:cells", "monocle"
-- What Super+L's notification calls each layout.
local LABELS = { [CELLS] = "cells", [MONOCLE] = "full screen" }
-- Monitors appear after the config loads, so laptop panels get their monocle rule up front. Rules made here
-- precede Omarchy's saved per-workspace layouts (default/hypr/toggles.lua loads later), so those still win.
local BUILTIN_OUTPUTS = { "eDP-1", "eDP-2", "LVDS-1", "DSI-1" }
local SAVED_LAYOUTS = paths.state_home .. "/omarchy/workspace-layouts"
-- Window state survives config reloads (theme switches, toggles) but not the Hyprland session.
local STATE_FILE = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/dotfiles-cells-"
  .. (os.getenv("HYPRLAND_INSTANCE_SIGNATURE") or "session") .. ".lua"
-- Super+U and per-screen layout choices last across logouts, like Hammerspoon's hs.settings.
local CHOICES_DIR = paths.state_home .. "/dotfiles"
local CHOICES_FILE = CHOICES_DIR .. "/cells.lua"
-- Browser windows Omarchy hides or pins by title (apps/browser.lua, apps/pip.lua) keep their own placement.
local NOT_OMARCHY_EXTRAS = "negative:(.*is sharing.*|Picture.?in.?[Pp]icture|Meet - .+)"

local M = { config = config }
local state = {
  opened = {},        -- address -> true: window.open already ran (or the window predates this config)
  floated = {},       -- address -> true: cells floated it into a floating cell
  native_float = {},  -- address -> true: it opened floating on its own (dialogs, Omarchy's floats)
  user_tiled = {},    -- address -> true: you tiled it after it floated (Super+T); it tiles across the whole area
  unmatched = {},     -- address -> true: opened without a registry class (it may arrive later)
  queued = {},        -- address -> true: placement deferred out of a layout pass or event
  overrides = {},     -- screen key -> layout key -> app key -> region (Super+U), kept across logouts
  pinned = {},        -- workspace id -> layout of the per-workspace rule Super+L or a screen change declared
  screen_layouts = {}, -- screen key -> layout key (Hyper+P, Hyper+;), kept across logouts
  screen_rules = {},  -- output -> layout its m[output] s[0] workspace rule declares
  fullscreen = {},    -- address -> fullscreen mode (1 maximized, 2 fullscreen) from the last window.fullscreen event
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
  file:write("return " .. serialize({ floated = state.floated, user_tiled = state.user_tiled, fullscreen = state.fullscreen }))
  file:close()
end

local function save_choices()
  os.execute("mkdir -p " .. o.shell_quote(CHOICES_DIR))
  local tmp = CHOICES_FILE .. ".tmp"
  local file = io.open(tmp, "w")
  if not file then return end
  file:write("return " .. serialize({ overrides = state.overrides, screen_layouts = state.screen_layouts }))
  file:close()
  os.rename(tmp, CHOICES_FILE)
end

local function is_builtin(mon)
  local name = mon and mon.name or ""
  return name:find("^eDP") ~= nil or name:find("^LVDS") ~= nil or name:find("^DSI") ~= nil
end

-- A screen's key for per-screen choices: its description (model and serial, so the same panel keeps its choice
-- on any connector), else the connector name.
local function screen_key(mon)
  if not mon then return nil end
  if type(mon.description) == "string" and mon.description ~= "" then return mon.description end
  return mon.name
end

-- Layout key and table for a monitor from the first matching `screens` entry. desc is a plain prefix of the
-- monitor's description (Hyprland's `desc:` semantics).
local function default_layout(mon)
  for _, screen in ipairs(config.screens) do
    local by_name = screen.name == nil or (mon ~= nil and screen.name == mon.name)
    local by_desc = screen.desc == nil
      or (mon ~= nil and type(mon.description) == "string" and mon.description:sub(1, #screen.desc) == screen.desc)
    local by_panel = screen.builtin == nil or screen.builtin == is_builtin(mon)
    if by_name and by_desc and by_panel then return screen.layout, config.layouts[screen.layout] end
  end
end

-- Layout key and table for a monitor: your Hyper+P / Hyper+; choice, else its `screens` default.
function M.layout_for(mon)
  local chosen = state.screen_layouts[screen_key(mon)]
  if chosen and config.layouts[chosen] then return chosen, config.layouts[chosen] end
  return default_layout(mon)
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

-- Region name for a window on a screen: that screen's Super+U override for its app in this layout, else the
-- layout's cell for the app, else layout.default.
function M.cell_for(win, mon, key, layout)
  local id, app = app_key(win)
  local screen = state.overrides[screen_key(mon)]
  local override = screen and screen[key] and screen[key][id]
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

-- Hyprland CSS gaps: a number, a {top, right, bottom, left} table (named or positional), or "t r b l".
local function css_sides(v)
  if type(v) == "number" then return v, v, v, v end
  if type(v) == "string" then
    local n = {}
    for x in v:gmatch("%-?%d+%.?%d*") do n[#n + 1] = tonumber(x) end
    v = n
  end
  if type(v) == "table" then
    local t = v.top or v[1] or 0
    local r = v.right or v[2] or t
    return t, r, v.bottom or v[3] or t, v.left or v[4] or r
  end
  return 0, 0, 0, 0
end

-- A tiled window's box inside its cell: gaps_out on sides at the screen edge, gaps_in elsewhere, plus the border
-- (Hyprland draws a floating window's border outside the size it is given).
local function inset(box, area)
  local it, ir, ib, il = css_sides(hl.get_config("general.gaps_in"))
  local ot, outr, ob, ol = css_sides(hl.get_config("general.gaps_out"))
  local border = hl.get_config("general.border_size")
  border = type(border) == "number" and border or 0
  local function edge(a, b) return math.abs(a - b) < 0.5 end
  local left = (edge(box.x, area.x) and ol or il) + border
  local top = (edge(box.y, area.y) and ot or it) + border
  local right = (edge(box.x + box.w, area.x + area.w) and outr or ir) + border
  local bottom = (edge(box.y + box.h, area.y + area.h) and ob or ib) + border
  return { x = box.x + left, y = box.y + top, w = box.w - left - right, h = box.h - top - bottom }
end

local function snap(win, region)
  local area = usable_area(win.monitor)
  local box = inset(scaled(area, region), area)
  local sel = "address:" .. win.address
  state.floated[win.address] = true
  state.user_tiled[win.address] = nil
  save()
  if not win.floating then hl.dispatch(hl.dsp.window.float({ window = sel, action = "enable" })) end
  hl.dispatch(hl.dsp.window.resize({ window = sel, x = round(box.w), y = round(box.h) }))
  hl.dispatch(hl.dsp.window.move({ window = sel, x = round(box.x), y = round(box.y) }))
  -- Cells overlap: the window you are working with goes on top.
  local active = hl.get_active_window()
  if active and active.address == win.address then
    hl.dispatch(hl.dsp.window.alter_zorder({ window = sel, mode = "top" }))
  end
end

local function unfloat(address)
  state.floated[address] = nil
  save()
  hl.dispatch(hl.dsp.window.float({ window = "address:" .. address, action = "disable" }))
end

-- Put a window into its cell: every cell floats, so on a cells workspace it gets float + exact geometry. Off a
-- cells workspace (the laptop panel after undocking, a dwindle workspace), a window cells floated goes back to
-- tiling. Grouped windows, windows that opened floating (dialogs, Omarchy's own floats) and windows you tiled
-- yourself (Super+T) are left alone.
function M.place(win)
  if not win or not win.address or not win.workspace or win.group then return end
  -- A fullscreen window keeps its geometry; window.fullscreen re-places it when it leaves.
  if (win.fullscreen or 0) ~= 0 then return end
  local address = win.address
  local key, layout = M.layout_for(win.monitor)
  if win.workspace.tiled_layout ~= CELLS or not layout or layout.monocle then
    if win.floating and state.floated[address] then unfloat(address) end
    return
  end
  if state.user_tiled[address] or (win.floating and not state.floated[address]) then return end
  local region = config.regions[M.cell_for(win, win.monitor, key, layout)]
  if region then snap(win, region) end
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
  local cells = layout ~= nil and not layout.monocle
  local tiled = {}
  for _, target in ipairs(targets) do
    local win = target.window
    local region = cells and win and not win.group and config.regions[M.cell_for(win, mon, key, layout)]
    if region then
      local address = win.address
      if state.floated[address] or state.native_float[address] then
        -- It floated (cells or the app itself) and you tiled it (Super+T): it stays tiled.
        state.floated[address], state.native_float[address] = nil, nil
        state.user_tiled[address] = true
        save()
      end
      if state.user_tiled[address] then
        tiled[#tiled + 1] = target
      else
        -- Floats next (window.open or the deferred pass); open it over its cell so nothing reflows.
        target:place(scaled(area, region))
        if state.opened[address] then place_later(address) end
      end
    else
      tiled[#tiled + 1] = target
    end
  end
  for i, target in ipairs(tiled) do target:place(slice(area, i, #tiled)) end
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

-- Regular workspaces only: the scratchpad keeps splitting on the laptop panel. Re-declaring a rule with the same
-- selector replaces its layout, as Super+L does per workspace.
local function set_screen_rule(output, monocle)
  local want = monocle and MONOCLE or CELLS
  if (state.screen_rules[output] or CELLS) == want then return end
  state.screen_rules[output] = want
  hl.workspace_rule({ workspace = "m[" .. output .. "] s[0]", layout = want })
end

local function saved_layout(id) return SAVED_LAYOUTS .. "/" .. id .. ".lua" end

-- Super+L: toggles this workspace between its screen's cells and full screen. The full-screen choice persists in
-- Omarchy's format, so default/hypr/workspace-layouts.lua restores it after a reload. Hyprland merges rules that
-- share a selector, so this only sets the layout of the workspace's rule (until the next reload it keeps that
-- layout even if the workspace changes screens).
function M.cycle_layout()
  local ws = hl.get_active_workspace()
  if not ws or ws.special then return end
  local own = monocle_screen(hl.get_active_monitor()) and MONOCLE or CELLS
  local id = tostring(ws.id)
  local next_layout
  if ws.tiled_layout ~= own then
    next_layout = own -- back to the screen's layout, also from a dwindle/scrolling layout saved earlier
  elseif own == CELLS then
    next_layout = MONOCLE
  else
    notify("Workspace " .. id .. " is full screen on this screen; Hyper+P picks a layout with cells")
    return
  end
  hl.workspace_rule({ workspace = id, layout = next_layout })
  state.pinned[id] = next_layout
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
  -- Full screen tiles the windows cells floated; back on cells, the layout pass floats them into their cells.
  local addresses = {}
  for _, win in ipairs(hl.get_workspace_windows(ws.id)) do
    if state.floated[win.address] then addresses[#addresses + 1] = win.address end
  end
  replace_floated(addresses)
  notify("Workspace " .. id .. " layout: " .. LABELS[next_layout])
end

-- Hyper+P / Hyper+; / Hyper+': the screen's layout (nil = its `screens` default), kept across logouts.
function M.set_screen_layout(mon, key)
  state.screen_layouts[screen_key(mon)] = key
  save_choices()
  local own = monocle_screen(mon) and MONOCLE or CELLS
  set_screen_rule(mon.name, own == MONOCLE)
  -- Super+L toggles on this screen end: its workspaces follow the new layout.
  for _, ws in ipairs(hl.get_workspaces()) do
    if not ws.special and ws.monitor and ws.monitor.name == mon.name then
      local id = tostring(ws.id)
      if os.remove(saved_layout(id)) or state.pinned[id] then
        hl.workspace_rule({ workspace = id, layout = own })
        state.pinned[id] = own
      end
    end
  end
  relayout()
  hl.exec_scheduled_prop_refresh_immediately()
  align_monocle()
  local addresses = {}
  for _, win in ipairs(hl.get_windows({})) do
    if state.floated[win.address] and win.monitor and win.monitor.name == mon.name then
      addresses[#addresses + 1] = win.address
    end
  end
  replace_floated(addresses) -- new cells, or back to tiling when the screen goes full screen
  local layout_key, layout = M.layout_for(mon)
  notify(mon.name .. " layout: " .. (layout.name or layout_key) .. (key == nil and " (default)" or ""))
end

-- Hyper+;: the focused screen's next layout in `order`.
function M.next_layout()
  local mon = hl.get_active_monitor()
  if not mon then return end
  local order = config.order or {}
  local current = M.layout_for(mon)
  local next_key = order[1]
  for i, key in ipairs(order) do
    if key == current then
      next_key = order[i % #order + 1]
      break
    end
  end
  M.set_screen_layout(mon, next_key)
end

-- Hyper+': back to the screen's `screens` default. Super+U choices stay.
function M.reset_layout()
  local mon = hl.get_active_monitor()
  if mon then M.set_screen_layout(mon, nil) end
end

-- Hyper+P: pick the focused screen's layout; "0" returns it to its `screens` default.
function M.pick_layout()
  local mon = hl.get_active_monitor()
  if not mon then return end
  local current = M.layout_for(mon)
  local options = {}
  for i, key in ipairs(config.order or {}) do
    local layout = config.layouts[key]
    local label = string.format("%d  %s", i, layout and layout.name or key)
    if key == current then label = label .. "  (current)" end
    options[#options + 1] = o.shell_quote(label)
  end
  local default_key, default = default_layout(mon)
  options[#options + 1] = o.shell_quote("0  reset to " .. ((default and default.name) or default_key or "default"))
  local callback = string.format("_G.dotfiles_cells.choose_layout(%q, ", mon.name)
  hl.exec_cmd("choice=$(omarchy-menu-select " .. o.shell_quote("Layout for " .. mon.name) .. " "
    .. table.concat(options, " ") .. ") || exit 0; n=${choice%%[!0-9]*}; [ -n \"$n\" ] && hyprctl eval "
    .. o.shell_quote(callback) .. "\"$n)\"")
end

function M.choose_layout(output, index)
  for _, mon in ipairs(hl.get_monitors()) do
    if mon.name == output then
      if index == 0 then
        M.set_screen_layout(mon, nil)
      elseif (config.order or {})[index] then
        M.set_screen_layout(mon, config.order[index])
      end
      return
    end
  end
end

-- Hammerspoon lilHyper+o / Hyper+o: screens left to right (then top to bottom), wrapping; the window lands in its
-- cell there (window.move_to_workspace also queues the placement; place_later runs it once). Windows cells does
-- not own (dialogs, Omarchy's pop-outs) keep their box relative to the screen instead; fullscreen ones only move.
function M.move_to_screen(step)
  local win = hl.get_active_window()
  if not win or not win.monitor then return end
  local mons = {}
  for _, m in ipairs(hl.get_monitors()) do mons[#mons + 1] = m end
  if #mons < 2 then return end
  table.sort(mons, function(a, b)
    if a.x ~= b.x then return a.x < b.x end
    if a.y ~= b.y then return a.y < b.y end
    return a.name < b.name
  end)
  for i, m in ipairs(mons) do
    if m.name == win.monitor.name then
      local target = mons[(i - 1 + step) % #mons + 1]
      local ws = target.active_workspace
      if not ws then return end
      local address = win.address
      local relative
      if win.floating and not state.floated[address] and (win.fullscreen or 0) == 0 and win.at and win.size then
        local from = usable_area(win.monitor)
        relative = {
          x = (win.at.x - from.x) / from.w, y = (win.at.y - from.y) / from.h,
          w = win.size.x / from.w, h = win.size.y / from.h,
        }
      end
      -- The move asks for the window's place on the other screen (Hammerspoon always snapped there), so a window
      -- you tiled (Super+T) goes back to its cell, as Super+U does.
      if not relative and state.user_tiled[address] then
        state.user_tiled[address] = nil
        save()
      end
      hl.dispatch(hl.dsp.window.move({ window = "address:" .. address, workspace = tostring(ws.id), follow = true }))
      if relative then
        hl.timer(guarded(function()
          local moved = hl.get_window("address:" .. address)
          if not moved or not moved.monitor then return end
          local box = scaled(usable_area(moved.monitor), relative)
          local sel = "address:" .. address
          hl.dispatch(hl.dsp.window.resize({ window = sel, x = round(box.w), y = round(box.h) }))
          hl.dispatch(hl.dsp.window.move({ window = sel, x = round(box.x), y = round(box.y) }))
        end), { timeout = 1, type = "oneshot" })
      elseif (win.fullscreen or 0) == 0 then
        place_later(address)
      end
      return
    end
  end
end

local function pretty(region, key)
  local name = region:gsub("^" .. key .. "_", "")
  return (name:gsub("_", " "))
end

-- Super+U (Hammerspoon cmd+u): pick a cell for the focused window's app on this screen
-- layout. "0" returns the app to its configured cell. Choices are kept across logouts.
function M.pick()
  local win = hl.get_active_window()
  if not win then return end
  local key, layout = M.layout_for(win.monitor)
  if not layout or layout.monocle or not win.workspace or win.workspace.tiled_layout ~= CELLS then
    if layout and layout.monocle then
      notify("Cells: this screen is full screen (Hyper+P picks a layout with cells)")
    else
      notify("Cells: this workspace is full screen (Super+L switches it back to cells)")
    end
    return
  end
  if win.group then
    notify("Cells: take the window out of its group first (Super+Alt+G)")
    return
  end
  local id = app_key(win)
  local current = M.cell_for(win, win.monitor, key, layout)
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
  local id, screen = app_key(win), screen_key(win.monitor)
  if not screen then return end
  local cell = (layout.cells or {})[index]
  if index == 0 then
    local apps = state.overrides[screen] and state.overrides[screen][key]
    if apps then apps[id] = nil end
  elseif cell then
    state.overrides[screen] = state.overrides[screen] or {}
    state.overrides[screen][key] = state.overrides[screen][key] or {}
    state.overrides[screen][key][id] = cell
  else
    return
  end
  save_choices()
  state.user_tiled[address], state.native_float[address] = nil, nil
  local region = config.regions[M.cell_for(win, win.monitor, key, layout)]
  if region then snap(win, region) else save() end
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

-- Alt+Tab opens OmaSwitch (piyush.omaswitch, cloned and enabled by mise.omarchy.toml) while it is installed
-- and in shell.json's plugins[], else cycle_windows. Checked per press, so removing or disabling the plugin
-- hands Alt+Tab back without a config reload.
local OMASWITCH = "piyush.omaswitch"

local function omaswitch_enabled()
  local dir = paths.config_home .. "/omarchy"
  local manifest = io.open(dir .. "/plugins/" .. OMASWITCH .. "/manifest.json")
  if not manifest then return false end
  manifest:close()
  local file = io.open(dir .. "/shell.json")
  if not file then return false end
  local text = file:read("a")
  file:close()
  local list = text:match('"plugins"%s*:%s*(%b[])')
  return list ~= nil and list:find('"' .. OMASWITCH .. '"', 1, true) ~= nil
end

local function switch_windows(forward)
  local cycle = cycle_windows(forward)
  local summon = "omarchy-shell shell summon " .. OMASWITCH .. " "
    .. o.shell_quote(string.format('{"mode":"cycle","direction":%d}', forward and 1 or -1))
  return function()
    if omaswitch_enabled() then hl.exec_cmd(summon) else cycle() end
  end
end

local function validate()
  local problems = {}
  local function problem(msg) problems[#problems + 1] = msg end
  for key, layout in pairs(config.layouts) do
    if not layout.monocle then
      local function check(name, where)
        if not config.regions[name] then problem(key .. "." .. where .. ": unknown region " .. tostring(name)) end
      end
      check(layout.default, "default")
      for i, name in ipairs(layout.cells or {}) do check(name, "cells[" .. i .. "]") end
      for app, name in pairs(layout.apps or {}) do check(name, "apps." .. app) end
    end
  end
  for i, screen in ipairs(config.screens) do
    if not config.layouts[screen.layout] then problem("screens[" .. i .. "]: unknown layout " .. tostring(screen.layout)) end
  end
  local order, listed = config.order or {}, {}
  for i, key in ipairs(order) do
    if not config.layouts[key] then
      problem("order[" .. i .. "]: unknown layout " .. tostring(key))
    elseif listed[key] then
      problem("order: " .. key .. " listed twice")
    end
    listed[key] = true
  end
  local missing = {}
  for key in pairs(config.layouts) do
    if not listed[key] then missing[#missing + 1] = key end
  end
  table.sort(missing)
  for _, key in ipairs(missing) do problem("order: layout " .. key .. " missing") end
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

hl.layout.register("cells", { recalculate = recalculate })
hl.config({ general = { layout = CELLS } })

-- Super+U and Hyper+P choices from earlier sessions. Keep only well-formed entries: screen -> layout -> app ->
-- region, naming a layout and region still in layouts.lua. Anything else (including the older layout -> app ->
-- region shape, which has no per-screen level) is dropped.
local choices_ok, choices = pcall(dofile, CHOICES_FILE)
if choices_ok and type(choices) == "table" then
  for screen, layouts in pairs(type(choices.overrides) == "table" and choices.overrides or {}) do
    if type(screen) == "string" and type(layouts) == "table" then
      for key, apps in pairs(layouts) do
        if config.layouts[key] and type(apps) == "table" then
          for id, region in pairs(apps) do
            if type(id) == "string" and type(region) == "string" and config.regions[region] then
              state.overrides[screen] = state.overrides[screen] or {}
              state.overrides[screen][key] = state.overrides[screen][key] or {}
              state.overrides[screen][key][id] = region
            end
          end
        end
      end
    end
  end
  for screen, key in pairs(type(choices.screen_layouts) == "table" and choices.screen_layouts or {}) do
    if type(screen) == "string" and config.layouts[key] then state.screen_layouts[screen] = key end
  end
end

for _, output in ipairs(BUILTIN_OUTPUTS) do
  set_screen_rule(output, monocle_screen({ name = output }))
end
for _, screen in ipairs(config.screens) do
  if screen.name then set_screen_rule(screen.name, monocle_screen({ name = screen.name })) end
end
for _, mon in ipairs(hl.get_monitors()) do
  set_screen_rule(mon.name, monocle_screen(mon))
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
  for address, mode in pairs(type(saved.fullscreen) == "table" and saved.fullscreen or {}) do
    if live[address] then state.fullscreen[address] = mode end
  end
end
for address, win in pairs(live) do
  state.opened[address] = true
  if win.floating and not state.floated[address] then state.native_float[address] = true end
  if (win.fullscreen or 0) ~= 0 then state.fullscreen[address] = win.fullscreen end
end
save()
-- The reload may have changed gaps (looknfeel.lua, Omarchy's no-gaps toggle) or layouts.lua: re-snap them.
local restored = {}
for address in pairs(state.floated) do restored[#restored + 1] = address end
replace_floated(restored)

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
end))
hl.on("window.move_to_workspace", guarded(function(win)
  if win and win.address then place_later(win.address) end
end))
hl.on("window.close", function(win)
  if not win or not win.address then return end
  local address = win.address
  local persisted = state.floated[address] or state.user_tiled[address] or state.fullscreen[address]
  for _, set in ipairs({ "opened", "floated", "native_float", "user_tiled", "unmatched", "fullscreen" }) do state[set][address] = nil end
  if persisted then save() end
end)
hl.on("monitor.added", guarded(function(mon)
  set_screen_rule(mon.name, monocle_screen(mon))
  relayout()
end))
hl.on("monitor.removed", guarded(relayout))
-- Hyprland only shifts floating windows by the monitor offset, so windows cells floated are re-placed on the new
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
-- Hyprland 0.56 drops a window's fullscreen state without telling the app when it rebuilds the workspace's tiled
-- layout (seen on config reloads; Super+L and Hyper+P take the same path in its source). The app stays fullscreen,
-- so Chromium hides its tabs again on every focus change. Put the window back in the mode it last reported.
local function restore_fullscreen()
  for address, mode in pairs(state.fullscreen) do
    local win = hl.get_window("address:" .. address)
    if not win then
      state.fullscreen[address] = nil
    elseif (win.fullscreen or 0) == 0 then
      hl.dispatch(hl.dsp.window.fullscreen({ window = "address:" .. address, action = "set",
        mode = mode == 1 and "maximized" or "fullscreen" }))
    end
  end
end
hl.on("config.props_refreshed", guarded(function()
  restore_fullscreen()
  align_monocle()
end))
-- A window that changed screens while fullscreen keeps its fullscreen geometry; when it leaves fullscreen it
-- goes to its cell (or tiles on a monocle screen).
hl.on("window.fullscreen", guarded(function(win)
  if not win or not win.address then return end
  state.fullscreen[win.address] = win.fullscreen ~= 0 and win.fullscreen or nil
  save()
  if win.fullscreen == 0 then place_later(win.address) end
end))

hl.unbind("SUPER + L")
o.bind("SUPER + L", "Toggle workspace between cells and full screen", guarded(M.cycle_layout))
o.bind("SUPER + U", "Move window to a cell", guarded(M.pick))
hl.unbind("ALT + TAB")
o.bind("ALT + TAB", "Window switcher (next window)", guarded(switch_windows(true)))
hl.unbind("ALT + SHIFT + TAB")
o.bind("ALT + SHIFT + TAB", "Window switcher (previous window)", guarded(switch_windows(false)))
-- Only dwindle understands togglesplit; anywhere else Hyprland raises a config error bar.
hl.unbind("SUPER + J")
o.bind("SUPER + J", "Toggle window split", guarded(function()
  local ws = current_workspace()
  if ws and ws.tiled_layout == "dwindle" then hl.dispatch(hl.dsp.layout("togglesplit")) end
end))
o.bind("SUPER + CTRL + ALT + SHIFT + P", "Pick this screen's layout", guarded(M.pick_layout))
o.bind("SUPER + CTRL + ALT + SHIFT + code:47", "Next layout for this screen", guarded(M.next_layout))
o.bind("SUPER + CTRL + ALT + SHIFT + code:48", "Reset this screen's layout", guarded(M.reset_layout))
o.bind("SUPER + CTRL + ALT + O", "Move window to the next screen", guarded(function() M.move_to_screen(1) end))
o.bind("SUPER + CTRL + ALT + SHIFT + O", "Move window to the previous screen", guarded(function() M.move_to_screen(-1) end))
-- Command+O / Command+Shift+O on macOS. Omarchy binds Super+O (pop window out) and
-- Super+Shift+O (Obsidian; CapsLock n summons it here), and Hyprland fires every bind on a key: unbind them first.
hl.unbind("SUPER + O")
o.bind("SUPER + O", "Move window to the next screen", guarded(function() M.move_to_screen(1) end))
hl.unbind("SUPER + SHIFT + O")
o.bind("SUPER + SHIFT + O", "Move window to the previous screen", guarded(function() M.move_to_screen(-1) end))

_G.dotfiles_cells = M
return M
