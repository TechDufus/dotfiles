# Vicinae

This role installs [Vicinae](https://github.com/vicinaehq/vicinae) as the
primary Raycast-style launcher for the Ubuntu AwesomeWM desktop.

Vicinae is intentionally separate from `awesomewm`:

- `awesomewm` owns global key capture, leader/summon bindings, focus, layout,
  and fallback behavior.
- `fabric` owns the visible command deck and emits AwesomeWM signals.
- `vicinae` owns the searchable command launcher, script commands, app search,
  file search, calculator, and eventual clipboard/search workflows.

## Install

```sh
dotfiles -t vicinae
```

The role mirrors the official install script without running `curl | bash`:

- resolves the latest GitHub release or a pinned `vicinae_version`
- downloads the x86_64 AppImage
- extracts it into `{{ vicinae_prefix }}/lib/vicinae`
- symlinks `{{ vicinae_prefix }}/bin/vicinae`
- installs bundled themes, desktop files, and the user systemd unit
- optionally sets input-server capabilities for snippets/paste support

The user service is installed but not enabled by default. AwesomeWM starts
`vicinae server --replace` after the X11 session environment exists.

## Managed Config

The role writes:

```text
~/.config/vicinae/dotfiles.json
```

If `~/.config/vicinae/settings.json` does not exist, the role creates it with
an import:

```json
{
  "imports": [
    "./dotfiles.json"
  ]
}
```

If the settings file already exists and does not import `dotfiles.json`, the
role leaves it untouched and prints a warning. This avoids overwriting settings
that Vicinae's GUI writes itself.

## Script Commands

Scripts are deployed to:

```text
~/.local/share/vicinae/scripts/techdufus
```

Initial scripts cover settings launchers, restarting AwesomeWM/Fabric, and
quick AI usage actions. They are intentionally simple script commands; build a
TypeScript extension only after scripts or dmenu prove insufficient.

## Rollout Boundary

This role only installs and configures Vicinae. The AwesomeWM role owns desktop
keybindings and removes the retired rofi, CopyQ, and bemoji fallback tools once
the Vicinae launcher, clipboard, app search, emoji, and settings flows validate.
