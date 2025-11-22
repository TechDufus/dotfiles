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

  -- Reposition all open apps (including multiple windows of same app)
  for app_name, app_config in pairs(layout.apps) do
    local app_def = require("cell-management.apps")[app_name]
    if app_def then
      local clients = helpers.find_all_clients_by_class(app_def.class)
      for _, c in ipairs(clients) do
        helpers.position_client_in_cell(c, app_name, layout)
      end
    end
  end
end

-- Interactive layout picker (Hyper+p) - Uses rofi for visual selection
function M.select_layout()
  local layouts = state.get_all_layouts()
  local current_index = state.get_current_layout_index()

  -- Build rofi menu with layout names
  local menu_items = {}
  for i, layout in ipairs(layouts) do
    local marker = (i == current_index) and "* " or "  "
    local menu_line = string.format("%s%d. %s", marker, i, layout.name)
    table.insert(menu_items, menu_line)
  end

  -- Create temporary file with menu items
  local menu_file = "/tmp/awesomewm-layout-menu"
  local f = io.open(menu_file, "w")
  if f then
    f:write(table.concat(menu_items, "\n"))
    f:close()
  end

  -- Launch rofi and handle selection
  awful.spawn.easy_async_with_shell(
    string.format('rofi -dmenu -i -p "Select layout" -format s < %s', menu_file),
    function(stdout, stderr, reason, exit_code)
      -- Parse selection: "  2. My Layout" -> extract "2"
      local index = stdout:match("^%s*%*?%s*(%d+)%.")
      if index then
        index = tonumber(index)
        if index then
          M.switch_layout(index)
        end
      end

      -- Clean up temp file
      os.remove(menu_file)
    end
  )
end

-- Cycle to next layout (Hyper+;)
function M.select_next_variant()
  local layouts = state.get_all_layouts()
  local current_index = state.get_current_layout_index()
  local next_index = (current_index % #layouts) + 1
  M.switch_layout(next_index)
end

-- Bind window to cell (Hyper+u) - Uses rofi for visual selection
function M.bind_to_cell()
  local c = client.focus
  if not c then
    print("[WARN] No focused client")
    return
  end

  local layout = state.get_current_layout()
  local apps_module = require("cell-management.apps")

  -- Build rofi menu with cell information
  local menu_items = {}
  for i, cell_def in ipairs(layout.cells) do
    -- Find which apps are assigned to this cell
    local apps_in_cell = {}
    for app_name, app_config in pairs(layout.apps or {}) do
      if app_config.cell == i then
        table.insert(apps_in_cell, app_name)
      end
    end

    -- Build menu line: "Cell 1: Terminal, Browser" or "Cell 1: (empty)"
    local app_list = #apps_in_cell > 0 and table.concat(apps_in_cell, ", ") or "(empty)"
    local menu_line = string.format("Cell %d: %s", i, app_list)
    table.insert(menu_items, menu_line)
  end

  -- Create temporary file with menu items
  local menu_file = "/tmp/awesomewm-cell-menu"
  local f = io.open(menu_file, "w")
  if f then
    f:write(table.concat(menu_items, "\n"))
    f:close()
  end

  -- Launch rofi and handle selection
  awful.spawn.easy_async_with_shell(
    string.format('rofi -dmenu -i -p "Move %s to cell" -format s < %s',
      c.class or "window", menu_file),
    function(stdout, stderr, reason, exit_code)
      -- Parse selection: "Cell 3: Spotify" -> extract "3"
      local cell_index = stdout:match("^Cell (%d+):")
      if cell_index then
        cell_index = tonumber(cell_index)

        if cell_index and cell_index >= 1 and cell_index <= #layout.cells then
          -- Get cell definition (now a direct position string, not an array)
          local cell_def = layout.cells[cell_index]
          local geom = require("cell-management.grid").cell_to_geometry(cell_def, c.screen)

          -- Position client
          c.floating = true
          c.x = geom.x
          c.y = geom.y
          c.width = geom.width
          c.height = geom.height

          print(string.format("[INFO] Moved %s to cell %d", c.class or "unknown", cell_index))
        end
      end

      -- Clean up temp file
      os.remove(menu_file)
    end
  )
end

return M
