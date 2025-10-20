# Feature: DotfilesCtl TUI Application

## Overview
A terminal user interface (TUI) application for managing dotfiles roles, built with Go and OpenTUI. This provides an interactive, visual alternative to the current bash-based `dotfiles` command, offering real-time progress monitoring, role management, and system status visualization. Initially deployed as `dotfilesctl`, with potential to eventually replace the existing `dotfiles` script.

## Problem Statement
The current `dotfiles` command is functional but lacks:
- Interactive role discovery and management
- Real-time visual feedback during long operations
- Easy way to see system status and installed roles
- Ability to preview what will be installed/changed
- Quick access to common operations without memorizing flags

## Users/Stakeholders
- **Primary**: The repository owner/maintainer for daily dotfiles management
- **Secondary**: Other developers who fork/use this dotfiles system
- **System**: CI/CD pipelines that may need programmatic access

## Requirements

### Functional
- **Role Browser**: Interactive list of all available roles with:
  - Installation status indicators (installed/not installed/partially installed)
  - Search and filter capabilities (by name, status, category)
  - Role descriptions and metadata display
  - Dependency information

- **Installation Manager**:
  - Install/uninstall individual or multiple roles
  - Real-time progress bars for each operation
  - Live log streaming with color support
  - Error handling with recovery suggestions
  - Dry-run mode to preview changes

- **System Status Dashboard**:
  - Overview of all installed roles and versions
  - System compatibility checks
  - Last run timestamps and success/failure status
  - Quick health checks for critical roles

- **Quick Actions Menu**:
  - Update all installed roles
  - Run specific Ansible tags
  - Bootstrap new systems
  - Check for updates to dotfiles repo
  - Clear cache/temporary files

- **Process Management**:
  - Parallel execution of independent operations
  - Graceful cancellation (Ctrl+C) with cleanup
  - Resume interrupted operations
  - Background task queue

### Non-Functional
- **Performance**:
  - Startup time < 100ms
  - Responsive UI even during heavy operations
  - Efficient caching to minimize repeated file reads

- **Cross-Platform**:
  - Full support for macOS, Ubuntu, Fedora, Arch Linux
  - Graceful degradation in minimal terminals
  - SSH session compatibility

- **Security**:
  - Integration with 1Password CLI for secrets
  - No credentials stored in cache
  - Secure handling of sudo operations

- **Usability**:
  - Vim-style keybindings for navigation
  - Catppuccin Mocha color scheme consistency
  - Context-sensitive help system
  - Intuitive layout with minimal learning curve

## Technical Specification

### Architecture
```
dotfilesctl (binary)
├── cmd/                    # CLI entry point
├── internal/
│   ├── tui/               # OpenTUI components
│   │   ├── views/         # Different screens
│   │   ├── components/    # Reusable UI components
│   │   └── theme/         # Catppuccin theme
│   ├── ansible/           # Ansible wrapper
│   │   ├── executor.go    # Playbook execution
│   │   ├── parser.go      # Output parsing
│   │   └── inventory.go   # Role discovery
│   ├── cache/             # State management
│   └── config/            # User preferences
└── pkg/
    └── models/            # Data structures
```

### Dependencies
- **External**:
  - OpenTUI (github.com/sst/opentui/packages/go)
  - Ansible (system requirement)
  - 1Password CLI (optional, for secrets)

- **Internal**:
  - Existing Ansible roles and playbooks
  - group_vars/all.yml configuration
  - Role metadata from tasks/main.yml files

### Data Model
```go
type Role struct {
    Name           string
    Description    string
    Status         InstallStatus
    Dependencies   []string
    LastModified   time.Time
    InstallTime    *time.Time
    Platforms      []string
    HasUninstall   bool
}

type InstallStatus int
const (
    NotInstalled InstallStatus = iota
    Installed
    PartiallyInstalled
    UpdateAvailable
    Failed
)

type Cache struct {
    Roles          map[string]*Role
    LastScan       time.Time
    SystemInfo     SystemInfo
    Preferences    UserPreferences
}
```

