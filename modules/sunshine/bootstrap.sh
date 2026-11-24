#!/usr/bin/env bash
# On desktops (no system battery), set up Sunshine so Moonlight on another machine can stream and
# control this one: the steps of Omarchy's omarchy-install-service-sunshine, with the real unit name.
# Omarchy 4.5's installer runs `systemctl --user enable --now sunshine`, but the package's unit is
# app-dev.lizardbyte.app.Sunshine.service and sunshine.service only its Alias=, which systemd refuses
# to enable, so that installer stops before the ports and web app. Drop these steps for the
# installer once Omarchy enables the real unit.
# Same UFW rules (comment omarchy-sunshine) and web app as Omarchy's, so
# omarchy-remove-service-sunshine still closes and removes them. No Hyprland autostart line: the
# enabled unit already starts with graphical-session.target, and the line would start a second copy.
# No sunshine.conf: Sunshine writes that file from its web UI, and by its documented defaults it
# picks wlr capture on Hyprland (NvFBC has no Wayland support) and NVENC on NVIDIA.
# Pairing a client is a PIN entered in Sunshine Admin, per device.
# Laptops are skipped: they are the clients here, and the setup opens inbound ports.
# Fail-soft: the steps need sudo and the network, and nothing else in dotfiles needs Sunshine.
set -uo pipefail

ROOT=${DOTFILES_SYSROOT:-}
UNIT=app-dev.lizardbyte.app.Sunshine.service
TCP_PORTS=(47984 47989 48010)
UDP_PORTS=(5353 47998 47999 48000 48002 48010)
PRIVATE_CIDRS=(10.0.0.0/8 172.16.0.0/12 192.168.0.0/16)

for supply in "$ROOT"/sys/class/power_supply/*; do
  [ "$(cat "$supply/type" 2>/dev/null)" = Battery ] || continue
  # Wireless mice and controllers report scope Device; a laptop's own battery does not.
  [ "$(cat "$supply/scope" 2>/dev/null)" = Device ] && continue
  echo "sunshine: battery found (laptop), skipped"
  exit 0
done

# Enabling the unit is the last step, so an enabled unit means the setup is done. No sudo prompt.
systemctl --user is-enabled --quiet "$UNIT" 2>/dev/null && exit 0

omarchy-pkg-add sunshine || { echo "sunshine: package install failed, skipped"; exit 0; }

# Moonlight's ports, from private LANs and (when Tailscale is up) the tailnet.
if command -v ufw >/dev/null 2>&1; then
  tailnet=0
  ip link show tailscale0 >/dev/null 2>&1 && tailnet=1
  ok=1
  for proto in tcp udp; do
    if [ "$proto" = tcp ]; then ports=("${TCP_PORTS[@]}"); else ports=("${UDP_PORTS[@]}"); fi
    for port in "${ports[@]}"; do
      for cidr in "${PRIVATE_CIDRS[@]}"; do
        sudo ufw allow in proto "$proto" from "$cidr" to any port "$port" comment omarchy-sunshine >/dev/null || ok=0
      done
      [ "$tailnet" -eq 0 ] ||
        sudo ufw allow in on tailscale0 to any port "$port" proto "$proto" comment omarchy-sunshine >/dev/null || ok=0
    done
  done
  sudo ufw reload >/dev/null || ok=0
  # Retried next run: the unit stays disabled until the ports are open.
  [ "$ok" -eq 1 ] || { echo "sunshine: opening Moonlight ports in UFW failed, skipped"; exit 0; }
else
  echo "sunshine: ufw not found, no firewall rules added"
fi

omarchy-webapp-install "Sunshine Admin" https://localhost:47990 \
  /usr/share/sunshine/web/images/logo-sunshine-45.png \
  "omarchy-launch-webapp https://localhost:47990 --ignore-certificate-errors" ||
  echo "sunshine: Sunshine Admin web app not added"

if systemctl --user enable --now "$UNIT"; then
  echo "sunshine: running; open Sunshine Admin to set its login and pair Moonlight"
else
  echo "sunshine: enabling $UNIT failed, skipped"
fi
exit 0
