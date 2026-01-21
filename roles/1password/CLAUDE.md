# 1Password Role

Installs 1Password CLI and configures SSH agent for centralized secret management across the dotfiles system.

## Key Files

- `~/.config/1Password/ssh/agent.toml` - SSH agent vault configuration
- `files/agent.toml` - Source agent config
- `tasks/MacOSX.yml` - Homebrew cask install
- `tasks/Ubuntu.yml` - APT with GPG verification

## Patterns

- **op:// URL Format**: Secrets referenced as `op://vault/item/field` in `group_vars/all.yml`
- **Graceful Degradation**: All roles check `op_installed` fact before 1Password operations
- **no_log Required**: Always use `no_log: true` for secret retrieval tasks
- **failed_when: false**: Optional secrets should not fail the playbook

## Integration

- **Used by**: git role for user.email and allowed_signers
- **Used by**: ssh role for private/public key deployment
- **Used by**: zsh role for runtime secrets (API keys via `vars.secret_functions.zsh`)

## Secret Reference Pattern

```yaml
# In group_vars/all.yml
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
```

## Gotchas

- **Role Disabled by Default**: Commented out in `group_vars/all.yml` - enable with `dotfiles -t 1password`
- **Authentication Required**: Must run `op signin my.1password.com` before roles that need secrets
- **Multi-Vault SSH**: `agent.toml` configures which vaults provide SSH keys (Personal, Raft, StarSage)
- **Ubuntu GPG Setup**: Uses dedicated keyring at `/usr/share/keyrings/1password-archive-keyring.gpg`
- **Test Agent**: Verify SSH keys with `ssh-add -l` after setup
