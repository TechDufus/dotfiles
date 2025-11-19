-- wibar.lua - Modern status bar with awesome-wm-widgets integration
-- Catppuccin Mocha themed wibar for AwesomeWM
-- Redesigned with visual grouping, semantic colors, and improved typography

local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local beautiful = require("beautiful")

-- Load awesome-wm-widgets
local volume_widget = require("awesome-wm-widgets.volume-widget.volume")
local brightness_widget = require("awesome-wm-widgets.brightness-widget.brightness")
local cpu_widget = require("awesome-wm-widgets.cpu-widget.cpu-widget")
local ram_widget = require("awesome-wm-widgets.ram-widget.ram-widget")
local calendar_widget = require("awesome-wm-widgets.calendar-widget.calendar")
local net_speed_widget = require("awesome-wm-widgets.net-speed-widget.net-speed")
local logout_menu_widget = require("awesome-wm-widgets.logout-menu-widget.logout-menu")
local fs_widget = require("awesome-wm-widgets.fs-widget.fs-widget")
local apt_widget = require("awesome-wm-widgets.apt-widget.apt-widget")

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
-- Using beautiful.* theme values where available, fallback to explicit values
-- Semantic color assignments for clarity and maintainability

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

    -- Accent colors (semantic usage)
    blue = "#89b4fa",      -- Controls, primary actions
    sapphire = "#74c7ec",  -- Download, secondary info
    sky = "#89dceb",       -- Upload, tertiary info
    teal = "#94e2d5",      -- Success, positive states
    green = "#a6e3a1",     -- Battery, resources (good)
    yellow = "#f9e2af",    -- Warning, medium states
    peach = "#fab387",     -- Important, highlighted info
    maroon = "#eba0ac",    -- Critical low, errors
    red = "#f38ba8",       -- Mute, errors, danger
    pink = "#f5c2e7",      -- Special states
    mauve = "#cba6f7",     -- Tertiary actions
    lavender = "#b4befe",  -- Hints, secondary text

    -- Transparency
    transparent = "#00000000",
}

-- ============================================================================
-- TYPOGRAPHY HIERARCHY
-- ============================================================================
-- Consistent font sizing and weights across the wibar

-- Font family configuration (change this to use a different font everywhere)
local font_family = "BerkeleyMono Nerd Font"

local fonts = {
    clock = font_family .. " Bold 11",      -- Primary time display
    data = font_family .. " 10",            -- Widget data (CPU/RAM/Net)
    icon = font_family .. " 12",            -- Icon-only widgets
    tag = font_family .. " Medium 11",      -- Workspace tags
}

-- ============================================================================
-- NERD FONT ICONS
-- ============================================================================
-- Consistent icon set for all widgets using Nerd Fonts

local icons = {
    -- System widgets
    cpu = "󰘚",        -- nf-md-cpu
    ram = "󰍛",        -- nf-md-memory
    disk = "󰋊",       -- nf-md-harddisk

    -- Network
    upload = "󰕒",     -- nf-md-upload
    download = "󰇚",   -- nf-md-download

    -- Updates
    package = "󰏖",    -- nf-md-package_variant

    -- Time
    clock = "󰥔",      -- nf-md-clock
    calendar = "󰃭",   -- nf-md-calendar

    -- Separators
    dot = "•",
    arrow_right = "",
    arrow_left = "",
}

-- ============================================================================
-- SPACING CONSTANTS
-- ============================================================================
-- Consistent spacing throughout the wibar (8px system)

local spacing = {
    wibar_height = 32,        -- Total wibar height
    group = 8,                -- Between widget groups
    widget = 4,               -- Between individual widgets
    container_padding = 6,    -- Internal container padding
    separator = 1,            -- Separator width
}

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Create a rounded container for widget groups
-- Provides visual grouping with background and rounded corners
local function create_container(widget, bg_color, padding)
    return wibox.widget {
        {
            widget,
            left = padding or spacing.container_padding,
            right = padding or spacing.container_padding,
            widget = wibox.container.margin,
        },
        bg = bg_color or colors.surface0,
        shape = function(cr, width, height)
            gears.shape.rounded_rect(cr, width, height, 6)
        end,
        widget = wibox.container.background,
    }
end

-- Create a vertical separator between widget groups
local function create_separator()
    return wibox.widget {
        widget = wibox.widget.separator,
        orientation = 'vertical',
        forced_width = spacing.separator,
        color = colors.surface1,
        visible = true,
    }
end

