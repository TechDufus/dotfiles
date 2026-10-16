#!/usr/bin/env bash
# Trust the borders formula when Homebrew requires tap trust, then start the service.
set -uo pipefail

formula="felixkratz/formulae/borders"

if ! command -v brew >/dev/null 2>&1; then
  echo "borders: brew not found, skipped"
  exit 0
fi

if brew config 2>/dev/null | grep -q 'HOMEBREW_REQUIRE_TAP_TRUST: set'; then
  if ! brew trust --json v1 2>/dev/null | grep -q "\"$formula\""; then
    brew trust --formula "$formula" || echo "borders: brew trust failed, skipped"
  fi
fi

if ! brew services list 2>/dev/null | grep -q '^borders[[:space:]]*started'; then
  brew services start borders || echo "borders: could not start service, skipped"
fi

exit 0
