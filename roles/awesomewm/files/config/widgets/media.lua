local awful = require("awful")
local naughty = require("naughty")
local wibox = require("wibox")

local batteryarc_widget = nil
local brightness_widget = require("awesome-wm-widgets.brightness-widget.brightness")
local hardware = require("widgets.hardware")
local popup_helpers = require("widgets.popup")

local M = {}

local function shell_escape(value)
    return string.format("'%s'", tostring(value):gsub("'", [['"'"']]))
end

local function command_exists(command)
    local handle = io.popen("command -v " .. command .. " >/dev/null 2>&1 && printf yes || printf no")
    if not handle then
        return false
    end

    local result = handle:read("*a")
    handle:close()
    return result and result:match("yes") ~= nil or false
end

local function first_available_command(candidates)
    for _, candidate in ipairs(candidates) do
        if command_exists(candidate) then
            return candidate
        end
    end

    return nil
end

local function detect_audio_backend()
    local has_pactl_widget, pactl_widget = pcall(require, "awesome-wm-widgets.pactl-widget.volume")
    local has_wpctl_widget, wpctl_widget = pcall(require, "awesome-wm-widgets.wpctl-widget.volume")
    local fallback_widget = require("awesome-wm-widgets.volume-widget.volume")

    if command_exists("pactl") then
        return {
            name = "pactl",
            widget_module = has_pactl_widget and pactl_widget or fallback_widget,
            widget_device = has_pactl_widget and "@DEFAULT_SINK@" or "pulse",
            mixer_cmd = first_available_command({ "pavucontrol", "pwvucontrol", "alsamixer" }),
            query_command = [[sh -c 'pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null; pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null']],
            parse_state = function(stdout)
                local volume_sum = 0
                local volume_count = 0

                for level in stdout:gmatch("(%d?%d?%d)%%") do
                    local numeric_level = tonumber(level)
                    if numeric_level ~= nil then
                        volume_sum = volume_sum + numeric_level
                        volume_count = volume_count + 1
                    end
                end

                local volume_level = volume_count > 0 and math.floor((volume_sum / volume_count) + 0.5) or nil
                local muted = stdout:match("Mute:%s+yes") ~= nil
                return volume_level, muted
            end,
            increase_command = function(step)
                return string.format("pactl set-sink-volume @DEFAULT_SINK@ +%d%%", step)
            end,
            decrease_command = function(step)
                return string.format("pactl set-sink-volume @DEFAULT_SINK@ -%d%%", step)
            end,
            toggle_command = "pactl set-sink-mute @DEFAULT_SINK@ toggle",
        }
    end

    if command_exists("wpctl") then
        return {
            name = "wpctl",
            widget_module = has_wpctl_widget and wpctl_widget or fallback_widget,
            widget_device = has_wpctl_widget and "@DEFAULT_SINK@" or "pulse",
            mixer_cmd = first_available_command({ "pwvucontrol", "pavucontrol", "alsamixer" }),
            query_command = "wpctl get-volume @DEFAULT_SINK@ 2>/dev/null",
            parse_state = function(stdout)
                local volume_level = stdout:match("(%d+%.%d+)")
                local muted = stdout:match("MUTED") ~= nil

                if volume_level then
                    volume_level = math.floor((tonumber(volume_level) * 100) + 0.5)
                end

                return volume_level, muted
            end,
            increase_command = function(step)
                return string.format("wpctl set-volume @DEFAULT_SINK@ %d%%+", step)
            end,
            decrease_command = function(step)
                return string.format("wpctl set-volume @DEFAULT_SINK@ %d%%-", step)
            end,
            toggle_command = "wpctl set-mute @DEFAULT_SINK@ toggle",
        }
    end

    if command_exists("amixer") then
        return {
            name = "amixer",
            widget_module = fallback_widget,
            widget_device = "pulse",
            mixer_cmd = first_available_command({ "alsamixer", "pavucontrol", "pwvucontrol" }),
            query_command = "amixer -D pulse sget Master 2>/dev/null",
            parse_state = function(stdout)
                local volume_level = stdout:match("(%d?%d?%d)%%")
                local muted = stdout:match("%[off%]") ~= nil

                return volume_level and tonumber(volume_level) or nil, muted
            end,
            increase_command = function(step)
                return string.format("amixer -D pulse sset Master %d%%+", step)
            end,
            decrease_command = function(step)
                return string.format("amixer -D pulse sset Master %d%%-", step)
            end,
            toggle_command = "amixer -D pulse sset Master toggle",
        }
    end

    return nil
end

local function refresh_volume_widget(widget, backend)
    if not widget or not backend or not backend.query_command then
        return
    end

    awful.spawn.easy_async_with_shell(backend.query_command, function(stdout)
        local volume_level, muted = backend.parse_state(stdout or "")

        if volume_level ~= nil and widget.set_volume_level then
            widget:set_volume_level(volume_level)
        end

        if muted and widget.mute then
            widget:mute()
        elseif muted == false and widget.unmute then
            widget:unmute()
        end
    end)
end

local function create_volume_controls(widget, backend, default_step)
    if not widget or not backend then
        return nil
    end

    local controls = {}

    local function run(command)
        awful.spawn.easy_async_with_shell(command, function()
            refresh_volume_widget(widget, backend)
        end)
    end

    function controls:inc(step)
        run(backend.increase_command(tonumber(step) or default_step or 5))
    end

    function controls:dec(step)
        run(backend.decrease_command(tonumber(step) or default_step or 5))
    end

    function controls:toggle()
        run(backend.toggle_command)
    end

    function controls:mixer()
        if backend.mixer_cmd then
            awful.spawn(backend.mixer_cmd)
        end
    end

    function controls:refresh()
        refresh_volume_widget(widget, backend)
    end

    return controls
end

local function create_brightness_controls(widget, step)
    if not widget or not command_exists("brightnessctl") then
        return nil
    end

    local controls = {}
    local brightness_step = tonumber(step) or 5

    local function refresh()
        awful.spawn.easy_async_with_shell(
            "sh -c 'brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d %'",
            function(stdout)
                local brightness_level = tonumber(stdout)
                if brightness_level ~= nil and widget.set_value then
                    widget:set_value(brightness_level)
                end
            end
        )
    end

    local function run(command)
        awful.spawn.easy_async_with_shell(command, function()
            refresh()
        end)
    end

    function controls:inc()
        run(string.format("brightnessctl set +%d%%", brightness_step))
    end

    function controls:dec()
        run(string.format("brightnessctl set %d-%%", brightness_step))
    end

    function controls:refresh()
        refresh()
    end

    return controls
end

local function create_audio_device_popup(shared, volume_controls)
    if not command_exists("pactl") then
        return nil
    end

    local popup = awful.popup({
        visible = false,
        ontop = true,
        widget = {},
    })
    local anchor_geometry = nil

    local function populate()
        awful.spawn.easy_async_with_shell([[
            sh -c '
            default_sink="$(pactl info 2>/dev/null | sed -n "s/^Default Sink: //p")"
            default_source="$(pactl info 2>/dev/null | sed -n "s/^Default Source: //p")"
            printf "default_sink\t%s\n" "$default_sink"
            pactl list short sinks 2>/dev/null | cut -f2 | while IFS= read -r sink; do
                printf "sink\t%s\n" "$sink"
            done
            printf "default_source\t%s\n" "$default_source"
            pactl list short sources 2>/dev/null | cut -f2 | while IFS= read -r source; do
                printf "source\t%s\n" "$source"
            done
            '
        ]], function(stdout)
            local rows = {
                spacing = shared.fixed_dpi(6),
                layout = wibox.layout.fixed.vertical,
            }
            local default_sink
            local default_source
            local sinks = {}
            local sources = {}

            for line in stdout:gmatch("[^\r\n]+") do
                local kind, value = line:match("^([^\t]+)\t(.*)$")
                if kind == "default_sink" then
                    default_sink = value
                elseif kind == "default_source" then
                    default_source = value
                elseif kind == "sink" then
                    table.insert(sinks, value)
                elseif kind == "source" then
                    table.insert(sources, value)
                end
            end

            table.insert(rows, wibox.widget {
                markup = string.format(
                    '<span foreground="%s" font_weight="bold">Audio Devices</span>',
                    shared.colors.blue
                ),
                font = shared.fonts.data,
                widget = wibox.widget.textbox,
            })

            local function append_section(title, items, default_item, setter, active_color)
                if #items == 0 then
                    return
                end

                table.insert(rows, wibox.widget {
                    markup = string.format(
                        '<span foreground="%s" font_weight="bold">%s</span>',
                        active_color,
                        title
                    ),
                    font = shared.fonts.data,
                    widget = wibox.widget.textbox,
                })

                for _, item in ipairs(items) do
                    local is_active = item == default_item
                    local marker = is_active and "●" or "○"
                    local color = is_active and active_color or shared.colors.subtext0

                    table.insert(rows, popup_helpers.create_selection_row(
                        shared,
                        string.format("%s %s", marker, item),
                        color,
                        function()
                            awful.spawn.easy_async_with_shell(setter .. " " .. shell_escape(item), function()
                                if volume_controls and volume_controls.refresh then
                                    volume_controls:refresh()
                                end

                                popup.visible = false
                                naughty.notify({
                                    title = title,
                                    text = "Switched to: " .. item,
                                    timeout = 2,
                                })
                            end)
                        end
                    ))
                end
            end

            append_section("Outputs", sinks, default_sink, "pactl set-default-sink", shared.colors.green)
            append_section("Inputs", sources, default_source, "pactl set-default-source", shared.colors.peach)

            if #sinks == 0 and #sources == 0 then
                table.insert(rows, wibox.widget {
                    markup = string.format(
                        '<span foreground="%s">No audio devices available</span>',
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
        end)
    end

    return function(widget_geometry)
        if popup.visible then
            popup.visible = false
            anchor_geometry = nil
            return
        end

        anchor_geometry = widget_geometry
        popup.visible = true
        populate()
    end
end

local function create_battery_popup(shared, battery_name)
    local popup = awful.popup({
        visible = false,
        ontop = true,
        widget = {},
    })
    local anchor_geometry = nil

    local upower_path = "/org/freedesktop/UPower/devices/battery_" .. battery_name

    local function populate(widget_geometry)
        anchor_geometry = widget_geometry
        local battery_info
        local profiles_ready = false
        local profiles_state = "unavailable"
        local profiles = {}
        local active_profile

        local function maybe_render()
            if battery_info == nil or not profiles_ready then
                return
            end

            local rows = {
                spacing = shared.fixed_dpi(8),
                layout = wibox.layout.fixed.vertical,
            }

            if battery_info ~= "" then
                table.insert(rows, wibox.widget {
                    markup = string.format(
                        '<span foreground="%s" font_weight="bold">Battery Status</span>',
                        shared.colors.blue
                    ),
                    font = shared.fonts.data,
                    widget = wibox.widget.textbox,
                })

                for line in battery_info:gmatch("[^\r\n]+") do
                    local trimmed = line:gsub("^%s+", ""):gsub("%s+$", "")
                    if trimmed ~= "" then
                        table.insert(rows, wibox.widget {
                            markup = string.format(
                                '<span foreground="%s">%s</span>',
                                shared.colors.text,
                                trimmed
                            ),
                            font = shared.fonts.data,
                            widget = wibox.widget.textbox,
                        })
                    end
                end
            end

            if #profiles > 0 then
                table.insert(rows, wibox.widget {
                    markup = string.format(
                        '<span foreground="%s" font_weight="bold">Power Profile</span>',
                        shared.colors.green
                    ),
                    font = shared.fonts.data,
                    widget = wibox.widget.textbox,
                })

                for _, profile in ipairs(profiles) do
                    local is_active = profile == active_profile
                    local marker = is_active and "●" or "○"
                    local color = is_active and shared.colors.green or shared.colors.subtext0

                    table.insert(rows, popup_helpers.create_selection_row(
                        shared,
                        string.format("%s %s", marker, profile),
                        color,
                        function()
                            awful.spawn.with_shell("powerprofilesctl set " .. shell_escape(profile))
                            popup.visible = false
                            naughty.notify({
                                title = "Power Profile",
                                text = "Switched to: " .. profile,
                                timeout = 2,
                            })
                        end
                    ))
                end
            elseif profiles_state == "unavailable" then
                table.insert(rows, wibox.widget {
                    markup = string.format(
                        '<span foreground="%s" style="italic">Power profiles unavailable</span>',
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

        awful.spawn.easy_async_with_shell(
            string.format(
                "upower -i %s 2>/dev/null | grep -E '(state|percentage|time to|energy-rate)' | sed 's/^[ \t]*//' | head -6",
                shell_escape(upower_path)
            ),
            function(stdout)
                battery_info = stdout or ""
                maybe_render()
            end
        )

        awful.spawn.easy_async_with_shell(
            "powerprofilesctl list 2>/dev/null",
            function(stdout, _, _, exit_code)
                if exit_code == 0 and stdout and stdout ~= "" then
                    profiles_state = "available"
                    for line in stdout:gmatch("[^\r\n]+") do
                        local active_marker, profile = line:match("^(%s?%*?)%s?([%w%-]+):$")
                        if profile and not line:match("^%s%s%s%s") then
                            table.insert(profiles, profile)
                            if active_marker and active_marker:match("%*") then
                                active_profile = profile
                            end
                        end
                    end
                end

                profiles_ready = true
                maybe_render()
            end
        )
    end

    return popup, populate
end

function M.create(shared)
    local audio_backend = detect_audio_backend()
    local volume = nil
    local volume_controls = nil

    if audio_backend and audio_backend.widget_module then
        volume = audio_backend.widget_module({
            widget_type = "arc",
            thickness = 2,
            main_color = shared.colors.blue,
            bg_color = shared.colors.surface1,
            mute_color = shared.colors.red,
            size = 18,
            device = audio_backend.widget_device,
            mixer_cmd = audio_backend.mixer_cmd,
            tooltip = true,
        })

        volume_controls = create_volume_controls(volume, audio_backend, 5)
        local toggle_audio_device_popup = create_audio_device_popup(shared, volume_controls)

        volume:buttons(awful.util.table.join(
            awful.button({}, 1, function()
                if volume_controls and volume_controls.toggle then
                    volume_controls:toggle()
                end
            end),
            awful.button({}, 2, function()
                if volume_controls and volume_controls.mixer then
                    volume_controls:mixer()
                end
            end),
            awful.button({}, 3, function()
                if toggle_audio_device_popup then
                    toggle_audio_device_popup(mouse.current_widget_geometry)
                end
            end),
            awful.button({}, 4, function()
                if volume_controls and volume_controls.inc then
                    volume_controls:inc(5)
                end
            end),
            awful.button({}, 5, function()
                if volume_controls and volume_controls.dec then
                    volume_controls:dec(5)
                end
            end)
        ))

        if volume_controls and volume_controls.refresh then
            volume_controls:refresh()
        end
    end

    local brightness = nil
    local brightness_controls = nil
    if hardware.detect_backlight() then
        brightness = brightness_widget({
            type = "arc",
            program = "brightnessctl",
            step = 5,
            size = 18,
            arc_thickness = 2,
            tooltip = true,
        })

        brightness_controls = create_brightness_controls(brightness, 5)
        if brightness_controls and brightness_controls.refresh then
            brightness_controls:refresh()
        end
    end

    local battery = nil
    local battery_name = hardware.detect_battery_name()
    if battery_name then
        if not batteryarc_widget then
            batteryarc_widget = require("awesome-wm-widgets.batteryarc-widget.batteryarc")
        end

        battery = batteryarc_widget({
            show_current_level = true,
            arc_thickness = 2,
            size = 18,
            main_color = shared.colors.green,
            low_level_color = shared.colors.maroon,
            medium_level_color = shared.colors.yellow,
            show_notification_mode = "off",
        })

        local battery_popup, populate_battery_popup = create_battery_popup(shared, battery_name)
        battery:connect_signal("button::press", function(_, _, _, button)
            if button ~= 1 then
                return
            end

            if battery_popup.visible then
                battery_popup.visible = false
                return
            end

            battery_popup.visible = true
            populate_battery_popup(mouse.current_widget_geometry)
        end)
    end

    return {
        volume = volume,
        brightness = brightness,
        battery = battery,
        controls = {
            volume = volume_controls,
            brightness = brightness_controls,
        },
    }
end

return M
