# AwesomeWM Cell-Based Window Management

## Overview

The AwesomeWM role implements a Hammerspoon-inspired cell-based window management system for Ubuntu. This provides:
- **80x40 virtual grid** for resolution-independent window positioning
- **F13 modal summoning** for instant app access (F13 + letter key)
- **Toggle behavior** (summon app twice to return to previous app)
- **Multiple layouts** with app-to-cell assignments
- **Manual window management** with Hyper key shortcuts

## Installation

```bash
# Install AwesomeWM with cell management
dotfiles -t awesomewm

# Test without making changes
dotfiles -t awesomewm --check

# Install with verbose output
dotfiles -t awesomewm -vvv
```

## Accessing AwesomeWM

1. Log out of your current session
2. At the login screen, click the gear icon (session selector)
3. Select "AwesomeWM" from the list
4. Log in with your password

## Keyboard Shortcuts

### Application Summoning (F13 Modal)

Press **F13** to enter summon mode, then press a letter key:

- **F13 + t** → Ghostty Terminal
- **F13 + b** → Brave Browser
- **F13 + d** → Discord
- **F13 + s** → Spotify (Music)
- **F13 + n** → Obsidian (Notes)
- **F13 + o** → 1Password

**Toggle Behavior**: Press the summon key twice to toggle back to the previous app.

**Example**:
1. F13 + t → Ghostty focuses
2. F13 + b → Brave focuses
3. F13 + t → Ghostty focuses (toggle)
4. F13 + t → Brave focuses (toggle back)

### Window Focus Navigation (Hyper + hjkl)

**Hyper** = Shift + Super + Alt + Ctrl (all four modifiers)

- **Hyper + h** → Focus window to the left
- **Hyper + j** → Focus window below
- **Hyper + k** → Focus window above
- **Hyper + l** → Focus window to the right

### Layout Management

- **Hyper + p** → Interactive layout picker
- **Hyper + ;** → Cycle to next layout
- **Hyper + u** → Bind focused window to cell (manual positioning)

### Standard AwesomeWM Shortcuts

- **Super + Enter** → Open terminal
- **Super + r** → Run prompt
- **Super + Ctrl + r** → Reload AwesomeWM
- **Super + Shift + q** → Quit AwesomeWM
- **Super + 1-9** → Switch to workspace 1-9
- **Super + Shift + 1-9** → Move window to workspace

## Configuration

All configuration files are in `~/.config/awesome/cell-management/`:

### Main Configuration Files

#### `apps.lua` - Application Registry

Define applications with their WM_CLASS and summon keys:

```lua
Terminal = {
  class = "ghostty",    -- WM_CLASS (verify with xprop)
  summon = "t",         -- F13 + t
  exec = "ghostty",     -- Launch command
},
```

**To add a new app**:
1. Find WM_CLASS: `xprop WM_CLASS` (click on window)
2. Add entry to `apps.lua`
3. Reload AwesomeWM: Super + Ctrl + r

#### `positions.lua` - Cell Definitions

Named cell positions using the 80x40 virtual grid:

```lua
fourk = {
  left_large = "0,0 52x40",      -- 65% width, full height
  right_side = "52,0 28x40",     -- 35% width, full height
  top_right = "50,2 28x20",      -- Floating top-right
  -- ... more cells
}
```

**To add a new cell**:
1. Edit `positions.lua`
2. Add cell definition: `"x,y wxh"` format
3. Use in layout definitions

#### `layouts.lua` - Layout Definitions

Define layouts with cell and app assignments:

```lua
{
  name = "4K Workspace",
  cells = {
    { positions.fourk.left_large, positions.full },  -- Cell 1
    { positions.fourk.right_side, positions.full },  -- Cell 2
    -- ... more cells
  },
  apps = {
    Terminal = { cell = 1, open = true },  -- Auto-launch in cell 1
    Browser  = { cell = 2, open = true },
    Discord  = { cell = 3 },               -- Don't auto-launch
  },
}
```

**To create a new layout**:
1. Copy existing layout in `layouts.lua`
2. Rename and adjust cell definitions
3. Update app assignments
4. Reload AwesomeWM

### Grid System

The cell management system uses an **80x40 virtual grid** that maps to your screen resolution:

- **Grid coordinates**: `"x,y wxh"` format
  - `x`: Column offset (0-79)
  - `y`: Row offset (0-39)
  - `w`: Width in grid units (1-80)
  - `h`: Height in grid units (1-40)

**Example on 4K (3840x2160)**:
- `"0,0 52x40"` → 65% width (2496px), full height (2160px)
- `"52,0 28x40"` → 35% width (1344px), full height (2160px)

The grid is resolution-independent, so the same cell definitions work on any screen size.

## Workflow Philosophy

This configuration translates the Hammerspoon (macOS) workflow to AwesomeWM:

| Hammerspoon Pattern | AwesomeWM Equivalent |
|---------------------|---------------------|
| F13 + letter (modal summon) | F13 + letter (same) |
| Cell-based layouts | Cell-based layouts (same) |
| Layout switching (Hyper+P) | Hyper+p (same) |
| Hyper+hjkl (focus) | Hyper+hjkl (same) |

**Muscle memory transfers directly** from macOS to Ubuntu!

## Troubleshooting

### AwesomeWM session doesn't appear at login

**Check session file**:
```bash
ls /usr/share/xsessions/
# Should contain: awesome.desktop
```

**Verify installation**:
```bash
which awesome
awesome --version
```

### Configuration errors on startup

