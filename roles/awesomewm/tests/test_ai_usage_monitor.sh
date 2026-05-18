#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
script_path="$repo_root/roles/awesomewm/files/scripts/ai-usage-monitor.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

export HOME="$tmpdir/home"
export AI_USAGE_MONITOR_TEST_MODE=1
mkdir -p "$HOME"

# shellcheck source=/dev/null
source "$script_path"

assert_json() {
  local json="$1"
  local jq_filter="$2"
  local expected="$3"
  local actual
  actual="$(jq -r "$jq_filter" <<< "$json")"
  if [[ "$actual" != "$expected" ]]; then
    printf 'expected %s => %s, got %s\n' "$jq_filter" "$expected" "$actual" >&2
    exit 1
  fi
}

mkdir -p "$CACHE_DIR"

printf 'codex\n' > "$PROVIDER_FILE"
[[ "$(selected_provider)" == "codex" ]]
printf 'claude\n' > "$PROVIDER_FILE"
[[ "$(selected_provider)" == "claude" ]]
printf 'bogus\n' > "$PROVIDER_FILE"
[[ "$(selected_provider)" == "codex" ]]

codex_output="$(build_output_for_provider "codex" '{"available":true,"session":{"utilization":17,"resets_at":"2026-05-13T18:01:40Z"},"weekly":null,"error":null}' '[]')"
assert_json "$codex_output" '.active_provider' 'codex'
assert_json "$codex_output" '.codex.available' 'true'
assert_json "$codex_output" '.codex.session.utilization' '17'
assert_json "$codex_output" '.claude.available' 'false'
assert_json "$codex_output" '.claude.error' 'inactive'
assert_json "$codex_output" '.errors | length' '0'

claude_output="$(build_output_for_provider "claude" '{"available":true,"five_hour":{"utilization":12,"resets_at":"2026-05-13T18:01:40Z"},"seven_day":null,"seven_day_opus":null,"seven_day_sonnet":null,"extra_usage":null,"error":null}' '[]')"
assert_json "$claude_output" '.active_provider' 'claude'
assert_json "$claude_output" '.claude.available' 'true'
assert_json "$claude_output" '.claude.five_hour.utilization' '12'
assert_json "$claude_output" '.codex.available' 'false'
assert_json "$claude_output" '.codex.error' 'inactive'

codex_error="$(build_error_output_for_provider "codex" "codex_rate_limits_not_found")"
assert_json "$codex_error" '.active_provider' 'codex'
assert_json "$codex_error" '.codex.error' 'codex_rate_limits_not_found'
assert_json "$codex_error" '.claude.error' 'inactive'
assert_json "$codex_error" '.errors[0]' 'codex_rate_limits_not_found'

claude_error="$(build_error_output_for_provider "claude" "token_expired")"
assert_json "$claude_error" '.active_provider' 'claude'
assert_json "$claude_error" '.claude.error' 'token_expired'
assert_json "$claude_error" '.codex.error' 'inactive'
assert_json "$claude_error" '.errors[0]' 'token_expired'

stable_status='{"active_provider":"codex","codex":{"available":true,"session":{"utilization":5},"weekly":null,"error":null},"claude":{"available":false,"error":"inactive"},"errors":[]}'
printf '%s\n' "$stable_status" > "$STATUS_FILE"
( cleanup )
[[ "$(cat "$STATUS_FILE")" == "$stable_status" ]]
