#!/usr/bin/env bash
set -uo pipefail

theme="$HOME/.config/bat/themes/Catppuccino Mocha.tmTheme"
url="https://raw.githubusercontent.com/catppuccin/bat/main/themes/Catppuccin%20Mocha.tmTheme"

[ -e "$theme" ] && exit 0

tmp="$(mktemp)"
if mkdir -p "$(dirname "$theme")" && curl -fsSL -o "$tmp" "$url" && mv "$tmp" "$theme"; then
  chmod 0644 "$theme"
else
  rm -f "$tmp"
  echo "bat: theme download failed, skipped"
fi
exit 0
