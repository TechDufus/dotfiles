#!/usr/bin/env bash
# Applies the Hyprland Lua modules and the fcitx5 keyboard config after `mise dot` deployed them.
set -euo pipefail

# Agent and SSH shells lack HYPRLAND_INSTANCE_SIGNATURE. Find the running session instead, so a
# run from there still reloads and validates rather than caching an unvalidated success.
if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && command -v hyprctl >/dev/null 2>&1; then
  HYPRLAND_INSTANCE_SIGNATURE=$(hyprctl instances -j 2>/dev/null | jq -r '.[0].instance // empty' || true)
  export HYPRLAND_INSTANCE_SIGNATURE
fi
if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
  echo "omarchy: not in Hyprland; applies at next login"
  exit 0
fi

hyprctl reload
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
