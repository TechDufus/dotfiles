-- keybindings.lua - Keyboard shortcut definitions (AwesomeWM 4.3 compatible)
local awful = require("awful")
local gears = require("gears")
local summon = require("cell-management.summon")
local apps = require("cell-management.apps")
local layout_manager = require("cell-management.layout-manager")
local cyclefocus = require("cyclefocus")

-- Create F13 modal placeholder
local summon_modal

-- Build summon modal keybindings dynamically
local summon_bindings = {}
for app_name, config in pairs(apps) do
  table.insert(summon_bindings, {
    {}, config.summon,  -- FIXED: empty modifiers table, not {'', ''}
    function()
      print("[DEBUG] Summon modal triggered for: " .. app_name)
      summon(app_name)
      if summon_modal then
        summon_modal:stop()  -- Exit modal after summon
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
  timeout = 1,  -- Auto-exit after 1 second
  autostart = false,
  start_callback = function()
    print("[DEBUG] F13 modal activated!")
  end,
  stop_callback = function()
    print("[DEBUG] F13 modal stopped")
  end,
  timeout_callback = function()
    print("[DEBUG] F13 modal timed out")
  end,
}

-- Configure cyclefocus for same-app window cycling
cyclefocus.cycle_filters = { cyclefocus.filters.same_class }

-- Create F16 macros modal placeholder
local macro_modal

-- Build F16 macro keybindings
local macro_bindings = {
  -- s: Screenshot with flameshot (copy to clipboard)
  {{}, 's', function()
    print("[DEBUG] F16 macro: Screenshot")
    awful.spawn("flameshot gui")  -- -c flag copies to clipboard
    if macro_modal then macro_modal:stop() end
  end},

  -- e: Emoji picker with rofimoji
  {{}, 'e', function()
    print("[DEBUG] F16 macro: Emoji picker")
    awful.spawn("rofimoji")
    if macro_modal then macro_modal:stop() end
  end},

  -- a: Cycle through windows of same application
  {{}, 'a', function()
    print("[DEBUG] F16 macro: Cycle same app windows")
    cyclefocus.cycle(1)  -- Cycle forward through same-class windows
    if macro_modal then macro_modal:stop() end
  end},
}

-- Initialize the F16 macro modal
-- NOTE: timeout = 1 provides auto-exit after 1 second (mimics Hammerspoon)
macro_modal = awful.keygrabber {
  keybindings = macro_bindings,
  stop_key = 'Escape',
  stop_event = 'press',
  timeout = 1,  -- Auto-exit after 1 second
  autostart = false,
  start_callback = function()
    print("[DEBUG] F16 macro modal activated!")
  end,
  stop_callback = function()
    print("[DEBUG] F16 macro modal stopped")
  end,
  timeout_callback = function()
    print("[DEBUG] F16 macro modal timed out")
  end,
}

-- Hyper key definition (Shift+Super+Alt+Ctrl on Linux)
-- NOTE: Can be changed to { 'Mod4', 'Shift' } for easier pressing
local hyper = { 'Shift', 'Mod4', 'Mod1', 'Control' }

-- Export global keybindings for rc.lua to register (v4.3 compatible)
local M = {}

M.globalkeys = gears.table.join(
  -- F13 modal triggers (hierarchy of fallbacks, matching Hyprland)
  -- Your actual F13 key!
  awful.key({}, 'XF86Tools', function()
    print("[DEBUG] XF86Tools pressed - starting modal")
    summon_modal:start()
  end, {description = 'Summon mode (XF86Tools)', group = 'launcher'}),

  -- Backup: raw keycode 191
  awful.key({}, '#191', function()
    print("[DEBUG] Keycode 191 pressed - starting modal")
    summon_modal:start()
  end, {description = 'Summon mode (keycode 191)', group = 'launcher'}),

  -- Fallback: symbolic F13
  awful.key({}, 'F13', function()
    print("[DEBUG] F13 pressed - starting modal")
    summon_modal:start()
  end, {description = 'Summon mode (F13)', group = 'launcher'}),

  -- F16 macro modal triggers (hierarchy of fallbacks)
  -- Symbolic F16
  awful.key({}, 'F16', function()
    print("[DEBUG] F16 pressed - starting macro modal")
    macro_modal:start()
  end, {description = 'Macro mode (F16)', group = 'launcher'}),

  -- Backup: XF86Launch5 (common F16 keysym)
  awful.key({}, 'XF86Launch5', function()
    print("[DEBUG] XF86Launch5 pressed - starting macro modal")
    macro_modal:start()
  end, {description = 'Macro mode (XF86Launch5)', group = 'launcher'}),

  -- Fallback: raw keycode 194 (common F16 keycode)
  awful.key({}, '#194', function()
    print("[DEBUG] Keycode 194 pressed - starting macro modal")
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
