# CLAUDE.md - Tmux Role Documentation

This file provides comprehensive guidance for working with the tmux role in this Ansible-based dotfiles management system.

## Role Overview

The tmux role configures a powerful terminal multiplexer environment with modern features, plugin management, and seamless integration with other development tools. It provides consistent tmux configuration across macOS, Ubuntu, Fedora, and Arch Linux with intelligent fallback mechanisms for restricted environments.

**Key Features:**
- Cross-platform tmux installation with graceful degradation
- Modern plugin ecosystem via TPM (Tmux Plugin Manager)
- Vi-mode key bindings and optimized terminal settings
- Integration with fzf, neovim, and session management tools
- Corporate environment compatibility with custom tmpdir handling
- Rich theming with Catppuccin color scheme
- Advanced session management with sesh integration

## File Structure

```
roles/tmux/
├── tasks/
│   ├── main.yml          # Entry point with OS detection and common tasks
│   ├── MacOSX.yml        # Homebrew installation for macOS
│   ├── Ubuntu.yml        # APT installation for Ubuntu/Debian
│   ├── Fedora.yml        # DNF installation with AppImage fallback
│   └── Archlinux.yml     # Pacman installation for Arch
├── files/
│   └── tmux/
│       └── tmux.conf     # Main tmux configuration file
└── uninstall.sh          # Complete uninstallation script
```

## Key Configuration Files

### `/files/tmux/tmux.conf`
The comprehensive tmux configuration file featuring:

**Terminal Settings:**
- 256-color terminal support with RGB capability
- Optimized for modern terminals (xterm-256color)
- Mouse support enabled for modern workflow

**Session Management:**
- Windows start at index 1 (not 0) for easier keyboard access
- Automatic window renumbering when windows are closed
- 1,000,000 line history buffer for extensive scrollback
- Vi-mode key bindings for familiar navigation

**Key Bindings:**
- `Alt+Shift+H/L` for quick window switching
- `Ctrl+Arrow` keys for pane resizing
- `S` key for pane synchronization toggle
- `o` key for sesh session manager popup
- Split panes inherit current directory path

**Plugin Ecosystem:**
- `tmux-sensible` - Sensible defaults
- `tmux-yank` - System clipboard integration
- `tmux-resurrect` - Session persistence
- `tmux-continuum` - Automatic session saving
- `tmux-battery` - Battery status display
- `vim-tmux-navigator` - Seamless vim/tmux pane navigation
- `catppuccin/tmux` - Modern color theme
- `tmux-fzf-url` - URL extraction with fzf
- `sainnhe/tmux/fzf` - Enhanced fzf integration

## OS-Specific Implementations

### macOS (`MacOSX.yml`)
- Simple Homebrew installation
- Leverages brew's package management capabilities
- No special considerations needed

### Ubuntu/Debian (`Ubuntu.yml`)
- Standard APT package installation
- Requires sudo privileges for system packages
- Compatible with all Ubuntu LTS versions

### Fedora/RHEL (`Fedora.yml`)
**Advanced installation logic with multiple fallbacks:**

1. **Primary**: DNF package installation (requires sudo)
2. **Fallback**: AppImage download to `~/.local/bin/tmux`
3. **Final**: Manual installation instructions with helpful links

**Corporate Environment Support:**
- Detects `can_install_packages` variable for restricted environments
- Provides graceful degradation when sudo is unavailable
- Downloads portable AppImage from trusted source
- Clear error messages with actionable solutions

### Arch Linux (`Archlinux.yml`)
- Pacman package installation
- Straightforward system package approach
- Minimal configuration required

## Common Customizations

### Changing the Prefix Key
The default prefix key is `Ctrl+b`. To customize:

```bash
# Add to tmux.conf before plugins
set -g prefix C-a
unbind C-b
bind C-a send-prefix
```

### Modifying Theme Colors
The configuration uses Catppuccin Mocha theme. To change:

```bash
# Available flavors: latte, frappe, macchiato, mocha
set -g @catppuccin_flavor "macchiato"
```

### Adding Custom Key Bindings
Add new bindings before the TPM initialization:

```bash
# Example: Bind 'r' to reload config
bind r source-file ~/.config/tmux/tmux.conf \; display-message "Config reloaded!"
```

### Plugin Management
To add new plugins:

1. Add to the plugin list: `set -g @plugin 'author/plugin-name'`
2. Run tmux plugin install: `prefix + I` (Ctrl+b then Shift+i)
3. To remove: Delete line and run `prefix + alt + u`

## Dependencies and Integration Points

### Critical Dependencies
- **TPM (Tmux Plugin Manager)**: Automatically cloned to `~/.tmux/plugins/tpm`
- **FZF**: Required for session manager and URL extraction features
- **Git**: Needed for TPM plugin management

### Integration with Other Roles

