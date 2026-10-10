#!/usr/bin/env bash
# Gamescope realtime scheduling and gamemode group membership. Fail-soft.
set -uo pipefail

if [ -e /usr/bin/gamescope ]; then
  if ! getcap /usr/bin/gamescope | grep -q cap_sys_nice; then
    sudo setcap cap_sys_nice=eip /usr/bin/gamescope || echo "steam: setcap on gamescope failed, skipped"
  fi
else
  echo "steam: /usr/bin/gamescope not installed, capability skipped"
fi

if getent group gamemode >/dev/null; then
  # id -nG "$USER" reads the group database, so this stays quiet after usermod until re-login.
  if ! id -nG "$USER" | tr ' ' '\n' | grep -qx gamemode; then
    if sudo usermod -aG gamemode "$USER"; then
      echo "steam: added $USER to gamemode; log out/in for gamemode"
    else
      echo "steam: adding $USER to gamemode failed, skipped"
    fi
  fi
else
  echo "steam: gamemode group not present, membership skipped"
fi

exit 0
