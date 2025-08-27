# Git Role - CLAUDE.md

This file provides comprehensive guidance for understanding and working with the Git role in this Ansible-based dotfiles system.

## Role Overview and Purpose

The Git role configures a comprehensive, secure, and cross-platform Git environment with:
- **Consistent Git configuration** across macOS, Ubuntu, Fedora, and Arch Linux
- **SSH-based commit signing** for enhanced security
- **1Password integration** for secure credential and key management
- **Enhanced Git experience** with delta diff viewer and optimized settings
- **Professional commit templates** with best practices
- **Cross-platform credential helpers** for seamless authentication

## Git Configuration Management Approach

### Core Philosophy
The role follows a layered configuration approach:
1. **Global base settings** applied to all platforms
2. **OS-specific enhancements** (e.g., delta on macOS)
3. **Security-first credential management** via 1Password
4. **Professional workflow optimization** (rebase, signing, templates)

### Configuration Settings Applied

#### Universal Git Settings (all platforms)
```yaml
# Visual enhancements
color.ui = auto
diff.colorMoved = zebra

# Repository hygiene
fetch.prune = true
init.defaultBranch = main
rerere.enabled = true

# Pull/push behavior
pull.ff = only
pull.rebase = true
rebase.autoStash = true

# Commit signing (SSH-based)
user.signingkey = ~/.ssh/id_ed25519.pub
gpg.format = ssh
commit.gpgsign = true
tag.gpgsign = true
gpg.ssh.allowedSignersFile = ~/.config/git/allowed_signers

# Merge strategy
merge.conflictStyle = zdiff3  # macOS only with delta
```

#### macOS-Specific Enhancements
When `git-delta` is available:
- **Enhanced diff viewer**: `core.pager = delta`
- **Interactive diff filtering**: `delta.interactive.diffFilter`
- **Side-by-side diffs**: `delta.side-by-side = true`
- **Negative space highlighting**: `delta.negative = true`

### Built-in Git Aliases
```bash
# Productivity aliases
git config alias.undo "reset HEAD~1 --mixed"
git config alias.br "branch --format='%(HEAD) %(color:yellow)%(refname:short)%(color:reset) - %(contents:subject) %(color:green)(%(committerdate:relative)) [%(authorname)]' --sort=-committerdate"
```

## 1Password Integration for Secure Credential Management

### Configuration Structure
```yaml
op:
  git:
    user:
      email: "op://Personal/GitHub/email"
    allowed_signers: "op://Personal/TechDufus SSH/allowed_signers"
```

### User Email Management
The role securely retrieves the Git user email from 1Password:
```yaml
- name: "1Password | Get user.email"
  command: "op --account my.1password.com read '{{ op.git.user.email }}'"
  register: op_git_user_email
  when: op_installed
  failed_when: false
```

**Fallback Behavior**: If 1Password is not authenticated or available, the role provides clear instructions without failing the entire playbook.

### SSH Key Management and Allowed Signers

#### Allowed Signers File
The role automatically configures `~/.config/git/allowed_signers` from 1Password:
```yaml
- name: "1Password | Configure ~/.config/git/allowed_signers"
  blockinfile:
    path: "{{ ansible_user_dir }}/.config/git/allowed_signers"
    block: "{{ op_git_ssh_allowed_signers.stdout }}"
    mode: "0600"
```

#### Expected 1Password Structure
Your 1Password vault should contain:
- **Email field**: Your Git commit email address
- **Allowed signers field**: SSH public keys for signature verification

Example `allowed_signers` content:
```
your-email@domain.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5...
your-email@domain.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC...
```

## Commit Template and Conventions

### Commit Template Structure
The role installs a commit template at `~/.config/git/commit_template`:
```
# No more than 50 chars ##### 50 chars is here: #


# Wrap at 72 chars ################################ 72 chars is here: #
```

### Best Practices Enforced
- **50-character subject line limit** with visual guide
- **72-character body wrap** with visual guide
- **Blank line separation** between subject and body
- **Imperative mood** encouraged for commit messages

