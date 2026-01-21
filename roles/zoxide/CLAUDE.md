# Zoxide Role

Installs zoxide, a smarter `cd` command that learns directory navigation patterns via frecency.

## Key Files
- `~/.local/share/zoxide/db.zo` - Binary database of directories
- Shell init in `roles/zsh/files/.zshrc` and `roles/bash/files/.bashrc`

## Patterns
- **Frecency scoring**: Combines frequency and recency for directory ranking
- **No config files**: All customization via environment variables
- **zinit conflict resolution**: ZSH config runs `unalias zi` before zoxide init

## Shell Integration
```bash
# ZSH (after unalias zi for zinit conflict)
eval "$(zoxide init zsh)"

# Bash (via oh-my-bash plugin)
plugins=(zoxide)
```

## Integration
- **Sesh/tmux**: `Ctrl-x` in sesh popup shows zoxide directories
- **Neovim**: `telescope-zoxide` plugin for directory navigation
- **fzf-tab**: Enhanced completion for `__zoxide_z` command

## Commands
- `z <pattern>` - Jump to matching directory
- `zi` - Interactive selection with fzf
- `z -` - Previous directory

## Gotchas
- **Database needs seeding**: Visit directories first to populate database
- **zi alias conflict**: zinit also uses `zi`; zsh config handles this
- **Ubuntu 21.04+ only**: Native apt package not available on older versions
- **No Fedora support**: Task file not implemented
