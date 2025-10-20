# FZF Role - CLAUDE.md

This file provides comprehensive guidance for Claude Code when working with the fzf (fuzzy finder) role in this dotfiles repository.

## Role Overview and Purpose

The **fzf role** installs and configures fzf, a command-line fuzzy finder that dramatically enhances productivity through interactive filtering, searching, and selection across the development environment. FZF serves as the foundation for numerous custom functions, shell integrations, and interactive workflows throughout the dotfiles system.

### Key Features
- **Cross-platform installation** supporting macOS, Ubuntu, and Fedora
- **Shell integration** with zsh and bash for enhanced command-line workflows
- **Custom theming** using Catppuccin Mocha color scheme
- **Extensive tool integrations** with git, tmux, kubernetes, and more
- **Performance-optimized configuration** with intelligent preview handling
- **Custom keybindings** for common development workflows

## Architecture and Installation Methods

### Installation Strategy by OS

**macOS (Homebrew)**:
```yaml
- name: "FZF | MacOSX | Install fzf"
  community.general.homebrew:
    name: fzf
    state: present
```

**Ubuntu/Fedora (Git Source)**:
The role deliberately removes package manager versions and installs from source for latest features:
```yaml
# Remove system package
- name: "FZF | Uninstall APT fzf"
  ansible.builtin.apt:
    name: fzf
    state: absent
  become: true

# Install from source
- name: "FZF | Clone Latest Version"
  ansible.builtin.git:
    repo: https://github.com/junegunn/fzf.git
    depth: 1
    dest: "{{ ansible_user_dir }}/.fzf"
  notify: "Install FZF"
```

### Handler Configuration
```yaml
- name: "Install FZF"
  ansible.builtin.shell: "{{ ansible_user_dir }}/.fzf/install --all --no-update-rc --no-fish"
```

**Installation flags explained**:
- `--all`: Install all components (binary, shell completion, key bindings)
- `--no-update-rc`: Don't modify shell rc files (handled by dotfiles)
- `--no-fish`: Skip fish shell integration (not used in this setup)

## Shell Integration Architecture

### ZSH Integration (`/home/techdufus/.dotfiles/roles/zsh/files/zsh/fzf_config.zsh`)

#### Core Configuration
```zsh
# Enhanced preview with bat and lsd
show_file_or_dir_preview="if [ -d {} ]; then lsd --oneline --tree --color=always --icon=always {} | head -200; else bat -n --color=always --line-range :500 {}; fi"

export FZF_CTRL_T_OPTS="--preview '$show_file_or_dir_preview'"

# Catppuccin Mocha theme
export FZF_DEFAULT_OPTS=" \
--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
--color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
--color=marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8 \
--color=selected-bg:#45475a \
--multi"
```

#### Intelligent Completion Function
```zsh
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

### Bash Integration
The role supports bash through similar configuration patterns in the bash role files.

## Custom FZF Configuration Deep Dive

### Environment Variables

**FZF_DEFAULT_OPTS**:
- **Theme**: Catppuccin Mocha color scheme for consistent UI
- **Multi-select**: `--multi` enables multiple item selection
- **Visual hierarchy**: Different colors for various UI elements

**FZF_CTRL_T_OPTS**:
- **Smart previews**: Directories show tree structure, files show syntax-highlighted content
- **Performance**: Limits output (200 lines for dirs, 500 for files) to prevent freezing
- **Tool integration**: Uses `lsd` for directory listings and `bat` for file previews

### Preview System Architecture

The preview system is built in layers:

1. **Detection**: Check if target is file or directory
2. **Directory handling**: Use `lsd` with tree view and icons
3. **File handling**: Use `bat` with syntax highlighting and line numbers
4. **Performance limits**: Truncate output to prevent UI lag

## Integration with Development Tools

### Git Integration (Comprehensive)

The fzf role enables extensive git workflow enhancements through custom functions:

#### Branch Operations (`gco`)
```zsh
# Interactive branch checkout with rich previews
gco() {
  git for-each-ref --format='%(refname:short)' refs/heads/ refs/remotes/ | \
    grep -v "HEAD" | \
    sort -u | \
    fzf \
      --preview='branch=$(echo {} | sed "s/^origin\///"); \
                 echo -e "\033[1;34m━━━ BRANCH: {} ━━━\033[0m\n"; \
                 echo -e "\033[1;32m📅 Last Activity:\033[0m $(git log -1 --format="%cr" {})"; \
                 echo -e "\033[1;33m👤 Last Author:\033[0m $(git log -1 --format="%an <%ae>" {})"; \
                 git log --oneline --graph --color=always -10 {} | head -20'
}
```

**Features**:
- Shows local and remote branches
- Rich preview with commit history, author info, and timestamps
- Automatic handling of remote branch tracking
- Color-coded output for better visual scanning

#### Commit Log Browser (`glog`)
```zsh
glog() {
  git log --graph --color=always --format="%C(auto)%h%d %s %C(black)%C(bold)%cr %C(auto)%an" --all "$@" | \
  fzf --ansi --no-sort --reverse --tiebreak=index \
      --preview='
        commit=$(echo {} | grep -o "[a-f0-9]\{7,\}" | head -1)
        git show --color=always --stat --patch "$commit" | head -500
      '
}
```

**Features**:
- Graph visualization of commit history
- Full diff preview with statistics
- Color preservation from git
- Performance optimization with output limits

#### Stash Management (`gstash`)
```zsh
gstash() {
  git stash list | \
    fzf --preview='git stash show -p --color=always $(echo {} | cut -d: -f1)' \
        --bind='enter:execute(git stash apply $(echo {} | cut -d: -f1))+abort' \
        --bind='ctrl-p:execute(git stash pop $(echo {} | cut -d: -f1))+abort' \
        --bind='ctrl-d:execute(git stash drop $(echo {} | cut -d: -f1))+abort'
}
```

**Keybindings**:
- `Enter`: Apply stash (keep in stash list)
- `Ctrl-P`: Pop stash (apply and remove from stash)
- `Ctrl-D`: Drop stash (delete permanently)
- `Ctrl-B`: Create branch from stash

#### Tag Management (`gtags`)
```zsh
gtags() {
  git tag --sort=-creatordate | fzf \
    --preview='git show --color=always {}' \
    --bind='enter:execute(git checkout {})'
}
```

**Features**:
- Chronological sorting (newest first)
- Full tag/commit preview
- Direct checkout capability
- Signature verification display

#### Worktree Management (`gwl`, `gwn`, `gwd`, `gws`)

**List worktrees** (`gwl`):
- Displays all worktrees with branch and commit info
- Highlights current worktree
- Shows last commit details for each

**Create worktree** (`gwn <branch>`):
- Unified worktrees directory structure
- Automatic branch detection and creation
- `.gitignore` management

**Delete worktree** (`gwd`):
- Interactive selection with preview
- Safety confirmation prompts
- Excludes current worktree from deletion

**Switch worktrees** (`gws`):
- Interactive selection with commit history preview
- Automatic directory change
- Branch status display

### Tmux Integration

FZF integrates deeply with tmux through plugins and session management:

```conf
# Tmux plugins that leverage fzf
set -g @plugin 'sainnhe/tmux/fzf'
set -g @plugin 'wfxr/tmux-fzf-url'

