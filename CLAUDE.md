# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is an **Ansible-based dotfiles management system** for automated cross-platform development environment setup. It supports macOS, Ubuntu, Fedora, and Arch Linux, providing a consistent development experience across all platforms. The system is built with modularity, idempotency, and graceful degradation in mind.

## Essential Commands

### Development
```bash
# Install/update all dotfiles
dotfiles

# Install specific roles only
dotfiles -t neovim,git,tmux

# Test changes without applying (dry run)
dotfiles --check

# Debug with verbose output
dotfiles -vvv

# List all available roles
dotfiles --list-tags
```

### Common Tasks
```bash
# Uninstall a role (keeps config)
dotfiles --uninstall <role>

# Completely remove a role
dotfiles --delete <role>

# Run syntax check
ansible-playbook main.yml --syntax-check

# Update dotfiles repository
cd ~/.dotfiles && git pull
```

## Architecture and Key Concepts

### 1. **Role-Based Architecture**
Each tool/application is a self-contained Ansible role in `/roles/<tool>/`. Roles automatically detect the OS and only run if supported, preventing errors on incompatible systems.

### 2. **OS Detection Pattern**
```yaml
- name: "{{ role_name }} | Checking for Distribution Config: {{ ansible_distribution }}"
  ansible.builtin.stat:
    path: "{{ role_path }}/tasks/{{ ansible_distribution }}.yml"
  register: distribution_config

- name: "{{ role_name }} | Run Tasks: {{ ansible_distribution }}"
  ansible.builtin.include_tasks: "{{ ansible_distribution }}.yml"
  when: distribution_config.stat.exists
```

### 3. **1Password Integration**
All secrets are managed through 1Password CLI (`op`). The system checks for 1Password availability and falls back gracefully when not authenticated.

### 4. **Package Management Hierarchy**
- macOS: Homebrew
- Ubuntu: apt/nala
- Fedora: dnf
- Arch: pacman
- Language-specific: pip, npm, go, cargo

## Important Patterns

### Directory Structure for Roles
```
roles/<role_name>/
├── tasks/
│   ├── main.yml          # Entry point with OS detection
│   ├── MacOSX.yml        # macOS-specific tasks
│   ├── Ubuntu.yml        # Ubuntu-specific tasks
│   └── Fedora.yml        # Fedora-specific tasks
├── files/               # Static configuration files
├── templates/           # Jinja2 templates
├── defaults/           # Default variables
├── handlers/           # Event handlers
└── uninstall.sh       # Uninstallation script
```

### Task Naming Convention
Always prefix tasks with the role name:
```yaml
- name: "{{ role_name }} | Install | Package dependencies"
```

### Adding New Features
1. Create role directory: `roles/<new_tool>/`
2. Add OS detection in `tasks/main.yml`
3. Create OS-specific task files as needed
4. Add static configs to `files/`
5. Create `uninstall.sh` for clean removal
6. Add role to `group_vars/all.yml` under `default_roles`

### Testing Approach
- Use `--check` flag for dry runs
- Verify idempotency by running twice
- Test on each supported OS
- Check CI linting passes

## Hidden Context

### ZSH Completions Timing Issue
ZSH completions can be overwritten by zinit's cdreplay. The solution is to load custom completions AFTER zinit's replay or use zinit's snippet management.

### 1Password Vault Migration
The project migrated from ansible-vault to 1Password for better secret rotation. Never store secrets in the repository - all secrets should use `op://` references.

### Bootstrap Script Intelligence
The `bin/dotfiles` script handles prerequisites automatically:
- Installs Homebrew on macOS
- Installs Ansible based on OS
- Handles WSL detection
- Provides visual feedback with spinners

### Performance Considerations
- Roles run in parallel where possible
- Ansible Galaxy dependencies are cached
- Use `failed_when: false` for operations that might fail but shouldn't stop execution

### Security Notes
- No secrets in repository (use 1Password)
- SSH keys managed through 1Password
- Git commit signing automated
- Sudo availability checked before operations

## Code Style

### Naming Conventions
- **Roles**: lowercase with underscores (`github_release`)
- **Variables**: snake_case with role prefix (`git_user_name`)
- **Files**: Match tool expectations (`.zshrc`, `config.yaml`)
- **Tasks**: Descriptive with role prefix

### File Organization
- OS-specific files in `files/os/<distribution>/`
- Templates use `.j2` extension
- Uninstall scripts are executable shell scripts

### YAML Standards
- 2-space indentation
- Fully qualified module names (`ansible.builtin.copy`)
- Boolean values: `true`/`false` (not `yes`/`no`)
- Multi-line strings use `|` or `>` appropriately

### Error Handling
- Use `block/rescue` for complex error recovery
- Register results and check `rc` for command success
- Provide helpful debug messages
- Always handle missing dependencies gracefully

## Gotchas and Tips

- **WSL Detection**: Special handling for Windows Subsystem for Linux - checks for PowerShell and host user
- **Homebrew on Linux**: Requires manual PATH setup in shell configs
- **1Password Authentication**: Must be authenticated before running roles that need secrets
- **Idempotency**: Always use `changed_when` appropriately to track state changes
- **OS Compatibility**: Test on target OS - not all roles support all distributions
- **Symlink vs Copy**: Prefer symlinks for config directories to maintain version control
- **Tab Completion**: Complex timing issues in tmux - see ZSH role for solutions
- **Package Versions**: Some packages (like termshark) need specific versions due to dependencies

## CI/CD Quality Gates

The repository enforces quality through GitHub Actions:
- **Ansible Lint**: Validates all playbooks and roles
- **ShellCheck**: Validates shell scripts
- **YAML Lint**: Checks YAML formatting
- **Markdown Lint**: Ensures documentation quality
- **Link Checker**: Validates all documentation links

Always ensure your changes pass all CI checks before merging.