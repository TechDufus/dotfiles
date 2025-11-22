-- wibar.lua - Flat status bar with Catppuccin Mocha theme
-- Clean, minimal design with spaced widgets (no container backgrounds)

local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local beautiful = require("beautiful")

-- Load awesome-wm-widgets
local volume_widget = require("awesome-wm-widgets.volume-widget.volume")
local brightness_widget = require("awesome-wm-widgets.brightness-widget.brightness")
local calendar_widget = require("awesome-wm-widgets.calendar-widget.calendar")
local logout_menu_widget = require("awesome-wm-widgets.logout-menu-widget.logout-menu")
local fs_widget = require("awesome-wm-widgets.fs-widget.fs-widget")

-- Only load battery on laptops (check if battery exists)
local battery_widget = nil
local f = io.open("/sys/class/power_supply/BAT0/capacity", "r")
if f ~= nil then
    io.close(f)
    battery_widget = require("awesome-wm-widgets.batteryarc-widget.batteryarc")
end

local wibar_config = {}

-- ============================================================================
-- CATPPUCCIN MOCHA COLOR PALETTE
-- ============================================================================

local colors = {
    -- Base colors
    base = beautiful.bg_normal or "#1e1e2e",
    surface0 = beautiful.bg_focus or "#313244",
    surface1 = "#45475a",
    surface2 = "#585b70",

    -- Text colors
    text = beautiful.fg_normal or "#cdd6f4",
    subtext0 = "#a6adc8",
    subtext1 = "#bac2de",

    -- Accent colors
    blue = "#89b4fa",
    sapphire = "#74c7ec",
    sky = "#89dceb",
    teal = "#94e2d5",
    green = "#a6e3a1",
    yellow = "#f9e2af",
    peach = "#fab387",
    maroon = "#eba0ac",
    red = "#f38ba8",
    pink = "#f5c2e7",
    mauve = "#cba6f7",
    lavender = "#b4befe",
}

-- ============================================================================
-- TYPOGRAPHY
-- ============================================================================

local font_family = "BerkeleyMono Nerd Font"

local fonts = {
    clock = font_family .. " Bold 11",
    data = font_family .. " 10",
    icon = font_family .. " 12",
}

-- ============================================================================
-- NERD FONT ICONS
-- ============================================================================

local icons = {
    cpu = "󰘚",
    ram = "󰍛",
    disk = "󰋊",
    upload = "󰕒",
    download = "󰇚",
    clock = "󰥔",
    dot = "•",
}

-- ============================================================================
-- SPACING
-- ============================================================================

local spacing = {
    wibar_height = 28,
    section = 24,      -- Between major sections
    widget = 16,       -- Between widgets in same section
    icon_gap = 6,      -- Between icon and value
}

-- ============================================================================
-- HELPER: Create spacing widget
-- ============================================================================

local function create_spacer(width)
    return wibox.widget {
        orientation = 'vertical',
        forced_width = width or spacing.widget,
        opacity = 0,
        widget = wibox.widget.separator,
    }
end

-- ============================================================================
-- CALENDAR CONFIGURATION
-- ============================================================================

local calendar = calendar_widget({
    theme = 'naughty',
    placement = 'top_right',
    radius = 8,
    start_sunday = false,
    week_numbers = false,
})

-- ============================================================================
-- WIDGET CONFIGURATIONS
-- ============================================================================

-- Volume Widget - Arc style
local volume_widget_display = volume_widget({
    widget_type = 'arc',
    thickness = 2,
    main_color = colors.blue,
    bg_color = colors.surface1,
    mute_color = colors.red,
    size = 18,
    device = 'pulse',
})

-- Brightness Widget - Arc style
local brightness_widget_display = brightness_widget({
    type = 'arc',
    program = 'brightnessctl',
    step = 5,
    size = 18,
    arc_thickness = 2,
    tooltip = true,
})

-- Battery Widget (laptops only)
local battery_widget_display = nil
if battery_widget then
    battery_widget_display = battery_widget({
        show_current_level = true,
        arc_thickness = 2,
        size = 18,
        main_color = colors.green,
        low_level_color = colors.maroon,
        medium_level_color = colors.yellow,
    })
end

-- Filesystem Widget
local fs_widget_display = fs_widget({
    mounts = { '/', '/home' },
    timeout = 60,
})

