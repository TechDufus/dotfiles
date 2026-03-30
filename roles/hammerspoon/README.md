# Hammerspoon

This role installs Hammerspoon, Karabiner, `GridLayout.spoon`, and
`WorkspaceManager.spoon`.

The split is intentional:

- `GridLayout.spoon` is the low-level placement engine.
- `WorkspaceManager.spoon` is the stateful runtime layered on top.
- `files/config/` holds your personal app catalog, layouts, screen defaults, and keybindings.

## Deploy

Provisioning path:

```sh
dotfiles -t hammerspoon
```

That run now does all of the following:

- copies `files/config/*.lua` into `~/.hammerspoon/`
- installs `GridLayout.spoon` from GitHub Releases
- overlays [files/spoons/GridLayout.spoon/helpers.lua](files/spoons/GridLayout.spoon/helpers.lua)
  because the latest tagged GridLayout release still predates PR #7
- installs `WorkspaceManager.spoon` from GitHub Releases

## Current Release State

As of March 29, 2026:

- `GridLayout.spoon` screen-aware cells merged in
  [`jesseleite/GridLayout.spoon#7`](https://github.com/jesseleite/GridLayout.spoon/pull/7)
  on March 28, 2026.
- the latest `GridLayout.spoon` release archive is still the tagged release line, so this role
  keeps the local `helpers.lua` overlay enabled until a newer release actually ships that code.
- `WorkspaceManager.spoon` now publishes release zips, so the role no longer vendors a local
  snapshot.

Role defaults live in [defaults/main.yml](defaults/main.yml).

## Config Boundary

Runtime behavior lives in `WorkspaceManager.spoon`:

- per-screen layout state
- per-window and per-app overrides
- summon/open/focus placement
- focused-window moves between screens
- screen change handling

Personal configuration stays here:

- [files/config/apps.lua](files/config/apps.lua)
- [files/config/layouts.lua](files/config/layouts.lua)
- [files/config/positions.lua](files/config/positions.lua)
- [files/config/screen_layouts.lua](files/config/screen_layouts.lua)
- [files/config/init.lua](files/config/init.lua)

## Role Defaults

- `hammerspoon_gridlayout_release_url`
  GridLayout release archive URL.
- `hammerspoon_legacy_config_files`
  Old top-level runtime modules removed during deploy now that the spoon bundles own that code.
- `hammerspoon_gridlayout_overlay_enabled`
  Keeps the local multi-monitor helper patch active until an upstream GridLayout release includes
  PR #7.
- `hammerspoon_gridlayout_overlay_src`
  Local helper overlay copied on top of the released GridLayout bundle.
- `hammerspoon_workspacemanager_release_url`
  WorkspaceManager release archive URL.

## Local Dev Mode

For live work against local spoon checkouts:

1. keep `~/.hammerspoon/init.lua` sourced from this role
2. symlink `~/.hammerspoon/Spoons/WorkspaceManager.spoon` to your local checkout
3. symlink `~/.hammerspoon/Spoons/GridLayout.spoon` to your local checkout
4. reload Hammerspoon after edits

Do not run `dotfiles -t hammerspoon` in the middle of that loop unless you want to restore the
release-managed bundles.

## Keybindings

Current bindings from [files/config/init.lua](files/config/init.lua):

- `F13`: summon modal
- `F13` twice: switch from summon modal to macro modal
- `F16`: macro modal
- `Hyper+a`: focus the frontmost app
- `Hyper+p`: pick a layout for the focused screen
- `Hyper+;`: cycle the focused screen's layout variant
- `Hyper+'`: reset the focused screen's layout overrides
- `cmd+u`: bind the focused window to a cell on its current screen
- `cmd+o`: move the focused window to the next screen
- `shift+cmd+o`: move the focused window to the previous screen

Legacy `lilHyper+o` and `Hyper+o` bindings still exist as alternate screen-move paths.

## File Layout

- [files/config/init.lua](files/config/init.lua)
  Composition root. Loads spoons, injects config, and binds keys.
- [files/config/apps.lua](files/config/apps.lua)
  Logical app definitions and summon bindings.
- [files/config/layouts.lua](files/config/layouts.lua)
  Ordered layout catalog.
- [files/config/positions.lua](files/config/positions.lua)
  Cell geometry primitives consumed by layouts.
- [files/config/screen_layouts.lua](files/config/screen_layouts.lua)
  Optional per-screen default layout selection.
- [files/spoons/GridLayout.spoon/helpers.lua](files/spoons/GridLayout.spoon/helpers.lua)
  Temporary overlay for screen-aware GridLayout cells until a tagged upstream release includes PR #7.
- [tasks/MacOSX.yml](tasks/MacOSX.yml)
  Installation and deployment tasks for the role.
- [defaults/main.yml](defaults/main.yml)
  Release URLs and GridLayout overlay toggles.
