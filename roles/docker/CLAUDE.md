# Docker Role - CLAUDE.md

This file provides guidance to Claude Code when working with the Docker role in this dotfiles repository.

## Role Overview

The Docker role provides cross-platform Docker installation and configuration for containerized application development. It handles the complexities of Docker installation across different operating systems while maintaining secure defaults and user-friendly configurations.

**Key Features:**
- Cross-platform Docker Engine installation (macOS via Homebrew, Ubuntu via official repository)
- Intelligent sudo requirement detection with graceful fallback
- Custom daemon configuration with optimized settings
- User permission management (docker group)
- Complete uninstallation support
- Integration with shell aliases for common Docker operations

## Architecture and Installation Methods

### macOS Installation
- **Method**: Homebrew CLI tool installation
- **Package**: `docker` (CLI only via Homebrew)
- **Service Management**: Not applicable (Docker Desktop handles daemon)
- **User Group**: Not managed (Docker Desktop handles permissions)

### Ubuntu Installation
- **Method**: Official Docker repository with GPG key verification
- **Packages**:
  - `docker-ce` - Docker Community Edition
  - `docker-ce-cli` - Docker CLI
  - `containerd.io` - Container runtime
  - `docker-buildx-plugin` - Extended build capabilities
  - `docker-compose-plugin` - Docker Compose v2
- **Service Management**: systemd service enabled and started
- **User Group**: User added to `docker` group for passwordless access

## Docker Daemon Configuration

The role deploys a custom `daemon.json` configuration template to `/etc/docker/daemon.json`:

```json
{
  "default-address-pools": [
    {
      "base": "172.18.0.0/16",
      "size": 24
    }
  ],
  "data-root": "{{ ansible_user_dir }}/.local/lib/docker",
  "experimental": true,
  "features": {
    "buildkit": true
  }
}
```

### Configuration Features

**Network Configuration:**
- Custom default address pools using `172.18.0.0/16` range
- Subnet size of `/24` for each network
- Prevents conflicts with common corporate network ranges

**Storage Configuration:**
- Data root relocated to `~/.local/lib/docker`
- Keeps Docker data in user space rather than system directories
- Simplifies backup and management

**Feature Flags:**
- `experimental: true` - Enables experimental Docker features
- `buildkit: true` - Uses BuildKit as the default builder (faster, more efficient builds)

## Docker Desktop vs Docker Engine Considerations

### macOS Approach
The role takes a **CLI-focused approach** on macOS:
- Installs Docker CLI via Homebrew for command-line operations
- Does NOT install Docker Desktop automatically
- Users can install Docker Desktop separately if GUI is needed
- Commented-out service management tasks (not applicable for CLI-only installation)

### Linux Approach
Full Docker Engine installation:
- Complete Docker daemon installation
- Service management and auto-start configuration
- User permission setup
- Custom daemon configuration deployment

## User Permissions and Docker Group Management

### Ubuntu/Linux Systems
The role handles docker group management automatically:

```yaml
- name: "Docker | Add user to docker group"
  ansible.builtin.user:
    append: true
    groups: docker
    name: "{{ ansible_env['USER'] }}"
  become: true
```

**Important Notes:**
- Group changes require logout/login or `newgrp docker` to take effect
- The role provides user feedback about this requirement
- Group membership allows running Docker commands without `sudo`

### macOS Systems
Docker group management is not needed:
- Docker Desktop handles permission management
- CLI operations work with user credentials

## Sudo Access Detection and Graceful Fallback

The Ubuntu installation includes intelligent sudo detection:

```yaml
- name: "Docker | {{ ansible_distribution }} | Check sudo availability"
  ansible.builtin.debug:
    msg:
      - "⚠️  DOCKER INSTALLATION REQUIREMENTS:"
      - "- Sudo access: {{ 'Available ✓' if has_sudo | default(false) else 'NOT AVAILABLE ✗' }}"
```

### Fallback Options When Sudo Unavailable
The role provides helpful alternatives:
1. **Podman** - Rootless container alternative
2. **System Administrator** - Request Docker installation
3. **Docker Desktop** - GUI alternative (where available)
4. **Cloud Development** - Use cloud-based environments

## WSL (Windows Subsystem for Linux) Support

Special handling for WSL environments:

```yaml
when: not ansible_host_environment_is_wsl
```

- Service management is skipped in WSL
- Docker daemon typically runs through Docker Desktop on Windows host
- Service handlers include WSL detection to prevent unnecessary operations

## Integration with Container Orchestration Tools

The role integrates well with other container-related roles in the dotfiles:

### Related Roles
- **podman** - Alternative container runtime (includes Docker compatibility alias)
- **kind** - Kubernetes in Docker for local testing
- **whalebrew** - Package manager using Docker images
- **orbstack** - Docker Desktop alternative for macOS

### Shell Integration
Docker aliases are provided through shell roles:

**Available Aliases:**
- `dprune` - Remove dangling Docker images: `docker rmi $(docker images --filter "dangling=true" -q --no-trunc)`
- `dsysprune` - Comprehensive system cleanup: `docker system prune -af`

