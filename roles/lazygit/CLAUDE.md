# CLAUDE.md - Lazygit Role

This file provides guidance to Claude Code when working with the lazygit role in this Ansible-based dotfiles management system.

## Role Overview

The **lazygit role** installs and configures Lazygit, a simple terminal UI for git commands. Lazygit provides an intuitive interface for common git operations including staging, committing, pushing, pulling, merging, rebasing, and managing branches. This role supports cross-platform installation on macOS, Ubuntu, Fedora, and other Linux distributions.

## Installation Methods by OS

### macOS
- **Package Manager**: Homebrew (`brew install lazygit`)
- **Installation Method**: Uses `community.general.homebrew` Ansible module
- **Location**: Installed via Homebrew package management
- **Prerequisites**: Homebrew must be installed

### Ubuntu/Debian
- **Installation Method**: GitHub releases (binary download)
- **Process**:
  1. Fetches latest release information from GitHub API
  2. Downloads Linux x86_64 tarball from releases
  3. Extracts and installs to `/usr/local/bin/lazygit`
  4. Version checking prevents unnecessary reinstallation
- **Version Management**: Intelligent version comparison and updates
- **Cleanup**: Automatic cleanup of temporary files via handlers

### Fedora/RHEL
- **Installation Method**: GitHub releases via `github_release` role
- **Features**:
  - Automatic architecture detection (x86_64/arm64)
  - Version pattern matching using regex
  - Sudo-aware installation (system-wide or user directory)
  - Fallback to user directory (`~/.local/bin`) when sudo unavailable
- **Installation Paths**:
  - With sudo: `/usr/local/bin/lazygit`
  - Without sudo: `~/.local/bin/lazygit`

## Configuration System

### Default Configuration Location
- **Config Directory**: `~/.config/lazygit/`
- **Main Config**: `~/.config/lazygit/config.yml`
- **State File**: `~/.config/lazygit/state.yml` (tracks recent repos, settings)

### Configuration Philosophy
This role follows a **minimal configuration approach**:
- Lazygit works excellently with default settings
- User customization happens post-installation
- No opinionated themes or keybindings imposed
- Respects existing user configurations

### State Management
The `state.yml` file automatically tracks:
- Recent repositories
- Last update check timestamp
- Custom command history
- UI preferences (hide command log, whitespace in diff view)
- Startup popup version

## Integration with Development Environment

### Neovim Integration
The role integrates seamlessly with Neovim through two plugins:

#### 1. Dedicated Lazygit Plugin (`lazygit.nvim`)
```lua
-- File: roles/neovim/files/lua/plugins/lazygit.lua
{
  "kdheepak/lazygit.nvim",
  dependencies = { "nvim-lua/plenary.nvim" }
}
```

#### 2. ToggleTerm Integration
```lua
-- File: roles/neovim/files/lua/plugins/toggleterm.lua
local Terminal = require("toggleterm.terminal").Terminal
local lazygit = Terminal:new({ cmd = "lazygit", hidden = true })

function _LAZYGIT_TOGGLE()
    lazygit:toggle()
end
```

#### Keybinding
- **Primary Shortcut**: `<leader>gg` opens Lazygit in Neovim
- **Location**: `roles/neovim/files/lua/techdufus/core/keymaps.lua`
- **Command**: `:LazyGit<cr>`

### Terminal Integration
Lazygit integrates with the broader terminal environment:
- Works in tmux sessions
- Supports floating terminal windows
- Respects system git configuration
- Inherits SSH keys and authentication

## Key Features and Workflows

### Core Git Operations
- **Staging**: Interactive file staging with space/enter
- **Committing**: Built-in commit message editor
- **Branching**: Visual branch management and switching
- **Merging**: Interactive merge conflict resolution
- **Rebasing**: Visual interactive rebase interface
- **Stashing**: Easy stash management
- **Remote Operations**: Push, pull, fetch with progress indicators

### Advanced Features
- **Submodule Support**: Navigate and manage git submodules
- **Worktree Management**: Create and switch between worktrees
- **Custom Commands**: Extensible with user-defined git commands
- **Diff Tools**: Integration with external diff/merge tools
- **Filtering**: Filter commits, files, and branches
- **Search**: Full-text search across commits and files

### Navigation and Keybindings (Default)
- **Panels**: `1-5` switch between panels (Files, Branches, Commits, etc.)
- **Movement**: `j/k` or arrow keys for navigation
- **Actions**: Context-sensitive with `?` for help
- **Tab Completion**: Smart completion for branch names and commands
- **Vim-like**: Familiar keybindings for vim users

## Common Workflows

### Daily Development Workflow
1. **Open Repository**: `cd project && lazygit`
2. **Stage Changes**: Navigate to files, space to stage
3. **Commit**: `c` for commit, write message, confirm
4. **Push**: `P` to push changes
5. **Branch Management**: Switch branches with visual interface

### Feature Branch Workflow
1. **Create Branch**: `b` to create new branch
2. **Work and Commit**: Stage and commit changes
3. **Rebase**: Interactive rebase before merge
4. **Merge**: Visual merge into main branch
5. **Cleanup**: Delete feature branch after merge

