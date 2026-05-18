#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
ubuntu_tasks="$repo_root/roles/1password/tasks/Ubuntu.yml"

grep -q "name:" "$ubuntu_tasks"
grep -q "1password-cli" "$ubuntu_tasks"
grep -q -- "- 1password$" "$ubuntu_tasks"
