# System Role - CLAUDE.md

This file provides guidance to Claude Code when working with the system role in this Ansible-based dotfiles repository.

## Role Overview and Purpose

The **system** role handles fundamental system-level configurations, package management, and OS optimizations across all supported platforms (macOS, Ubuntu, Fedora, Arch Linux). It establishes the foundation for other roles by installing essential system utilities, configuring sudo access, and applying OS-specific performance tweaks.

**Core Responsibilities:**
- Install essential system utilities (jq, iSCSI tools, compression utilities)
- Configure passwordless sudo for seamless automation
- Apply OS-specific performance optimizations and system tuning
- Handle WSL-specific requirements (win32yank clipboard integration)
- Provide graceful degradation when running without sudo privileges
- Maintain system cleanliness through automated maintenance tasks

## Architecture and File Structure

```
roles/system/
├── tasks/
│   ├── main.yml                     # OS detection and role entry point
│   ├── MacOSX.yml                   # macOS-specific tasks
│   ├── Ubuntu.yml                   # Ubuntu/Debian tasks + WSL support
│   ├── Fedora.yml                   # Fedora/RHEL comprehensive system tuning
│   ├── Archlinux.yml               # Arch Linux package installation
│   └── hosts-management-archive.yml # ARCHIVED: deprecated hosts management
├── templates/
│   ├── user-sudo.j2                # Sudo configuration template
│   └── hosts.j2                     # DEPRECATED: hosts file template
├── handlers/
│   └── main.yml                     # System service restart handlers
├── uninstall.sh                    # Role cleanup and removal script
└── TODO.md                         # Known issues and improvement plans
```

## OS-Specific Package Management

### macOS (MacOSX.yml)
- **Package Manager**: Homebrew
- **Key Features**:
  - Updates and upgrades all Homebrew packages
  - Installs minimal essential utilities (jq)
  - Configures passwordless sudo via `/private/etc/sudoers.d/`
- **Packages**: jq
- **Special Considerations**: Uses macOS-specific sudoers path

### Ubuntu (Ubuntu.yml)
- **Package Manager**: APT
- **Key Features**:
  - Full system update with autoremove and autoclean
  - WSL-specific win32yank installation for clipboard integration
  - Comprehensive package installation for system utilities
- **Packages**: jq, open-iscsi
- **WSL Integration**:
  - Detects WSL environment via `ansible_host_environment_is_wsl`
  - Downloads and installs win32yank.exe v0.0.4 for clipboard sharing
  - Handles file placement in `/usr/local/bin/` with proper cleanup

### Fedora (Fedora.yml) - Most Comprehensive
This is the most feature-rich implementation with extensive system tuning:

#### DNF Performance Optimizations
```yaml
max_parallel_downloads: 10      # Faster package downloads
fastestmirror: True            # Automatically select fastest mirrors
deltarpm: True                 # Use delta RPMs to save bandwidth
install_weak_deps: False       # Skip recommended packages
clean_requirements_on_remove: True  # Clean dependencies on removal
```

#### System Performance Tweaks
- **Swappiness**: Set to 10 (reduces swap usage for better performance)
- **Journal Size**: Limited to 500MB to prevent log disk bloat
- **Service Optimization**: Disables unnecessary services (ModemManager)
- **ZRAM Configuration**: Compressed memory swap using zstd algorithm

#### Automatic Maintenance
- **DNF Automatic**: Configured for security updates only
- **Cleanup Script**: Weekly automated system cleanup
  - Cleans DNF cache
  - Removes old kernels (keeps last 2)
  - Purges old journal entries (>7 days)
  - Cleans temporary files
  - Updates mlocate database
- **Scheduled Maintenance**: Runs every Sunday at 3 AM

#### Advanced Memory Management
```yaml
[zram0]
zram-size = min(ram / 2, 4096)  # Use half RAM or 4GB max
compression-algorithm = zstd     # Best compression ratio
```

#### Packages
- jq, iscsi-initiator-utils, dnf-automatic, dnf-plugins-core
- util-linux, cronie, mlocate, zram-generator

### Arch Linux (Archlinux.yml)
- **Package Manager**: Pacman
- **Key Features**:
  - System update with latest packages
  - Minimal essential package installation
- **Packages**: jq, open-iscsi, unzip
- **Philosophy**: Follows Arch's minimalist approach

## Sudo Configuration and Security

### Passwordless Sudo Setup
All platforms configure passwordless sudo using the `user-sudo.j2` template:

```bash
{{ ansible_env['USER'] }} ALL=(ALL) NOPASSWD: ALL
```

### Security Considerations
- **File Permissions**: Sudoers files are set to mode `0440` (read-only for owner/group)
- **Validation**: Fedora implementation includes `validate: 'visudo -cf %s'` for syntax checking
- **User-Specific**: Each user gets their own sudoers file in `/etc/sudoers.d/`
- **Reversible**: Uninstall script properly removes sudo configurations

