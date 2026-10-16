#!/usr/bin/env bash
# Requires Linux, a non-root account, sudo's real visudo, and unprivileged
# bubblewrap user namespaces. Only a disposable sudoers.d is writable there.
set -euo pipefail

module_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
fail() { echo "FAIL: $*" >&2; exit 1; }
[ "$(uname -s)" = Linux ] || fail "requires Linux"
[ "$(/usr/bin/id -u)" -ne 0 ] || fail "run as a non-root account"
real_visudo=$(command -v visudo) || fail "install sudo (visudo required)"
command -v bwrap >/dev/null || fail "install bubblewrap (user namespaces required)"
[ -d /etc/sudoers.d ] || fail "sudo must provide /etc/sudoers.d"

scratch=$(mktemp -d)
trap 'rm -rf -- "$scratch"' EXIT
mkdir "$scratch/bin" "$scratch/policy"
export SYSTEM_TEST_ROOT="$scratch"
export SYSTEM_TEST_VISUDO="$real_visudo"
export SYSTEM_TEST_CORRUPT=0

# This is the privileged boundary, not a replacement parser or admission
# decision. The production root script executes unchanged inside a namespace.
cat > "$scratch/bin/sudo" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$SYSTEM_TEST_ROOT/sudo.calls"
if [ "$1" = bash ]; then
  exec bwrap --unshare-user --unshare-pid --uid 0 --gid 0 \
    --ro-bind / / --bind "$SYSTEM_TEST_ROOT" "$SYSTEM_TEST_ROOT" \
    --bind "$SYSTEM_TEST_ROOT/policy" /etc/sudoers.d \
    --dev /dev --proc /proc -- "$@"
fi
# Never run live udev/localectl. Reaching this boundary is the observable
# follow-through that must not happen after a policy failure.
printf '%s\n' "$*" >> "$SYSTEM_TEST_ROOT/after-policy"
SH

cat > "$scratch/bin/visudo" <<'SH'
#!/usr/bin/env bash
set -uo pipefail
if [ "$SYSTEM_TEST_CORRUPT" = 1 ]; then
  # Fault-inject malformed on-disk bytes immediately before the real parser.
  # The parser, not the fixture, decides whether the candidate is acceptable.
  for candidate; do :; done
  chmod u+w "$candidate"
  printf '\nthis is not valid sudoers !!!\n' >> "$candidate"
  chmod 0440 "$candidate"
fi
"$SYSTEM_TEST_VISUDO" "$@"
result=$?
printf '%s\n' "$result" > "$SYSTEM_TEST_ROOT/parser-result"
exit "$result"
SH

cat > "$scratch/bin/localectl" <<'SH'
#!/usr/bin/env bash
printf '%s\n' 'VC Keymap: dvorak' 'X11 Layout: us' 'X11 Model: pc105' \
  'X11 Variant: dvorak' 'X11 Options: caps:none' 'System Locale: LANG=en_US.UTF-8'
SH
chmod +x "$scratch/bin/"*
export PATH="$scratch/bin:/usr/sbin:/usr/bin:/sbin:/bin"

sandbox() {
  bwrap --unshare-user --unshare-pid --uid 0 --gid 0 \
    --ro-bind / / --bind "$scratch" "$scratch" \
    --bind "$scratch/policy" /etc/sudoers.d --dev /dev --proc /proc -- "$@"
}
# Fail clearly before exercising production if this host/container forbids
# namespaces. There is deliberately no unsafe host fallback or silent skip.
sandbox true || fail "bubblewrap user namespaces unavailable"

reset_observations() {
  rm -f "$scratch/parser-result" "$scratch/after-policy" "$scratch/sudo.calls"
}
assert_no_candidates() {
  local candidates=("$scratch/policy/".techdufus.*)
  [ ! -e "${candidates[0]}" ] || fail "staged candidate leaked"
}
run_bootstrap() {
  USER=environment_spoof SUDO_USER=root bash "$module_dir/bootstrap.sh" > "$scratch/output" 2>&1
}

