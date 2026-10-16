#!/usr/bin/env bash
# Exercise the shipped reset only in a disposable HOME; never launch Tern.
set -euo pipefail

MODULE=$(cd "$(dirname "$0")/.." && pwd)
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || fail "jq is required to exercise Tern's settings reset"

case "$(uname -s)" in
  Darwin) standard="$T/home/Library/Application Support/Tern/settings.json" ;;
  *) standard="$T/home/.config/tern/settings.json" ;;
esac
alternate="$T/alternate/settings.json"
xdg="$T/xdg/tern/settings.json"
mkdir -p "$(dirname "$standard")" "$(dirname "$alternate")" "$(dirname "$xdg")"

reset_settings() {
  HOME="$T/home" TERN_CONFIG_DIR="$T/alternate" XDG_CONFIG_HOME="$T/xdg" \
    bash "$MODULE/bootstrap.sh"
}

# Native deployment owns only the standard root. Its cleanup must not redirect
# to an unrelated app configuration just because alternate-root vars are set.
printf '%s\n' '{"opacity":60,"surface_chat":"Reader","theme":"custom","user":{"opacity":42},"unmanaged":[1,2]}' >"$standard"
printf '%s\n' '{"opacity":17,"surface_chat":"User choice","private":"alternate"}' >"$alternate"
printf '%s\n' '{"opacity":19,"surface_chat":"User choice","private":"xdg"}' >"$xdg"
cp "$alternate" "$T/alternate.before"
cp "$xdg" "$T/xdg.before"
reset_settings
jq -e '. == {"theme":"custom","user":{"opacity":42},"unmanaged":[1,2]}' "$standard" >/dev/null \
  || fail "reset did not remove only the top-level default-owned keys"
cmp -s "$alternate" "$T/alternate.before" || fail "reset changed the unsupported TERN_CONFIG_DIR root"
cmp -s "$xdg" "$T/xdg.before" || fail "reset changed the unsupported XDG_CONFIG_HOME root"

cp "$standard" "$T/standard.before"
reset_settings
cmp -s "$standard" "$T/standard.before" || fail "second reset changed already-clean settings"

# The bootstrap task is fail-soft and must never replace an unreadable JSON
# document with partial output, nor create a config when the app has none yet.
printf '%s\n' '{broken-json' >"$standard"
cp "$standard" "$T/malformed.before"
reset_settings
cmp -s "$standard" "$T/malformed.before" || fail "reset changed malformed settings"
rm "$standard"
reset_settings
[ ! -e "$standard" ] || fail "reset created missing settings"
cmp -s "$alternate" "$T/alternate.before" || fail "missing standard root redirected reset to alternate settings"
cmp -s "$xdg" "$T/xdg.before" || fail "missing standard root redirected reset to XDG settings"

echo "Tern settings reset tests passed"
