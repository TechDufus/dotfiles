#!/usr/bin/env bash
# Battle.net (Omarchy's umu + GE-Proton prefix) exits when its window is closed instead of waiting
# in the tray. Under Proton a tray-resident client is the fragile part: the tray icon cannot bring
# it back, a relaunch only asks the running copy to show itself (blank and unresponsive when its
# renderer has died), and after a day or more it can hang outright, which blocks every new launch
# until the prefix is killed.
#
# HideOnClose "false" in each account's User.Client (Roaming/Battle.net/<account id>.config) makes
# X exit; the same key in Battle.net.config alone did not (tested live with Battle.net 2.53).
# "On game launch" (GameLaunchWindowBehavior) is left to Battle.net's Settings: its stored values
# are unconfirmed, and "1" in the account file kept Battle.net open beside the game.
#
# A task rather than a mise merge entry: the account file's name is only known once Battle.net has
# written it, and merge creates a missing target, while a stray drive_c tree makes
# omarchy-install-gaming-battlenet offer to wipe a "partial install". Fail-soft.
set -uo pipefail

prefix="$HOME/Games/battlenet"
dir="$prefix/drive_c/users/steamuser/AppData/Roaming/Battle.net"

# Account files appear at first login; until then there is nothing to set.
[ -d "$dir" ] || exit 0
command -v jq >/dev/null 2>&1 || { echo "battlenet: jq not found, skipped"; exit 0; }

pending=()
for config in "$dir"/*.config; do
  [ -f "$config" ] && [ "${config##*/}" != Battle.net.config ] || continue
  jq -e '.User | type == "object"' "$config" >/dev/null 2>&1 || continue
  jq -e '.User.Client.HideOnClose == "false"' "$config" >/dev/null 2>&1 || pending+=("$config")
done
[ ${#pending[@]} -gt 0 ] || exit 0

# A running client rewrites these files from memory when it exits, dropping the change.
# Same check as omarchy-launch-battlenet: a wineserver whose WINEPREFIX is this prefix.
for pid in $(pgrep -x wineserver); do
  running=$(tr '\0' '\n' <"/proc/$pid/environ" 2>/dev/null | sed -n 's/^WINEPREFIX=//p')
  if [ -n "$running" ] && [ "$(realpath "$running" 2>/dev/null)" = "$(realpath "$prefix")" ]; then
    echo "battlenet: Battle.net is running, close setting unchanged; quit it and rerun dotfiles"
    exit 0
  fi
done

for config in "${pending[@]}"; do
  tmp=$(mktemp "$config.XXXXXX") || { echo "battlenet: cannot create temp file, skipped"; continue; }
  if jq --indent 4 '.User.Client.HideOnClose = "false"' "$config" >"$tmp" \
    && chmod --reference="$config" "$tmp" && mv "$tmp" "$config"; then
    echo "battlenet: ${config##*/} set to exit when its window is closed"
  else
    rm -f "$tmp"
    echo "battlenet: updating ${config##*/} failed, skipped"
  fi
done
exit 0
