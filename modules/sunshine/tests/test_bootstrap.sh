#!/usr/bin/env bash
# Run the shipped bootstrap against a disposable system root with stubbed pacman and Omarchy
# installer; never installs Sunshine, opens ports or touches services.
set -euo pipefail

MODULE=$(cd "$(dirname "$0")/.." && pwd)
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

mkdir -p "$T/bin"
cat >"$T/bin/pacman" <<'EOF'
#!/usr/bin/env bash
[ "$*" = "-Q sunshine" ] || exit 2
[ -e "$STUB_STATE/installed" ]
EOF
cat >"$T/bin/omarchy-install-service-sunshine" <<'EOF'
#!/usr/bin/env bash
echo "installer" >>"$STUB_LOG"
[ -z "${INSTALLER_FAIL:-}" ] || exit 1
touch "$STUB_STATE/installed"
EOF
chmod +x "$T/bin"/*

# Fresh sysroot and state; each argument adds a power supply as name:type:scope.
setup() {
  R="$T/root-$RANDOM" S="$T/state-$RANDOM"
  mkdir -p "$R/sys/class/power_supply" "$S"
  local spec name type scope
  for spec in "$@"; do
    IFS=: read -r name type scope <<<"$spec"
    mkdir -p "$R/sys/class/power_supply/$name"
    printf '%s\n' "$type" >"$R/sys/class/power_supply/$name/type"
    [ -z "$scope" ] || printf '%s\n' "$scope" >"$R/sys/class/power_supply/$name/scope"
  done
}
run() {
  : >"$T/log"
  PATH="$T/bin:$PATH" DOTFILES_SYSROOT="$R" STUB_STATE="$S" STUB_LOG="$T/log" \
    bash "$MODULE/bootstrap.sh" >"$T/out" 2>&1
}
installs() { grep -c '^installer$' "$T/log" || true; }

# Laptop: its own battery (no scope attribute, as on most laptops) skips the setup.
setup BAT0:Battery: AC:Mains:
run || fail "laptop run exited non-zero"
grep -q 'battery found (laptop), skipped' "$T/out" || fail "laptop skip was not reported"
[ "$(installs)" = 0 ] || fail "laptop ran the installer"

# Desktop with a wireless mouse battery (scope Device): runs Omarchy's installer once.
setup hidpp_battery_0:Battery:Device
run || fail "desktop run exited non-zero"
[ "$(installs)" = 1 ] || fail "desktop did not run the installer: $(cat "$T/out")"

# Already installed: nothing to do, no output.
run || fail "repeat run exited non-zero"
[ "$(installs)" = 0 ] || fail "repeat run ran the installer again"
[ ! -s "$T/out" ] || fail "repeat run printed: $(cat "$T/out")"

# Installer fails: warn and exit 0 so the rest of dotfiles still runs.
setup
INSTALLER_FAIL=1 run || fail "failed-installer run exited non-zero"
grep -q "Sunshine installer failed, skipped" "$T/out" || fail "installer failure was not reported"

echo "sunshine bootstrap tests passed"
