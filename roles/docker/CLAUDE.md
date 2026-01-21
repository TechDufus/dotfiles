# Docker Role

Installs Docker Engine with custom daemon configuration for network pools and user-space data storage.

## Key Files
- `/etc/docker/daemon.json` - Custom daemon config (from `templates/daemon.json`)
- `~/.local/lib/docker` - Docker data directory (user-space, not system)
- `handlers/main.yml` - `restart_docker` handler for config changes

## Patterns
- **Custom network pools**: Uses `172.18.0.0/16` range to avoid corporate/home network conflicts
- **User-space data-root**: Docker data stored in `~/.local/lib/docker` for easier backup
- **BuildKit enabled**: Experimental features and BuildKit enabled by default
- **Group management**: Adds user to `docker` group on Linux (requires logout/login)

## Integration
- **podman**: Alternative runtime with Docker compatibility alias
- **Shell aliases**: `dprune` and `dsysprune` defined in `zsh/files/zsh/docker_aliases.zsh`
- **kind/whalebrew**: Other container-related roles depend on Docker

## Daemon Configuration
```json
{
  "default-address-pools": [{"base": "172.18.0.0/16", "size": 24}],
  "data-root": "~/.local/lib/docker",
  "experimental": true,
  "features": {"buildkit": true}
}
```

## Gotchas
- **macOS is CLI-only**: Homebrew installs CLI, not Docker Desktop (no daemon management)
- **WSL skips service management**: Service tasks have `when: not ansible_host_environment_is_wsl`
- **Group changes need re-login**: Docker group membership requires logout/login or `newgrp docker`
- **Sudo required on Linux**: Full Docker Engine install needs sudo; provides Podman fallback message
- **Optional role**: Commented out in `default_roles` - must be explicitly enabled
- **Data directory permissions**: `~/.local/lib/docker` created with mode 0710
