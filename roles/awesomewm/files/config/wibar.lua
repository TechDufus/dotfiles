-- wibar.lua - Flat status bar with Catppuccin Mocha theme
-- Clean, minimal design with spaced widgets (no container backgrounds)

local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local beautiful = require("beautiful")
local naughty = require("naughty")
local dpi = beautiful.xresources.apply_dpi
local icon_resolver = require("icon-resolver")

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
    data = font_family .. " 11",
    icon = font_family .. " 16",
}

-- ============================================================================
-- NERD FONT ICONS
-- ============================================================================

local icons = {
    launcher = "󰀻",
    cpu = "󰘚",
    ram = "󰍛",
    gpu = "󰢮",           -- Graphics card icon
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
    wibar_height = dpi(28),
    section = dpi(24),      -- Between major sections
    widget = dpi(16),       -- Between widgets in same section
    icon_gap = dpi(6),      -- Between icon and value
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
-- Uses upower for time-to-empty estimation (more reliable than acpi on many laptops)
-- Left-click shows combined battery info + power profile popup
local battery_widget_display = nil
local battery_popup = nil

-- Combined battery info + power profile popup
local function toggle_battery_popup(widget_geometry)
    -- Toggle: if popup exists, hide it
    if battery_popup then
        battery_popup.visible = false
        battery_popup = nil
        return
    end

    -- Capture mouse position for popup placement
    local mouse_coords = mouse.coords()

    -- Fetch both battery info and power profiles concurrently
    local battery_info = nil
    local profiles_info = nil
    local active_profile = nil
    local profiles_list = {}

    local function build_popup()
        -- Wait until both async calls complete
        if battery_info == nil or profiles_info == nil then
            return
        end

        -- Build popup content
        local popup_widgets = {
            layout = wibox.layout.fixed.vertical,
            spacing = dpi(8),
        }

        -- Battery status section
        if battery_info and battery_info ~= "" then
            -- Header
            table.insert(popup_widgets, wibox.widget {
                markup = string.format('<span foreground="%s" font_weight="bold">Battery Status</span>', colors.blue),
                font = fonts.data,
                widget = wibox.widget.textbox,
            })

            -- Battery info lines
            for line in battery_info:gmatch("[^\r\n]+") do
                local trimmed = line:gsub("^%s+", ""):gsub("%s+$", "")
                if trimmed ~= "" then
                    table.insert(popup_widgets, wibox.widget {
                        markup = string.format('<span foreground="%s">%s</span>', colors.text, trimmed),
                        font = fonts.data,
                        widget = wibox.widget.textbox,
                    })
                end
            end

            -- Separator
            table.insert(popup_widgets, wibox.widget {
                forced_height = dpi(8),
                widget = wibox.container.background,
            })
        end

        -- Power profiles section
        if #profiles_list > 0 then
            -- Header
            table.insert(popup_widgets, wibox.widget {
                markup = string.format('<span foreground="%s" font_weight="bold">Power Profile</span>', colors.green),
                font = fonts.data,
                widget = wibox.widget.textbox,
            })

            -- Profile buttons
            for _, profile in ipairs(profiles_list) do
                local is_active = (profile == active_profile)
                local indicator = is_active and "●" or "○"
                local color = is_active and colors.green or colors.subtext0

                local profile_widget = wibox.widget {
                    {
                        {
                            markup = string.format('<span foreground="%s">%s %s</span>', color, indicator, profile),
                            font = fonts.data,
                            widget = wibox.widget.textbox,
                        },
                        left = dpi(4),
                        right = dpi(4),
                        top = dpi(2),
                        bottom = dpi(2),
                        widget = wibox.container.margin,
                    },
                    bg = colors.base,
                    widget = wibox.container.background,
                }

                -- Hover effect
                profile_widget:connect_signal("mouse::enter", function(w)
                    w.bg = colors.surface1
                end)
                profile_widget:connect_signal("mouse::leave", function(w)
                    w.bg = colors.base
                end)

                -- Click to set profile
                profile_widget:connect_signal("button::press", function(_, _, _, button)
                    if button == 1 then
                        awful.spawn.with_shell("powerprofilesctl set " .. profile)
                        naughty.notify({
                            title = "Power Profile",
                            text = "Switched to: " .. profile,
                            timeout = 2,
                        })
                        -- Close popup after selection
                        if battery_popup then
                            battery_popup.visible = false
                            battery_popup = nil
                        end
                    end
                end)

                table.insert(popup_widgets, profile_widget)
            end
        elseif profiles_info == "unavailable" then
            table.insert(popup_widgets, wibox.widget {
                markup = string.format('<span foreground="%s" style="italic">Power profiles unavailable</span>', colors.subtext0),
                font = fonts.data,
                widget = wibox.widget.textbox,
            })
        end

        -- Create the popup
        battery_popup = awful.popup {
            widget = {
                {
                    popup_widgets,
                    margins = dpi(12),
                    widget = wibox.container.margin,
                },
                bg = colors.base,
                shape = function(cr, w, h)
                    gears.shape.rounded_rect(cr, w, h, dpi(8))
                end,
                border_width = dpi(1),
                border_color = colors.surface1,
                widget = wibox.container.background,
            },
            placement = function(c)
                -- Position below the battery widget (use mouse x, below wibar)
                local screen_geo = awful.screen.focused().geometry
                local workarea = awful.screen.focused().workarea
                local popup_width = c.width or 200

                -- Center popup horizontally on mouse position, clamp to screen
                local x = mouse_coords.x - (popup_width / 2)
                x = math.max(screen_geo.x + dpi(4), x)
                x = math.min(screen_geo.x + screen_geo.width - popup_width - dpi(4), x)

                -- Position just below the wibar
                local y = workarea.y + dpi(4)

                c.x = x
                c.y = y
            end,
            ontop = true,
            visible = true,
        }

        -- Hide popup when clicking outside
        battery_popup:connect_signal("mouse::leave", function()
            -- Use a timer to allow clicking on items
            gears.timer.start_new(0.5, function()
                if battery_popup and not mouse.current_wibox then
                    battery_popup.visible = false
                    battery_popup = nil
                end
                return false
            end)
        end)
    end

    -- Fetch battery info
    awful.spawn.easy_async_with_shell(
        [[upower -i /org/freedesktop/UPower/devices/battery_BAT0 2>/dev/null | grep -E '(state|percentage|time to|energy-rate)' | sed 's/^[ \t]*//' | head -6]],
        function(stdout, _, _, _)
            battery_info = stdout or ""
            build_popup()
        end
    )

    -- Fetch power profiles
    awful.spawn.easy_async_with_shell(
        [[powerprofilesctl list 2>/dev/null]],
        function(stdout, _, _, exit_code)
            if exit_code ~= 0 or not stdout or stdout == "" then
                profiles_info = "unavailable"
            else
                profiles_info = "available"
                -- Parse profiles
                for line in stdout:gmatch("[^\r\n]+") do
                    local is_active, profile = line:match("^(%s?%*?)%s?([%w%-]+):$")
                    if profile and not line:match("^%s%s%s%s") then
                        table.insert(profiles_list, profile)
                        if is_active and is_active:match("%*") then
                            active_profile = profile
                        end
                    end
                end
            end
            build_popup()
        end
    )
end

if battery_widget then
    battery_widget_display = battery_widget({
        show_current_level = true,
        arc_thickness = 2,
        size = 18,
        main_color = colors.green,
        low_level_color = colors.maroon,
        medium_level_color = colors.yellow,
        show_notification_mode = "off",  -- Disable built-in acpi tooltip
    })
    -- Left-click: combined battery info + power profile menu (toggle)
    battery_widget_display:connect_signal("button::press", function(_, _, _, button)
        if button == 1 then  -- Left click
            toggle_battery_popup()
        end
    end)
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

-- ============================================================================
-- GRACEFUL SHUTDOWN HELPERS
-- ============================================================================

-- Gracefully close all clients then execute a command
-- This sends WM_DELETE_WINDOW to each app, allowing them to save state
local function graceful_shutdown(final_command)
    local all_clients = client.get()

    -- If no clients, just run the command immediately
    if #all_clients == 0 then
        awful.spawn.with_shell(final_command)
        return
    end

    -- Track remaining clients
    local remaining = #all_clients

    -- Timer for force-shutdown fallback (10 seconds max wait)
    local timeout_timer = gears.timer {
        timeout = 10,
        single_shot = true,
        callback = function()
            naughty.notify({
                preset = naughty.config.presets.normal,
                title = "Shutdown",
                text = "Timeout reached, forcing shutdown...",
                timeout = 2
            })
            -- Give the notification time to display
            gears.timer.start_new(1, function()
                awful.spawn.with_shell(final_command)
                return false
            end)
        end
    }

    -- Connect to client removal signal to track when all clients are gone
    local function check_complete()
        if #client.get() == 0 then
            timeout_timer:stop()
            -- Small delay to ensure everything is cleaned up
            gears.timer.start_new(0.5, function()
                awful.spawn.with_shell(final_command)
                return false
            end)
        end
    end

    -- Watch for client removal
    client.connect_signal("unmanage", check_complete)

    -- Start the timeout timer
    timeout_timer:start()

    -- Show notification
    naughty.notify({
        preset = naughty.config.presets.normal,
        title = "Shutdown",
        text = "Closing " .. remaining .. " application(s) gracefully...",
        timeout = 3
    })

    -- Send graceful close signal to all clients
    for _, c in ipairs(all_clients) do
        -- c:kill() sends WM_DELETE_WINDOW, allowing apps to save and close properly
        c:kill()
    end
end

-- Logout Menu Widget
local logout_widget_display = logout_menu_widget({
    font = fonts.data,
    onlock = function() awful.spawn.with_shell('i3lock -c ' .. colors.base:gsub("#", "")) end,
    onpoweroff = function() graceful_shutdown("systemctl poweroff") end,
    onreboot = function() graceful_shutdown("systemctl reboot") end,
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
        widget = wibox.widget.textbox,
    },
    -- Temperature
    {
        {
            id = "temp",
            markup = string.format('<span foreground="%s"> 0°</span>', colors.subtext0),
            font = fonts.data,
            widget = wibox.widget.textbox,
        },
        left = spacing.icon_gap,
        widget = wibox.container.margin,
    },
    layout = wibox.layout.fixed.horizontal,
}

local cpu_prev = { total = 0, idle = 0 }

-- Detect CPU thermal sensor at startup
-- Checks: thermal_zone (laptops), hwmon k10temp/coretemp (AMD/Intel), fallback thermal_zone0
local cpu_thermal_path = nil

local function file_exists(path)
    local f = io.open(path, "r")
    if f then f:close() return true end
    return false
end

local function read_file(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*l")
    f:close()
    return content
end

-- Check thermal_zone (laptops/Intel) then hwmon (desktops/AMD)
local i = 0
while not cpu_thermal_path do
    local zone_type = read_file("/sys/class/thermal/thermal_zone" .. i .. "/type")
    if not zone_type then break end
    if zone_type:match("x86_pkg") then
        cpu_thermal_path = "/sys/class/thermal/thermal_zone" .. i .. "/temp"
    end
    i = i + 1
end

i = 0
while not cpu_thermal_path do
    local name = read_file("/sys/class/hwmon/hwmon" .. i .. "/name")
    if not name then break end
    if name == "k10temp" or name == "coretemp" then
        local path = "/sys/class/hwmon/hwmon" .. i .. "/temp1_input"
        if file_exists(path) then cpu_thermal_path = path end
    end
    i = i + 1
end

if not cpu_thermal_path and file_exists("/sys/class/thermal/thermal_zone0/temp") then
    cpu_thermal_path = "/sys/class/thermal/thermal_zone0/temp"
end

-- CPU update using native Lua file read (no shell spawning)
local cpu_timer = gears.timer {
    timeout = 5,  -- Power optimization: reduced from 3s
    autostart = true,
    call_now = true,
    callback = function()
        local f = io.open("/proc/stat", "r")
        if not f then return end
        local line = f:read("*l")
        f:close()

        local user, nice, system, idle, iowait, irq, softirq, steal =
            line:match('cpu%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)')

        if user then
            user, nice, system, idle = tonumber(user), tonumber(nice), tonumber(system), tonumber(idle)
            iowait, irq, softirq, steal = tonumber(iowait), tonumber(irq), tonumber(softirq), tonumber(steal)

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

        -- Read CPU temperature
        if cpu_thermal_path then
            local temp_file = io.open(cpu_thermal_path, "r")
            if temp_file then
                local temp_raw = temp_file:read("*l")
                temp_file:close()
                if temp_raw then
                    local temp = math.floor(tonumber(temp_raw) / 1000 + 0.5)
                    cpu_widget_display:get_children_by_id("temp")[1].markup =
                        string.format('<span foreground="%s"> %d°</span>', colors.subtext0, temp)
                end
            end
        end
    end
}

-- ============================================================================
-- RAM WIDGET
-- ============================================================================

local ram_widget_display = wibox.widget {
    {
        {
            markup = string.format('<span foreground="%s">%s</span>', colors.green, icons.ram),
            font = fonts.icon,
            forced_width = dpi(22),
            widget = wibox.widget.textbox,
        },
        right = dpi(4),
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

-- RAM update using native Lua file read (no shell spawning)
local ram_timer = gears.timer {
    timeout = 5,  -- Power optimization: reduced from 3s
    autostart = true,
    call_now = true,
    callback = function()
        local f = io.open("/proc/meminfo", "r")
        if not f then return end
        local content = f:read("*a")
        f:close()

        local mem_total = tonumber(content:match("MemTotal:%s+(%d+)"))
        local mem_available = tonumber(content:match("MemAvailable:%s+(%d+)"))

        if mem_total and mem_available and mem_total > 0 then
            local usage = ((mem_total - mem_available) / mem_total) * 100
            ram_widget_display:get_children_by_id("value")[1].markup =
                string.format('<span foreground="%s">%.0f%%</span>', colors.text, usage)
        end
    end
}

-- ============================================================================
-- GPU WIDGET (NVIDIA only - hidden when no GPU present)
-- ============================================================================

-- Check for NVIDIA GPU (nvidia-smi availability)
local has_nvidia_gpu = false
local nvidia_check = io.popen("which nvidia-smi 2>/dev/null")
if nvidia_check then
    local nvidia_path = nvidia_check:read("*a")
    nvidia_check:close()
    has_nvidia_gpu = nvidia_path ~= nil and nvidia_path ~= ""
end

local gpu_widget_display = nil

if has_nvidia_gpu then
    gpu_widget_display = wibox.widget {
        -- GPU icon
        {
            {
                markup = string.format('<span foreground="%s">%s</span>', colors.peach, icons.gpu),
                font = fonts.icon,
                widget = wibox.widget.textbox,
            },
            left = 2,
            right = spacing.icon_gap + 2,
            widget = wibox.container.margin,
        },
        -- GPU utilization
        {
            id = "util",
            markup = string.format('<span foreground="%s">0%%</span>', colors.text),
            font = fonts.data,
            widget = wibox.widget.textbox,
        },
        -- VRAM usage
        {
            {
                id = "vram",
                markup = string.format('<span foreground="%s"> 0G</span>', colors.subtext0),
                font = fonts.data,
                widget = wibox.widget.textbox,
            },
            left = spacing.icon_gap,
            widget = wibox.container.margin,
        },
        -- Temperature
        {
            {
                id = "temp",
                markup = string.format('<span foreground="%s"> 0°</span>', colors.subtext0),
                font = fonts.data,
                widget = wibox.widget.textbox,
            },
            left = spacing.icon_gap,
            widget = wibox.container.margin,
        },
        layout = wibox.layout.fixed.horizontal,
    }

    -- Update GPU stats via nvidia-smi
    awful.widget.watch(
        'nvidia-smi --query-gpu=utilization.gpu,memory.used,temperature.gpu --format=csv,noheader,nounits',
        10,  -- Power optimization: reduced from 2s (nvidia-smi is expensive)
        function(widget, stdout)
            local util, vram_mb, temp = stdout:match("(%d+),%s*(%d+),%s*(%d+)")
            if util then
                gpu_widget_display:get_children_by_id("util")[1].markup =
                    string.format('<span foreground="%s">%s%%</span>', colors.text, util)

                -- Convert MB to GB for display
                local vram_gb = tonumber(vram_mb) / 1024
                gpu_widget_display:get_children_by_id("vram")[1].markup =
                    string.format('<span foreground="%s"> %.1fG</span>', colors.subtext0, vram_gb)

                gpu_widget_display:get_children_by_id("temp")[1].markup =
                    string.format('<span foreground="%s"> %s°</span>', colors.subtext0, temp)
            end
        end
    )
end

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

-- Detect default network interface ONCE at startup (not every update)
local default_iface = nil
local iface_handle = io.popen("ip route show default 2>/dev/null | head -1")
if iface_handle then
    local route_line = iface_handle:read("*l")
    iface_handle:close()
    if route_line then
        default_iface = route_line:match("dev%s+(%S+)")
    end
end

-- Track previous values for rate calculation
local net_prev = { tx = 0, rx = 0, time = 0 }

-- Network update using native Lua file read (no shell spawning per update)
local net_timer = gears.timer {
    timeout = 5,  -- Power optimization: reduced from 2s
    autostart = true,
    call_now = true,
    callback = function()
        if not default_iface then return end

        local tx_path = "/sys/class/net/" .. default_iface .. "/statistics/tx_bytes"
        local rx_path = "/sys/class/net/" .. default_iface .. "/statistics/rx_bytes"

        local tx_file = io.open(tx_path, "r")
        local rx_file = io.open(rx_path, "r")
        if not tx_file or not rx_file then
            if tx_file then tx_file:close() end
            if rx_file then rx_file:close() end
            return
        end

        local tx = tonumber(tx_file:read("*l")) or 0
        local rx = tonumber(rx_file:read("*l")) or 0
        tx_file:close()
        rx_file:close()

        local now = os.time()
        if net_prev.time > 0 then
            local elapsed = now - net_prev.time
            if elapsed > 0 then
                local tx_rate = (tx - net_prev.tx) / elapsed
                local rx_rate = (rx - net_prev.rx) / elapsed
                net_widget_display:get_children_by_id("upload")[1].markup =
                    string.format('<span foreground="%s">%s</span>', colors.text, format_speed(tx_rate))
                net_widget_display:get_children_by_id("download")[1].markup =
                    string.format('<span foreground="%s">%s</span>', colors.text, format_speed(rx_rate))
            end
        end
        net_prev.tx, net_prev.rx, net_prev.time = tx, rx, now
    end
}

-- ============================================================================
-- CLOCK WIDGET
-- ============================================================================

local clock_widget = wibox.widget {
    {
        {
            format = "%a %b %d, %I:%M %p",
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
            forced_width = dpi(20),
            forced_height = dpi(20),
            align = "center",
            valign = "center",
            widget = wibox.widget.textbox,
        },
        left = dpi(4),
        right = dpi(4),
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

    -- Helper: Update tasklist icon using high-resolution icon lookup
    -- Tries: 1) Desktop file icon (GNOME-style), 2) c.icon (_NET_WM_ICON), 3) Fallback
    local function update_tasklist_icon(self, c)
        local icon_widget = self:get_children_by_id('icon_role')[1]
        local fallback = self:get_children_by_id('fallback_icon')[1]

        -- Try high-resolution icon lookup first
        local icon_path = icon_resolver.get_icon_path(c)

        if icon_path then
            -- Use high-res icon from desktop file / icon theme
            icon_widget.image = icon_path
            icon_widget.visible = true
            fallback.visible = false
        elseif c.icon then
            -- Fall back to _NET_WM_ICON (may be low-res but better than nothing)
            icon_widget.image = c.icon
            icon_widget.visible = true
            fallback.visible = false
        else
            -- No icon found, show fallback
            fallback.visible = true
            icon_widget.visible = false
        end
    end

    -- Tasklist (icons only, centered) with fallback for missing icons
    s.mytasklist = awful.widget.tasklist {
        screen = s,
        filter = awful.widget.tasklist.filter.currenttags,
        buttons = tasklist_buttons,
        layout = {
            spacing = dpi(8),
            layout = wibox.layout.fixed.horizontal,
        },
        widget_template = {
            {
                {
                    {
                        id = 'icon_role',
                        forced_height = dpi(24),
                        forced_width = dpi(24),
                        widget = wibox.widget.imagebox,
                    },
                    {
                        id = 'fallback_icon',
                        markup = string.format('<span foreground="%s">󰣆</span>', colors.subtext0),
                        font = font_family .. " 18",
                        forced_height = dpi(24),
                        forced_width = dpi(24),
                        align = "center",
                        valign = "center",
                        visible = false,
                        widget = wibox.widget.textbox,
                    },
                    layout = wibox.layout.stack,
                },
                margins = dpi(3),
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
                -- GPU widget (desktop only - hidden on laptops without NVIDIA GPU)
                gpu_widget_display and create_spacer(spacing.widget) or nil,
                gpu_widget_display and gpu_widget_display or nil,
                create_spacer(spacing.section),
                net_widget_display,
                create_spacer(spacing.section),
            },

            -- CENTER: Empty (tasklist is in bottom layer)
            nil,

            -- RIGHT: Controls, systray, clock, logout
            -- Conditional widgets (battery, brightness) at far left so missing ones don't leave gaps
            {
                layout = wibox.layout.fixed.horizontal,

                -- Laptop-only widgets (at far left edge)
                battery_widget_display and battery_widget_display or nil,
                battery_widget_display and create_spacer(spacing.widget) or nil,
                brightness_widget_display and brightness_widget_display or nil,
                brightness_widget_display and create_spacer(spacing.section) or nil,

                -- Disk usage
                fs_widget_display,
                create_spacer(spacing.widget),

                -- Volume
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