-- Create transparent padding/spacing
local function create_padding(width)
    return wibox.widget {
        widget = wibox.widget.separator,
        orientation = 'vertical',
        forced_width = width or spacing.group,
        color = colors.transparent,
        visible = true,
    }
end

-- Create text widget with icon and data (for CPU/RAM/Net)
local function create_text_widget(icon, text_widget, icon_color, text_color)
    return wibox.widget {
        {
            markup = string.format('<span foreground="%s">%s</span>', icon_color or colors.blue, icon),
            font = fonts.icon,
            align = "center",
            forced_width = 20,  -- Fixed width to prevent icon clipping
            widget = wibox.widget.textbox,
        },
        {
            text = " ",
            widget = wibox.widget.textbox,
        },
        text_widget,
        layout = wibox.layout.fixed.horizontal,
    }
end

-- Add hover effect to interactive widgets
local function add_hover_effect(widget, hover_bg)
    local original_bg = widget.bg
    widget:connect_signal("mouse::enter", function()
        widget.bg = hover_bg or colors.surface1
    end)
    widget:connect_signal("mouse::leave", function()
        widget.bg = original_bg
    end)
    return widget
end

-- ============================================================================
-- CALENDAR CONFIGURATION
-- ============================================================================

local catppuccin_calendar = {
    theme = 'naughty',
    placement = 'top_right',
    radius = 12,
    start_sunday = false,
    week_numbers = false,
    auto_hide = true,
    timeout = 3,
}

-- ============================================================================
-- WIDGET CONFIGURATIONS
-- ============================================================================

-- Volume Widget - Arc style with blue accent
local volume_widget_display = volume_widget({
    widget_type = 'arc',
    thickness = 3,
    main_color = colors.blue,
    bg_color = colors.surface0,
    mute_color = colors.red,
    size = 22,
    device = 'pulse',
})

-- Brightness Widget - Arc style with yellow accent
local brightness_widget_display = brightness_widget({
    type = 'arc',
    program = 'brightnessctl',
    step = 5,
    size = 22,
    arc_thickness = 3,
    tooltip = true,
})

-- Battery Widget - Arc style with green/yellow/red states
local battery_widget_display = nil
if battery_widget then
    battery_widget_display = battery_widget({
        show_current_level = true,
        arc_thickness = 3,
        size = 22,
        main_color = colors.green,
        low_level_color = colors.maroon,
        medium_level_color = colors.yellow,
    })
end

-- CPU Widget - Icon + Text style (converting from graph)
local cpu_text = wibox.widget {
    text = "0%",
    font = fonts.data,
    align = "right",
    forced_width = 40,  -- Fixed width to prevent jumping
    widget = wibox.widget.textbox,
}

-- Update CPU text from widget data
awful.widget.watch('bash -c "top -bn1 | grep Cpu | sed \'s/.*, *\\([0-9.]*\\)%* id.*/\\1/\' | awk \'{print 100 - $1}\'"', 2,
    function(widget, stdout)
        local cpu_value = tonumber(stdout)
        if cpu_value then
            cpu_text.markup = string.format('<span foreground="%s">%.0f%%</span>', colors.blue, cpu_value)
        end
    end
)

local cpu_widget_display = create_text_widget(icons.cpu, cpu_text, colors.blue)

-- RAM Widget - Icon + Text style (converting from bar)
local ram_text = wibox.widget {
    text = "0%",
    font = fonts.data,
    align = "right",
    forced_width = 40,  -- Fixed width to prevent jumping
    widget = wibox.widget.textbox,
}

-- Update RAM text from widget data
awful.widget.watch('bash -c "free | grep Mem | awk \'{print ($3/$2) * 100.0}\'"', 2,
    function(widget, stdout)
        local ram_value = tonumber(stdout)
        if ram_value then
            ram_text.markup = string.format('<span foreground="%s">%.0f%%</span>', colors.green, ram_value)
        end
    end
)

local ram_widget_display = create_text_widget(icons.ram, ram_text, colors.green)

-- Network Speed Widget - Icon + Text with colored upload/download
local net_upload_text = wibox.widget {
    text = "0KB/s",
    font = fonts.data,
    align = "right",
    forced_width = 65,  -- Fixed width to prevent jumping (fits "999.9MB/s")
    widget = wibox.widget.textbox,
}

local net_download_text = wibox.widget {
    text = "0KB/s",
    font = fonts.data,
    align = "right",
    forced_width = 65,  -- Fixed width to prevent jumping (fits "999.9MB/s")
    widget = wibox.widget.textbox,
}

