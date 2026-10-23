#!/usr/bin/env bash
# Applies the Hyprland Lua modules and the fcitx5 keyboard config after `mise dot` deployed them.
set -euo pipefail

# shellcheck source=hypr-instance.sh source-path=SCRIPTDIR
. "$(dirname "$0")/hypr-instance.sh"
hypr_live_sig
sig=$HYPR_SIG
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
