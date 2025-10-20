# 1Password Role - CLAUDE.md

This file provides comprehensive guidance for working with the 1Password role in this Ansible-based dotfiles system. The 1Password role is the **security foundation** of the entire dotfiles ecosystem, providing centralized secret management and SSH agent functionality.

## Role Overview

The 1Password role serves as the **secure secret management backbone** for the entire dotfiles system. It installs the 1Password CLI, configures the SSH agent, and enables seamless integration with other roles that require secure credentials.

### Purpose and Scope
- **Primary Purpose**: Install and configure 1Password CLI for secure secret management
- **SSH Agent**: Configure 1Password SSH agent for key management across multiple vaults
- **Integration Hub**: Provide secure credential access for git, SSH, and other roles
- **Cross-Platform**: Support macOS and Ubuntu/Debian with platform-specific installation methods

### Key Features
- Automated 1Password CLI installation per platform
- SSH agent configuration for multiple vault access
- Secure directory structure creation with proper permissions
- Integration with the broader dotfiles ecosystem
- Clean uninstallation process with data preservation warnings

## Architecture and Files

```
roles/1password/
├── tasks/
│   ├── main.yml          # OS detection and common setup
│   ├── MacOSX.yml        # macOS installation via Homebrew
│   └── Ubuntu.yml        # Ubuntu installation via apt with GPG verification
├── files/
│   └── agent.toml        # SSH agent configuration for multiple vaults
└── uninstall.sh         # Safe uninstallation with user confirmation
```

### Core Components

#### 1. Cross-Platform Installation (`tasks/main.yml`)
```yaml
# Standard OS detection pattern
- name: "{{ role_name }} | Checking for Distribution Config: {{ ansible_distribution }}"
  ansible.builtin.stat:
    path: "{{ role_path }}/tasks/{{ ansible_distribution }}.yml"
  register: distribution_config

- name: "{{ role_name }} | Run Tasks: {{ ansible_distribution }}"
  ansible.builtin.include_tasks: "{{ ansible_distribution }}.yml"
  when: distribution_config.stat.exists
```

#### 2. Directory Structure Creation
Creates secure configuration directories with proper permissions:
- `~/.config/` (755)
- `~/.config/1Password/` (755)
- `~/.config/1Password/ssh/` (755)

#### 3. SSH Agent Configuration Deployment
Deploys `agent.toml` to `~/.config/1Password/ssh/agent.toml` with 644 permissions.

## Platform-Specific Installation

### macOS Installation (`tasks/MacOSX.yml`)
Uses Homebrew Cask for both GUI and CLI:
```yaml
- name: "1Password | MacOSX | Install 1Password"
  community.general.homebrew_cask:
    name: "{{ item }}"
    state: present
  loop:
    - 1password          # GUI application
    - 1password-cli      # Command-line interface
```

### Ubuntu Installation (`tasks/Ubuntu.yml`)
Implements secure APT repository setup with GPG verification:
```yaml
# GPG key management
- name: "1Password | Add APT Key"
  ansible.builtin.apt_key:
    url: https://downloads.1password.com/linux/keys/1password.asc
    keyring: /usr/share/keyrings/1password-archive-keyring.gpg
    state: present
  become: true

# Repository configuration
- name: "1Password | Add APT Repo"
  ansible.builtin.apt_repository:
    repo: "deb [arch={{ ansible_machine | replace('x86_64', 'amd64') }} signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/{{ ansible_machine | replace('x86_64', 'amd64') }} stable main"
    state: present
  become: true

# Package signature verification setup
- name: "1Password | Add debsig-verify policy"
  # Complex block for package signature verification
```

**Security Features**:
- GPG key verification for package authenticity
- Dedicated keyring isolation (`/usr/share/keyrings/1password-archive-keyring.gpg`)
- Package signature verification via debsig-verify policy
- Architecture-specific repository URLs

## SSH Agent Configuration

### Agent Configuration (`files/agent.toml`)
Configures 1Password SSH agent to access keys from multiple vaults:

```toml
# Enable SSH keys from Personal vault
[[ssh-keys]]
vault = "Personal"

# Enable SSH keys from Raft vault
[[ssh-keys]]
vault = "Raft"

# Enable SSH keys from StarSage vault
[[ssh-keys]]
vault = "StarSage"
```

### SSH Agent Integration
The SSH agent integration works by:

1. **macOS**: Setting `SSH_AUTH_SOCK` environment variable
   ```bash
   export SSH_AUTH_SOCK=~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock
   ```

