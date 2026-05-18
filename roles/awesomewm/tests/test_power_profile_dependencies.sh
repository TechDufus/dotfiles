#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
tasks_path="$repo_root/roles/awesomewm/tasks/Ubuntu.yml"

grep -q "power-profiles-daemon" "$tasks_path"
