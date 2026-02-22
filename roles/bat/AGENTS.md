# Bat Role

Installs bat, a `cat` replacement with syntax highlighting and Git integration.

## Key Files
- `~/.config/bat/config` - Main configuration
- `~/.config/bat/themes/Catppuccino Mocha.tmTheme` - Theme file (auto-downloaded)
- `files/config` - Source config in repo

## Patterns
- **Theme auto-download**: Catppuccin theme fetched from GitHub during setup
- **Ubuntu .deb install**: Downloads latest release as .deb package from GitHub API
- **Version comparison**: Skips reinstall if current version matches latest

## Key Config Settings
```bash
--theme="Catppuccino Mocha"
--style="numbers,changes,header"
```

## Integration
- **fzf**: Can be used as preview command in fzf
- **Git pager**: Configure with `git config --global core.pager "bat --paging=always"`
- **Man pages**: Use as MANPAGER with `col -bx | bat -l man -p`

## Gotchas
- **Theme name has typo**: Config uses `Catppuccino Mocha` (note the "o")
- **Cache rebuild needed**: After adding themes run `bat cache --build`
- **aarch64 excluded on Ubuntu**: Installation skipped on ARM Ubuntu systems
- **No Arch support**: `Archlinux.yml` not implemented
