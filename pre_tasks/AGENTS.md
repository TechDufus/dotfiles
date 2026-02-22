# pre_tasks/ Directory

Detection tasks that run before any roles execute. All tasks tagged `always`.

## Detection Sequence
1. **WSL Detection**: Sets `ansible_host_environment_is_wsl` (bool)
2. **PowerShell Policy** (WSL only): Configures RemoteSigned execution policy
3. **WSL Host User** (WSL only): Sets `wsl_host_user` from Windows username
4. **Host User**: Sets `host_user` from `$USER` environment variable
5. **Sudo Detection**: Sets privilege escalation facts and package manager
6. **1Password Detection**: Sets `op_installed` (bool)

## Key Variables Set
| Variable | Purpose |
|----------|---------|
| `ansible_host_environment_is_wsl` | True if running in WSL environment |
| `host_user` | Current Unix username |
| `wsl_host_user` | Windows username (WSL only) |
| `has_sudo` | Whether privilege escalation is available |
| `sudo_method` | Method used: `sudo`, `doas`, or `none` |
| `detected_package_manager` | OS package manager: `brew`, `apt`, `dnf`, `pacman`, `yum` |
| `can_install_packages` | Whether package installation is possible |
| `op_installed` | Whether 1Password CLI is available |

## Gotchas
- WSL detection checks `/proc/version` for "microsoft" string
- Sudo detection tests passwordless, cached credentials, then doas/pkexec fallbacks
- macOS with Homebrew sets `can_install_packages: true` without requiring sudo
- 1Password detection only checks if `op` binary exists, not authentication state
