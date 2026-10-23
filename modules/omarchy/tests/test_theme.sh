#!/usr/bin/env bash
# theme.sh applies the default Omarchy theme once per default value; later picks stay.
# Runs the real script with stub omarchy-theme-set and hyprctl in a scrubbed environment.
set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SCRIPT="$HERE/../theme.sh"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/stub"

cat >"$T/stub/omarchy-theme-set" <<'EOF'
#!/bin/sh
echo "$1 headless=${OMARCHY_THEME_HEADLESS:-0} sig=${HYPRLAND_INSTANCE_SIGNATURE:-}" >>"$SET_LOG"
[ "${STUB_SET_RC:-0}" = 0 ] || exit "$STUB_SET_RC"
mkdir -p "$HOME/.local/state/omarchy/current"
echo "$1" >"$HOME/.local/state/omarchy/current/theme.name"
EOF
cat >"$T/stub/hyprctl" <<'EOF'
#!/bin/sh
[ "$1 $2" != "instances -j" ] || echo "${STUB_INSTANCES:-[]}"
EOF
chmod +x "$T/stub/omarchy-theme-set" "$T/stub/hyprctl"

FAILS=0 CASE="" OUT="" RC=0
fail() {
  echo "FAIL [$CASE]: $*" >&2
  FAILS=$((FAILS + 1))
}
reset() {
  CASE=$1
  rm -rf "${T:?}/home" "${T:?}/set.log"
  mkdir -p "$T/home"
}
run() { # run [NAME=value ...]: theme.sh with the sandbox HOME
  OUT=$(env -i HOME="$T/home" PATH="$T/stub:/usr/bin:/bin" SET_LOG="$T/set.log" "$@" bash "$SCRIPT" 2>&1)
  RC=$?
}
current() {
  mkdir -p "$T/home/.local/state/omarchy/current"
  echo "$1" >"$T/home/.local/state/omarchy/current/theme.name"
}
marker() { cat "$T/home/.local/state/dotfiles/omarchy-theme" 2>/dev/null; }
calls() { cat "$T/set.log" 2>/dev/null; }
LIVE='STUB_INSTANCES=[{"instance":"abc"}]'

reset fresh-machine
current tokyo-night
run OMARCHY_DEFAULT_THEME=pulsar "$LIVE"
[ "$(calls)" = "pulsar headless=0 sig=abc" ] || fail "switch in the live session: $(calls)"
[ "$(marker)" = pulsar ] || fail "marker: $(marker)"
case $OUT in *"switched to pulsar"*) ;; *) fail "message: $OUT" ;; esac

CASE=same-default-again
rm -f "$T/set.log"
run OMARCHY_DEFAULT_THEME=pulsar "$LIVE"
[ -z "$(calls)" ] || fail "switched again: $(calls)"

CASE=later-pick-stays
current catppuccin
run OMARCHY_DEFAULT_THEME=pulsar "$LIVE"
[ -z "$(calls)" ] || fail "overrode the theme picked in Omarchy's menu: $(calls)"

CASE=new-default-applies
run "OMARCHY_DEFAULT_THEME=Rose Pine" "$LIVE"
[ "$(calls)" = "rose-pine headless=0 sig=abc" ] || fail "new default, normalized name: $(calls)"
[ "$(marker)" = rose-pine ] || fail "marker: $(marker)"

reset already-current
current pulsar
run OMARCHY_DEFAULT_THEME=pulsar "$LIVE"
[ -z "$(calls)" ] || fail "switched to the theme already in use: $(calls)"
[ "$(marker)" = pulsar ] || fail "marker not recorded: $(marker)"

reset no-session
current tokyo-night
run OMARCHY_DEFAULT_THEME=pulsar
[ "$(calls)" = "pulsar headless=1 sig=" ] || fail "staged headless outside a session: $(calls)"

reset stale-signature
current tokyo-night
run OMARCHY_DEFAULT_THEME=pulsar HYPRLAND_INSTANCE_SIGNATURE=old 'STUB_INSTANCES=[{"instance":"new"}]'
[ "$(calls)" = "pulsar headless=0 sig=new" ] || fail "stale signature not replaced: $(calls)"

reset switch-fails
current tokyo-night
run OMARCHY_DEFAULT_THEME=pulsar STUB_SET_RC=1 "$LIVE"
[ "$RC" -eq 0 ] || fail "fail-soft: exit $RC"
[ -z "$(marker)" ] || fail "marker written although the switch failed"
case $OUT in *"failed, skipped"*) ;; *) fail "message: $OUT" ;; esac

reset no-default
current tokyo-night
run "$LIVE"
[ -z "$(calls)" ] || fail "switched without a default: $(calls)"

if [ "$FAILS" -ne 0 ]; then
  echo "test_theme: $FAILS failure(s)" >&2
  exit 1
fi
echo "test_theme: all passed"
