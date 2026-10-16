# AGENTS.md

Personal dotfiles applied with mise: `mise bootstrap`, `[dotfiles]`, `[tools]`, and tasks. Omarchy and macOS are primary; CachyOS remains supported. Ansible is a development-tool runtime only, not the provisioning engine.

## Layout
- `bin/dotfiles`: curl entrypoint and daily wrapper. Installs git and mise, pulls this repo, links `~/.config/mise/conf.d` → `~/.dotfiles/modules`, writes OS profile and independent machine purpose to generated mise discovery settings, then runs `mise bootstrap`. In a terminal it runs the bootstrap parts stage by stage behind a summary view and logs mise's output to `~/.local/state/dotfiles/last-run.log`; piped or with `--plain` it is one `mise bootstrap --yes` with mise's own output.
- Wrapper configuration/task context defaults to HOME, not the caller's project; `DOTFILES_DIR` selects only the source checkout. Explicit `-C` / `--cd` keeps caller-relative resolution and deliberately selects one consistent context for preview, bootstrap, and status, with plain-mode output. Do not silently discard an explicit context or mix it with HOME-only probes.
- `modules/<name>/`: one mise conf.d folder per module: env files, config sources, `bootstrap.sh`, `tests/`.
- `modules/base`: `min_version`, package managers, and the `bootstrap` and `check` tasks.

## Profiles, purpose, and env files
`bin/dotfiles` detects the profile from `/etc/os-release` (`DOTFILES_PROFILE` overrides it): `omarchy` (Hyprland), `cachyos` (KDE Plasma), or `macos`. Profiles describe OS/session, not chassis: Omarchy supports laptops and desktops.
- `mise.toml`: every supported profile.
- `mise.linux.toml` / `mise.macos.toml`: platform env, loaded via `auto_env`.
- `mise.omarchy.toml` / `mise.cachyos.toml`: OS/session-specific config.
- Precedence, low to high: `mise.toml` < linux/macos < omarchy/cachyos. `~/.config/mise/config.toml` (Omarchy writes it with `mise use -g`) beats every module for the same `[tools]` key.
- Machine purpose is independent of OS/session: `work` or `personal`, defaulting to `personal` only when `${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/purpose` is absent. Keep this validated marker local and untracked; empty/invalid markers fail before provisioning.
- `dotfiles --purpose` prints the effective purpose without setup. Standalone `dotfiles --set-purpose work` / `dotfiles --set-purpose personal` only update the marker and generated mise discovery settings: no prerequisite install, repo sync, `conf.d` replacement, conflict moves, tasks, or apply. Reject mixed bootstrap arguments, including `--dry-run`, before writing.
- The wrapper owns `${XDG_CONFIG_HOME:-$HOME/.config}/mise/miserc.local.toml`: retain `auto_env = true`, select `[purpose]` on macOS and `[distro profile, purpose]` on Linux. Raw mise uses the persisted selection after the setter or normal setup; do not hand-edit generated discovery or treat the marker alone as a native mise input. Explicit `MISE_ENV` / `-E` remains an intentional native override; retain the distro environment on Linux.

## Where things go
- An app with config, system files, or steps gets `modules/<app>`.
- Pure installs go in `modules/packages`.
- Runtimes and global dev CLIs go in `modules/devtools`.

## Mapping rules
1. Packages are `"<manager>:<name>" = "latest"`. `pacman:` for official repos. `aur:` only where the package is foreign on that machine (mise checks `pacman -Qm`); Omarchy's own repo ships brave-bin and herdr, so those are `pacman:` in `mise.omarchy.toml` and `aur:` or `[tools]` in `mise.cachyos.toml`. `brew:`/`brew-cask:` only in `mise.macos.toml` (elsewhere mise would install Linuxbrew); tap formulas use full names. Exception: the 1Password app and CLI are installed by the fail-soft `bootstrap:1password` task, because one failed package install stops the whole run and `dotfiles` must finish without 1Password.
   - Named purpose restrictions use native package tables: `{ version = "latest", env = "personal" }` or `env = "work"`; omitted `env` means shared. Preserve manager, version, and platform/profile placement. Discord is personal-only in both package files; leave other apps and shared shortcuts unchanged. No parallel policy engine, module allowlist, or duplicated OS configuration.
   - Purpose gates those package declarations, not unrelated task-installed apps or external installers. Future app restrictions must cover their installer/config ownership too. Switching purpose never uninstalls apps and is not organizational/security enforcement.