### Implementation Approach
1. **Wrapper Implementation**: Direct execution of ansible-playbook with JSON output format
2. **Progress Tracking**: Parse Ansible callback output for real-time updates
3. **State Detection**: Scan filesystem and package managers to determine installation status
4. **Cache Strategy**: SQLite or JSON file in ~/.cache/dotfilesctl/
5. **Configuration**: Store preferences in ~/.config/dotfilesctl/config.yaml

## Implementation Notes

### Patterns to Follow
- Use similar color codes as bin/dotfiles (Catppuccin Mocha)
- Maintain consistent task naming: "role_name | action | description"
- Follow Go best practices and idioms
- Implement similar spinner/progress indicators as current bash script

### Testing Strategy
- **Unit Tests**: Role parsing, status detection, cache operations
- **Integration Tests**: Ansible execution, file operations
- **E2E Tests**: Full workflow from UI interaction to role installation
- **Cross-platform CI**: Test on all supported platforms via GitHub Actions

### Migration Path
1. Phase 1: Deploy as `dotfilesctl` alongside existing `dotfiles`
2. Phase 2: Feature parity and user testing
3. Phase 3: Optional replacement with symlink/alias
4. Phase 4: Full replacement with backwards compatibility wrapper

## Success Criteria
- [ ] Successfully browse and search all available roles
- [ ] Install/uninstall roles with visual progress feedback
- [ ] View system status and installed roles at a glance
- [ ] Execute common operations 50% faster than command-line equivalents
- [ ] Zero regression in functionality vs current dotfiles script
- [ ] <100ms startup time on all platforms
- [ ] Graceful handling of all error conditions

## Out of Scope
- Configuration file editing (use neovim)
- Role creation or modification
- Git operations (commits, pushes)
- Ansible vault management
- Complex Ansible operations (custom inventories, multiple hosts)

## Future Considerations
- **v2 Features**:
  - Role dependency visualization graph
  - Preset configurations (minimal, work, full)
  - Backup and restore functionality
  - Plugin system for custom actions
  - Integration with dotfiles repository updates
  - Batch operations with transaction support

- **Extensibility**:
  - JSON API for programmatic access
  - Hook system for pre/post operations
  - Custom themes beyond Catppuccin
  - Export/import of configurations

## Examples

### Basic Usage
```bash
# Launch TUI
dotfilesctl

# Direct commands (non-interactive)
dotfilesctl install neovim tmux
dotfilesctl uninstall docker
dotfilesctl status
dotfilesctl update --all
```

### Key Bindings
```
Navigation:
  j/k     - Move up/down
  h/l     - Collapse/expand
  /       - Search
  f       - Filter

Actions:
  i       - Install role
  u       - Uninstall role
  r       - Refresh
  Space   - Select/deselect
  Enter   - Execute
  ?       - Help
  q       - Quit
```

### UI Layout Mockup
```
┌─ DotfilesCtl ─────────────────────────────────┐
│ [Roles] [Status] [Logs] [Help]                │
├────────────────────────────────────────────────┤
│ Search: [_____________] Filter: [All Roles ▼] │
├────────────────────────────────────────────────┤
│ ◉ ansible      [installed]   Core dependency  │
│ ◉ neovim       [installed]   Text editor      │
│ ○ docker       [available]   Containers       │
│ ◉ tmux         [installed]   Terminal mux     │
│ ⚠ rust         [partial]     Lang toolchain   │
├────────────────────────────────────────────────┤
│ [i]nstall [u]ninstall [r]efresh [q]uit       │
└────────────────────────────────────────────────┘
```

## References
- [OpenTUI Documentation](https://github.com/sst/opentui)
- [Ansible JSON Callback Plugin](https://docs.ansible.com/ansible/latest/plugins/callback.html)
- [Catppuccin Mocha Color Palette](https://github.com/catppuccin/catppuccin)
- Current implementation: `bin/dotfiles` script
- Ansible playbook structure: `main.yml`, `roles/*/tasks/main.yml`