## OS-Specific Package Management and Installation

### macOS (Homebrew)
```yaml
- name: "Git | MacOSX | Install git"
  homebrew:
    name: git
    state: present

- name: "Git | MacOSX | Install git-delta"
  homebrew:
    name: git-delta
    state: present
```

### Ubuntu/Debian
```yaml
- name: "Git | Ubuntu | Install git (system package)"
  apt:
    name: [git]
    state: present
  become: true
  when: can_install_packages | default(false)
```

**Graceful Degradation**: If sudo is not available, provides manual installation instructions.

### Fedora/RHEL
```yaml
- name: "Git | Fedora | Install git (system package)"
  dnf:
    name: [git]
    state: present
  become: true
```

### Arch Linux
```yaml
- name: "Git | Archlinux | Install git"
  pacman:
    name: [git]
    state: present
  become: true
```

## SSH-Based Commit Signing Setup

### Why SSH Over GPG
- **Simpler key management**: Reuses existing SSH keys
- **Better tooling integration**: Works seamlessly with GitHub/GitLab
- **Reduced complexity**: No need for separate GPG key infrastructure
- **Cross-platform consistency**: SSH is available everywhere

### Signing Configuration
```bash
# Use SSH key for signing
user.signingkey = ~/.ssh/id_ed25519.pub
gpg.format = ssh

# Enable automatic signing
commit.gpgsign = true
tag.gpgsign = true

# Configure allowed signers
gpg.ssh.allowedSignersFile = ~/.config/git/allowed_signers
```

### Verification Process
1. **Commits/tags are signed** with your SSH private key
2. **Verification uses** the allowed_signers file
3. **GitHub/GitLab** automatically recognize SSH signatures
4. **Local verification** works with `git log --show-signature`

## Enhanced Git Aliases and Functions

The role integrates with shell configurations to provide enhanced Git workflows:

### From `zsh/git_functions.zsh` and `bash/git_functions.sh`

#### Quick Workflow Functions
```bash
# Add, commit (signed), and push in one command
gacp "commit message"

# Same as gacp + create PR, approve, and merge
gacpgh "commit message"

# Parse current branch for prompt
parse_git_branch()
```

#### Interactive Enhanced Functions (ZSH only)
```bash
# Enhanced status with comprehensive repository info
gss

# Interactive branch checkout with fuzzy search
gco

# Interactive commit log browser with full diff preview
glog

# Interactive stash manager (apply/pop/drop/branch)
gstash

# Interactive tag browser with preview
gtags
```

#### Worktree Management
```bash
# List all worktrees with detailed information
gwl

# Create new worktree in organized structure
gwn <branch>

# Interactive worktree deletion
gwd

# Interactive worktree switcher
gws
```

#### Standard Git Aliases
```bash
gs      # git status
gc      # git checkout
gcb     # git checkout -b
gcm     # git commit -m
gcane   # git commit --amend --no-edit
gd      # git diff
gp      # git push
gpf     # git push --force-with-lease
gu      # git restore --staged (unstage)
gw      # git worktree
gbr     # git branch (formatted)
ggl     # git log graph
```

## Integration with GitHub CLI and GitLab CLI

### GitHub CLI Integration
- **Automatic PR creation**: `gacpgh` function creates and merges PRs
- **PR status in enhanced status**: `gss` shows current branch PR info
- **Seamless workflow**: From commit to production in one command

### Expected Setup
The role assumes you have:
- `gh` CLI installed and authenticated
- Repository configured with appropriate remote origins
- Proper permissions for PR creation and merging

## Credential Helpers and Cross-Platform Authentication

### Credential Management Strategy
The role doesn't configure credential helpers directly but relies on:
- **SSH key-based authentication** for Git operations
- **OS-native credential helpers** when available
- **1Password SSH agent integration** (if configured)

### Platform-Specific Helpers
- **macOS**: Git typically uses osxkeychain helper automatically
- **Linux**: Relies on SSH keys and system keyring integration
- **WSL**: Special handling for Windows credential integration