2. Tools that are not system packages (npm/bun/go globals, GitHub releases, curl installers) go in `[tools]` as `"latest"`: registry short name when one exists, otherwise `github:`/`go:`/`npm:`.
3. Deploy modes. Decide by who writes the file:
   - Only you edit it and the app just reads it → symlink (the default; a live edit is a repo edit). A directory → `mode = "symlink-each"` when other tools also drop files into it (links for deleted sources are removed automatically), `mode = "symlink"` for a whole tree the repo owns.
   - The app also writes it: JSON/TOML/YAML → `merge = true` for the keys the repo owns; other formats → `line` or `block` edits (e.g. `~/.npmrc`, where `npm login` writes tokens). A non-JSON/TOML/YAML file the app rewrites wholesale drops blocks, so its owned keys are task-set instead (`modules/btop/settings.sh`).
   - `mode = "copy"` only when a link cannot work: the app replaces the file by temp-file rename, rewrites it wholesale, refuses symlinks, or must see a real file. Put the reason in a comment on the entry. Directory copies are additive, and `dotfiles` overwrites live edits to copies (save them first with `mise dot add`).
   - Never put secrets or app runtime state in a linked file: this repo is public.
   - Per-user template values use `get_env` only in supported `[bootstrap.files]` (`template = true`) and merge sources (`template = "tera"`). Never trust `$USER` or a root fallback as the recipient of a sudoers grant; derive the actual invoking non-root UID.
   - Switching an entry from a whole-directory `symlink` to `symlink-each`: delete the old directory link on each machine first. With `--force-dotfiles`, mise otherwise writes links through the old link into the repo, replacing the source files with links to themselves.
4. Always write an explicit relative `source`; it resolves from the module folder. Never rely on `dotfiles.root`.
5. Imperative steps go in `[tasks."bootstrap:<module>"]`: cwd is the module folder; multi-line steps live in `./bootstrap.sh`. They must be idempotent: every bootstrap runs them all, one at a time in name order. Steps that should run only after their inputs change use `sources = [...]` and `outputs = { auto = true }`. Fail soft: on failure print `<module>: <what failed>, skipped` and `exit 0`. Only `bootstrap:system` (sudoers validation/install) and `bootstrap:omarchy` (`hyprctl configerrors`) exit non-zero, because a failure stops the remaining tasks.
6. Secrets: only `modules/secrets/bootstrap.sh` calls `op`, and it always exits 0.
7. Tests execute shipped code (Lua, zsh, TS extensions, Python helpers). They live in `modules/<m>/tests/` and run from `[tasks."test:<module>"]`, declared in the same env file as the code they test.
8. Git identity/signing defaults belong to `modules/git`, with precedence over historical globals and below explicit repository-local settings. `bootstrap:git` owns include placement, not `mise dot apply/status`: put one owned include block last in `~/.gitconfig`, remove only exact obsolete managed blocks from the other global config, and preserve unrelated contents. Unsafe/customized configs warn and skip; never replace or delete an entire user Git config.
   - Publish the validated new Git include owner before retiring old blocks so signing policy survives interruption. Cleanup failure may leave temporary duplicate includes: warn, preserve unrelated content, and recover on rerun rather than deleting global files. Single loading describes successful convergence, not every interrupted state.

Retiring a file: `mode = "absent"` removes the target unconditionally, including customized replacements; it is not safe historical ownership detection. Use it only when unconditional removal is intended and approved. Otherwise retire the declaration and document manual cleanup after reviewing the live file. Never delete former role configuration wholesale.

