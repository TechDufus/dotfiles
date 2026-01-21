-- keybindings.lua - Keyboard shortcut definitions (AwesomeWM 4.3 compatible)
local awful = require("awful")
local gears = require("gears")
local summon = require("cell-management.summon")
local apps = require("cell-management.apps")
local layout_manager = require("cell-management.layout-manager")
local user_config = require("cell-management.config")

-- Forward declaration for modals (referenced before definition)
local summon_modal, macro_modal

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

-- Initialize the F13 modal (summon_modal declared at top for double-tap logic)
-- Handles double-tap: if F13/CapsLock pressed while modal is open, switch to macro modal
summon_modal = awful.keygrabber {
  stop_key = 'Escape',
  stop_event = 'press',
  timeout = 1,  -- 1 second timeout for modal auto-close
  autostart = false,
  keypressed_callback = function(self, mod, key, event)
    -- Double-tap detection: F13 pressed again while summon modal is open
    -- This enables CapsLock double-tap on laptop keyboards to access macro modal
    if key == "F13" or key == "Caps_Lock" then
      self:stop()
      gears.timer.delayed_call(function()
        if macro_modal then macro_modal:start() end
      end)
      return
    end

    -- Check if it's a summon key
    for app_name, app_cfg in pairs(apps) do
      if app_cfg.summon == key then
        local app = app_name  -- Capture for closure
        self:stop()
        gears.timer.delayed_call(function()
          summon(app)
        end)
        return
      end
    end
    -- Any non-summon key also stops the modal
    self:stop()
  end,
}


-- Initialize the F16 macro modal
-- NOTE: timeout = 1 provides auto-exit after 1 second (mimics Hammerspoon)
-- Uses keypressed_callback with delayed_call pattern for clean keygrabber release
macro_modal = awful.keygrabber {
  stop_key = 'Escape',
  stop_event = 'press',
  timeout = 1,
  autostart = false,
  keypressed_callback = function(self, mod, key, event)
    -- s: Screenshot with flameshot
    if key == 's' then
      self:stop()
      gears.timer.delayed_call(function()
        awful.spawn("flameshot gui -c -s")
      end)
      return
    end

    -- e: Emoji picker with bemoji
    if key == 'e' then
      self:stop()
      gears.timer.delayed_call(function()
        awful.spawn(os.getenv("HOME") .. "/.local/bin/bemoji -cn --hist-limit 5")
      end)
      return
    end

    -- a: Cycle through windows of same application
    if key == 'a' then
      self:stop()
      gears.timer.delayed_call(function()
        cycle_same_class()
      end)
      return
    end

    -- g: GUI Settings menu (rofi picker)
    if key == 'g' then
      self:stop()
      gears.timer.delayed_call(function()
        awful.spawn.easy_async_with_shell([[
          printf '%s\n' "Audio (pavucontrol)" "Display (arandr)" "GTK Themes (lxappearance)" "Bluetooth (blueman-manager)" "Network (nm-connection-editor)" "Power (xfce4-power-manager-settings)" | rofi -dmenu -i -p "Settings" | sed 's/.*(\(.*\))/\1/' | xargs -I{} sh -c '{}'
        ]], function() end)
      end)
      return
    end

    -- Any non-macro key stops the modal
    self:stop()
  end,
}

-- Use shared hyper key definition
local hyper = user_config.hyper

-- Export global keybindings for rc.lua to register (v4.3 compatible)
local M = {}

M.globalkeys = gears.table.join(
  -- F13 modal triggers - direct summon modal
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
