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

-- Post-restart layout re-apply
-- After AwesomeWM restarts, various placement functions can nudge windows.
-- This timer waits for everything to settle, then re-applies the current layout.
if awesome.startup then
  gears.timer.start_new(0.5, function()
    local current_index = state.get_current_layout_index()
    layout_manager.switch_layout(current_index)
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
