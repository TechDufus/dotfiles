-- layout-manager.lua - Layout switching and manual cell binding
local awful = require("awful")
local gears = require("gears")
local naughty = require("naughty")
local state = require("cell-management.state")
local helpers = require("cell-management.helpers")

local M = {}

local key_to_number = {
  ["1"] = 1, ["KP_1"] = 1,
  ["2"] = 2, ["KP_2"] = 2,
  ["3"] = 3, ["KP_3"] = 3,
  ["4"] = 4, ["KP_4"] = 4,
  ["5"] = 5, ["KP_5"] = 5,
  ["6"] = 6, ["KP_6"] = 6,
  ["7"] = 7, ["KP_7"] = 7,
  ["8"] = 8, ["KP_8"] = 8,
  ["9"] = 9, ["KP_9"] = 9,
}

local function get_relative_screen(base_screen, offset)
  if not base_screen or screen.count() < 2 then
    return base_screen
  end

  local base_index = base_screen.index or 1
  local target_index = ((base_index - 1 + offset) % screen.count()) + 1
  return screen[target_index] or base_screen
end

local function reapply_layout_for_screen(target_screen)
  target_screen = state.resolve_screen(target_screen)
  if not target_screen then
    return
  end

  local layout = state.get_current_layout(target_screen)
  if not layout or not layout.apps then
    return
  end

  local apps = require("cell-management.apps")

  -- Reposition all known app windows assigned to this screen's layout.
  for app_name, _ in pairs(layout.apps) do
    local app_def = apps[app_name]
    if app_def then
      local clients = helpers.find_all_clients_by_class(app_def.class)
      for _, c in ipairs(clients) do
        if c.screen == target_screen then
          helpers.position_client_in_cell(c, app_name, layout)
        end
      end
    end
  end
end

local function notify_picker(title, lines)
  naughty.notify({
    title = title,
    text = table.concat(lines, "\n"),
    timeout = 2,
  })
end

local function start_numeric_picker(title, lines, max_index, callback)
  notify_picker(title, lines)

  local picker = awful.keygrabber {
    stop_key = "Escape",
    stop_event = "press",
    timeout = 2,
    autostart = false,
    keypressed_callback = function(self, mod, key)
      local index = key_to_number[key]

      if index and index <= max_index then
        self:stop()
        gears.timer.delayed_call(function()
          callback(index)
        end)
        return
      end

      self:stop()
    end,
  }

  picker:start()
end

local function move_client_to_cell(c, cell_index, target_screen, layout)
  if not c or not c.valid then
    return
  end

  cell_index = tonumber(cell_index)
  if not cell_index then
    print("[WARN] Invalid cell index: " .. tostring(cell_index))
    return
  end

  target_screen = target_screen or c.screen
  layout = layout or state.get_current_layout(target_screen)

  if not layout or not layout.cells then
    print("[WARN] No layout configured for " .. helpers.get_screen_label(target_screen))
    return
  end

  if cell_index < 1 or cell_index > #layout.cells then
    print("[WARN] Invalid cell index: " .. tostring(cell_index))
    return
  end

  local app_name = c.class and helpers.find_app_by_class(c.class) or nil
  if app_name and layout.apps and layout.apps[app_name] then
    state.set_app_cell_override(app_name, cell_index, target_screen)
    helpers.position_client_in_cell(c, app_name, layout)
    return
  end

  local cell_def = layout.cells[cell_index]
  local geom = require("cell-management.grid").cell_to_geometry(cell_def, c.screen)

  c.fullscreen = false
  c.maximized = false
  c.maximized_vertical = false
  c.maximized_horizontal = false
  c.floating = true
  c.x = geom.x
  c.y = geom.y
  c.width = geom.width
  c.height = geom.height
end

