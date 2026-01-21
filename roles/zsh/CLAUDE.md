# ZSH Role

Installs ZSH shell with Zinit plugin manager, Powerlevel10k prompt, and 30+ modular configuration files for development tools.

## Key Files

- `~/.zshrc` - Main entry point
- `~/.p10k.zsh` - Powerlevel10k prompt config
- `~/.config/zsh/*.zsh` - Modular tool configs
- `files/.zshrc` - Source zshrc
- `files/zsh/` - All module files
- `files/os/<distro>/os_functions.zsh` - OS-specific functions

## Module Categories

- **Core**: `vars.zsh` (Catppuccin colors), `paths_vars.zsh`, `dotfiles_completions.zsh`
- **Git**: `git_functions.zsh` (gss, gco, glog, worktrees)
- **Containers**: `docker_aliases.zsh`, `podman_aliases.zsh`, `k8s_functions.zsh`
- **Tools**: `neovim_functions.zsh`, `terraform_functions.zsh`, `claude_functions.zsh`
- **Integration**: `fzf_config.zsh`, `nvm_config.zsh`, `vars.secret_functions.zsh`

## Patterns

- **Plugin Loading Order**: P10k instant prompt first, then zinit plugins, then `zinit cdreplay -q` for completions
- **Module Auto-loading**: All `~/.config/zsh/*.zsh` files sourced automatically
- **Lazy NVM**: Node version manager can be lazy-loaded for faster startup
- **OS Functions**: Each distro has own `os_functions.zsh` with update aliases and SSH agent paths

## Integration

- **Requires**: fzf for interactive functions (gco, glog, gstash)
- **Requires**: bat, lsd for fzf previews
- **Requires**: 1password for `vars.secret_functions.zsh` (runtime secrets)
- **Used by**: Most roles depend on zsh being configured for shell integration

## Gotchas

- **tmux Completion Timing**: Completions can fail in tmux due to async compinit. Solution: `dotfiles_completions.zsh` uses precmd hook to defer registration until shell is ready
- **Zinit First Run**: Requires internet to clone plugins on first shell launch
- **P10k Configure**: Run `p10k configure` for wizard-based prompt customization
- **macOS SSH Agent**: Uses 1Password agent socket at `~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock`
- **Completion Cache**: Clear with `rm ~/.zcompdump* && exec zsh` if completions break
