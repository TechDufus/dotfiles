-- TechDufus Hyprland config.
-- Symlinked by the `hyprland` role so repo edits reload Hyprland.
-- CachyOS Hyprland 0.55 reports configProvider=lua and loads hyprland.lua directly.
-- Visual direction is Catppuccin Mocha: dark, readable, and maintainable.


------------------
---- MONITORS ----
------------------

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- Current CachyOS desktop: 1080p utility display on the left, 4K primary on the right.
-- Keep a wildcard fallback so laptops and temporary displays still come up.
hl.monitor({
    output   = "DP-1",
    mode     = "1920x1080@60",
    position = "0x0",
    scale    = "1",
})

hl.monitor({
    output   = "HDMI-A-1",
    mode     = "3840x2160@60",
    position = "1920x0",
    scale    = "1.5",
})

hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})


---------------------
---- MY PROGRAMS ----
---------------------

-- Set programs that you use. Keep this boring: Hyprland handles key routing,
-- small helpers handle workflow semantics.
local terminal    = "ghostty"
local fileManager = "thunar"
local menu        = "fuzzel"
local waybarCommand = [[waybar --config "$HOME/.config/waybar/config.jsonc" --style "$HOME/.config/waybar/style.css"]]



-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

-- Autostart core Wayland desktop services. `hl.on("hyprland.start", ...)`
-- runs once per compositor start; config reloads do not duplicate these.
hl.on("hyprland.start", function ()
    hl.exec_cmd("/usr/lib/hyprpolkitagent/hyprpolkitagent")
    hl.exec_cmd("mako")
    hl.exec_cmd([[hyprpaper --config "$HOME/.config/hypr/hyprpaper.conf"]])
    hl.exec_cmd(waybarCommand)
    hl.exec_cmd("nm-applet --indicator")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
end)


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("GDK_BACKEND", "wayland,x11")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("CLUTTER_BACKEND", "wayland")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")


-----------------------
----- PERMISSIONS -----
-----------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Permissions/
-- Please note permission changes here require a Hyprland restart and are not applied on-the-fly
-- for security reasons

-- hl.config({
--   ecosystem = {
--     enforce_permissions = true,
--   },
-- })

-- hl.permission("/usr/(bin|local/bin)/grim", "screencopy", "allow")
-- hl.permission("/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", "screencopy", "allow")
-- hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")


-----------------------
---- LOOK AND FEEL ----
-----------------------

-- Refer to https://wiki.hypr.land/Configuring/Basics/Variables/
hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 10,

        border_size = 1,

        col = {
            active_border   = { colors = {"rgba(cba6f7ee)", "rgba(89b4faee)"}, angle = 45 },
            inactive_border = "rgba(6c7086aa)",
        },

        resize_on_border = false,
        allow_tearing    = false,
        layout           = "dwindle",
    },

    decoration = {
        rounding       = 15,
        rounding_power = 2,

        active_opacity     = 0.97,
        inactive_opacity   = 0.94,
        fullscreen_opacity = 1.0,

        shadow = {
            enabled      = true,
            range        = 15,
            render_power = 4,
            color        = 0xee1a1a1a,
        },

        blur = {
            enabled           = true,
            size              = 8,
            passes            = 2,
            ignore_opacity    = true,
            new_optimizations = true,
            popups            = true,
            input_methods     = true,
            vibrancy          = 0.12,
        },
    },

    animations = {
        enabled = true,
    },
})

-- Material-style curves: soft deceleration in, brisk acceleration out.
hl.curve("materialSpecial",          { type = "bezier", points = { {0.05, 0.7}, {0.1, 1}    } })
hl.curve("materialEmphasizedAccel",  { type = "bezier", points = { {0.3, 0},    {0.8, 0.15} } })
hl.curve("materialEmphasizedDecel",  { type = "bezier", points = { {0.05, 0.7}, {0.1, 1}    } })
hl.curve("materialStandard",         { type = "bezier", points = { {0.2, 0},    {0, 1}      } })