# URL opener configuration
set -g @fzf-url-fzf-options '-p 60%,30% --prompt="   " --border-label=" Open URL "'
set -g @fzf-url-history-limit '2000'

# Session management with sesh
bind-key "T" display-popup -E -w 40% -h 60% -x C -y C \
  'sesh list --icons -H | fzf --reverse --no-sort --ansi --border-label " sesh " --prompt "⚡  "'
```

**Features**:
- **URL extraction**: Find and open URLs from tmux buffers
- **Session management**: Interactive session switching with `sesh`
- **Popup windows**: Integrated fzf popups within tmux
- **Custom styling**: Consistent theming with dotfiles

### Kubernetes Integration

Kubernetes workflows are enhanced through fzf-powered aliases:

```bash
# Interactive context switching
alias kctx='kubectl config use-context $(kubectl config get-contexts -o name | fzf)'
```

**Workflow**:
1. List all available Kubernetes contexts
2. Fuzzy search through context names
3. Select and switch context interactively

### Background Selection (`change_background`)

Creative integration for desktop customization:

```zsh
change_background() {
    dconf write /org/mate/desktop/background/picture-filename "'$HOME/anime/$(ls ~/anime| fzf)'"
}
```

## Key Bindings and Shortcuts

### Default FZF Keybindings
- `Ctrl-T`: File/directory fuzzy finder
- `Ctrl-R`: Command history search
- `Alt-C`: Directory navigation

### Custom Function Keybindings

**Git Stash Management**:
- `Enter`: Apply stash (keep in list)
- `Ctrl-P`: Pop stash (apply and remove)
- `Ctrl-D`: Drop stash (delete)
- `Ctrl-B`: Create branch from stash

**Git Log Browser**:
- `Enter`: Show full commit diff in less
- `↑/↓`: Navigate commits
- `Esc`: Exit without action

**Branch Checkout**:
- `Enter`: Checkout selected branch
- Remote branches automatically create local tracking branches

## Performance Optimizations

### Preview Performance
```zsh
# Limit output to prevent UI freezing
show_file_or_dir_preview="if [ -d {} ]; then lsd --oneline --tree --color=always --icon=always {} | head -200; else bat -n --color=always --line-range :500 {}; fi"
```

### Git Operations
```zsh
# Limit commit preview output
git show --color=always --stat --patch "$commit" | head -500
```

### Memory Management
- Uses `depth: 1` for git clones to minimize disk usage
- Truncates large outputs to prevent memory issues
- Employs lazy loading for expensive operations

## Common Use Cases and Workflows

### Daily Development Workflow

1. **Project Navigation**:
   ```zsh
   # Navigate to files
   Ctrl-T

   # Change to directory
   Alt-C
   ```

2. **Git Operations**:
   ```zsh
   # Switch branches
   gco

   # Browse commit history
   glog

   # Manage stashes
   gstash

   # Work with multiple worktrees
   gws  # switch worktrees
   gwn feature-branch  # create new worktree
   ```

3. **Session Management**:
   ```zsh
   # In tmux
   <prefix>T  # Switch sessions with sesh + fzf
   ```

4. **Command History**:
   ```zsh
   Ctrl-R  # Search command history
   ```

### Advanced Workflows

**Multi-repository Management**:
- Use worktrees for parallel development
- Switch contexts quickly with `gws`
- Maintain separate environments per feature

**Kubernetes Development**:
- Quick context switching with `kctx`
- Combine with other k8s tools for enhanced workflows

**Tmux Productivity**:
- Session switching without leaving current context
- URL extraction from terminal output
- Popup-based interactions

## Troubleshooting Tips

### Common Issues

**FZF Not Found**:
- Ensure installation completed: `~/.fzf/bin/fzf --version`
- Check PATH includes fzf binary location
- Verify shell integration loaded: `echo $FZF_DEFAULT_OPTS`

**Preview Not Working**:
- Verify `bat` and `lsd` are installed (dependencies for enhanced previews)
- Check if preview command runs standalone: `bat --version`, `lsd --version`
- Test basic preview: `echo "test" | fzf --preview 'echo {}'`

**Slow Performance**:
- Large repositories may cause preview lag
- Increase `head` limits if truncation is too aggressive
- Consider excluding large directories with `.fzfignore`

**Git Functions Failing**:
- Ensure in git repository: `git rev-parse --git-dir`
- Check git configuration for signing: `git config --get user.signingkey`
- Verify remote connections: `git remote -v`

### Performance Tuning

**For Large Repositories**:
```zsh
# Add .fzfignore file to exclude large directories
echo "node_modules/" >> ~/.fzfignore
echo "vendor/" >> ~/.fzfignore
echo ".git/" >> ~/.fzfignore
```

**For Slow Machines**:
- Reduce preview line limits
- Disable multi-select if not needed
- Use basic previews instead of syntax highlighting

### Shell Integration Issues

**ZSH Completions**:
- FZF completions loaded after zinit: timing-sensitive
- Use `zinit wait` for deferred loading
- Check load order in `.zshrc`

**Tmux Integration**:
- Ensure plugins loaded: `<prefix>I` to install
- Check tmux version compatibility: `tmux -V`
- Verify popup support (tmux 3.2+)

## Development Guidelines

### Adding New FZF Functions

1. **Function Structure**:
```zsh
function_name() {
  # Input validation
  if ! command_exists; then
    echo "Error: prerequisite not found"
    return 1
  fi

  # Data preparation
  local data=$(prepare_data)

  # FZF invocation with preview
  echo "$data" | fzf \
    --preview='preview_command {}' \
    --bind='key:action' \
    --header="Help text"
}
```

2. **Best Practices**:
- Always validate prerequisites
- Include comprehensive error handling
- Use consistent color schemes
- Provide helpful headers and keybinding hints
- Limit preview output for performance
- Follow existing naming conventions

3. **Preview Guidelines**:
- Use conditional logic for different data types
- Implement safety limits (head -N)
- Preserve color output with `--color=always`
- Handle empty/missing data gracefully

### Testing New Integrations

1. **Unit Testing**:
```bash
# Test basic functionality
your_function --help
your_function --dry-run