## Troubleshooting Guide

### Common Issues and Solutions

#### 1Password Authentication Issues
```bash
# Symptom: Warning about 1Password not authenticated
# Solution: Sign in to 1Password CLI
eval $(op signin)
```

#### SSH Signing Issues
```bash
# Check if SSH key exists
ls -la ~/.ssh/id_ed25519*

# Test SSH agent
ssh-add -l

# Verify allowed_signers configuration
cat ~/.config/git/allowed_signers
```

#### Delta Not Working (macOS)
```bash
# Verify delta installation
brew list git-delta

# Check pager configuration
git config --global core.pager
```

#### Commit Signing Failures
```bash
# Test manual signing
git commit -S -m "test"

# Check signing configuration
git config --list | grep -E "(gpg|sign)"

# Verify SSH key permissions
ls -la ~/.ssh/id_ed25519
chmod 600 ~/.ssh/id_ed25519
```

#### Permission Issues on Linux
```bash
# If git installation fails
sudo apt update && sudo apt install git

# If config directory creation fails
mkdir -p ~/.config/git
chmod 755 ~/.config/git
```

### Debug Mode
Run with verbose output to troubleshoot:
```bash
dotfiles -t git -vvv
```

## Role Dependencies and Integration

### Prerequisites
- **Operating System**: macOS, Ubuntu, Fedora, or Arch Linux
- **Ansible**: Version 2.9+ with community.general collection
- **1Password CLI** (optional but recommended): For secure credential management
- **SSH keys**: For commit signing (role doesn't generate these)

### Integration with Other Roles
- **ZSH/Bash roles**: Provide enhanced Git functions and aliases
- **SSH role**: Should run before Git role to ensure keys are available
- **1Password role**: Should run before Git role for credential access
- **GitHub CLI role**: Enhances Git workflow with PR management

### Variable Dependencies
```yaml
# Required variables
git_user_name: "Your Full Name"  # Used for commit attribution

# Optional 1Password variables
op:
  git:
    user:
      email: "op://vault/item/field"
    allowed_signers: "op://vault/item/field"
```

## Security Considerations

### Secrets Management
- **No secrets stored in repository**: All sensitive data via 1Password
- **SSH key-based authentication**: More secure than password-based
- **Commit signing enabled**: Ensures commit authenticity
- **Allowed signers verification**: Prevents signature spoofing

### Best Practices Enforced
- **Always sign commits and tags**: Configured automatically
- **Use SSH format for signing**: Simpler and more secure than GPG
- **Secure credential storage**: Via 1Password or OS keychain
- **No credential exposure**: Failed 1Password auth doesn't break setup

### File Permissions
```bash
~/.config/git/allowed_signers  # 0600 (read-only for user)
~/.config/git/commit_template  # 0644 (readable by all)
```

## Development Guidelines

### Adding New Git Configuration
1. **Add to main.yml**: For cross-platform settings
2. **Add to OS-specific files**: For platform-unique features
3. **Test on all platforms**: Ensure compatibility
4. **Document in this file**: Update relevant sections

### Testing Approach
```bash
# Test role in isolation
dotfiles -t git --check

# Verify configuration
git config --list --global | grep -v credential

# Test signing
git commit --allow-empty -m "test commit"
git log --show-signature -1

# Test 1Password integration
op read 'op://vault/item/field'
```

### Adding New 1Password Integration
1. **Update group_vars/all.yml**: Add new op.git.* paths
2. **Add task in main.yml**: Follow existing pattern
3. **Add error handling**: Use failed_when: false
4. **Test authentication states**: Both authenticated and not

### Extending Git Functions
1. **Add to appropriate shell role**: zsh/bash
2. **Follow naming convention**: Prefix with 'g'
3. **Include help text**: Document in ghelp() function
4. **Test interactivity**: Ensure fzf integration works

This comprehensive guide ensures secure, consistent, and efficient Git configuration across all supported platforms while maintaining flexibility for different authentication scenarios.