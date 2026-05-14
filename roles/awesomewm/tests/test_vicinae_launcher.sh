#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
config_path="$repo_root/roles/awesomewm/files/config/rc.lua"

grep -q "techdufus::launcher_root" "$config_path"
grep -q "techdufus::launcher_apps" "$config_path"
grep -q "techdufus::launcher_clipboard" "$config_path"
grep -q "techdufus::launcher_settings" "$config_path"
grep -q "techdufus::launch_flare" "$config_path"
grep -q "launch_vicinae_root" "$config_path"
grep -q "launch_rofi_apps" "$config_path"
grep -q "launch_copyq_clipboard" "$config_path"
grep -q "start_vicinae_server" "$config_path"
grep -q "vicinae://toggle" "$config_path"
grep -q "vicinae server --replace" "$config_path"
grep -q 'class = { "Vicinae", "vicinae" }' "$config_path"
grep -q 'instance = { "command", "Vicinae", "vicinae" }' "$config_path"
grep -q 'name = { "Vicinae Launcher", "Vicinae", "vicinae" }' "$config_path"
grep -q 'awful.placement.centered(c' "$config_path"

if grep -q "org.dev_byteatatime_flare.SingleInstance" "$config_path"; then
  echo "Flare DBus launcher path should not remain active in rc.lua" >&2
  exit 1
fi
