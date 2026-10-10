#!/usr/bin/env bash
# Install Raycast Beta from the official DMG; needs Apple Silicon and macOS 26+.
set -uo pipefail

app="/Applications/Raycast Beta.app"
tmp=""

# Always detach the DMG and remove the temp dir.
trap '[ -n "$tmp" ] && { hdiutil detach "$tmp/mount" -quiet >/dev/null 2>&1; rm -rf "$tmp"; }' EXIT

if [ "$(uname -m)" != "arm64" ] || [ "$(sw_vers -productVersion | cut -d. -f1)" -lt 26 ]; then
  echo "raycast: Raycast Beta requires Apple Silicon and macOS Tahoe or newer, skipped"
  exit 0
fi

if [ -e "$app" ] && [ ! -d "$app" ]; then
  echo "raycast: $app exists but is not a directory, skipped"
  exit 0
fi

if [ ! -d "$app" ]; then
  page=$(curl -fsSL https://www.raycast.com/new) || { echo "raycast: could not fetch download page, skipped"; exit 0; }
  url=$(printf '%s\n' "$page" | grep -Eo 'https://x-r2\.raycast-releases\.com/Raycast_Beta_[A-Za-z0-9._-]+_arm64\.dmg' | head -n 1)
  if [ -z "$url" ]; then
    echo "raycast: could not find the Raycast Beta Apple Silicon DMG URL on https://www.raycast.com/new, skipped"
    exit 0
  fi

  tmp=$(mktemp -d -t raycast-beta) || { echo "raycast: could not create temp dir, skipped"; exit 0; }
  mkdir -p "$tmp/mount"
  curl -fsSL -o "$tmp/Raycast_Beta_arm64.dmg" "$url" || { echo "raycast: DMG download failed, skipped"; exit 0; }
  hdiutil attach -nobrowse -quiet -mountpoint "$tmp/mount" "$tmp/Raycast_Beta_arm64.dmg" || { echo "raycast: could not mount DMG, skipped"; exit 0; }
  if [ ! -d "$tmp/mount/Raycast Beta.app" ]; then
    echo "raycast: Raycast Beta.app not found in the DMG, skipped"
    exit 0
  fi
  sudo ditto "$tmp/mount/Raycast Beta.app" "$app" || { echo "raycast: install failed, skipped"; exit 0; }
fi

if [ -d "$app" ] && [ -e /Applications/Raycast.app ]; then
  sudo rm -rf /Applications/Raycast.app
fi
exit 0
