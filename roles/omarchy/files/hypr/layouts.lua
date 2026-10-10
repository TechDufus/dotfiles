-- Screen layouts for the cells engine (cells.lua). Managed by ~/.dotfiles roles/omarchy.
-- Same model as roles/hammerspoon/files/config/{positions,layouts,screen_layouts}.lua and
-- roles/plasma/files/summon/{regions,layouts}.toml: named regions, a layout per screen, app -> cell.
return {
  -- Fractions of a screen's usable area (Waybar excluded). Tiled regions sit side by side and must
  -- not overlap within a layout; float = true regions float on top at exactly that box (overlays).
  regions = {
    standard_browser_left    = { x = 0,     y = 0,     w = 0.4,   h = 1 },
    standard_terminal_right  = { x = 0.4,   y = 0,     w = 0.6,   h = 1 },
    standard_utility_overlay = { x = 0.125, y = 0.1,   w = 0.75,  h = 0.8,  float = true },

    hd_left_main             = { x = 0,     y = 0,     w = 0.6,   h = 1 },
    hd_right_side            = { x = 0.6,   y = 0,     w = 0.4,   h = 1 },
    hd_float_center          = { x = 0.125, y = 0.1,   w = 0.75,  h = 0.8,  float = true },

    fourk_left_large         = { x = 0,     y = 0,     w = 0.65,  h = 1 },
    fourk_right_side         = { x = 0.65,  y = 0,     w = 0.35,  h = 1 },
    fourk_top_right          = { x = 0.625, y = 0.05,  w = 0.35,  h = 0.5,  float = true },
    fourk_center_left_large  = { x = 0.075, y = 0.125, w = 0.55,  h = 0.75, float = true },
    fourk_center_large       = { x = 0.125, y = 0.125, w = 0.75,  h = 0.75, float = true },
    fourk_right_small        = { x = 0.6,   y = 0.2,   w = 0.375, h = 0.6,  float = true },
  },

  -- cells: Super+U picker order. apps: summon registry name (summon_apps.lua) -> region.
  -- default: region for every other window. tile: where a floating-cell window goes when you tile
  -- it yourself (Super+T). monocle = true: Hyprland's monocle layout, every window full screen and
  -- one visible at a time; summon and Alt+Tab flip between them.
  layouts = {
    standard = {
      name = "Standard Dev",
      cells = { "standard_browser_left", "standard_terminal_right", "standard_utility_overlay" },
      default = "standard_utility_overlay",
      tile = "standard_browser_left",
      apps = {
        browser = "standard_browser_left",
        terminal = "standard_terminal_right",
        tern = "standard_terminal_right",
        agenda = "standard_utility_overlay",
        discord = "standard_utility_overlay",
        files = "standard_utility_overlay",
        obsidian = "standard_utility_overlay",
        onepassword = "standard_utility_overlay",
        outlook = "standard_utility_overlay",
        signal = "standard_utility_overlay",
        spotify = "standard_utility_overlay",
        teams = "standard_utility_overlay",
      },
    },
    fourk = {
      name = "4K Workspace",
      cells = {
        "fourk_left_large", "fourk_right_side", "fourk_top_right",
        "fourk_center_left_large", "fourk_center_large", "fourk_right_small",
      },
      default = "fourk_center_large",
      tile = "fourk_right_side",
      apps = {
        terminal = "fourk_left_large",
        tern = "fourk_left_large",
        browser = "fourk_right_side",
        discord = "fourk_top_right",
        obsidian = "fourk_top_right",
        signal = "fourk_top_right",
        files = "fourk_center_left_large",
        onepassword = "fourk_center_left_large",
        outlook = "fourk_center_left_large",
        spotify = "fourk_center_left_large",
        teams = "fourk_center_large",
        agenda = "fourk_right_small",
      },
    },
    hd = {
      name = "HD Workspace",
      cells = { "hd_left_main", "hd_right_side", "hd_float_center" },
      default = "hd_float_center",
      tile = "hd_right_side",
      apps = {
        terminal = "hd_left_main",
        tern = "hd_left_main",
        browser = "hd_right_side",
        agenda = "hd_float_center",
        discord = "hd_float_center",
        files = "hd_float_center",
        obsidian = "hd_float_center",
        onepassword = "hd_float_center",
        outlook = "hd_float_center",
        signal = "hd_float_center",
        spotify = "hd_float_center",
        teams = "hd_float_center",
      },
    },
    fullscreen = { name = "Fullscreen", monocle = true },
  },

  -- First match wins. name: output connector (hyprctl monitors). builtin: the laptop panel.
  -- Mirrors screen_layouts.lua: the built-in display is Fullscreen, every other screen Standard Dev.
  screens = {
    -- { name = "DP-1", layout = "fourk" },
    { builtin = true, layout = "fullscreen" },
    { layout = "standard" },
  },
}
