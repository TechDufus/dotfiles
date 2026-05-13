# Fabric AwesomeWM UI

This role installs [Fabric](https://wiki.ffpy.org/) as an opt-in UI layer for
the existing AwesomeWM desktop.

The boundary is intentional:

- AwesomeWM keeps X11 window management, global key capture, leader/summon
  behavior, app focus, tags, and cell placement.
- Fabric owns visible desktop UI surfaces where practical: panel, status
  widgets, popups, notification UI, tasklist overlays, and future summon/layout
  overlays.

## Deploy

```sh
dotfiles -t fabric
```

On Ubuntu this role:

- installs GTK/PyGObject/cairo/Xlib/build dependencies from apt
- installs `uv` with `pipx` when needed
- creates `~/.local/share/fabric-awesomewm/venv` with `uv`
- installs Fabric from `Fabric-Development/fabric` into that venv
- deploys `~/.config/fabric/awesomewm`
- deploys `~/.local/bin/fabric-awesomewm`
- writes `~/.config/awesome/fabric-ui-enabled` after the launcher, Fabric import,
  and config self-check pass

The AwesomeWM role checks that sentinel file at runtime. When present, AwesomeWM
starts Fabric and skips creating the Lua wibar, while the rest of AwesomeWM
continues to own window management.

## Current UI

The first Fabric config provides:

- an X11 dock-style top bar
- workspace placeholders for AwesomeWM tags 1-9
- command-backed status pills for load, memory, network, battery, volume, AI
  usage, DND, settings, and clock
- a settings launcher that reuses the existing rofi settings picker

## Notes

Fabric's X11 backend is documented as experimental, and transparent widgets need
an X11 compositor such as `picom`. The first pass intentionally keeps the
integration reversible: remove `~/.config/awesome/fabric-ui-enabled` and restart
AwesomeWM to return to the Lua wibar.

Launcher output is written to
`~/.cache/fabric-awesomewm/fabric-awesomewm.log` so startup crashes do not fail
silently when AwesomeWM launches Fabric.

Native GTK/PyGObject/cairo/Xlib Python bindings are intentionally installed with apt
and exposed through a `--system-site-packages` venv. The role uses `uv` for the
venv and Fabric package install, but avoids asking Python packaging tools to
rebuild the desktop binding stack on each Ubuntu host.
