#!/usr/bin/env bash
# Omarchy renders ~/.config/omarchy/themed/k9s.yaml.tpl only while it sets a theme, so after the
# template changes, refresh the current theme once, then copy the rendered skin into place: the
# theme-set hook does not run in headless mode. Fail-soft.
set -uo pipefail
here=$(dirname "$0")

if [ -f "$HOME/.local/state/omarchy/current/theme.name" ]; then
  if command -v omarchy-theme-refresh >/dev/null 2>&1; then
    # shellcheck source=../omarchy/hypr-instance.sh
    . "$here/../omarchy/hypr-instance.sh"
    hypr_live_sig
    if [ -n "$HYPR_SIG" ]; then
      export HYPRLAND_INSTANCE_SIGNATURE=$HYPR_SIG
    else
      export OMARCHY_THEME_HEADLESS=1
    fi
    omarchy-theme-refresh >/dev/null || echo "k9s: omarchy-theme-refresh failed, skipped"
  else
    echo "k9s: omarchy-theme-refresh not found, skipped"
  fi
fi

bash "$here/omarchy-skin.hook" || echo "k9s: skin copy failed, skipped"
exit 0
