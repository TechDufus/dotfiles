# SSH Role

Deploys SSH keys from 1Password vaults with proper permissions and security handling.

## Key Files
- `~/.ssh/` - SSH directory (mode 0700)
- `~/.ssh/<keyname>` - Private keys (mode 0600)
- `~/.ssh/<keyname>.pub` - Public keys (mode 0644)
- `group_vars/all.yml` - `op.ssh` configuration for key paths

## Patterns
- **1Password key retrieval**: Uses `op read` with `?ssh-format=openssh` for private keys
- **No logging**: All sensitive operations use `no_log: true` to prevent secrets in logs
- **Hierarchical config**: Keys organized as `op.ssh.<service>.<account>` in group_vars

## Configuration Structure
```yaml
# group_vars/all.yml
op:
  ssh:
    github:
      techdufus:
        - name: id_ed25519
          vault_path: "op://Personal/TechDufus SSH"
```

## Integration
- **1Password role**: Requires 1Password CLI installed and authenticated
- **Git role**: SSH keys used for Git authentication and commit signing
- **1Password SSH Agent**: macOS uses `~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock`

## Gotchas
- **Requires 1Password auth**: Role skips silently if `op` not authenticated
- **SSH config commented out**: Template system ready but `config.j2` task disabled in main.yml
- **Key names matter**: `item.name` becomes both filename and `.pub` suffix
- **No config management yet**: Only deploys keys, not `~/.ssh/config`
- **WSL permissions**: May need special handling for Windows/Linux path translation
