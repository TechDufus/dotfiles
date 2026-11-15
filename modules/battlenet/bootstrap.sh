#!/usr/bin/env bash
# Battle.net (Omarchy's umu + GE-Proton prefix) exits instead of waiting in the tray: "On game
# launch" and "When clicking X" are both "Exit Battle.net completely". Under Proton a tray-resident
# client is the fragile part: the tray icon cannot bring it back, a relaunch only asks the running
# copy to show itself (blank and unresponsive when its renderer has died), and after a day or more
# it can hang outright, which blocks every new launch until the prefix is killed.
#
# Both settings live per account, under User.Client in Roaming/Battle.net/<account id>.config, not
# in Battle.net.config. GameLaunchWindowBehavior follows Battle.net's own Behavior enum
# (MinToSysTray 0, Exit 1, KeepItOpen 2, Minimize 3); HideOnClose "false" makes X exit.
#
# A task rather than a mise merge entry: the account file's name is only known once Battle.net has
# written it, and merge creates a missing target, while a stray drive_c tree makes
# omarchy-install-gaming-battlenet offer to wipe a "partial install". Fail-soft.
set -uo pipefail

prefix="$HOME/Games/battlenet"
dir="$prefix/drive_c/users/steamuser/AppData/Roaming/Battle.net"
set_keys='.User.Client.GameLaunchWindowBehavior = "1" | .User.Client.HideOnClose = "false"'
is_set='.User.Client.GameLaunchWindowBehavior == "1" and .User.Client.HideOnClose == "false"'

# Account files appear at first login; until then there is nothing to set.
[ -d "$dir" ] || exit 0
command -v jq >/dev/null 2>&1 || { echo "battlenet: jq not found, skipped"; exit 0; }

pending=()
for config in "$dir"/*.config; do
  [ -f "$config" ] && [ "${config##*/}" != Battle.net.config ] || continue
  jq -e '.User | type == "object"' "$config" >/dev/null 2>&1 || continue
  jq -e "$is_set" "$config" >/dev/null 2>&1 || pending+=("$config")
done
[ ${#pending[@]} -gt 0 ] || exit 0

# A running client rewrites these files from memory when it exits, dropping the change.
# Same check as omarchy-launch-battlenet: a wineserver whose WINEPREFIX is this prefix.
for pid in $(pgrep -x wineserver); do
  running=$(tr '\0' '\n' <"/proc/$pid/environ" 2>/dev/null | sed -n 's/^WINEPREFIX=//p')
  if [ -n "$running" ] && [ "$(realpath "$running" 2>/dev/null)" = "$(realpath "$prefix")" ]; then
    echo "battlenet: Battle.net is running, exit settings unchanged; quit it and rerun dotfiles"
    exit 0
  fi
done

for config in "${pending[@]}"; do
  tmp=$(mktemp "$config.XXXXXX") || { echo "battlenet: cannot create temp file, skipped"; continue; }
  if jq --indent 4 "$set_keys" "$config" >"$tmp" \
    && chmod --reference="$config" "$tmp" && mv "$tmp" "$config"; then
    echo "battlenet: ${config##*/} set to exit on game launch and on close"
  else
    rm -f "$tmp"
    echo "battlenet: updating ${config##*/} failed, skipped"
  fi
done
exit 0