-- Logout Menu Widget
local logout_widget_display = logout_menu_widget({
    font = fonts.data,
    onlock = function() awful.spawn.with_shell('i3lock -c 1e1e2e') end,
})

-- ============================================================================
-- CPU WIDGET
-- ============================================================================

local cpu_widget_display = wibox.widget {
    {
        {
            markup = string.format('<span foreground="%s">%s</span>', colors.blue, icons.cpu),
            font = fonts.icon,
            widget = wibox.widget.textbox,
        },
        left = 2,   -- Nerd Font icons need extra space
        right = spacing.icon_gap + 2,
        widget = wibox.container.margin,
    },
    {
        id = "value",
        markup = string.format('<span foreground="%s">0%%</span>', colors.text),
        font = fonts.data,
        widget = wibox.widget.textbox,
    },
    layout = wibox.layout.fixed.horizontal,
}

awful.widget.watch('bash -c "top -bn1 | grep Cpu | sed \'s/.*, *\\([0-9.]*\\)%* id.*/\\1/\' | awk \'{print 100 - $1}\'"', 2,
    function(widget, stdout)
        local cpu_value = tonumber(stdout)
        if cpu_value then
            cpu_widget_display:get_children_by_id("value")[1].markup =
                string.format('<span foreground="%s">%.0f%%</span>', colors.text, cpu_value)
        end
    end
)

-- ============================================================================
-- RAM WIDGET
-- ============================================================================

local ram_widget_display = wibox.widget {
    {
        {
            markup = string.format('<span foreground="%s">%s</span>', colors.green, icons.ram),
            font = fonts.icon,
            widget = wibox.widget.textbox,
        },
        left = 2,
        right = spacing.icon_gap + 2,
        widget = wibox.container.margin,
    },
    {
        id = "value",
        markup = string.format('<span foreground="%s">0%%</span>', colors.text),
        font = fonts.data,
        widget = wibox.widget.textbox,
    },
    layout = wibox.layout.fixed.horizontal,
}

awful.widget.watch('bash -c "free | grep Mem | awk \'{print ($3/$2) * 100.0}\'"', 2,
    function(widget, stdout)
        local ram_value = tonumber(stdout)
        if ram_value then
            ram_widget_display:get_children_by_id("value")[1].markup =
                string.format('<span foreground="%s">%.0f%%</span>', colors.text, ram_value)
        end
    end
)

-- ============================================================================
-- NETWORK SPEED WIDGET
-- ============================================================================

local net_widget_display = wibox.widget {
    -- Upload icon
    {
        {
            markup = string.format('<span foreground="%s">%s</span>', colors.sky, icons.upload),
            font = fonts.icon,
            widget = wibox.widget.textbox,
        },
        left = 2,
        right = spacing.icon_gap + 2,
        widget = wibox.container.margin,
    },
    -- Upload value
    {
        id = "upload",
        markup = string.format('<span foreground="%s">0K</span>', colors.text),
        font = fonts.data,
        widget = wibox.widget.textbox,
    },
    create_spacer(spacing.widget),
    -- Download icon
    {
        {
            markup = string.format('<span foreground="%s">%s</span>', colors.sapphire, icons.download),
            font = fonts.icon,
            widget = wibox.widget.textbox,
        },
        left = 2,
        right = spacing.icon_gap + 2,
        widget = wibox.container.margin,
    },
    -- Download value
    {
        id = "download",
        markup = string.format('<span foreground="%s">0K</span>', colors.text),
        font = fonts.data,
        widget = wibox.widget.textbox,
    },
    layout = wibox.layout.fixed.horizontal,
}

-- Format bytes to human readable (compact)
local function format_speed(bytes)
    if bytes < 1024 then
        return string.format("%.0fB", bytes)
    elseif bytes < 1024 * 1024 then
        return string.format("%.0fK", bytes / 1024)
    else
        return string.format("%.1fM", bytes / 1024 / 1024)
    end
end

-- Track previous values for rate calculation
local net_prev = { tx = 0, rx = 0 }

