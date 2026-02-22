# Ghostty Role

Configures Ghostty terminal emulator with GPU-accelerated effects and custom GLSL shaders.

## Key Files
- `~/.config/ghostty/config` - Main configuration
- `~/.config/ghostty/shaders/` - Custom cursor effect shaders
- `files/shaders/cursor_blaze.glsl` - Electric trail effect
- `files/shaders/cursor_smear.glsl` - Smooth trailing effect (Catppuccin colors)

## Patterns
- **Nightly builds required**: Uses `ghostty@tip` for background-image support
- **Custom shaders**: GLSL shaders for cursor effects using Ghostty's built-in variables
- **Hidden titlebar**: `macos-titlebar-style = hidden` for minimal UI

## Key Config Settings
```ini
theme = catppuccin-mocha
font-family = "BerkeleyMono Nerd Font"
custom-shader = shaders/cursor_blaze.glsl
background-image-opacity = 0.5
auto-update-channel = tip
```

## Integration
- **Catppuccin theme**: Consistent with dotfiles ecosystem theming
- **Shell integration**: `shell-integration-features = no-cursor` prevents shell cursor conflicts

## Gotchas
- **macOS only**: Linux/Windows task files not implemented yet
- **Background images need nightly**: Stable releases lack `background-image` support
- **Shader GPU requirements**: Complex shaders may not work on older hardware
- **Legacy config path**: Uninstall handles both `~/.config/ghostty/` and `~/Library/Application Support/com.mitchellh.ghostty`
- **Font dependency**: Requires BerkeleyMono Nerd Font installed separately