-- Update network speed text
awful.widget.watch('bash -c "cat /sys/class/net/$(ip route | grep default | awk \'{print $5}\' | head -1)/statistics/tx_bytes"', 1,
    function(widget, stdout)
        local tx_bytes = tonumber(stdout)
        if tx_bytes and widget.tx_prev then
            local tx_rate = (tx_bytes - widget.tx_prev)
            local tx_kb = tx_rate / 1024
            if tx_kb < 1024 then
                net_upload_text.markup = string.format('<span foreground="%s">%.0fKB/s</span>', colors.sky, tx_kb)
            else
                net_upload_text.markup = string.format('<span foreground="%s">%.1fMB/s</span>', colors.sky, tx_kb / 1024)
            end
        end
        widget.tx_prev = tx_bytes
    end
)

awful.widget.watch('bash -c "cat /sys/class/net/$(ip route | grep default | awk \'{print $5}\' | head -1)/statistics/rx_bytes"', 1,
    function(widget, stdout)
        local rx_bytes = tonumber(stdout)
        if rx_bytes and widget.rx_prev then
            local rx_rate = (rx_bytes - widget.rx_prev)
            local rx_kb = rx_rate / 1024
            if rx_kb < 1024 then
                net_download_text.markup = string.format('<span foreground="%s">%.0fKB/s</span>', colors.sapphire, rx_kb)
            else
                net_download_text.markup = string.format('<span foreground="%s">%.1fMB/s</span>', colors.sapphire, rx_kb / 1024)
            end
        end
        widget.rx_prev = rx_bytes
    end
)

local net_speed_widget_display = wibox.widget {
    {
        markup = string.format('<span foreground="%s">%s</span>', colors.sky, icons.upload),
        font = fonts.icon,
        align = "center",
        forced_width = 20,  -- Fixed width to prevent icon clipping
        widget = wibox.widget.textbox,
    },
    {
        text = " ",
        widget = wibox.widget.textbox,
    },
    net_upload_text,
    {
        text = "  ",
        widget = wibox.widget.textbox,
    },
    {
        markup = string.format('<span foreground="%s">%s</span>', colors.sapphire, icons.download),
        font = fonts.icon,
        align = "center",
        forced_width = 20,  -- Fixed width to prevent icon clipping
        widget = wibox.widget.textbox,
    },
    {
        text = " ",
        widget = wibox.widget.textbox,
    },
    net_download_text,
    layout = wibox.layout.fixed.horizontal,
}

-- Filesystem Widget - Icon-only with tooltip
local fs_widget_display = fs_widget({
    mounts = { '/', '/home' },
    timeout = 60,
})

-- APT Widget - Icon with badge, hides when 0 updates
local apt_widget_display = apt_widget({
    interval = 600,  -- Check every 10 minutes
})

-- Calendar Widget
local calendar = calendar_widget(catppuccin_calendar)

-- Logout Menu Widget - Keep as-is with Catppuccin lock color
local logout_widget_display = logout_menu_widget({
    font = fonts.data,
    onlock = function() awful.spawn.with_shell('i3lock -c 1e1e2e') end,
})

-- ============================================================================
-- CLOCK WIDGET
-- ============================================================================

local mytextclock = wibox.widget {
    {
        markup = string.format('<span foreground="%s">%s</span>', colors.blue, icons.clock),
        font = fonts.icon,
        align = "center",
        forced_width = 20,  -- Fixed width to prevent icon clipping
        widget = wibox.widget.textbox,
    },
    {
        text = " ",
        widget = wibox.widget.textbox,
    },
    {
        format = "%a %b %d, %H:%M",
        font = fonts.clock,
        widget = wibox.widget.textclock,
    },
    layout = wibox.layout.fixed.horizontal,
}

-- Attach calendar popup to clock (click handler only, no double-container)
-- The system_group will handle the container and hover effect
mytextclock:connect_signal("button::press", function(_, _, _, button)
    if button == 1 then  -- Left click
        calendar.toggle()
    end
end)

-- ============================================================================
-- KEYBOARD LAYOUT INDICATOR
-- ============================================================================

local mykeyboardlayout = awful.widget.keyboardlayout()

-- ============================================================================
-- WIBAR CREATION
-- ============================================================================

