# orca

Installs [Orca](https://www.onorca.dev/) on macOS via the official Homebrew tap
and on Archlinux/CachyOS via `stably-orca-bin`.

## What this role does

- **macOS:** Taps `stablyai/orca` and installs the `stablyai/orca/orca` cask (app + `orca` CLI)
- **Archlinux/CachyOS:** Installs `stably-orca-bin` from pacman when the package is in a configured repo, otherwise from the AUR
- Skips the macOS cask when `Orca.app` is already present but not Homebrew-managed
- Fails if Homebrew or `/Applications/Orca.app` is the unrelated Plotly `orca` cask

## What this role does not do

- It does not manage `~/Library/Application Support/orca` (settings, sessions, accounts)
- It does not manage `~/.orca` (generated agent hooks, keybindings)
- It does not manage `~/Library/Preferences/com.stablyai.orca.plist`
- It does not upgrade Orca; the app auto-updates in place

Bare `brew install --cask orca` installs deprecated Plotly Orca. This role always uses the fully qualified tap.

On Arch, the AUR package installs the `stably-orca` launcher (not the GNOME screen-reader `orca` package). Upstream's source/git AUR packages (`stably-orca`, `stably-orca-git`) conflict with `stably-orca-bin`; this role does not switch between them.

## Usage

```bash
dotfiles -t orca
```
