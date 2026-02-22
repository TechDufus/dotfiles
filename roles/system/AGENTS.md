# System Role

Installs essential system utilities (jq, iSCSI), configures passwordless sudo, and applies OS-specific performance optimizations.

## Key Files
- `/etc/sudoers.d/{{ user }}` - Passwordless sudo config (Linux)
- `/private/etc/sudoers.d/{{ user }}` - Passwordless sudo config (macOS)
- `/etc/dnf/dnf.conf` - Fedora package manager optimizations
- `templates/user-sudo.j2` - Sudo template source

## Patterns

### Fedora Has Most Features
Fedora implementation is the most comprehensive:
- DNF parallel downloads (10), fastest mirror, delta RPMs
- Swappiness reduced to 10
- ZRAM with zstd compression
- Automated weekly cleanup (kernels, journals, temp files)
- DNF automatic security updates

Other platforms have minimal implementations.

### WSL Clipboard Integration
Ubuntu detects WSL via `ansible_host_environment_is_wsl` and installs win32yank:
- Downloads to `/usr/local/bin/win32yank.exe` (with sudo)
- Falls back to `~/.local/bin/` without sudo
- Required for Neovim clipboard in WSL

### Graceful Sudo Fallback
Uses `can_install_packages` variable to skip privileged operations:
- Package installs skipped with helpful message
- User-local alternatives used when possible

## Integration
- **Foundation role**: Should run early; other roles depend on jq and sudo
- **Used by**: Neovim role (WSL clipboard via win32yank)

## Gotchas
- Hosts management is DEPRECATED (archived in `hosts-management-archive.yml`)
- Previous hosts implementation overwrote entire `/etc/hosts` - dangerous
- Fedora validates sudoers with `visudo -cf`; other platforms do not
- Never uninstalls system packages like git or python
