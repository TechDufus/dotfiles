#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
config_path="$repo_root/roles/awesomewm/files/config/rc.lua"

grep -q "techdufus::launch_flare" "$config_path"
grep -q "launch_flare_centered" "$config_path"
grep -q "center_flare_clients" "$config_path"
grep -q "org.dev_byteatatime_flare.SingleInstance" "$config_path"
grep -q "ExecuteCallback" "$config_path"
grep -q "awful.spawn.easy_async" "$config_path"
grep -q "awful.spawn(flare_launcher_command)" "$config_path"
grep -q "awful.placement.centered(c" "$config_path"
grep -q 'class = { "Flare" }' "$config_path"
