# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is an **Ansible-based dotfiles management system** for automated cross-platform development environment setup. It supports macOS, Ubuntu, Fedora, and Arch Linux, providing a consistent development experience across all platforms. The system is built with modularity, idempotency, and graceful degradation in mind, featuring 50+ preconfigured development tools with visual feedback and intelligent error handling.

## Essential Commands

### Development
```bash
# Install/update all dotfiles (runs ansible-playbook)
dotfiles

# Install specific roles only
dotfiles -t neovim,git,tmux

# Test changes without applying (dry run)
dotfiles --check

# Debug with verbose output
dotfiles -vvv

# List all available roles
dotfiles --list-tags

# Run Ansible syntax check
ansible-playbook main.yml --syntax-check
```

### Common Tasks
```bash
# Uninstall a role (keeps config)
dotfiles --uninstall <role>

# Completely remove a role (packages + config)
dotfiles --delete <role>

# Update dotfiles repository
cd ~/.dotfiles && git pull

# Bootstrap on new machine (auto-installs prerequisites)
bash -c "$(curl -fsSL https://raw.githubusercontent.com/<username>/dotfiles/main/bin/bootstrap)"

# Force reinstall everything
ansible-playbook main.yml --force
```

### Role Development
```bash
# Create new role structure
mkdir -p roles/<new_tool>/{tasks,files,templates,defaults,handlers}

# Test a single role
dotfiles -t <new_tool>

# Run with specific variables
ansible-playbook main.yml -e "git_user_name='New Name'"
```

## Architecture and Key Concepts

### 1. **Role-Based Architecture**
Each tool/application is a self-contained Ansible role in `/roles/<tool>/`. Roles automatically detect the OS and only run if supported, preventing errors on incompatible systems.

```
roles/<role_name>/
├── tasks/
│   ├── main.yml          # Entry point with OS detection
│   ├── MacOSX.yml        # macOS-specific tasks
│   ├── Ubuntu.yml        # Ubuntu-specific tasks
│   ├── Fedora.yml        # Fedora-specific tasks
│   └── Archlinux.yml     # Arch-specific tasks
├── files/                # Static configuration files
├── templates/            # Jinja2 templates (.j2)
├── defaults/             # Default variables
├── handlers/             # Event handlers
└── uninstall.sh         # Uninstallation script
```

### 2. **OS Detection Pattern**
Every role uses this consistent pattern for cross-platform support:
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

```yaml
# Reading secrets pattern
- name: "git | Get user email from 1Password"
  ansible.builtin.shell: |
    op --account my.1password.com read 'op://Dotfiles/Github/email'
  register: git_user_email_op
  when: op_installed and op_authenticated
  failed_when: false
```

### 4. **Package Management Hierarchy**
- **macOS**: Homebrew (`brew`) and Homebrew Cask (`brew cask`)
- **Ubuntu**: apt with nala preference when available
- **Fedora**: dnf
- **Arch**: pacman
- **Language-specific**: pip, npm, go get/install, cargo, gem

### 5. **Bootstrap Intelligence**
The `bin/dotfiles` script handles prerequisites automatically:
- Detects OS and installs appropriate package manager
- Installs Ansible based on OS
- Handles WSL detection and setup
- Provides visual feedback with custom spinners
- Auto-installs 1Password CLI on supported platforms

## Important Patterns

### Directory Structure for New Roles
When creating a new role, follow this structure:
1. Create role directory: `roles/<new_tool>/`
2. Add OS detection in `tasks/main.yml`
3. Create OS-specific task files as needed
4. Add static configs to `files/` (use subdirs for OS-specific files)
5. Create templates in `templates/` with `.j2` extension
6. Add default variables to `defaults/main.yml`
7. Create `uninstall.sh` for clean removal
8. Add role to `group_vars/all.yml` under `default_roles`

### Task Naming Convention
Always prefix tasks with the role name:
```yaml
- name: "{{ role_name }} | Install | Package dependencies"
- name: "{{ role_name }} | Configure | User settings"
- name: "{{ role_name }} | Symlink | Configuration files"
```