### Conflict Resolution
1. **Merge/Rebase**: Conflicts show in dedicated view
2. **External Tool**: Opens configured merge tool
3. **Manual Resolution**: Edit conflicts in editor
4. **Continue**: Continue merge/rebase operation

## Customization Options

### Theme Configuration
```yaml
# ~/.config/lazygit/config.yml
gui:
  theme:
    lightTheme: false
    activeBorderColor:
      - '#ff9e64'
      - bold
    inactiveBorderColor:
      - '#27a1b9'
```

### Custom Commands
```yaml
customCommands:
  - key: '<c-r>'
    command: 'gh repo view --web'
    description: 'Open repo in GitHub'
    context: 'global'
```

### Diff Tool Integration
```yaml
git:
  paging:
    colorArg: always
    pager: delta --dark --paging=never
  merging:
    tool: 'vimdiff'
```

## Troubleshooting

### Common Issues

#### Installation Problems
1. **Permission Denied**: Ensure user has write access to installation directory
2. **Download Failures**: Check internet connectivity and GitHub access
3. **Version Conflicts**: Clear `/tmp/lazygit*` files and reinstall

#### Runtime Issues
1. **Git Not Found**: Ensure git is installed and in PATH
2. **SSH Keys**: Configure SSH agent for remote operations
3. **Large Repositories**: May be slow; consider excluding large binary files

#### Integration Issues
1. **Neovim Not Opening**: Check `<leader>gg` keybinding configuration
2. **Terminal Issues**: Ensure terminal supports colors and Unicode
3. **Tmux Integration**: May need tmux-specific configuration

### Debugging Commands
```bash
# Check installation
which lazygit
lazygit --version

# Test in repository
cd /path/to/git/repo
lazygit

# Check configuration
cat ~/.config/lazygit/config.yml
cat ~/.config/lazygit/state.yml
```

### Log Files
- **Location**: Lazygit creates logs in system temp directory
- **Access**: Use `lazygit --debug` for verbose logging
- **Cleanup**: Logs rotate automatically

## Development Guidelines

### Role Structure
```
roles/lazygit/
├── tasks/
│   ├── main.yml          # OS detection entry point
│   ├── MacOSX.yml        # Homebrew installation
│   ├── Ubuntu.yml        # GitHub release installation
│   └── Fedora.yml        # GitHub release via github_release role
├── handlers/
│   └── main.yml          # Cleanup temporary files
└── uninstall.sh          # Cross-platform removal script
```

### Adding New OS Support
1. Create `tasks/<Distribution>.yml`
2. Implement installation method for OS
3. Update `uninstall.sh` with OS-specific removal
4. Test installation and uninstallation
5. Document any OS-specific requirements

### Version Management
- Ubuntu uses direct GitHub API calls and version comparison
- Fedora uses `github_release` role with pattern matching
- Both methods prevent unnecessary reinstallation
- Version format: `v0.40.2` → extracted and compared

### Testing Approach
```bash
# Test installation
dotfiles -t lazygit

# Test specific OS
ansible-playbook main.yml -t lazygit --limit ubuntu_hosts

# Test uninstallation
./roles/lazygit/uninstall.sh

# Test Neovim integration
nvim
# Press <leader>gg to test lazygit integration
```

### Handler Usage
Handlers automatically clean up temporary files:
- `Cleanup lazygit downloaded tar`: Removes downloaded tarballs
- `Remove extracted lazygit directory`: Cleans extraction directory

## Security Considerations

- **Downloads**: All downloads from official GitHub releases
- **Checksums**: No checksum validation currently (potential improvement)
- **Permissions**: Installs with appropriate executable permissions (0755)
- **User Isolation**: User-directory installation when sudo unavailable
- **Cleanup**: Automatic cleanup of temporary files prevents disk bloat

## Performance Notes

- **Installation Speed**: Ubuntu method involves download/extraction
- **Memory Usage**: Minimal memory footprint during operation
- **Large Repositories**: Performance depends on git repository size
- **Startup Time**: Fast startup, lazy loading of repository information

## Integration Points

### With Other Roles
- **Git Role**: Depends on git configuration and SSH setup
- **Neovim Role**: Provides terminal UI integration
- **Terminal Emulator**: Works with kitty, tmux, and other terminals
- **Shell Environment**: Inherits PATH and environment variables

### External Tools
- **Diff Tools**: delta, vimdiff, meld integration
- **Editors**: Configurable commit message editor
- **SSH Agent**: Uses system SSH configuration
- **GPG**: Supports commit signing when configured

## Future Enhancements

### Potential Improvements
1. **Configuration Templates**: Provide opinionated default configurations
2. **Theme Integration**: Match terminal/editor color schemes
3. **Checksum Validation**: Add SHA256 verification for downloads
4. **Auto-update**: Periodic update checking and installation
5. **Custom Commands**: Ship with useful custom command presets

### Architecture Considerations
- **Config Management**: Currently hands-off approach works well
- **Installation Method**: GitHub releases provide reliability
- **Version Strategy**: Current approach balances automation and control
- **Integration Depth**: Current Neovim integration is comprehensive

This role exemplifies the dotfiles system's philosophy: robust installation, minimal configuration, maximum user freedom for customization.