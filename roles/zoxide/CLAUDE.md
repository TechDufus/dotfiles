# Zoxide Role - CLAUDE.md

## Role Overview

The **zoxide** role installs and configures zoxide, a smarter `cd` command that learns your directory navigation patterns. Zoxide is a modern replacement for `cd` that uses a database of your most frequently and recently visited directories to enable intelligent directory jumping with minimal typing.

This role provides a clean, minimal installation that integrates seamlessly with shell completions, fzf, sesh session manager, and Neovim telescope for a comprehensive navigation workflow.

## Key Features

- **Smart Directory Navigation**: Jump to frequently used directories with partial names
- **Cross-Platform Support**: Works on macOS (Homebrew), Ubuntu 21.04+, and Arch Linux
- **Shell Integration**: Automatic initialization in both zsh and bash
- **Fuzzy Finding**: Integrated with fzf for enhanced directory selection
- **Session Management**: Works with sesh for tmux session navigation
- **Editor Integration**: Available in Neovim through telescope-zoxide plugin

## Installation and Setup

### Platform Support
- **macOS**: Installed via Homebrew (`brew install zoxide`)
- **Ubuntu**: Native package support for Ubuntu 21.04+ (`apt install zoxide`)
- **Arch Linux**: Installed via pacman (`pacman -S zoxide`)

### Prerequisites
- Modern shell (zsh or bash)
- Optional: fzf for enhanced fuzzy finding capabilities
- Optional: tmux + sesh for session management integration

## Core Functionality

### Basic Commands
```bash
z <pattern>     # Jump to directory matching pattern
zi <pattern>    # Interactive selection with fzf
z -             # Jump to previous directory
zoxide add <dir> # Manually add directory to database
zoxide query <pattern> # Query database without jumping
zoxide remove <pattern> # Remove directory from database
```

### Database Management
- **Location**: `~/.local/share/zoxide/db.zo` (or `$XDG_DATA_HOME/zoxide/db.zo`)
- **Format**: Binary database storing directory paths with frequency/recency scores
- **Backup**: Consider backing up database for consistent experience across machines

## Shell Integration

### Zsh Configuration
Located in `/home/techdufus/.dotfiles/roles/zsh/files/.zshrc`:
```bash
# Unalias zinit's zi to avoid conflicts with zoxide
unalias zi
eval "$(zoxide init zsh)"
```

Key integrations:
- **fzf-tab completion**: Enhanced tab completion for `__zoxide_z` command
- **Preview support**: Directory contents shown during selection
- **Conflict resolution**: Properly handles zinit's `zi` alias conflict

### Bash Configuration
Located in `/home/techdufus/.dotfiles/roles/bash/files/.bashrc`:
```bash
# Zoxide included in oh-my-bash plugins array
plugins=(
  kubectl
  progress
  xterm
  zoxide
)
```

## Advanced Integrations

### Tmux + Sesh Integration
Zoxide integrates with the sesh session manager through tmux keybindings:
- **Keybinding**: `prefix + o` opens sesh popup
- **Zoxide access**: `Ctrl-x` switches to zoxide mode in sesh selector
- **Workflow**: Select directories from zoxide database → create/attach tmux sessions

Configuration in `/home/techdufus/.dotfiles/roles/tmux/files/tmux/tmux.conf`:
```bash
bind-key "o" display-popup -E -w 80% -h 70% "sesh connect \"$(
  sesh list --icons  -H | fzf --reverse --no-sort --ansi --border-label ' sesh ' --prompt '⚡  ' \
    --header '  ^a all ^t tmux ^g configs ^x zoxide ^d tmux kill ^f find' \
    --bind 'ctrl-x:change-prompt(📁  )+reload(zoxide query -l)'
)\""
```

### Neovim Telescope Integration
Available through `telescope-zoxide` plugin:
- **Plugin**: `jvgrootveld/telescope-zoxide` in telescope dependencies
- **Usage**: Navigate to directories from within Neovim
- **Workflow**: Open telescope → zoxide picker → jump to directory

## Performance Considerations

### Database Optimization
- **Aging Algorithm**: Zoxide uses frecency (frequency + recency) scoring
- **Automatic Cleanup**: Old, unused entries automatically decay over time
- **Manual Management**: Use `zoxide remove` for unwanted entries

### Shell Startup Impact
- **Minimal Overhead**: `eval "$(zoxide init zsh)"` adds ~5ms to shell startup
- **Lazy Loading**: Consider lazy-loading for extremely performance-sensitive environments
- **Memory Usage**: Lightweight in-memory database cache

### Large Directory Trees
- **Indexing**: Only visited directories are indexed (not recursive scanning)
- **Query Performance**: O(log n) lookup time with binary search
- **Storage**: Efficient binary format keeps database small