### Configuration Management
- **Static files**: Use `ansible.builtin.copy` from `files/` directory
- **Dynamic files**: Use `ansible.builtin.template` with `.j2` templates
- **Symlinks preferred**: Link to role files to maintain version control
- **User customization**: Variables in `group_vars/all.yml`

### Error Handling Best Practices
```yaml
# For non-critical operations
- name: "role | Optional feature"
  command: some-command
  failed_when: false
  changed_when: false

# For complex operations
- block:
    - name: "role | Try operation"
      command: risky-command
  rescue:
    - name: "role | Fallback operation"
      command: safe-command
```

### Testing Approach
- Use `--check` flag for dry runs
- Verify idempotency by running twice
- Test on each supported OS
- Check CI linting passes (ansible-lint, shellcheck, yaml-lint)
- Validate uninstall scripts work cleanly

## Hidden Context

### ZSH Completions Timing Issue
ZSH completions can be overwritten by zinit's cdreplay. This is especially problematic in tmux:
- tmux starts → PTY creation → .zshrc → compinit → custom completions fail
- **Solution**: Load custom completions AFTER zinit's replay or use zinit's snippet management
- Alternative: Use precmd hook to defer registration until shell is ready

### 1Password Vault Migration
The project migrated from ansible-vault to 1Password for better secret rotation:
- Old method: `~/.ansible-vault/vault.secret` (deprecated, security risk)
- New method: All secrets use `op://` references
- **Never store secrets in the repository**
- Git history may contain old encrypted values - secret was "scorched from earth"

### WSL-Specific Handling
- Detects WSL by checking `/proc/version` for Microsoft string
- PowerShell ExecutionPolicy must be RemoteSigned
- Complex logic to detect Windows username from WSL environment
- Special handling for file permissions and symlinks

### Bootstrap Script Intelligence
The `bin/dotfiles` script is more than a wrapper:
- Auto-detects OS and installs prerequisites
- Custom spinner implementation for visual feedback
- Handles missing dependencies gracefully
- Provides helpful error messages with solutions

### Performance Considerations
- Roles run in parallel where possible
- Ansible Galaxy dependencies are cached
- Use `failed_when: false` for operations that might fail but shouldn't stop execution
- Heavy operations (like large git clones) show progress

### Known Issues and Workarounds

**Ubuntu 22+ pip changes**:
- System-managed Python prevents direct pip installs
- Solution: Different installation approach for Ubuntu >22

**Homebrew on Linux**:
- Requires manual PATH setup in shell configs
- Not automatically added to PATH like on macOS

**termshark v2.4.0**:
- Has dependency issues
- Currently commented out in `group_vars/all.yml`

**Hosts management**:
- Current implementation overwrites entire `/etc/hosts`
- TODO: Refactor to use blockinfile for safer updates

**Dual GPU mouse cursor**:
- Kitty custom cursor can become invisible on dual GPU setups
- Workaround: Disable custom cursor in Kitty config

### Security Notes
- **No secrets in repository** - use 1Password references
- **SSH keys** managed through 1Password, deployed on demand
- **Git commit signing** automated with allowed_signers from 1Password
- **Sudo availability** checked before operations, graceful fallback
- **Credential helpers** configured per-OS for secure git access
- **Critical system packages** (git, python) never uninstalled

## Code Style

### Naming Conventions
- **Roles**: lowercase with underscores (`github_release`, `starship`)
- **Variables**: snake_case with role prefix (`git_user_name`, `tmux_prefix_key`)
- **Files**: Match tool expectations (`.zshrc`, `config.yaml`, `kitty.conf`)
- **Tasks**: Descriptive with role prefix pattern
- **OS-specific files**: `filename_{{ ansible_distribution }}.ext`

### File Organization
- OS-specific files in `files/os/<distribution>/` when many files differ
- Templates use `.j2` extension consistently
- Uninstall scripts are executable shell scripts
- Handler files for service management operations

