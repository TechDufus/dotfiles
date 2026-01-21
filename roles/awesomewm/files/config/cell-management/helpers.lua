-- helpers.lua - Utility functions for cell management system
local awful = require("awful")

local M = {}

-- Parse cell string "0,0 52x40" → {x=0, y=0, w=52, h=40}
-- Example: parse_cell_string("10,5 30x20") returns {x=10, y=5, w=30, h=20}
function M.parse_cell_string(cell)
  if type(cell) == "table" then
    return cell  -- Already parsed
  end

  -- Pattern: "x,y wxh"
  local x, y, w, h = cell:match("(%d+),(%d+)%s+(%d+)x(%d+)")
  if not x then
    print("[ERROR] Invalid cell format: " .. tostring(cell))
    return {x=0, y=0, w=80, h=40}  -- Fallback to full screen
  end

  return {
    x = tonumber(x),
    y = tonumber(y),
    w = tonumber(w),
    h = tonumber(h),
  }
end

-- Find client by WM_CLASS (case-insensitive)
-- Returns first matching client or nil
function M.find_client_by_class(wm_class)
  if not wm_class then return nil end

  for _, c in ipairs(client.get()) do
    if c.class and c.class:lower() == wm_class:lower() then
      return c
    end
  end
  return nil
end

-- Find ALL clients by WM_CLASS (case-insensitive)
-- Returns table of all matching clients (may be empty)
function M.find_all_clients_by_class(wm_class)
  if not wm_class then return {} end

  local matches = {}
  for _, c in ipairs(client.get()) do
    if c.class and c.class:lower() == wm_class:lower() then
      table.insert(matches, c)
    end
  end
  return matches
end

-- Find app name by WM_CLASS (reverse lookup)
function M.find_app_by_class(wm_class)
  if not wm_class then return nil end

  local apps = require("cell-management.apps")
  for app_name, config in pairs(apps) do
    if config.class:lower() == wm_class:lower() then
      return app_name
    end
  end
  return nil
end

-- Position client in its assigned cell
-- c: client object
-- app_name: application name from apps.lua
-- layout: layout definition from layouts.lua
function M.position_client_in_cell(c, app_name, layout)
  if not c or not layout or not layout.apps[app_name] then
    print("[WARN] position_client_in_cell: invalid params")
    return
  end

  local grid = require("cell-management.grid")
  local app_config = layout.apps[app_name]
  local cell_index = app_config.cell
  local cell_def = layout.cells[cell_index]

  if not cell_def then
    print("[WARN] Invalid cell index: " .. tostring(cell_index))
    return
  end

  -- Cell def is now the position string directly (no longer an array)
  local primary_position = cell_def

  -- Convert to pixel geometry
  local geom = grid.cell_to_geometry(primary_position, c.screen)

  -- Clear conflicting properties before setting geometry
  c.fullscreen = false
  c.maximized = false
  c.maximized_vertical = false
  c.maximized_horizontal = false

  -- Apply geometry
  c.floating = true  -- Must float for manual positioning
  c.x = geom.x
  c.y = geom.y
  c.width = geom.width
  c.height = geom.height
end

return M
