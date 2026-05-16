#!/usr/bin/env bash
set -euo pipefail

export PATH="${HOME}/.local/bin:${HOME}/.npm-global/bin:${HOME}/.bun/bin:${PATH}"
export NVM_DIR="${HOME}/.nvm"

if [[ -s "${NVM_DIR}/nvm.sh" ]]; then
  # shellcheck disable=SC1091
  source "${NVM_DIR}/nvm.sh"
fi

if ! command -v npm >/dev/null 2>&1; then
  echo "npm not found; nothing to uninstall"
  exit 0
fi

npm uninstall -g clawpatch

if command -v clawpatch >/dev/null 2>&1; then
  echo "Warning: clawpatch is still available on PATH from another install source"
else
  echo "clawpatch removed"
fi
