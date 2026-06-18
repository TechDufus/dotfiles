# 📦 Flatpak Role

Universal Linux application management with Flatpak - runtime setup plus Ubuntu desktop applications from Flathub.

## Overview

This Ansible role sets up Flatpak on Linux systems. Ubuntu uses it for a curated desktop app set when a graphical environment is detected. Archlinux/CachyOS only installs the Flatpak runtime and Flathub remote when the role is explicitly tagged; Arch desktop apps should prefer native pacman role installs, with Flatpak as an optional fallback.

## Supported Platforms

- **Ubuntu** - runtime, Flathub, and desktop apps when graphical
- **Archlinux/CachyOS** - runtime and Flathub only, explicit tag required

## What Gets Installed

### System Packages
- **flatpak** - Universal Linux application sandboxing and distribution framework

### Flathub Remote
- Configures the official [Flathub](https://flathub.org) repository

### Desktop Applications

On Ubuntu with a graphical desktop environment, the following applications are installed:

| Application | Flatpak ID | Description |
|------------|------------|-------------|
| **Brave Browser** | `com.brave.Browser` | Privacy-focused web browser |
| **Discord** | `com.discordapp.Discord` | Voice, video, and text communication |
| **Spotify** | `com.spotify.Client` | Music streaming service |
| **Obsidian** | `md.obsidian.Obsidian` | Markdown-based knowledge base |
| **Steam** | `com.valvesoftware.Steam` | Gaming platform |

## Features

### 🎯 Smart Desktop Detection

On Ubuntu, the role uses systemd to detect whether the system is running a graphical desktop environment:

```mermaid
flowchart TD
    A[Start Flatpak Role] --> B{Check systemd target}
    B -->|graphical.target| C{Is WSL?}
    B -->|other target| D[Skip Desktop Apps]
    C -->|No| E[Install Desktop Apps]
    C -->|Yes| D
    E --> F[End]
    D --> F
```

- Ubuntu checks if `systemctl get-default` returns `graphical.target`
- Ubuntu skips desktop applications on headless servers
- Ubuntu skips desktop applications in WSL environments
- Archlinux/CachyOS does not install desktop applications from Flatpak

### 🔒 Sandboxed Applications

Ubuntu Flatpak desktop applications run in containerized environments with:
- Isolated filesystem access
- Controlled system permissions
- Consistent runtime dependencies

### 🔄 Idempotent Installation

- Safe to run multiple times
- Only installs missing packages
- Updates existing Flathub remote configuration

## What Gets Configured

### Flathub Remote Repository
- **URL**: `https://flathub.org/repo/flathub.flatpakrepo`
- **Name**: `flathub`
- **Scope**: System-wide

### Desktop Integration
- Ubuntu Flatpak applications appear in system application menus
- Desktop files integrate with the desktop environment
- Icon themes are registered by Flatpak

## Dependencies

### Ansible Collections
- `community.general` (for `flatpak` and `flatpak_remote` modules)

### System Requirements
- Linux distribution with a supported task file
- Graphical desktop environment (Ubuntu desktop apps only)
- Internet connection for Flathub

## Usage

### Install with specific tag
```bash
dotfiles -t flatpak
```

### Install as part of default roles
On Ubuntu, the role is included in `default_roles` and runs automatically with:
```bash
dotfiles
```

On Archlinux/CachyOS, the role is excluded from default runs. Use `dotfiles -t flatpak` only when you want the Flatpak runtime and Flathub remote.

### Skip desktop applications
Archlinux/CachyOS always skips Flatpak desktop application installs. On Ubuntu, run on a headless system or WSL to skip them automatically.

## Architecture

```mermaid
graph LR
    A[Flatpak Role] --> B{Distribution}
    B -->|Ubuntu| C[Install Flatpak]
    B -->|Archlinux/CachyOS tagged| D[Install Flatpak]
    C --> E[Configure Flathub]
    D --> E
    E --> F{Ubuntu Desktop?}
    F -->|Yes| G[Install Ubuntu Desktop Apps]
    F -->|No or Archlinux/CachyOS| H[Skip Apps]
    G --> I[Brave Browser]
    G --> J[Discord]
    G --> K[Spotify]
    G --> L[Obsidian]
    G --> M[Steam]
```

## Key Implementation Details

### Environment Detection Logic
Ubuntu desktop app installation uses:

```yaml
# Checks systemd default target
systemctl get-default  # Returns: graphical.target or multi-user.target

# Combines with WSL detection
flatpak_is_desktop: "{{ flatpak_systemd_target.stdout == 'graphical.target' and not ansible_host_environment_is_wsl }}"
```

### Application Installation Pattern
- Ubuntu desktop apps use the `community.general.flatpak` module
- Installs from `flathub` remote
- Loops through the Ubuntu application list
- Requires `become: true` for system-wide installation

## Customization

To modify the Ubuntu Flatpak desktop application list, edit `roles/flatpak/tasks/Ubuntu.yml`:

```yaml
- name: "Flatpak | Install desktop applications"
  community.general.flatpak:
    name: "{{ item }}"
    state: present
    remote: flathub
  loop:
    - com.your.Application  # Add your Flatpak ID here
  when: flatpak_is_desktop
  become: true
```

Browse available applications at [Flathub.org](https://flathub.org).

## Troubleshooting

### Applications not installing
- Ubuntu only: verify you're running a graphical desktop with `systemctl get-default`
- Check Flathub is accessible: `flatpak remote-list`
- Manually test: `flatpak install flathub com.brave.Browser`

### Permission issues
- Ensure role runs with `become: true`
- Check user is in required groups: `groups $USER`

### WSL limitations
- Ubuntu desktop apps are intentionally skipped in WSL
- Use native Windows apps or WSLg instead

## Links

- [Flatpak Official Site](https://flatpak.org/)
- [Flathub Application Repository](https://flathub.org/)
- [Flatpak Documentation](https://docs.flatpak.org/)
- [Ansible community.general.flatpak module](https://docs.ansible.com/ansible/latest/collections/community/general/flatpak_module.html)

## Role Structure

```
roles/flatpak/
├── README.md          # This file
└── tasks/
    ├── Archlinux.yml  # Arch runtime and Flathub only
    └── Ubuntu.yml     # Ubuntu runtime, Flathub, and desktop apps
```
