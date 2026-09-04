#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
zsh_bin="${ZSH_BIN:-zsh}"

if ! command -v "$zsh_bin" >/dev/null; then
  echo "SKIP: zsh not installed"
  exit 0
fi
zsh_bin="$(command -v "$zsh_bin")"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
bin_dir="$tmp_dir/bin"
home_dir="$tmp_dir/home"
secret_file="$home_dir/.config/zsh/vars.secret"
op_reads="$tmp_dir/op.reads"
mkdir -p "$bin_dir" "$home_dir/.config/zsh"
data_home="$tmp_dir/data"
zinit_home="$data_home/zinit/zinit.git"
mkdir -p "$zinit_home"
cat > "$zinit_home/zinit.zsh" <<'ZINIT'
zinit() { :; }
ZINIT
cp "$repo_root/roles/zsh/files/zsh/vars.secret_functions.zsh" \
  "$home_dir/.config/zsh/vars.secret_functions.zsh"

cat > "$bin_dir/op" <<'OP'
#!/usr/bin/env sh

# Serialize fixture writes; assertions compare the resulting read set.
record_read() {
  lock_dir="${OP_READS:?}.lock"
  until mkdir "$lock_dir" 2>/dev/null; do
    sleep 0.01
  done
  printf '%s\n' "$1" >> "${OP_READS:?}"
  rmdir "$lock_dir"
}

await_startup_peer() {
  case "$1" in
    op://fixture/startup-scope/alpha)
      ready_file="${OP_READS:?}.startup-alpha-ready"
      peer_file="${OP_READS:?}.startup-bravo-ready"
      ;;
    op://fixture/startup-scope/bravo)
      ready_file="${OP_READS:?}.startup-bravo-ready"
      peer_file="${OP_READS:?}.startup-alpha-ready"
      ;;
    *)
      return 1
      ;;
  esac

  : > "$ready_file"
  attempts=0
  # A liveness guard only: success requires both readiness markers, not speed.
  while [ ! -f "$peer_file" ]; do
    attempts=$((attempts + 1))
    [ "$attempts" -lt 1000 ] || return 1
    sleep 0.01
  done
}

case "${1-}" in
  vault)
    exit 71
    ;;
  read)
    reference=""
    for argument in "$@"; do
      reference="$argument"
    done

    case "$reference" in
      op://fixture/startup-prime)
        record_read "$reference"
        : > "${OP_READS:?}.startup-prime-ready"
        printf '%s\n' 'startup-scope'
        exit 0
        ;;
      op://fixture/startup-scope/alpha|op://fixture/startup-scope/bravo)
        [ -f "${OP_READS:?}.startup-prime-ready" ] || exit 75
        await_startup_peer "$reference" || exit 76
        ;;
    esac

    record_read "$reference"
    case "${OP_PROFILE_READ_MODE-}:${reference}" in
      conditional-failure:op://fixture/conditional-network|conditional-failure:op://fixture/conditional-local)
        exit 17
        ;;
    esac

    case "$reference" in
      op://fixture/reload-first) printf '%s\n' 'fixture-reload-first' ;;
      op://fixture/reload-second) printf '%s\n' 'fixture-reload-second' ;;
      op://fixture/startup-scope/alpha) printf '%s\n' 'fixture-startup-alpha' ;;
      op://fixture/startup-scope/bravo) printf '%s\n' 'fixture-startup-bravo' ;;
      op://fixture/failure-alpha) printf '%s\n' 'fixture-failure-alpha' ;;
      op://fixture/failure-bravo) exit 17 ;;
      op://fixture/empty) ;;
      op://fixture/conditional-alpha) printf '%s\n' 'fixture-conditional-alpha' ;;
      op://fixture/conditional-network) printf '%s\n' 'fixture-conditional-network' ;;
      op://fixture/conditional-local) printf '%s\n' 'fixture-conditional-local' ;;
      op://fixture/conditional-dependent) printf '%s\n' 'fixture-conditional-dependent' ;;
      op://fixture/prior-alpha) printf '%s\n' 'fixture-prior-alpha' ;;
      op://fixture/prior-bravo) printf '%s\n' 'fixture-prior-bravo' ;;
      op://fixture/current-gamma) printf '%s\n' 'fixture-current-gamma' ;;
      op://fixture/current-delta) exit 23 ;;
      op://fixture/inherited-alpha) printf '%s\n' 'fixture-inherited-alpha' ;;
      *) exit 70 ;;
    esac
    ;;
  *)
    exit 71
    ;;
