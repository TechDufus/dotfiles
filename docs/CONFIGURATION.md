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
restore the block. Those modules replace Omarchy's tiling default: `cells.lua`
sets `general.layout` to `lua:cells` (a Lua tiling layout driven by
`layouts.lua`), puts laptop panels on Hyprland's monocle layout, and rebinds
`Super+L`, `Super+J`, and `Alt+Tab` so they work with those layouts.

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
| tern | `roles/tern/files/settings.json` |
| cursor | `roles/cursor/files/` |
| lfk | `roles/lfk/files/config.yaml` |
| git | `roles/git/files/gitconfig` |
| plasma desktop settings | `roles/plasma/defaults/main.yml` (`plasma_desktop_kconfig_settings`) |
| plasma summon | `roles/plasma/files/kwin/plasma-summon/`, `roles/plasma/files/summon/` |
| plasma summon service | `roles/plasma/files/bin/plasma-summon-service.py`, `roles/plasma/files/systemd/plasma-summon.service` |
| omarchy summon registry | `roles/omarchy/files/hypr/summon_apps.lua` |
| omarchy summon engine | `roles/omarchy/files/hypr/summon.lua` |

The Herdr role copies the entire canonical `roles/herdr/files/config.toml` to `~/.config/herdr/config.toml`; edit the tracked source rather than the live output.

The Tern role syncs `roles/tern/files/settings.json` both ways instead of symlinking it, because Tern replaces the file when you change a setting in its UI. `dotfiles -t tern` deploys repo edits and reports in-app edits; `-e tern_capture=true` copies the live file into the repo. See `roles/tern/README.md`.

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

### Herdr presentation and shortcuts

The configuration targets Herdr 0.9.3. Expanded desktop Agents use a vertical
hierarchy with `row_gap = 0` and no per-agent layout overrides:

- First identity row: state icon and bold workspace.
- Second identity row: subdued machine label, dim agent identity, and dim
  optional tab.
- Optional third task row: `terminal_title_stripped` alone in Catppuccin
  subtext (`#a6adc8`) without dimming.

The agent identity keeps the second row populated for detected agents when
optional context disappears. A lone auto-named tab is omitted from Agents
context; missing tokens add neither text nor separators. The standalone title
row disappears when its title is absent, leaving the identity rows intact.
Long rows truncate to the available sidebar width rather than wrapping.

The machine token's `rules = [{ equals = "Local", hide = true }]` hides exactly
the case-sensitive label `Local`, including its separator. This is a label
match, not a local-versus-remote connection test: remote labels other than
`Local` stay visible, and a remote profile named `Local` would also be hidden.

`ui.mobile_width_threshold = 96` selects native mobile layout at terminal
widths of **96 columns or fewer**, including ordinary narrow desktop terminals.
The condition uses columns only, not phone detection, orientation, aspect
ratio, or terminal height. At 97 columns and above, desktop chrome returns.
Mobile dedicates the width to the pane beneath its compact header rather than
keeping a sidebar visible. Open its full-width switcher with default
**Prefix, then W** (`Ctrl+B`, then `w`) or the header's switch button.

Native mobile switcher agent entries have fixed rows: machine plus workspace
on the first, then optional tab, state, and agent on the second. They truncate
rather than wrap. Custom sidebar rows, token styles, the `Local` hide rule,
and task titles are desktop-only; mobile still displays `Local` and does not
show the terminal task title. Use short, distinct machine, workspace, and
agent labels to keep identities distinguishable at narrow widths; layout
settings cannot guarantee visibility of arbitrarily long labels.

Herdr retains its inherited Catppuccin palette without new accent overrides.
Only three surfaces change: sidebar background `#11111b`, active-row background
`#1e1e2e`, and selection background `#313244`. These distinguish the desktop
sidebar canvas, active item, and selection without recoloring the whole
interface. The native mobile surface uses the inherited panel background,
not the desktop-only `sidebar_bg` override.
Ghostty's managed Catppuccin Mocha near-black canvas and OMP's
`dark-catppuccin` remain separate application surfaces, not shared palette
settings.

Existing bindings remain intact. The added shortcuts are:

| Action | Shortcut |
|--------|----------|
| Resize pane left/down/up/right | `Ctrl+Shift+Alt+H/J/K/L` |
| Move tab previous/next | `Alt+Shift+Left/Right` |
| Clear pane | Prefix, then `Ctrl+K` |

The default prefix is `Ctrl+B`: clear pane therefore means `Ctrl+B`, then
`Ctrl+K`, not the existing direct `Ctrl+K` pane-focus shortcut. Go To remains
prefix then `G` or `O`. Pane focus, agent cycling/index shortcuts, the
`Alt+Backtick` `gh dash` popup, priority ordering, symbols, hidden scrollbars,
internal-only pane dividers, pane history, ASCII-prefix input switching, and
100 MB scrollback remain unchanged. Graphics use the default-enabled
`terminal.kitty_graphics`; the deprecated experimental graphics key is absent.

Themes, sidebar layouts, and normal keybindings are client-local, including
while viewing SSH machines. Deploy the canonical file locally, then reload
the local client through Herdr's global-menu **reload config** action with
Local selected; the action also reloads the selected server's config.
`herdr server reload-config` addresses the server side and is not a substitute
for reloading the client's presentation. Do not select a remote server for this
local-only change. Reload does not restart panes; startup-only settings require
a separately planned restart. The role does not automatically reload, stop,
or restart any running server.

On macOS, a normal role run fetches the HTTPS stable `latest.json` manifest,
normalizes `arm64` to `aarch64`, and validates the matching HTTPS asset and its
64-hex SHA-256 checksum. The checksum-backed download installs
`~/.local/bin/herdr` with mode `0755`: missing or stale bytes converge to the
current stable release, while matching bytes avoid another asset download.
Manifest-dependent installation and the read-only `--version` probe are
skipped in check mode. Updating the executable does not replace a running
server process automatically; client/binary and running-server versions can
temporarily differ. This macOS installer change does not modify Linux or remote
machines.

See the upstream [sidebar row layouts](https://herdr.dev/docs/configuration/#sidebar-row-layouts)
and [config reference](https://herdr.dev/docs/config-reference/) for token and
keybinding syntax.

## Commands

```bash
dotfiles                    # Run all default roles
dotfiles -t neovim,git      # Run specific roles
dotfiles --check            # Dry run
dotfiles -e "var=value"     # Override variable
```
