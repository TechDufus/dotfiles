#!/usr/bin/env bash
# Run the shipped bootstrap against a disposable system root with stubbed sudo, systemctl, ip and
# Omarchy helpers; never installs Sunshine, opens ports or touches services.
set -euo pipefail

MODULE=$(cd "$(dirname "$0")/.." && pwd)
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

UNIT=app-dev.lizardbyte.app.Sunshine.service
mkdir -p "$T/bin"
# sudo only logs: the bootstrap's privileged calls are all ufw. UFW_FAIL fails rule additions.
cat >"$T/bin/sudo" <<'EOF'
#!/usr/bin/env bash
echo "sudo $*" >>"$STUB_LOG"
[ -z "${UFW_FAIL:-}" ] || [ "$2" != allow ]
EOF
cat >"$T/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
echo "systemctl $*" >>"$STUB_LOG"
case "$*" in
  "--user is-enabled --quiet app-dev.lizardbyte.app.Sunshine.service") [ -e "$STUB_STATE/enabled" ] ;;
  "--user enable --now app-dev.lizardbyte.app.Sunshine.service") [ -e "$STUB_STATE/installed" ] && touch "$STUB_STATE/enabled" ;;
  *) exit 2 ;;
esac
EOF
cat >"$T/bin/ip" <<'EOF'
#!/usr/bin/env bash
[ "$*" = "link show tailscale0" ] && [ -n "${TAILNET:-}" ]
EOF
cat >"$T/bin/omarchy-pkg-add" <<'EOF'
#!/usr/bin/env bash
echo "omarchy-pkg-add $*" >>"$STUB_LOG"
[ -z "${PKG_FAIL:-}" ] || exit 1
touch "$STUB_STATE/installed"
EOF
cat >"$T/bin/omarchy-webapp-install" <<'EOF'
#!/usr/bin/env bash
{ printf 'omarchy-webapp-install'; printf ' [%s]' "$@"; echo; } >>"$STUB_LOG"
EOF
# Present even where the CI image has no ufw; the bootstrap only runs it through sudo.
printf '#!/usr/bin/env bash\nexit 0\n' >"$T/bin/ufw"
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
called() { grep -qxF -- "$1" "$T/log"; }
count() { grep -c -- "$1" "$T/log" || true; }

# Laptop: its own battery (no scope attribute, as on most laptops) skips the setup.
setup BAT0:Battery: AC:Mains:
run || fail "laptop run exited non-zero"
grep -q 'battery found (laptop), skipped' "$T/out" || fail "laptop skip was not reported"
[ ! -s "$T/log" ] || fail "laptop run called stubs: $(cat "$T/log")"

# Desktop with a wireless mouse battery (scope Device) and Tailscale up: full setup.
setup hidpp_battery_0:Battery:Device
TAILNET=1 run || fail "desktop run exited non-zero"
called "omarchy-pkg-add sunshine" || fail "package was not installed"
called "sudo ufw allow in proto tcp from 192.168.0.0/16 to any port 47989 comment omarchy-sunshine" ||
  fail "LAN rule missing: $(cat "$T/log")"
called "sudo ufw allow in on tailscale0 to any port 48000 proto udp comment omarchy-sunshine" ||
  fail "tailnet rule missing"
# 3 TCP + 6 UDP ports, each from 3 private ranges and tailscale0.
[ "$(count '^sudo ufw allow ')" = 36 ] || fail "expected 36 UFW rules, got $(count '^sudo ufw allow ')"
called "sudo ufw reload" || fail "UFW was not reloaded"
called "omarchy-webapp-install [Sunshine Admin] [https://localhost:47990] [/usr/share/sunshine/web/images/logo-sunshine-45.png] [omarchy-launch-webapp https://localhost:47990 --ignore-certificate-errors]" ||
  fail "web app not installed as Omarchy does: $(grep webapp "$T/log")"
[ "$(tail -n1 "$T/log")" = "systemctl --user enable --now $UNIT" ] || fail "unit was not enabled last"
if grep -q 'sunshine\.service\|autostart' "$T/log"; then fail "touched the alias or autostart"; fi

# Enabled: nothing to do, no sudo, no output.
run || fail "repeat run exited non-zero"
[ "$(count '^sudo ')" = 0 ] || fail "repeat run used sudo"
[ "$(count '^systemctl --user enable')" = 0 ] || fail "repeat run enabled again"
[ ! -s "$T/out" ] || fail "repeat run printed: $(cat "$T/out")"

# Tailscale down: LAN rules only.
setup
run || fail "no-tailnet run exited non-zero"
[ "$(count 'tailscale0')" = 0 ] || fail "added tailnet rules without tailscale0"
[ "$(count '^sudo ufw allow ')" = 27 ] || fail "expected 27 LAN rules, got $(count '^sudo ufw allow ')"

# UFW fails: warn, leave the unit disabled so the next run retries, then finish.
setup
UFW_FAIL=1 run || fail "ufw-failure run exited non-zero"
grep -q 'opening Moonlight ports in UFW failed, skipped' "$T/out" || fail "UFW failure was not reported"
[ ! -e "$S/enabled" ] || fail "unit enabled with ports closed"
run || fail "retry run exited non-zero"
[ -e "$S/enabled" ] || fail "retry did not finish the setup"

# Package install fails: warn, exit 0, no rules, nothing enabled.
setup
PKG_FAIL=1 run || fail "failed-install run exited non-zero"
grep -q 'package install failed, skipped' "$T/out" || fail "failed install was not reported"
[ "$(count '^sudo ')" = 0 ] || fail "failed install still opened ports"
[ ! -e "$S/enabled" ] || fail "failed install enabled the unit"

echo "sunshine bootstrap tests passed"
