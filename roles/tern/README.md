# Tern Role

Keeps [Tern](https://stencil.so/tern)'s `settings.json` in this repo in both directions: every `dotfiles -t tern` run merges edits made in the repo and edits made in Tern's settings UI, then writes the result to both places. Changes made in the app show up in `git diff`.

## Scope

- Syncs `roles/tern/files/settings.json` ↔ Tern's `settings.json` on macOS and Linux.
- Does **not** install Tern. It is a closed beta behind a Stencil sign-in and updates itself; install it by hand.
- Does not touch the rest of Tern's config folder (`known_hosts`, the hosts list, `account.lock`, plugins, themes).
- Fonts come from the `fonts` role (`BerkeleyMono Nerd Font`).

Tern's config folder is `$TERN_CONFIG_DIR`, else `~/Library/Application Support/Tern` on macOS, else `$XDG_CONFIG_HOME/tern` (`~/.config/tern`) on Linux; the role resolves it the same way.

## How Tern stores settings

`settings.json` holds only the settings that differ from Tern's defaults; resetting a setting removes its key. Every setting's name, type, range and default is listed by Tern's plugin API (`cx.settings:list()` / `cx.settings:describe(key)`) and the Settings pages; common ones:

| Area | Keys |
|------|------|
| Fonts | `font_family`, `font_family_bold`, `font_family_italic`, `font_family_bold_italic`, `font_size` (8–32 px), `font_weight`, `adjust_cell_height`, `ui_font`, `code_font` |
| Theme | `theme` (`System`/`Light`/`Dark`), `theme_dark`, `theme_light` (unset: follow omp's theme) |
| Keys | `keymap` (`tern`/`ghostty`/`kitty`/`cmux`/`tmux`), `keymap_prefix`, `keybinds` |
| Look | `layout`, `material`, `opacity`, `blur`, `tabs`, `status_bar`, `pane_headers`, `cursor`, `prompt_style`, `prompt_parts` |

Two Tern behaviours shape this role:

- Saving from the UI replaces `settings.json` with a new file, so a symlink into the repo would be silently broken. The role writes copies instead.
- A running Tern keeps its settings in memory: it ignores edits made to the file until **Reload settings** (command palette) or a restart, and its next in-app change writes its in-memory settings back over them. After a run that updates Tern's file, reload before changing anything in Tern.

## Sync

The role keeps the merged result of the last run as the merge base (`$XDG_STATE_HOME/dotfiles/tern-settings.base.json`) and merges per key, nested objects included:

| Repo since last sync | Tern since last sync | Result |
|------|------|------|
| unchanged | changed or removed the key | Tern's value goes into the repo |
| changed or removed the key | unchanged | the repo's value goes into Tern |
| changed | changed differently | the repo's value wins; Tern's value is reported and its file backed up beside it |

With no base yet (first run on a machine), keys present on only one side are kept and keys set differently on both sides are conflicts.

```bash
dotfiles -t tern                                    # sync both ways
git diff roles/tern/files/settings.json             # review what changed in Tern, then commit
git restore roles/tern/files/settings.json && dotfiles -t tern   # or drop those changes from Tern too
```
