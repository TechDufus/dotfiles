# superwhisper

Installs `superwhisper` on macOS and manages the portable settings file by symlink.

## What this role does

- Installs `superwhisper` via Homebrew cask
- Symlinks `~/Documents/Superwhisper/settings/settings.json` to the repo-managed file at `roles/superwhisper/files/settings.json`
- Backs up any existing non-symlinked `settings.json` to `settings.json.backup` before replacing it
- If `superwhisper.app` is already present in `/Applications`, the role skips the cask install instead of failing and still manages `settings.json`

## What this role does not do

- It does not manage `~/Library/Preferences/com.superduper.superwhisper.plist`
- It does not manage hotkeys or other macOS preference keys

Those preferences are intentionally excluded because macOS preference writes do not reliably preserve symlinks in `~/Library/Preferences`.

## Usage

```bash
dotfiles -t superwhisper
```

After the role runs, edits made by superwhisper to `settings.json` will update the tracked file in this repo automatically via the symlink.
