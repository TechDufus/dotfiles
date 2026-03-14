local awful = require("awful")
local only_on_screen = require("awful.widget.only_on_screen")
local wibox = require("wibox")

local ai_usage_widget = require("ai-usage-widget")
local user_config = require("cell-management.config")
local screen_helpers = require("cell-management.helpers")
local clock = require("widgets.clock")
local controller = require("widgets.controller")
local dnd = require("widgets.dnd")
local launcher = require("widgets.launcher")
local media = require("widgets.media")
local monitoring = require("widgets.monitoring")
local shared = require("widgets.shared")
local system = require("widgets.system")
local tasklist = require("widgets.tasklist")

local M = {}
local systray = wibox.widget.systray()
local systray_sections = setmetatable({}, { __mode = "k" })

local function configured_systray_target()
    return user_config.systray_screen or "primary"
end

local function resolve_output_screen(output_name)
    for index = 1, screen.count() do
        local screen_obj = screen[index]
        for _, candidate in ipairs(screen_helpers.get_screen_output_names(screen_obj)) do
            if candidate == output_name then
                return screen_obj
            end
        end
    end

    return nil
end

local function resolve_systray_screen()
    local target = configured_systray_target()

    if target == nil or target == "primary" then
        return "primary"
    end

    if type(target) == "number" then
        return screen[target] or "primary"
    end

    if type(target) == "string" then
        local screen_index = target:match("^screen:(%d+)$")
        if screen_index then
            return screen[tonumber(screen_index)] or "primary"
        end

        return resolve_output_screen(target) or "primary"
    end

    return "primary"
end

local function sync_systray_target()
    local target_screen = resolve_systray_screen()
    local dpi_screen = target_screen == "primary" and awful.screen.primary or target_screen

    systray:set_screen(target_screen)
    if dpi_screen then
        systray:set_base_size(shared.screen_dpi(16, dpi_screen))
    end

    for systray_section in pairs(systray_sections) do
        systray_section:set_screen(target_screen)
    end
end

function M.increase_volume(step)
    controller.increase_volume(step)
end

function M.decrease_volume(step)
    controller.decrease_volume(step)
end

function M.toggle_volume()
    controller.toggle_volume()
end

function M.increase_brightness()
    controller.increase_brightness()
end

function M.decrease_brightness()
    controller.decrease_brightness()
end

function M.create_wibar(screen_obj, tasklist_buttons, mainmenu)
    local screen_spacing = shared.screen_spacing(screen_obj)
    local systray_section = only_on_screen(
        wibox.widget {
            layout = wibox.layout.fixed.horizontal,
            shared.create_spacer(screen_spacing.section),
            {
                systray,
                valign = "center",
                widget = wibox.container.place,
            },
            shared.create_spacer(screen_spacing.section),
        },
        "primary"
    )

    screen_obj.mypromptbox = awful.widget.prompt()
    screen_obj.mytasklist = tasklist.create(screen_obj, tasklist_buttons, shared)

    local widgets = {
        launcher = launcher.create(shared, mainmenu),
        monitoring = monitoring.create(shared),
        media = media.create(shared),
        system = system.create(shared),
        dnd = dnd.create(shared),
        clock = clock.create(shared),
        ai = ai_usage_widget.create(shared.colors, shared.fonts, shared.spacing, shared.icons),
    }

    controller.register(screen_obj, widgets.media.controls)
    systray_sections[systray_section] = true

    screen_obj.mywibox = awful.wibar({
        position = "top",
        screen = screen_obj,
        ontop = true,
        height = screen_spacing.wibar_height,
        bg = shared.colors.base,
        fg = shared.colors.text,
    })

    screen_obj.mywibox:setup {
        layout = wibox.layout.stack,
        {
            screen_obj.mytasklist,
            halign = "center",
            valign = "center",
            widget = wibox.container.place,
        },
        {
            layout = wibox.layout.align.horizontal,
            {
                layout = wibox.layout.fixed.horizontal,
                shared.create_spacer(screen_spacing.widget),
                widgets.launcher,
                shared.create_spacer(screen_spacing.section),
                widgets.monitoring.cpu,
                shared.create_spacer(screen_spacing.widget),
                widgets.monitoring.ram,
                widgets.monitoring.gpu and shared.create_spacer(screen_spacing.widget) or nil,
                widgets.monitoring.gpu,
                shared.create_spacer(screen_spacing.section),
                widgets.monitoring.network,
                shared.create_spacer(screen_spacing.section),
            },
            nil,
            {
                layout = wibox.layout.fixed.horizontal,
                widgets.media.battery,
                widgets.media.battery and shared.create_spacer(screen_spacing.widget) or nil,
                widgets.media.brightness,
                widgets.media.brightness and shared.create_spacer(screen_spacing.section) or nil,
                widgets.system.filesystem,
                shared.create_spacer(screen_spacing.widget),
                widgets.media.volume,
                shared.create_spacer(screen_spacing.widget),
                widgets.ai,
                systray_section,
                widgets.dnd,
                shared.create_spacer(screen_spacing.widget),
                widgets.clock,
                shared.create_spacer(screen_spacing.widget),
                widgets.system.logout,
                shared.create_spacer(screen_spacing.section),
            },
        },
    }

    sync_systray_target()
end

screen.connect_signal("primary_changed", sync_systray_target)
screen.connect_signal("list", sync_systray_target)
screen.connect_signal("property::outputs", sync_systray_target)

return M
