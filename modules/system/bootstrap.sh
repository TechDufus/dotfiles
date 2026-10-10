#!/usr/bin/env bash
# Validate sudoers, apply the udev rule, and converge keymap/locale via localectl.
set -euo pipefail

sudo visudo -cf /etc/sudoers.d/techdufus || exit 1

sudo udevadm control --reload-rules
sudo udevadm trigger --action=add --subsystem-match=usb --attr-match=idVendor=046d --attr-match=idProduct=c548
sudo udevadm settle

if ! status=$(localectl status 2>/dev/null); then
  echo "system: localectl unavailable, keyboard and locale skipped"
  exit 0
fi

field() { printf '%s\n' "$status" | sed -n "s/^[[:space:]]*$1:[[:space:]]*//p" | head -n 1; }

if [ "$(field 'VC Keymap')" != "dvorak" ]; then
  sudo localectl set-keymap dvorak
fi

if [ "$(field 'X11 Layout')" != "us" ] || [ "$(field 'X11 Model')" != "pc105" ] ||
  [ "$(field 'X11 Variant')" != "dvorak" ] || [ "$(field 'X11 Options')" != "caps:none" ]; then
  sudo localectl set-x11-keymap us pc105 dvorak caps:none
fi

if [ "$(field 'System Locale')" != "LANG=en_US.UTF-8" ]; then
  sudo localectl set-locale LANG=en_US.UTF-8
fi
