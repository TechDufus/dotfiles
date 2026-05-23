#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# AI Usage Monitor
# Polls the currently selected AI provider, then writes a status JSON file
# for consumption by desktop widgets (AwesomeWM, Waybar, etc.).
# ---------------------------------------------------------------------------

POLL_INTERVAL="${POLL_INTERVAL:-60}"
CACHE_DIR="$HOME/.cache/ai-usage-monitor"
STATUS_FILE="$CACHE_DIR/status.json"
PROVIDER_FILE="$CACHE_DIR/provider.txt"
CREDENTIALS_FILE="$HOME/.claude/.credentials.json"
API_URL="https://api.anthropic.com/api/oauth/usage"
CODEX_AUTH_FILE="$HOME/.codex/auth.json"
CODEX_API_URL="https://chatgpt.com/backend-api/wham/usage"
CODEX_REFRESH_URL="https://auth.openai.com/oauth/token"
CODEX_CLIENT_ID="app_EMoamEEZ73f0CkXaXp7hrann"

# ---------------------------------------------------------------------------
# Logging helper – all output goes to stderr with a timestamp
# ---------------------------------------------------------------------------
log() {
  printf '%s [ai-usage-monitor] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2
}

# ---------------------------------------------------------------------------
# Active provider helpers
# ---------------------------------------------------------------------------
normalize_provider() {
  local provider="${1:-codex}"
  case "$provider" in
    claude|codex)
      printf '%s\n' "$provider"
      ;;
    *)
      printf 'codex\n'
      ;;
  esac
}

