#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
config_path="$repo_root/roles/awesomewm/files/config/rc.lua"
layout_manager_path="$repo_root/roles/awesomewm/files/config/cell-management/layout-manager.lua"
tasks_path="$repo_root/roles/awesomewm/tasks/Ubuntu.yml"
defaults_path="$repo_root/roles/awesomewm/defaults/main.yml"

grep -q "techdufus::launcher_root" "$config_path"
grep -q "techdufus::launcher_apps" "$config_path"
grep -q "techdufus::launcher_clipboard" "$config_path"
grep -q "techdufus::launcher_emoji" "$config_path"
grep -q "techdufus::launcher_settings" "$config_path"
grep -q "techdufus::launch_flare" "$config_path"
grep -q "launch_vicinae_root" "$config_path"
grep -q "launch_vicinae_apps" "$config_path"
grep -q "launch_vicinae_clipboard" "$config_path"
grep -q "launch_vicinae_emoji" "$config_path"
grep -q "launch_vicinae_settings" "$config_path"
grep -q "start_vicinae_server" "$config_path"
grep -q "vicinae://toggle" "$config_path"
grep -q "vicinae://launch/applications?toggle=true" "$config_path"
grep -q "vicinae://launch/clipboard/history?toggle=true" "$config_path"
grep -q "vicinae://launch/core/search-emojis?toggle=true" "$config_path"
grep -q "vicinae://launch/scripts?fallbackText=settings&toggle=true" "$config_path"
grep -q "vicinae server --replace" "$config_path"
grep -q "Run dotfiles -t vicinae" "$config_path"
grep -q 'class = { "Vicinae", "vicinae" }' "$config_path"
grep -q 'instance = { "command", "Vicinae", "vicinae" }' "$config_path"
grep -q 'name = { "Vicinae Launcher", "Vicinae", "vicinae" }' "$config_path"
grep -q 'awful.placement.centered(c' "$config_path"

if grep -q "org.dev_byteatatime_flare.SingleInstance" "$config_path"; then
  echo "Flare DBus launcher path should not remain active in rc.lua" >&2
  exit 1
fi

if grep -Eq "\\b(rofi|copyq|bemoji|rofimoji)\\b" "$config_path" "$layout_manager_path"; then
  echo "Legacy rofi/CopyQ/bemoji runtime references should not remain" >&2
  exit 1
fi

if grep -Eq "Install bemoji|Download bemoji|Deploy rofi|Deploy CopyQ|rofi[[:space:]]+#|copyq[[:space:]]+#" "$tasks_path"; then
  echo "Legacy rofi/CopyQ/bemoji install or deploy tasks should not remain" >&2
  exit 1
fi

grep -q "awesomewm_remove_legacy_launcher_tools: true" "$defaults_path"
grep -q "awesomewm_legacy_launcher_packages:" "$defaults_path"
grep -q "rofi" "$defaults_path"
grep -q "copyq" "$defaults_path"
grep -q "bemoji" "$defaults_path"
grep -q "awful.keygrabber" "$layout_manager_path"
grep -q "function M.bind_to_cell(cell_index)" "$layout_manager_path"
grep -q "move_client_to_cell" "$layout_manager_path"

keybindings_path="$repo_root/roles/awesomewm/files/config/cell-management/keybindings.lua"
grep -q "techdufus::launcher_emoji" "$keybindings_path"
grep -q "techdufus::launcher_settings" "$keybindings_path"
