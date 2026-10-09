# Tern Role

Keeps the settings that should match on every machine in `roles/tern/files/settings.json`. Each `dotfiles -t tern` run writes them into [Tern](https://stencil.so/tern)'s `settings.json` and leaves every other setting to that machine.

## Scope

- Applies `roles/tern/files/settings.json` to Tern's `settings.json` on macOS and Linux, and holds the settings in `tern_reset_settings` at Tern's defaults.
- Does **not** install Tern. It is a closed beta behind a Stencil sign-in and updates itself; install it by hand.
- Does not touch the rest of Tern's config folder (`known_hosts`, the hosts list, `account.lock`, plugins, themes).
- Fonts come from the `fonts` role (`BerkeleyMono Nerd Font`).

Tern's config folder is `$TERN_CONFIG_DIR`, else `~/Library/Application Support/Tern` on macOS, else `$XDG_CONFIG_HOME/tern` (`~/.config/tern`) on Linux; the role resolves it the same way.

## Shared and per-machine settings

- Shared values are applied on every run, overriding changes made to them in Tern's UI. The role never writes back to the shared file.
- Nested objects merge key by key; shared values win and each machine's other entries stay.
- Lists and scalars are replaced whole.
- Keys the shared file doesn't name are untouched: keybinds, window sizes, recent files and machine paths such as `shell` or `git.gpg_program` stay per machine.
- Removing a key from the shared file stops managing it: each machine keeps its current value.
- List only values that differ from Tern's defaults: Tern drops default-valued keys whenever it saves, so the role would keep adding them back. To hold a setting at its default on every machine, add its top-level key to `tern_reset_settings` in `defaults/main.yml` (now `opacity`, 60 %, and `surface_chat`, Reader); each run removes it from Tern's file. A key can't be in both places.
- Copy values exactly as Tern writes them. They are case-sensitive (`Spine`, not `spine`), and if Tern can't read one value it loads its defaults for every setting, then writes those back on its next save.
- A missing or blank `settings.json` counts as empty. Invalid JSON, or a target that isn't a regular file, fails the run without writing.
- The role writes only when the merged result differs as parsed data, so Tern's own formatting and key order never cause a rewrite.

To add or change a shared setting:

1. Change it in Tern.
2. Use **Open settings.json** in the command palette to open the live file.
3. Copy the key and value into `roles/tern/files/settings.json`.
4. Run `dotfiles -t tern` on each machine.
5. Use **Reload settings** in Tern.

### Keybinds

Keep keybinds per machine by default. `cmd` (or `super`) means ⌘ on macOS and the Super/Windows key on Linux; Tern's defaults use ⌘ chords on macOS and Ctrl+Shift chords on Linux, where plain Ctrl chords go to programs. `ctrl`, `alt` (or `opt`) and `shift` name the same keys on both OSes, so chords spelled only with those modifiers can go in the shared file. A shared `keybinds` object merges with each machine's own bindings.

`"keymap": "tmux"` adds tmux's prefix table over the defaults: `keymap_prefix` (default `ctrl+b`), then a key, such as `c` for a new tab or `%` to split. Those chords use only Ctrl, so they are the same on both OSes; only the bare prefix chord loses its default action.

## How Tern stores settings

`settings.json` holds only the settings that differ from Tern's defaults; resetting a setting removes its key. Every setting's name, type, range and default is listed by Tern's plugin API (`cx.settings:list()` / `cx.settings:describe(key)`) and the Settings pages; common ones:

| Area | Keys |
|------|------|
| Fonts | `font_family`, `font_family_bold`, `font_family_italic`, `font_family_bold_italic`, `font_size` (8–32 px), `font_weight`, `adjust_cell_height`, `ui_font`, `code_font` |
| Theme | `theme` (`System`/`Light`/`Dark`), `theme_dark`, `theme_light` (unset: follow omp's theme) |
| Keys | `keymap` (`tern`/`ghostty`/`kitty`/`cmux`/`tmux`), `keymap_prefix`, `keybinds` |
| Look | `layout`, `material`, `opacity`, `blur`, `tabs`, `status_bar`, `pane_headers`, `cursor`, `prompt_style`, `prompt_parts` |

Two Tern behaviours shape this role:

- Saving from the UI replaces `settings.json` with a new file, so a symlink into the repo would be silently broken. The role writes a copy instead.
- A running Tern keeps its settings in memory: it ignores edits made to the file until **Reload settings** (command palette) or a restart, and its next in-app change writes its in-memory settings back over them. After a run that reports changes, reload before changing anything in Tern.

## Usage

```bash
dotfiles -t tern  # apply shared settings to this machine
```

When it changes Tern's settings, the run prints the keys it changed and asks you to reload before changing anything in Tern.
