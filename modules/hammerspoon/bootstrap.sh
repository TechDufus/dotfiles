#!/usr/bin/env bash
# Install the GridLayout and WorkspaceManager spoons from their latest releases.
set -uo pipefail

spoons="$HOME/.hammerspoon/Spoons"
grid_url="https://github.com/jesseleite/GridLayout.spoon/releases/latest/download/GridLayout.spoon.zip"
wm_url="https://github.com/TechDufus/WorkspaceManager.spoon/releases/latest/download/WorkspaceManager.spoon.zip"

tmp=$(mktemp -d) || { echo "hammerspoon: could not create temp dir, skipped"; exit 0; }
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$spoons" || { echo "hammerspoon: could not create $spoons, skipped"; exit 0; }

# Download both archives first so a failed download keeps the installed spoons.
curl -fsSL -o "$tmp/GridLayout.spoon.zip" "$grid_url" || { echo "hammerspoon: GridLayout download failed, skipped"; exit 0; }
curl -fsSL -o "$tmp/WorkspaceManager.spoon.zip" "$wm_url" || { echo "hammerspoon: WorkspaceManager download failed, skipped"; exit 0; }

rm -rf "$spoons/GridLayout.spoon"
mkdir -p "$spoons/GridLayout.spoon"
unzip -q -o "$tmp/GridLayout.spoon.zip" -d "$spoons/GridLayout.spoon" || echo "hammerspoon: GridLayout unzip failed, skipped"

rm -rf "$spoons/WorkspaceManager.spoon"
unzip -q -o "$tmp/WorkspaceManager.spoon.zip" -d "$spoons" || echo "hammerspoon: WorkspaceManager unzip failed, skipped"

# hs.application.find searches Accessibility window titles and can block on Chromium apps;
# configured bundle IDs need only the exact hs.application.get lookup.
for f in summon.lua workspace_manager.lua; do
  if [ -f "$spoons/WorkspaceManager.spoon/$f" ]; then
    perl -0pi -e 's/hs\.application\.get\(([A-Za-z_][A-Za-z0-9_.]*)\) or hs\.application\.find\(\1\)/hs.application.get($1)/g' "$spoons/WorkspaceManager.spoon/$f" ||
      echo "hammerspoon: patching $f failed, skipped"
  fi
done
exit 0
