local wibox = require("wibox")

local notifications = require("notifications")
local dnd = notifications.dnd

local M = {}

function M.create(shared)
    local widget = wibox.widget {
        {
            {
                id = "icon",
                font = shared.fonts.icon,
                forced_width = shared.fixed_dpi(20),
                forced_height = shared.fixed_dpi(20),
                align = "center",
                valign = "center",
                widget = wibox.widget.textbox,
            },
            left = shared.fixed_dpi(4),
            right = shared.fixed_dpi(4),
            widget = wibox.container.margin,
        },
        valign = "center",
        widget = wibox.container.place,
    }

    local function set_icon(color, icon)
        widget:get_children_by_id("icon")[1].markup =
            string.format('<span foreground="%s">%s</span>', color, icon)
    end

    local function update_icon()
        if dnd.is_enabled() then
            set_icon(shared.colors.red, shared.icons.dnd_enabled)
        else
            set_icon(shared.colors.blue, shared.icons.dnd_normal)
        end
    end

    dnd.connect_signal("state::changed", update_icon)

    widget:connect_signal("button::press", function(_, _, _, button)
        if button == 1 then
            dnd.toggle()
        end
    end)

    widget:connect_signal("mouse::enter", function()
        if dnd.is_enabled() then
            set_icon(shared.colors.maroon, shared.icons.dnd_enabled)
        else
            set_icon(shared.colors.sapphire, shared.icons.dnd_normal)
        end
    end)

    widget:connect_signal("mouse::leave", update_icon)
    update_icon()

    return widget
end

return M
