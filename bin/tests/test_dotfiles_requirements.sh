#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
dotfiles_script="$repo_root/bin/dotfiles"

function_definition="$(
  python3 - "$dotfiles_script" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")
start = text.index("update_ansible_galaxy() {")
lines = text[start:].splitlines()
body = []
for line in lines:
    body.append(line)
    if len(body) > 1 and line == "}":
        break
else:
    raise SystemExit("update_ansible_galaxy function end not found")

print("\n".join(body))
PY
)"

eval "$function_definition"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

DOTFILES_DIR="$tmpdir/dotfiles"
mkdir -p "$DOTFILES_DIR/requirements"
: > "$DOTFILES_DIR/requirements/common.yml"
: > "$DOTFILES_DIR/requirements/arch.yml"

declare -a commands=()
declare -a task_labels=()

_cmd() { commands+=("$1"); }
__task() { task_labels+=("$1"); }

assert_eq() {
  local expected=$1
  local actual=$2
  local message=$3

  if [[ "$actual" != "$expected" ]]; then
    printf 'FAIL: %s\nexpected: %s\nactual:   %s\n' "$message" "$expected" "$actual" >&2
    exit 1
  fi
}

update_ansible_galaxy arch

expected_common="ansible-galaxy collection install -r \"$DOTFILES_DIR/requirements/common.yml\""
expected_arch="ansible-galaxy collection install -r \"$DOTFILES_DIR/requirements/arch.yml\""

assert_eq "2" "${#commands[@]}" "common and Arch requirements are installed separately"
assert_eq "$expected_common" "${commands[0]}" "common requirements command"
assert_eq "$expected_arch" "${commands[1]}" "Arch requirements command"
assert_eq "Installing Ansible dependencies from requirements/common.yml" "${task_labels[0]}" "common task label"
assert_eq "Installing Ansible dependencies from requirements/arch.yml" "${task_labels[1]}" "Arch task label"

commands=()
task_labels=()
rm "$DOTFILES_DIR/requirements/arch.yml"

update_ansible_galaxy arch

assert_eq "1" "${#commands[@]}" "missing OS requirements file is skipped"
assert_eq "$expected_common" "${commands[0]}" "common-only command"
