-- state.lua - State management for cell management system
local layouts = require("cell-management.layouts")

local M = {}

-- State storage (in-memory only, no persistence in v1)
local state = {
  current_layout_index = 1,
  previous_client_class = nil,
  app_to_cell_overrides = {},  -- User manual assignments via Hyper+u
}

-- Get current layout
function M.get_current_layout()
  return layouts[state.current_layout_index]
end

-- Get current layout index
function M.get_current_layout_index()
  return state.current_layout_index
end

-- Set current layout index
function M.set_current_layout_index(index)
  if index >= 1 and index <= #layouts then
    state.current_layout_index = index
  else
    print("[WARN] Invalid layout index: " .. tostring(index))
  end
end

-- Get previous client class (for toggle behavior)
function M.get_previous_client_class()
  return state.previous_client_class
end

-- Set previous client class
function M.set_previous_client_class(class)
  state.previous_client_class = class
end

-- Get all layouts
function M.get_all_layouts()
  return layouts
end

-- Get app-to-cell overrides
function M.get_app_cell_override(app_name)
  return state.app_to_cell_overrides[app_name]
end

-- Set app-to-cell override
function M.set_app_cell_override(app_name, cell_index)
  state.app_to_cell_overrides[app_name] = cell_index
end

return M
