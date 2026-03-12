local awful = require("awful")
local wibox = require("wibox")

local icon_resolver = require("icon-resolver")

local M = {}

local function update_tasklist_icon(self, client_obj)
    local icon_widget = self:get_children_by_id("icon_role")[1]
    local fallback = self:get_children_by_id("fallback_icon")[1]
    local icon_path = icon_resolver.get_icon_path(client_obj)

    if icon_path then
        icon_widget.image = icon_path
        icon_widget.visible = true
        fallback.visible = false
        return
    end

    if client_obj.icon then
        icon_widget.image = client_obj.icon
        icon_widget.visible = true
        fallback.visible = false
        return
    end

    fallback.visible = true
    icon_widget.visible = false
end

function M.create(screen_obj, tasklist_buttons, shared)
    return awful.widget.tasklist {
        screen = screen_obj,
        filter = awful.widget.tasklist.filter.currenttags,
        buttons = tasklist_buttons,
        layout = {
            spacing = shared.screen_dpi(8, screen_obj),
            layout = wibox.layout.fixed.horizontal,
        },
        widget_template = {
            {
                {
                    {
                        id = "icon_role",
                        forced_height = shared.screen_dpi(24, screen_obj),
                        forced_width = shared.screen_dpi(24, screen_obj),
                        widget = wibox.widget.imagebox,
                    },
                    {
                        id = "fallback_icon",
                        markup = string.format(
                            '<span foreground="%s">󰣆</span>',
                            shared.colors.subtext0
                        ),
                        font = shared.font_family .. " 18",
                        forced_height = shared.screen_dpi(24, screen_obj),
                        forced_width = shared.screen_dpi(24, screen_obj),
                        align = "center",
                        valign = "center",
                        visible = false,
                        widget = wibox.widget.textbox,
                    },
                    layout = wibox.layout.stack,
                },
                margins = shared.screen_dpi(3, screen_obj),
                widget = wibox.container.margin,
            },
            id = "background_role",
            widget = wibox.container.background,
            create_callback = function(self, client_obj)
                update_tasklist_icon(self, client_obj)
            end,
            update_callback = function(self, client_obj)
                update_tasklist_icon(self, client_obj)
            end,
        },
    }
end

return M
