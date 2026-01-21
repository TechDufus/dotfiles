# 🔐 SSH Role

Automated SSH client installation and secure key management through 1Password integration.

## Overview

This Ansible role provides secure SSH key deployment and management using 1Password vaults. It ensures SSH clients are installed across multiple platforms and automatically deploys SSH keys from 1Password with proper permissions, eliminating manual key management while maintaining security best practices.

## Supported Platforms

| Platform | SSH Client | Installation Method |
|----------|------------|---------------------|
| macOS | OpenSSH | Homebrew (if not present) |
| Ubuntu | openssh-client | apt |
| Fedora | openssh-clients | dnf |

## Features

- **Automated SSH Client Installation** - Ensures OpenSSH is available on all platforms
- **1Password Integration** - Securely retrieves and deploys SSH keys from 1Password vaults
- **Multi-Key Support** - Deploy multiple SSH key pairs for different services and accounts
- **Secure Permissions** - Automatically sets correct file permissions (0700 for `.ssh`, 0600 for private keys, 0644 for public keys)
- **No Secret Logging** - All sensitive operations use `no_log: true` to prevent key exposure in logs
- **Graceful Degradation** - Warns when 1Password is unavailable instead of failing
- **Safe Uninstall** - Removes only managed keys, preserves user's SSH directory and configuration

## What Gets Installed

### Packages

| Platform | Package |
|----------|---------|
| macOS | `openssh` (via Homebrew, only if not present) |
| Ubuntu | `openssh-client` |
| Fedora | `openssh-clients` |

### Configuration

- Creates `~/.ssh/` directory with mode `0700`
- Deploys SSH key pairs from 1Password vaults:
  - Private keys: `~/.ssh/<key_name>` (mode `0600`)
  - Public keys: `~/.ssh/<key_name>.pub` (mode `0644`)

## Architecture

```mermaid
graph TB
    A[SSH Role] --> B{OS Detection}
    B -->|macOS| C[Check OpenSSH]
    B -->|Ubuntu| D[Install openssh-client]
    B -->|Fedora| E[Install openssh-clients]

    C -->|Not Found| F[Install via Homebrew]
    C -->|Found| G[Skip]
    F --> H[Create .ssh Directory]
    G --> H
    D --> H
    E --> H

    H --> I{1Password Available?}
    I -->|Yes| J[Retrieve Keys from Vaults]
    I -->|No| K[Warn and Skip]

    J --> L[Deploy Private Key]
    J --> M[Deploy Public Key]

    L --> N[Set Permissions 0600]
    M --> O[Set Permissions 0644]

    N --> P[SSH Keys Ready]
    O --> P
    K --> Q[Manual Setup Required]
```

## Dependencies

### Required

- **1Password CLI** - Must be installed and authenticated to deploy SSH keys
  - Installation handled by the `1password` role
  - Must run `op signin` before deploying keys

### Optional

- **1Password SSH Agent** - For automatic SSH key management on macOS
  - Configured in the `1password` role
  - Sets `SSH_AUTH_SOCK` environment variable

## Configuration

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

Each SSH vault entry in 1Password must contain:

| Field | Description |
|-------|-------------|
| `private_key` | SSH private key (automatically converted to OpenSSH format) |
| `public_key` | SSH public key |

### Multi-Account Support

Configure keys for different services or environments:

```yaml
op:
  ssh:
    github:
      personal:
        - name: github_personal
          vault_path: "op://Personal/GitHub SSH"
    gitlab:
      work:
        - name: gitlab_work
          vault_path: "op://Work/GitLab SSH"
```

## Usage

### Deploy All SSH Keys

```bash
dotfiles -t ssh
```

### Verify Installation

```bash
# Check SSH client version
ssh -V

# List deployed keys
ls -la ~/.ssh/

# Test GitHub connection
ssh -T git@github.com

# List keys in SSH agent (if using 1Password agent)
ssh-add -l
```

### Uninstall

```bash
dotfiles --uninstall ssh
```

The uninstall script will:
- List all deployed SSH keys
- Prompt for confirmation before removal
- Remove keys from SSH agent (if running)
- Preserve your `.ssh` directory and configuration
- Clean up managed SSH config entries (if any)

## Security Features

### Permission Management
- `.ssh` directory: `0700` (owner full access only)
- Private keys: `0600` (owner read/write only)
- Public keys: `0644` (owner read/write, group/other read)

### Secret Protection
- No keys stored in repository
- All 1Password operations use `no_log: true`
- Keys retrieved only during deployment
- OpenSSH format enforced for compatibility

### Key Rotation Workflow

1. Update keys in 1Password vault
2. Run `dotfiles -t ssh` to deploy new keys
3. Test SSH connections to ensure functionality
4. Remove old keys from remote systems (GitHub, GitLab, servers)

## Troubleshooting

### 1Password Not Authenticated

```bash
# Check 1Password status
op account list

# Sign in
op signin

# Verify vault access
op item list --vault "Personal"
```

### Wrong File Permissions

```bash
# Fix SSH directory permissions
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_*
chmod 644 ~/.ssh/*.pub
```

### Keys Not Loading in SSH Agent

```bash
# Add key manually
ssh-add ~/.ssh/id_ed25519

# List loaded keys
ssh-add -l

# Test connection with verbose output
ssh -T git@github.com -v
```

### Missing SSH Keys After Deployment

```bash
# Run with verbose output
dotfiles -t ssh -vvv

# Check 1Password vault structure
op item get "TechDufus SSH" --vault "Personal"

# Verify vault path in group_vars/all.yml
```

## Integration Points

### Git Role
- SSH keys used for Git authentication
- Multiple keys support different Git accounts
- Commit verification with SSH signatures

### 1Password Role
- Requires 1Password CLI installation
- Depends on active 1Password session
- SSH agent configuration (macOS)

### Shell Configuration
- `SSH_AUTH_SOCK` exported in shell configs (macOS with 1Password agent)
- Environment variables affect SSH behavior

## Best Practices

- **Use Ed25519 Keys** - More secure and performant than RSA
- **Rotate Keys Regularly** - Update keys in 1Password and redeploy
- **Test Before Production** - Verify key deployment on test systems
- **Separate Keys by Purpose** - Different keys for work, personal, and projects
- **Monitor SSH Agent** - Check which keys are loaded with `ssh-add -l`
- **Backup Strategy** - 1Password vaults are backed up automatically

## Future Enhancements

- **SSH Config Management** - Template-based SSH client configuration (currently commented out)
- **Known Hosts Management** - Automated `known_hosts` updates
- **Connection Testing** - Automated validation of deployed keys
- **Arch Linux Support** - Add `Archlinux.yml` task file
- **Multi-Platform SSH Agent** - Better Linux SSH agent integration

## Official Documentation

- [OpenSSH Manual](https://www.openssh.com/manual.html)
- [1Password SSH Agent](https://developer.1password.com/docs/ssh/)
- [GitHub SSH Keys](https://docs.github.com/en/authentication/connecting-to-github-with-ssh)
- [SSH Best Practices](https://www.ssh.com/academy/ssh/config)

---

**Related Roles:** `1password`, `git`, `zsh`
