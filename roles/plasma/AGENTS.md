# Plasma role guidance

- This role owns stable KDE Plasma preferences and the Plasma summon stack.
- Keep sparse desktop preferences in `defaults/main.yml` under `plasma_desktop_kconfig_settings`.
- Each KConfig setting is one item: `file`, ordered `group_path`, `key`, exact string `value`.
- Discover live scalar settings with `kreadconfig6`; apply them through the existing `kwriteconfig6` task path.
- Keep fully owned runtime artifacts in `files/` or `templates/`: summon TOML registries, KWin script, helper service, systemd unit, keyd bridge.
- Do not raw-copy Plasma-generated session files such as `plasma-org.kde.plasma.desktop-appletsrc`, `plasmashellrc`, tray/applets, wallpaper, containment IDs, screen geometry, or activity state.
- If a setting depends on generated IDs or monitor/session state, leave it manual or build a purpose-specific reconciler.
- Treat summon and CapsLock/F13 behavior as user-critical. Prefer minimal, tested changes; physical keyboard behavior still needs user confirmation.
