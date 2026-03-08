-- init.lua - Module loader/orchestrator for cell management system
local awful = require("awful")
local gears = require("gears")

-- Load modules in dependency order
local state = require("cell-management.state")
local grid = require("cell-management.grid")
local positions = require("cell-management.positions")
local apps = require("cell-management.apps")
local layouts = require("cell-management.layouts")
local helpers = require("cell-management.helpers")
local summon = require("cell-management.summon")
local layout_manager = require("cell-management.layout-manager")
local user_config = require("cell-management.config")

-- Load keybindings (registers global keys)
require("cell-management.keybindings")

local function get_configured_layout_for_screen(target_screen)
  local screen_layouts = user_config.screen_layouts or {}

  for _, output_name in ipairs(helpers.get_screen_output_names(target_screen)) do
    local layout_index = state.resolve_layout_index(screen_layouts[output_name])
    if layout_index then
      return layout_index
    end
  end

  if target_screen == awful.screen.primary then
    local primary_layout = state.resolve_layout_index(screen_layouts.primary)
    if primary_layout then
      return primary_layout
    end
  end

  local indexed_layout = state.resolve_layout_index(screen_layouts["screen:" .. tostring(target_screen.index or 1)])
  if indexed_layout then
    return indexed_layout
  end

  return nil
end

-- Resolution-based layout auto-selection.
-- Uses explicit per-screen config first, then falls back to screen width.
local function get_best_layout_for_screen(target_screen)
  target_screen = state.resolve_screen(target_screen)
  if not target_screen then
    return 1
  end

  local configured_layout = get_configured_layout_for_screen(target_screen)
  if configured_layout then
    return configured_layout
  end

  local screen_width = target_screen.geometry.width

  for index, layout in ipairs(layouts) do
    local min_w = layout.min_width or 0
    local max_w = layout.max_width or math.huge

    if screen_width >= min_w and screen_width <= max_w then
      return index
    end
  end

  -- Fallback to first layout if nothing matches
  return 1
end

local function initialize_layouts_for_all_screens()
  for screen_index = 1, screen.count() do
    local target_screen = screen[screen_index]
    if target_screen then
      local best_layout = get_best_layout_for_screen(target_screen)
      state.set_current_layout_index(best_layout, target_screen)
    end
  end
end

local reapply_timer = nil

local function schedule_layout_reapply()
  if reapply_timer then
    reapply_timer:stop()
  end

  reapply_timer = gears.timer {
    timeout = 0.2,
    autostart = true,
    single_shot = true,
    callback = function()
      layout_manager.reapply_current_layout()
      reapply_timer = nil
    end,
  }
end

-- Post-restart layout re-apply
-- After AwesomeWM restarts, various placement functions can nudge windows.
-- This timer waits for everything to settle, then re-applies the current layout.
if awesome.startup then
  gears.timer.start_new(0.5, function()
    initialize_layouts_for_all_screens()
    layout_manager.reapply_current_layout()
    return false  -- Don't repeat
  end)
end

screen.connect_signal("property::geometry", schedule_layout_reapply)
screen.connect_signal("added", function(s)
  state.set_current_layout_index(get_best_layout_for_screen(s), s)
  schedule_layout_reapply()
end)

-- Return public API (for future extensions)
return {
  state = state,
  grid = grid,
  summon = summon,
  helpers = helpers,
  layout_manager = layout_manager,
}