selected_provider() {
  local provider
  if [[ -f "$PROVIDER_FILE" ]]; then
    provider="$(head -n1 "$PROVIDER_FILE" 2>/dev/null || true)"
  else
    provider="codex"
  fi
  normalize_provider "$provider"
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
# Codex usage collection
# Reads the latest Codex session token_count events from ~/.codex/sessions and
# maps primary/secondary rate limits into session/weekly widget windows.
# ---------------------------------------------------------------------------
find_codex_rate_limits() {
  local session_dir="$HOME/.codex/sessions"
  local file rate
  local -a session_files=()

  if [[ ! -d "$session_dir" ]]; then
    return 1
  fi

  # Sessions can be resumed, so filename time is not necessarily the newest
  # usage sample. Sort by mtime and inspect the most recently written files first.
  mapfile -t session_files < <(
    find "$session_dir" -type f -name '*.jsonl' -printf '%T@\t%p\n' 2>/dev/null |
      LC_ALL=C sort -nr |
      cut -f2-
  )
  if [[ ${#session_files[@]} -eq 0 ]]; then
    return 1
  fi

  for file in "${session_files[@]}"; do
    rate="$(jq -cs '
      (
        [
          .[]
          | select(.type == "event_msg")
          | select(.payload.type == "token_count")
          | (.payload.info.rate_limits // .payload.rate_limits)
          | select(.limit_id == "codex")
        ]
        | last
      ) // (
        [
          .[]
          | select(.type == "event_msg")
          | select(.payload.type == "token_count")
          | (.payload.info.rate_limits // .payload.rate_limits)
          | select((.primary != null) or (.secondary != null))
        ]
        | last
      )
    ' "$file" 2>/dev/null || true)"

    if [[ -n "$rate" && "$rate" != "null" ]]; then
      printf '%s\n' "$rate"
      return 0
    fi
  done

  return 1
}

codex_json_from_usage_response() {
  local body="$1"

  jq -n \
    --argjson usage "$body" '
      def reset_epoch($w):
        if $w.reset_at != null then
          ($w.reset_at | tonumber)
        elif $w.reset_after_seconds != null then
          (now + ($w.reset_after_seconds | tonumber))
        else
          null
        end;

      def fmt_window($w):
        if ($w | type) != "object" then
          null
        else
          {
            utilization: ($w.used_percent // null),
            resets_at: (
              reset_epoch($w) as $reset
              | if $reset == null then
                  null
                else
                  ($reset | gmtime | strftime("%Y-%m-%dT%H:%M:%SZ"))
                end
            )
          }
        end;

      {
        available: true,
        session: (fmt_window($usage.rate_limit.primary_window)),
        weekly: (fmt_window($usage.rate_limit.secondary_window)),
        plan_type: ($usage.plan_type // null),
        error: null
      }
    '
}

codex_api_error_name() {
  local http_code="$1"
  local body="${2:-}"
  local api_code

  api_code="$(jq -r '.error.code // .code // empty' <<< "$body" 2>/dev/null || true)"
  case "$api_code" in
    token_expired)
      printf 'codex_token_expired\n'
      ;;
    invalid_api_key|unauthorized|forbidden)
      printf 'codex_%s\n' "$api_code"
      ;;
    *)
      printf 'codex_api_%s\n' "$http_code"
      ;;
  esac
}

refresh_codex_token() {
  local refresh_token request response http_code body access_token new_refresh_token id_token tmp last_refresh

  refresh_token="$(jq -r '.tokens.refresh_token // empty' "$CODEX_AUTH_FILE" 2>/dev/null || true)"
  if [[ -z "$refresh_token" ]]; then
    return 1
  fi

  request="$(jq -n \
    --arg client_id "$CODEX_CLIENT_ID" \
    --arg refresh_token "$refresh_token" \
    '{client_id:$client_id,grant_type:"refresh_token",refresh_token:$refresh_token}')"
  response="$(printf '%s' "$request" | curl -s -w "\n%{http_code}" --max-time 15 \
    -H "Content-Type: application/json" \
    --data @- \
    "$CODEX_REFRESH_URL" 2>/dev/null)" || return 1
  http_code="$(tail -n1 <<< "$response")"
  body="$(sed '$d' <<< "$response")"
  if [[ "$http_code" != "200" || -z "$body" ]]; then
    return 1
  fi

  access_token="$(jq -r '.access_token // empty' <<< "$body" 2>/dev/null || true)"
  if [[ -z "$access_token" ]]; then
    return 1
  fi
  new_refresh_token="$(jq -r '.refresh_token // empty' <<< "$body" 2>/dev/null || true)"
  id_token="$(jq -r '.id_token // empty' <<< "$body" 2>/dev/null || true)"
  last_refresh="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  tmp="$(mktemp "${CODEX_AUTH_FILE}.XXXXXX")" || return 1

  if jq \
    --arg access_token "$access_token" \
    --arg refresh_token "$new_refresh_token" \
    --arg id_token "$id_token" \
    --arg last_refresh "$last_refresh" \
    '
      .tokens.access_token = $access_token
      | if $refresh_token != "" then .tokens.refresh_token = $refresh_token else . end
      | if $id_token != "" then .tokens.id_token = $id_token else . end
      | .last_refresh = $last_refresh
    ' "$CODEX_AUTH_FILE" > "$tmp"; then
    chmod 600 "$tmp"
    mv -f "$tmp" "$CODEX_AUTH_FILE"
    return 0
  fi

  rm -f "$tmp"
  return 1
}

codex_section_from_api() {
  local token account response http_code body codex_json attempt
  local -a headers

  if [[ ! -f "$CODEX_AUTH_FILE" ]]; then
    return 1
  fi

  for attempt in 0 1; do
    token="$(jq -r '.tokens.access_token // empty' "$CODEX_AUTH_FILE" 2>/dev/null || true)"
    if [[ -z "$token" ]]; then
      return 1
    fi

    account="$(jq -r '.tokens.account_id // empty' "$CODEX_AUTH_FILE" 2>/dev/null || true)"
    headers=(
      -H "Authorization: Bearer ${token}"
      -H "User-Agent: OpenCode-Status-Plugin/1.0"
    )
    if [[ -n "$account" ]]; then
      headers+=(-H "ChatGPT-Account-Id: ${account}")
    fi

    response="$(curl -s -w "\n%{http_code}" --max-time 15 "${headers[@]}" "$CODEX_API_URL" 2>/dev/null)" || return 1
    http_code="$(tail -n1 <<< "$response")"
    body="$(sed '$d' <<< "$response")"

    if [[ "$http_code" == "200" ]]; then
      break
    fi

    if [[ "$http_code" == "401" && "$attempt" -eq 0 ]] && refresh_codex_token; then
      continue
    fi

    codex_error_section "$(codex_api_error_name "$http_code" "$body")"
    return 0
  done

  if [[ -z "$body" ]]; then
    return 1
  fi

  codex_json="$(codex_json_from_usage_response "$body" 2>/dev/null || true)"
  if [[ -z "$codex_json" || "$codex_json" == "null" ]]; then
    return 1
  fi

  printf '%s\n' "$codex_json"
}


codex_section() {
  local rate_limits codex_json

  codex_json="$(codex_section_from_api 2>/dev/null || true)"
  if [[ -n "$codex_json" && "$codex_json" != "null" ]]; then
    printf '%s\n' "$codex_json"
    return
  fi
  rate_limits="$(find_codex_rate_limits 2>/dev/null || true)"
  if [[ -z "$rate_limits" || "$rate_limits" == "null" ]]; then
    cat <<'CODEX'
{"available":false,"session":null,"weekly":null,"error":"codex_rate_limits_not_found"}
CODEX
    return
  fi

  codex_json="$(jq -n \
    --argjson rate "$rate_limits" '
      def fmt_window($w):
        if ($w | type) != "object" then
          null
        else
          {
            utilization: ($w.used_percent // null),
            resets_at: (
              if $w.resets_at == null then
                null
              else
                ($w.resets_at | tonumber | gmtime | strftime("%Y-%m-%dT%H:%M:%SZ"))
              end
            )
          }
        end;

      {
        available: true,
        session: (fmt_window($rate.primary)),
        weekly: (fmt_window($rate.secondary)),
        error: null
      }
    ' 2>/dev/null || true)"

  if [[ -z "$codex_json" || "$codex_json" == "null" ]]; then
    cat <<'CODEX'
{"available":false,"session":null,"weekly":null,"error":"codex_parse_error"}
CODEX
    return
  fi

  printf '%s\n' "$codex_json"
}

# ---------------------------------------------------------------------------
# Build an error state for the claude section
# ---------------------------------------------------------------------------
claude_error_section() {
  local err="$1"
  printf '{"available":false,"five_hour":null,"seven_day":null,"seven_day_opus":null,"seven_day_sonnet":null,"extra_usage":null,"error":"%s"}' "$err"
}

inactive_claude_section() {
  claude_error_section "inactive"
}

codex_error_section() {
  local err="$1"
  printf '{"available":false,"session":null,"weekly":null,"error":"%s"}' "$err"
}

inactive_codex_section() {
  codex_error_section "inactive"
}

# ---------------------------------------------------------------------------
# Build the full output envelope
# ---------------------------------------------------------------------------
build_output_for_provider() {
  local provider active_json errors_json ts claude_json codex_json
  provider="$(normalize_provider "${1:-codex}")"
  active_json="$2"
  errors_json="${3:-[]}"
  local ts
  ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

  if [[ "$provider" == "claude" ]]; then
    claude_json="$active_json"
    codex_json="$(inactive_codex_section)"
  else
    claude_json="$(inactive_claude_section)"
    codex_json="$active_json"
  fi

  jq -n \
    --arg ts "$ts" \
    --arg active_provider "$provider" \
    --argjson claude "$claude_json" \
    --argjson codex "$codex_json" \
    --argjson errors "$errors_json" \
    '{timestamp:$ts,active_provider:$active_provider,claude:$claude,codex:$codex,errors:$errors}'
}

build_error_output_for_provider() {
  local provider err active_json
  provider="$(normalize_provider "${1:-codex}")"
  err="$2"
  if [[ "$provider" == "claude" ]]; then
    active_json="$(claude_error_section "$err")"
  else
    active_json="$(codex_error_section "$err")"
  fi
  build_output_for_provider "$provider" "$active_json" "[\"$err\"]"
}

# ---------------------------------------------------------------------------
# Write an unavailable / error state and optionally exit
# ---------------------------------------------------------------------------
write_error_state() {
  local err="$1"
  local provider="${2:-$(selected_provider)}"
  local output
  output="$(build_error_output_for_provider "$provider" "$err")"
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
  log "Leaving last status snapshot intact. Exiting."
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

  local token expires_at now_ms response http_code body claude_json codex_json output provider provider_error errors_json
  local curl_ok

  while true; do
    provider="$(selected_provider)"
    log "Selected provider: $provider"

    if [[ "$provider" == "codex" ]]; then
      codex_json="$(codex_section)"
      provider_error="$(jq -r '.error // empty' <<< "$codex_json" 2>/dev/null || true)"
      if [[ -n "$provider_error" ]]; then
        errors_json="[\"$provider_error\"]"
      else
        errors_json="[]"
      fi
      output="$(build_output_for_provider "codex" "$codex_json" "$errors_json")"
      write_status "$output"
      log "Status updated successfully for codex"
      sleep "$POLL_INTERVAL" &
      wait $! || true
      continue
    fi

    # -- 1. Read credentials fresh every cycle --------------------------------
    if [[ ! -f "$CREDENTIALS_FILE" ]]; then
      log "Credentials file not found: $CREDENTIALS_FILE"
      write_error_state "credentials_not_found" "$provider"
      sleep "$POLL_INTERVAL" &
      wait $! || true
      continue
    fi

    token="$(jq -r '.claudeAiOauth.accessToken // empty' "$CREDENTIALS_FILE" 2>/dev/null || true)"
    if [[ -z "$token" ]]; then
      log "No access token found in credentials file"
      write_error_state "no_access_token" "$provider"
      sleep "$POLL_INTERVAL" &
      wait $! || true
      continue
    fi

    # -- 2. Check token expiry -----------------------------------------------
    expires_at="$(jq -r '.claudeAiOauth.expiresAt // "0"' "$CREDENTIALS_FILE" 2>/dev/null || echo "0")"
    now_ms="$(date +%s)000"
    if (( now_ms >= expires_at )); then
      log "Access token has expired (expiresAt=${expires_at}, now=${now_ms})"
      write_error_state "token_expired" "$provider"
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
      write_error_state "network_error" "$provider"
      sleep "$POLL_INTERVAL" &
      wait $! || true
      continue
    fi

    # Split body and HTTP status code
    http_code="$(tail -n1 <<< "$response")"
    body="$(sed '$d' <<< "$response")"

    if [[ "$http_code" != "200" ]]; then
      log "API returned HTTP $http_code"
      write_error_state "api_error_${http_code}" "$provider"
      sleep "$POLL_INTERVAL" &
      wait $! || true
      continue
    fi

    # -- 4. Parse the response -----------------------------------------------
    claude_json="$(parse_usage_response "$body" 2>/dev/null)" || {
      log "Failed to parse API response"
      write_error_state "json_parse_error" "$provider"
      sleep "$POLL_INTERVAL" &
      wait $! || true
      continue
    }

    if [[ -z "$claude_json" || "$claude_json" == "null" ]]; then
      log "jq produced empty output"
      write_error_state "json_parse_error" "$provider"
      sleep "$POLL_INTERVAL" &
      wait $! || true
      continue
    fi

    # -- 5. Build and write the final status file ----------------------------
    output="$(build_output_for_provider "claude" "$claude_json" "[]")"
    write_status "$output"
    log "Status updated successfully for claude"

    # Sleep in background so trap can fire immediately
    sleep "$POLL_INTERVAL" &
    wait $! || true
  done
}

if [[ "${AI_USAGE_MONITOR_TEST_MODE:-0}" != "1" ]]; then
  main
fi
