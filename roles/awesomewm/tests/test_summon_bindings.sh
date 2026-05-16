#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
apps_path="$repo_root/roles/awesomewm/files/config/cell-management/apps.lua"
keybindings_path="$repo_root/roles/awesomewm/files/config/cell-management/keybindings.lua"

grep -q 'Signal = {' "$apps_path"
grep -q 'summon = "C"' "$apps_path"
grep -q 'exec = "signal-desktop"' "$apps_path"

grep -q "local modifier_keys = {" "$keybindings_path"
grep -q "Shift_L = true" "$keybindings_path"
grep -q "Shift_R = true" "$keybindings_path"
grep -q "if modifier_keys\\[key\\] then" "$keybindings_path"
grep -q "binding_key_for_event(mod, key)" "$keybindings_path"
grep -q "return key:upper()" "$keybindings_path"
