# Tern Role

Keeps [Tern](https://stencil.so/tern)'s `settings.json` in this repo, in both directions: repo edits deploy to the machine, and changes made in Tern's settings UI can be captured back into the repo.

## Scope

- Manages `roles/tern/files/settings.json` → Tern's `settings.json` on Linux.
- Does **not** install Tern. It is a closed beta behind a Stencil sign-in and updates itself; install it by hand.
- Does not touch the rest of Tern's config folder (`known_hosts`, the hosts list, `account.lock`, plugins, themes).
- Fonts come from the `fonts` role (`BerkeleyMono Nerd Font`).

Tern's config folder is `$TERN_CONFIG_DIR`, else `$XDG_CONFIG_HOME/tern`, else `~/.config/tern`; the role resolves it the same way.

## How Tern stores settings

`settings.json` holds only the settings that differ from Tern's defaults, so the repo copy is exactly your customizations. Every setting's name, type, range and default is listed by Tern's plugin API (`cx.settings:list()` / `cx.settings:describe(key)`) and the Settings pages; common ones:

| Area | Keys |
|------|------|
| Fonts | `font_family`, `font_family_bold`, `font_family_italic`, `font_family_bold_italic`, `font_size` (8–32 px), `font_weight`, `adjust_cell_height`, `ui_font`, `code_font` |
| Theme | `theme` (`System`/`Light`/`Dark`), `theme_dark`, `theme_light` (unset: follow omp's theme) |
| Keys | `keymap` (`tern`/`ghostty`/`kitty`/`cmux`/`tmux`), `keymap_prefix`, `keybinds` |
| Look | `layout`, `material`, `opacity`, `blur`, `tabs`, `status_bar`, `pane_headers`, `cursor.*`, `prompt_style`, `prompt_parts.*` |

Two Tern behaviours shape this role:

- Saving from the UI replaces `settings.json` with a new file, so a symlink into the repo would be silently broken. The role copies instead.
- A running Tern does not pick up edits made outside the app. After a deploy, run **Reload settings** from the command palette, or restart Tern.

## Sync

The role remembers the checksum of the last synced file (`$XDG_STATE_HOME/dotfiles/tern-settings.sha256`) and decides per run:

| Repo since last sync | App since last sync | Result |
|------|------|------|
| unchanged | unchanged | nothing to do |
| changed | unchanged | deploys the repo copy |
| unchanged | changed | leaves the app's file alone and says how to capture |
| changed | changed (or never synced) | touches nothing and says how to resolve |

```bash
dotfiles -t tern                        # deploy repo changes, report in-app changes
dotfiles -t tern -e tern_capture=true   # copy the live settings.json into the repo, then git diff + commit
dotfiles -t tern -e tern_force=true     # overwrite the live file with the repo copy (old file backed up beside it)
```

Typical loop: change something in Tern → `dotfiles -t tern -e tern_capture=true` → review `git diff roles/tern/files/settings.json` → commit. Other machines pick it up on their next `dotfiles -t tern`.
