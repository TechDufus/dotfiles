-- layout-manager.lua - Layout switching and manual cell binding
local awful = require("awful")
local state = require("cell-management.state")
local helpers = require("cell-management.helpers")

local M = {}

-- Switch to layout by index
function M.switch_layout(index)
  local layouts = state.get_all_layouts()
  if index < 1 or index > #layouts then
    print("[WARN] Invalid layout index: " .. tostring(index))
    return
  end

  state.set_current_layout_index(index)
  local layout = state.get_current_layout()

  print("[INFO] Switched to layout: " .. layout.name)

  -- Reposition all open apps
  for app_name, app_config in pairs(layout.apps) do
    local app_def = require("cell-management.apps")[app_name]
    if app_def then
      local client = helpers.find_client_by_class(app_def.class)
      if client then
        helpers.position_client_in_cell(client, app_name, layout)
      end
    end
  end
end

-- Interactive layout picker (Hyper+p)
function M.select_layout()
  local layouts = state.get_all_layouts()
  local current_index = state.get_current_layout_index()

  -- Build prompt text
  local prompt_text = "Select layout: "
  for i, layout in ipairs(layouts) do
    local marker = (i == current_index) and "*" or " "
    prompt_text = prompt_text .. string.format("%s%d) %s  ", marker, i, layout.name)
  end

  awful.prompt.run {
    prompt = prompt_text,
    textbox = awful.screen.focused().mypromptbox.widget,
    exe_callback = function(input)
      local index = tonumber(input)
      if index then
        M.switch_layout(index)
      end
    end,
  }
end

-- Cycle to next layout (Hyper+;)
function M.select_next_variant()
  local layouts = state.get_all_layouts()
  local current_index = state.get_current_layout_index()
  local next_index = (current_index % #layouts) + 1
  M.switch_layout(next_index)
end

-- Bind window to cell (Hyper+u)
function M.bind_to_cell()
  local c = client.focus
  if not c then
    print("[WARN] No focused client")
    return
  end

  local layout = state.get_current_layout()
  local prompt_text = string.format("Move to cell (1-%d): ", #layout.cells)

  awful.prompt.run {
    prompt = prompt_text,
    textbox = awful.screen.focused().mypromptbox.widget,
    exe_callback = function(input)
      local cell_index = tonumber(input)
      if cell_index and cell_index >= 1 and cell_index <= #layout.cells then
        -- Get cell definition
        local cell_def = layout.cells[cell_index]
        local geom = require("cell-management.grid").cell_to_geometry(cell_def[1], c.screen)

        -- Position client
        c.floating = true
        c.x = geom.x
        c.y = geom.y
        c.width = geom.width
        c.height = geom.height

        print(string.format("[INFO] Moved %s to cell %d", c.class or "unknown", cell_index))
      else
        print("[WARN] Invalid cell index: " .. tostring(input))
      end
    end,
  }
end

return M
