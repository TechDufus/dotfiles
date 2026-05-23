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

codex_usage_payload='{"plan_type":"pro","rate_limit":{"primary_window":{"used_percent":23,"limit_window_seconds":18000,"reset_at":1779163225},"secondary_window":{"used_percent":15,"limit_window_seconds":604800,"reset_at":1779571181}}}'
codex_usage_json="$(codex_json_from_usage_response "$codex_usage_payload")"
assert_json "$codex_usage_json" '.error // "ok"' 'ok'
assert_json "$codex_usage_json" '.session.utilization' '23'
assert_json "$codex_usage_json" '.weekly.utilization' '15'
assert_json "$codex_usage_json" '.session.resets_at' '2026-05-19T04:00:25Z'
assert_json "$codex_usage_json" '.weekly.resets_at' '2026-05-23T21:19:41Z'

session_dir="$HOME/.codex/sessions/2026/05/16"
mkdir -p "$session_dir"
older_session="$session_dir/rollout-2026-05-16T15-47-40-older.jsonl"
newer_session="$session_dir/rollout-2026-05-16T15-31-40-newer.jsonl"
printf '%s\n' '{"type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","primary":{"used_percent":0},"secondary":{"used_percent":0}}}}' > "$older_session"
printf '%s\n' '{"type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","primary":{"used_percent":0},"secondary":{"used_percent":10}}}}' > "$newer_session"
touch -d '2026-05-16 20:54:11 UTC' "$older_session"
touch -d '2026-05-18 23:08:53 UTC' "$newer_session"
latest_codex_rate="$(find_codex_rate_limits)"
assert_json "$latest_codex_rate" '.secondary.used_percent' '10'

printf '{"tokens":{"access_token":"expired-token","account_id":"test-account"}}\n' > "$CODEX_AUTH_FILE"
mock_bin="$tmpdir/bin"
mkdir -p "$mock_bin"
cat > "$mock_bin/curl" <<'SH'
#!/usr/bin/env bash
printf '{"error":{"code":"token_expired"}}\n401'
SH
chmod +x "$mock_bin/curl"
codex_api_error="$(PATH="$mock_bin:$PATH" codex_section)"
assert_json "$codex_api_error" '.available' 'false'
assert_json "$codex_api_error" '.error' 'codex_token_expired'

printf '{"tokens":{"access_token":"expired-token","refresh_token":"refresh-token","account_id":"test-account"}}\n' > "$CODEX_AUTH_FILE"
mock_refresh_bin="$tmpdir/bin-refresh"
mock_state_dir="$tmpdir/mock-state"
mkdir -p "$mock_refresh_bin" "$mock_state_dir"
cat > "$mock_refresh_bin/curl" <<'SH'
#!/usr/bin/env bash
last_arg="${*: -1}"
if [[ "$last_arg" == *"/oauth/token" ]]; then
  printf '{"access_token":"fresh-token","refresh_token":"fresh-refresh"}\n200'
elif [[ -f "$MOCK_STATE_DIR/usage-retried" ]]; then
  printf '{"plan_type":"pro","rate_limit":{"primary_window":{"used_percent":31,"reset_after_seconds":60},"secondary_window":{"used_percent":9,"reset_after_seconds":120}}}\n200'
else
  touch "$MOCK_STATE_DIR/usage-retried"
  printf '{"error":{"code":"token_expired"}}\n401'
fi
SH
chmod +x "$mock_refresh_bin/curl"
codex_refreshed="$(MOCK_STATE_DIR="$mock_state_dir" PATH="$mock_refresh_bin:$PATH" codex_section)"
assert_json "$codex_refreshed" '.available' 'true'
assert_json "$codex_refreshed" '.session.utilization' '31'
assert_json "$codex_refreshed" '.weekly.utilization' '9'
auth_after_refresh="$(jq -c . "$CODEX_AUTH_FILE")"
assert_json "$auth_after_refresh" '.tokens.access_token' 'fresh-token'
assert_json "$auth_after_refresh" '.tokens.refresh_token' 'fresh-refresh'

stable_status='{"active_provider":"codex","codex":{"available":true,"session":{"utilization":5},"weekly":null,"error":null},"claude":{"available":false,"error":"inactive"},"errors":[]}'
printf '%s\n' "$stable_status" > "$STATUS_FILE"
( cleanup )
[[ "$(cat "$STATUS_FILE")" == "$stable_status" ]]