### Platform-Specific Paths
- **macOS**: `/private/etc/sudoers.d/{{ user }}`
- **Linux**: `/etc/sudoers.d/{{ user }}`

## WSL-Specific Features

### win32yank Clipboard Integration
Essential for Neovim clipboard functionality in WSL:

```yaml
# Download process
url: https://github.com/equalsraf/win32yank/releases/download/v0.0.4/win32yank-x64.zip
destination: /usr/local/bin/win32yank.exe (with sudo) or ~/.local/bin/ (without)
```

### WSL Detection
Uses `ansible_host_environment_is_wsl` variable to detect WSL environment and apply WSL-specific configurations.

## System-Level Optimizations and Performance Tuning

### Fedora-Specific Optimizations
The Fedora implementation serves as the template for comprehensive system tuning:

1. **Package Manager Performance**:
   - Parallel downloads for faster updates
   - Fastest mirror selection
   - Delta RPM support for bandwidth savings

2. **Memory Management**:
   - Reduced swappiness (vm.swappiness=10)
   - ZRAM configuration for compressed swap
   - Automatic memory cleanup

3. **Storage Management**:
   - Journal size limits to prevent disk bloat
   - Automatic cleanup of old kernels and temporary files
   - Controlled package cache management

4. **Service Optimization**:
   - Disables unnecessary services (ModemManager)
   - Enables essential services (crond, dnf-automatic)

## Graceful Degradation Without Sudo

The system role is designed to work even when sudo access is unavailable:

### Detection Mechanism
```yaml
when: can_install_packages | default(false)
```

### Fallback Behaviors
- **Package Installation**: Reports missing packages instead of failing
- **WSL Tools**: Installs to `~/.local/bin/` instead of system directories
- **System Tweaks**: Skips privileged operations gracefully
- **Status Reporting**: Clearly indicates what was skipped vs. completed

### User Guidance
Provides helpful messages about missing packages and suggests contacting system administrators.

## Hosts File Management (DEPRECATED)

### Current Status: ARCHIVED
The hosts file management feature has been disabled and archived due to several critical issues:

### Known Issues (from TODO.md)
1. **Hardcoded 1Password vault paths** specific to personal use
2. **Repetitive code** for each host entry
3. **No error handling** for missing 1Password entries
4. **WSL handling is too simplistic**
5. **Overwrites entire /etc/hosts file** (dangerous!)

### Archived Implementation
- **Template**: `templates/hosts.j2` - basic hosts file template
- **Archive**: `tasks/hosts-management-archive.yml` - original problematic code
- **Issues**: Hardcoded vault references, no dynamic host management

### Proposed Refactor (TODO)
```yaml
# Better approach using blockinfile:
system_custom_hosts:
  - name: "myapp.local"
    ip: "127.0.0.1"
  - name: "database.local"
    ip: "192.168.1.100"
    source: "op://vault/item/field"  # Optional 1Password source

- name: "System | Manage custom hosts entries"
  ansible.builtin.blockinfile:
    path: /etc/hosts
    marker: "# {mark} ANSIBLE MANAGED CUSTOM HOSTS"
    block: |
      {% for host in system_custom_hosts %}
      {{ host.ip }} {{ host.name }}
      {% endfor %}
```

### Action Items
- [ ] Create separate `hosts` role or submodule
- [ ] Support multiple host sources (static, 1Password, files)
- [ ] Use blockinfile to preserve system entries
- [ ] Add host validation and error handling
- [ ] Better WSL detection and handling
- [ ] Make 1Password integration optional

## System Service Handlers

### Available Handlers
```yaml
- name: restart systemd-journald    # Restart journal service after config changes
- name: restart systemd-zram-setup@zram0  # Restart ZRAM after configuration
```

### Usage Pattern
```yaml
notify: restart systemd-journald
```

Used primarily by Fedora tasks when modifying system service configurations.

## Common System Utilities Installation

### Cross-Platform Essentials
- **jq**: JSON processor for CLI operations and other roles
- **iSCSI tools**: Storage connectivity (open-iscsi/iscsi-initiator-utils)
- **Compression tools**: unzip (Arch), built into other package managers

### Platform-Specific Additions
- **Fedora**: dnf-automatic, dnf-plugins-core, util-linux, cronie, mlocate, zram-generator
- **Ubuntu**: WSL-specific win32yank for clipboard integration
- **macOS**: Minimal approach with Homebrew management
- **Arch**: Follows minimalist philosophy

## Performance Tuning Details

### Memory Management
```bash
# Swappiness reduction (Fedora)
vm.swappiness=10  # Prefer RAM over swap

# ZRAM configuration
zram-size = min(ram / 2, 4096)  # Compressed swap
compression-algorithm = zstd     # Best ratio
```