## Customization Points

### Environment Variables
```bash
export _ZO_ECHO=1           # Print matched directory before jumping
export _ZO_DATA_DIR="$HOME/.local/share/zoxide"  # Custom database location
export _ZO_EXCLUDE_DIRS="$HOME/tmp:$HOME/.cache"  # Excluded directories
export _ZO_FZF_OPTS="--height 40% --reverse"      # Custom fzf options
export _ZO_MAXAGE=10000     # Maximum age for database entries
```

### Custom Aliases
```bash
alias cd='z'      # Replace cd entirely (aggressive)
alias j='zi'      # Interactive jumping shorthand
alias za='zoxide add'    # Quick directory addition
alias zr='zoxide remove' # Quick directory removal
```

### Integration Hooks
```bash
# Custom hook after directory change
_z_hook() {
  # Custom logic after zoxide navigation
}
eval "$(zoxide init zsh --hook pwd)"  # Enable pwd hooks
```

## Common Usage Patterns

### Project Navigation
```bash
z dot        # Jump to ~/.dotfiles
z nvim       # Jump to neovim config
z proj work  # Jump to work projects directory
zi           # Interactive selection of all directories
```

### Development Workflow
1. **Project Setup**: `z <project>` to jump to project directory
2. **Session Creation**: Use sesh integration for tmux sessions
3. **Editor Integration**: Access directories from Neovim telescope
4. **Quick Navigation**: `z -` to toggle between current and previous

### Database Maintenance
```bash
zoxide query -l              # List all directories in database
zoxide query -l | head -20   # Show top 20 directories
zoxide remove "/old/path"    # Remove specific directory
```

## Troubleshooting

### Common Issues

**Command not found**: Ensure shell is restarted after installation
```bash
# Reload shell configuration
source ~/.zshrc  # or source ~/.bashrc
```

**No matches found**: Build database by visiting directories first
```bash
# Visit directories to populate database
cd ~/Projects && cd ~/.dotfiles && cd ~/Documents
```

**Conflicts with existing aliases**: Check for conflicting `z` aliases
```bash
# Check existing aliases
alias | grep -E '^(z|zi)='
# Unalias if needed
unalias z zi
```

**Database corruption**: Remove and rebuild database
```bash
rm ~/.local/share/zoxide/db.zo
# Revisit directories to rebuild
```

### Performance Issues

**Slow initialization**: Profile shell startup
```bash
time zsh -c 'eval "$(zoxide init zsh)" && exit'
```

**Large database**: Clean up unused entries
```bash
# Remove directories that no longer exist
zoxide query -l | while read dir; do
  [[ ! -d "$dir" ]] && zoxide remove "$dir"
done
```

### Integration Problems

**fzf not working**: Ensure fzf is installed and configured
```bash
command -v fzf || echo "fzf not found"
```

**Sesh integration broken**: Verify sesh and tmux configuration
```bash
sesh list  # Should show available sessions
```

## Development Guidelines

### Adding Custom Integrations
1. **Hook into zoxide events**: Use `--hook` option during initialization
2. **Custom commands**: Create shell functions that use `zoxide query`
3. **External tools**: Pipe zoxide output to other navigation tools

### Testing Changes
```bash
# Test basic functionality
z /tmp && pwd && z -

# Test interactive mode
zi

# Test database queries
zoxide query -l | head -5
```

### Configuration Management
- Database is stored in XDG-compliant location
- Configuration through environment variables only
- No additional config files needed

### Best Practices
- **Gradual adoption**: Start with `zi` for interactive use
- **Database seeding**: Visit important directories early
- **Regular cleanup**: Remove obsolete paths periodically
- **Integration testing**: Verify shell, tmux, and editor integrations work together

## Cross-Tool Workflow

### Complete Navigation Stack
1. **Shell Navigation**: `z <pattern>` for quick jumps
2. **Interactive Selection**: `zi` with fzf for browsing
3. **Session Management**: `prefix + o` → `Ctrl-x` in tmux for session navigation
4. **Editor Integration**: Telescope zoxide picker in Neovim
5. **Completion Enhancement**: fzf-tab integration for better completions

This creates a cohesive navigation experience where zoxide serves as the central directory intelligence, feeding into various tools and interfaces throughout the development environment.

## Future Enhancements

### Potential Improvements
- **Cross-machine sync**: Sync database across multiple machines
- **Project-aware navigation**: Integration with git repositories
- **Workspace management**: Integration with VS Code workspaces
- **Context switching**: Different databases for different contexts (work/personal)

The zoxide role provides a solid foundation for intelligent directory navigation while maintaining simplicity and performance across the entire dotfiles ecosystem.