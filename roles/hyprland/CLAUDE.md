# Hyprland Role Documentation

## Overview

The Hyprland role automates the installation and configuration of Hyprland, a dynamic tiling Wayland compositor, on Ubuntu systems. This role uses a hybrid approach: leveraging the [JaKooLit Ubuntu-Hyprland installer](https://github.com/JaKooLit/Ubuntu-Hyprland) for system-level installation while maintaining custom configurations through version-controlled dotfiles.

## Purpose

Hyprland provides a modern, efficient window management experience with:
- **Tiling window management** with vim-style navigation
- **Scratchpad workspaces** for instant app access (inspired by Hammerspoon workflow)
- **Beautiful animations** and visual effects
- **Wayland native** for better performance and security
- **Highly customizable** through simple configuration files

## Architecture

### Installation Strategy

1. **System Installation** (via JaKooLit)
   - Detects Ubuntu version (24.04, 24.10, etc.)
   - Clones version-specific branch from JaKooLit repository
   - Falls back to `main` branch if version-specific doesn't exist
   - Runs automated installer with preset configuration
   - Installs Hyprland, Waybar, rofi, hyprlock, hypridle, and dependencies

2. **Configuration Management** (via Dotfiles)
   - Symlinks custom configs from `roles/hyprland/files/`
   - Maintains version control of all configurations
   - Updates terminal emulator configs for Wayland compatibility
   - Preserves user customizations through git

### Components Installed

| Component | Purpose | Config Location |
|-----------|---------|-----------------|
| **Hyprland** | Window compositor | `~/.config/hyprland/hyprland.conf` |
| **Waybar** | Status bar | `~/.config/waybar/config` |
| **rofi-wayland** | Application launcher | System default |
| **hyprlock** | Screen locker | `~/.config/hyprland/hyprlock.conf` |
| **hypridle** | Idle management | `~/.config/hyprland/hypridle.conf` |
| **hyprpaper** | Wallpaper daemon | `~/.config/hyprland/hyprpaper.conf` |
| **swappy** | Screenshot tool | System default |
| **nwg-look** | GTK theme manager | System default |

## Usage

### Installation

```bash
# Install Hyprland with all dependencies
dotfiles -t hyprland

# Test without making changes
dotfiles -t hyprland --check

# Install with verbose output
dotfiles -t hyprland -vvv
```

### Accessing Hyprland

1. Log out of your current session
2. At the login screen, click the gear icon (session selector)
3. Select "Hyprland" from the list
4. Log in with your password

### Basic Keyboard Shortcuts

**Scratchpads** (Quick app access - replaces Hammerspoon F13 modal):
- `Super + T` - Toggle terminal scratchpad
- `Super + N` - Toggle notes (Obsidian) scratchpad
- `Super + O` - Toggle 1Password scratchpad
- `Super + I` - Toggle music (Spotify) scratchpad
- `Super + F` - Toggle file manager scratchpad
- `Super + G` - Toggle AI (Claude) scratchpad

**Window Management** (Vim-style):
- `Super + H/J/K/L` - Focus left/down/up/right window
- `Super + Shift + H/J/K/L` - Move window left/down/up/right
- `Super + Ctrl + H/J/K/L` - Resize window
- `Super + Q` - Close window
- `Super + V` - Toggle floating mode
- `Super + M` - Maximize window

**Workspaces**:
- `Super + 1-9` - Switch to workspace 1-9
- `Super + Shift + 1-9` - Move window to workspace 1-9
- `Super + [` / `Super + ]` - Previous/Next workspace

**Application Launchers**:
- `Super + D` - Application launcher (rofi)
- `Super + Return` - New terminal window
- `Super + B` - Browser
- `Super + E` - File manager

**Utilities**:
- `Super + Shift + S` - Screenshot (region select)
- `Super + C` - Lock screen
- `Super + Shift + R` - Reload Waybar
- `Super + Shift + X` - Exit Hyprland

## Configuration

### Main Configuration Files

All configuration files are symlinked from `roles/hyprland/files/` to `~/.config/`:

#### `hyprland.conf`
Main Hyprland configuration with:
- Monitor setup
- Startup applications
- Window rules and auto-positioning
- Keybindings
- Animations and visual effects
- Workspace configuration

**To customize**: Edit `roles/hyprland/files/hyprland.conf` and run `dotfiles -t hyprland`

#### `hyprlock.conf`
Screen lock configuration with Catppuccin Mocha theme.

**Features**:
- Blurred screenshot background
- Password input with visual feedback
- Clock and date display
- User information

#### `hypridle.conf`
Idle management configuration.

**Default behavior**:
- 2.5 minutes: Dim screen to 10%
- 5 minutes: Turn off screen
- 10 minutes: Lock screen
- 30 minutes: Suspend (optional, commented out)

**To adjust timeouts**: Edit `roles/hyprland/files/hypridle.conf` and reload

#### `hyprpaper.conf`
Wallpaper configuration.

**To change wallpaper**:
1. Place wallpaper at `~/Pictures/wallpaper.jpg`
2. Or edit `hyprpaper.conf` to point to your wallpaper location

#### `waybar/config` and `waybar/style.css`
Status bar configuration with Catppuccin Mocha theme.

**Modules** (left to right):
- Workspaces
- Active window title
- Clock (center)
- Audio, Network, CPU, Memory, Temperature, Battery, System tray

**To customize**: Edit config files and reload with `Super + Shift + R`

### Scratchpad Workflow

Scratchpads are special workspaces that float above all other windows and can be toggled instantly.

**How it works**:
1. Applications launch into special workspaces on startup (hidden)
2. Press keybind to show/hide the scratchpad
3. Applications stay running in background when hidden

**Benefits**:
- Instant access to frequently used apps
- No startup delay (apps are pre-launched)
- Clean workspace (apps hidden when not needed)
- Better than traditional alt-tab workflow

**Configured scratchpads**:
- Terminal (`ghostty`) - Super+T
- Notes (`obsidian`) - Super+N
- Passwords (`1password`) - Super+O
- Music (`spotify`) - Super+I
- Files (`thunar`) - Super+F
- AI (`claude`) - Super+G

**To add more scratchpads**:
Edit `hyprland.conf` and add:
```conf
# In startup section
exec-once = [workspace special:name silent] application

# In keybindings section
bind = $mainMod, KEY, togglespecialworkspace, name

# In window rules section (optional sizing)
windowrulev2 = size 1400 900, class:^(app)$, onworkspace:special:name
```

### Window Rules

Window rules automatically position and size applications.

**Current rules** (see `hyprland.conf:96-141`):
- Browsers: Maximized
- Chat apps (Discord, Slack): Floating, top-right (800x900)
- Email: Floating, centered (1400x900)
- Teams/Zoom: Maximized
- Scratchpads: Centered with specific sizes per app

**To add custom rules**:
```conf
# Float and position app
windowrulev2 = float, class:^(myapp)$
windowrulev2 = size 1200 800, class:^(myapp)$
windowrulev2 = move 100 100, class:^(myapp)$

# Or center it
windowrulev2 = center, class:^(myapp)$
```

**Finding app class**:
Run in terminal: `hyprctl clients` and look for the `class` field

### Terminal Emulator Integration

The role automatically adds Wayland flags to terminal configs:

**Kitty** (`~/.config/kitty/kitty.conf`):
```conf
linux_display_server wayland
wayland_titlebar_color background
```

**Ghostty** (`~/.config/ghostty/config`):
```conf
wayland-app-id = ghostty
```

These changes are made automatically during installation.

## Workflow Philosophy

This configuration translates the Hammerspoon (macOS) workflow to Hyprland:

| Hammerspoon Pattern | Hyprland Equivalent | Improvement |
|---------------------|---------------------|-------------|
| F13 + letter (modal summon) | Super + letter (direct scratchpad) | 1 keypress instead of 2 |
| Cell-based layouts | Window rules + auto-positioning | Automatic, no manual assignment |
| Layout switching (Hyper+P) | Workspace switching (Super+1-9) | Built-in, persistent contexts |
| Hyper+hjkl (focus) | Super+hjkl (same) | Native support, faster |

**Muscle memory transfers**:
- `F13 + T` → `Super + T` (terminal)
- `Hyper + hjkl` → `Super + hjkl` (navigation)
- `Hyper + P` → `Super + 1-9` (workspace switch)
- `Hyper + Q` → `Super + Q` (close window)

## Troubleshooting

### Hyprland session doesn't appear at login

**Check session file**:
```bash
ls /usr/share/wayland-sessions/
# Should contain: hyprland.desktop
```

**If missing**, run:
```bash
sudo cp /usr/share/applications/Hyprland.desktop /usr/share/wayland-sessions/
```

**Verify login manager**:
```bash
systemctl status gdm  # or sddm, lightdm, etc.
```

### Screen is black after login

**Possible causes**:
1. Config syntax error
2. Missing dependencies
3. NVIDIA driver issues

**Debug steps**:
```bash
# Check Hyprland logs
cat ~/.local/share/hyprland/hyprland.log

# Test config syntax
hyprland --config ~/.config/hyprland/hyprland.conf --check

# Run from TTY (Ctrl+Alt+F3)
Hyprland
# Watch for error messages
```

### NVIDIA issues

**Symptoms**: Black screen, flickering, cursor invisible

**Solution**: Ensure NVIDIA environment variables are set in `hyprland.conf`:
```conf
env = LIBVA_DRIVER_NAME,nvidia
env = XDG_SESSION_TYPE,wayland
env = GBM_BACKEND,nvidia-drm
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = WLR_NO_HARDWARE_CURSORS,1
```

**Check NVIDIA driver**:
```bash
nvidia-smi  # Should show driver version
```

### Waybar not appearing

**Check if running**:
```bash
pgrep waybar
```

**Restart manually**:
```bash
killall waybar
waybar &
```

**Check logs**:
```bash
waybar -l debug
```

### Applications not launching into scratchpads

**Verify app is installed**:
```bash
which ghostty obsidian 1password spotify
```

**Check hyprland.conf startup section**:
Look for `exec-once = [workspace special:name silent] app`

**Manual launch**:
```bash
hyprctl dispatch exec "[workspace special:terminal silent] ghostty"
```

### Keybinds not working

**Check config syntax**:
```bash
grep "^bind" ~/.config/hyprland/hyprland.conf
```

**Reload config**:
```bash
hyprctl reload
```

**Test specific bind**:
```bash
# Run in terminal and press the keybind
hyprctl keyword bind "SUPER, T, togglespecialworkspace, terminal"
```

### Terminal Wayland flags not applying

The role uses `failed_when: false` for terminal config updates, so:
- If terminal not installed: No error, just skips
- If config doesn't exist: No error, just skips

**Verify manually**:
```bash
# Kitty
grep wayland ~/.config/kitty/kitty.conf

# Ghostty
grep wayland ~/.config/ghostty/config
```

**Add manually if needed**:
```bash
# Kitty
echo "linux_display_server wayland" >> ~/.config/kitty/kitty.conf

# Ghostty
echo "wayland-app-id = ghostty" >> ~/.config/ghostty/config
```

## Maintenance

### Updating Hyprland

Hyprland updates come through system package manager:
```bash
sudo apt update
sudo apt upgrade
```

### Updating configurations

1. Edit files in `~/.dotfiles/roles/hyprland/files/`
2. Commit changes: `git add . && git commit -m "Update Hyprland config"`
3. Apply changes: `dotfiles -t hyprland`
4. Reload Hyprland: `hyprctl reload` or `Super + Shift + R` (for Waybar)

### Upgrading Ubuntu version

When you upgrade Ubuntu (e.g., 24.04 → 24.10):
1. The role automatically detects new version
2. Pulls corresponding JaKooLit branch
3. No code changes needed!

### Uninstalling Hyprland

**Complete removal**:
```bash
cd ~/.dotfiles
./roles/hyprland/uninstall.sh
```

This will:
1. Run JaKooLit's official uninstall script
2. Remove all configuration files
3. Remove Wayland flags from terminal configs
4. Clean up installer cache

**Partial removal** (keep configs):
```bash
# Remove packages only (manual)
sudo apt remove hyprland waybar rofi-wayland
```

## Development

### Adding new scratchpad

1. Edit `roles/hyprland/files/hyprland.conf`
2. Add startup command:
   ```conf
   exec-once = [workspace special:myapp silent] myappcommand
   ```
3. Add keybind:
   ```conf
   bind = $mainMod, KEY, togglespecialworkspace, myapp
   ```
4. Add window rule for sizing (optional):
   ```conf
   windowrulev2 = size 1200 800, class:^(myapp)$, onworkspace:special:myapp
   ```
5. Apply changes: `dotfiles -t hyprland`

### Customizing theme colors

All colors use Catppuccin Mocha palette.

**To change**:
1. Edit color definitions in:
   - `waybar/style.css` (status bar)
   - `hyprlock.conf` (lock screen)
   - `hyprland.conf` (borders, etc.)
2. Apply changes: `dotfiles -t hyprland`
3. Reload: `Super + Shift + R` (Waybar) or `hyprctl reload` (Hyprland)

### Testing changes

**Dry run**:
```bash
dotfiles -t hyprland --check
```

**Ansible syntax check**:
```bash
ansible-playbook ~/.dotfiles/main.yml --syntax-check
```

**Idempotency test**:
```bash
# Should show 0 changes on second run
dotfiles -t hyprland
dotfiles -t hyprland --check
```

## Known Issues

### JaKooLit installer changes

**Issue**: JaKooLit script may change over time, breaking integration.

**Mitigation**:
- Role uses `creates: /usr/bin/Hyprland` to prevent re-runs
- Pins to version-specific branches when available
- Expected behavior documented in PRP

**If installer breaks**:
1. Check JaKooLit repository for changes
2. Update preset file if format changed
3. Report issue in dotfiles repository

### WSL incompatibility

**Issue**: Wayland doesn't work in WSL.

**Mitigation**:
- Role detects WSL environment automatically
- Skips installation with clear message
- No error, just informational output

### Preset file format

**Issue**: JaKooLit may change preset format.

**Mitigation**:
- Keep preset simple (key=value pairs)
- Format documented in comments
- Check JaKooLit repo before Ubuntu upgrades

## Reference

### External Documentation
- [Hyprland Wiki](https://wiki.hyprland.org/)
- [JaKooLit Ubuntu-Hyprland](https://github.com/JaKooLit/Ubuntu-Hyprland)
- [Waybar Documentation](https://github.com/Alexays/Waybar/wiki)
- [Catppuccin Theme](https://github.com/catppuccin/catppuccin)

### Internal References
- **Feature Spec**: `PRPs/features/hyprland-window-manager.feature.md`
- **PRP**: `PRPs/hyprland-window-manager.md`
- **Main README**: `README.md`
- **System Role**: `roles/system/` (WSL detection)
- **Docker Role**: `roles/docker/` (sudo handling pattern)
- **Ghostty Role**: `roles/ghostty/` (config deployment pattern)

### File Locations
- **Role files**: `~/.dotfiles/roles/hyprland/`
- **Hyprland config**: `~/.config/hyprland/`
- **Waybar config**: `~/.config/waybar/`
- **Installer cache**: `~/.cache/hyprland-installer/`
- **Logs**: `~/.local/share/hyprland/hyprland.log`

## Support

For issues or questions:
1. Check this documentation first
2. Review Hyprland logs: `~/.local/share/hyprland/hyprland.log`
3. Check JaKooLit repository: https://github.com/JaKooLit/Ubuntu-Hyprland/issues
4. Open issue in dotfiles repository with:
   - Ubuntu version
   - Error messages
   - Relevant log excerpts
   - Steps to reproduce