### Storage Optimization
```bash
# Journal size management
SystemMaxUse=500M  # Limit systemd journal size

# Automatic cleanup targets
- DNF cache and old packages
- Kernel versions (keep last 2)
- Journal entries older than 7 days
- Temporary files older than 10 days
```

### Network and Package Management
```bash
# DNF optimizations (Fedora)
max_parallel_downloads=10
fastestmirror=True
install_weak_deps=False
```

## Security Hardening Considerations

### Sudo Configuration Security
- Uses separate files in `/etc/sudoers.d/` for easy management
- Proper file permissions (0440)
- Syntax validation on Fedora
- Reversible configuration for uninstallation

### System Service Management
- Disables unnecessary services (ModemManager)
- Enables security update automation (dnf-automatic)
- Controlled service restart through handlers

### Update Management
- **Fedora**: Automated security updates only
- **Ubuntu**: Full system updates with cleanup
- **macOS**: Homebrew update and upgrade
- **Arch**: System-wide package updates

### Package Validation
- Uses official package repositories only
- WSL tools downloaded from GitHub releases (verified sources)
- Proper checksum validation through package managers

## Known Issues and TODOs

### High Priority Issues
1. **Hosts Management Refactor** (Status: Archived)
   - Current implementation is dangerous and hardcoded
   - Needs complete redesign with blockinfile approach
   - Should be moved to separate role

### Medium Priority Improvements
2. **Cross-Platform Performance Tuning**
   - Apply Fedora's comprehensive optimizations to other platforms
   - Standardize swappiness and memory management
   - Add macOS-specific performance tweaks

3. **WSL Integration Enhancement**
   - Better WSL detection mechanisms
   - Windows username detection improvements
   - Enhanced clipboard integration

### Low Priority Enhancements
4. **Package Management Standardization**
   - Unified package list across platforms
   - Better handling of platform-specific packages
   - Improved error handling for missing packages

## Troubleshooting Tips

### Common Issues

#### "Permission Denied" Errors
- **Symptom**: Tasks fail with permission denied
- **Solution**: Ensure `can_install_packages` is true or run with sudo
- **Check**: `ansible-playbook main.yml -e "can_install_packages=true"`

#### WSL win32yank Not Working
- **Symptom**: Clipboard operations fail in WSL
- **Check**: Verify `/usr/local/bin/win32yank.exe` exists and is executable
- **Solution**: Re-run system role: `dotfiles -t system`

#### Sudo Configuration Not Applied
- **Symptom**: Still prompted for passwords
- **Check**: Verify sudoers file exists: `ls -la /etc/sudoers.d/`
- **Solution**: Check file permissions and syntax

#### DNF Performance Issues (Fedora)
- **Symptom**: Slow package operations
- **Check**: Verify `/etc/dnf/dnf.conf` has optimizations applied
- **Solution**: Re-run system role to apply DNF tweaks

#### System Services Not Starting
- **Symptom**: Services fail to start after configuration
- **Check**: `systemctl status <service-name>`
- **Solution**: Check handler execution and service dependencies

### Debugging Commands

```bash
# Check system role status
dotfiles -t system -vvv

# Verify sudo configuration
sudo visudo -c -f /etc/sudoers.d/$USER

# Check WSL environment detection
ansible localhost -m setup | grep wsl

# Verify installed packages
# Fedora: dnf list installed | grep -E "(jq|iscsi)"
# Ubuntu: dpkg -l | grep -E "(jq|open-iscsi)"
# macOS: brew list | grep jq

# Check system performance settings (Fedora)
cat /proc/sys/vm/swappiness
systemctl status dnf-automatic.timer
```

## Development Guidelines

### Adding New System Utilities
1. **Add to all OS-specific files** or use conditional installation
2. **Consider sudo requirements** and provide fallback behavior
3. **Test on target platforms** to ensure compatibility
4. **Update uninstall script** if package creates system-wide changes

### Performance Optimization Guidelines
1. **Start with Fedora implementation** as the comprehensive template
2. **Test impact** of each optimization on system stability
3. **Provide rollback mechanism** through proper service handlers
4. **Document rationale** for each performance tweak

### Security Best Practices
1. **Never store secrets** in role files
2. **Use proper file permissions** for sensitive configurations
3. **Validate sudo configurations** before applying
4. **Provide secure defaults** that can be customized

### Cross-Platform Considerations
1. **Test on all supported OS** before merging changes
2. **Handle package name differences** gracefully
3. **Account for service name variations** across platforms
4. **Consider filesystem path differences** (macOS vs Linux)

### Error Handling Patterns
```yaml
# For optional operations
failed_when: false
changed_when: false

# For critical operations with fallback
block:
  - name: "Try privileged operation"
rescue:
  - name: "Fallback operation"
```

This comprehensive system role serves as the foundation for all other dotfiles roles, ensuring a properly configured and optimized system environment across all supported platforms.