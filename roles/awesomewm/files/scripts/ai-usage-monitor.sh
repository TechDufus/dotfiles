#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# AI Usage Monitor
# Polls the Claude OAuth usage API and writes a status JSON file for
# consumption by desktop widgets (AwesomeWM, Waybar, etc.).
# ---------------------------------------------------------------------------

POLL_INTERVAL="${POLL_INTERVAL:-60}"
CACHE_DIR="$HOME/.cache/ai-usage-monitor"
STATUS_FILE="$CACHE_DIR/status.json"
CREDENTIALS_FILE="$HOME/.claude/.credentials.json"
API_URL="https://api.anthropic.com/api/oauth/usage"

# ---------------------------------------------------------------------------
# Logging helper – all output goes to stderr with a timestamp
# ---------------------------------------------------------------------------
log() {
  printf '%s [ai-usage-monitor] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2
}

# ---------------------------------------------------------------------------
# Write JSON atomically (tmp + mv)
# ---------------------------------------------------------------------------
write_status() {
  local json="$1"
  local tmp
  tmp="$(mktemp "$CACHE_DIR/.status.XXXXXX.json")"
  printf '%s\n' "$json" > "$tmp"
  mv -f "$tmp" "$STATUS_FILE"
}

# ---------------------------------------------------------------------------
# Build the codex section (always unavailable – codexbar not installed)
# ---------------------------------------------------------------------------
codex_section() {
  cat <<'CODEX'
{"available":false,"session":null,"weekly":null,"error":"codexbar_not_installed"}
CODEX
}

# ---------------------------------------------------------------------------
# Build an error state for the claude section
# ---------------------------------------------------------------------------
claude_error_section() {
  local err="$1"
  printf '{"available":false,"five_hour":null,"seven_day":null,"seven_day_opus":null,"seven_day_sonnet":null,"extra_usage":null,"error":"%s"}' "$err"
}

# ---------------------------------------------------------------------------
# Build the full output envelope
# ---------------------------------------------------------------------------
build_output() {
  local claude_json="$1"
  local errors_json="${2:-[]}"
  local ts
  ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  local codex
  codex="$(codex_section)"
  jq -n \
    --arg ts "$ts" \
    --argjson claude "$claude_json" \
    --argjson codex "$codex" \
    --argjson errors "$errors_json" \
    '{timestamp:$ts,claude:$claude,codex:$codex,errors:$errors}'
}

# ---------------------------------------------------------------------------
# Write an unavailable / error state and optionally exit
# ---------------------------------------------------------------------------
write_error_state() {
  local err="$1"
  local claude
  claude="$(claude_error_section "$err")"
  local output
  output="$(build_output "$claude" "[\"$err\"]")"
  write_status "$output"
}

# ---------------------------------------------------------------------------
# Clean shutdown on SIGTERM / SIGINT
# ---------------------------------------------------------------------------
shutting_down=false
cleanup() {
  if "$shutting_down"; then
    return
  fi
  shutting_down=true
  log "Caught signal, shutting down..."
  write_error_state "monitor_stopped"
  log "Wrote final unavailable state. Exiting."
  exit 0
}
trap cleanup SIGTERM SIGINT

