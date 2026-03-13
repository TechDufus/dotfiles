local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local hardware = require("widgets.hardware")
local popup_helpers = require("widgets.popup")

local M = {}

local function format_speed(bytes)
    if bytes < 1024 then
        return string.format("%.0fB", bytes)
    end
    if bytes < 1024 * 1024 then
        return string.format("%.0fK", bytes / 1024)
    end
    return string.format("%.1fM", bytes / 1024 / 1024)
end

local cpu_thermal_path = hardware.detect_cpu_thermal_path()
local default_iface = hardware.detect_default_iface()
local nvidia_available = hardware.has_nvidia_gpu()

local function create_cpu_popup(widget, shared, get_cpu_snapshot)
    local popup = awful.popup({
        visible = false,
        ontop = true,
        widget = {},
    })

    local refresh_timer
    local anchor_geometry = nil

    local function populate()
        awful.spawn.easy_async_with_shell(
            [[ps -eo pid=,comm=,%cpu=,%mem= --sort=-%cpu | head -n 6]],
            function(stdout)
                local snapshot = get_cpu_snapshot()
                local rows = {
                    spacing = shared.fixed_dpi(6),
                    layout = wibox.layout.fixed.vertical,
                }

                table.insert(rows, wibox.widget {
                    markup = string.format(
                        '<span foreground="%s" font_weight="bold">CPU %d%%</span>',
                        shared.colors.blue,
                        snapshot.usage or 0
                    ),
                    font = shared.fonts.data,
                    widget = wibox.widget.textbox,
                })

                if snapshot.temp then
                    table.insert(rows, wibox.widget {
                        markup = string.format(
                            '<span foreground="%s">Temperature %d°</span>',
                            shared.colors.subtext0,
                            snapshot.temp
                        ),
                        font = shared.fonts.data,
                        widget = wibox.widget.textbox,
                    })
                end

                table.insert(rows, wibox.widget {
                    forced_height = shared.fixed_dpi(4),
                    widget = wibox.container.background,
                })

                table.insert(rows, wibox.widget {
                    markup = string.format(
                        '<span foreground="%s" font_weight="bold">Top Processes</span>',
                        shared.colors.green
                    ),
                    font = shared.fonts.data,
                    widget = wibox.widget.textbox,
                })

                local found_process = false
                for line in stdout:gmatch("[^\r\n]+") do
                    local pid, command, cpu, mem = line:match("^%s*(%d+)%s+(.+)%s+([%d%.]+)%s+([%d%.]+)%s*$")
                    if pid and command and cpu and mem then
                        found_process = true
                        table.insert(rows, wibox.widget {
                            {
                                {
                                    markup = string.format(
                                        '<span foreground="%s">%s</span>',
                                        shared.colors.text,
                                        command
                                    ),
                                    font = shared.fonts.data,
                                    ellipsize = "end",
                                    forced_width = shared.fixed_dpi(150),
                                    widget = wibox.widget.textbox,
                                },
                                {
                                    markup = string.format(
                                        '<span foreground="%s">%s%% CPU</span>',
                                        shared.colors.subtext0,
                                        cpu
                                    ),
                                    font = shared.fonts.data,
                                    widget = wibox.widget.textbox,
                                },
                                {
                                    markup = string.format(
                                        '<span foreground="%s">%s%% MEM</span>',
                                        shared.colors.subtext0,
                                        mem
                                    ),
                                    font = shared.fonts.data,
                                    widget = wibox.widget.textbox,
                                },
                                spacing = shared.fixed_dpi(10),
                                layout = wibox.layout.fixed.horizontal,
                            },
                            widget = wibox.container.background,
                        })
                    end
                end

                if not found_process then
                    table.insert(rows, wibox.widget {
                        markup = string.format(
                            '<span foreground="%s">No process data available</span>',
                            shared.colors.subtext0
                        ),
                        font = shared.fonts.data,
                        widget = wibox.widget.textbox,
                    })
                end

                popup:setup(popup_helpers.create_frame(shared, rows))

                if anchor_geometry then
                    popup:move_next_to(anchor_geometry)
                end
            end
        )
    end

    refresh_timer = gears.timer {
        timeout = 3,
        autostart = false,
        callback = populate,
    }

    widget:connect_signal("button::press", function(_, _, _, button)
        if button ~= 1 then
            return
        end

        if popup.visible then
            popup.visible = false
            anchor_geometry = nil
            refresh_timer:stop()
            return
        end

        anchor_geometry = mouse.current_widget_geometry
        popup.visible = true
        populate()
        refresh_timer:start()
    end)

    popup:connect_signal("property::visible", function()
        if not popup.visible then
            anchor_geometry = nil
            refresh_timer:stop()
        end
    end)
