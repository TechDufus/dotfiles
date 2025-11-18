-- grid.lua - Grid system for cell-to-pixel conversion
-- NOTE: Uses screen.workarea (excludes status bar), not screen.geometry
-- NOTE: AwesomeWM's useless_gap is applied automatically - no manual margins needed

local helpers = require("cell-management.helpers")
local awful = require("awful")

local M = {}

-- Virtual grid size (resolution-independent)
local GRID_W, GRID_H = 80, 40

-- Convert virtual grid cell to pixel coordinates
-- cell: string like "0,0 52x40" or table {x=0, y=0, w=52, h=40}
-- screen: awful.screen object (defaults to primary)
-- Returns: geometry table {x, y, width, height}
function M.cell_to_geometry(cell, screen)
  local cell_table = helpers.parse_cell_string(cell)
  screen = screen or awful.screen.primary

  if not screen then
    print("[ERROR] No screen found")
    return {x=0, y=0, width=1920, height=1080}  -- Fallback
  end

  local workarea = screen.workarea  -- Excludes status bar

  -- Calculate single cell size in pixels
  local cell_width_px = workarea.width / GRID_W
  local cell_height_px = workarea.height / GRID_H

  -- Calculate window geometry
  local x = workarea.x + (cell_table.x * cell_width_px)
  local y = workarea.y + (cell_table.y * cell_height_px)
  local w = cell_table.w * cell_width_px
  local h = cell_table.h * cell_height_px

  return {
    x = math.floor(x),
    y = math.floor(y),
    width = math.floor(w),
    height = math.floor(h),
  }
end

return M
