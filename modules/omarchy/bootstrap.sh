#!/usr/bin/env bash
# Applies the Hyprland Lua modules and the fcitx5 keyboard config after `mise dot` deployed them.
set -euo pipefail

# Agent and SSH shells lack HYPRLAND_INSTANCE_SIGNATURE, and long-lived herdr/tmux panes keep a
# stale one after Hyprland restarts. Use it only if that instance is live, else find the running
# one, so a run from anywhere reloads and validates instead of caching an unvalidated success.
sig=${HYPRLAND_INSTANCE_SIGNATURE:-}
live=""
if command -v hyprctl >/dev/null 2>&1; then
  live=$(hyprctl instances -j 2>/dev/null | jq -r '.[].instance' 2>/dev/null || true)
fi
if [ -n "$sig" ] && ! grep -qxF -- "$sig" <<<"$live"; then
  sig=""
fi
[ -n "$sig" ] || sig=$(head -n 1 <<<"$live")
if [ -z "$sig" ]; then
  echo "omarchy: not in Hyprland; applies at next login"
  exit 0
fi
export HYPRLAND_INSTANCE_SIGNATURE=$sig

if ! hyprctl reload >/dev/null; then
  echo "omarchy: hyprctl reload failed for Hyprland instance $sig" >&2
  exit 1
fi
errors=$(hyprctl configerrors -j)
if ! jq -e 'map(select(. != "")) | length == 0' <<<"$errors" >/dev/null; then
  echo "omarchy: hyprctl configerrors reports errors:" >&2
  echo "$errors" >&2
  exit 1
fi

# fcitx5 reads keyboard.conf only at start.
if [ "$(systemctl --user is-active omarchy-fcitx5.service || true)" = "active" ]; then
  systemctl --user restart omarchy-fcitx5.service
fi