esac
OP
chmod +x "$bin_dir/op"

cat > "$bin_dir/tailscale" <<'TAILSCALE'
#!/usr/bin/env sh

case "${TAILSCALE_IP_RESULT-}" in
  success) exit 0 ;;
  *) exit 1 ;;
esac
TAILSCALE
chmod +x "$bin_dir/tailscale"

expect_reads() {
  local expected actual
  expected="$(printf '%s\n' "$@" | LC_ALL=C sort)"
  actual="$(LC_ALL=C sort "$op_reads")"
  if [[ "$actual" != "$expected" ]]; then
    echo "unexpected fixture reads" >&2
    return 1
  fi
}

write_startup_profile() {
  cat > "$secret_file" <<'SECRETS'
TEST_STARTUP_ITEM="$(__secret_op_read --account "$TEST_ACCOUNT" "op://fixture/startup-prime")" || return 1
__secret_export_op_read TEST_STARTUP_ALPHA --account "$TEST_ACCOUNT" "op://fixture/${TEST_STARTUP_ITEM}/alpha" || return 1
__secret_export_op_read TEST_STARTUP_BRAVO --account "$TEST_ACCOUNT" "op://fixture/${TEST_STARTUP_ITEM}/bravo" || return 1
__secret_await_op_reads || return 1
unset TEST_STARTUP_ITEM
SECRETS
}

write_failed_read_profile() {
  cat > "$secret_file" <<'SECRETS'
__secret_export_op_read TEST_FAILURE_ALPHA --account "$TEST_ACCOUNT" "op://fixture/failure-alpha" || return 1
__secret_export_op_read TEST_FAILURE_BRAVO --account "$TEST_ACCOUNT" "op://fixture/failure-bravo" || return 1
__secret_await_op_reads || return 1
SECRETS
}

write_empty_profile() {
  cat > "$secret_file" <<'SECRETS'
__secret_export_op_read TEST_EMPTY_VALUE --account "$TEST_ACCOUNT" "op://fixture/empty" || return 1
__secret_await_op_reads || return 1
SECRETS
}

write_conditional_profile() {
  cat > "$secret_file" <<'SECRETS'
__secret_export_op_read TEST_CONDITIONAL_ALPHA --account "$TEST_ACCOUNT" "op://fixture/conditional-alpha" || return 1
if command -v tailscale >/dev/null 2>&1 && tailscale ip -4 >/dev/null 2>&1; then
  __secret_export_op_read TEST_CONDITIONAL_ENDPOINT --account "$TEST_ACCOUNT" "op://fixture/conditional-network" || return 1
else
  __secret_export_op_read TEST_CONDITIONAL_ENDPOINT --account "$TEST_ACCOUNT" "op://fixture/conditional-local" || return 1
fi
__secret_await_op_reads || return 1
export TEST_CONDITIONAL_DERIVED="$TEST_CONDITIONAL_ENDPOINT"
__secret_export_op_read TEST_CONDITIONAL_DEPENDENT --account "$TEST_ACCOUNT" "op://fixture/conditional-dependent" || return 1
__secret_await_op_reads || return 1
SECRETS
}

# --- a changed profile with the same inventory reloads its synthetic value ---
cat > "$secret_file" <<'SECRETS'
__secret_export_op_read TEST_RELOAD_VALUE --account "$TEST_ACCOUNT" "op://fixture/reload-first" || return 1
__secret_await_op_reads || return 1
SECRETS
: > "$op_reads"
reload_stdout="$tmp_dir/reload.stdout"
reload_stderr="$tmp_dir/reload.stderr"
if ! env -i \
  HOME="$home_dir" \
  PATH="$bin_dir:/usr/bin:/bin" \
  OP_READS="$op_reads" \
  TEST_ACCOUNT="fixture-account" \
  REPO_ROOT="$repo_root" \
  "$zsh_bin" -f >"$reload_stdout" 2>"$reload_stderr" <<'ZSH'
source "$REPO_ROOT/roles/zsh/files/zsh/vars.secret_functions.zsh"
secret --quiet || exit 1
[[ "$TEST_RELOAD_VALUE" == 'fixture-reload-first' ]] || exit 1
[[ -n "${SECRETS_LOADED_SIGNATURE-}" ]] || exit 1
cat > "$HOME/.config/zsh/vars.secret" <<'SECRETS'
__secret_export_op_read TEST_RELOAD_VALUE --account "$TEST_ACCOUNT" "op://fixture/reload-second" || return 1
__secret_await_op_reads || return 1
SECRETS
secret --quiet || exit 1
[[ "$TEST_RELOAD_VALUE" == 'fixture-reload-second' ]] || exit 1
[[ -n "${SECRETS_LOADED_SIGNATURE-}" ]] || exit 1
ZSH
then
  echo "changed profile did not reload" >&2
  exit 1
