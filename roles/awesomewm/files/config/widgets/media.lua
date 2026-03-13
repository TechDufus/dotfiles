local awful = require("awful")
local naughty = require("naughty")
local wibox = require("wibox")

local batteryarc_widget = nil
local brightness_widget = require("awesome-wm-widgets.brightness-widget.brightness")
local volume_widget = require("awesome-wm-widgets.volume-widget.volume")
local hardware = require("widgets.hardware")
local popup_helpers = require("widgets.popup")

local M = {}

local function shell_escape(value)
    return string.format("'%s'", tostring(value):gsub("'", [['"'"']]))
end

local function create_audio_device_popup(shared, anchor_widget)
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
                            awful.spawn.with_shell(setter .. " " .. shell_escape(item))
                            popup.visible = false
                            naughty.notify({
                                title = title,
                                text = "Switched to: " .. item,
                                timeout = 2,
                            })
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

    anchor_widget:connect_signal("button::press", function(_, _, _, button)
        if button ~= 2 then
            return
        end

        if popup.visible then
            popup.visible = false
            anchor_geometry = nil
            return
        end

        anchor_geometry = mouse.current_widget_geometry
        popup.visible = true
        populate()
    end)
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
    local volume = volume_widget({
        widget_type = "arc",
        thickness = 2,
        main_color = shared.colors.blue,
        bg_color = shared.colors.surface1,
        mute_color = shared.colors.red,
        size = 18,
        device = "pulse",
    })
    create_audio_device_popup(shared, volume)

    local brightness = nil
    if hardware.detect_backlight() then
        brightness = brightness_widget({
            type = "arc",
            program = "brightnessctl",
            step = 5,
            size = 18,
            arc_thickness = 2,
            tooltip = true,
        })
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
            volume = volume,
            brightness = brightness,
        },
    }
end

return M
