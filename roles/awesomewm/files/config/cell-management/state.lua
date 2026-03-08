-- state.lua - State management for cell management system
local awful = require("awful")
local layouts = require("cell-management.layouts")

local M = {}

-- State storage (in-memory only, no persistence in v1)
local state = {
  screen_state = setmetatable({}, { __mode = "k" }),
  previous_client_class = nil,
  last_focused_client_by_class = {},  -- Track most recent client per WM_CLASS
}

local function resolve_screen(target_screen)
  return target_screen or awful.screen.focused() or awful.screen.primary
end

local function get_screen_state(target_screen)
  local screen_obj = resolve_screen(target_screen)
  if not screen_obj then
    return nil, nil
  end

  local screen_state = state.screen_state[screen_obj]
  if not screen_state then
    screen_state = {
      current_layout_index = 1,
      app_to_cell_overrides = {},
    }
    state.screen_state[screen_obj] = screen_state
  end

  return screen_state, screen_obj
end

local function get_override_bucket(screen_state, layout_index, create)
  if not screen_state then
    return nil
  end

  local bucket_index = layout_index or screen_state.current_layout_index
  local bucket = screen_state.app_to_cell_overrides[bucket_index]

  if not bucket and create then
    bucket = {}
    screen_state.app_to_cell_overrides[bucket_index] = bucket
  end

  return bucket
end

function M.resolve_screen(target_screen)
  return resolve_screen(target_screen)
end

function M.resolve_layout_index(layout_ref)
  if type(layout_ref) == "number" then
    if layouts[layout_ref] then
      return layout_ref
    end

    print("[WARN] Invalid layout index: " .. tostring(layout_ref))
    return nil
  end

  if type(layout_ref) == "string" then
    local requested_name = layout_ref:lower()
    for index, layout in ipairs(layouts) do
      if layout.name and layout.name:lower() == requested_name then
        return index
      end
    end

    print("[WARN] Unknown layout name: " .. layout_ref)
  end

  return nil
end

-- Get current layout
function M.get_current_layout(target_screen)
  local index = M.get_current_layout_index(target_screen)
  return index and layouts[index] or nil
end

-- Get current layout index
function M.get_current_layout_index(target_screen)
  local screen_state = get_screen_state(target_screen)
  return screen_state and screen_state.current_layout_index or nil
end

-- Set current layout index
function M.set_current_layout_index(index, target_screen)
  if not layouts[index] then
    print("[WARN] Invalid layout index: " .. tostring(index))
    return
  end

  local screen_state = get_screen_state(target_screen)
  if not screen_state then
    return
  end

  screen_state.current_layout_index = index
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
function M.get_app_cell_override(app_name, target_screen, layout_index)
  if not app_name then return nil end

  local screen_state = get_screen_state(target_screen)
  local overrides = get_override_bucket(screen_state, layout_index, false)
  return overrides and overrides[app_name] or nil
end

-- Set app-to-cell override
function M.set_app_cell_override(app_name, cell_index, target_screen, layout_index)
  if not app_name then return end

  local screen_state = get_screen_state(target_screen)
  local overrides = get_override_bucket(screen_state, layout_index, true)
  overrides[app_name] = cell_index
end

-- Get last focused client for a WM_CLASS
function M.get_last_focused_client(wm_class)
  if not wm_class then return nil end
  return state.last_focused_client_by_class[wm_class:lower()]
end

-- Set last focused client for a WM_CLASS
function M.set_last_focused_client(wm_class, c)
  if not wm_class then return end
  state.last_focused_client_by_class[wm_class:lower()] = c
end

return M
