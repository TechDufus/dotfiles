#!/usr/bin/env bash
# Switches Omarchy to $OMARCHY_DEFAULT_THEME once per value of it: a theme picked later in
# Omarchy's menu stays until the default in mise.omarchy.toml changes. Fail-soft.
set -uo pipefail

# omarchy-theme-set's own normalization: "Tokyo Night" -> tokyo-night.
want=$(printf '%s' "${OMARCHY_DEFAULT_THEME:-}" | tr '[:upper:] ' '[:lower:]-')
[ -n "$want" ] || exit 0
marker=${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/omarchy-theme
[ "$(cat "$marker" 2>/dev/null)" != "$want" ] || exit 0

record() { mkdir -p "${marker%/*}" && printf '%s\n' "$want" >"$marker"; }

current=$(cat "$HOME/.local/state/omarchy/current/theme.name" 2>/dev/null || true)
if [ "$current" = "$want" ]; then
  record
  exit 0
fi
if ! command -v omarchy-theme-set >/dev/null 2>&1; then
  echo "omarchy-theme: omarchy-theme-set not found, skipped"
  exit 0
fi

# Outside a live session, Omarchy's headless mode stages the theme for the next login.
# shellcheck source=hypr-instance.sh source-path=SCRIPTDIR
. "$(dirname "$0")/hypr-instance.sh"
hypr_live_sig
if [ -n "$HYPR_SIG" ]; then
  export HYPRLAND_INSTANCE_SIGNATURE=$HYPR_SIG
else
  export OMARCHY_THEME_HEADLESS=1
fi

if omarchy-theme-set "$want"; then
  record
  echo "omarchy-theme: switched to $want"
else
  echo "omarchy-theme: omarchy-theme-set $want failed, skipped"
fi
exit 0
