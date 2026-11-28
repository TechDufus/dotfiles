# Machine purpose

Purpose is independent of the OS profile: any supported profile can be `work` or `personal`. An unmarked machine defaults to `personal`, preserving the usual setup on other machines. The local, untracked marker is `${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/purpose`; invalid or empty stored values stop the wrapper before provisioning rather than silently selecting personal.

`dotfiles --set-purpose work` and `dotfiles --set-purpose personal` only save that marker and regenerate mise discovery settings. They do not install prerequisites, sync the repo, replace `conf.d`, move conflicts, run tasks, or apply packages/dotfiles. Run the setter on its own, not with bootstrap flags such as `--dry-run`. `dotfiles --purpose` is a read-only query of the effective purpose.

The wrapper owns generated `${XDG_CONFIG_HOME:-$HOME/.config}/mise/miserc.local.toml`; do not hand-edit purpose there. The setter and normal setup keep `auto_env = true` and persist `env = ["work"]` (or `["personal"]`) on macOS, and `env = ["omarchy", "work"]` on Linux (substitute `personal` when selected). Subsequent raw mise commands use this persisted selection; a marker alone does not configure raw mise before the setter or normal setup has generated it.

Package restrictions use mise's native [`[bootstrap.packages]` `env` option](https://mise.jdx.dev/bootstrap/packages/#by-config-environment): `env = "work"` is work-only, `env = "personal"` is personal-only, and omitting `env` is shared, still subject to the existing platform/profile declarations. Discord is personal-only on macOS and Linux; all other app declarations and shared shortcuts are unchanged. Selecting work does **not uninstall** an existing Discord installation or disable its shortcuts.

This is an installation preference, not an allowlist or organizational/security enforcement. It does not restrict unrelated apps installed by bootstrap tasks or external installers; any future restriction on those apps must also cover their installer/configuration owner. Explicit native `MISE_ENV` or `mise -E` selections can intentionally override generated environments; preserve the distro environment when doing so on Linux.

Read-only inspection from HOME, with compatible mise and existing package-manager prerequisites:

```bash
cd ~
dotfiles --purpose
mise bootstrap packages status --json
# macOS: compare requested packages without changing the saved purpose.
MISE_AUTO_ENV=true mise -E work bootstrap packages status --json
MISE_AUTO_ENV=true mise -E personal bootstrap packages status --json
# Linux: retain the actual distro environment.
MISE_AUTO_ENV=true mise -E omarchy,work bootstrap packages status --json
MISE_AUTO_ENV=true mise -E omarchy,personal bootstrap packages status --json
```

[`status`](https://mise.jdx.dev/cli/bootstrap/packages/status.html) does not install packages or use sudo. Discord should be absent from the work request and present in the personal control; shared package requests should remain unchanged. A work status does not prove Discord is absent from the machine, and cross-platform selection on macOS is not native Linux runtime verification.
