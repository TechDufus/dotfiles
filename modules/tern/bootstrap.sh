#!/usr/bin/env bash
# Tern drops settings that equal its defaults whenever it saves, so they cannot live in
# settings.json; remove them here so Tern falls back to its defaults (opacity 60 %, Reader chat).
# Fail-soft.
set -uo pipefail

if [ "$(uname -s)" = Darwin ]; then
  settings="$HOME/Library/Application Support/Tern/settings.json"
else
  settings="$HOME/.config/tern/settings.json"
fi

[ -f "$settings" ] || exit 0
command -v jq >/dev/null 2>&1 || { echo "tern: jq not found, skipped"; exit 0; }

if jq -e 'has("opacity") or has("surface_chat")' "$settings" >/dev/null 2>&1; then
  tmp="$(mktemp "$settings.XXXXXX")" || { echo "tern: cannot create temp file, skipped"; exit 0; }
  if jq --indent 2 'del(.opacity, .surface_chat)' "$settings" > "$tmp" \
    && chmod 0644 "$tmp" && mv "$tmp" "$settings"; then
    echo 'tern: run "Reload settings" in Tern (Ctrl+Shift+F5)'
  else
    rm -f "$tmp"
    echo "tern: settings cleanup failed, skipped"
  fi
fi

exit 0
