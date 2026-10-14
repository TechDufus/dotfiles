# AGENTS.md

Personal dotfiles for three machines, applied with mise: `mise bootstrap`, `[dotfiles]`, `[tools]`, and tasks. No Ansible.

## Layout
- `bin/dotfiles`: curl entrypoint and daily wrapper. Installs git and mise, pulls this repo, links `~/.config/mise/conf.d` → `~/.dotfiles/modules`, writes the profile to `~/.config/mise/miserc.local.toml`, then runs `mise bootstrap`. In a terminal it runs the bootstrap parts stage by stage behind a summary view and logs mise's output to `~/.local/state/dotfiles/last-run.log`; piped or with `--plain` it is one `mise bootstrap --yes` with mise's own output.
- `modules/<name>/`: one mise conf.d folder per module: env files, config sources, `bootstrap.sh`, `tests/`.
- `modules/base`: `min_version`, package managers, and the `bootstrap` and `check` tasks.

## Profiles and env files
`bin/dotfiles` detects the profile from `/etc/os-release` (`DOTFILES_PROFILE` overrides it): `omarchy` (laptop, Hyprland), `cachyos` (desktop, KDE Plasma + Steam), or `macos`.
- `mise.toml`: every machine.
- `mise.linux.toml` / `mise.macos.toml`: platform env, loaded via `auto_env`.
- `mise.omarchy.toml` / `mise.cachyos.toml`: one machine only.
- Precedence, low to high: `mise.toml` < linux/macos < omarchy/cachyos. `~/.config/mise/config.toml` (Omarchy writes it with `mise use -g`) beats every module for the same `[tools]` key.

## Where things go
- An app with config, system files, or steps gets `modules/<app>`.
- Pure installs go in `modules/packages`.
- Runtimes and global dev CLIs go in `modules/devtools`.

## Mapping rules
1. Packages are `"<manager>:<name>" = "latest"`. `pacman:` for official repos. `aur:` only where the package is foreign on that machine (mise checks `pacman -Qm`); Omarchy's own repo ships brave-bin and herdr, so those are `pacman:` in `mise.omarchy.toml` and `aur:` or `[tools]` in `mise.cachyos.toml`. `brew:`/`brew-cask:` only in `mise.macos.toml` (elsewhere mise would install Linuxbrew); tap formulas use full names. Exception: the 1Password app and CLI are installed by the fail-soft `bootstrap:1password` task, because one failed package install stops the whole run and `dotfiles` must finish without 1Password.
2. Tools that are not system packages (npm/bun/go globals, GitHub releases, curl installers) go in `[tools]` as `"latest"`: registry short name when one exists, otherwise `github:`/`go:`/`npm:`.
3. Deploy modes. Decide by who writes the file:
   - Only you edit it and the app just reads it → symlink (the default; a live edit is a repo edit). A directory → `mode = "symlink-each"` when other tools also drop files into it (links for deleted sources are removed automatically), `mode = "symlink"` for a whole tree the repo owns.
   - The app also writes it: JSON/TOML/YAML → `merge = true` for the keys the repo owns; other formats → `line` or `block` edits (e.g. `~/.npmrc`, where `npm login` writes tokens).
   - `mode = "copy"` only when a link cannot work: the app replaces the file by temp-file rename, rewrites it wholesale, refuses symlinks, or must see a real file. Put the reason in a comment on the entry. Directory copies are additive, and `dotfiles` overwrites live edits to copies (save them first with `mise dot add`).
   - Never put secrets or app runtime state in a linked file: this repo is public.
   - Per-user values use Tera `{{ get_env(name='USER', default='root') }}` / `{{ get_env(name='HOME', default='/root') }}`, only in `[bootstrap.files]` (`template = true`) and merge sources (`template = "tera"`).
   - Switching an entry from a whole-directory `symlink` to `symlink-each`: delete the old directory link on each machine first. With `--force-dotfiles`, mise otherwise writes links through the old link into the repo, replacing the source files with links to themselves.
4. Always write an explicit relative `source`; it resolves from the module folder. Never rely on `dotfiles.root`.
5. Imperative steps go in `[tasks."bootstrap:<module>"]`: cwd is the module folder; multi-line steps live in `./bootstrap.sh`. They must be idempotent: every bootstrap runs them all, one at a time in name order. Steps that should run only after their inputs change use `sources = [...]` and `outputs = { auto = true }`. Fail soft: on failure print `<module>: <what failed>, skipped` and `exit 0`. Only `bootstrap:system` (visudo) and `bootstrap:omarchy` (`hyprctl configerrors`) exit non-zero, because a failure stops the remaining tasks.
6. Secrets: only `modules/secrets/bootstrap.sh` calls `op`, and it always exits 0.
7. Tests execute shipped code (Lua, zsh, TS extensions, Python helpers). They live in `modules/<m>/tests/` and run from `[tasks."test:<module>"]`, declared in the same env file as the code they test.

Retiring a file: replace its entry with `mode = "absent"` for one release, then delete the entry.

## Verify before reporting done
- `mise bootstrap --dry-run` and `mise dot diff` show only the intended changes.
- `cd ~ && mise run check` passes (from `~`, so a project-local `check` task cannot shadow it).
- Apply with `dotfiles`.

## Omarchy landmines
- Never write under `/usr/share/omarchy`.
- Never manage `~/.config/hypr/hyprland.lua`; hook in only through the `autostart.lua` block.
- No tmux, btop, or opencode config on Omarchy; Omarchy owns those.
- herdr comes from Omarchy's pacman package there.

## Other landmines
- No plaintext secrets; reference 1Password with `op://` only.
- Optional work fails soft instead of stopping the bootstrap, especially around sudo and 1Password.
- mise bootstrap is new: read <https://mise.jdx.dev/bootstrap.html> and <https://mise.jdx.dev/dotfiles.html> instead of guessing syntax.
- No per-module READMEs. No tests that grep config text.
