# 🚀 Quick Start Guide

**Complete beginner to dotfiles?** This guide will get you from zero to a fully configured development environment in under 15 minutes.

## 📖 What are dotfiles?

Dotfiles are configuration files for your development tools (terminal, editor, git, etc.). This repository automates the installation and configuration of 50+ development tools using Ansible, so you get a consistent setup across different machines.

## ⏱️ Time Estimate: 8-15 minutes

- **Prerequisites**: 2-3 minutes
- **Installation**: 5-12 minutes (varies by system and internet speed)
- **Basic Configuration**: 1-3 minutes

## 📋 Step 1: Prerequisites Check (2-3 minutes)

Before running anything, let's make sure your system is ready:

### Check Your Operating System

This works on:
- ✅ **macOS** (Monterey 12.0+)
- ✅ **Ubuntu** (20.04+)
- ✅ **Fedora** (any recent version)
- ✅ **Arch Linux** (any recent version)
- ✅ **CachyOS** (Arch-family, Plasma/Hyprland/Steam path)

```bash
# Check your OS version
uname -a
```

### Install Package Manager (macOS Only)

**macOS users need to install Homebrew first:**

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

> 📖 **What is Homebrew?** It's the missing package manager for macOS. [Learn more](https://brew.sh/)

### Update Your System

**IMPORTANT**: Update your system packages first:

```bash
# macOS
brew update && brew upgrade

# Ubuntu
sudo apt update && sudo apt upgrade -y

# Fedora
sudo dnf update && sudo dnf upgrade -y

# Arch Linux / CachyOS
sudo pacman -Syu
```

On Linux, keep sudo credentials warm before a long role run:

```bash
sudo -v
dotfiles -t system,plasma
```

If you invoke `ansible-playbook` directly instead of `bin/dotfiles`, use
`--ask-become-pass` when sudo requires a password.

> ⏰ **This may take 5-10 minutes depending on your system**

### CachyOS Desktop Paths

For CachyOS daily-driver setup, the bootstrap detects CachyOS as an Arch-family
host, installs `requirements/arch.yml`, and maps Ansible task dispatch to the
repo's `Archlinux` role files. A full default run prunes macOS/Ubuntu-only
desktop roles on Arch-family systems, while explicit tags still work when you
need a single role.

If reinstalling is cheap, prefer the CachyOS Plasma edition for the normal KDE
session, SDDM, portals, settings UI, and first-login defaults. The `plasma` role
then makes that install repo-managed. If you keep the current install, the same
role installs Plasma after the fact.

```bash
# Normal KDE Plasma Wayland desktop plus KWin summon workflow
dotfiles -t plasma,brave,discord,signal,spotify,obsidian

# Hyprland desktop and summon workflow
dotfiles -t hyprland,brave,discord,signal,spotify,obsidian

# Steam/Proton/NVIDIA/Gamescope support (large, optional stack)
dotfiles -t steam

# Optional Flatpak runtime only; native pacman/AUR app roles are preferred
dotfiles -t flatpak
```

The `taskfile` role deploys an Arch-specific `~/Taskfile.yml` with maintenance
helpers:

```bash
task update          # sudo pacman -Syu --disable-download-timeout
task pacnew          # list .pacnew/.pacsave files for manual review
task desktop-health  # Plasma summon service + strict Steam runtime checks
```

Hyprland config is symlinked from
`roles/hyprland/files/hypr/hyprland.lua` to
`~/.config/hypr/hyprland.lua`, so repo edits are picked up by Hyprland reloads.
Waybar is also role-managed from `roles/hyprland/files/waybar/` and launches as
a normal full-width top Catppuccin Mocha panel on each display. The Hyprland role also owns the
Catppuccin wallpaper and `hyprpaper` config, so reboot should visibly change
the background as well as compositor/window styling. Hyprlock, Hypridle, and
the Hyprland-specific summon helper/config are managed from the same role
directory. The app, region, and monitor-layout registries live under
`roles/hyprland/files/summon`.

Plasma uses `roles/plasma/files/kwin/plasma-summon/` for the KWin script,
`roles/plasma/files/bin/plasma-summon-service.py` for safe app launching, and
`roles/plasma/files/summon/` for the same app, region, and layout model. The
role symlinks the KWin package into `~/.local/share/kwin/scripts/`, enables it
with `kwriteconfig6`, starts the user D-Bus helper, and writes stable desktop
preferences such as keyboard repeat, cursor/icons/fonts/default apps,
notifications, KWin effects/decorations, locale, and AC power timeouts.

Window-management carry-over:

- Tap `CapsLock`/keyboard `F13` once, then press a logical app letter: summon/focus an app; the keyd bridge keeps this layout-safe for the repo's Dvorak default and QWERTY. Existing windows are not moved. Repeating a summon while that app is focused toggles back to the previously focused app.
- Tap `CapsLock`/keyboard `F13` twice, then logical `a`/`s`/`e`: cycle same-app windows, screenshot a region to clipboard, or open the emoji picker.
- `Super+U`: open the styled fuzzy picker, type part of a cell/region name, press `Enter`, and move the focused window.
- `Super+O` / `Shift+Super+O`: move the focused window to the next/previous monitor; managed apps snap into that monitor's active layout, while unmanaged windows keep their relative geometry.
- `Hyper+P`: open the styled fuzzy picker for layouts and press `Enter`; only the active monitor changes. `Hyper+;` cycles the active monitor layout, and `Hyper+'` resets that monitor to its configured or width-based default.