2. **Agent Configuration**: Using `agent.toml` to control key availability and order
3. **Vault Access**: Configuring which vaults provide SSH keys to the agent
4. **Key Testing**: Using `ssh-add -l` to verify available keys

### Key Benefits
- **Zero Key Management**: No manual SSH key file management
- **Secure Storage**: Keys never stored on disk in plain text
- **Multi-Vault Support**: Access keys from different organizational contexts
- **Automatic Authentication**: Seamless key usage with proper agent configuration

## Secret Management Patterns

### 1Password CLI Usage Patterns

#### Standard Secret Reading
```yaml
# Basic secret retrieval
- name: "role | Get secret from 1Password"
  ansible.builtin.command: "op read 'op://vault/item/field'"
  register: secret_value
  no_log: true
  when: op_installed
```

#### Account-Specific Retrieval
```yaml
# Account-specific secret retrieval
- name: "role | Get account-specific secret"
  ansible.builtin.command: "op --account my.1password.com read 'op://vault/item/field'"
  register: secret_value
  no_log: true
  when: op_installed
```

#### SSH Key Retrieval
```yaml
# SSH private key with format specification
- name: "SSH | Get private key from Vault"
  ansible.builtin.command: "op read --account my.1password.com '{{ vault_path }}/private_key?ssh-format=openssh'"
  register: private_key
  no_log: true
  when: op_installed

# SSH public key retrieval
- name: "SSH | Get public key from Vault"
  ansible.builtin.command: "op read --account my.1password.com '{{ vault_path }}/public_key'"
  register: public_key
  no_log: true
  when: op_installed
```

### Secret Reference Format (`op://` URLs)

The system uses standardized `op://` URL format for secret references:

```yaml
# Configuration in group_vars/all.yml
op:
  git:
    user:
      email: "op://Personal/GitHub/email"
    allowed_signers: "op://Personal/TechDufus SSH/allowed_signers"
  ssh:
    github:
      techdufus:
        - name: id_ed25519
          vault_path: "op://Personal/TechDufus SSH"
        - name: raft-infra
          vault_path: "op://Raft/Raft-SSH"
```

**URL Format**: `op://vault_name/item_name/field_name`
- `vault_name`: The 1Password vault containing the item
- `item_name`: The specific item within the vault
- `field_name`: The field within the item (optional, defaults to password)

## System Integration Points

### 1. Pre-Task Detection (`pre_tasks/detect_1password.yml`)
The main playbook detects 1Password availability:

```yaml
- name: Detect 1Password
  ansible.builtin.command:
    cmd: which op
  changed_when: false
  failed_when: false
  register: op_installed

- name: Register 1Password
  ansible.builtin.set_fact:
    op_installed: "{{ op_installed.rc == 0 }}"
  when: op_installed.rc == 0
```

### 2. Conditional Role Execution
Roles use `op_installed` fact for conditional secret operations:

```yaml
- name: "role | Secret operation"
  ansible.builtin.command: "op read 'secret_path'"
  when: op_installed
  failed_when: false
```

### 3. Git Integration
The git role uses 1Password for:

#### User Configuration
```yaml
- name: "Git | Get user email from 1Password"
  ansible.builtin.command: "op --account my.1password.com read '{{ op.git.user.email }}'"
  register: git_user_email_op
  when: op_installed
  failed_when: false
```

#### SSH Commit Signing
```yaml
- name: "1Password | Get allowed_signers"
  ansible.builtin.command: "op read '{{ op.git.allowed_signers }}'"
  register: op_git_ssh_allowed_signers
  when: op_installed

- name: "1Password | Configure ~/.config/git/allowed_signers"
  ansible.builtin.blockinfile:
    path: "{{ ansible_user_dir }}/.config/git/allowed_signers"
    block: "{{ op_git_ssh_allowed_signers.stdout }}"
    when:
      - op_installed
      - op_git_ssh_allowed_signers.rc == 0
```

### 4. SSH Key Management
The ssh role uses 1Password for automated key deployment:

```yaml
# Private key deployment
- name: "SSH | Deploy [{{ item.name }}] private key"
  ansible.builtin.copy:
    dest: "{{ ansible_user_dir }}/.ssh/{{ item.name }}"
    content: "{{ op_private_key.stdout }}\n"
    mode: "0600"
  no_log: true

# Public key deployment
- name: "SSH | Deploy [{{ item.name }}] public key"
  ansible.builtin.copy:
    dest: "{{ ansible_user_dir }}/.ssh/{{ item.name }}.pub"
    content: "{{ op_public_key.stdout }}"
    mode: "0644"
  no_log: true
```

### 5. Shell Environment Integration
Shell roles (zsh, bash) use 1Password for runtime environment variables:

```bash
# Example from zsh/files/zsh/vars.secret
export OPENAI_API_KEY=$(op read --account $MY_ACCOUNT "op://Personal/Openai/Project Key")
export GITHUB_TOKEN=$(op read --account $MY_ACCOUNT "op://Personal/GitHub/token")
export SONAR_TOKEN=$(op read --account $MY_ACCOUNT "op://Raft/Sonarcube Cloud/credential")
```

## Authentication and Session Management

### Authentication Prerequisites
1. **1Password Account**: Active 1Password account with CLI access
2. **Account Setup**: CLI configured with account domain (`my.1password.com`)
3. **Authentication**: Valid session token or interactive authentication
4. **Vault Access**: Appropriate permissions for target vaults

### Session Management
```bash
# Check authentication status
op account list

# Sign in to account
op signin my.1password.com

# Verify session
op whoami

# List accessible vaults
op vault list
```

### Error Handling Patterns
Roles implement graceful degradation when 1Password is unavailable:

```yaml
- name: "role | Try 1Password operation"
  ansible.builtin.command: "op read 'secret_path'"
  register: secret_result
  failed_when: false
  when: op_installed

- name: "role | Use fallback when 1Password unavailable"
  ansible.builtin.set_fact:
    config_value: "{{ fallback_value }}"
  when: not op_installed or secret_result.rc != 0
```

## Security Best Practices

### 1. Secret Handling
- **No Logging**: Use `no_log: true` for all secret operations
- **Secure Permissions**: Set appropriate file permissions (600 for private keys, 644 for config)
- **Memory Protection**: Avoid storing secrets in variables longer than necessary
- **Conditional Execution**: Always check `op_installed` before 1Password operations

### 2. Vault Organization
- **Separation of Concerns**: Use different vaults for different contexts (Personal, Raft, StarSage)
- **Principle of Least Privilege**: Only configure access to necessary vaults
- **Naming Conventions**: Use consistent item and field naming across vaults

### 3. Error Handling
- **Graceful Degradation**: Continue playbook execution even when secrets unavailable
- **User Feedback**: Provide clear messages when 1Password operations fail
- **Fallback Values**: Use sensible defaults when secrets unavailable

### 4. Integration Safety
```yaml
# Safe pattern for 1Password integration
- block:
    - name: "role | Get secret from 1Password"
      ansible.builtin.command: "op read '{{ secret_path }}'"
      register: secret_value
      no_log: true
  rescue:
    - name: "role | Handle 1Password unavailable"
      ansible.builtin.debug:
        msg: "1Password unavailable, using fallback configuration"
  when: op_installed
```

## Troubleshooting

### Common Issues

#### 1. CLI Not Found
**Symptom**: `op_installed` is false after role execution
**Solutions**:
- Verify installation completed successfully
- Check PATH includes 1Password CLI location
- On macOS: Ensure Homebrew is properly configured
- On Ubuntu: Verify APT repository was added correctly

#### 2. Authentication Failures
**Symptom**: `op read` commands fail with authentication errors
**Solutions**:
```bash
# Check current authentication
op account list

# Re-authenticate
op signin my.1password.com

# Verify session
op whoami
```

#### 3. SSH Agent Not Working
**Symptom**: SSH keys not available via agent
**Solutions**:
- Verify `SSH_AUTH_SOCK` environment variable is set
- Check `agent.toml` configuration
- Test agent connection: `ssh-add -l`
- Restart 1Password application

#### 4. Permission Errors
**Symptom**: Cannot access 1Password directories or configs
**Solutions**:
- Check directory permissions: `ls -la ~/.config/1Password/`
- Re-run role to fix permissions: `dotfiles -t 1password`
- Verify user ownership of configuration files

#### 5. Vault Access Issues
**Symptom**: Cannot read from specific vaults
**Solutions**:
- Verify vault names in `agent.toml` match actual vault names
- Check vault permissions in 1Password
- Confirm item names and field names are correct

### Debugging Commands

```bash
# Test 1Password CLI installation
which op
op --version

# Test authentication
op whoami
op account list

# Test vault access
op vault list
op item list --vault "Personal"

# Test SSH agent
echo $SSH_AUTH_SOCK
ssh-add -l

# Test specific secret retrieval
op read "op://Personal/GitHub/email"
```

### Log Analysis
When debugging failed deployments:

```bash
# Run with verbose output
dotfiles -vvv -t 1password

# Check for specific error patterns
# - "op: command not found" → Installation failed
# - "authentication required" → Need to sign in
# - "vault not found" → Check vault names in agent.toml
# - "item not found" → Verify item names in group_vars/all.yml
```