# ---------------------------------------------------------------------------
# Parse the API response into the claude JSON section
# ---------------------------------------------------------------------------
parse_usage_response() {
  local body="$1"

  # Use jq to transform the API response into our output format.
  # The API returns flat top-level fields with snake_case keys:
  #   .five_hour, .seven_day, .seven_day_opus, .seven_day_sonnet, .extra_usage
  # Each limit (when not null) has: utilization, resets_at
  # extra_usage (when not null) has: is_enabled, monthly_limit, used_credits, utilization
  jq -r '
    def fmt_limit:
      if . == null then null
      else {
        utilization: (.utilization // 0),
        resets_at:   (.resets_at // null)
      }
      end;

    def fmt_extra:
      if . == null then null
      else {
        is_enabled:    (.is_enabled // false),
        monthly_limit: (.monthly_limit // null),
        used_credits:  (.used_credits // 0),
        utilization:   (.utilization // 0)
      }
      end;

    {
      available:        true,
      five_hour:        (.five_hour        | fmt_limit),
      seven_day:        (.seven_day        | fmt_limit),
      seven_day_opus:   (.seven_day_opus   | fmt_limit),
      seven_day_sonnet: (.seven_day_sonnet | fmt_limit),
      extra_usage:      (.extra_usage      | fmt_extra),
      error:            null
    }
  ' <<< "$body"
}

# ---------------------------------------------------------------------------
# Main polling loop
# ---------------------------------------------------------------------------
main() {
  mkdir -p "$CACHE_DIR"
  log "Starting AI usage monitor (poll every ${POLL_INTERVAL}s)"
  log "Status file: $STATUS_FILE"

  local token expires_at now_ms response http_code body claude_json output
  local curl_ok

  while true; do
    # -- 1. Read credentials fresh every cycle --------------------------------
    if [[ ! -f "$CREDENTIALS_FILE" ]]; then
      log "Credentials file not found: $CREDENTIALS_FILE"
      write_error_state "credentials_not_found"
      sleep "$POLL_INTERVAL" &
      wait $! || true
      continue
    fi

    token="$(jq -r '.claudeAiOauth.accessToken // empty' "$CREDENTIALS_FILE" 2>/dev/null || true)"
    if [[ -z "$token" ]]; then
      log "No access token found in credentials file"
      write_error_state "no_access_token"
      sleep "$POLL_INTERVAL" &
      wait $! || true
      continue
    fi

    # -- 2. Check token expiry -----------------------------------------------
    expires_at="$(jq -r '.claudeAiOauth.expiresAt // "0"' "$CREDENTIALS_FILE" 2>/dev/null || echo "0")"
    now_ms="$(date +%s)000"
    if (( now_ms >= expires_at )); then
      log "Access token has expired (expiresAt=${expires_at}, now=${now_ms})"
      write_error_state "token_expired"
      sleep "$POLL_INTERVAL" &
      wait $! || true
      continue
    fi

    # -- 3. Call the usage API -----------------------------------------------
    curl_ok=true
    response="$(curl -s -w "\n%{http_code}" --max-time 15 \
      -H "Authorization: Bearer ${token}" \
      -H "anthropic-beta: oauth-2025-04-20" \
      "$API_URL" 2>/dev/null)" || curl_ok=false

    if [[ "$curl_ok" == "false" ]]; then
      log "curl failed (network error)"
      write_error_state "network_error"
      sleep "$POLL_INTERVAL" &
      wait $! || true
      continue
    fi

    # Split body and HTTP status code
    http_code="$(tail -n1 <<< "$response")"
    body="$(sed '$d' <<< "$response")"

    if [[ "$http_code" != "200" ]]; then
      log "API returned HTTP $http_code"
      write_error_state "api_error_${http_code}"
      sleep "$POLL_INTERVAL" &
      wait $! || true
      continue
    fi

    # -- 4. Parse the response -----------------------------------------------
    claude_json="$(parse_usage_response "$body" 2>/dev/null)" || {
      log "Failed to parse API response"
      write_error_state "json_parse_error"
      sleep "$POLL_INTERVAL" &
      wait $! || true
      continue
    }

    if [[ -z "$claude_json" || "$claude_json" == "null" ]]; then
      log "jq produced empty output"
      write_error_state "json_parse_error"
      sleep "$POLL_INTERVAL" &
      wait $! || true
      continue
    fi

    # -- 5. Build and write the final status file ----------------------------
    output="$(build_output "$claude_json" "[]")"
    write_status "$output"
    log "Status updated successfully"

    # Sleep in background so trap can fire immediately
    sleep "$POLL_INTERVAL" &
    wait $! || true
  done
}

main