After `dotfiles -t steam`, verify the non-interactive pieces:

```bash
steam-health
steam-health --runtime
steam-health --runtime --strict   # final cutover gate: warnings fail
```

If `steam-health` reports `pacman-multilib` as failed, enable `[multilib]` in
`/etc/pacman.conf`, run `sudo pacman -Syu`, then rerun `dotfiles -t steam`.
Steam/Proton 32-bit graphics packages are intentionally skipped until multilib
is available.

`steam-health --runtime` includes `gamemoded -t`, `vkcube --c 10`, and a
nested Gamescope smoke test with `--keep-alive`. Add `--strict` for final
cutover validation; it exits non-zero on warnings such as missing Steam sign-in
or missing native/Proton/DX12 app manifests.

The Steam role prefers native Arch/CachyOS packages. On CachyOS it installs
`gamescope-session-cachyos` when the package is available. On vanilla Arch-family
hosts where that package is unavailable, the role installs a dotfiles-managed
fallback SDDM session named `Gamescope Steam (dotfiles)`. Use a full Gamescope
session to validate Steam Big Picture and real fullscreen games; nested Gamescope
under a desktop compositor can crash after a test app exits without `--keep-alive`
on the current NVIDIA stack.

Manual Steam cutover checks still require an interactive session:

1. Log out and back in after the Steam role so the active session picks up the
   `gamemode` group.
2. Sign into Steam and install at least one native Linux game, one Proton game,
   and one DX12/Proton title.
3. Launch each installed test class once from the regular Steam session:
   native Linux, Proton, and DX12/Proton. Do not count the Steam stack validated
   until all three reach gameplay or an equivalent interactive title screen.
4. From SDDM, choose `Gamescope` or `Gamescope Steam (dotfiles)` and validate
   Steam Big Picture plus at least one real fullscreen game there.
5. Back in the regular desktop session, validate fullscreen focus/media-key
   behavior with the same game before treating the migration as complete.

### Internet Connection

Make sure you have a stable internet connection - we'll be downloading lots of tools!

## 🚀 Step 2: Run the Bootstrap (5-10 minutes)

Now for the magic! One command installs everything:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/TechDufus/dotfiles/main/bin/dotfiles)"
```

### What You'll See

The script will show progress like this:

```
 [✓] Loading Setup for detected OS: darwin
 [✓] Installing Homebrew (This may take 5-10 minutes)
 [✓] Installing Git
 [✓] Installing Ansible
 [✓] Installing 1Password CLI
 [✓] Downloading dotfiles repository (This may take a minute)
 [✓] Installing Ansible dependencies (This may take a few minutes)
```

> **Note**: On macOS, 1Password CLI is automatically installed but you don't need to configure it immediately - you can run dotfiles without 1Password setup.

### If Something Goes Wrong

- **Script stops with an error?** → See our [Troubleshooting Guide](TROUBLESHOOTING.md)
- **Need help?** → Join our [Discord](https://discord.gg/5M4hjfyRBj) or [create an issue](https://github.com/TechDufus/dotfiles/issues)

## ⚙️ Step 3: Basic Configuration (2-3 minutes)

After installation, you'll have a default configuration. Let's personalize it:

### Edit Your Configuration

```bash
# Open your config file
cd ~/.dotfiles
nvim group_vars/all.yml  # or vim if you prefer
```

### Essential Settings

At minimum, update these settings in your `all.yml`:

```yaml
# Required: Your name for git commits
git_user_name: "Your Name"

# Choose which tools to run by default
default_roles:
  - system          # Essential system tools
  - git             # Version control
  - zsh             # Modern shell
  - neovim          # Text editor
  - plasma          # KDE Plasma desktop, stable desktop prefs, KWin summon, and regions

# Keep one shared list, but prune irrelevant stacks per OS
exclude_roles_by_distribution:
  Archlinux:
    - awesomewm
    - vicinae
    - flatpak       # Optional: run explicitly with dotfiles -t flatpak

```

### Apply Your Changes

```bash
# Run dotfiles again to apply your customization
dotfiles
```

## 🎉 You're Done!

Your development environment is now set up! Here's what you got:

- **Modern shell** (zsh with oh-my-zsh)
- **Text editor** (Neovim with configuration)
- **Developer tools** (git, tmux, fzf, and more)
- **Package managers** for different languages
- **Automatic updates** with the `dotfiles` command

## 🔄 What's Next?

### Daily Usage

```bash
# Update your environment anytime
dotfiles

# Install specific tools only
dotfiles -t neovim,git

# See what would change (dry run)
dotfiles --check
```

### Advanced Configuration

- **Secure secrets**: Set up [1Password integration](../README.md#1password-integration)
- **More examples**: Check out [configuration examples](EXAMPLES.md)
- **Customize roles**: Edit individual tool configs in the `roles/` directory

### Get Help

- 💬 **Discord**: [Join our community](https://discord.gg/5M4hjfyRBj)
- 🐛 **Issues**: [Report problems](https://github.com/TechDufus/dotfiles/issues)
- 📖 **Docs**: [Full documentation](../README.md)

---

**Questions about this guide?** Please [open an issue](https://github.com/TechDufus/dotfiles/issues) - we'd love to improve it!