## Development Guidelines

### Adding New Secret References

1. **Add to group_vars/all.yml**:
   ```yaml
   op:
     new_role:
       secret_name: "op://Vault/Item/field"
   ```

2. **Use in role tasks**:
   ```yaml
   - name: "role | Get secret from 1Password"
     ansible.builtin.command: "op read '{{ op.new_role.secret_name }}'"
     register: secret_value
     no_log: true
     when: op_installed
     failed_when: false
   ```

3. **Handle unavailability**:
   ```yaml
   - name: "role | Use secret or fallback"
     ansible.builtin.set_fact:
       config_value: "{{ secret_value.stdout if (op_installed and secret_value.rc == 0) else 'fallback_value' }}"
   ```

### Creating New Vault Integrations

1. **Update agent.toml**:
   ```toml
   [[ssh-keys]]
   vault = "NewVault"
   ```

2. **Add vault references to group_vars**:
   ```yaml
   op:
     ssh:
       new_context:
         - name: new_key
           vault_path: "op://NewVault/SSH Key Item"
   ```

3. **Test vault access**:
   ```bash
   op vault list
   op item list --vault "NewVault"
   ```

### Role Development Standards

1. **Always check `op_installed`** before 1Password operations
2. **Use `no_log: true`** for secret operations
3. **Set `failed_when: false`** for optional secret retrieval
4. **Provide fallback behavior** when 1Password unavailable
5. **Use consistent naming** for secret references
6. **Document vault requirements** in role documentation

### Testing Changes

```bash
# Test 1password role in isolation
dotfiles -t 1password

# Test with dependent roles
dotfiles -t 1password,git,ssh

# Test dry run
dotfiles --check -t 1password

# Test without 1Password available
op signout --forget --account my.1password.com
dotfiles -t git  # Should use fallbacks
```

## Uninstallation Process

The role provides a comprehensive uninstallation script (`uninstall.sh`) with:

### Safety Features
- **User Confirmation**: Requires explicit confirmation before removal
- **Data Warning**: Warns about losing access to vault data
- **Graceful Handling**: Continues even if some removal steps fail

### Removal Process
1. **Application Termination** (macOS): Closes 1Password app if running
2. **Package Removal**: Removes via platform package manager
3. **Data Cleanup**: Removes configuration and cache directories
4. **Preservation**: Keeps vault data intact (only removes local config)

### Platform-Specific Cleanup
- **macOS**: Removes Homebrew casks, application bundle, preferences
- **Linux**: Removes APT packages, CLI binary, configuration

## Current Status

### Active Integration
The 1Password role is currently **commented out** in `group_vars/all.yml` (`# - 1password`), meaning:
- Role is available but not deployed by default
- Other roles gracefully handle its absence via `op_installed` checks
- Can be manually activated by uncommenting or running `dotfiles -t 1password`

### Why It's Disabled
- **Optional Dependency**: Not all users have 1Password accounts
- **Graceful Degradation**: System works without it using fallbacks
- **Manual Activation**: Users can enable when needed
- **Security Choice**: Users opt into secret management integration

## Integration Examples

### Successful Integration Pattern (Git Role)
```yaml
# Check for 1Password availability
- name: "Git | Get user email from 1Password"
  ansible.builtin.command: "op --account my.1password.com read '{{ op.git.user.email }}'"
  register: git_user_email_op
  when: op_installed
  failed_when: false
  no_log: true

# Use secret or prompt user
- name: "Git | Set user.email"
  community.general.git_config:
    name: user.email
    scope: global
    value: "{{ git_user_email_op.stdout if (op_installed and git_user_email_op.rc == 0) else git_user_email | default(omit) }}"
```

This pattern ensures the system works with or without 1Password, providing a seamless experience regardless of secret management availability.

## Future Considerations

### Potential Enhancements
1. **Session Management**: Automatic session renewal
2. **Multi-Account Support**: Support for multiple 1Password accounts
3. **Biometric Integration**: Platform-specific biometric authentication
4. **Secret Rotation**: Automated secret rotation workflows
5. **Audit Logging**: Enhanced logging for secret access patterns

### Security Roadmap
1. **Zero-Trust Principles**: Enhanced verification for secret access
2. **Secret Scanning**: Automated scanning for exposed secrets
3. **Compliance Integration**: Support for compliance frameworks
4. **Key Rotation**: Automated SSH key rotation workflows

The 1Password role represents the security foundation of this dotfiles system, providing enterprise-grade secret management with graceful degradation for users who prefer alternative approaches.