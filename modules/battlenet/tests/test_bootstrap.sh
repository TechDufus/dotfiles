#!/usr/bin/env bash
# Exercise the shipped settings task in a disposable HOME; never starts Wine or Battle.net.
set -euo pipefail

MODULE=$(cd "$(dirname "$0")/.." && pwd)
T=$(mktemp -d)
fake_pid=
trap '[ -z "$fake_pid" ] || kill "$fake_pid" 2>/dev/null; rm -rf "$T"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || fail "jq is required to exercise the Battle.net settings task"

prefix="$T/home/Games/battlenet"
dir="$prefix/drive_c/users/steamuser/AppData/Roaming/Battle.net"
account="$dir/1a2b3c4.config"
global="$dir/Battle.net.config"
run_task() { HOME="$T/home" bash "$MODULE/bootstrap.sh"; }
exits='.User.Client.GameLaunchWindowBehavior == "1" and .User.Client.HideOnClose == "false"'

# Not installed: the task must not create the prefix (Omarchy's installer would call it partial).
run_task
[ ! -e "$prefix" ] || fail "task created $prefix without a Battle.net install"

mkdir -p "$dir"
printf '%s\n' '{"User":{"Client":{"HideOnClose":"true","DisplayExitPrompt":"false","Windows":{"BrowserMainWindow":{"WindowState":"0"}}},"Games":{"wowf":{"LastSeenPatchNotesBuild":"1"}}}}' >"$account"
printf '%s\n' '{"Client":{"AutoLogin":"true"},"Games":{"wowf":{"LastPlayed":"1"}}}' >"$global"
chmod 0640 "$account"
cp "$global" "$T/global.before"

# A running prefix rewrites the files on exit, so the task must leave them alone. The fake
# wineserver is a copy of sleep (comm = wineserver) carrying this prefix as WINEPREFIX.
cp "$(command -v sleep)" "$T/wineserver"
WINEPREFIX="$prefix" "$T/wineserver" 30 &
fake_pid=$!
for _ in $(seq 50); do [ "$(cat "/proc/$fake_pid/comm" 2>/dev/null)" = wineserver ] && break; sleep 0.1; done
cp "$account" "$T/before"
out=$(run_task)
cmp -s "$account" "$T/before" || fail "task changed the account config while the prefix was running"
[[ $out == *"is running"* ]] || fail "running prefix was not reported: $out"
kill "$fake_pid"; wait "$fake_pid" 2>/dev/null || true; fake_pid=

run_task >/dev/null
jq -e "$exits"' and .User.Client.DisplayExitPrompt == "false"
  and .User.Client.Windows == {"BrowserMainWindow":{"WindowState":"0"}}
  and .User.Games == {"wowf":{"LastSeenPatchNotesBuild":"1"}}' "$account" >/dev/null \
  || fail "task did not set exactly the two owned keys in the account config"
[ "$(stat -c %a "$account")" = 640 ] || fail "task changed the account config's mode"
cmp -s "$global" "$T/global.before" || fail "task changed Battle.net.config, which holds no account settings"

cp "$account" "$T/applied"
[ -z "$(run_task)" ] || fail "second run reported a change"
cmp -s "$account" "$T/applied" || fail "second run rewrote an already-correct account config"

# A second account gets the same settings; a malformed file is never touched.
second="$dir/5d6e7f8.config"
printf '%s\n' '{"User":{"Client":{}}}' >"$second"
printf '%s\n' '{broken-json' >"$dir/broken.config"
cp "$dir/broken.config" "$T/malformed"
run_task >/dev/null 2>&1
jq -e "$exits" "$second" >/dev/null || fail "task skipped a second account"
cmp -s "$dir/broken.config" "$T/malformed" || fail "task changed a malformed config"
[ -z "$(find "$dir" -name '*.config.*')" ] || fail "task left a temp file behind"

echo "Battle.net settings task tests passed"