local function move_client_to_screen(c, target_screen, follow)
  if not c or not target_screen or c.screen == target_screen then
    return
  end

  local source_tag = c.first_tag
  local target_tag = source_tag and target_screen.tags[source_tag.index] or target_screen.selected_tag

  c:move_to_screen(target_screen)

  if target_tag then
    c:move_to_tag(target_tag)
    if follow then
      target_tag:view_only()
    end
  end

  local layout = state.get_current_layout(target_screen)
  local app_name = c.class and helpers.find_app_by_class(c.class) or nil
  if layout and app_name and layout.apps and layout.apps[app_name] then
    helpers.position_client_in_cell(c, app_name, layout)
  end

  if follow then
    awful.screen.focus(target_screen)
    c:emit_signal("request::activate", "move_to_screen", { raise = true })
  end
end

-- Switch to layout by index
function M.switch_layout(index, target_screen)
  local layouts = state.get_all_layouts()
  if index < 1 or index > #layouts then
    print("[WARN] Invalid layout index: " .. tostring(index))
    return
  end

  target_screen = state.resolve_screen(target_screen)
  state.set_current_layout_index(index, target_screen)
  M.reapply_current_layout(target_screen)
end

function M.reapply_current_layout(target_screen)
  if target_screen then
    reapply_layout_for_screen(target_screen)
    return
  end

  for screen_index = 1, screen.count() do
    local screen_obj = screen[screen_index]
    if screen_obj then
      reapply_layout_for_screen(screen_obj)
    end
  end
end

function M.move_client_to_next_screen(c, follow)
  if not c then return end
  move_client_to_screen(c, get_relative_screen(c.screen, 1), follow ~= false)
end

function M.move_client_to_previous_screen(c, follow)
  if not c then return end
  move_client_to_screen(c, get_relative_screen(c.screen, -1), follow ~= false)
end

-- Interactive layout picker (Hyper+p)
function M.select_layout(target_screen)
  target_screen = state.resolve_screen(target_screen)

  local layouts = state.get_all_layouts()
  local current_index = state.get_current_layout_index(target_screen)
  local screen_label = helpers.get_screen_label(target_screen)
  local picker_lines = {}
  for i, layout in ipairs(layouts) do
    local marker = (i == current_index) and "*" or " "
    table.insert(picker_lines, string.format("%s %d  %s", marker, i, layout.name))
  end

  start_numeric_picker(
    "Layout for " .. screen_label,
    picker_lines,
    #layouts,
    function(index)
      M.switch_layout(index, target_screen)
    end
  )
end

-- Cycle to next layout (Hyper+;)
function M.select_next_variant(target_screen)
  target_screen = state.resolve_screen(target_screen)

  local layouts = state.get_all_layouts()
  local current_index = state.get_current_layout_index(target_screen)
  local next_index = (current_index % #layouts) + 1
  M.switch_layout(next_index, target_screen)
end

-- Bind window to cell (Hyper+u)
function M.bind_to_cell(cell_index)
  local c = client.focus
  if not c then
    print("[WARN] No focused client")
    return
  end

  local target_screen = c.screen
  local layout = state.get_current_layout(target_screen)

  if not layout then
    print("[WARN] No layout configured for " .. helpers.get_screen_label(target_screen))
    return
  end

  if cell_index then
    move_client_to_cell(c, cell_index, target_screen, layout)
    return
  end

  local picker_lines = {}
  for i, _ in ipairs(layout.cells) do
    local apps_in_cell = {}
    for app_name, app_config in pairs(layout.apps or {}) do
      if app_config.cell == i then
        table.insert(apps_in_cell, app_name)
      end
    end

    local app_list = #apps_in_cell > 0 and table.concat(apps_in_cell, ", ") or "(empty)"
    table.insert(picker_lines, string.format("%d  %s", i, app_list))
  end

  start_numeric_picker(
    string.format("Move %s on %s to cell", c.class or "window", helpers.get_screen_label(target_screen)),
    picker_lines,
    #layout.cells,
    function(index)
      move_client_to_cell(c, index, target_screen, layout)
    end
  )
end

return M
