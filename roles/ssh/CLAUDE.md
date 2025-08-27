# SSH Role - CLAUDE.md

## Overview

The SSH role provides secure SSH key management through 1Password integration for the dotfiles system. This role focuses on automated deployment of SSH keys from 1Password vaults while maintaining security best practices and proper file permissions.

## Role Purpose

- **SSH Key Deployment**: Automatically deploys SSH keys from 1Password vaults
- **Secure Key Management**: Maintains proper file permissions (0600 for private keys, 0644 for public keys)
- **Multi-Account Support**: Supports multiple SSH key sets for different services/accounts
- **1Password Integration**: Leverages 1Password CLI for secure key retrieval
- **Clean Uninstall**: Provides safe removal of deployed keys without affecting user's SSH directory

## Architecture

### File Structure
```
roles/ssh/
├── tasks/
│   ├── main.yml          # Main entry point with .ssh directory setup
│   └── ssh_keys.yml      # SSH key deployment logic
└── uninstall.sh         # Safe key removal script
```

### Key Management Flow
1. **Directory Setup**: Ensures `~/.ssh` exists with proper permissions (0700)
2. **1Password Check**: Only runs if 1Password CLI is installed and authenticated
3. **Key Retrieval**: Fetches private and public keys from specified 1Password vaults
4. **Key Deployment**: Deploys keys with correct permissions and naming
5. **No Logging**: Uses `no_log: true` to prevent secrets from appearing in logs

## 1Password Integration

### Configuration Structure
SSH keys are configured in `group_vars/all.yml` under the `op.ssh` section:

```yaml
op:
  ssh:
    github:
      techdufus:
        - name: id_ed25519                    # Key filename in ~/.ssh/
          vault_path: "op://Personal/TechDufus SSH"
        - name: raft-infra
          vault_path: "op://Raft/Raft-SSH"
```

### 1Password Vault Structure
Each SSH vault entry in 1Password should contain:
- **private_key**: The private SSH key (supports OpenSSH format via `?ssh-format=openssh`)
- **public_key**: The corresponding public SSH key

### Multi-Account Support
The configuration supports multiple account structures:
- **Service-based**: `ssh.github.techdufus`, `ssh.gitlab.work`
- **Environment-based**: `ssh.personal`, `ssh.work`
- **Project-based**: `ssh.project1`, `ssh.project2`

## SSH Key Deployment Process

### Key Retrieval
```yaml
- name: "SSH | Get [{{ item.name }}] key from Vault"
  ansible.builtin.command: "op read --account my.1password.com '{{ item.vault_path }}/private_key?ssh-format=openssh'"
  register: op_private_key
  changed_when: false
  no_log: true
```

### Key Deployment
- **Private Key**: Deployed to `~/.ssh/{{ item.name }}` with mode 0600
- **Public Key**: Deployed to `~/.ssh/{{ item.name }}.pub` with mode 0644
- **Content**: Keys are written with proper line endings

### Security Measures
- **No Logging**: All sensitive operations use `no_log: true`
- **Proper Permissions**: Strict file permissions enforced
- **Secure Directory**: `.ssh` directory created with 0700 permissions
- **1Password Authentication**: Requires active 1Password session

## SSH Agent Integration

### 1Password SSH Agent
The system integrates with 1Password's SSH agent on macOS:

```bash
# Set in shell configurations
export SSH_AUTH_SOCK=~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock
```

### Agent Configuration
1Password agent configuration in `roles/1password/files/agent.toml`:
```toml
[[ssh-keys]]
vault = "Personal"

[[ssh-keys]]
vault = "Raft"
```

## SSH Configuration Management

### Current State
- SSH config management is currently commented out in `main.yml`
- Template system ready for SSH config deployment
- Placeholder for `config.j2` template exists

### Future SSH Config Features
When implemented, SSH config will support:
- Host-specific configurations
- Jump host setups
- Key-specific host mappings
- Connection multiplexing
- Security hardening options

## Security Best Practices

### File Permissions
- **Private Keys**: 0600 (owner read/write only)
- **Public Keys**: 0644 (owner read/write, group/other read)
- **.ssh Directory**: 0700 (owner full access only)

### Secret Handling
- **No Repository Storage**: SSH keys never stored in repository
- **1Password Only**: All keys managed through 1Password vaults
- **No Logging**: Sensitive operations exclude logs
- **Temporary Access**: Keys retrieved only during deployment

### Key Rotation Workflow
1. Update keys in 1Password vault
2. Run `dotfiles -t ssh` to deploy new keys
3. Test SSH connections
4. Update SSH agent if using 1Password agent
5. Remove old keys from remote systems

## Platform Considerations

### macOS
- **1Password SSH Agent**: Native integration available
- **Keychain**: System keychain integration possible
- **File Permissions**: Standard Unix permissions apply

