#!/usr/bin/env bash
# Preserve an existing stable app, including hand-installed copies.
set -uo pipefail

[ -d /Applications/Raycast.app ] || brew install --cask raycast ||
  echo "raycast: stable app install failed, skipped"
exit 0