end

local function create_cpu_widget(shared)
    local widget = wibox.widget {
        {
            {
                markup = string.format(
                    '<span foreground="%s">%s</span>',
                    shared.colors.blue,
                    shared.icons.cpu
                ),
                font = shared.fonts.icon,
                widget = wibox.widget.textbox,
            },
            left = 2,
            right = shared.spacing.icon_gap + 2,
            widget = wibox.container.margin,
        },
        {
            id = "value",
            markup = string.format('<span foreground="%s">0%%</span>', shared.colors.text),
            font = shared.fonts.data,
            widget = wibox.widget.textbox,
        },
        {
            {
                id = "temp",
                markup = string.format('<span foreground="%s"> 0°</span>', shared.colors.subtext0),
                font = shared.fonts.data,
                widget = wibox.widget.textbox,
            },
            left = shared.spacing.icon_gap,
            widget = wibox.container.margin,
        },
        layout = wibox.layout.fixed.horizontal,
    }

    local previous = { total = 0, idle = 0 }
    local state = { usage = 0, temp = nil }

    create_cpu_popup(widget, shared, function()
        return state
    end)

    gears.timer {
        timeout = 5,
        autostart = true,
        call_now = true,
        callback = function()
            local stat_file = io.open("/proc/stat", "r")
            if stat_file then
                local line = stat_file:read("*l")
                stat_file:close()

                local user, nice, system, idle, iowait, irq, softirq, steal =
                    line:match("cpu%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)")

                if user then
                    user = tonumber(user)
                    nice = tonumber(nice)
                    system = tonumber(system)
                    idle = tonumber(idle)
                    iowait = tonumber(iowait)
                    irq = tonumber(irq)
                    softirq = tonumber(softirq)
                    steal = tonumber(steal)

                    local total = user + nice + system + idle + iowait + irq + softirq + steal
                    local diff_idle = idle - previous.idle
                    local diff_total = total - previous.total
                    local usage = 0

                    if diff_total > 0 then
                        usage = math.floor((1 - diff_idle / diff_total) * 100 + 0.5)
                    end

                    previous.total = total
                    previous.idle = idle
                    state.usage = usage

                    widget:get_children_by_id("value")[1].markup =
                        string.format('<span foreground="%s">%d%%</span>', shared.colors.text, usage)
                end
            end

            if cpu_thermal_path then
                local temp_file = io.open(cpu_thermal_path, "r")
                if temp_file then
                    local temp_raw = temp_file:read("*l")
                    temp_file:close()
                    if temp_raw then
                        state.temp = math.floor(tonumber(temp_raw) / 1000 + 0.5)
                        widget:get_children_by_id("temp")[1].markup = string.format(
                            '<span foreground="%s"> %d°</span>',
                            shared.colors.subtext0,
                            state.temp
                        )
                    end
                end
            end
        end,
    }

    return widget
end

local function create_ram_widget(shared)
    local widget = wibox.widget {
        {
            {
                markup = string.format(
                    '<span foreground="%s">%s</span>',
                    shared.colors.green,
                    shared.icons.ram
                ),
                font = shared.fonts.icon,
                forced_width = shared.fixed_dpi(22),
                widget = wibox.widget.textbox,
            },
            right = shared.fixed_dpi(4),
            widget = wibox.container.margin,
        },
        {
            id = "value",
            markup = string.format('<span foreground="%s">0%%</span>', shared.colors.text),
            font = shared.fonts.data,
            widget = wibox.widget.textbox,
        },
        layout = wibox.layout.fixed.horizontal,
    }

    gears.timer {
        timeout = 5,
        autostart = true,
        call_now = true,
        callback = function()
            local mem_file = io.open("/proc/meminfo", "r")
            if not mem_file then
                return
            end

            local content = mem_file:read("*a")
            mem_file:close()

            local total = tonumber(content:match("MemTotal:%s+(%d+)"))
            local available = tonumber(content:match("MemAvailable:%s+(%d+)"))
            if total and available and total > 0 then
                local usage = ((total - available) / total) * 100
                widget:get_children_by_id("value")[1].markup =
                    string.format('<span foreground="%s">%.0f%%</span>', shared.colors.text, usage)
            end
        end,
    }

    return widget
end

