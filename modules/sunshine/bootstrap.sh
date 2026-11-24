#!/usr/bin/env bash
# On desktops (no system battery), set up Sunshine so Moonlight on another machine can stream and
# control this one. Omarchy owns the setup: omarchy-install-service-sunshine installs the package,
# enables the user service, opens the Moonlight ports for private LANs and tailscale0, adds the
# Sunshine Admin web app and the Hyprland autostart line. This task only runs it once, when the
# package is missing; pairing a client is a PIN entered in Sunshine Admin, per device.
# No sunshine.conf: Sunshine writes that file from its web UI, and its defaults already fit
# Hyprland on NVIDIA (NvFBC fails on Wayland, so capture falls through to wlr; encoder picks NVENC).
# Laptops are skipped: they are the clients here, and the installer opens inbound ports.
# Fail-soft: the installer needs sudo and the network, and nothing else in dotfiles needs Sunshine.
set -uo pipefail

ROOT=${DOTFILES_SYSROOT:-}

for supply in "$ROOT"/sys/class/power_supply/*; do
  [ "$(cat "$supply/type" 2>/dev/null)" = Battery ] || continue
  # Wireless mice and controllers report scope Device; a laptop's own battery does not.
  [ "$(cat "$supply/scope" 2>/dev/null)" = Device ] && continue
  echo "sunshine: battery found (laptop), skipped"
  exit 0
done

pacman -Q sunshine >/dev/null 2>&1 && exit 0

if ! command -v omarchy-install-service-sunshine >/dev/null 2>&1; then
  echo "sunshine: omarchy-install-service-sunshine not found, skipped"
  exit 0
fi
omarchy-install-service-sunshine || echo "sunshine: Omarchy's Sunshine installer failed, skipped"
exit 0
