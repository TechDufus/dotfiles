#!/usr/bin/env bash
# Keep the traefik helm repo configured (trailing slash on the URL is ignored).
set -uo pipefail

name=traefik
url=https://helm.traefik.io/traefik

if ! command -v helm >/dev/null 2>&1; then
  echo "devtools: helm not installed, skipped"
  exit 0
fi

current=$(helm repo list -o yaml 2>/dev/null | sed -n "s/^[[:space:]-]*url:[[:space:]]*//p" | sed 's#/*$##')
if printf '%s\n' "$current" | grep -qxF "$url"; then
  exit 0
fi

helm repo add "$name" "$url" --force-update >/dev/null || echo "devtools: helm repo add $name failed, skipped"
exit 0