function wibar_config.create_wibar(s, taglist_buttons, tasklist_buttons)
    -- Create a promptbox for each screen
    s.mypromptbox = awful.widget.prompt()

    -- Create an imagebox widget for layout indicator
    s.mylayoutbox = awful.widget.layoutbox(s)
    s.mylayoutbox:buttons(gears.table.join(
        awful.button({}, 1, function() awful.layout.inc(1) end),
        awful.button({}, 3, function() awful.layout.inc(-1) end),
        awful.button({}, 4, function() awful.layout.inc(1) end),
        awful.button({}, 5, function() awful.layout.inc(-1) end)
    ))

    -- Create a taglist widget
    s.mytaglist = awful.widget.taglist {
        screen = s,
        filter = awful.widget.taglist.filter.all,
        buttons = taglist_buttons,
    }

    -- Create a tasklist widget (icons only)
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
                margins = 4,
                widget = wibox.container.margin,
            },
            id = 'background_role',
            widget = wibox.container.background,
        },
    }

    -- Create the wibox
    s.mywibox = awful.wibar({
        position = "top",
        screen = s,
        ontop = true,
        height = spacing.wibar_height,
        bg = colors.base,
        fg = colors.text,
    })

    -- ========================================================================
    -- WIDGET GROUP ASSEMBLY
    -- ========================================================================

    -- Group 1: System Monitoring (CPU, RAM, Net)
    local monitoring_group = create_container(
        wibox.widget {
            cpu_widget_display,
            create_padding(spacing.widget),
            create_separator(),
            create_padding(spacing.widget),
            ram_widget_display,
            create_padding(spacing.widget),
            create_separator(),
            create_padding(spacing.widget),
            net_speed_widget_display,
            layout = wibox.layout.fixed.horizontal,
        },
        colors.surface0
    )

    -- Group 2: Storage & Updates (Filesystem, APT)
    local storage_group = create_container(
        wibox.widget {
            fs_widget_display,
            create_padding(spacing.widget),
            create_separator(),
            create_padding(spacing.widget),
            apt_widget_display,
            layout = wibox.layout.fixed.horizontal,
        },
        colors.surface0
    )

    -- Group 3: Controls (Battery, Brightness, Volume)
    local controls_widgets = {
        layout = wibox.layout.fixed.horizontal,
    }

    -- Add battery if available
    if battery_widget_display then
        table.insert(controls_widgets, battery_widget_display)
        table.insert(controls_widgets, create_padding(spacing.widget))
        table.insert(controls_widgets, create_separator())
        table.insert(controls_widgets, create_padding(spacing.widget))
    end

    -- Add brightness
    table.insert(controls_widgets, brightness_widget_display)
    table.insert(controls_widgets, create_padding(spacing.widget))
    table.insert(controls_widgets, create_separator())
    table.insert(controls_widgets, create_padding(spacing.widget))

    -- Add volume
    table.insert(controls_widgets, volume_widget_display)

    local controls_group = create_container(
        wibox.widget(controls_widgets),
        colors.surface0
    )

    -- Group 4: System Tray
    local systray = wibox.widget.systray()
    systray:set_base_size(20)

    -- Group 5: Time & System (Keyboard, Clock, Logout)
    local system_group = create_container(
        wibox.widget {
            mykeyboardlayout,
            create_padding(spacing.widget),
            create_separator(),
            create_padding(spacing.widget),
            mytextclock,
            create_padding(spacing.widget),
            create_separator(),
            create_padding(spacing.widget),
            logout_widget_display,
            layout = wibox.layout.fixed.horizontal,
        },
        colors.surface0
    )

    -- Add hover effect to system group
    system_group = add_hover_effect(system_group, colors.surface1)

    -- ========================================================================
    -- FINAL WIBAR LAYOUT
    -- ========================================================================

    s.mywibox:setup {
        layout = wibox.layout.align.horizontal,
        {
            -- Left widgets: Prompt only (taglist hidden)
            layout = wibox.layout.fixed.horizontal,
            create_padding(spacing.group),
            s.mypromptbox,
        },
        -- Middle widget: Tasklist
        s.mytasklist,
        {
            -- Right widgets: All widget groups
            layout = wibox.layout.fixed.horizontal,
            monitoring_group,
            create_padding(spacing.group),
            storage_group,
            create_padding(spacing.group),
            controls_group,
            create_padding(spacing.group),
            systray,
            create_padding(spacing.group),
            system_group,
            create_padding(spacing.group),
        },
    }
end

-- ============================================================================
-- EXPORTS
-- ============================================================================
-- Export widget modules for keybindings in rc.lua

wibar_config.volume_widget = volume_widget
wibar_config.brightness_widget = brightness_widget

return wibar_config
