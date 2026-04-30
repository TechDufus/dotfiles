#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
CONFIG_DIR="$ROOT_DIR/roles/hammerspoon/files/config"
INIT_LUA="$CONFIG_DIR/init.lua"
KARABINER_CONFIG="$ROOT_DIR/roles/hammerspoon/files/karabiner/karabiner.json"
DEFAULTS="$ROOT_DIR/roles/hammerspoon/defaults/main.yml"

fail() {
  echo "not ok - $*" >&2
  exit 1
}

assert_not_contains() {
  local file="$1"
  local needle="$2"

  if grep -Fq "$needle" "$file"; then
    fail "expected $file not to contain: $needle"
  fi
}

assert_contains() {
  local file="$1"
  local needle="$2"

  if ! grep -Fq "$needle" "$file"; then
    fail "expected $file to contain: $needle"
  fi
}

if [[ -e "$CONFIG_DIR/karabiner.lua" ]]; then
  fail "Hammerspoon must not ship a Karabiner service restarter"
fi

assert_not_contains "$INIT_LUA" "require('karabiner').start()"
assert_contains "$DEFAULTS" "karabiner.lua"
assert_contains "$KARABINER_CONFIG" '"key_code": "caps_lock"'
assert_contains "$KARABINER_CONFIG" '"key_code": "f13"'

if grep -R --line-number 'launchctl kickstart -k' "$CONFIG_DIR"; then
  fail "Hammerspoon config must not kill/restart Karabiner services"
fi

echo "ok - Hammerspoon leaves Karabiner service lifecycle to Karabiner"
