# ZSH Role - CLAUDE.md

This file provides guidance to Claude Code when working with the ZSH shell configuration role in this dotfiles repository.

## Role Overview

The ZSH role provides a **comprehensive, modular shell configuration** that transforms the default shell experience into a powerful, interactive development environment. It features intelligent OS detection, cross-platform compatibility, plugin management via Zinit, and over 30 specialized function modules covering everything from Git workflows to Kubernetes management.

**Key Features:**
- **Modular Architecture**: 30+ specialized `.zsh` modules for different tools and workflows
- **Cross-Platform**: Supports macOS, Ubuntu, Fedora, and Arch Linux
- **Plugin System**: Zinit-based plugin management with Oh My Zsh integration
- **Visual Theme**: Powerlevel10k prompt with custom Catppuccin Mocha colors
- **Smart Completions**: Advanced tab completion with timing fixes for tmux
- **Performance Optimized**: Lazy loading, caching, and startup optimizations

## Architecture and File Structure

### Core Configuration Files

```
roles/zsh/
├── files/
│   ├── .zshrc                    # Main configuration entry point
│   ├── .p10k.zsh                # Powerlevel10k prompt configuration
│   └── zsh/                     # Modular configuration directory
│       ├── vars.zsh             # Color schemes and global variables
│       ├── vars.secret_functions.zsh # Secret-related functions (1Password)
│       ├── fzf_config.zsh       # FZF integration and theming
│       ├── nvm_config.zsh       # Node Version Manager setup
│       ├── dotfiles_completions.zsh # Custom tab completions
│       └── <tool>_*.zsh         # Tool-specific modules
└── os/                          # OS-specific configurations
    ├── MacOSX/os_functions.zsh  # macOS-specific functions
    ├── Ubuntu/os_functions.zsh  # Ubuntu-specific functions
    └── Fedora/os_functions.zsh  # Fedora-specific functions
```

### Module Categories

**Core Infrastructure:**
- `vars.zsh` - Catppuccin Mocha color scheme, environment variables
- `vars.secret_functions.zsh` - 1Password integration functions
- `paths_vars.zsh` - PATH management and directory variables
- `paths_functions.zsh` - Directory navigation enhancements

**Tool Integration:**
- `git_functions.zsh` - Enhanced Git workflows (gss, gco, glog, worktrees)
- `docker_aliases.zsh` / `podman_aliases.zsh` - Container management
- `k8s_functions.zsh` / `k8s_aliases.zsh` - Kubernetes tooling
- `terraform_functions.zsh` / `terraform_aliases.zsh` - Infrastructure as Code
- `neovim_functions.zsh` / `neovim_aliases.zsh` - Editor integration

**Development Tools:**
- `claude_functions.zsh` - Claude AI CLI integration
- `gpt_functions.zsh` - ChatGPT CLI functions
- `pkg_functions.zsh` - Package manager abstractions
- `speedtest_functions.zsh` - Network testing utilities

**Special Purpose:**
- `fzf_config.zsh` - Fuzzy finder configuration and theming
- `dotfiles_completions.zsh` - Custom tab completion with tmux timing fixes
- `jj_completions.zsh` - Jujutsu version control completions

## Plugin Management System

### Zinit Configuration

The role uses **Zinit** as the plugin manager for maximum performance and flexibility:

```zsh
# Core setup in .zshrc
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

# Auto-install if missing
if [ ! -d "$ZINIT_HOME" ]; then
  mkdir -p "$(dirname $ZINIT_HOME)"
  git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

# Load zinit
source "${ZINIT_HOME}/zinit.zsh"
```

### Plugin Loading Order

**Critical plugins loaded first:**
1. **Powerlevel10k** - Prompt theme (with instant prompt support)
2. **zsh-syntax-highlighting** - Command syntax highlighting
3. **zsh-completions** - Additional completions
4. **zsh-autosuggestions** - Command history suggestions
5. **fzf-tab** - Enhanced tab completion with fuzzy search

