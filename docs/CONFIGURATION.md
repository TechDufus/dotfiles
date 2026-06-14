# Configuration Reference

## Quick Start

```bash
cp group_vars/all.yml.example group_vars/all.yml
nvim group_vars/all.yml
```

## What's Configurable via Ansible

These are the only things you configure in `group_vars/all.yml`:

### Identity

| Variable | Required | Description |
|----------|----------|-------------|
| `git_user_name` | Yes | Your name for git commits |
| `op.git.user.email` | Yes | 1Password path to your email |

```yaml
git_user_name: "Your Name"

op:
  git:
    user:
      email: "op://Personal/GitHub/email"
```

### Role Selection

| Variable | Description |
|----------|-------------|
| `default_roles` | Shared role list used by `dotfiles` / `--tags all` |
| `exclude_roles_by_distribution` | Per-distribution roles pruned from default runs only |

```yaml
default_roles:
  - system
  - git
  - neovim
  - zsh
  - tmux
  - plasma
exclude_roles_by_distribution:
  Archlinux:
    - asciiquarium
    - bash
    - awesomewm
    - vicinae
    - flatpak
    - starship
```

Explicit tags still run even when a role is excluded from a distribution's
default run, for example `dotfiles -t flatpak`.

### Arch/CachyOS Package Source Policy

Arch-family roles use native package sources in this order:

1. `pacman` official repositories first.
2. AUR only when the package is absent from official repositories.
3. Flatpak only as an explicit fallback/runtime role.

CachyOS is normalized to `Archlinux` before role dispatch, so Arch task files
cover both vanilla Arch and CachyOS.

Pacman module calls also inherit these defaults from `group_vars/all.yml`:

```yaml
arch_pacman_extra_args: "--disable-download-timeout"
arch_pacman_update_cache_extra_args: "--disable-download-timeout"
arch_pacman_upgrade_extra_args: "--disable-download-timeout"
```

That avoids false failures from CachyOS mirror stalls on large packages while
still letting pacman verify signatures and package integrity.

### Keyboard

These variables are consumed by Linux system/X11 keyboard setup. Hyprland is a
symlinked Wayland config, so compositor input policy lives in
`roles/hyprland/files/hypr/hyprland.lua`; keep both aligned when changing
layouts.

| Variable | Description |
|----------|-------------|
| `keyboard.model` | XKB keyboard model for Linux console/X11 paths |
| `keyboard.layout` | XKB layout, for example `us` |
| `keyboard.variant` | XKB variant, for example `dvorak` |
| `keyboard.options` | XKB options list, for example `caps:none` |

```yaml
keyboard:
  model: pc105
  layout: us
  variant: dvorak
  options:
    - caps:none
```

### Package Lists

| Variable | Description |
|----------|-------------|
| `go.packages` | Go packages to install |
| `helm.repos` | Helm repositories to add |
| `npm_global_packages` | NPM packages (in `roles/npm/defaults/main.yml`) |
| `bun_global_packages` | Bun packages (in `roles/bun/defaults/main.yml`) |

```yaml
go:
  packages:
    - package: github.com/go-task/task/v3/cmd/task@latest
      cmd: task

helm:
  repos:
    - name: traefik
      url: https://helm.traefik.io/traefik
```

### Versions

| Variable | Default | Description |
|----------|---------|-------------|
| `nvm_node_version` | `"lts/*"` | Node.js version via NVM |
| `k8s.repo.version` | `"v1.34"` | Kubernetes repo version |

## What's NOT Configurable via Ansible

Everything else is configured by editing the actual config files directly:

| Tool | Config Location |
|------|-----------------|
| tmux | `roles/tmux/files/tmux/tmux.conf` |
| neovim | `roles/neovim/files/` |
| zsh | `roles/zsh/files/.zshrc` |
| starship | `roles/starship/files/starship.toml` |
| kitty | `roles/kitty/files/kitty.conf` |
| ghostty | `roles/ghostty/files/config` |
| lfk | `roles/lfk/files/config.yaml` |
| git | `roles/git/files/gitconfig` |
| hyprland | `roles/hyprland/files/hypr/` |
| waybar | `roles/hyprland/files/waybar/` |
| hyprpaper | `roles/hyprland/files/hypr/hyprpaper.conf`, `roles/hyprland/files/wallpapers/` |
| hyprland summon | `roles/hyprland/files/summon/`, `roles/hyprland/files/bin/hypr-summon.py` |
| plasma desktop settings | `roles/plasma/defaults/main.yml` (`plasma_desktop_kconfig_settings`) |
| plasma summon | `roles/plasma/files/kwin/plasma-summon/`, `roles/plasma/files/summon/` |
| plasma summon service | `roles/plasma/files/bin/plasma-summon-service.py`, `roles/plasma/files/systemd/plasma-summon.service` |

Hyprland owns the normal top Waybar panel, summon app registry, percentage-based
regions, and active-monitor layout profiles. Edit those files directly in the
role; the symlinks keep the live desktop aligned with the repository.

Plasma owns a normal KDE session, stable desktop KConfig preferences in
`plasma_desktop_kconfig_settings`, and a KWin script for the same summon,
region, monitor, and layout workflow. Each KConfig entry is one scalar key with
`file`, ordered
`group_path`, `key`, and exact string `value`; discover new values with
`kreadconfig6`, then add one list item. The summon helper service reads the TOML
registries and launches configured apps over D-Bus; KWin keeps direct control of
windows, including managed app cells for configured layouts. Monitor wake
workarounds are intentionally local-machine state, not dotfiles-managed Plasma
role state.
Panel/dock containment IDs, per-screen applet geometry, wallpaper paths, and
system-tray applet ordering are intentionally not blindly copied because those
files contain machine-specific IDs.

This is intentional. Config files are readable, portable, and self-contained. You look at the file and know exactly what it does.

## Commands

```bash
dotfiles                    # Run all default roles
dotfiles -t neovim,git      # Run specific roles
dotfiles --check            # Dry run
dotfiles -e "var=value"     # Override variable
```