local function create_gpu_widget(shared)
    if not nvidia_available then
        return nil
    end

    local widget = wibox.widget {
        {
            {
                markup = string.format(
                    '<span foreground="%s">%s</span>',
                    shared.colors.peach,
                    shared.icons.gpu
                ),
                font = shared.fonts.icon,
                widget = wibox.widget.textbox,
            },
            left = 2,
            right = shared.spacing.icon_gap + 2,
            widget = wibox.container.margin,
        },
        {
            id = "util",
            markup = string.format('<span foreground="%s">0%%</span>', shared.colors.text),
            font = shared.fonts.data,
            widget = wibox.widget.textbox,
        },
        {
            {
                id = "vram",
                markup = string.format('<span foreground="%s"> 0G</span>', shared.colors.subtext0),
                font = shared.fonts.data,
                widget = wibox.widget.textbox,
            },
            left = shared.spacing.icon_gap,
            widget = wibox.container.margin,
        },
        {
            {
                id = "temp",
                markup = string.format('<span foreground="%s"> 0°</span>', shared.colors.subtext0),
                font = shared.fonts.data,
                widget = wibox.widget.textbox,
            },
            left = shared.spacing.icon_gap,
            widget = wibox.container.margin,
        },
        layout = wibox.layout.fixed.horizontal,
    }

    awful.widget.watch(
        "nvidia-smi --query-gpu=utilization.gpu,memory.used,temperature.gpu --format=csv,noheader,nounits",
        10,
        function(_, stdout)
            local util, vram_mb, temp = stdout:match("(%d+),%s*(%d+),%s*(%d+)")
            if util then
                widget:get_children_by_id("util")[1].markup =
                    string.format('<span foreground="%s">%s%%</span>', shared.colors.text, util)
                widget:get_children_by_id("vram")[1].markup = string.format(
                    '<span foreground="%s"> %.1fG</span>',
                    shared.colors.subtext0,
                    tonumber(vram_mb) / 1024
                )
                widget:get_children_by_id("temp")[1].markup =
                    string.format('<span foreground="%s"> %s°</span>', shared.colors.subtext0, temp)
            end
        end
    )

    return widget
end

local function create_network_widget(shared)
    local widget = wibox.widget {
        {
            {
                markup = string.format(
                    '<span foreground="%s">%s</span>',
                    shared.colors.sky,
                    shared.icons.upload
                ),
                font = shared.fonts.icon,
                widget = wibox.widget.textbox,
            },
            left = 2,
            right = shared.spacing.icon_gap + 2,
            widget = wibox.container.margin,
        },
        {
            id = "upload",
            markup = string.format('<span foreground="%s">0K</span>', shared.colors.text),
            font = shared.fonts.data,
            widget = wibox.widget.textbox,
        },
        shared.create_spacer(shared.spacing.widget),
        {
            {
                markup = string.format(
                    '<span foreground="%s">%s</span>',
                    shared.colors.sapphire,
                    shared.icons.download
                ),
                font = shared.fonts.icon,
                widget = wibox.widget.textbox,
            },
            left = 2,
            right = shared.spacing.icon_gap + 2,
            widget = wibox.container.margin,
        },
        {
            id = "download",
            markup = string.format('<span foreground="%s">0K</span>', shared.colors.text),
            font = shared.fonts.data,
            widget = wibox.widget.textbox,
        },
        layout = wibox.layout.fixed.horizontal,
    }

    local previous = { tx = 0, rx = 0, time = 0 }

    gears.timer {
        timeout = 5,
        autostart = true,
        call_now = true,
        callback = function()
            if not default_iface then
                return
            end

            local tx_file = io.open("/sys/class/net/" .. default_iface .. "/statistics/tx_bytes", "r")
            local rx_file = io.open("/sys/class/net/" .. default_iface .. "/statistics/rx_bytes", "r")
            if not tx_file or not rx_file then
                if tx_file then
                    tx_file:close()
                end
                if rx_file then
                    rx_file:close()
                end
                return
            end

            local tx = tonumber(tx_file:read("*l")) or 0
            local rx = tonumber(rx_file:read("*l")) or 0
            tx_file:close()
            rx_file:close()

            local now = os.time()
            if previous.time > 0 then
                local elapsed = now - previous.time
                if elapsed > 0 then
                    widget:get_children_by_id("upload")[1].markup = string.format(
                        '<span foreground="%s">%s</span>',
                        shared.colors.text,
                        format_speed((tx - previous.tx) / elapsed)
                    )
                    widget:get_children_by_id("download")[1].markup = string.format(
                        '<span foreground="%s">%s</span>',
                        shared.colors.text,
                        format_speed((rx - previous.rx) / elapsed)
                    )
                end
            end

            previous.tx = tx
            previous.rx = rx
            previous.time = now
        end,
    }

    return widget
end

function M.create(shared)
    return {
        cpu = create_cpu_widget(shared),
        ram = create_ram_widget(shared),
        gpu = create_gpu_widget(shared),
        network = create_network_widget(shared),
    }
end

return M
