-- window-switcher.lua - Windows/macOS style Alt+Tab window switcher
-- Shows a popup with app icons, highlights current selection

local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local beautiful = require("beautiful")
local icon_resolver = require("icon-resolver")

local window_switcher = {}

-- Configuration (using theme colors with fallbacks)
local config = {
    icon_size = 48,
    icon_margin = 8,
    border_width = 2,
    border_radius = 12,
    bg_color = beautiful.bg_normal or "#1e1e2e",
    border_color = beautiful.taglist_bg_hover or "#45475a",
    highlight_color = beautiful.fg_focus or "#89b4fa",
    text_color = beautiful.fg_normal or "#cdd6f4",
    font = beautiful.font or "sans 10",
}

-- State
local popup = nil
local clients_list = {}
local current_index = 1
local keygrabber_active = false

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

-- Get all clients sorted by most recently focused (MRU order)
local function get_clients()
    local cls = {}

    -- Use focus history for MRU ordering
    local history = awful.client.focus.history.list
    for _, c in ipairs(history) do
        -- Include all clients except special ones (like desktop widgets)
        if c.valid and (c.type == "normal" or c.type == "dialog") then
            table.insert(cls, c)
        end
    end

    -- Also add any clients not in history (newly created, never focused)
    for _, c in ipairs(client.get()) do
        if c.type == "normal" or c.type == "dialog" then
            local found = false
            for _, h in ipairs(cls) do
                if h == c then
                    found = true
                    break
                end
            end
            if not found then
                table.insert(cls, c)
            end
        end
    end

    return cls
end

-- Create icon widget for a client
local function create_client_icon(c, is_selected)
    -- Try high-resolution icon lookup first (GNOME-style via desktop files)
    -- Falls back to c.icon (_NET_WM_ICON), then to generic icon
    local icon_surface = icon_resolver.get_icon_surface(c, config.icon_size)

    -- Create either an image icon or a fallback text icon
    local icon_content
    if icon_surface then
        icon_content = wibox.widget {
            image = icon_surface,
            forced_width = config.icon_size,
            forced_height = config.icon_size,
            widget = wibox.widget.imagebox,
        }
    elseif beautiful.awesome_icon then
        -- Use theme's default icon as secondary fallback
        icon_content = wibox.widget {
            image = beautiful.awesome_icon,
            forced_width = config.icon_size,
            forced_height = config.icon_size,
            widget = wibox.widget.imagebox,
        }
    else
        -- Final fallback: show a generic window icon (Nerd Font)
        icon_content = wibox.widget {
            markup = string.format('<span foreground="%s">󰣆</span>', config.text_color),
            font = "BerkeleyMono Nerd Font 32",
            forced_width = config.icon_size,
            forced_height = config.icon_size,
            align = "center",
            valign = "center",
            widget = wibox.widget.textbox,
        }
    end

    local icon_widget = wibox.widget {
        {
            {
                icon_content,
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

-- Start keygrabber to detect when Super is released
local function start_keygrabber()
    if keygrabber_active then return end
    keygrabber_active = true

    awful.keygrabber.run(function(mod, key, event)
        -- On Super release, focus the selected window and hide the popup
        if event == "release" and (key == "Super_L" or key == "Super_R") then
            keygrabber_active = false
            -- Focus the selected window NOW
            local selected = clients_list[current_index]
            if selected and selected.valid then
                if selected.minimized then
                    selected.minimized = false
                end
                if not selected:isvisible() then
                    selected:move_to_tag(awful.screen.focused().selected_tag)
                end
                selected:emit_signal("request::activate", "window_switcher", { raise = true })
            end
            -- Hide popup
            if popup then
                popup.visible = false
            end
            awful.keygrabber.stop()
            return true
        end

        -- Handle Tab press while holding Super
        if event == "press" then
            local has_super = false
            for _, m in ipairs(mod) do
                if m == "Mod4" then has_super = true; break end
            end

            if has_super and key == "Tab" then
                -- Check for Shift
                local has_shift = false
                for _, m in ipairs(mod) do
                    if m == "Shift" then has_shift = true; break end
                end

                if has_shift then
                    window_switcher.cycle(-1)
                else
                    window_switcher.cycle(1)
                end
                return true
            end

            -- Escape cancels
            if key == "Escape" then
                keygrabber_active = false
                if popup then
                    popup.visible = false
                end
                awful.keygrabber.stop()
                return true
            end
        end

        return true
    end)
end

-- Cycle through windows (used by keygrabber while popup is visible)
-- Only updates the visual selection - does NOT focus until Super is released
function window_switcher.cycle(direction)
    if #clients_list == 0 then
        return
    end

    -- Cycle to next/previous
    current_index = current_index + direction
    if current_index > #clients_list then
        current_index = 1
    elseif current_index < 1 then
        current_index = #clients_list
    end

    -- Only update the popup visual - don't focus yet
    update_popup()
end

-- Show the switcher (called on first Super+Tab)
function window_switcher.show(direction)
    -- Only fetch fresh client list if switcher is not already visible
    -- This prevents focus history from scrambling the order mid-switch
    if not popup or not popup.visible then
        clients_list = get_clients()

        if #clients_list == 0 then
            return
        end

        -- Find current client index (starting point)
        local focused = client.focus
        current_index = 1
        for i, c in ipairs(clients_list) do
            if c == focused then
                current_index = i
                break
            end
        end

        -- Start keygrabber to detect Super release
        start_keygrabber()
    end

    -- Cycle to the next/previous window
    window_switcher.cycle(direction)

    -- Update and show popup
    update_popup()
end

-- Hide the switcher
function window_switcher.hide()
    if popup then
        popup.visible = false
    end
    keygrabber_active = false
end

return window_switcher
