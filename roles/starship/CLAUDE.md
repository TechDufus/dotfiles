# Starship Role

Installs Starship cross-shell prompt with Catppuccin theming, git status, and language-specific segments.

## Key Files

- `~/.config/starship.toml` - Prompt configuration
- `files/starship.toml` - Source config with full Catppuccin palettes

## Patterns

- **Catppuccin Latte Default**: Light theme palette, switch via `palette = "catppuccin_mocha"` for dark
- **Custom Segments**: `[custom.giturl]` detects GitHub/GitLab/Bitbucket, `[custom.docker]` shows when Dockerfile present
- **Performance Tuning**: Several modules disabled by default (gcloud, nodejs, memory_usage, time)
- **Fedora Multi-tier Install**: Tries DNF, falls back to installer script, then user directory

## Integration

- **Requires**: Nerd Font for icons to display correctly
- **Used with**: zsh role (alternative to Powerlevel10k - user choice)
- **Used with**: zsh-vi-mode for vimcmd_symbol display

## Key Configuration Sections

```toml
[character]
success_symbol = "[[󰄛](green) ❯](peach)"
error_symbol = "[[󰄛](red) ❯](peach)"

[git_status]
format = '[\($all_status$ahead_behind\)]($style) '
untracked = " "
modified = " "
staged = '[++\($count\)](green)'

[kubernetes]
format = '[$symbol$context([\(](peach)$namespace[\)](peach))]($style) '
disabled = false
```

## Gotchas

- **Icons Not Showing**: Install a Nerd Font and configure terminal to use it
- **Slow Prompt**: Run `starship timings` to identify slow modules, disable as needed
- **Git Remote Detection**: Custom giturl segment requires git remote to be configured
- **Ubuntu Installer**: Uses `creates: /usr/local/bin/starship` for idempotency
- **Theme Switching**: Change `palette = "catppuccin_latte"` to mocha/macchiato/frappe