**Oh My Zsh snippets:**
- `OMZL::async_prompt.zsh` - Async prompt infrastructure
- `OMZL::git.zsh` - Git helper functions
- `OMZP::git` - Git plugin
- `OMZP::sudo` - Sudo functionality
- Various tool-specific plugins (kubectl, aws, etc.)

### Completion System Architecture

The completion system has **complex timing requirements**, especially in tmux:

```zsh
# Load completions in correct order
autoload -U +X bashcompinit && bashcompinit  # Bash compatibility
autoload -Uz compinit && compinit            # ZSH native completions
zinit cdreplay -q                            # Replay zinit captured completions
```

## The tmux Completion Timing Problem

### Problem Description

ZSH completions can fail in tmux due to initialization timing:

**Regular Terminal Flow:**
```
Terminal → .zshrc → compinit → custom completions → ✅ works
```

**Tmux Pane Flow (problematic):**
```
tmux → new PTY → .zshrc → compinit (async?) → custom completions → ❌ _comps undefined
```

### The Solution

The `dotfiles_completions.zsh` module implements a **deferred registration system**:

```zsh
# In tmux: use precmd hook to defer until shell is ready
if [[ -n "$TMUX" ]]; then
    local _register_dotfiles_completion() {
        compdef __dotfiles_completion dotfiles
        # Remove hook after running once
        add-zsh-hook -d precmd _register_dotfiles_completion
    }
    add-zsh-hook precmd _register_dotfiles_completion
else
    # Regular terminal: register immediately
    compdef __dotfiles_completion dotfiles
fi
```

**Why This Works:**
- `precmd` runs before each prompt display
- Guarantees shell initialization is complete
- Self-removing hook prevents repeat registration
- Falls back to immediate registration outside tmux

## Color System and Theming

### Catppuccin Mocha Integration

The entire shell uses **Catppuccin Mocha** color scheme for consistency:

```zsh
# Primary colors from vars.zsh
export CAT_RED='\033[38;2;243;139;168m'     # #f38ba8
export CAT_GREEN='\033[38;2;166;227;161m'   # #a6e3a1
export CAT_BLUE='\033[38;2;137;180;250m'    # #89b4fa
export CAT_YELLOW='\033[38;2;249;226;175m'  # #f9e2af
export CAT_MAUVE='\033[38;2;203;166;247m'   # #cba6f7
# ... (complete palette defined)
```

### FZF Theme Integration

FZF uses matching Catppuccin colors:

```zsh
# From fzf_config.zsh
export FZF_DEFAULT_OPTS=" \
--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
--color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
--color=marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8 \
--color=selected-bg:#45475a \
--multi"
```

### Visual Elements

**Box Drawing Characters:**
```zsh
export BOX_TOP="╔══════════════════════════════════════════════════════════╗"
export BOX_MID="║"
export BOX_BOT="╚══════════════════════════════════════════════════════════╝"
export DIVIDER="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
```

## Advanced Git Integration

### Enhanced Git Functions

The `git_functions.zsh` module provides interactive Git workflows:

**`gss()` - Enhanced Status:**
- Current branch and upstream tracking
- Ahead/behind commit counts
- Working tree statistics (staged/modified/untracked)
- Last commit information
- Stash count
- Worktree listings
- GitHub PR status (if `gh` CLI available)

**`gco()` - Interactive Checkout:**
- Fuzzy search through local and remote branches
- Live preview showing recent commits
- Automatic tracking branch creation for remotes
- Branch activity and author information

**`glog()` - Interactive Log Browser:**
- Full commit history with graph visualization
- Live diff preview in side panel
- Search and navigation through commits

**Worktree Management:**
- `gwl` - List all worktrees with details
- `gwn <branch>` - Create new worktree in organized structure
- `gwd` - Interactive worktree deletion
- `gws` - Switch between worktrees

