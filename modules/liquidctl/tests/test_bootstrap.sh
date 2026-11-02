#!/usr/bin/env bash
# Run the shipped bootstrap against a disposable system root with stubbed sudo, pacman,
# systemctl and udevadm; never touch the real /etc, packages or services.
set -euo pipefail

MODULE=$(cd "$(dirname "$0")/.." && pwd)
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

UNIT=etc/systemd/system/liquidctl-lianli-uni-sl.service
RULE=etc/udev/rules.d/90-liquidctl-lianli-uni-sl.rules
REAL_STAT=$(command -v stat)
mkdir -p "$T/bin"

# sudo logs and runs its command as the test user. `install -o root -g root` would need
# root, so the owner flags are dropped; the stat stub reports the test user's files as
# root-owned, the same view a real root install gives the bootstrap.
cat >"$T/bin/sudo" <<'EOF'
#!/usr/bin/env bash
echo "sudo $*" >>"$STUB_LOG"
if [ "$1" = install ]; then
  shift
  args=()
  while [ $# -gt 0 ]; do
    case "$1" in -o|-g) shift 2 ;; *) args+=("$1"); shift ;; esac
  done
  exec install "${args[@]}"
fi
exec "$@"
EOF
cat >"$T/bin/stat" <<EOF
#!/usr/bin/env bash
"$REAL_STAT" "\$@" | sed "s/^\$(id -u):\$(id -g):/0:0:/"
EOF
cat >"$T/bin/pacman" <<'EOF'
#!/usr/bin/env bash
echo "pacman $*" >>"$STUB_LOG"
case "$1" in
  -Q) [ -e "$STUB_STATE/installed" ] ;;
  -Si) exit 0 ;;
  -S) [ -z "${PACMAN_FAIL:-}" ] || exit 1; touch "$STUB_STATE/installed" ;;
  *) exit 2 ;;
esac
EOF
for cmd in systemctl udevadm; do
  # shellcheck disable=SC2016 # expands in the generated stub, not here
  printf '#!/usr/bin/env bash\necho "%s $*" >>"$STUB_LOG"\n' "$cmd" >"$T/bin/$cmd"
done
chmod +x "$T/bin"/*

# Fresh sysroot and stub state for one scenario; $1 = with or without the hub.
setup() {
  R="$T/root-$1-$RANDOM" S="$T/state-$RANDOM"
  mkdir -p "$R/sys/bus/usb/devices/1-1" "$R/sys/bus/usb/devices/1-2" "$S"
  printf '046d\n' >"$R/sys/bus/usb/devices/1-1/idVendor"
  printf 'c548\n' >"$R/sys/bus/usb/devices/1-1/idProduct"
  if [ "$1" = hub ]; then
    printf '0cf2\n' >"$R/sys/bus/usb/devices/1-2/idVendor"
    printf 'a100\n' >"$R/sys/bus/usb/devices/1-2/idProduct"
  else
    printf '0cf2\n' >"$R/sys/bus/usb/devices/1-2/idVendor"
    printf 'a101\n' >"$R/sys/bus/usb/devices/1-2/idProduct"
  fi
}
run() {
  : >"$T/log"
  PATH="$T/bin:$PATH" DOTFILES_SYSROOT="$R" STUB_STATE="$S" STUB_LOG="$T/log" \
    bash "$MODULE/bootstrap.sh" >"$T/out" 2>&1
}
called() { grep -qxF -- "$1" "$T/log"; }
calls_of() { grep -c -- "^$1 " "$T/log" || true; }

# (a) No hub (a different Lian Li product id): skip without touching anything.
setup nohub
run || fail "no-hub run exited non-zero"
grep -q 'no Lian Li UNI FAN SL hub, skipped' "$T/out" || fail "no-hub run did not report the skip"
[ ! -s "$T/log" ] || fail "no-hub run called stubs: $(cat "$T/log")"
[ ! -e "$R/etc" ] || fail "no-hub run deployed files"

# (b) Hub present, liquidctl missing: install, deploy both files, reload, start.
setup hub
run || fail "hub run exited non-zero"
called "sudo pacman -S --needed --noconfirm liquidctl" || fail "liquidctl was not installed"
cmp -s "$MODULE/systemd/liquidctl-lianli-uni-sl.service" "$R/$UNIT" || fail "unit not deployed byte-identical"
cmp -s "$MODULE/udev/rules.d/90-liquidctl-lianli-uni-sl.rules" "$R/$RULE" || fail "udev rule not deployed byte-identical"
[ "$("$REAL_STAT" -c %a "$R/$UNIT")" = 644 ] || fail "unit mode is not 0644"
[ "$("$REAL_STAT" -c %a "$R/$RULE")" = 644 ] || fail "udev rule mode is not 0644"
called "systemctl daemon-reload" || fail "systemd was not reloaded"
called "udevadm control --reload" || fail "udev rules were not reloaded"
called "systemctl start liquidctl-lianli-uni-sl.service" || fail "service was not started"

# (c) Immediate re-run changes nothing and needs no privileges.
run || fail "repeat run exited non-zero"
for cmd in sudo systemctl udevadm; do
  [ "$(calls_of "$cmd")" = 0 ] || fail "repeat run called $cmd: $(cat "$T/log")"
done

# A drifted unit is repaired and services reloaded again.
printf 'drift\n' >>"$R/$UNIT"
run || fail "drift run exited non-zero"
cmp -s "$MODULE/systemd/liquidctl-lianli-uni-sl.service" "$R/$UNIT" || fail "drifted unit not restored"
called "systemctl start liquidctl-lianli-uni-sl.service" || fail "service not restarted after drift repair"

# (d) Package install fails: warn, exit 0, deploy nothing.
setup hub
PACMAN_FAIL=1 run || fail "failed-install run exited non-zero"
grep -q 'liquidctl: pacman install failed, skipped' "$T/out" || fail "failed install was not reported"
[ ! -e "$R/etc" ] || fail "failed install still deployed files"
for cmd in systemctl udevadm; do
  [ "$(calls_of "$cmd")" = 0 ] || fail "failed install called $cmd"
done

echo "liquidctl bootstrap tests passed"
