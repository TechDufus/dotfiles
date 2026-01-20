# Lazygit Role

Installs lazygit, a terminal UI for git commands, with minimal configuration approach.

## Key Files
- `~/.config/lazygit/config.yml` - User config (not managed by role)
- `~/.config/lazygit/state.yml` - Auto-generated state tracking
- `handlers/main.yml` - Cleanup handlers for temp files

## Patterns
- **Minimal config approach**: No opinionated settings; works with defaults
- **GitHub release install**: Ubuntu/Fedora use GitHub API for latest version
- **Version comparison**: Prevents unnecessary reinstalls on subsequent runs
- **User-local fallback**: Installs to `~/.local/bin/` when sudo unavailable

## Integration
- **Neovim**: Two integration methods:
  - `kdheepak/lazygit.nvim` plugin
  - ToggleTerm with `_LAZYGIT_TOGGLE()` function
- **Keybinding**: `<leader>gg` opens lazygit in Neovim
- **Git role**: Inherits git config, SSH keys, GPG signing

## Installation Paths
- **With sudo**: `/usr/local/bin/lazygit`
- **Without sudo**: `~/.local/bin/lazygit`
- **macOS**: Homebrew manages location

## Gotchas
- **No config deployment**: Role installs binary only; user customizes post-install
- **Temp file cleanup**: Handlers remove `/tmp/lazygit*` after installation
- **Architecture detection**: Fedora uses `github_release` role with arch pattern matching
- **No checksum validation**: Downloads not verified (potential improvement)
- **State tracking**: `state.yml` auto-tracks recent repos and UI preferences
