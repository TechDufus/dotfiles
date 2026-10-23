#!/usr/bin/env bash
# Keep the traefik name mapped to its Helm repo URL (trailing slashes are ignored).
set -uo pipefail

name=traefik
url=https://helm.traefik.io/traefik

if ! command -v helm >/dev/null 2>&1; then
  echo "devtools: helm not installed, skipped"
  exit 0
fi

current=$(helm repo list -o table 2>/dev/null | awk -v name="$name" '$1 == name { sub(/\/+$/, "", $2); print $2 }')
if [ "$current" = "$url" ]; then
  exit 0
fi

helm repo add "$name" "$url" --force-update >/dev/null || echo "devtools: helm repo add $name failed, skipped"
exit 0
