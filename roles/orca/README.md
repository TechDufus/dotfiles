# orca

Installs [Orca](https://www.onorca.dev/) on macOS via the official Homebrew tap.

## What this role does

- Taps `stablyai/orca`
- Installs the `stablyai/orca/orca` cask (app + `orca` CLI)
- Skips the cask when `Orca.app` is already present but not Homebrew-managed
- Fails if Homebrew or `/Applications/Orca.app` is the unrelated Plotly `orca` cask

## What this role does not do

- It does not manage `~/Library/Application Support/orca` (settings, sessions, accounts)
- It does not manage `~/.orca` (generated agent hooks, keybindings)
- It does not manage `~/Library/Preferences/com.stablyai.orca.plist`
- It does not upgrade Orca; the app auto-updates in place

Bare `brew install --cask orca` installs deprecated Plotly Orca. This role always uses the fully qualified tap.

## Usage

```bash
dotfiles -t orca
```
