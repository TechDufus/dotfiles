#!/usr/bin/env bash
# Optional OpenMonitor hook. No-op when the helper is not installed.
set -eu
event="${1:-}"
hook="${HOME}/.openmonitor/hook.sh"
[[ -n "$event" && -x "$hook" ]] || exit 0
exec "$hook" "$event"