policy="$scratch/policy/techdufus"
printf 'root ALL=(ALL:ALL) ALL\n' > "$policy"
chmod 0440 "$policy"
cp -p "$policy" "$scratch/before"
printf '# unrelated policy remains untouched\n' > "$scratch/policy/unrelated"
cp -p "$scratch/policy/unrelated" "$scratch/unrelated-before"

# Rejected exact candidate cannot replace an already installed policy, and
# must stop udev/locale follow-through. Capture the real parser's exit status
# so an unrelated early setup failure cannot masquerade as this regression.
reset_observations
export SYSTEM_TEST_CORRUPT=1
before=$(stat -c '%i:%Y:%a' "$policy")
if run_bootstrap; then fail "malformed candidate accepted"; fi
[ -s "$scratch/parser-result" ] || fail "negative case did not reach real visudo"
[ "$(cat "$scratch/parser-result")" -ne 0 ] || fail "real parser accepted malformed candidate"
cmp -s "$policy" "$scratch/before" || fail "rejected policy replaced existing bytes"
[ "$(stat -c '%i:%Y:%a' "$policy")" = "$before" ] || fail "rejection changed existing policy metadata"
[ ! -e "$scratch/after-policy" ] || fail "system steps ran after parser rejection"
assert_no_candidates

# Converge a valid grant to the kernel identity, not USER or SUDO_USER.
reset_observations
export SYSTEM_TEST_CORRUPT=0
run_bootstrap || { cat "$scratch/output" >&2; fail "valid candidate rejected"; }
[ "$(cat "$scratch/parser-result")" = 0 ] || fail "valid case bypassed real parser"
printf '#%s ALL=(ALL) NOPASSWD: ALL\n' "$(/usr/bin/id -u)" > "$scratch/expected"
cmp -s "$policy" "$scratch/expected" || fail "grant did not target the invoking UID"
[ "$(sandbox stat -c '%u:%g:%a' /etc/sudoers.d/techdufus)" = '0:0:440' ] || fail "wrong policy ownership/mode"
[ -s "$scratch/after-policy" ] || fail "successful policy did not allow later steps"
assert_no_candidates

# A correct existing grant must not be rewritten; incorrect mode must repair.
touch -t 200101010101 "$policy"
before=$(stat -c '%i:%Y:%a' "$policy")
run_bootstrap || fail "idempotent run failed"
[ "$(stat -c '%i:%Y:%a' "$policy")" = "$before" ] || fail "unchanged policy was rewritten"
chmod 0644 "$policy"
run_bootstrap || fail "mode repair failed"
[ "$(sandbox stat -c '%u:%g:%a' /etc/sudoers.d/techdufus)" = '0:0:440' ] || fail "incorrect mode not repaired"
cmp -s "$policy" "$scratch/expected" || fail "mode repair changed grant"

# A root invocation is not a proxy for some environment-selected account.
reset_observations
before=$(stat -c '%i:%Y:%a' "$policy")
if sandbox env USER=environment_spoof SUDO_USER=environment_spoof \
  bash "$module_dir/bootstrap.sh" > "$scratch/output" 2>&1; then
  fail "root invocation accepted"
fi
[ ! -e "$scratch/sudo.calls" ] || fail "root invocation reached privileged boundary"
[ "$(stat -c '%i:%Y:%a' "$policy")" = "$before" ] || fail "root rejection changed policy"

# Refuse ambiguous special-file ownership without touching the target.
rm "$policy"
ln -s unrelated "$policy"
reset_observations
if run_bootstrap; then fail "symlink policy accepted"; fi
[ -L "$policy" ] || fail "symlink policy replaced"
[ ! -e "$scratch/after-policy" ] || fail "system steps ran after target rejection"
cmp -s "$scratch/policy/unrelated" "$scratch/unrelated-before" || fail "unrelated policy changed"
assert_no_candidates

# Initial provisioning also converges without any live destination writes.
rm "$policy"
run_bootstrap || fail "initial policy provisioning failed"
cmp -s "$policy" "$scratch/expected" || fail "initial grant incorrect"
assert_no_candidates
printf 'PASS: isolated sudoers candidate validation, identity, convergence and failure boundary\n'
