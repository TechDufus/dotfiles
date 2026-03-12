#!/usr/bin/env bash
set -euo pipefail

resolve_peon_sh() {
  local peon_bin peon_bin_real peon_prefix candidate

  candidate="${CODEX_PEON_INSTALL_DIR:-$HOME/.local/share/codex-peon/hooks/peon-ping}/peon.sh"
  if [ -f "$candidate" ]; then
    printf '%s\n' "$candidate"
    return 0
  fi

  if command -v peon >/dev/null 2>&1; then
    peon_bin="$(command -v peon)"
    peon_bin_real="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$peon_bin" 2>/dev/null || true)"
    if [ -n "$peon_bin_real" ]; then
      peon_prefix="$(cd "$(dirname "$peon_bin_real")/.." && pwd)"
      candidate="$peon_prefix/libexec/peon.sh"
      if [ -f "$candidate" ]; then
        printf '%s\n' "$candidate"
        return 0
      fi
    fi
  fi

  for candidate in \
    /opt/homebrew/opt/peon-ping/libexec/peon.sh \
    /usr/local/opt/peon-ping/libexec/peon.sh
  do
    if [ -f "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

PEON_SH="$(resolve_peon_sh || true)"
[ -n "$PEON_SH" ] || exit 0

PEON_DIR="${CODEX_PEON_DIR:-$HOME/.openpeon}"
CODEX_NOTIFY_PAYLOAD="${1:-}"
if [ -z "$CODEX_NOTIFY_PAYLOAD" ] && [ ! -t 0 ]; then
  CODEX_NOTIFY_PAYLOAD="$(cat)"
fi
[ -n "$CODEX_NOTIFY_PAYLOAD" ] || exit 0

CODEX_NOTIFY_PAYLOAD="$CODEX_NOTIFY_PAYLOAD" python3 - <<'PY' | CLAUDE_PEON_DIR="$PEON_DIR" bash "$PEON_SH"
import json
import os
import re


def first_non_empty(*values):
    for value in values:
        if value is None:
            continue
        if isinstance(value, str):
            if value.strip():
                return value.strip()
        else:
            return value
    return ""


raw = os.environ.get("CODEX_NOTIFY_PAYLOAD", "").strip()
payload_in = {}
if raw:
    try:
        parsed = json.loads(raw)
        if isinstance(parsed, dict):
            payload_in = parsed
    except Exception:
        payload_in = {}

raw_event = first_non_empty(
    payload_in.get("type", ""),
    payload_in.get("event", ""),
    "agent-turn-complete",
)
event_key = str(raw_event).strip().lower().replace("_", "-")

notif_type = str(payload_in.get("notification_type", "")).strip().lower()
if (
    event_key.startswith("permission")
    or event_key.startswith("approve")
    or event_key in ("approval-requested", "approval-needed", "input-required")
    or notif_type == "permission_prompt"
):
    mapped_event = "Notification"
    mapped_ntype = "permission_prompt"
elif event_key in ("start", "session-start"):
    mapped_event = "SessionStart"
    mapped_ntype = notif_type
elif event_key == "idle-prompt":
    mapped_event = "Notification"
    mapped_ntype = "idle_prompt"
elif event_key.startswith("error") or event_key.startswith("fail"):
    mapped_event = "PostToolUseFailure"
    mapped_ntype = notif_type
else:
    mapped_event = "Stop"
    mapped_ntype = notif_type

cwd = str(first_non_empty(payload_in.get("cwd", ""), os.environ.get("PWD", ""), "/"))
raw_session_id = str(
    first_non_empty(
        payload_in.get("thread-id", ""),
        payload_in.get("thread_id", ""),
        payload_in.get("session_id", ""),
        payload_in.get("conversation_id", ""),
        os.getpid(),
    )
)
safe_session_id = re.sub(r"[^A-Za-z0-9._:-]", "-", raw_session_id).strip("-")
if not safe_session_id:
    safe_session_id = str(os.getpid())

payload_out = {
    "hook_event_name": mapped_event,
    "notification_type": mapped_ntype,
    "cwd": cwd,
    "session_id": f"codex-{safe_session_id}",
    "permission_mode": str(payload_in.get("permission_mode", "")),
    "source": "codex",
}

summary = first_non_empty(
    payload_in.get("last-assistant-message", ""),
    payload_in.get("last_agent_message", ""),
    payload_in.get("summary", ""),
)
if isinstance(summary, str) and summary:
    payload_out["transcript_summary"] = summary[:120]

error = first_non_empty(payload_in.get("error", ""), payload_in.get("message", ""))
if mapped_event == "PostToolUseFailure":
    payload_out["tool_name"] = str(payload_in.get("tool_name", "") or payload_in.get("tool", "") or "Bash")[:64]
    payload_out["error"] = str(error or f"Codex event: {raw_event}")[:180]

print(json.dumps(payload_out))
PY
