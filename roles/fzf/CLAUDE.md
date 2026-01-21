# FZF Role

Installs fzf fuzzy finder with Catppuccin theming and shell integration for interactive filtering and selection.

## Key Files

- `~/.fzf/` - Source installation (Linux)
- `roles/zsh/files/zsh/fzf_config.zsh` - ZSH integration and theming
- `roles/zsh/files/zsh/git_functions.zsh` - FZF-powered git functions

## Patterns

- **Linux Source Install**: Removes apt/dnf package and installs from git for latest features
- **Handler-based Install**: Git clone triggers `~/.fzf/install --all --no-update-rc --no-fish`
- **Smart Preview**: Directories use `lsd --tree`, files use `bat` with syntax highlighting
- **Performance Limits**: Previews truncated (200 lines dirs, 500 lines files) to prevent lag

## Integration

- **Requires**: bat for syntax-highlighted file previews
- **Requires**: lsd for directory tree previews with icons
- **Used by**: zsh role for git functions (gco, glog, gstash, gws)
- **Used by**: tmux role for session switching (sesh + fzf)

## FZF-Powered Functions

- `gco` - Interactive branch checkout with commit preview
- `glog` - Commit history browser with diff preview
- `gstash` - Stash management (Enter=apply, Ctrl-P=pop, Ctrl-D=drop)
- `gws` - Worktree switching
- `kctx` - Kubernetes context switching

## Default Keybindings

- `Ctrl-T` - File/directory finder with preview
- `Ctrl-R` - Command history search
- `Alt-C` - Directory navigation

## Gotchas

- **macOS vs Linux Install**: Homebrew on macOS, git source on Linux (different paths)
- **Preview Dependencies**: Without bat/lsd, previews fall back to basic output
- **Catppuccin Theme**: Colors defined in `FZF_DEFAULT_OPTS` in fzf_config.zsh
- **Large Repos**: May need `.fzfignore` to exclude node_modules, vendor, .git
- **tmux Popups**: Require tmux 3.2+ for fzf popup windows
