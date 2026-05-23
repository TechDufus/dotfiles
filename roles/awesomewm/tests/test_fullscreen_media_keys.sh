#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
config_path="$repo_root/roles/awesomewm/files/config/rc.lua"

python3 - "$config_path" <<'PY'
import sys
from pathlib import Path

config = Path(sys.argv[1]).read_text()

required_helpers = [
    "local function restore_fullscreen_client(c)",
    "local function run_preserving_fullscreen(action)",
    "fullscreen-system-key",
    "gears.timer.start_new(0.15, restore)",
    "gears.timer.start_new(0.60, restore)",
    "local function should_lock_fullscreen_pointer(c)",
    "local function confine_pointer_to_screen(s)",
    "fullscreen_pointer_lock_timer = gears.timer({",
    "timeout = 0.02",
    "mouse.coords({ x = x, y = y })",
]
for helper in required_helpers:
    if helper not in config:
        raise SystemExit(f"missing fullscreen helper: {helper}")

media_keys = [
    "XF86AudioRaiseVolume",
    "XF86AudioLowerVolume",
    "XF86AudioMute",
    "XF86AudioMicMute",
    "XF86MonBrightnessUp",
    "XF86MonBrightnessDown",
    "XF86AudioPlay",
    "XF86AudioPause",
    "XF86AudioNext",
    "XF86AudioPrev",
    "XF86AudioStop",
]

for key in media_keys:
    start = config.find(f'awful.key({{}}, "{key}", function()')
    if start == -1:
        raise SystemExit(f"missing media binding: {key}")
    end = config.find('end, { description', start)
    if end == -1:
        raise SystemExit(f"malformed media binding: {key}")
    block = config[start:end]
    if "run_preserving_fullscreen(function()" not in block:
        raise SystemExit(f"media binding does not preserve fullscreen focus: {key}")

for signal in [
    'client.connect_signal("focus", update_fullscreen_pointer_lock)',
    'client.connect_signal("unfocus", update_fullscreen_pointer_lock)',
    'client.connect_signal("unmanage", update_fullscreen_pointer_lock)',
    'client.connect_signal("property::fullscreen", update_fullscreen_pointer_lock)',
    'client.connect_signal("property::hidden", update_fullscreen_pointer_lock)',
    'client.connect_signal("property::minimized", update_fullscreen_pointer_lock)',
    'screen.connect_signal("property::geometry", update_fullscreen_pointer_lock)',
]:
    if signal not in config:
        raise SystemExit(f"missing fullscreen pointer-lock signal: {signal}")
PY
