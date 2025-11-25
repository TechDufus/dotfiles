-- init.lua - Module loader/orchestrator for cell management system
local awful = require("awful")

-- Load modules in dependency order
local state = require("cell-management.state")
local grid = require("cell-management.grid")
local positions = require("cell-management.positions")
local apps = require("cell-management.apps")
local layouts = require("cell-management.layouts")
local helpers = require("cell-management.helpers")
local summon = require("cell-management.summon")

-- Load keybindings (registers global keys)
require("cell-management.keybindings")

-- Return public API (for future extensions)
return {
  state = state,
  grid = grid,
  summon = summon,
  helpers = helpers,
}
