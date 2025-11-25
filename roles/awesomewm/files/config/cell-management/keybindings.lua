-- keybindings.lua - Keyboard shortcut definitions (AwesomeWM 4.3 compatible)
local awful = require("awful")
local gears = require("gears")
local summon = require("cell-management.summon")
local apps = require("cell-management.apps")
local layout_manager = require("cell-management.layout-manager")
local config = require("cell-management.config")

-- Simple same-class window cycling (no external dependencies)
local function cycle_same_class()
  local focused = client.focus
  if not focused then return end

  local target_class = focused.class
  if not target_class then return end

  -- Get all clients with same class
  local same_class_clients = {}
  for _, c in ipairs(client.get()) do
    if c.class == target_class and not c.minimized then
      table.insert(same_class_clients, c)
    end
  end

  if #same_class_clients <= 1 then return end  -- Nothing to cycle

  -- Find current index and cycle to next
  local current_idx = 1
  for i, c in ipairs(same_class_clients) do
    if c == focused then
      current_idx = i
      break
    end
  end

  local next_idx = (current_idx % #same_class_clients) + 1
  local next_client = same_class_clients[next_idx]

  next_client:jump_to()
  next_client:raise()
end

-- Create F13 modal placeholder
local summon_modal

-- Build summon modal keybindings dynamically
local summon_bindings = {}
for app_name, config in pairs(apps) do
  table.insert(summon_bindings, {
    {}, config.summon,
    function()
      summon(app_name)
      if summon_modal then
        summon_modal:stop()
      end
    end
  })
end

-- Initialize the F13 modal
-- NOTE: timeout = 1 provides auto-exit after 1 second (mimics Hammerspoon)
summon_modal = awful.keygrabber {
  keybindings = summon_bindings,
  stop_key = 'Escape',
  stop_event = 'press',
  timeout = 1,
  autostart = false,
}


-- Create F16 macros modal placeholder
local macro_modal

-- Build F16 macro keybindings
local macro_bindings = {
  -- s: Screenshot with flameshot
  {{}, 's', function()
    awful.spawn("flameshot gui -c -s")
    if macro_modal then macro_modal:stop() end
  end},

  -- e: Emoji picker with rofimoji
  {{}, 'e', function()
    awful.spawn("rofimoji")
    if macro_modal then macro_modal:stop() end
  end},

  -- a: Cycle through windows of same application
  {{}, 'a', function()
    if macro_modal then macro_modal:stop() end
    cycle_same_class()
  end},

  -- g: GUI Settings menu (rofi picker)
  {{}, 'g', function()
    if macro_modal then macro_modal:stop() end
    awful.spawn.easy_async_with_shell([[
      printf '%s\n' "Audio (pavucontrol)" "Display (arandr)" "GTK Themes (lxappearance)" "Bluetooth (blueman-manager)" "Network (nm-connection-editor)" "Power (xfce4-power-manager-settings)" | rofi -dmenu -i -p "Settings" | sed 's/.*(\(.*\))/\1/' | xargs -I{} sh -c '{}'
    ]], function() end)
  end},
}

-- Initialize the F16 macro modal
-- NOTE: timeout = 1 provides auto-exit after 1 second (mimics Hammerspoon)
macro_modal = awful.keygrabber {
  keybindings = macro_bindings,
  stop_key = 'Escape',
  stop_event = 'press',
  timeout = 1,
  autostart = false,
}

-- Use shared hyper key definition
local hyper = config.hyper

-- Export global keybindings for rc.lua to register (v4.3 compatible)
local M = {}

M.globalkeys = gears.table.join(
  -- F13 modal triggers (hierarchy of fallbacks)
  awful.key({}, 'XF86Tools', function()
    summon_modal:start()
  end, {description = 'Summon mode (XF86Tools)', group = 'launcher'}),

  awful.key({}, '#191', function()
    summon_modal:start()
  end, {description = 'Summon mode (keycode 191)', group = 'launcher'}),

  awful.key({}, 'F13', function()
    summon_modal:start()
  end, {description = 'Summon mode (F13)', group = 'launcher'}),

  -- F16 macro modal triggers (hierarchy of fallbacks)
  awful.key({}, 'F16', function()
    macro_modal:start()
  end, {description = 'Macro mode (F16)', group = 'launcher'}),

  awful.key({}, 'XF86Launch5', function()
    macro_modal:start()
  end, {description = 'Macro mode (XF86Launch5)', group = 'launcher'}),

  awful.key({}, '#194', function()
    macro_modal:start()
  end, {description = 'Macro mode (keycode 194)', group = 'launcher'}),

  -- Window focus navigation (Hyper + hjkl)
  awful.key(hyper, 'h', function()
    awful.client.focus.global_bydirection('left')
    if client.focus then client.focus:raise() end
  end, {description = 'Focus left', group = 'client'}),

  awful.key(hyper, 'j', function()
    awful.client.focus.global_bydirection('down')
    if client.focus then client.focus:raise() end
  end, {description = 'Focus down', group = 'client'}),

  awful.key(hyper, 'k', function()
    awful.client.focus.global_bydirection('up')
    if client.focus then client.focus:raise() end
  end, {description = 'Focus up', group = 'client'}),

  awful.key(hyper, 'l', function()
    awful.client.focus.global_bydirection('right')
    if client.focus then client.focus:raise() end
  end, {description = 'Focus right', group = 'client'}),

  -- Layout management (Hyper + p/;/u)
  awful.key(hyper, 'p', function()
    layout_manager.select_layout()
  end, {description = 'Pick layout', group = 'layout'}),

  awful.key(hyper, ';', function()
    layout_manager.select_next_variant()
  end, {description = 'Next layout', group = 'layout'}),

  awful.key(hyper, 'u', function()
    layout_manager.bind_to_cell()
  end, {description = 'Bind window to cell', group = 'layout'})
)

return M