fi
if [[ -s "$reload_stdout" || -s "$reload_stderr" ]]; then
  echo "changed profile reload was not quiet" >&2
  exit 1
fi
if ! expect_reads \
  'op://fixture/reload-first' \
  'op://fixture/reload-second'; then
  exit 1
fi
echo "ok changed profile reloads"

# --- startup loads a primed concurrent wave without a session marker ---
write_startup_profile
: > "$op_reads"
rm -f \
  "$op_reads.startup-prime-ready" \
  "$op_reads.startup-alpha-ready" \
  "$op_reads.startup-bravo-ready"
startup_stdout="$tmp_dir/startup.stdout"
startup_stderr="$tmp_dir/startup.stderr"
if ! env -i \
  HOME="$home_dir" \
  PATH="$bin_dir:/usr/bin:/bin" \
  OP_READS="$op_reads" \
  TEST_ACCOUNT="fixture-account" \
  XDG_DATA_HOME="$data_home" \
  REPO_ROOT="$repo_root" \
  "$zsh_bin" -f >"$startup_stdout" 2>"$startup_stderr" <<'ZSH'
source "$REPO_ROOT/roles/zsh/files/.zshrc"
[[ "$TEST_STARTUP_ALPHA" == 'fixture-startup-alpha' ]] || exit 1
[[ "$TEST_STARTUP_BRAVO" == 'fixture-startup-bravo' ]] || exit 1
(( ! ${+parameters[TEST_STARTUP_ITEM]} )) || exit 1
[[ "${SECRETS_ALREADY_LOADED-}" == true ]] || exit 1
[[ -n "${SECRETS_LOADED_AT-}" ]] || exit 1
[[ -n "${SECRETS_LOADED_VARS-}" ]] || exit 1
[[ -n "${SECRETS_LOADED_SIGNATURE-}" ]] || exit 1
ZSH
then
  echo "startup did not complete the primed concurrent secret wave" >&2
  exit 1
fi
if [[ -s "$startup_stdout" || -s "$startup_stderr" ]]; then
  echo "successful startup was not quiet" >&2
  exit 1
fi
if ! expect_reads \
  'op://fixture/startup-prime' \
  'op://fixture/startup-scope/alpha' \
  'op://fixture/startup-scope/bravo'; then
  exit 1
fi
echo "ok startup loads a primed concurrent secret wave"

# --- startup warns once and continues after an unavailable secret read ---
write_failed_read_profile
: > "$op_reads"
startup_failure_body="$tmp_dir/startup-failure.body"
startup_failure_stdout="$tmp_dir/startup-failure.stdout"
startup_failure_stderr="$tmp_dir/startup-failure.stderr"
: > "$startup_failure_body"
if ! env -i \
  HOME="$home_dir" \
  PATH="$bin_dir:/usr/bin:/bin" \
  OP_READS="$op_reads" \
  TEST_ACCOUNT="fixture-account" \
  XDG_DATA_HOME="$data_home" \
  BODY_CALLS="$startup_failure_body" \
  REPO_ROOT="$repo_root" \
  "$zsh_bin" -f >"$startup_failure_stdout" 2>"$startup_failure_stderr" <<'ZSH'
source "$REPO_ROOT/roles/zsh/files/.zshrc"
print -r -- continued > "$BODY_CALLS"
ZSH
then
  echo "startup stopped after an unavailable secret read" >&2
  exit 1
fi
if [[ -s "$startup_failure_stdout" ]]; then
  echo "failed startup wrote stdout" >&2
  exit 1
fi
if [[ "$(<"$startup_failure_stderr")" != 'Warning: 1Password secrets are unavailable; continuing without them' ]]; then
  echo "startup warning was not generic and singular" >&2
  exit 1
fi
if [[ "$(<"$startup_failure_body")" != continued ]]; then
  echo "startup did not continue to the command body" >&2
  exit 1
fi
if ! expect_reads \
  'op://fixture/failure-alpha' \
  'op://fixture/failure-bravo'; then
  exit 1
fi
echo "ok startup warns and continues"

