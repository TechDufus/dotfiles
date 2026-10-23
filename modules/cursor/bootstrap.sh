#!/usr/bin/env bash
# Cursor agent CLI installer plus the keys a recursive JSON merge cannot replace. Fail-soft.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
managed="$here/cli-config.json"
config="$HOME/.cursor/cli-config.json"

if ! command -v agent >/dev/null 2>&1 \
  && ! command -v cursor-agent >/dev/null 2>&1 \
  && [ ! -x "$HOME/.local/bin/agent" ]; then
  curl -fsS https://cursor.com/install | bash || echo "cursor: agent install failed, skipped"
fi

# The merge only updates these keys recursively; replace them wholesale so stale
# model parameters do not linger.
[ -f "$config" ] || exit 0
command -v jq >/dev/null 2>&1 || { echo "cursor: jq not found, skipped"; exit 0; }

tmp="$(mktemp "$config.XXXXXX")" || { echo "cursor: cannot create temp file, skipped"; exit 0; }
trap 'rm -f "$tmp"' EXIT

if ! jq --slurpfile m "$managed" \
  '.selectedModel = $m[0].selectedModel | .modelParameters = $m[0].modelParameters | .statusLine = $m[0].statusLine' \
  "$config" > "$tmp"; then
  echo "cursor: cli-config.json rewrite failed, skipped"
  exit 0
fi

# Compare as sorted JSON so formatting differences do not count as changes.
if [ "$(jq -S . "$config")" != "$(jq -S . "$tmp")" ]; then
  chmod 0600 "$tmp" && mv "$tmp" "$config" || echo "cursor: cannot write $config, skipped"
fi

exit 0