### YAML Standards
- 2-space indentation (enforced by yaml-lint)
- Fully qualified module names (`ansible.builtin.copy` not just `copy`)
- Boolean values: `true`/`false` (not `yes`/`no`)
- Multi-line strings use `|` for literal, `>` for folded
- Comments explain "why", not "what"

### Idempotency Requirements
- All tasks must be safely re-runnable
- Use `creates:` parameter for file creation
- Use `changed_when:` appropriately
- Register results and check conditions
- Prefer declarative modules over shell commands

## Gotchas and Tips

- **WSL Detection**: Special handling for Windows Subsystem for Linux - checks for PowerShell and host user
- **Homebrew on Linux**: Requires manual PATH setup in shell configs (not automated)
- **1Password Authentication**: Must be authenticated before running roles that need secrets
- **Idempotency**: Always use `changed_when` appropriately to track state changes
- **OS Compatibility**: Test on target OS - not all roles support all distributions
- **Symlink vs Copy**: Prefer symlinks for config directories to maintain version control
- **Tab Completion**: Complex timing issues in tmux - see ZSH role for solutions
- **Package Versions**: Some packages (like termshark) need specific versions due to dependencies
- **System Dependencies**: Never uninstall git, python, or other critical system packages
- **Dual Config Files**: Some roles have both generic and OS-specific configs (e.g., `kitty.conf` and `kitty_MacOSX.conf`)
- **Visual Mode**: The bootstrap script includes custom color output using Catppuccin Mocha theme

## CI/CD Quality Gates

The repository enforces quality through GitHub Actions:
- **Ansible Lint**: Validates all playbooks and roles follow best practices
- **ShellCheck**: Validates shell scripts for common issues
- **YAML Lint**: Checks YAML formatting with relaxed Ansible-compatible rules
- **Markdown Lint**: Ensures documentation quality
- **Link Checker**: Validates all documentation links with retry logic

All workflows trigger on:
- Push to main branch
- Pull requests to main branch
- Path-specific triggers for relevant file types

Always ensure your changes pass all CI checks before merging. Run local checks with:
```bash
# Ansible syntax check
ansible-playbook main.yml --syntax-check

# Dry run to test changes
dotfiles --check
```

## Common Development Tasks

### Adding a New Tool/Application
1. Create role structure: `mkdir -p roles/<tool>/{tasks,files,defaults}`
2. Copy OS detection pattern from existing role's `tasks/main.yml`
3. Create OS-specific task files for supported platforms
4. Add installation tasks using appropriate package manager
5. Add configuration deployment (copy/template/symlink)
6. Create `uninstall.sh` following existing patterns
7. Add to `default_roles` in `group_vars/all.yml`
8. Test with `dotfiles -t <tool>` on each supported OS

### Debugging Failed Installations
1. Run with verbose output: `dotfiles -vvv`
2. Check role's OS-specific task file exists
3. Verify package name for the OS's package manager
4. Check 1Password authentication if using secrets
5. Look for conditional failures in task output
6. Test role in isolation: `dotfiles -t <role>`

### Modifying Existing Configurations
1. Locate configuration in `roles/<tool>/files/`
2. Make changes to the file
3. Run `dotfiles -t <tool>` to apply changes
4. Verify symlinks updated with `ls -la ~/.<config>`
5. Test the application with new configuration
6. Commit changes with descriptive message

This comprehensive guide should help Claude understand and work effectively with this dotfiles repository.

---

## Active Work
<!-- Auto-updated by /work when in structured mode -->
<!-- Clear this section when task completes -->

## Learned Patterns
<!-- Append when notable patterns discovered -->
<!-- Format:
### YYYY-MM-DD - <category>
- Task: <what was done>
- Pattern: <reusable insight>
- Files: <relevant locations>
-->

## Decisions Log
<!-- Append when significant choices made -->
<!-- Format:
### YYYY-MM-DD - <decision>
- Context: <situation>
- Chosen: <option selected>
- Rationale: <why>
-->