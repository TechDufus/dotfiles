local wibox = require("wibox")

local calendar_widget = require("awesome-wm-widgets.calendar-widget.calendar")

local M = {}

function M.create(shared)
    local calendar = calendar_widget({
        theme = "naughty",
        placement = "top_right",
        radius = 8,
        start_sunday = false,
        week_numbers = false,
    })

    local widget = wibox.widget {
        {
            {
                format = "%a %b %d, %I:%M %p",
                font = shared.fonts.clock,
                widget = wibox.widget.textclock,
            },
            left = 4,
            widget = wibox.container.margin,
        },
        layout = wibox.layout.fixed.horizontal,
    }

    widget:connect_signal("button::press", function(_, _, _, button)
        if button == 1 then
            calendar.toggle()
        end
    end)

    return widget
end

return M
