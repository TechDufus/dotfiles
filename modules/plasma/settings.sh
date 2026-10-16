#!/usr/bin/env bash
# Sparse KConfig writes for stable Plasma preferences; sourced by bootstrap.sh.
# Discover a live value with: kreadconfig6 --file <file> --group <outer> [--group <inner>] --key <key>
# then add one explicit line below. Do not raw-copy Plasma-generated session files.

# One failed write warns and lets the rest continue.
kwriteconfig6() {
  command kwriteconfig6 "$@" || echo "plasma: kwriteconfig6 $* failed, skipped" >&2
}

# Input
kwriteconfig6 --file kcminputrc --group Keyboard --key RepeatDelay 400
kwriteconfig6 --file kcminputrc --group Keyboard --key RepeatRate 30
kwriteconfig6 --file kcminputrc --group Mouse --key cursorTheme Sweet-cursors

# Notifications
kwriteconfig6 --file plasmanotifyrc --group Notifications --key PopupTimeout 4000

# KWin
kwriteconfig6 --file kwinrc --group Plugins --key blurEnabled true
kwriteconfig6 --file kwinrc --group Plugins --key mouseclickEnabled true
kwriteconfig6 --file kwinrc --group Windows --key ElectricBorders 1
kwriteconfig6 --file kwinrc --group Xwayland --key Scale 1
kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key library org.kde.oxygen
kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme Oxygen

# Globals
kwriteconfig6 --file kdeglobals --group General --key BrowserApplication brave-browser.desktop
kwriteconfig6 --file kdeglobals --group General --key TerminalApplication '/usr/bin/ghostty --gtk-single-instance=true'
kwriteconfig6 --file kdeglobals --group General --key TerminalService com.mitchellh.ghostty.desktop
kwriteconfig6 --file kdeglobals --group General --key XftAntialias true
kwriteconfig6 --file kdeglobals --group General --key XftHintStyle hintslight
kwriteconfig6 --file kdeglobals --group General --key XftSubPixel none
kwriteconfig6 --file kdeglobals --group General --key fixed 'BerkeleyMono Nerd Font,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1,,0,0'
kwriteconfig6 --file kdeglobals --group General --key font 'BerkeleyMono Nerd Font,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1,,0,0'
kwriteconfig6 --file kdeglobals --group General --key menuFont 'BerkeleyMono Nerd Font,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1,,0,0'
kwriteconfig6 --file kdeglobals --group General --key smallestReadableFont 'BerkeleyMono Nerd Font,8,-1,5,400,0,0,0,0,0,0,0,0,0,0,1,,0,0'
kwriteconfig6 --file kdeglobals --group General --key toolBarFont 'BerkeleyMono Nerd Font,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1,,0,0'
kwriteconfig6 --file kdeglobals --group Icons --key Theme candy-icons
kwriteconfig6 --file kdeglobals --group KDE --key AnimationDurationFactor 0.125
kwriteconfig6 --file kdeglobals --group KDE --key DefaultDarkLookAndFeel CachyOS-Nord
kwriteconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage org.kde.breezedark.desktop

# Locale
kwriteconfig6 --file plasma-localerc --group Formats --key LANG en_US.UTF-8

# Power (AC)
kwriteconfig6 --file powerdevilrc --group AC --group Display --key DimDisplayIdleTimeoutSec 600
kwriteconfig6 --file powerdevilrc --group AC --group Display --key TurnOffDisplayIdleTimeoutSec 900
kwriteconfig6 --file powerdevilrc --group AC --group Display --key TurnOffDisplayIdleTimeoutWhenLockedSec 120
kwriteconfig6 --file powerdevilrc --group AC --group SuspendAndShutdown --key AutoSuspendIdleTimeoutSec 5400
kwriteconfig6 --file powerdevilrc --group AC --group SuspendAndShutdown --key PowerButtonAction 1

# Plasma summon: enable the KWin script and reserve the Tools key
kwriteconfig6 --file kwinrc --group Plugins --key plasma-summonEnabled true
kwriteconfig6 --file kglobalshortcutsrc --group systemsettings.desktop --key _launch $'none,Tools\tMeta+I,System Settings'

# Plasma summon KWin shortcuts
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key 'Move Active to Cell 1' 'none,none,Move active window to layout cell 1'
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key 'Move Active to Cell 2' 'none,none,Move active window to layout cell 2'
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key 'Move Active to Cell 3' 'none,none,Move active window to layout cell 3'
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key 'Move Active to Cell 4' 'none,none,Move active window to layout cell 4'
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key 'Move Active to Cell 5' 'none,none,Move active window to layout cell 5'
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key 'Move Active to Cell 6' 'none,none,Move active window to layout cell 6'
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key 'Move Active to Region bottom_right' 'none,none,Move active window to bottom_right'
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key 'Move Active to Region center' 'none,none,Move active window to center'
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key 'Move Active to Region chat' 'none,none,Move active window to chat'
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key 'Move Active to Region full' 'none,none,Move active window to full'
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key 'Move Active to Region left' 'none,none,Move active window to left'
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key 'Move Active to Region main' 'none,none,Move active window to main'
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key 'Move Active to Region right' 'none,none,Move active window to right'
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key 'Move Active to Region side' 'none,none,Move active window to side'
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key 'Move Active to Region top_right' 'none,none,Move active window to top_right'
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key 'Move Active to Region wide' 'none,none,Move active window to wide'
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key 'Cycle Active Screen Layout' 'none,none,Cycle active screen layout'
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key 'Pick Active Window Region' 'none,none,Pick region/cell for active window'
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key 'Pick Active Screen Layout' 'none,none,Pick active screen layout'
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key 'Open Plasma Summon Window Mover' 'Meta+U,none,Pick region/cell for active window'
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key 'Hide Active Window' 'Meta+H,none,Minimize active window'
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key 'Open Plasma Summon Layout Picker' 'Meta+Alt+Ctrl+Shift+P,none,Pick active screen layout'

# BrowserApplication above needs this desktop entry.
browser_found=0
for dir in "$HOME/.local/share/applications" /usr/local/share/applications /usr/share/applications \
  "$HOME/.local/share/flatpak/exports/share/applications" /var/lib/flatpak/exports/share/applications; do
  [ -e "$dir/brave-browser.desktop" ] && browser_found=1
done
[ "$browser_found" = 1 ] || echo "plasma: brave-browser.desktop not found; kdeglobals BrowserApplication points at a missing entry" >&2
unset browser_found dir
