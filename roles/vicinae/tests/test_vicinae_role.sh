#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
role_dir="$repo_root/roles/vicinae"

grep -q "vicinae_prefix: /usr/local" "$role_dir/defaults/main.yml"
grep -q "vicinae_install_input_server: true" "$role_dir/defaults/main.yml"
grep -q "https://api.github.com/repos/{{ vicinae_repo }}/releases/latest" "$role_dir/tasks/Ubuntu.yml"
grep -q "vicinae_appimage_asset_regex" "$role_dir/tasks/Ubuntu.yml"
grep -q "cap_dac_override=ep" "$role_dir/tasks/Ubuntu.yml"
grep -q "vicinae_enable_user_service" "$role_dir/tasks/Ubuntu.yml"
grep -q '"./dotfiles.json"' "$role_dir/templates/settings.json.j2"
grep -q '"search_files_in_root": false' "$role_dir/templates/dotfiles.json.j2"
grep -q '"favicon_service": "none"' "$role_dir/templates/dotfiles.json.j2"

for script in "$role_dir"/files/scripts/*; do
  grep -q "@vicinae.schemaVersion 1" "$script"
  grep -q "@vicinae.title" "$script"
  grep -q "@vicinae.mode" "$script"
  bash -n "$script"
done
