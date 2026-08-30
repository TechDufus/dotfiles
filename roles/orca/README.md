# orca

Installs [Orca](https://www.onorca.dev/) on macOS via the official Homebrew tap
and on Archlinux/CachyOS via `stably-orca-bin`.

## What this role does

- **macOS:** Taps `stablyai/orca` and installs the `stablyai/orca/orca` cask (app + `orca` CLI)
- **Archlinux/CachyOS:** Installs `stably-orca-bin` from pacman when the package is in a configured repo, otherwise from the AUR
- Skips the macOS cask when `Orca.app` is already present but not Homebrew-managed
- Fails if Homebrew or `/Applications/Orca.app` is the unrelated Plotly `orca` cask
- Owns the shared `/orca` spawn-prompt skill and symlinks it into each agent skill home that already exists

## What this role does not do

- It does not manage `~/Library/Application Support/orca` (settings, sessions, accounts)
- It does not manage `~/.orca` (generated agent hooks, keybindings)
- It does not manage `~/Library/Preferences/com.stablyai.orca.plist`
- It does not upgrade Orca; the app auto-updates in place
- It does not add the skill to Cursor, OMP, Codex, or Claude role file trees
- It does not create missing agent skill directories; those homes stay optional

Bare `brew install --cask orca` installs deprecated Plotly Orca. This role always uses the fully qualified tap.

On Arch, the AUR package installs the `stably-orca` launcher (not the GNOME screen-reader `orca` package). Upstream's source/git AUR packages (`stably-orca`, `stably-orca-git`) conflict with `stably-orca-bin`; this role does not switch between them.

## Spawn-prompt skill

Canonical source: `files/skills/orca`. Optional magic words the human types when prompting a worker. Orchestration owns spec structure. Coordinator invoke: `/orca` or `/skill:orca`.

### Install

`dotfiles -t orca` walks `orca_prompt_skill_dests` in `defaults/main.yml` and links each dest to `files/skills/orca`:

| Dest state | Action |
| --- | --- |
| Parent skill dir missing | Skip. Do not create the harness home. |
| Missing, or already a symlink | `force` link. Safe to rerun. |
| Regular file or directory | Leave it. Print a skip message. |

Do not copy this skill into other roles' `files/skills/`.

To add a harness: append `$HOME/<agent-skill-home>/orca` to `orca_prompt_skill_dests`, name it in this section, then `dotfiles -t orca`. Current dests: `~/.cursor/skills/orca`, `~/.omp/agent/skills/orca`, `~/.codex/skills/orca`, `~/.claude/skills/orca`.

### Skill content

This file records how the human prompts with extra harness features. It is not a feature catalog.

When adding a token or a new agent section, ask for the exact word they type and when they use it. Do not invent examples or "also useful" rows.

## Usage

```bash
dotfiles -t orca
```
