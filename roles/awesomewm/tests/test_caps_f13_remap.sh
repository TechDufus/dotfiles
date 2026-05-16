#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
script_path="$repo_root/roles/awesomewm/files/scripts/remap-caps-to-f13.sh"
config_path="$repo_root/roles/awesomewm/files/config/rc.lua"
tasks_path="$repo_root/roles/awesomewm/tasks/Ubuntu.yml"

bash -n "$script_path"

grep -q "xmodmap -e 'keycode 66 = F13'" "$script_path"
grep -q "setxkbmap -option" "$script_path"
grep -q "Caps Lock:" "$script_path"
grep -q "xdotool key Caps_Lock" "$script_path"
grep -q "localectl_field \"X11 Layout\"" "$script_path"
grep -q "setxkbmap_field \"layout\"" "$script_path"
grep -q "remap-caps-to-f13.sh" "$config_path"
grep -q "Deploy CapsLock to F13 remap script" "$tasks_path"
grep -q "scripts/remap-caps-to-f13.sh" "$tasks_path"