hl.animation({ leaf = "global",           enabled = true, speed = 1, bezier = "materialStandard" })
hl.animation({ leaf = "layersIn",         enabled = true, speed = 5, bezier = "materialEmphasizedDecel", style = "slide" })
hl.animation({ leaf = "layersOut",        enabled = true, speed = 4, bezier = "materialEmphasizedAccel", style = "slide" })
hl.animation({ leaf = "fadeLayers",       enabled = true, speed = 5, bezier = "materialStandard" })
hl.animation({ leaf = "windowsIn",        enabled = true, speed = 5, bezier = "materialEmphasizedDecel" })
hl.animation({ leaf = "windowsOut",       enabled = true, speed = 3, bezier = "materialEmphasizedAccel" })
hl.animation({ leaf = "windowsMove",      enabled = true, speed = 6, bezier = "materialStandard" })
hl.animation({ leaf = "workspaces",       enabled = true, speed = 5, bezier = "materialStandard" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4, bezier = "materialSpecial", style = "slidefadevert 15%" })
hl.animation({ leaf = "fade",             enabled = true, speed = 6, bezier = "materialStandard" })
hl.animation({ leaf = "fadeDim",          enabled = true, speed = 6, bezier = "materialStandard" })
hl.animation({ leaf = "border",           enabled = true, speed = 6, bezier = "materialStandard" })

-- Ref https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/
-- "Smart gaps" / "No gaps when only"
-- uncomment all if you wish to use that.
-- hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
-- hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })
-- hl.window_rule({
--     name  = "no-gaps-wtv1",
--     match = { float = false, workspace = "w[tv1]" },
--     border_size = 0,
--     rounding    = 0,
-- })
-- hl.window_rule({
--     name  = "no-gaps-f1",
--     match = { float = false, workspace = "f[1]" },
--     border_size = 0,
--     rounding    = 0,
-- })

-- See https://wiki.hypr.land/Configuring/Layouts/Dwindle-Layout/ for more
hl.config({
    dwindle = {
        preserve_split = true,
        smart_split    = false,
        smart_resizing = true,
    },

    master = {
        new_status = "master",
    },

    scrolling = {
        fullscreen_on_one_column = true,
        focus_fit_method         = 1,
        column_width             = 0.5,
        follow_focus             = true,
        follow_min_visible       = 0.0,
    },
})

----------------
----  MISC  ----
----------------

hl.config({
    misc = {
        vrr                           = 1,
        animate_manual_resizes        = false,
        animate_mouse_windowdragging  = false,
        force_default_wallpaper       = 0,
        disable_hyprland_logo         = true,
        on_focus_under_fullscreen     = 2,
        allow_session_lock_restore    = true,
        middle_click_paste            = false,
        focus_on_activate             = true,
        session_lock_xray             = true,
        mouse_move_enables_dpms       = true,
        key_press_enables_dpms        = true,
        background_color              = "rgb(11111b)",
    },
})


---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout  = "us",
        kb_variant = "dvorak",
        kb_model   = "pc105",
        kb_options = "caps:none",
        kb_rules   = "",

        numlock_by_default = false,
        repeat_delay       = 250,
        repeat_rate        = 35,
        follow_mouse       = 1,
        focus_on_close     = 1,
        sensitivity        = 0,

        touchpad = {
            natural_scroll       = true,
            disable_while_typing = true,
            scroll_factor        = 0.3,
        },
    },
})

hl.config({
    binds = {
        scroll_event_delay = 0,
    },

    cursor = {
        hotspot_padding = 1,
    },

    gestures = {
        workspace_swipe_distance                 = 700,
        workspace_swipe_cancel_ratio             = 0.15,
        workspace_swipe_min_speed_to_force       = 5,
        workspace_swipe_direction_lock           = true,
        workspace_swipe_direction_lock_threshold = 10,
        workspace_swipe_create_new               = true,
    },
})

hl.gesture({
    fingers = 4,
    direction = "horizontal",
    action = "workspace"
})

-- Example per-device config
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Devices/ for more
hl.device({
    name        = "epic-mouse-v1",
    sensitivity = -0.5,
})


