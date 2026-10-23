#!/usr/bin/env bash
# Install validated Linux sudoers policy, then converge udev, keymap and locale.
set -euo pipefail

# Never use USER (or a root process's environment) to select a grant recipient.
uid=$(/usr/bin/id -u)
if [ "$uid" -eq 0 ]; then
  echo "system: run bootstrap as the intended non-root account, not as root" >&2
  exit 1
fi

sudo bash --noprofile --norc -s -- "$uid" <<'SUDOERS'
set -euo pipefail
umask 077
policy=/etc/sudoers.d/techdufus
if [ -L "$policy" ] || { [ -e "$policy" ] && [ ! -f "$policy" ]; }; then
  echo "system: refusing to replace non-regular sudoers policy: $policy" >&2
  exit 1
fi

# Stage in the protected destination directory so validation and installation
# use the same root-owned bytes, with an atomic rename only after acceptance.
candidate=$(mktemp /etc/sudoers.d/.techdufus.XXXXXX)
trap 'rm -f -- "$candidate"' EXIT
printf '#%s ALL=(ALL) NOPASSWD: ALL\n' "$1" > "$candidate"
chown 0:0 "$candidate"
chmod 0440 "$candidate"
visudo -cf "$candidate"

if [ -f "$policy" ] && cmp -s "$candidate" "$policy" &&
  [ "$(stat -c '%u:%g:%a' -- "$policy")" = "0:0:440" ]; then
  exit 0
fi
mv -f -- "$candidate" "$policy"
SUDOERS

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