### Git Workflow Shortcuts

```zsh
# Quick commit and push with signing
gacp() {
  git add -A
  git commit -S -m "$*"        # Try signed commit first
  if [ $? -ne 0 ]; then
    git commit -m "$*"         # Fallback to unsigned
  fi
  git push -u origin $(git branch | sed -n -e 's/^\* \(.*\)/\1/p')
}

# Full GitHub workflow automation
gacpgh() {
  gacp "$*"
  gh pr create --fill
  gh pr review --approve
  gh pr merge -dm
}
```

## Claude AI Integration

### Claude Functions Module

The `claude_functions.zsh` provides dotfiles integration:

**Settings Management:**
- `c.settings-status` - Check if Claude settings changed
- `c.settings-save` - Commit settings changes to dotfiles

**Session Management:**
- `c.continue` / `c.c` - Continue session with workspace context
- `c.resume` - Pick previous session to resume
- `c.usage` - Live usage monitoring
- `c.usage-report` - Generate usage statistics

**Smart Context Detection:**
```zsh
c.continue() {
  local git_root=$(git rev-parse --show-toplevel 2>/dev/null)
  if [[ -n "$git_root" ]]; then
    pushd "$git_root" > /dev/null 2>&1
    claude --continue
    popd > /dev/null 2>&1
  else
    claude --continue
  fi
}
```

## OS-Specific Configurations

### Platform Detection and Loading

The role automatically loads OS-specific configurations:

```yaml
# From tasks/main.yml
- name: "ZSH | {{ ansible_distribution }} | Identify distribution config"
  ansible.builtin.stat:
    path: "{{ role_path }}/files/os/{{ ansible_distribution }}"
  register: zsh_os_distribution_config

- name: "ZSH | Calculate os config src"
  ansible.builtin.set_fact:
    zsh_os_config: "{{ zsh_os_distribution_config if zsh_os_distribution_config.stat.exists else zsh_os_family_config }}"
```

### OS-Specific Functions

**macOS (`os/MacOSX/os_functions.zsh`):**
```zsh
alias update='brew update && brew upgrade && brew cleanup'
export SSH_AUTH_SOCK=~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock
```

**Ubuntu (`os/Ubuntu/os_functions.zsh`):**
```zsh
alias update='sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y'
# Intelligent nala integration
if [ -x "$(command -v nala)" ]; then
  source <(nala --show-completion)
  alias update='sudo nala upgrade -y && sudo nala autoremove -y && sudo nala clean'
fi
```

## Performance Considerations

### Startup Optimization

**Zinit Optimizations:**
- Uses `zinit cdreplay -q` for fast completion loading
- Ice modifiers for conditional loading: `zinit ice depth=1`
- Snippet loading for specific Oh My Zsh components only

**Lazy Loading Pattern:**
```zsh
# Example from nvm_config.zsh (commented optimization)
lazy_load_nvm() {
  unset -f nvm node npm npx
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
}

nvm() {
  lazy_load_nvm
  nvm "$@"
}
```

**Directory Auto-loading:**
```zsh
# Load all custom modules efficiently
for file in $HOME/.config/zsh/*.zsh; do
  source "$file"
done
```

### Memory Management

**History Configuration:**
```zsh
HISTSIZE=10000                    # Memory limit
HISTFILE=~/.zsh_history          # Persistent storage
SAVEHIST=$HISTSIZE               # Disk limit
HISTDUP=erase                    # Remove duplicates
setopt sharehistory              # Share between sessions
setopt hist_ignore_all_dups      # Ignore duplicate commands
```

**Completion Caching:**
- ZSH's built-in completion caching is enabled
- Zinit manages plugin-specific caches
- Custom completions use efficient parsing

## Integration with Other Tools

### FZF Integration

