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

-- Notification modules (loaded lazily to avoid circular dependency)
local notifications = nil
local dnd = nil

-- ============================================================================
-- COLORS - Derived from theme with fallbacks
-- ============================================================================

local colors = {
    -- Base colors (from theme)
    base = beautiful.bg_normal,
    surface0 = beautiful.bg_focus,
    surface1 = beautiful.taglist_bg_hover or "#45475a",
    surface2 = "#585b70",

    -- Text colors (from theme)
    text = beautiful.fg_normal,
    subtext0 = "#a6adc8",
    subtext1 = "#bac2de",

    -- Accent colors (matching theme)
    blue = beautiful.fg_focus or "#89b4fa",
    sapphire = "#74c7ec",
    sky = "#89dceb",
    teal = "#94e2d5",
    green = "#a6e3a1",
    yellow = "#f9e2af",
    peach = "#fab387",
    maroon = "#eba0ac",
    red = beautiful.bg_urgent or "#f38ba8",
    pink = "#f5c2e7",
    mauve = beautiful.hotkeys_modifiers_fg or "#cba6f7",
    lavender = "#b4befe",
}

-- ============================================================================
-- TYPOGRAPHY
-- ============================================================================

local font_family = "BerkeleyMono Nerd Font"

local fonts = {
    clock = font_family .. " Bold 15",
    data = font_family .. " 14",
    icon = font_family .. " 16",
}

-- ============================================================================
-- NERD FONT ICONS
-- ============================================================================

local icons = {
    launcher = "󰀻",
    cpu = "󰘚",
    ram = "󰍛",
    disk = "󰋊",
    upload = "󰕒",
    download = "󰇚",
    clock = "󰥔",
    dot = "•",
    dnd_normal = "󰂚",    -- Bell icon
    dnd_enabled = "󰂛",   -- Bell-off icon
}

-- ============================================================================
-- SPACING
-- ============================================================================

local spacing = {
    wibar_height = 36,
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

-- Brightness Widget - Arc style (laptops only - check for backlight hardware)
local brightness_widget_display = nil
local has_backlight = false
local backlight_handle = io.popen("ls /sys/class/backlight/ 2>/dev/null")
if backlight_handle then
    local backlight_result = backlight_handle:read("*a")
    backlight_handle:close()
    has_backlight = backlight_result ~= nil and backlight_result ~= ""
end
if has_backlight then
    brightness_widget_display = brightness_widget({
        type = 'arc',
        program = 'brightnessctl',
        step = 5,
        size = 18,
        arc_thickness = 2,
        tooltip = true,
    })
end

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

-- Filesystem Widget - Auto-detect real disk mounts
local function get_disk_mounts()
    local mounts = {}
    local dominated_types = {
        ext4 = true, ext3 = true, ext2 = true,
        xfs = true, btrfs = true, zfs = true,
        ntfs = true, fuseblk = true,
        exfat = true, f2fs = true, jfs = true, reiserfs = true,
    }

    local handle = io.popen("df -T 2>/dev/null | tail -n +2")
    if handle then
        for line in handle:lines() do
            local fs, fstype, size, used, avail, percent, mount =
                line:match("(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(.+)")
            if fstype and dominated_types[fstype] and mount then
                table.insert(mounts, mount)
            end
        end
        handle:close()
    end

    -- Ensure root is always first if present
    table.sort(mounts, function(a, b)
        if a == "/" then return true end
        if b == "/" then return false end
        return a < b
    end)

    -- Fallback to root if nothing detected
    if #mounts == 0 then
        mounts = { "/" }
    end

    return mounts
end

local fs_widget_display = fs_widget({
    mounts = get_disk_mounts(),
    timeout = 60,
})

-- Logout Menu Widget
local logout_widget_display = logout_menu_widget({
    font = fonts.data,
    onlock = function() awful.spawn.with_shell('i3lock -c ' .. colors.base:gsub("#", "")) end,
})

-- ============================================================================
-- LAUNCHER WIDGET (Start Menu)
-- ============================================================================

local launcher_widget = wibox.widget {
    {
        {
            markup = string.format('<span foreground="%s">%s</span>', colors.mauve, icons.launcher),
            font = fonts.icon,
            widget = wibox.widget.textbox,
        },
        left = 4,
        right = 4,
        widget = wibox.container.margin,
    },
    layout = wibox.layout.fixed.horizontal,
}

-- Click handler will be connected in create_wibar (needs access to mymainmenu)

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
        left = 2,
        right = spacing.icon_gap + 2,
        widget = wibox.container.margin,
    },
    {
        id = "value",
        markup = string.format('<span foreground="%s">0%%</span>', colors.text),
        font = fonts.data,
        forced_width = 42,  -- Fixed width prevents layout shift
        widget = wibox.widget.textbox,
    },
    layout = wibox.layout.fixed.horizontal,
}

