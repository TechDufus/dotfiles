# Apps

Notes on app modules whose behavior is not obvious from their config. Omarchy-only pieces are in [omarchy.md](omarchy.md).

## OMP

Managed OMP configuration preserves deliberate routing, capability, trust-boundary, and visual choices while omitting redundant default tuning so future upstream defaults can apply.

Shared `devtools` installs [ovnfs](https://github.com/stencil-hq/ovnfs) on both supported profiles. Omarchy also installs `fuse3`; macOS uses its built-in NFS support. OMP detects ovnfs by default without managed backend/path overrides. Subagent filesystem isolation remains opt-in per task with `isolated: true`; installing ovnfs does not isolate every subagent automatically.

The main `omp` configuration defaults to `openai-codex/gpt-6.2-astra:xhigh`, uses GPT-6.2 Sol for task and reviewer roles, and GPT-6.2 Astra for slow, plan, and designer roles. `omp-codex` defaults to `openai-codex/gpt-6.2-sol:max` and uses GPT-6.2 Sol for those five roles. In both configurations, smol and tiny use GPT-6 Luna at low thinking, vision uses GPT-6.1 Terra at high thinking, commit uses Terra at low thinking, and memory and advisor use Terra at medium thinking. Memory is explicit so Mnemopi extraction and consolidation do not fall through to tiny's lightweight Luna model. Prewalk and plan-yolo may select smol for implementation, so Luna is not limited to background tasks. `omp-claude-terra` uses Claude for its main roles and GPT-6.1 Terra for its advisor. `omp-claude-fable` defaults to Claude Fable 5.2, uses Fable for slow, plan, and reviewer roles, Opus 5.5 for task, designer, vision, and a low-thinking advisor, and Sonnet 5.5 for smol, tiny, and commit.

`omp-claude-sol` was renamed to `omp-claude-terra`. On older installs, `~/.local/bin/omp-claude-sol` and `~/.omp/agent/overlays/claude-sol.yml` may remain as dangling symlinks because targeted mise apply creates the new names without pruning the old paths. Inspect these paths before removing them; remove only obsolete managed symlinks, not custom files.

`bootstrap:omp` installs and updates the user-wide Herdr, Worktrunk, and [Impeccable](https://impeccable.style/) skills from upstream Git checkouts in `~/.local/share/dotfiles/`, linked into `~/.omp/agent/skills/`. Existing non-symlink destinations are preserved. To refresh these skills without running the other module bootstraps, run from HOME:

```bash
MISE_TASK_RUN_AUTO_INSTALL=false MISE_AUTO_ENV=true mise run bootstrap:omp
```

Start a new OMP session after installation, then invoke Impeccable with `/skill:impeccable critique the settings page` or another subcommand. Installation is user-wide; `init` and `document` create project-specific `PRODUCT.md` and `DESIGN.md` context only when requested. The bootstrap does not enable Impeccable hooks or live mode.

## Tern

Native mise merges and the bootstrap reset both use the standard Tern roots: `~/Library/Application Support/Tern` on macOS and `~/.config/tern` on Linux. `TERN_CONFIG_DIR` and a custom `XDG_CONFIG_HOME` are not supported by this module; the old role's alternate-root behavior is not carried forward.

Tern shares dark Catppuccin styling, Float layout, Glass material, vertical tabs, BerkeleyMono Nerd Font, copy-on-select, and the Console chat style (`surface_chat`). Bootstrap removes the legacy explicit opacity override so Tern's default applies. Use **Reload settings (`Control+Shift+F5`)** after settings cleanup; the macOS held-key-repeat preference in [macOS migration](migration.md#macos-migration) instead requires a full quit and reopen.

macOS and Omarchy now share **CapsLock → t** for Tern and **CapsLock → Shift+T** for Ghostty. Linux-only pane keys are `Control+]` / `Control+[` for next/previous pane and `Control+Alt+]` / `Control+Alt+[` for next/previous tab across sessions.

## Tailscale

`bootstrap:tailscale` installs the client and nothing else, and warns instead of failing. On Omarchy it installs the `tailscale` package from the `extra` repo and runs `sudo systemctl enable --now tailscaled`; once the daemon is enabled and running, repeat runs change nothing and do not prompt for sudo. On macOS it installs the standalone app with the `tailscale-app` Homebrew cask, and leaves a hand-installed or App Store `/Applications/Tailscale.app` alone.

The module never joins a tailnet, holds no auth key and sets no routes. Joining is a one-time interactive step per device: `sudo tailscale up --accept-routes` on Linux (the browser sign-in URL is printed), or open the app and sign in on macOS. `--accept-routes` is what makes the home subnets reachable when away. At home, leave Tailscale down (`sudo tailscale down` on Linux, turn it off in the menu bar on macOS) so traffic stays on the LAN. Omarchy's own menu installer (`omarchy-install-service-tailscale`) installs the same package and daemon but also joins, sets the operator and adds a bar widget, so use either that or this module's step, not both.

## Moonlight

macOS installs [Moonlight](https://moonlight-stream.org/) (`brew-cask:moonlight`) to stream and control the Omarchy desktop. Sunshine, the host side, is not managed here: Omarchy's `omarchy-install-service-sunshine` sets it up, but in Omarchy 4.5 it stops at `systemctl --user enable --now sunshine`, an alias of the packaged `app-dev.lizardbyte.app.Sunshine.service` that systemd refuses to enable, before it opens the firewall ports. Pair each Mac once: add the desktop in Moonlight and enter the PIN it shows in Sunshine Admin's **PIN** tab.