**Preview Functions:**
```zsh
show_file_or_dir_preview="if [ -d {} ]; then lsd --oneline --tree --color=always --icon=always {} | head -200; else bat -n --color=always --line-range :500 {}; fi"

_fzf_comprun() {
  local command=$1
  shift
  case "$command" in
    export|unset) fzf --preview "eval 'echo ${}'"     "$@" ;;
    ssh)          fzf --preview 'dig {}'               "$@" ;;
    *)            fzf --preview "$show_file_or_dir_preview" "$@" ;;
  esac
}
```

### Starship Prompt (Alternative)

While Powerlevel10k is the default, the configuration supports Starship:
- Configuration managed through separate starship role
- Can coexist with P10k (user choice)
- Cross-shell compatibility for consistent experience

### NVM Auto-Switching

```zsh
# Automatic Node version switching
load-nvmrc() {
  local nvmrc_path="$(nvm_find_nvmrc)"
  if [ -n "$nvmrc_path" ]; then
    local nvmrc_node_version=$(nvm version "$(cat "${nvmrc_path}")")
    if [ "$nvmrc_node_version" = "N/A" ]; then
      nvm install
    elif [ "$nvmrc_node_version" != "$(nvm version)" ]; then
      nvm use
    fi
  # ... (automatic fallback logic)
}

add-zsh-hook chpwd load-nvmrc  # Run on directory change
```

## Installation Intelligence

### Multi-Method Installation

The role handles various installation scenarios:

**System Installation (with sudo):**
```yaml
- name: "Zsh | Install Zsh (system package)"
  ansible.builtin.package:
    name: zsh
    state: present
  become: true
```

**User-Local Installation (no sudo):**
- Provides manual build instructions
- Sets up local directories (`~/.local/bin`, `~/.local/src`)
- Updates PATH configuration
- Graceful fallback to current shell

**Shell Change Logic:**
```yaml
- name: "Zsh | Set as default shell (requires sudo)"
  ansible.builtin.user:
    name: "{{ host_user }}"
    shell: /usr/bin/zsh
  become: true
  when:
    - zsh_check.rc == 0 or zsh_system_install is succeeded
    - '"/zsh" not in current_shell.stdout'
```

## Common Customization Points

### Adding New Tool Modules

1. **Create module file**: `roles/zsh/files/zsh/<tool>_functions.zsh`
2. **Follow naming convention**: Functions prefixed with tool name
3. **Use color variables**: From `vars.zsh` for consistency
4. **Add help function**: `<tool>.help()` following existing patterns

**Template Structure:**
```zsh
#!/usr/bin/env zsh
# <Tool> integration functions

# Main function with comprehensive features
<tool>-enhanced() {
  # Check prerequisites
  if ! command -v <tool> >/dev/null 2>&1; then
    echo "Error: <tool> not found"
    return 1
  fi
  
  # Use fzf integration if applicable
  <tool> list | fzf \
    --preview='<tool> show {}' \
    --bind='enter:execute(<tool> use {})'
}

# Help function
<tool>.help() {
  echo -e "${CAT_SAPPHIRE}${BOX_TOP}${NC}"
  echo -e "${CAT_SAPPHIRE}${BOX_MID}${NC}  🔧 ${CAT_TEXT}<Tool> Functions${NC}"
  echo -e "${CAT_SAPPHIRE}${BOX_BOT}${NC}"
  # ... (documentation)
}
```

### Modifying Completions

**For existing tools:**
1. Edit relevant `*_completions.zsh` file
2. Test in fresh shell: `exec zsh`
3. Verify in tmux environment

**For new completions:**
1. Create `<tool>_completions.zsh`
2. Use conditional loading: `if command -v <tool> >/dev/null 2>&1; then`
3. Consider tmux timing if complex

### Color Scheme Customization

**Modify base colors** in `vars.zsh`:
```zsh
export CAT_<NAME>='\033[38;2;R;G;Bm'  # RGB color
```

