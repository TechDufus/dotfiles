#!/usr/bin/env bash
# settings.sh owns only the btop.conf keys in its settings files and leaves the rest alone.
# Runs the real script against a sandbox XDG_CONFIG_HOME with a stub pkill.
set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SCRIPT="$HERE/../settings.sh"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/stub"
cat >"$T/stub/pkill" <<'EOF'
#!/bin/sh
echo "$*" >>"$STUB_LOG"
EOF
chmod +x "$T/stub/pkill"

FAILS=0 CASE="" OUT="" RC=0
CONF="$T/cfg/btop/btop.conf"
fail() {
  echo "FAIL [$CASE]: $1"
  FAILS=$((FAILS + 1))
}
reset() {
  CASE=$1
  rm -rf "$T/cfg" "$T/signals"
}
run() { # run <settings files...>
  OUT=$(XDG_CONFIG_HOME="$T/cfg" STUB_LOG="$T/signals" PATH="$T/stub:$PATH" bash "$SCRIPT" "$@" 2>&1)
  RC=$?
}
value() { awk -F' = ' -v k="$1" '$1 == k { print $2 }' "$CONF"; }
count() { awk -F' = ' -v k="$1" '$1 == k { n++ } END { print n + 0 }' "$CONF"; }
signals() { cat "$T/signals" 2>/dev/null; }

printf 'update_ms = 200\nshown_boxes = "cpu mem net proc gpu0"\n#* not a key = 1\n' >"$T/settings.conf"
printf 'color_theme = "current"\n' >"$T/omarchy.conf"
printf 'update_ms = 500\n' >"$T/override.conf"
app_file() {
  mkdir -p "${CONF%/*}"
  cat >"$CONF" <<'EOF'
#? Config file for btop v.1.4.7

#* Name of a btop++/bpytop/bashtop formatted ".theme" file
color_theme = "current"

#* Set to True to enable "h,j,k,l,g,G" keys for directional control in lists.
vim_keys = true

#* Update time in milliseconds
update_ms = 2000
EOF
}

reset replaces-in-place
app_file
run "$T/settings.conf"
[ "$RC" -eq 0 ] || fail "exit $RC"
[ "$(value update_ms)" = 200 ] || fail "owned key not set: $(value update_ms)"
[ "$(sed -n '10p' "$CONF")" = "update_ms = 200" ] || fail "owned key moved from its line"
[ "$(sed -n '9p' "$CONF")" = "#* Update time in milliseconds" ] || fail "comment above the key lost"
[ "$(value vim_keys)" = true ] || fail "unowned key changed: $(value vim_keys)"
[ "$(value color_theme)" = '"current"' ] || fail "theme changed without a theme file"
[ "$(tail -n 1 "$CONF")" = 'shown_boxes = "cpu mem net proc gpu0"' ] || fail "missing owned key not appended"
[ "$(count not)" = 0 ] || fail "comment line in the settings file treated as a key"
[ "$(signals)" = "-USR2 -x btop" ] || fail "running btop not told to reload: $(signals)"

CASE=unchanged-file-untouched
before=$(stat -c '%i %Y' "$CONF" 2>/dev/null || stat -f '%i %m' "$CONF")
rm -f "$T/signals"
sleep 1
run "$T/settings.conf"
after=$(stat -c '%i %Y' "$CONF" 2>/dev/null || stat -f '%i %m' "$CONF")
[ "$before" = "$after" ] || fail "rewrote a file that already had every owned key"
[ -z "$OUT" ] || fail "reported a change: $OUT"
[ -z "$(signals)" ] || fail "signalled btop without a change: $(signals)"

reset later-file-wins
app_file
run "$T/settings.conf" "$T/override.conf"
[ "$(value update_ms)" = 500 ] || fail "later settings file did not win: $(value update_ms)"
[ "$(count update_ms)" = 1 ] || fail "key written $(count update_ms) times"

reset duplicate-keys-collapse
app_file
echo "update_ms = 100" >>"$CONF"
run "$T/settings.conf"
[ "$(count update_ms)" = 1 ] || fail "duplicate owned key kept: $(count update_ms)"

reset missing-file-created
run "$T/settings.conf" "$T/omarchy.conf"
[ -f "$CONF" ] || fail "btop.conf not created"
[ "$(value color_theme)" = '"current"' ] || fail "theme key missing from new file"
[ "$(value update_ms)" = 200 ] || fail "owned key missing from new file"

reset link-replaced-not-written-through
mkdir -p "${CONF%/*}"
printf 'update_ms = 2000\n' >"$T/checkout.conf"
ln -s "$T/checkout.conf" "$CONF"
run "$T/settings.conf"
[ ! -L "$CONF" ] || fail "link left in place"
[ "$(cat "$T/checkout.conf")" = "update_ms = 2000" ] || fail "wrote through the link"
[ "$(value update_ms)" = 200 ] || fail "owned key not set on the replacement file"

reset unreadable-settings-fail-soft
app_file
run "$T/nope.conf"
[ "$RC" -eq 0 ] || fail "fail-soft: exit $RC"
case $OUT in *"cannot read"*"skipped"*) ;; *) fail "message: $OUT" ;; esac
[ "$(value update_ms)" = 2000 ] || fail "changed the file despite the error"

if [ "$FAILS" -ne 0 ]; then
  echo "test_settings: $FAILS failure(s)"
  exit 1
fi
echo "test_settings: all passed"
