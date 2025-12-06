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

-- Load keybindings (registers global keys)
require("cell-management.keybindings")

-- Resolution-based layout auto-selection
-- Finds the best layout based on primary screen resolution
local function get_best_layout_for_resolution()
  local screen_width = awful.screen.focused().geometry.width

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

-- Post-restart layout re-apply
-- After AwesomeWM restarts, various placement functions can nudge windows.
-- This timer waits for everything to settle, then re-applies the current layout.
if awesome.startup then
  gears.timer.start_new(0.5, function()
    -- Auto-select layout based on screen resolution
    local best_layout = get_best_layout_for_resolution()
    state.set_current_layout_index(best_layout)
    layout_manager.switch_layout(best_layout)
    return false  -- Don't repeat
  end)
end

-- Return public API (for future extensions)
return {
  state = state,
  grid = grid,
  summon = summon,
  helpers = helpers,
}