## Verify before reporting done
- From HOME, `dotfiles --dry-run` and `mise dot diff` should show only the intended changes. Preview may still evaluate trusted templates and update mise metadata/caches; use isolated HOME/XDG/mise directories and confinement for experiments.
- Preview must not update live purpose/discovery. Older generated selections without purpose may require config-only `dotfiles --set-purpose work` (or `personal`) before retrying; do not drop retained globals to force preview success. From HOME, inspect native requests with `mise bootstrap packages status --json`, or compare `MISE_AUTO_ENV=true mise -E work bootstrap packages status --json` and `-E personal` on macOS; on Linux retain `-E omarchy,work` / `omarchy,personal` (or `cachyos`). Status is read-only and does not use sudo; work must omit Discord, personal must include it, and shared requests must be unchanged. This does not prove an existing Discord installation was removed.
- Run `cd ~ && MISE_TASK_RUN_AUTO_INSTALL=false MISE_AUTO_ENV=true DOTFILES_TEST_REAL_MISE="$(command -v mise)" mise run check` with a trusted compatible mise and prerequisites already installed. The auto-install prefix must be set before the outer task runner starts, not inside a task. Do not disable other projects' normal task auto-install globally.
- The gate runs all loaded `test:*` suites; macOS CI must not narrow it to Hammerspoon. Keep the real-mise source-relative fixture enabled. A macOS-hosted Linux profile-selection check is not native Linux runtime verification.
- On macOS, native configuration/cache fixtures must canonicalize temporary HOME roots with `pwd -P` before deriving child paths; fix fixture path aliases rather than weaken production symlink/security guards.
- On a suitable native Linux executor, also run `cd ~ && MISE_TASK_RUN_AUTO_INSTALL=false MISE_AUTO_ENV=true mise run check:system-sudoers`: it needs a non-root account, real `visudo`, bubblewrap, enabled unprivileged user/PID namespaces, and existing `/etc/sudoers.d`. It tests a disposable mapped policy directory, not the live grant; it is separate from the wildcard module suites.
- CI routes the same sudoers script to a dedicated non-root Ubuntu `system-sudoers` job, outside wildcard suites, using packaged sudo/bubblewrap without relaxing host namespace policy. A job definition is not passing-run evidence, and this isolated gate is not full Omarchy/CachyOS runtime verification.
- When live application is authorized, apply with `dotfiles`, inspect `mise dot status --missing`, and require a no-change repeat. Check signing, services, app consumers, and fail-soft outcomes separately; a Git branch reversal is not a live rollback.

## Omarchy landmines
- Never write under `/usr/share/omarchy`.
- Never manage `~/.config/hypr/hyprland.lua`; hook in only through the `autostart.lua` block.
- No tmux or opencode config on Omarchy; Omarchy owns those.
- btop on Omarchy: Omarchy owns the theme (`color_theme = "current"` → `themes/current.theme`) and its shipped `btop.conf`; `bootstrap:btop` sets only the keys in `modules/btop/settings.conf` and `omarchy.conf`. Never deploy the whole `btop.conf` there.
- herdr comes from Omarchy's pacman package there.
- Tools Omarchy installs with `omarchy-mise-install` (codex, claude, omp, grok, pi, …; see `/usr/share/omarchy/install/user/mise.sh`) get `~/.local/bin` wrappers that run `mise use -g`. Declaring one in a module's `mise.toml` or `mise.linux.toml` makes that fail with "declared in multiple global config files"; declare it only in `mise.macos.toml` / `mise.cachyos.toml`.
- Omarchy owns its desktop and gaming stack. Do not port CachyOS-specific gaming, KDE, or GPU policy automatically; keep retained CachyOS support profile-scoped.

## Other landmines
- No plaintext secrets; reference 1Password with `op://` only.
- Optional work fails soft instead of stopping the bootstrap, especially around package installs and 1Password. Linux sudoers validation/install is not optional: validate a protected root:root `0440` candidate with `visudo` before replacing the managed file, and stop before udev/keyboard changes on failure. Never install it through unconditional `[bootstrap.files]`; never add a macOS grant.
- mise bootstrap is new: read <https://mise.jdx.dev/bootstrap.html> and <https://mise.jdx.dev/dotfiles.html> instead of guessing syntax.
- No per-module READMEs. No tests that grep config text.
- Current Mac app bindings are in `modules/hammerspoon/config/apps.lua` and documented in README: CapsLock → `w` is AWS WorkSpaces (`com.amazon.workspaces`), CapsLock → Shift+T is Tern, and unshifted `t` is Ghostty. Do not revive retired role docs or commented-out bindings.
- Tern's native merge destinations and reset use standard roots only: `~/Library/Application Support/Tern` on macOS, `~/.config/tern` on Linux. `TERN_CONFIG_DIR` and custom `XDG_CONFIG_HOME` are unsupported for this module. Native destination/edit keys do not expand environment/Tera expressions; do not add a second imperative deployer to pretend otherwise.
