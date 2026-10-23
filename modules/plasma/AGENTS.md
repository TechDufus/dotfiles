# Plasma module guidance

- This module owns stable KDE Plasma preferences and the Plasma summon stack (CachyOS only, `mise.cachyos.toml`).
- Keep sparse desktop preferences in `settings.sh`, one explicit `kwriteconfig6 --file F --group G [--group G2] --key K V` line each.
- Discover live scalar settings with `kreadconfig6`, then add one line to `settings.sh`.
- Keep runtime artifacts the module fully owns (registries, scripts, services, units) as module files.
- Do not raw-copy Plasma-generated session state: applet layouts, containment IDs, screen geometry, wallpaper, or activity state.
- If a setting depends on generated IDs or monitor/session state, leave it manual or build a purpose-specific reconciler.
- Treat summon and CapsLock/F13 behavior as user-critical. Prefer minimal, tested changes; physical keyboard behavior still needs user confirmation.
