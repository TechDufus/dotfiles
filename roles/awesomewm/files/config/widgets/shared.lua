local beautiful = require("beautiful")
local wibox = require("wibox")

local xresources = beautiful.xresources

-- Keep the base widget sizing fixed so the secondary display does not inherit
-- oversized dimensions from the primary 4K screen.
local function fixed_dpi(size)
    return size
end

local colors = {
    base = beautiful.bg_normal,
    surface0 = beautiful.bg_focus,
    surface1 = beautiful.taglist_bg_hover or "#45475a",
    surface2 = "#585b70",

    text = beautiful.fg_normal,
    subtext0 = "#a6adc8",
    subtext1 = "#bac2de",

    blue = beautiful.fg_focus or "#89b4fa",
    sapphire = "#74c7ec",
    sky = "#89dceb",
    teal = "#94e2d5",
    green = "#a6e3a1",
    yellow = "#f9e2af",
    peach = "#fab387",
    maroon = "#eba0ac",
    red = beautiful.bg_urgent or "#f38ba8",
    pink = "#f5c2e7",
    mauve = beautiful.hotkeys_modifiers_fg or "#cba6f7",
    lavender = "#b4befe",
}

local font_family = "BerkeleyMono Nerd Font"

local fonts = {
    clock = font_family .. " Bold 13",
    data = font_family .. " 10",
    icon = font_family .. " 14",
}

local icons = {
    launcher = "󰀻",
    cpu = "󰘚",
    ram = "󰍛",
    gpu = "󰢮",
    upload = "󰕒",
    download = "󰇚",
    dnd_normal = "󰂚",
    dnd_enabled = "󰂛",
    ai = "✦",
}

local spacing = {
    wibar_height = fixed_dpi(28),
    section = fixed_dpi(24),
    widget = fixed_dpi(16),
    icon_gap = fixed_dpi(6),
}

local M = {
    colors = colors,
    fonts = fonts,
    icons = icons,
    spacing = spacing,
    font_family = font_family,
    fixed_dpi = fixed_dpi,
}

function M.create_spacer(width)
    return wibox.widget {
        orientation = "vertical",
        forced_width = width or spacing.widget,
        opacity = 0,
        widget = wibox.widget.separator,
    }
end

function M.screen_spacing(screen)
    return {
        wibar_height = xresources.apply_dpi(28, screen),
        section = xresources.apply_dpi(24, screen),
        widget = xresources.apply_dpi(16, screen),
    }
end

function M.screen_dpi(value, screen)
    return xresources.apply_dpi(value, screen)
end

return M
