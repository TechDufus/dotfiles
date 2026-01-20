# Sesh Role

Configures sesh, a smart tmux session manager with zoxide and fzf integration.

## Key Files
- `~/.config/sesh/sesh.toml` - Session configuration
- `files/sesh.toml` - Source config in repo
- Tmux keybinding in `roles/tmux/files/tmux/tmux.conf`

## Patterns
- **Go package install**: Installed via `go` role from `group_vars/all.yml`
- **Default startup command**: Creates split layout with Claude in right pane
- **Predefined sessions**: `[[sessions]]` blocks for quick-access directories

## Configuration Structure
```toml
[[sessions]]
name = "dotfiles"
path = "~/.dotfiles"

[default_session]
startup_command = "tmux split-window -h -p 50 && ..."
```

## Integration
- **tmux**: `prefix + o` opens sesh popup (80% width, 70% height)
- **zoxide**: `Ctrl-x` in sesh switches to zoxide directory list
- **fzf**: Interactive selection with live session previews
- **fd**: `Ctrl-f` enables file finder mode

## Tmux Popup Controls
- `Ctrl-a` - All sessions
- `Ctrl-t` - Tmux sessions only
- `Ctrl-g` - Config/Git directories
- `Ctrl-x` - Zoxide directories
- `Ctrl-d` - Kill selected session

## Gotchas
- **Requires Go role**: Installed as Go package, not system package
- **Tmux config owns keybinding**: Sesh popup defined in tmux role, not here
- **Zoxide dependency**: `Ctrl-x` requires zoxide installed and populated
- **fd dependency**: File finder mode requires fd installed
