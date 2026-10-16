#!/usr/bin/env bash
set -uo pipefail

if ! command -v gh >/dev/null 2>&1; then
  echo "gh: gh not installed, skipped"
  exit 0
fi
if ! gh auth status >/dev/null 2>&1; then
  echo "gh: not authenticated (run 'gh auth login'), skipped"
  exit 0
fi

if [ "$(uname -s)" = "Darwin" ]; then
  gh extension list | grep -q dlvhdr/gh-dash \
    || gh extension install dlvhdr/gh-dash \
    || echo "gh: gh-dash install failed, skipped"
fi
gh extension upgrade --all || echo "gh: extension upgrade failed, skipped"
exit 0