awful.widget.watch('bash -c "cat /sys/class/net/$(ip route | grep default | awk \'{print $5}\' | head -1)/statistics/tx_bytes /sys/class/net/$(ip route | grep default | awk \'{print $5}\' | head -1)/statistics/rx_bytes 2>/dev/null"', 1,
    function(widget, stdout)
        local lines = {}
        for line in stdout:gmatch("[^\n]+") do
            table.insert(lines, tonumber(line) or 0)
        end
        if #lines >= 2 then
            local tx, rx = lines[1], lines[2]
            if net_prev.tx > 0 then
                local tx_rate = tx - net_prev.tx
                local rx_rate = rx - net_prev.rx
                net_widget_display:get_children_by_id("upload")[1].markup =
                    string.format('<span foreground="%s">%s</span>', colors.text, format_speed(tx_rate))
                net_widget_display:get_children_by_id("download")[1].markup =
                    string.format('<span foreground="%s">%s</span>', colors.text, format_speed(rx_rate))
            end
            net_prev.tx, net_prev.rx = tx, rx
        end
    end
)

-- ============================================================================
-- CLOCK WIDGET
-- ============================================================================

local clock_widget = wibox.widget {
    {
        {
            format = "%a %b %d, %H:%M",
            font = fonts.clock,
            widget = wibox.widget.textclock,
        },
        left = 4,  -- Prevent overlap from systray
        widget = wibox.container.margin,
    },
    layout = wibox.layout.fixed.horizontal,
}

clock_widget:connect_signal("button::press", function(_, _, _, button)
    if button == 1 then calendar.toggle() end
end)

-- ============================================================================
-- WIBAR CREATION
-- ============================================================================

function wibar_config.create_wibar(s, taglist_buttons, tasklist_buttons)
    -- Promptbox for each screen
    s.mypromptbox = awful.widget.prompt()

    -- Layout indicator
    s.mylayoutbox = awful.widget.layoutbox(s)
    s.mylayoutbox:buttons(gears.table.join(
        awful.button({}, 1, function() awful.layout.inc(1) end),
        awful.button({}, 3, function() awful.layout.inc(-1) end),
        awful.button({}, 4, function() awful.layout.inc(1) end),
        awful.button({}, 5, function() awful.layout.inc(-1) end)
    ))

    -- Taglist (hidden for cell-based workflow, but available)
    s.mytaglist = awful.widget.taglist {
        screen = s,
        filter = awful.widget.taglist.filter.all,
        buttons = taglist_buttons,
    }

    -- Tasklist (icons only, centered)
    s.mytasklist = awful.widget.tasklist {
        screen = s,
        filter = awful.widget.tasklist.filter.currenttags,
        buttons = tasklist_buttons,
        layout = {
            spacing = 8,
            layout = wibox.layout.fixed.horizontal,
        },
        widget_template = {
            {
                {
                    id = 'icon_role',
                    widget = wibox.widget.imagebox,
                },
                margins = 3,
                widget = wibox.container.margin,
            },
            id = 'background_role',
            widget = wibox.container.background,
        },
    }

    -- System tray
    local systray = wibox.widget.systray()
    systray:set_base_size(16)

    -- Create the wibar
    s.mywibox = awful.wibar({
        position = "top",
        screen = s,
        ontop = true,
        height = spacing.wibar_height,
        bg = colors.base,
        fg = colors.text,
    })

    -- ========================================================================
    -- FLAT LAYOUT - No container backgrounds, clean spacing
    -- ========================================================================

    s.mywibox:setup {
        layout = wibox.layout.align.horizontal,

        -- LEFT: Monitoring widgets
        {
            layout = wibox.layout.fixed.horizontal,
            create_spacer(spacing.section),
            cpu_widget_display,
            create_spacer(spacing.widget),
            ram_widget_display,
            create_spacer(spacing.section),
            net_widget_display,
            create_spacer(spacing.section),
        },

        -- CENTER: Tasklist
        {
            s.mytasklist,
            halign = "center",
            widget = wibox.container.place,
        },

        -- RIGHT: Controls, systray, clock, logout
        {
            layout = wibox.layout.fixed.horizontal,

            -- Disk usage
            fs_widget_display,
            create_spacer(spacing.section),

            -- Controls (battery if laptop, brightness, volume)
            battery_widget_display and battery_widget_display or nil,
            battery_widget_display and create_spacer(spacing.widget) or nil,
            brightness_widget_display,
            create_spacer(spacing.widget),
            volume_widget_display,
            create_spacer(spacing.section),

            -- System tray
            systray,
            create_spacer(spacing.section),

            -- Clock
            clock_widget,
            create_spacer(spacing.widget),

            -- Logout
            logout_widget_display,
            create_spacer(spacing.section),
        },
    }
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

wibar_config.volume_widget = volume_widget
wibar_config.brightness_widget = brightness_widget

return wibar_config