# Test edge cases
cd /tmp && your_function  # wrong directory
your_function with-invalid-input
```

2. **Integration Testing**:
- Test with different repository states
- Verify tmux integration works
- Check cross-platform compatibility
- Test performance with large datasets

### Code Style Guidelines

**Function Naming**:
- Git functions: `g<action>` (gco, glog, gstash)
- Worktree functions: `gw<action>` (gwl, gwn, gwd, gws)
- Utility functions: descriptive names (change_background)

**Color Usage**:
- Follow Catppuccin Mocha theme consistently
- Use semantic colors (green=success, red=danger, yellow=warning)
- Preserve tool-native colors when possible

**Error Handling**:
- Always validate git repository context
- Provide clear error messages
- Fail gracefully with helpful suggestions
- Use consistent error format across functions

## Integration Points

### Dependencies
- **bat**: Syntax highlighting for file previews
- **lsd**: Enhanced directory listings with icons
- **git**: Core version control operations
- **tmux**: Terminal multiplexing and session management
- **sesh**: Session management integration
- **kubectl**: Kubernetes context switching

### File Relationships
- **ZSH integration**: `/home/techdufus/.dotfiles/roles/zsh/files/zsh/fzf_config.zsh`
- **Git functions**: `/home/techdufus/.dotfiles/roles/zsh/files/zsh/git_functions.zsh`
- **Tmux config**: `/home/techdufus/.dotfiles/roles/tmux/files/tmux/tmux.conf`
- **Kubernetes aliases**: `/home/techdufus/.dotfiles/roles/bash/files/bash/k8s_aliases.sh`

### Extension Points
- Custom completion functions via `_fzf_comprun`
- Additional git workflows through new functions
- Tmux plugin integrations
- Cross-tool data sharing through consistent formatting

This comprehensive guide should enable effective development, troubleshooting, and enhancement of the fzf integration throughout the dotfiles system.