# Omarchy desktop

The shortcuts are in the README's [Omarchy screens](../README.md#omarchy-screens) table. This page explains how the pieces behind them behave.

## Cells and screens

Floating windows that cells does not place, such as dialogs, keep their position and size relative to the screen. Moving a window you tiled with `Super+T` puts it back in its cell. Fullscreen windows stay fullscreen, also across config reloads: Hyprland 0.56 forgets their fullscreen state there without telling the app, and Brave then hides its tabs again on every focus change. When they leave it, a window cells places goes back to its cell; one you tiled or popped out yourself stays where Hyprland restores it. `Super+O` and `Super+Shift+O` replace Omarchy's pop-out and Obsidian bindings. Use CapsLock → `n` to summon Obsidian.

Windows whose class matches a `keep_tiled` entry in `modules/omarchy/hypr/layouts.lua` (Proton and Wine games, `steam_app_*`) stay tiled across the screen instead of floating into a cell: Hyprland lets floating X11 windows move themselves, and on the mixed-scale desk that throws them between screens. An entry is a table with a lowercase Lua-pattern `class` and an optional `except_title`; the Battle.net launcher shares its game's class and is excepted by its title, so it is placed like any other app. `Super+F` still makes tiled games fullscreen. `hypr/games.lua` also turns off focus-on-activate for those games (not for the Battle.net launcher's own windows): Wine asks to be activated again whenever a game loses focus, which otherwise pulls focus and the cursor back from any window floating over it. The Battle.net launcher is a normal window instead of Omarchy's always-on-top float, which stacked above every tiled window and hid summoned apps on the HP's monocle screen: it gets a cell on the 4K and joins the monocle stack on the HP.

The summon leader is CapsLock or F13, as on the Mac (Karabiner turned CapsLock into F13). A keyboard that sends F13 from its Caps Lock key needs no remap.

Every window is fully opaque, focused or not; Omarchy's default translucency is turned off so video never shows the wallpaper through. Apps that should be see-through set it themselves, such as Ghostty's `background-opacity`.

`modules/omarchy/hypr/monitors.lua` sets up the desk with the Acer VG281K 4K and the HP P224 1080p. The HP is on the left, the 4K is main, and the cursor starts there at login. Workspaces 1–3 (terminal, browser, Obsidian) live on the 4K, and workspaces 4–5 (chat, music) on the HP. The HP defaults to the Fullscreen layout. These rules match the panels by description, and the workspace bindings apply only while both panels are connected, so other machines are unaffected.

## Shell plugins

`mise.omarchy.toml` clones four shell plugins into `~/.config/omarchy/plugins/`: [OMP Usage](https://github.com/iamanro/omarchy-omp-usage) (quota, resets and cost for every provider omp is logged in to), [GitHub](https://github.com/robzolkos/omarchy-github) (notifications, review requests, your PRs, Actions), [Resources](https://github.com/Kyotroo/omarchy-bar-resources) (CPU, memory, disk, temperature and network fill-up icons; click for settings) and [OmaSwitch](https://github.com/piyush97/omaswitch) (Alt+Tab switcher with live previews). `bootstrap:omarchy-plugins` enables them, putting the three widgets in the bar, and takes the stock Agents widget out, through the running Omarchy shell, once per plugin list: later changes stay until a list changes. Outside a session it waits for the next run.

Alt+Tab opens OmaSwitch only while it is installed and enabled; on each press `cells.lua` checks the plugin folder and `shell.json`, so `omarchy plugin disable piyush.omaswitch` or `remove` hands Alt+Tab back to plain window cycling without a keybinding change or reload. To drop it for good, delete its `[bootstrap.repos]` entry and its id from `OMARCHY_PLUGINS`, then run `omarchy plugin remove piyush.omaswitch --yes`: mise never deletes a clone.

The GitHub widget reads through `gh`: run `gh auth login`, then `gh auth refresh -h github.com -s notifications -s repo`. `omarchy update` does not update third-party plugins by itself, so a linked post-update hook runs `omarchy plugin update --yes`: every update brings all git-managed plugins to their latest commit, validated and rolled back on failure. `dotfiles --update` also fast-forwards them; a plain `dotfiles` run never fetches them.

## liquidctl

`bootstrap:liquidctl` (Omarchy) acts only on machines with a Lian Li UNI FAN SL hub (USB `0cf2:a100`); elsewhere it prints a skip line. On those machines it installs `liquidctl` from `extra`, plus a udev rule and a oneshot unit that runs `liquidctl --match "Uni SL" initialize` whenever the hub appears (boot or replug), so the fans follow the motherboard's PWM. It warns instead of failing, and repeat runs change nothing and do not prompt for sudo. Check with `liquidctl status` and `systemctl status liquidctl-lianli-uni-sl.service`.

## Battle.net

`bootstrap:battlenet` (Omarchy) sets Battle.net's **When clicking X** to **Exit Battle.net completely** (`HideOnClose` in each account's settings file in Omarchy's prefix, `~/Games/battlenet`). Under Proton, a Battle.net left waiting in the tray is the fragile part: the tray icon can't bring it back, opening it again only asks the hidden copy to show itself (which can come back blank and frozen), and after a day or so it can hang and block every new launch until the prefix is killed. **On game launch** is left to Battle.net's own Settings; pick **Exit Battle.net completely** there. The task does nothing until Battle.net is installed and logged in, and skips with a message while it is running, because Battle.net rewrites these files when it exits.