#### Neovim Integration (`vim-tmux-navigator`)
- Seamless pane navigation between tmux and neovim
- Shared key bindings: `Ctrl+h/j/k/l` for pane movement
- Configuration exists in both tmux and neovim roles
- **Important**: Both roles must be installed for full functionality

#### Sesh Session Manager
- Advanced session management with fzf integration
- Bound to `prefix + o` for quick session switching
- Requires sesh role to be installed and configured
- Provides session preview and management capabilities

#### ZSH Integration
- Custom `TMUX_TMPDIR` set to `$HOME/tmp/tmux` in zsh vars
- **Corporate Compatibility**: Avoids `/tmp` restrictions in corporate environments
- Automatically creates user-writable tmux temporary directory

#### Terminal Integration
- Optimized for modern terminals (kitty, alacritty, wezterm)
- RGB color support requires compatible terminal
- Terminal settings cascade from other terminal roles

## Corporate Environment Considerations

### TMUX_TMPDIR Configuration
Corporate environments often restrict `/tmp` access. The system handles this by:

1. **ZSH vars.zsh** sets `TMUX_TMPDIR="$HOME/tmp/tmux"`
2. Creates user-writable temporary directory
3. Avoids permission issues in restricted environments
4. Referenced in recent commit: "configure tmux tmpdir to avoid corporate /tmp restrictions"

### Restricted Installation Scenarios
The Fedora role demonstrates best practices for corporate environments:

- Detects sudo availability via `can_install_packages` variable
- Provides AppImage fallback for userland installation
- Clear messaging for manual installation when automated methods fail
- Graceful degradation without breaking the entire dotfiles installation

## Troubleshooting Tips

### Plugin Installation Issues
```bash
# Manual plugin installation
cd ~/.tmux/plugins/tpm
./scripts/install_plugins.sh

# Clean plugin cache
rm -rf ~/.tmux/plugins/*
# Restart tmux and reinstall: prefix + I
```

### Terminal Color Issues
```bash
# Test color support
tmux info | grep -E "RGB|Tc"

# Force color in terminal
export TERM=xterm-256color
```

### Session Restoration Problems
```bash
# Check continuum status
tmux show-environment -g TMUX_CONTINUUM_STATUS

# Manual session save/restore
prefix + Ctrl+s  # Save session
prefix + Ctrl+r  # Restore session
```

### Permission Errors in Corporate Environments
```bash
# Check tmpdir configuration
echo $TMUX_TMPDIR

# Create tmpdir if missing
mkdir -p ~/tmp/tmux
```

### Navigation Issues with Neovim
Ensure both roles are installed:
```bash
dotfiles -t tmux,neovim
```

## Development Guidelines

### Adding New OS Support
1. Create `tasks/<Distribution>.yml` following existing patterns
2. Use appropriate package manager for the distribution
3. Add detection logic in `uninstall.sh`
4. Test on target platform thoroughly

### Modifying Configuration
1. **Always test changes**: Use `tmux source-file ~/.config/tmux/tmux.conf`
2. **Plugin changes**: Require `prefix + I` to install or `prefix + U` to update
3. **Key binding conflicts**: Check existing bindings with `tmux list-keys`
4. **Theme changes**: Test with multiple terminal emulators

### Plugin Development Considerations
- Plugins load after configuration, so order matters
- Some plugins require specific settings before their `@plugin` declaration
- Test plugin combinations for conflicts
- Document any required external dependencies

### Adding Corporate Features
- Use environment detection patterns from existing roles
- Provide multiple installation methods (system, user, manual)
- Include clear error messages with actionable solutions
- Test in restricted environments when possible

## Special Tmux Considerations

### Session Management Philosophy
- **Persistent sessions**: Use tmux-resurrect + continuum for automatic persistence
- **Quick switching**: Sesh integration provides modern session management
- **Directory-based**: New panes/windows inherit current directory
- **Named sessions**: Encourage descriptive session names for organization

### Performance Optimizations
- **Escape time**: Set to 0 for immediate mode switching
- **History limit**: Large buffer (1M lines) for extensive scrollback
- **Status updates**: 1-second interval balances responsiveness and performance
- **Plugin loading**: Lazy loading where possible to reduce startup time

### Theme and Visual Design
- **Catppuccin integration**: Consistent with other dotfile theming
- **Status bar**: Custom design with session, path, battery, and network status
- **Window indicators**: Clear visual feedback for active/inactive windows
- **Popup styling**: Consistent rounded borders for fzf and other popups

### Key Binding Philosophy
- **Vi-mode**: Consistent with vim/neovim muscle memory
- **Prefix efficiency**: Common operations accessible with minimal keystrokes
- **Alt bindings**: Quick window switching without prefix key
- **Context awareness**: Bindings respect current pane/window context

This tmux role provides a production-ready, corporate-friendly terminal multiplexing solution that integrates seamlessly with the broader dotfiles ecosystem while maintaining flexibility for individual customization.