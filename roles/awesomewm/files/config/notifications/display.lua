-- display.lua - Styled notification popups (compatible with Ubuntu AwesomeWM 4.3)
local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local naughty = require("naughty")
local beautiful = require("beautiful")
local dpi = require("beautiful.xresources").apply_dpi

local rules_config = require("notifications.rules")
local dnd = require("notifications.dnd")

local M = {}

-- Catppuccin Mocha colors (matching wibar.lua)
local colors = {
    base = beautiful.notification_bg or "#1e1e2e",
    surface0 = "#313244",
    surface1 = "#45475a",
    text = beautiful.notification_fg or "#cdd6f4",
    subtext0 = "#a6adc8",
    blue = "#89b4fa",
    green = "#a6e3a1",
    red = "#f38ba8",
    yellow = "#f9e2af",
    mauve = "#cba6f7",
}

-- Urgency color mapping
local urgency_colors = {
    low = colors.subtext0,
    normal = colors.blue,
    critical = colors.red,
}

-- Get app-specific settings
local function get_app_settings(app_name)
    local settings = {}

    -- Start with defaults
    for k, v in pairs(rules_config.defaults) do
        settings[k] = v
    end

    -- Apply app-specific overrides
    if app_name and rules_config.apps[app_name] then
        for k, v in pairs(rules_config.apps[app_name]) do
            settings[k] = v
        end
    end

    return settings
end

-- Check if app is muted
local function is_muted(app_name)
    if not app_name then return false end

    for _, muted_app in ipairs(rules_config.muted) do
        if app_name == muted_app or app_name:lower() == muted_app:lower() then
            return true
        end
    end
    return false
end

-- Initialize notification display handler
function M.init()
    -- Configure naughty defaults for better looking notifications
    naughty.config.defaults.timeout = 5
    naughty.config.defaults.position = "top_right"
    naughty.config.defaults.margin = dpi(16)
    naughty.config.defaults.gap = dpi(8)
    naughty.config.defaults.ontop = true
    naughty.config.defaults.icon_size = dpi(48)
    naughty.config.defaults.border_width = dpi(2)

    -- Icon lookup paths
    naughty.config.icon_dirs = {
        "/usr/share/icons/Papirus-Dark/48x48/apps/",
        "/usr/share/icons/Papirus/48x48/apps/",
        "/usr/share/icons/hicolor/48x48/apps/",
        "/usr/share/icons/hicolor/scalable/apps/",
        "/usr/share/pixmaps/",
        "/var/lib/flatpak/exports/share/icons/hicolor/48x48/apps/",
        "/var/lib/flatpak/exports/share/icons/hicolor/scalable/apps/",
    }
    naughty.config.icon_formats = { "png", "svg", "gif", "xpm" }

    -- Use naughty.config.notify_callback to intercept ALL notifications (including D-Bus)
    naughty.config.notify_callback = function(args)
        args = args or {}

        -- Extract app_name from freedesktop_hints if not set directly
        if not args.app_name and args.freedesktop_hints then
            args.app_name = args.freedesktop_hints["desktop-entry"]
        end

        -- Debug logging
        print("[notifications.display] Notification from: " .. (args.app_name or "unknown"))

        -- Check DND mode
        if dnd.is_enabled() then
            -- Critical notifications bypass DND
            if args.urgency ~= "critical" then
                dnd.queue_notification(args)
                return nil  -- Don't show notification
            end
        end

        -- Check if app is muted
        if is_muted(args.app_name) then
            print("[notifications.display] Muted notification from: " .. (args.app_name or "unknown"))
            return nil  -- Don't show notification
        end

        -- Get app-specific settings
        local settings = get_app_settings(args.app_name)

        -- Apply settings to notification args
        if settings.timeout and not args.timeout then
            args.timeout = settings.timeout
        end

        -- Try to find icon if not provided
        if not args.icon and args.app_name then
            args.icon = args.app_name
        end

        -- Apply Catppuccin styling
        local border_color = urgency_colors[args.urgency] or colors.blue

        args.bg = args.bg or colors.base
        args.fg = args.fg or colors.text
        args.border_color = args.border_color or border_color
        args.border_width = args.border_width or dpi(2)
        args.margin = args.margin or dpi(settings.margin or 10)
        args.max_width = args.max_width or dpi(settings.max_width or 400)
        args.max_height = args.max_height or dpi(settings.max_height or 200)
        args.position = args.position or settings.position or "top_right"
        args.icon_size = args.icon_size or dpi(48)

        -- Use shape for rounded corners if supported
        if gears.shape then
            args.shape = function(cr, w, h)
                gears.shape.rounded_rect(cr, w, h, dpi(settings.border_radius or 12))
            end
        end

        -- Return modified args to show the notification
        return args
    end

    print("[notifications.display] Initialized notification display handler with notify_callback")
end

return M
