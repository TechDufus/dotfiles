#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
role_dir="$repo_root/roles/signal"
flatpak_tasks="$repo_root/roles/flatpak/tasks/Ubuntu.yml"
apps_path="$repo_root/roles/awesomewm/files/config/cell-management/apps.lua"
defaults_path="$repo_root/group_vars/all.yml"

grep -q "include_tasks" "$role_dir/tasks/main.yml"
grep -q "updates.signal.org/desktop/apt/keys.asc" "$role_dir/tasks/Ubuntu.yml"
grep -q "updates.signal.org/static/desktop/apt/signal-desktop.sources" "$role_dir/tasks/Ubuntu.yml"
grep -q "signal-desktop-keyring.gpg" "$role_dir/tasks/Ubuntu.yml"
grep -q "name: signal-desktop" "$role_dir/tasks/Ubuntu.yml"
grep -q "name: org.signal.Signal" "$role_dir/tasks/Ubuntu.yml"
grep -q "state: absent" "$role_dir/tasks/Ubuntu.yml"
grep -q "  - signal" "$defaults_path"
grep -q 'exec = "signal-desktop"' "$apps_path"

if grep -q "org.signal.Signal" "$flatpak_tasks"; then
  echo "Signal should be installed by the signal role, not the Flatpak role" >&2
  exit 1
fi
