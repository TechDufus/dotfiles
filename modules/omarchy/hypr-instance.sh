# shellcheck shell=bash
# Sourced by bootstrap.sh and theme.sh.
# hypr_live_sig sets HYPR_SIG to a live Hyprland instance, or empty when none runs.
# Agent and SSH shells lack HYPRLAND_INSTANCE_SIGNATURE, and long-lived herdr/tmux panes keep a
# stale one after Hyprland restarts. Use it only if that instance is live, else find the running
# one, so a run from anywhere reaches the session instead of failing or caching a false success.
hypr_live_sig() {
  local live=""
  HYPR_SIG=${HYPRLAND_INSTANCE_SIGNATURE:-}
  if command -v hyprctl >/dev/null 2>&1; then
    live=$(hyprctl instances -j 2>/dev/null | jq -r '.[].instance' 2>/dev/null || true)
  fi
  if [ -n "$HYPR_SIG" ] && ! grep -qxF -- "$HYPR_SIG" <<<"$live"; then
    HYPR_SIG=""
  fi
  [ -n "$HYPR_SIG" ] || HYPR_SIG=$(head -n 1 <<<"$live")
}