local cpu_prev = { total = 0, idle = 0 }

awful.widget.watch('bash -c "grep \'^cpu \' /proc/stat"', 2,
    function(widget, stdout)
        local user, nice, system, idle, iowait, irq, softirq, steal =
            stdout:match('cpu%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)')

        if user then
            local total = user + nice + system + idle + iowait + irq + softirq + steal
            local diff_idle = idle - cpu_prev.idle
            local diff_total = total - cpu_prev.total
            local usage = 0
            if diff_total > 0 then
                usage = math.floor((1 - diff_idle / diff_total) * 100 + 0.5)
            end
            cpu_prev.total = total
            cpu_prev.idle = idle

            cpu_widget_display:get_children_by_id("value")[1].markup =
                string.format('<span foreground="%s">%d%%</span>', colors.text, usage)
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
            forced_width = 20,
            widget = wibox.widget.textbox,
        },
        left = 2,
        right = spacing.icon_gap,
        widget = wibox.container.margin,
    },
    {
        id = "value",
        markup = string.format('<span foreground="%s">0%%</span>', colors.text),
        font = fonts.data,
        forced_width = 42,  -- Fixed width prevents layout shift
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
        forced_width = 52,  -- Fixed width prevents layout shift
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
        forced_width = 52,  -- Fixed width prevents layout shift
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
-- DND (DO NOT DISTURB) WIDGET
-- ============================================================================

local dnd_widget = wibox.widget {
    {
        {
            id = "icon",
            markup = string.format('<span foreground="%s">%s</span>', colors.blue, icons.dnd_normal),
            font = fonts.icon,
            forced_width = 20,
            forced_height = 20,
            align = "center",
            valign = "center",
            widget = wibox.widget.textbox,
        },
        left = 4,
        right = 4,
        widget = wibox.container.margin,
    },
    valign = "center",
    widget = wibox.container.place,
}

-- Update icon based on DND state
local function update_dnd_icon()
    if not dnd then return end
    local icon_widget = dnd_widget:get_children_by_id("icon")[1]
    if dnd.is_enabled() then
        icon_widget.markup = string.format('<span foreground="%s">%s</span>', colors.red, icons.dnd_enabled)
    else
        icon_widget.markup = string.format('<span foreground="%s">%s</span>', colors.blue, icons.dnd_normal)
    end
end

-- Click handlers (modules loaded lazily on first interaction)
dnd_widget:connect_signal("button::press", function(_, _, _, button)
    -- Lazy load notifications module
    if not notifications then
        notifications = require("notifications")
        dnd = notifications.dnd
        -- Connect signal now that module is loaded
        dnd.connect_signal("state::changed", function()
            update_dnd_icon()
        end)
    end

    if button == 1 then  -- Left click: toggle DND
        dnd.toggle()
    end
end)

-- Hover effect
dnd_widget:connect_signal("mouse::enter", function()
    if not dnd then return end
    local icon_widget = dnd_widget:get_children_by_id("icon")[1]
    local color = dnd.is_enabled() and colors.maroon or colors.sapphire
    local icon = dnd.is_enabled() and icons.dnd_enabled or icons.dnd_normal
    icon_widget.markup = string.format('<span foreground="%s">%s</span>', color, icon)
end)

dnd_widget:connect_signal("mouse::leave", function()
    update_dnd_icon()
end)

-- ============================================================================
-- WIBAR CREATION
-- ============================================================================

function wibar_config.create_wibar(s, taglist_buttons, tasklist_buttons, mainmenu)
    -- Promptbox for each screen
    s.mypromptbox = awful.widget.prompt()

    -- Connect launcher click handler (needs mainmenu from rc.lua)
    if mainmenu then
        launcher_widget:buttons(awful.util.table.join(
            awful.button({}, 1, function() mainmenu:show() end)
        ))
    end

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

    -- Helper: Update fallback icon visibility based on whether app has an icon
    local function update_tasklist_icon(self, c)
        local icon_widget = self:get_children_by_id('icon_role')[1]
        local fallback = self:get_children_by_id('fallback_icon')[1]
        if c.icon == nil then
            fallback.visible = true
            icon_widget.visible = false
        else
            fallback.visible = false
            icon_widget.visible = true
        end
    end

    -- Tasklist (icons only, centered) with fallback for missing icons
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
                    {
                        id = 'icon_role',
                        forced_height = 24,
                        forced_width = 24,
                        widget = wibox.widget.imagebox,
                    },
                    {
                        id = 'fallback_icon',
                        markup = string.format('<span foreground="%s">󰣆</span>', colors.subtext0),
                        font = font_family .. " 18",
                        forced_height = 24,
                        forced_width = 24,
                        align = "center",
                        valign = "center",
                        visible = false,
                        widget = wibox.widget.textbox,
                    },
                    layout = wibox.layout.stack,
                },
                margins = 3,
                widget = wibox.container.margin,
            },
            id = 'background_role',
            widget = wibox.container.background,
            create_callback = function(self, c) update_tasklist_icon(self, c) end,
            update_callback = function(self, c) update_tasklist_icon(self, c) end,
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
    -- STACKED LAYOUT - Tasklist truly centered on screen
    -- ========================================================================

    s.mywibox:setup {
        layout = wibox.layout.stack,

        -- LAYER 1 (bottom): Tasklist - truly centered on full screen width
        {
            s.mytasklist,
            halign = "center",
            valign = "center",
            widget = wibox.container.place,
        },

        -- LAYER 2 (top): Left and right widgets
        {
            layout = wibox.layout.align.horizontal,

            -- LEFT: Launcher + Monitoring widgets
            {
                layout = wibox.layout.fixed.horizontal,
                create_spacer(spacing.widget),
                launcher_widget,
                create_spacer(spacing.section),
                cpu_widget_display,
                create_spacer(spacing.widget),
                ram_widget_display,
                create_spacer(spacing.section),
                net_widget_display,
                create_spacer(spacing.section),
            },

            -- CENTER: Empty (tasklist is in bottom layer)
            nil,

            -- RIGHT: Controls, systray, clock, logout
            {
                layout = wibox.layout.fixed.horizontal,

                -- Disk usage
                fs_widget_display,
                create_spacer(spacing.section),

                -- Controls (battery if laptop, brightness if laptop, volume)
                battery_widget_display and battery_widget_display or nil,
                battery_widget_display and create_spacer(spacing.widget) or nil,
                brightness_widget_display and brightness_widget_display or nil,
                brightness_widget_display and create_spacer(spacing.widget) or nil,
                volume_widget_display,
                create_spacer(spacing.section),

                -- System tray (vertically centered)
                {
                    systray,
                    valign = 'center',
                    widget = wibox.container.place,
                },
                create_spacer(spacing.section),

                -- DND (notifications) widget
                dnd_widget,
                create_spacer(spacing.widget),

                -- Clock
                clock_widget,
                create_spacer(spacing.widget),

                -- Logout
                logout_widget_display,
                create_spacer(spacing.section),
            },
        },
    }
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

wibar_config.volume_widget = volume_widget
wibar_config.brightness_widget = brightness_widget

return wibar_config