**Update FZF colors** in `fzf_config.zsh`:
```zsh
export FZF_DEFAULT_OPTS=" \
--color=bg+:#<hex>,bg:#<hex>,spinner:#<hex> \
..."
```

**Powerlevel10k customization:**
- Run `p10k configure` for wizard
- Edit `.p10k.zsh` for manual changes
- Colors automatically inherit from terminal theme

## Troubleshooting Guide

### Completion Issues

**Symptoms:**
- Tab completion not working
- `command not found: _comps`
- Completions work in regular terminal but not tmux

**Solutions:**
1. **Check loading order**: Ensure `compinit` runs before custom completions
2. **Tmux timing fix**: Verify precmd hook is active
3. **Force reload**: `autoload -U compinit && compinit`
4. **Clear cache**: `rm ~/.zcompdump* && exec zsh`

### Plugin Loading Failures

**Symptoms:**
- Zinit errors on startup
- Missing syntax highlighting
- Prompt not loading

**Solutions:**
1. **Reinstall zinit**: `rm -rf ~/.local/share/zinit && exec zsh`
2. **Update plugins**: `zinit update --all`
3. **Check network**: Zinit requires internet for first install
4. **Fallback mode**: Comment plugin loading to isolate issues

### Performance Problems

**Symptoms:**
- Slow shell startup
- Laggy completions
- High memory usage

**Solutions:**
1. **Profile startup**: Use `zsh -x` to trace loading
2. **Disable expensive modules**: Comment out resource-intensive functions
3. **Enable lazy loading**: Use deferred loading patterns
4. **Clear caches**: Remove completion and plugin caches

### OS-Specific Issues

**macOS:**
- **Homebrew PATH**: Ensure `/opt/homebrew/bin` in PATH
- **SSH agent**: Verify 1Password SSH integration
- **Terminal.app**: May need manual font configuration

**Ubuntu/Debian:**
- **Sudo requirements**: Some features need sudo for system packages
- **Nala integration**: Automatic detection might fail on older systems
- **Build tools**: Manual installation requires gcc/make

**Fedora:**
- **DNF permissions**: Package installation needs sudo
- **SELinux**: May interfere with custom scripts

### Module Conflicts

**Symptoms:**
- Function name conflicts
- Alias overwrites
- Environment variable issues

**Solutions:**
1. **Check loading order**: Modules loaded alphabetically
2. **Use unique prefixes**: Tool-specific function naming
3. **Explicit unaliasing**: Use `unalias <name>` in module files
4. **Environment isolation**: Check for variable overwrites

## Development Guidelines

### Code Standards

**Function Naming:**
- Use tool prefix: `git-function`, `k8s-command`
- Help functions: `<tool>.help()`
- Interactive commands: `<tool>-interactive` or `g<shortcut>`

**Error Handling:**
```zsh
# Check prerequisites
if ! command -v tool >/dev/null 2>&1; then
  echo "Error: tool not found"
  return 1
fi

# Git repository checks
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "Error: Not in a git repository"
  return 1
fi
```

**User Interface:**
- Use Catppuccin colors consistently
- Provide clear error messages
- Include help text in functions
- Use fzf for interactive selections

**Performance:**
- Lazy load expensive operations
- Cache results when possible
- Use efficient shell constructs
- Minimize external command calls

### Testing Guidelines

**Local Testing:**
1. Test in fresh shell: `exec zsh`
2. Test in tmux pane: `tmux new-session`
3. Test with/without sudo
4. Test on target OS platforms

**Integration Testing:**
1. Run full dotfiles installation
2. Verify no conflicts with existing tools
3. Test completion systems
4. Check color rendering in various terminals

**Performance Testing:**
1. Measure startup time: `time zsh -i -c exit`
2. Profile memory usage
3. Test with large repositories
4. Verify responsive completion

This comprehensive ZSH configuration represents a sophisticated, modular approach to shell customization that balances power, performance, and maintainability across multiple platforms and use cases.