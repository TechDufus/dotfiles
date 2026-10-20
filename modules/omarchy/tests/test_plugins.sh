#!/usr/bin/env bash
# plugins.sh enables the listed shell plugins and disables the hidden ones, once per value of the
# two lists; later shell changes stay. Runs the real script against a stub shell.
set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SCRIPT="$HERE/../plugins.sh"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/stub"

# The stub shell knows the ids in $STUB/known; the ids in $STUB/bar are the enabled ones.
cat >"$T/stub/omarchy-shell" <<'EOF'
#!/bin/sh
case "$2" in
  ping) [ "${STUB_SHELL:-up}" = up ] || exit 1; echo ok ;;
  rescanPlugins) echo rescan >>"$STUB/calls" ;;
esac
EOF
cat >"$T/stub/omarchy-plugin-list" <<'EOF'
#!/bin/sh
jq -Rn --rawfile bar "$STUB/bar" '[inputs | . as $id | {id: $id, enabled: ($bar | split("\n") | index($id) != null)}]' <"$STUB/known"
EOF
cat >"$T/stub/omarchy-plugin-enable" <<'EOF'
#!/bin/sh
echo "enable $1" >>"$STUB/calls"
[ "${STUB_ENABLE_RC:-0}" = 0 ] || exit "$STUB_ENABLE_RC"
echo "$1" >>"$STUB/bar"
EOF
cat >"$T/stub/omarchy-plugin-disable" <<'EOF'
#!/bin/sh
echo "disable $1" >>"$STUB/calls"
grep -vxF "$1" "$STUB/bar" >"$STUB/bar.new"
mv "$STUB/bar.new" "$STUB/bar"
EOF
cat >"$T/stub/omarchy-plugin-validate" <<'EOF'
#!/bin/sh
[ -f "$1/manifest.json" ] || { echo "plugin folder not found: $1" >&2; exit 1; }
EOF
chmod +x "$T/stub"/*

FAILS=0 CASE="" OUT="" RC=0
fail() {
  echo "FAIL [$CASE]: $*" >&2
  FAILS=$((FAILS + 1))
}
reset() { # reset NAME: fresh HOME, cloned plugins, bar = tray + stock agents
  CASE=$1
  rm -rf "${T:?}/home" "${T:?}/state"
  mkdir -p "$T/state" "$T/home/.config/omarchy/plugins"
  clone acme.usage
  clone acme.github
  printf '%s\n' omarchy.tray omarchy.agents acme.usage acme.github >"$T/state/known"
  printf '%s\n' omarchy.tray omarchy.agents >"$T/state/bar"
}
clone() { mkdir -p "$T/home/.config/omarchy/plugins/$1" && echo '{}' >"$T/home/.config/omarchy/plugins/$1/manifest.json"; }
run() { # run [NAME=value ...]: plugins.sh with the sandbox HOME and the default lists
  rm -f "$T/state/calls"
  OUT=$(env -i HOME="$T/home" PATH="$T/stub:/usr/bin:/bin" STUB="$T/state" \
    OMARCHY_PLUGINS="acme.usage acme.github" OMARCHY_HIDDEN_PLUGINS=omarchy.agents "$@" bash "$SCRIPT" 2>&1)
  RC=$?
}
calls() { tr '\n' ',' 2>/dev/null <"$T/state/calls"; }
bar() { tr '\n' ' ' <"$T/state/bar"; }
marker() { cat "$T/home/.local/state/dotfiles/omarchy-plugins" 2>/dev/null; }

reset fresh-machine
run
[ "$(calls)" = "disable omarchy.agents,rescan,enable acme.usage,enable acme.github," ] || fail "calls: $(calls)"
[ "$(bar)" = "omarchy.tray acme.usage acme.github " ] || fail "bar: $(bar)"
[ "$(marker)" = "enabled=acme.usage acme.github hidden=omarchy.agents" ] || fail "marker: $(marker)"
case $OUT in *"disabled omarchy.agents"*"enabled acme.github"*) ;; *) fail "message: $OUT" ;; esac

CASE=same-lists-again
run
[ -z "$(calls)" ] || fail "applied again: $(calls)"

CASE=later-bar-change-stays
echo omarchy.agents >>"$T/state/bar"
run
[ -z "$(calls)" ] || fail "overrode a later bar change: $(calls)"

CASE=new-list-applies
echo acme.extra >>"$T/state/known"
clone acme.extra
run OMARCHY_PLUGINS="acme.usage acme.github acme.extra"
[ "$(calls)" = "disable omarchy.agents,rescan,enable acme.extra," ] || fail "only the missing changes: $(calls)"
[ "$(marker)" = "enabled=acme.usage acme.github acme.extra hidden=omarchy.agents" ] || fail "marker: $(marker)"

reset already-in-place
printf '%s\n' omarchy.tray acme.usage acme.github >"$T/state/bar"
run
[ "$(calls)" = "rescan," ] || fail "changed a bar that already matches: $(calls)"
[ -n "$(marker)" ] || fail "marker not recorded"

reset shell-not-running
run STUB_SHELL=down
[ "$RC" -eq 0 ] || fail "fail-soft: exit $RC"
[ -z "$(calls)" ] || fail "called the shell: $(calls)"
[ -z "$(marker)" ] || fail "marker written without the shell"
case $OUT in *"not running, skipped"*) ;; *) fail "message: $OUT" ;; esac

reset missing-clone
rm -rf "$T/home/.config/omarchy/plugins/acme.usage"
run
[ "$RC" -eq 0 ] || fail "fail-soft: exit $RC"
[ "$(bar)" = "omarchy.tray acme.github " ] || fail "the valid plugin was not enabled: $(bar)"
[ -z "$(marker)" ] || fail "marker written although a plugin is missing"
case $OUT in *"acme.usage is missing or invalid"*) ;; *) fail "message: $OUT" ;; esac

reset enable-fails
run STUB_ENABLE_RC=1
[ "$RC" -eq 0 ] || fail "fail-soft: exit $RC"
[ -z "$(marker)" ] || fail "marker written although enabling failed"
case $OUT in *"enabling acme.usage failed, skipped"*) ;; *) fail "message: $OUT" ;; esac

CASE=retry-after-failure
run
[ "$(calls)" = "rescan,enable acme.usage,enable acme.github," ] || fail "retry: $(calls)"
[ -n "$(marker)" ] || fail "marker not recorded after the retry"

reset no-lists
run OMARCHY_PLUGINS= OMARCHY_HIDDEN_PLUGINS=
[ -z "$(calls)" ] || fail "acted without lists: $(calls)"

if [ "$FAILS" -ne 0 ]; then
  echo "test_plugins: $FAILS failure(s)" >&2
  exit 1
fi
echo "test_plugins: all passed"
