# Tmux Role

Configures tmux terminal multiplexer with TPM plugins, vi-mode, and corporate environment support.

## Key Files
- `~/.config/tmux/tmux.conf` - Main configuration
- `~/.tmux/plugins/tpm/` - Tmux Plugin Manager (auto-cloned)
- `files/tmux/tmux.conf` - Source config in repo

## Patterns
- **TPM plugin management**: Plugins installed via `prefix + I`
- **Corporate TMPDIR**: ZSH sets `TMUX_TMPDIR="$HOME/tmp/tmux"` to avoid `/tmp` restrictions
- **Fedora AppImage fallback**: Downloads portable tmux when sudo unavailable

## Key Plugins
- `tmux-sensible` - Sensible defaults
- `tmux-resurrect` + `tmux-continuum` - Session persistence
- `vim-tmux-navigator` - Seamless vim/tmux pane navigation
- `catppuccin/tmux` - Theme
- `tmux-fzf-url` - URL extraction

## Key Bindings
- `prefix + o` - Sesh session manager popup
- `Alt+Shift+H/L` - Quick window switching
- `S` - Toggle pane synchronization
- `Ctrl+h/j/k/l` - Pane navigation (shared with Neovim)

## Integration
- **Neovim**: `vim-tmux-navigator` requires matching Neovim plugin
- **Sesh**: Session manager popup via `prefix + o`
- **ZSH**: `TMUX_TMPDIR` set in `roles/zsh/files/zsh/vars.zsh`

## Gotchas
- **Windows start at 1**: Not 0, for easier keyboard access
- **1M line history**: Large scrollback buffer configured
- **Corporate /tmp issues**: Must use `TMUX_TMPDIR` in restricted environments
- **Plugin install required**: After first run, press `prefix + I` to install plugins
- **Both roles needed**: vim-tmux-navigator needs config in both tmux and neovim roles