### Linux (Ubuntu/Fedora/Arch)
- **SSH Agent**: Manual SSH agent management
- **File Permissions**: Standard Unix permissions
- **1Password Agent**: Limited availability compared to macOS

### WSL (Windows Subsystem for Linux)
- **File Permissions**: May require special handling
- **Agent Forwarding**: Complex setup with Windows host
- **Path Considerations**: Windows/Linux path translation

## Troubleshooting

### Common Issues

#### 1Password Not Authenticated
```bash
# Check 1Password authentication
op account list
op signin

# Verify access to SSH vaults
op item list --vault "Personal"
```

#### Wrong File Permissions
```bash
# Fix SSH directory permissions
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_*
chmod 644 ~/.ssh/*.pub
```

#### Keys Not Loading in SSH Agent
```bash
# Manual key addition
ssh-add ~/.ssh/id_ed25519

# List loaded keys
ssh-add -l

# Test SSH connection
ssh -T git@github.com
```

#### Missing SSH Keys
```bash
# Verify 1Password vault structure
op item get "TechDufus SSH" --vault "Personal"

# Check vault path configuration in group_vars/all.yml
```

### Debug Commands
```bash
# Test SSH key deployment
dotfiles -t ssh -vvv

# Verify SSH configuration
ssh -T git@github.com -v

# Check SSH agent status
echo $SSH_AUTH_SOCK
ssh-add -l
```

## Development Guidelines

### Adding New SSH Keys

1. **Create 1Password Entry**:
   - Add private_key field with SSH private key
   - Add public_key field with SSH public key
   - Note the vault path

2. **Update Configuration**:
   ```yaml
   op:
     ssh:
       service:
         account:
           - name: key_name
             vault_path: "op://Vault/Item Name"
   ```

3. **Deploy and Test**:
   ```bash
   dotfiles -t ssh
   ssh-add -l
   ssh -T service@hostname
   ```

### Adding SSH Config Management

When implementing SSH config management:

1. **Create Template**: Add `templates/config.j2`
2. **Enable Task**: Uncomment template task in `main.yml`
3. **Add Variables**: Define SSH config variables
4. **Test Idempotency**: Ensure repeated runs don't change config unnecessarily

### Best Practices

#### Task Naming
- Use descriptive names with SSH prefix: `"SSH | Deploy [{{ item.name }}] private key"`
- Include item context in loop operations
- Maintain consistency with existing patterns

#### Variable Structure
```yaml
# Good: Hierarchical and descriptive
op.ssh.github.personal
op.ssh.gitlab.work

# Avoid: Flat and ambiguous
ssh_keys
keys
```

#### Security Considerations
- Always use `no_log: true` for sensitive operations
- Never store keys in repository or logs
- Test key deployment on non-production systems first
- Regularly rotate SSH keys
- Use Ed25519 keys when possible (more secure than RSA)

#### Error Handling
```yaml
# Handle 1Password failures gracefully
- name: "SSH | Deploy SSH keys"
  block:
    - include_tasks: ssh_keys.yml
  rescue:
    - name: "SSH | 1Password authentication failed"
      debug:
        msg: "SSH key deployment skipped - 1Password not authenticated"
```

## Integration Points

### Git Role Integration
- SSH keys used for Git authentication
- Allowed signers for commit verification
- Multiple key support for different Git accounts

### 1Password Role Dependency
- Requires 1Password CLI installation
- Needs active 1Password session
- Agent configuration affects SSH workflow

### Shell Configuration
- SSH agent socket exported in shell configs
- Shell functions may interact with SSH agent
- Environment variables affect SSH behavior

## Future Enhancements

### Planned Features
- **SSH Config Management**: Full SSH client configuration
- **Known Hosts Management**: Automated known_hosts updates
- **Key Rotation Automation**: Scheduled key rotation workflows
- **Multi-Platform Agent**: Better Linux SSH agent integration

### Potential Improvements
- **Key Type Detection**: Auto-detect key algorithms
- **Connection Testing**: Automated SSH connection validation
- **Backup Management**: SSH key backup strategies
- **Audit Logging**: SSH key usage tracking (while maintaining security)

### Integration Opportunities
- **Yubikey Support**: Hardware key integration
- **Certificate Authentication**: SSH certificate-based auth
- **Bastion Host Management**: Jump host automation
- **Container SSH**: SSH into containerized environments

## Security Considerations

### Threat Model
- **Key Compromise**: Keys stored securely in 1Password
- **Local Access**: File permissions prevent unauthorized access
- **Network Exposure**: Keys not transmitted over network during normal operations
- **Logging Exposure**: No-log directives prevent accidental logging

### Compliance
- Follows security best practices for SSH key management
- Supports key rotation requirements
- Maintains audit trail through 1Password
- Enables centralized key management

This comprehensive guide provides everything needed to understand, maintain, and extend the SSH role while maintaining security best practices and 1Password integration.