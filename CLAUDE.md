# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a comprehensive dotfiles repository that uses Ansible to automate development environment setup across multiple operating systems (macOS, Ubuntu, Arch Linux). The repository includes configurations for development tools, terminal environments, and productivity applications.

## Essential Commands

### Running the Playbook
```bash
# Run the full playbook
dotfiles

# Run specific roles/tags
dotfiles -t neovim,zsh

# Run with verbosity
dotfiles -vvv

# Dry run (check mode)
dotfiles --check

# List all available tags
dotfiles --list-tags
```

### Development Commands
```bash
# Lint the Ansible playbook
ansible-lint

# Test specific role
dotfiles -t <role_name> -vvv

# Update dependencies
cd ~/.dotfiles && git pull
```

### Common Maintenance Tasks
```bash
# Update all gh extensions
gh extension list | awk '{print $3}' | xargs -I {} gh extension upgrade {}

# Update npm global packages
npm update -g

# Update Homebrew packages (macOS)
brew update && brew upgrade
```

## Architecture and Key Concepts

### 1. **Ansible-Based Architecture**
- Main playbook: `main.yml` orchestrates all roles
- Each tool/application has its own role in `roles/` directory
- OS-specific configurations handled via conditional task inclusion
- Pre-tasks validate environment before role execution

### 2. **1Password Integration**
- Replaces traditional ansible-vault with 1Password CLI (`op`)
- Secrets referenced via vault paths (e.g., `op://Personal/GitHub/email`)
- SSH keys, Git configs, and sensitive data managed through 1Password
- Authentication required before playbook execution

### 3. **Cross-Platform Support**
- Each role checks for OS-specific task files (`MacOSX.yml`, `Ubuntu.yml`, `Archlinux.yml`)
- Bootstrap script (`bin/dotfiles`) handles OS detection and prerequisite installation
- Shared configurations in role defaults, OS-specific overrides in task files

### 4. **Key Configuration Files**
- `group_vars/all.yml`: Central configuration defining enabled roles and user-specific settings
- `bin/dotfiles`: Bootstrap script and main entry point
- Role structure: `roles/<name>/tasks/main.yml` checks for OS-specific implementations

### 5. **Shell Environment**
- ZSH as default shell with extensive custom functions
- Functions organized by purpose: `pkg_functions.zsh`, `k8s_functions.zsh`, `gcloud_functions.zsh`
- Powerlevel10k prompt for cross-shell prompt consistency
- Integration with fzf for fuzzy finding

### 6. **Development Tool Management**
- Package installations handled by `bin-install` function (supports multiple tools)
- Version management for: Node.js (nvm), Python, Go, Ruby
- Kubernetes tooling: kubectl, k9s, helm with custom helper functions
- Cloud CLIs: AWS, Azure, Google Cloud with credential management

## Important Patterns

### Adding New Roles
1. Create role directory: `roles/<name>/`
2. Add `tasks/main.yml` with OS detection template
3. Create OS-specific task files as needed
4. Add role to `default_roles` in `group_vars/all.yml`

### Secret Management
- Never commit secrets directly
- Always use 1Password vault references
- Format: `op://<vault>/<item>/<field>`

### File Deployments
- Use `ansible.builtin.copy` or `ansible.builtin.template`
- Files stored in `roles/<name>/files/`
- OS-specific files in `roles/<name>/files/os/<OS>/`

### Testing Changes
- Always test with specific tags first: `dotfiles -t <role> --check`
- Use verbose mode for debugging: `-vvv`
- Check `~/.dotfiles.log` for execution history
