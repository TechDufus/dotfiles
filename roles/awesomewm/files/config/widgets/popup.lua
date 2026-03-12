local gears = require("gears")
local wibox = require("wibox")

local M = {}

function M.create_frame(shared, content)
    return {
        {
            content,
            margins = shared.fixed_dpi(12),
            widget = wibox.container.margin,
        },
        bg = shared.colors.base,
        shape = function(cr, width, height)
            gears.shape.rounded_rect(cr, width, height, shared.fixed_dpi(8))
        end,
        border_width = shared.fixed_dpi(1),
        border_color = shared.colors.surface1,
        widget = wibox.container.background,
    }
end

function M.create_selection_row(shared, label, color, on_click)
    local row = wibox.widget {
        {
            {
                markup = string.format('<span foreground="%s">%s</span>', color, label),
                font = shared.fonts.data,
                widget = wibox.widget.textbox,
            },
            left = shared.fixed_dpi(4),
            right = shared.fixed_dpi(4),
            top = shared.fixed_dpi(2),
            bottom = shared.fixed_dpi(2),
            widget = wibox.container.margin,
        },
        bg = shared.colors.base,
        widget = wibox.container.background,
    }

    row:connect_signal("mouse::enter", function(current)
        current.bg = shared.colors.surface1
    end)
    row:connect_signal("mouse::leave", function(current)
        current.bg = shared.colors.base
    end)
    row:connect_signal("button::press", function(_, _, _, button)
        if button == 1 then
            on_click()
        end
    end)

    return row
end

return M
