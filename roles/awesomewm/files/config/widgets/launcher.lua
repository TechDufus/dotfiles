local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")

local M = {}

function M.create(shared, mainmenu)
    local widget = wibox.widget {
        {
            {
                markup = string.format(
                    '<span foreground="%s">%s</span>',
                    shared.colors.mauve,
                    shared.icons.launcher
                ),
                font = shared.fonts.icon,
                widget = wibox.widget.textbox,
            },
            left = 4,
            right = 4,
            widget = wibox.container.margin,
        },
        layout = wibox.layout.fixed.horizontal,
    }

    if mainmenu then
        widget:buttons(gears.table.join(
            awful.button({}, 1, function()
                mainmenu:show()
            end)
        ))
    end

    return widget
end

return M
