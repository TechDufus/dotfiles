#!/usr/bin/env bash
# Install the Tailscale client and, on Linux, enable its daemon. Deliberately not in
# [bootstrap.packages]: one failed package install stops the whole mise run, and nothing else
# in dotfiles needs Tailscale. This step only warns.
# Joining a tailnet is interactive and per device, so it is never done here: no `tailscale up`,
# no auth key, no routes.
set -uo pipefail

if [ "$(uname -s)" = Darwin ]; then
  # Leave a hand-installed or App Store app alone: the cask would not replace it.
  [ -d /Applications/Tailscale.app ] || brew install --cask tailscale-app ||
    echo "tailscale: app install failed, skipped"
  exit 0
fi

if ! pacman -Q tailscale >/dev/null 2>&1; then
  if pacman -Si tailscale >/dev/null 2>&1; then
    sudo pacman -S --needed --noconfirm tailscale || echo "tailscale: pacman install failed, skipped"
  else
    echo "tailscale: not in any configured repo, skipped"
  fi
fi
pacman -Q tailscale >/dev/null 2>&1 || exit 0

if ! command -v systemctl >/dev/null 2>&1; then
  echo "tailscale: systemctl not found, tailscaled not enabled"
  exit 0
fi

# Already enabled and running: nothing to do, and no sudo prompt.
if systemctl is-enabled --quiet tailscaled.service && systemctl is-active --quiet tailscaled.service; then
  exit 0
fi
sudo systemctl enable --now tailscaled.service ||
  echo "tailscale: enabling tailscaled failed, skipped"
exit 0
