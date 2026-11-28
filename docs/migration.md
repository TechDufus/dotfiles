# Migration notes

What changed for machines that ran the Ansible version of this repo (tagged [`ansible-final`](https://github.com/TechDufus/dotfiles/tree/ansible-final)) or that still carry state from retired modules.

## macOS migration

- Existing stable Raycast is preserved, including hand-installed copies; the stable Homebrew cask is installed only when the app is absent. The migration neither installs Beta nor deletes stable.
- Existing sudo policy is left untouched. Privileged changes can still require authentication.
- The 1Password SSH agent selects only `Personal` on macOS; other profiles retain their shared selections.
- Claude uses a Mac-specific, symlinked settings source containing only theme and TUI. It does not enable the shared permission/plugin/hook profile. The Herdr-generated session hook is neither carried forward nor registered.
- Hammerspoon uses lowercase `t` for Tern and uppercase `T` for Ghostty. Spoon updates validate both releases before replacement, restore prior installations on failure/interruption, and leave unchanged installs untouched. If restoration fails, the reported transaction directory retains the originals.
- Tern's macOS profile disables the press-and-hold accent menu for `so.stencil.tern` so held letters and numbers can repeat. Global repeat timing and other apps are unchanged. Fully quit and reopen Tern after applying this preference; reloading its settings alone is insufficient.
- On macOS, mise shims take precedence over local CLI installations, including app-owned launchers such as Tern's `omp`. Login Zsh restores this order after Apple's `path_helper`. Linux keeps its intentional local-wrapper-first order; optional CLI paths remain available on both platforms. pnpm uses native upstream releases rather than npm lifecycle scripts.
- Vimscript language-server installation is no longer managed. An existing Bun-global `vim-language-server` must be removed during an approved cutover if OMP's built-in discovery should stop finding it; Vim syntax parsers remain available.
- Yazi's Mac profile owns its config and theme; its current built-in keymap replaces the empty legacy keymap. Obsolete Plasma, rofimoji, and OpenCode companion links are retired only on macOS.
- Neovim generates a new ignored `lazy-lock.json` from its configured plugins instead of carrying forward the old role's lock. macOS declares Ruby for Mason's Solargraph and selects it inside Neovim without changing the shell's Ruby. Go-tool builds report installation failures rather than completing before their installers.
- Neovim's shared theme explicitly selects Catppuccin Mocha, with transparent editing areas and ordinary floating windows rather than near-black overrides. It inherits the terminal background; window opacity remains a terminal setting, and selections/statuslines retain their own contrast.
- The global TypeScript compiler remains on `latest`. TypeScript language-server 6 carries a private compatible SDK 6 through its mise postinstall hook, without adding competing compiler executables.

## Migration ownership and rollback

- Ansible is retained as a development-tool dependency for the Ansible language server, not as the provisioning engine. macOS owns standalone Ansible through Homebrew; Linux owns `ansible-core` and `ansible-lint` through pacman. The existing macOS Neovim profile also owns `ansible-lint`.
- `bootstrap:git` places one owned include block at the end of `~/.gitconfig`, after historical globals. After successful migration, defaults and the generated `~/.config/git/identity.gitconfig` are loaded once; macOS also includes its platform defaults. Explicit repository-local settings still win. Cleanup removes only exact obsolete `dotfiles` / `dotfiles-macos` blocks from `~/.config/git/config` (or an active XDG config root within HOME), preserving unrelated contents and both global files. This transfers ownership without requiring a change to an already-correct identity.
- Helm bootstrap requires the canonical `traefik` name to point at its required repository URL. It repairs a missing or incorrect alias without a broad repository update; optional Helm failures still warn and skip.
- Retired Ollama helpers are not deleted automatically. If `~/.config/ollama/Modelfile.qwen-omp` or `~/.local/bin/ollama-qwen`, `ollama-qwen-start`, or `ollama-qwen-stop` remain, review their contents and consumers before manually removing obsolete copies. Customized files or replacement symlinks must not be treated as known historical files.
- The retired `sesh` popup (`prefix+o`) is removed from the managed tmux config instead of reinstalling its provider. Omarchy's native tmux configuration remains outside this module's ownership.
- Retired OMP custom agents (`gap-advisor`, `plan-critic`, `risk-assessor`, `security-auditor`, `validator`) are not deleted automatically. On each machine, remove the leftover `~/.omp/agent/agents/<name>.md` links by hand; they point at deleted sources.
- The short-lived `bootstrap:sunshine` task is retired; Sunshine setups it made stay. To remove one: `systemctl --user disable --now app-dev.lizardbyte.app.Sunshine.service`, then `omarchy-remove-service-sunshine` for the package, `omarchy-sunshine` UFW rules and Sunshine Admin web app.
- Go is a mise tool in `devtools`, installed before the `go:` tools that build with it, instead of `pacman:go` / `brew:go`; before this, `omarchy update` (which runs `mise up`) failed on those tools until the packages step had run. The retired system package is not removed automatically: after checking nothing else needs it, remove it with `sudo pacman -Rs go` or `brew uninstall go`. A `go` entry hand-added to `~/.config/mise/config.toml` as a workaround can be dropped too.
- Linux passwordless sudo policy is derived from the actual invoking non-root UID, not `$USER` or a root fallback. `bootstrap:system` protects and validates a root-owned `0440` candidate with real `visudo` before atomic installation, rejects symlink/non-regular destinations, and fails before later udev/keyboard steps if validation or installation fails. Other policy files and macOS sudo policy are left alone.

Git include placement is task-owned: `mise dot apply` / `status` cover the linked source files but do not perform or verify the include migration. After applying those sources, use full bootstrap or the targeted task:

```bash
cd ~ && MISE_TASK_RUN_AUTO_INSTALL=false mise run bootstrap:git
```

Python 3 is required. The task warns and skips changed/damaged owned blocks, unsafe/shared files or parents, lock files, or an explicit `GIT_CONFIG_GLOBAL` redirect; inspect its outcome rather than assuming a green dotfile status proves Git ownership.

The new validated include owner is published **before** obsolete includes are removed, so interruption does not remove the signing policy. If cleanup fails after publication, temporary duplicate includes can remain. Review the warning and rerun `bootstrap:git` to complete cleanup and restore single loading; do not delete a global config file to recover.

After an authorized apply on **native Linux**, validate the installed sudoers include graph and file metadata before considering the system step complete:

```bash
sudo visudo -cf /etc/sudoers
sudo stat -c '%U:%G:%a' /etc/sudoers.d/techdufus
sudo -l
```

Expect `root:root:440` for the managed file and review the invoking account's effective policy. Run bootstrap as the normal user, not root. These post-apply checks complement, rather than replace, the automatic pre-install candidate validation.

For an Ansible cutover, use a plain terminal and a fixed reviewed revision. Preserve unique local commits, copied/merged configurations, and any retired-role configuration you intend to keep before switching branches. Retiring the old `roles/` source tree is not an instruction to delete its former live configuration wholesale: review each local file and its current owner. Remove redundant public CLI installations only after checking consumers; app-owned runtimes such as Tern's OMP and a Bun binary used by a LaunchAgent may still be required.

Relink configurations before broader provisioning, run again to settle permissions on merge-created files, then require clean `mise dot status --missing` and a no-change repeat. Verify signing, service health, actual application behavior, and any fail-soft task outcomes separately. A Git checkout reversal does not undo installed tools, services, shell registration, copies, merges, or removals; preserve a verified private rollback snapshot of the affected live configuration and ownership rather than treating a branch switch as a transaction.
