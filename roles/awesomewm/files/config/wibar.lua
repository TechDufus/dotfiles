local awful = require("awful")
local wibox = require("wibox")

local ai_usage_widget = require("ai-usage-widget")
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

    local systray = nil
    if screen_obj == awful.screen.primary then
        systray = wibox.widget.systray()
        systray:set_base_size(shared.screen_dpi(16, screen_obj))
    end

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
                systray and shared.create_spacer(screen_spacing.section) or nil,
                systray and {
                    systray,
                    valign = "center",
                    widget = wibox.container.place,
                } or nil,
                systray and shared.create_spacer(screen_spacing.section) or nil,
                widgets.dnd,
                shared.create_spacer(screen_spacing.widget),
                widgets.clock,
                shared.create_spacer(screen_spacing.widget),
                widgets.system.logout,
                shared.create_spacer(screen_spacing.section),
            },
        },
    }
end

return M