---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER" -- Sets "Windows" key as main modifier
local hyper = "SHIFT + SUPER + ALT + CTRL"
local summonCommand = "hypr-summon app "
local regionCommand = "hypr-summon region "
local cellCommand = "hypr-summon cell "
local cycleRegionCommand = "hypr-summon cycle main wide side chat center full"
local layoutCycleCommand = "hypr-summon layout cycle"
local layoutResetCommand = "hypr-summon layout reset"
local otherMonitorCommand = "hypr-summon monitor next"
local previousMonitorCommand = "hypr-summon monitor previous"
local screenshotArea = [[grim -g "$(slurp)" - | wl-copy]]
local screenshotFullClipboard = "grim - | wl-copy"
local screenshotFullFile = [[mkdir -p "$HOME/Pictures/Screenshots" && grim "$HOME/Pictures/Screenshots/$(date +%Y%m%d-%H%M%S).png"]]
local resetSubmapCommand = [[hyprctl dispatch 'hl.dsp.submap("reset")']]
local function submap_exec(command)
    return hl.dsp.exec_cmd(resetSubmapCommand .. "; " .. command)
end


-- Core desktop binds
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + Q",      hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + C",      hl.dsp.window.close())
hl.bind(mainMod .. " + M",      hl.dsp.exec_cmd([[command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()']]))
hl.bind(mainMod .. " + E",      hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + R",      hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + CONTROL + R", hl.dsp.exec_cmd("hyprctl reload"))
hl.bind(mainMod .. " + Space",  hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + V",      hl.dsp.exec_cmd([[cliphist list | fuzzel --dmenu | cliphist decode | wl-copy]]))
hl.bind(mainMod .. " + L",      hl.dsp.exec_cmd("hyprlock"))
hl.bind(mainMod .. " + F",      hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + T",      hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + P",      hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J",      hl.dsp.layout("togglesplit"))    -- dwindle only

-- Move focus with mainMod + arrow keys and Hyper + hjkl.
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))
hl.bind(hyper .. " + h",       hl.dsp.focus({ direction = "left" }))
hl.bind(hyper .. " + P",         hl.dsp.exec_cmd(layoutCycleCommand))
hl.bind(hyper .. " + semicolon", hl.dsp.exec_cmd(layoutCycleCommand))
hl.bind(hyper .. " + apostrophe", hl.dsp.exec_cmd(layoutResetCommand))
hl.bind(hyper .. " + j",       hl.dsp.focus({ direction = "down" }))
hl.bind(hyper .. " + k",       hl.dsp.focus({ direction = "up" }))
hl.bind(hyper .. " + l",       hl.dsp.focus({ direction = "right" }))

-- Move focus and active windows between the side display and primary display.
-- Hyprland 0.55 currently handles explicit output names more reliably than
-- relative monitor selectors for these dispatchers.
hl.bind(mainMod .. " + CONTROL + left",  hl.dsp.focus({ monitor = "DP-1" }))
hl.bind(mainMod .. " + O",         hl.dsp.exec_cmd(otherMonitorCommand))
hl.bind(mainMod .. " + SHIFT + O", hl.dsp.exec_cmd(previousMonitorCommand))
hl.bind(mainMod .. " + CONTROL + right", hl.dsp.focus({ monitor = "HDMI-A-1" }))
hl.bind(mainMod .. " + SHIFT + left",    hl.dsp.window.move({ monitor = "DP-1", follow = true }))
hl.bind(mainMod .. " + SHIFT + right",   hl.dsp.window.move({ monitor = "HDMI-A-1", follow = true }))

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,             hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key,     hl.dsp.window.move({ workspace = i }))
end

-- Special workspace (scratchpad)
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("scratch"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:scratch" }))

-- Trigger+letter summon. F13 is canonical; the aliases preserve the old
-- AwesomeWM laptop/remap paths seen as XF86Tools or CapsLock.
hl.bind("F13",       hl.dsp.submap("summon"))
hl.bind("XF86Tools", hl.dsp.submap("summon"))
hl.bind("Caps_Lock", hl.dsp.submap("summon"))
hl.bind("code:66",   hl.dsp.submap("summon"))
hl.define_submap("summon", "reset", function()
    hl.bind("t",      submap_exec(summonCommand .. "terminal"))
    hl.bind("b",      submap_exec(summonCommand .. "browser"))
    hl.bind("d",      submap_exec(summonCommand .. "discord"))
    hl.bind("c",      submap_exec(summonCommand .. "signal"))
    hl.bind("s",      submap_exec(summonCommand .. "spotify"))
    hl.bind("n",      submap_exec(summonCommand .. "obsidian"))
    hl.bind("o",      submap_exec(summonCommand .. "onepassword"))
    hl.bind("f",      submap_exec(summonCommand .. "files"))
    hl.bind("g",      submap_exec(summonCommand .. "steam"))
    hl.bind("escape", hl.dsp.submap("reset"))
    hl.bind("catchall", hl.dsp.submap("reset"))
end)

-- Region placement mode for focused windows.
hl.bind(mainMod .. " + U", hl.dsp.submap("regions"))
hl.define_submap("regions", "reset", function()
    hl.bind("m",      submap_exec(regionCommand .. "main"))
    hl.bind("w",      submap_exec(regionCommand .. "wide"))
    hl.bind("s",      submap_exec(regionCommand .. "side"))
    hl.bind("c",      submap_exec(regionCommand .. "chat"))
    hl.bind("e",      submap_exec(regionCommand .. "center"))
    hl.bind("l",      submap_exec(regionCommand .. "left"))
    hl.bind("r",      submap_exec(regionCommand .. "right"))
    hl.bind("t",      submap_exec(regionCommand .. "top_right"))
    hl.bind("b",      submap_exec(regionCommand .. "bottom_right"))
    hl.bind("f",      submap_exec(regionCommand .. "full"))
    hl.bind("space",  submap_exec(cycleRegionCommand))
    hl.bind("Return", submap_exec(cycleRegionCommand))
    for i = 1, 6 do
        hl.bind(tostring(i), submap_exec(cellCommand .. i))
    end
    hl.bind("escape", hl.dsp.submap("reset"))
    hl.bind("catchall", hl.dsp.submap("reset"))
end)

-- Macro layer for actions that are not app summons.
hl.bind("F16",         hl.dsp.submap("macro"))
hl.bind("XF86Launch5", hl.dsp.submap("macro"))
hl.define_submap("macro", "reset", function()
    hl.bind("s",      submap_exec(screenshotArea))
    hl.bind("g",      submap_exec(menu))
    hl.bind("escape", hl.dsp.submap("reset"))
    hl.bind("catchall", hl.dsp.submap("reset"))
end)

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Laptop multimedia keys for volume and LCD brightness
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })

-- Media control keys remain compositor-level binds so games do not receive them.
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-- Screenshots
hl.bind("Print",           hl.dsp.exec_cmd(screenshotArea))
hl.bind("SHIFT + Print",   hl.dsp.exec_cmd(screenshotFullClipboard))
hl.bind("CONTROL + Print", hl.dsp.exec_cmd(screenshotFullFile))

--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- and https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

-- Example window rules that are useful

-- Practical polish: dialogs float, media overlays stay out of the way, and
-- games bypass compositor effects where Hyprland supports it.
hl.window_rule({
    name  = "float-file-dialogs",
    match = { title = "(Select|Open)( a)? (File|Folder)(s)?|Save As|.* Properties" },

    float  = true,
    center = true,
    size   = "70% 80%",
})

hl.window_rule({
    name  = "pin-picture-in-picture",
    match = { title = "Picture(-| )in(-| )[Pp]icture" },

    float             = true,
    pin               = true,
    keep_aspect_ratio = true,
})

hl.window_rule({
    name  = "steam-friends-float",
    match = { class = "steam", title = "Friends List" },

    float    = true,
    rounding = 10,
})

hl.window_rule({
    name  = "game-performance",
    match = { class = "(steam_app_(default|[0-9]+))|gamescope" },

    opaque       = true,
    immediate    = true,
    idle_inhibit = "always",
})

local suppressMaximizeRule = hl.window_rule({
    -- Ignore maximize requests from all apps. You'll probably like this.
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})
-- suppressMaximizeRule:set_enabled(false)

hl.window_rule({
    -- Fix some dragging issues with XWayland
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})


-- Layer rules also return a handle.
-- local overlayLayerRule = hl.layer_rule({
--     name  = "no-anim-overlay",
--     match = { namespace = "^my-overlay$" },
--     no_anim = true,
-- })
-- overlayLayerRule:set_enabled(false)

-- Hyprland-run windowrule
hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
    float = true,
})
