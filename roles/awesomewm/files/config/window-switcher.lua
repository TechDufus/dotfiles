-- window-switcher.lua - Windows/macOS style Alt+Tab window switcher
-- Shows a popup with app icons, highlights current selection

local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local beautiful = require("beautiful")

local window_switcher = {}

-- Configuration
local config = {
    icon_size = 48,
    icon_margin = 8,
    border_width = 2,
    border_radius = 12,
    bg_color = "#1e1e2e",           -- Catppuccin base
    border_color = "#45475a",        -- Catppuccin surface1
    highlight_color = "#89b4fa",     -- Catppuccin blue
    text_color = "#cdd6f4",          -- Catppuccin text
    font = "BerkeleyMono Nerd Font 10",
    hide_delay = 1.5,                -- Seconds to hide after last action
}

-- State
local popup = nil
local clients_list = {}
local current_index = 1
local hide_timer = nil

-- Create the popup widget
local function create_popup()
    if popup then return end

    popup = awful.popup({
        ontop = true,
        visible = false,
        placement = awful.placement.centered,
        shape = function(cr, w, h)
            gears.shape.rounded_rect(cr, w, h, config.border_radius)
        end,
        border_width = config.border_width,
        border_color = config.border_color,
        bg = config.bg_color,
        widget = wibox.widget {
            layout = wibox.layout.fixed.horizontal,
        }
    })
end

-- Get all clients (including minimized/hidden)
local function get_clients()
    local cls = {}

    for _, c in ipairs(client.get()) do
        -- Include all clients except special ones (like desktop widgets)
        if c.type == "normal" or c.type == "dialog" then
            table.insert(cls, c)
        end
    end

    return cls
end

-- Create icon widget for a client
local function create_client_icon(c, is_selected)
    local icon_widget = wibox.widget {
        {
            {
                {
                    image = c.icon or beautiful.awesome_icon,
                    forced_width = config.icon_size,
                    forced_height = config.icon_size,
                    widget = wibox.widget.imagebox,
                },
                margins = config.icon_margin,
                widget = wibox.container.margin,
            },
            bg = is_selected and config.highlight_color .. "40" or "#00000000",
            shape = function(cr, w, h)
                gears.shape.rounded_rect(cr, w, h, 8)
            end,
            border_width = is_selected and 2 or 0,
            border_color = config.highlight_color,
            widget = wibox.container.background,
        },
        layout = wibox.layout.fixed.vertical,
    }

    return icon_widget
end

-- Update the popup content
local function update_popup()
    if not popup then create_popup() end
    if #clients_list == 0 then
        popup.visible = false
        return
    end

    local icons_layout = wibox.layout.fixed.horizontal()
    icons_layout.spacing = 4

    for i, c in ipairs(clients_list) do
        local icon = create_client_icon(c, i == current_index)
        icons_layout:add(icon)
    end

    popup.widget = wibox.widget {
        {
            icons_layout,
            margins = 12,
            widget = wibox.container.margin,
        },
        layout = wibox.layout.fixed.vertical,
    }

    popup.visible = true
end

-- Reset hide timer
local function reset_hide_timer()
    if hide_timer then
        hide_timer:stop()
    end

    hide_timer = gears.timer.start_new(config.hide_delay, function()
        if popup then
            popup.visible = false
        end
        return false
    end)
end

-- Show the switcher and cycle
function window_switcher.show(direction)
    clients_list = get_clients()

    if #clients_list == 0 then
        return
    end

    -- Find current client index
    local focused = client.focus
    current_index = 1
    for i, c in ipairs(clients_list) do
        if c == focused then
            current_index = i
            break
        end
    end

    -- Cycle to next/previous
    current_index = current_index + direction
    if current_index > #clients_list then
        current_index = 1
    elseif current_index < 1 then
        current_index = #clients_list
    end

    -- Focus the selected client (and show if hidden/minimized)
    local selected = clients_list[current_index]
    if selected then
        -- Unminimize if needed
        if selected.minimized then
            selected.minimized = false
        end
        -- Move to current tag if on different tag
        if not selected:isvisible() then
            selected:move_to_tag(awful.screen.focused().selected_tag)
        end
        -- Focus and raise
        selected:emit_signal("request::activate", "window_switcher", { raise = true })
    end

    -- Update and show popup
    update_popup()
    reset_hide_timer()
end

-- Hide the switcher
function window_switcher.hide()
    if popup then
        popup.visible = false
    end
    if hide_timer then
        hide_timer:stop()
        hide_timer = nil
    end
end

return window_switcher