# --- failed and empty reads leave no partial exports or loaded metadata ---
write_failed_read_profile
: > "$op_reads"
read_failure_stdout="$tmp_dir/read-failure.stdout"
read_failure_stderr="$tmp_dir/read-failure.stderr"
if ! env -i \
  HOME="$home_dir" \
  PATH="$bin_dir:/usr/bin:/bin" \
  OP_READS="$op_reads" \
  TEST_ACCOUNT="fixture-account" \
  REPO_ROOT="$repo_root" \
  "$zsh_bin" -f >"$read_failure_stdout" 2>"$read_failure_stderr" <<'ZSH'
source "$REPO_ROOT/roles/zsh/files/zsh/vars.secret_functions.zsh"
if secret --quiet; then
  exit 1
fi
for name in TEST_FAILURE_ALPHA TEST_FAILURE_BRAVO SECRETS_ALREADY_LOADED SECRETS_LOADED_AT SECRETS_LOADED_VARS SECRETS_LOADED_SIGNATURE; do
  (( ! ${+parameters[$name]} )) || exit 1
done
ZSH
then
  echo "failed read left secret state" >&2
  exit 1
fi
if [[ -s "$read_failure_stdout" || -s "$read_failure_stderr" ]]; then
  echo "failed read was not quiet" >&2
  exit 1
fi
if ! expect_reads \
  'op://fixture/failure-alpha' \
  'op://fixture/failure-bravo'; then
  exit 1
fi

write_empty_profile
: > "$op_reads"
empty_stdout="$tmp_dir/empty.stdout"
empty_stderr="$tmp_dir/empty.stderr"
if ! env -i \
  HOME="$home_dir" \
  PATH="$bin_dir:/usr/bin:/bin" \
  OP_READS="$op_reads" \
  TEST_ACCOUNT="fixture-account" \
  REPO_ROOT="$repo_root" \
  "$zsh_bin" -f >"$empty_stdout" 2>"$empty_stderr" <<'ZSH'
source "$REPO_ROOT/roles/zsh/files/zsh/vars.secret_functions.zsh"
if secret --quiet; then
  exit 1
fi
for name in TEST_EMPTY_VALUE SECRETS_ALREADY_LOADED SECRETS_LOADED_AT SECRETS_LOADED_VARS SECRETS_LOADED_SIGNATURE; do
  (( ! ${+parameters[$name]} )) || exit 1
done
ZSH
then
  echo "empty read left secret state" >&2
  exit 1
fi
if [[ -s "$empty_stdout" || -s "$empty_stderr" ]]; then
  echo "empty read was not quiet" >&2
  exit 1
fi
if ! expect_reads 'op://fixture/empty'; then
  exit 1
fi
echo "ok failed and empty reads clear state"

# --- a conditional failure stops before a dependent read ---
write_conditional_profile
: > "$op_reads"
conditional_stdout="$tmp_dir/conditional.stdout"
conditional_stderr="$tmp_dir/conditional.stderr"
if ! env -i \
  HOME="$home_dir" \
  PATH="$bin_dir:/usr/bin:/bin" \
  OP_READS="$op_reads" \
  OP_PROFILE_READ_MODE=conditional-failure \
  TAILSCALE_IP_RESULT=failure \
  TEST_ACCOUNT="fixture-account" \
  REPO_ROOT="$repo_root" \
  "$zsh_bin" -f >"$conditional_stdout" 2>"$conditional_stderr" <<'ZSH'
source "$REPO_ROOT/roles/zsh/files/zsh/vars.secret_functions.zsh"
if secret --quiet; then
  exit 1
fi
for name in TEST_CONDITIONAL_ALPHA TEST_CONDITIONAL_ENDPOINT TEST_CONDITIONAL_DERIVED TEST_CONDITIONAL_DEPENDENT SECRETS_ALREADY_LOADED SECRETS_LOADED_AT SECRETS_LOADED_VARS SECRETS_LOADED_SIGNATURE; do
  (( ! ${+parameters[$name]} )) || exit 1
done
ZSH
then
  echo "conditional failure left secret state" >&2
  exit 1
fi
if [[ -s "$conditional_stdout" || -s "$conditional_stderr" ]]; then
  echo "conditional failure was not quiet" >&2
  exit 1
fi
if ! expect_reads \
  'op://fixture/conditional-alpha' \
  'op://fixture/conditional-local'; then
  exit 1
fi
echo "ok conditional failure stops dependent read"