**Alias Files:**
- `/home/techdufus/.dotfiles/roles/zsh/files/zsh/docker_aliases.zsh`
- `/home/techdufus/.dotfiles/roles/bash/files/bash/docker_aliases.sh`

## Storage Driver Configuration

The role configures Docker to use user-space storage:

```yaml
- name: "Docker | Ensure docker data directory exists"
  ansible.builtin.file:
    path: "{{ ansible_user_dir }}/.local/lib/docker"
    state: directory
    mode: "0710"
```

**Benefits:**
- User-owned Docker data directory
- Easier backup and migration
- Avoids permission issues with system directories
- Cleaner uninstallation process

## Network Configuration Best Practices

Custom network pools prevent common conflicts:

**Default Pools:**
- Base: `172.18.0.0/16`
- Size: `/24` subnets
- Total available: 256 subnets with 254 hosts each

**Why This Range:**
- Avoids `10.0.0.0/8` (common in corporate networks)
- Avoids `192.168.0.0/16` (common in home networks)
- Uses RFC 1918 private range
- Provides ample subnet space for complex applications

## Service Management and Handlers

### Service Handler
```yaml
- name: restart_docker
  ansible.builtin.service:
    name: docker
    state: restarted
  become: true
  when: not ansible_host_environment_is_wsl
```

**Triggered by:**
- Changes to `/etc/docker/daemon.json`
- Docker configuration updates

**WSL Considerations:**
- Service restart skipped in WSL environments
- Docker Desktop on Windows handles service management

## Troubleshooting Guide

### Common Installation Issues

**Permission Denied Errors:**
```bash
# Check if user is in docker group
groups $USER | grep docker

# If not in group, run:
sudo usermod -aG docker $USER
newgrp docker  # Or logout/login
```

**Service Won't Start:**
```bash
# Check service status
sudo systemctl status docker

# Check journal logs
sudo journalctl -u docker

# Verify daemon.json syntax
sudo dockerd --validate
```

**WSL-Specific Issues:**
- Ensure Docker Desktop is running on Windows
- Check WSL integration is enabled in Docker Desktop
- Verify Docker Desktop WSL backend is configured

### Network Conflicts
If custom address pools conflict with existing networks:
1. Edit `templates/daemon.json` to use different range
2. Restart Docker service
3. Recreate affected containers/networks

### Storage Issues
If data directory permissions cause problems:
```bash
# Fix ownership
sudo chown -R $USER:$USER ~/.local/lib/docker

# Fix permissions
chmod -R 750 ~/.local/lib/docker
```

## Development Guidelines

### Adding New OS Support
To add support for additional Linux distributions:

1. Create new task file: `tasks/NewDistribution.yml`
2. Follow the existing pattern with sudo detection
3. Use distribution-specific package manager
4. Update uninstall script with new distribution support

### Modifying Docker Configuration
To change daemon configuration:

1. Edit `templates/daemon.json`
2. Test changes with: `sudo dockerd --validate --config-file=/etc/docker/daemon.json`
3. Use handler to restart service: `notify: restart_docker`

### Testing Changes
```bash
# Test role in isolation
dotfiles -t docker

# Check Docker installation
docker --version
docker info

# Verify daemon configuration
sudo cat /etc/docker/daemon.json

# Test Docker functionality
docker run hello-world
```

## Security Considerations

### User Group Management
- Adding users to docker group grants root-equivalent privileges
- Docker group members can mount host filesystem
- Consider using rootless Docker for enhanced security

### Network Security
- Custom address pools reduce network discovery risks
- BuildKit enables more secure build processes
- Experimental features should be evaluated for production use

### Data Directory Security
- User-space data directory reduces system-wide exposure
- Directory permissions set to `0710` (owner read/write/execute, group execute only)
- No world access to Docker data

## Uninstallation Process

The role includes a comprehensive uninstallation script supporting:

### macOS Cleanup
- Stops Docker Desktop application
- Removes Docker Desktop app bundle
- Uninstalls Homebrew Docker CLI
- Cleans user Docker configuration
- Removes Docker Desktop container and preference files

### Linux Cleanup
- Stops and disables Docker service
- Removes Docker packages (distribution-specific)
- Deletes Docker data directories
- Removes docker group
- Cleans user Docker configuration

### Safety Features
- Interactive confirmation before removal
- Data backup warning
- Graceful handling of missing components
- Cross-platform detection and appropriate cleanup

## Role Status and Maintenance

**Current Status:** Optional role (commented in default_roles)
**Maintenance Level:** Active
**OS Support:**
- ✅ macOS (Homebrew CLI)
- ✅ Ubuntu (Full Docker Engine)
- ⚠️  Other Linux distributions (partial support in uninstall script)

**Dependencies:**
- Homebrew (macOS)
- sudo access (Linux)
- Internet connectivity for repository setup

The Docker role provides a solid foundation for containerized development workflows while maintaining security best practices and cross-platform compatibility.