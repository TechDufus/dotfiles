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
| `op_account` | No | 1Password CLI account, default `my.1password.com` |
| `op.git.user.email` | Yes | 1Password path to your email |

```yaml
git_user_name: "Your Name"

op_account: my.1password.com

op:
  git:
    user:
      email: "op://Personal/GitHub/email"
```

### Role Selection

| Variable | Description |
|----------|-------------|
| `default_roles` | Shared role list used by `dotfiles` / `--tags all` |
| `exclude_roles_by_session` | Per-desktop-session roles dropped from every run, including explicit tags |
| `exclude_roles_by_distribution` | Per-distribution roles pruned from default runs only |

```yaml
default_roles:
  - system
  - git
  - neovim
  - zsh
  - tmux
  - plasma
  - omarchy
exclude_roles_by_session:
  omarchy:
    - plasma
    - tldr
    - neofetch
  default:
    - omarchy
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

`exclude_roles_by_session` is keyed by `dotfiles_session`, which
`pre_tasks/detect_omarchy.yml` sets to `omarchy` when Omarchy markers
(`/usr/bin/omarchy`, `/usr/share/omarchy`) exist and `default` otherwise.
Unlike the distribution exclusion, it also drops explicitly tagged roles:
`dotfiles -t plasma` runs nothing on Omarchy, and `dotfiles -t omarchy` runs
nothing on CachyOS or plain Arch.

### Omarchy Desktop Session

Omarchy is treated as a desktop session on top of the normalized `Archlinux`
distribution, not as a separate distribution. On Omarchy, `plasma`, `tldr`, and
`neofetch` are skipped. The btop and opencode configs stay Omarchy-owned (the
`btop` and `opencode` roles skip their config tasks). The `neovim` role skips
the `neovim-git` AUR package, which conflicts with `omarchy-nvim`, and the
`system` role skips `pacman -Syu` because Omarchy's pacman guard blocks it; use
`omarchy update` for system upgrades. The `omarchy` role injects a managed block
into `~/.config/hypr/hyprland.lua` that loads the repo's Lua modules. If
`omarchy refresh hyprland` rewrites that file, rerun `dotfiles -t omarchy` to
restore the block.

The `omarchy` role also writes `~/.config/fcitx5/conf/keyboard.conf` to clear
fcitx5's word-hint hotkeys (`Ctrl+Alt+H`/`Ctrl+Alt+J`) so herdr's
`ctrl+alt+j`/`ctrl+alt+k` agent navigation reaches the terminal. The `system`
role writes `/etc/sudoers.d/$USER` (passwordless sudo) on Arch, including
Omarchy, when sudo credentials are available.

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

These variables are consumed by Linux system/X11 keyboard setup. Plasma desktop
keyboard preferences live in `plasma_desktop_kconfig_settings`.

On Omarchy, Hyprland reads the layout and variant from `/etc/vconsole.conf`,
which the `system` role's `localectl` tasks write. The `omarchy` role builds
Hyprland's `kb_options` from `keyboard.options` plus `omarchy_kb_extra_options`
(`caps:none`, `compose:ralt`, `shift:both_capslock_cancel`). CapsLock is the
summon leader, so Compose moves to Right Alt and both Shifts toggle Caps Lock.

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
| herdr | `roles/herdr/files/config.toml` |
| cursor | `roles/cursor/files/` |
| lfk | `roles/lfk/files/config.yaml` |
| git | `roles/git/files/gitconfig` |
| plasma desktop settings | `roles/plasma/defaults/main.yml` (`plasma_desktop_kconfig_settings`) |
| plasma summon | `roles/plasma/files/kwin/plasma-summon/`, `roles/plasma/files/summon/` |
| plasma summon service | `roles/plasma/files/bin/plasma-summon-service.py`, `roles/plasma/files/systemd/plasma-summon.service` |
| omarchy summon registry | `roles/omarchy/files/hypr/summon_apps.lua` |
| omarchy summon engine | `roles/omarchy/files/hypr/summon.lua` |

The Herdr role copies the entire canonical `roles/herdr/files/config.toml` to `~/.config/herdr/config.toml`; edit the tracked source rather than the live output.

Plasma owns a normal KDE session, stable desktop KConfig preferences in
`plasma_desktop_kconfig_settings`, and a KWin script for the same summon,
region, monitor, and layout workflow. Each KConfig entry is one scalar key with
`file`, ordered
`group_path`, `key`, and exact string `value`; discover new values with
`kreadconfig6`, then add one list item. The summon helper service reads the TOML
registries and launches configured apps over D-Bus; set per-screen default
layouts in `roles/plasma/files/summon/layouts.toml` under `[output_layouts]`
using a connector name, serial, model, or KWin output key. KWin keeps direct
control of windows, including managed app cells for configured layouts. Monitor
wake workarounds are intentionally local-machine state, not dotfiles-managed
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
