-- notifications/init.lua - Notification system orchestrator
local awful = require("awful")
local gears = require("gears")
local naughty = require("naughty")

-- Load modules in dependency order
local rules = require("notifications.rules")
local dnd = require("notifications.dnd")
local display = require("notifications.display")

local M = {}

-- Hyper key definition (matching cell-management/keybindings.lua)
local hyper = { 'Shift', 'Mod4', 'Mod1', 'Control' }

-- Export globalkeys for rc.lua to register
M.globalkeys = gears.table.join(
    -- Toggle DND mode
    awful.key(hyper, 'n', function()
        dnd.toggle()
    end, {description = 'toggle DND mode', group = 'notifications'})
)

-- Initialize the notification system
function M.init()
    -- Initialize display handler (connects to request::display)
    display.init()

    -- Configure naughty presets (compatible with all AwesomeWM versions)
    naughty.config.presets.critical = {
        bg = "#f38ba8",
        fg = "#1e1e2e",
        timeout = 0,  -- Never auto-dismiss
    }

    naughty.config.presets.low = {
        timeout = 3,
    }

    naughty.config.presets.normal = {
        timeout = 5,
    }

    print("[notifications] Notification system initialized")
end

-- Export modules for external access
M.dnd = dnd
M.display = display
M.rules = rules

-- Initialize on load
M.init()

return M
