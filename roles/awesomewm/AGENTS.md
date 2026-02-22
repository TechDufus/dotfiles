# AwesomeWM Role

Installs AwesomeWM with Hammerspoon-inspired cell-based window management for Ubuntu.

## Key Files
- `~/.config/awesome/rc.lua` - Main AwesomeWM config
- `~/.config/awesome/cell-management/apps.lua` - App registry with WM_CLASS and summon keys
- `~/.config/awesome/cell-management/positions.lua` - Named cell definitions (80x40 grid)
- `~/.config/awesome/cell-management/layouts.lua` - Layout definitions with app assignments
- `~/.config/awesome/cell-management/keybindings.lua` - Hyper key and F13 modal config

## Patterns

### 80x40 Virtual Grid
Resolution-independent positioning using `"x,y wxh"` format:
- `"0,0 52x40"` = 65% width, full height
- Grid maps to any screen resolution

### F13 Modal Summoning
- Laptop: CapsLock remapped to F13 on startup
- External keyboard: Physical F13/F16 keys work directly
- Press F13, then letter key to summon app (e.g., F13+t = Ghostty)
- Same app twice = toggle back to previous app

### WM_CLASS Matching
Apps identified by WM_CLASS (case-sensitive):
```bash
xprop WM_CLASS  # Click window to find class
```
Common values: `com.mitchellh.ghostty`, `brave-browser`, `Spotify` (capital S)

## Integration
- **Mirrors**: Hammerspoon role (macOS) - same keybindings transfer
- **Hyper key**: Shift+Super+Alt+Ctrl for manual window management

## Gotchas
- Ubuntu only (no macOS/Fedora/Arch support)
- CapsLock permanently remapped; use Shift for capitals
- WM_CLASS is case-sensitive (`Spotify` not `spotify`)
- No multi-monitor support in v1
- No layout persistence across restarts
- Double-tap CapsLock (150ms) enters macro mode, not summon mode
