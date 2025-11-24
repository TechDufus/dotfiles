---------------------------
-- Catppuccin Mocha theme --
---------------------------

local theme_assets = require("beautiful.theme_assets")
local xresources = require("beautiful.xresources")
local dpi = xresources.apply_dpi
local gears = require("gears")
local gfs = require("gears.filesystem")

local theme = {}

-- Catppuccin Mocha Palette
local mocha = {
    -- Dark backgrounds
    crust     = "#11111b",
    mantle    = "#181825",
    base      = "#1e1e2e",
    surface0  = "#313244",
    surface1  = "#45475a",
    surface2  = "#585b70",

    -- Text/foreground
    text      = "#cdd6f4",
    subtext1  = "#bac2de",
    subtext0  = "#a6adc8",
    overlay2  = "#9399b2",
    overlay1  = "#7f849c",
    overlay0  = "#6c7086",

    -- Accent colors
    lavender  = "#b4befe",
    blue      = "#89b4fa",
    sapphire  = "#74c7ec",
    sky       = "#89dceb",
    teal      = "#94e2d5",
    green     = "#a6e3a1",
    yellow    = "#f9e2af",
    peach     = "#fab387",
    maroon    = "#eba0ac",
    red       = "#f38ba8",
    mauve     = "#cba6f7",
    pink      = "#f5c2e7",
    flamingo  = "#f2cdcd",
    rosewater = "#f5e0dc",
}

-- Font
theme.font          = "BerkeleyMono Nerd Font 10"

-- Background colors
theme.bg_normal     = mocha.base
theme.bg_focus      = mocha.surface0
theme.bg_urgent     = mocha.red
theme.bg_minimize   = mocha.mantle
theme.bg_systray    = mocha.base

-- Foreground colors
theme.fg_normal     = mocha.text
theme.fg_focus      = mocha.blue
theme.fg_urgent     = mocha.base
theme.fg_minimize   = mocha.overlay0

-- Gaps and borders
theme.useless_gap   = dpi(5)
theme.border_width  = dpi(2)
theme.border_normal = mocha.surface0 .. "aa"  -- With transparency
theme.border_focus  = mocha.blue .. "ee"      -- Matches Hyprland
theme.border_marked = mocha.red

-- Taglist
theme.taglist_bg_focus      = mocha.blue
theme.taglist_fg_focus      = mocha.base
theme.taglist_bg_occupied   = mocha.surface0
theme.taglist_fg_occupied   = mocha.text
theme.taglist_bg_empty      = mocha.base
theme.taglist_fg_empty      = mocha.overlay0
theme.taglist_bg_urgent     = mocha.red
theme.taglist_fg_urgent     = mocha.base
theme.taglist_bg_hover      = mocha.surface1
theme.taglist_spacing       = dpi(4)

-- Tasklist
theme.tasklist_bg_focus     = mocha.surface0
theme.tasklist_fg_focus     = mocha.blue
theme.tasklist_bg_normal    = mocha.base
theme.tasklist_fg_normal    = mocha.text
theme.tasklist_bg_urgent    = mocha.red
theme.tasklist_fg_urgent    = mocha.base
theme.tasklist_bg_minimize  = mocha.mantle
theme.tasklist_fg_minimize  = mocha.overlay0

-- Titlebar
theme.titlebar_bg_normal    = mocha.base
theme.titlebar_bg_focus     = mocha.surface0
theme.titlebar_fg_normal    = mocha.text
theme.titlebar_fg_focus     = mocha.blue

-- Notifications
theme.notification_bg           = mocha.base
theme.notification_fg           = mocha.text
theme.notification_border_color = mocha.blue
theme.notification_border_width = dpi(2)
theme.notification_opacity      = 0.95
theme.notification_margin       = dpi(16)
theme.notification_icon_size    = dpi(48)
theme.notification_max_width    = dpi(400)
theme.notification_max_height   = dpi(200)
theme.notification_font         = "BerkeleyMono Nerd Font 11"
theme.notification_shape        = function(cr, w, h)
    require("gears").shape.rounded_rect(cr, w, h, dpi(12))
end

-- Hotkeys popup
theme.hotkeys_bg                = mocha.base
theme.hotkeys_fg                = mocha.text
theme.hotkeys_border_color      = mocha.blue
theme.hotkeys_border_width      = dpi(2)
theme.hotkeys_modifiers_fg      = mocha.mauve
theme.hotkeys_label_fg          = mocha.sapphire
theme.hotkeys_font              = "BerkeleyMono Nerd Font Bold 10"
theme.hotkeys_description_font  = "BerkeleyMono Nerd Font 9"

-- Menu
theme.menu_height       = dpi(20)
theme.menu_width        = dpi(150)
theme.menu_bg_normal    = mocha.base
theme.menu_bg_focus     = mocha.surface0
theme.menu_fg_normal    = mocha.text
theme.menu_fg_focus     = mocha.blue
theme.menu_border_color = mocha.surface0
theme.menu_border_width = dpi(2)

-- Wibar
theme.wibar_bg          = mocha.base
theme.wibar_fg          = mocha.text
theme.wibar_opacity     = 1.0
theme.wibar_height      = dpi(28)

-- System tray
theme.bg_systray        = mocha.base
theme.systray_icon_spacing = dpi(4)

-- Wallpaper (uncomment and set your image path)
-- theme.wallpaper = gfs.get_configuration_dir() .. "themes/catppuccin-mocha/wallpaper.jpg"
-- Or use absolute path:
theme.wallpaper = "/home/techdufus/Pictures/tengen-uzui-dark-3840x2160-18405.jpg"

-- Layout icons (using text symbols as fallback)
theme.layout_fairh      = "[]="
theme.layout_fairv      = "||="
theme.layout_floating   = "><>"
theme.layout_magnifier  = "[M]"
theme.layout_max        = "[M]"
theme.layout_fullscreen = "[ ]"
theme.layout_tilebottom = "TTT"
theme.layout_tileleft   = "|||"
theme.layout_tile       = "[T]"
theme.layout_tiletop    = "TTT"
theme.layout_spiral     = "[@]"
theme.layout_dwindle    = "[\\]"
theme.layout_cornernw   = "[⌜]"
theme.layout_cornerne   = "[⌝]"
theme.layout_cornersw   = "[⌞]"
theme.layout_cornerse   = "[⌟]"

return theme