**Check syntax**:
```bash
awesome -k ~/.config/awesome/rc.lua
# Should output: "Configuration file syntax OK"
```

**View error log**:
```bash
tail -f ~/.xsession-errors
# Or if using systemd:
journalctl -f
```

### F13 key not working

**Option 1: Use F14 instead**

Edit `~/.config/awesome/cell-management/keybindings.lua`:
```lua
awful.key({}, 'F14', function()  -- Change F13 to F14
  summon_modal:start()
end),
```

**Option 2: Remap another key to F13**

Use `xmodmap` or your keyboard settings to remap an unused key to F13.

### Hyper key hard to press

**Use Super+Shift instead**

Edit `~/.config/awesome/cell-management/keybindings.lua`:
```lua
local hyper = { 'Mod4', 'Shift' }  -- Easier than 4-key combo
```

### App not positioning correctly

**Verify WM_CLASS**:
```bash
xprop WM_CLASS
# Click on the application window
# Output: WM_CLASS(STRING) = "class", "Class"
```

**Update apps.lua** with the exact class string (case-sensitive!):
```lua
MyApp = {
  class = "exact-class-from-xprop",  -- Use lowercase value
  summon = "x",
  exec = "myapp",
},
```

**Common WM_CLASS values**:
- Ghostty: `ghostty`
- Brave: `brave-browser`
- Discord: `discord`
- Spotify: `Spotify` (capital S!)
- Obsidian: `obsidian`
- 1Password: `1Password` (capital P!)

### Windows overlap status bar

The grid system uses `screen.workarea` which should exclude the status bar. If windows still overlap:

1. Check AwesomeWM wibar configuration in `rc.lua`
2. Verify no custom geometry overrides
3. Restart AwesomeWM: Super + Ctrl + r

## Known Limitations (v1)

1. **No layout persistence**: State resets on AwesomeWM restart
2. **No visual feedback**: Modal entry/exit has no on-screen indicator
3. **No cell overlay**: Hyper+u uses text prompt, not visual overlay
4. **Single monitor only**: Multi-monitor not supported in v1
5. **Fixed grid**: 80x40 grid not configurable at runtime
6. **First window only**: Multi-window apps (multiple browser windows) - only first window handled

## Development

### Adding a New Application

1. **Find WM_CLASS**:
   ```bash
   xprop WM_CLASS  # Click on app window
   ```

2. **Add to apps.lua**:
   ```lua
   MyApp = {
     class = "myapp",     -- From xprop (lowercase)
     summon = "m",        -- F13 + m
     exec = "myapp-cmd",  -- Launch command
   },
   ```

3. **Add to layout** (optional):
   ```lua
   apps = {
     -- ... existing apps
     MyApp = { cell = 5, open = true },  -- Auto-launch in cell 5
   }
   ```

4. **Reload AwesomeWM**: Super + Ctrl + r

5. **Test**: F13 + m → MyApp launches/focuses

### Creating a New Layout

1. **Edit layouts.lua**:
   ```lua
   {
     name = "My Custom Layout",
     cells = {
       { positions.halves.left, positions.full },   -- Cell 1
       { positions.halves.right, positions.full },  -- Cell 2
     },
     apps = {
       Terminal = { cell = 1, open = true },
       Browser  = { cell = 2, open = true },
     },
   },
   ```

2. **Reload AwesomeWM**: Super + Ctrl + r

3. **Test**: Hyper + p → Select your new layout

### Defining Custom Cells

1. **Edit positions.lua**:
   ```lua
   custom = {
     left_third = "0,0 27x40",     -- Left 33%
     center_third = "27,0 26x40",  -- Center 33%
     right_third = "53,0 27x40",   -- Right 33%
   }
   ```

2. **Use in layout**:
   ```lua
   cells = {
     { positions.custom.left_third, positions.full },
     { positions.custom.center_third, positions.full },
     { positions.custom.right_third, positions.full },
   }
   ```

## Settings Tools (No GNOME Required)

| Setting | Command | Description |
|---------|---------|-------------|
| Audio/Mic/Speaker | `pavucontrol` | Default devices, volume levels |
| Display/Monitors | `arandr` | Screen layout, resolution, rotation |
| GTK Themes/Fonts | `lxappearance` | Appearance, icons, cursor |
| Bluetooth | `blueman-manager` | Pairing, connections |
| Network | `nm-connection-editor` | WiFi, VPN, Ethernet |
| Profile Picture | Log into GNOME once, or use AccountsService |

## Uninstalling

**Remove configuration only**:
```bash
./roles/awesomewm/uninstall.sh
```

**Complete removal** (including AwesomeWM package):
```bash
sudo apt remove awesome xdotool
rm -rf ~/.config/awesome
```

## Reference

### Internal Files
- **PRP**: `PRPs/awesomewm-cell-management.md`
- **Feature Spec**: `PRPs/features/awesomewm-cell-management.feature.md`
- **Hammerspoon Role**: `roles/hammerspoon/` (macOS reference)

### External Documentation
- **AwesomeWM API**: https://awesomewm.org/doc/api/
- **AwesomeWM Wiki**: https://wiki.archlinux.org/title/Awesome
- **Lua Reference**: http://www.lua.org/manual/5.3/

## Support

For issues or questions:
1. Check this documentation first
2. Verify WM_CLASS with `xprop WM_CLASS`
3. Check syntax: `awesome -k ~/.config/awesome/rc.lua`
4. View logs: `tail -f ~/.xsession-errors`
5. Open issue in dotfiles repository with:
   - Ubuntu version
   - Error messages
   - Steps to reproduce
