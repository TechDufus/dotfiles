#!/usr/bin/env bash
# On machines with a Lian Li UNI FAN SL hub (USB 0cf2:a100), install liquidctl and a udev-started
# oneshot unit that runs `liquidctl initialize` whenever the hub appears (boot or replug), which
# puts every channel into motherboard PWM sync.
# Deliberately a task, not [bootstrap.packages]/[bootstrap.files]: only machines with the hub get
# it, mise cannot gate files by hardware, and one failed package install would stop the whole run.
# This step only warns.
set -uo pipefail

MODULE=$(cd "$(dirname "$0")" && pwd)
ROOT=${DOTFILES_SYSROOT:-}
SERVICE=liquidctl-lianli-uni-sl.service

hub=0
for vendor in "$ROOT"/sys/bus/usb/devices/*/idVendor; do
  [ -f "$vendor" ] || continue
  dev=$(dirname "$vendor")
  if [ "$(cat "$vendor")" = 0cf2 ] && [ "$(cat "$dev/idProduct" 2>/dev/null)" = a100 ]; then
    hub=1
    break
  fi
done
if [ "$hub" -eq 0 ]; then
  echo "liquidctl: no Lian Li UNI FAN SL hub, skipped"
  exit 0
fi

if ! pacman -Q liquidctl >/dev/null 2>&1; then
  if pacman -Si liquidctl >/dev/null 2>&1; then
    sudo pacman -S --needed --noconfirm liquidctl || echo "liquidctl: pacman install failed, skipped"
  else
    echo "liquidctl: not in any configured repo, skipped"
  fi
fi
pacman -Q liquidctl >/dev/null 2>&1 || exit 0

changed=0
# Install a root:root 0644 copy only when content, owner or mode differ.
deploy() {
  local src=$MODULE/$1 dest=$ROOT$2
  if [ -f "$dest" ] && [ ! -L "$dest" ] && cmp -s "$src" "$dest" &&
    [ "$(stat -c '%u:%g:%a' -- "$dest")" = "0:0:644" ]; then
    return 0
  fi
  if sudo install -D -o root -g root -m 0644 -- "$src" "$dest"; then
    changed=1
  else
    echo "liquidctl: installing $2 failed, skipped"
  fi
}
deploy "systemd/$SERVICE" "/etc/systemd/system/$SERVICE"
deploy udev/rules.d/90-liquidctl-lianli-uni-sl.rules /etc/udev/rules.d/90-liquidctl-lianli-uni-sl.rules

# No change: no sudo prompt.
[ "$changed" -eq 1 ] || exit 0
sudo systemctl daemon-reload || echo "liquidctl: systemd daemon-reload failed"
sudo udevadm control --reload || echo "liquidctl: udev rules reload failed"
# Configure the hub now; afterwards udev starts the unit whenever the hub appears.
sudo systemctl start "$SERVICE" || echo "liquidctl: starting $SERVICE failed, hub not configured"
exit 0