# --- a failed explicit reload clears prior and current inventories ---
cat > "$secret_file" <<'SECRETS'
__secret_export_op_read TEST_PRIOR_ALPHA --account "$TEST_ACCOUNT" "op://fixture/prior-alpha" || return 1
__secret_export_op_read TEST_PRIOR_BRAVO --account "$TEST_ACCOUNT" "op://fixture/prior-bravo" || return 1
__secret_await_op_reads || return 1
SECRETS
: > "$op_reads"
reload_failure_stdout="$tmp_dir/reload-failure.stdout"
reload_failure_stderr="$tmp_dir/reload-failure.stderr"
if ! env -i \
  HOME="$home_dir" \
  PATH="$bin_dir:/usr/bin:/bin" \
  OP_READS="$op_reads" \
  TEST_ACCOUNT="fixture-account" \
  REPO_ROOT="$repo_root" \
  "$zsh_bin" -f >"$reload_failure_stdout" 2>"$reload_failure_stderr" <<'ZSH'
source "$REPO_ROOT/roles/zsh/files/zsh/vars.secret_functions.zsh"
secret --quiet || exit 1
[[ "$TEST_PRIOR_ALPHA" == 'fixture-prior-alpha' ]] || exit 1
[[ "$TEST_PRIOR_BRAVO" == 'fixture-prior-bravo' ]] || exit 1
cat > "$HOME/.config/zsh/vars.secret" <<'SECRETS'
__secret_export_op_read TEST_CURRENT_GAMMA --account "$TEST_ACCOUNT" "op://fixture/current-gamma" || return 1
__secret_export_op_read TEST_CURRENT_DELTA --account "$TEST_ACCOUNT" "op://fixture/current-delta" || return 1
__secret_await_op_reads || return 1
SECRETS
if secret --quiet --reload; then
  exit 1
fi
for name in TEST_PRIOR_ALPHA TEST_PRIOR_BRAVO TEST_CURRENT_GAMMA TEST_CURRENT_DELTA SECRETS_ALREADY_LOADED SECRETS_LOADED_AT SECRETS_LOADED_VARS SECRETS_LOADED_SIGNATURE; do
  (( ! ${+parameters[$name]} )) || exit 1
done
ZSH
then
  echo "failed reload left secret state" >&2
  exit 1
fi
if [[ -s "$reload_failure_stdout" || -s "$reload_failure_stderr" ]]; then
  echo "failed reload was not quiet" >&2
  exit 1
fi
if ! expect_reads \
  'op://fixture/prior-alpha' \
  'op://fixture/prior-bravo' \
  'op://fixture/current-gamma' \
  'op://fixture/current-delta'; then
  exit 1
fi
echo "ok failed reload clears inventories"

# --- incomplete inherited metadata cannot suppress a required reload ---
cat > "$secret_file" <<'SECRETS'
__secret_export_op_read TEST_INHERITED_ALPHA --account "$TEST_ACCOUNT" "op://fixture/inherited-alpha" || return 1
__secret_await_op_reads || return 1
SECRETS
: > "$op_reads"
inherited_stdout="$tmp_dir/inherited.stdout"
inherited_stderr="$tmp_dir/inherited.stderr"
if ! env -i \
  HOME="$home_dir" \
  PATH="$bin_dir:/usr/bin:/bin" \
  OP_READS="$op_reads" \
  TEST_ACCOUNT="fixture-account" \
  SECRETS_ALREADY_LOADED=true \
  REPO_ROOT="$repo_root" \
  "$zsh_bin" -f >"$inherited_stdout" 2>"$inherited_stderr" <<'ZSH'
source "$REPO_ROOT/roles/zsh/files/zsh/vars.secret_functions.zsh"
secret --quiet || exit 1
[[ "$TEST_INHERITED_ALPHA" == 'fixture-inherited-alpha' ]] || exit 1
[[ "${SECRETS_ALREADY_LOADED-}" == true ]] || exit 1
[[ -n "${SECRETS_LOADED_VARS-}" ]] || exit 1
[[ -n "${SECRETS_LOADED_SIGNATURE-}" ]] || exit 1
ZSH
then
  echo "incomplete inherited metadata suppressed reload" >&2
  exit 1
fi
if [[ -s "$inherited_stdout" || -s "$inherited_stderr" ]]; then
  echo "inherited metadata reload was not quiet" >&2
  exit 1
fi
if ! expect_reads 'op://fixture/inherited-alpha'; then
  exit 1
fi
echo "ok incomplete inherited metadata reloads"

echo "ok secret startup"
