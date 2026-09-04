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
op_operations="$tmp_dir/op.operations"
op_accounts="$tmp_dir/op.accounts"
secret_tmp_dir="$tmp_dir/secret-tmp"
mkdir -p "$bin_dir" "$home_dir/.config/zsh" "$secret_tmp_dir"
cp "$repo_root/roles/zsh/files/zsh/vars.secret_functions.zsh" \
  "$home_dir/.config/zsh/vars.secret_functions.zsh"

cat > "$bin_dir/op" <<'OP'
#!/usr/bin/env sh

record_fixture() {
  file="$1"
  value="$2"
  lock_dir="$file.lock"
  attempts=0
  until mkdir "$lock_dir" 2>/dev/null; do
    attempts=$((attempts + 1))
    [ "$attempts" -lt 400 ] || exit 72
    sleep 0.01
  done
  printf '%s\n' "$value" >> "$file"
  rmdir "$lock_dir"
}

record_operation() {
  record_fixture "${OP_OPERATIONS:?}" "$1"
}

record_account() {
  record_fixture "${OP_ACCOUNTS:?}" "$1"
}

resolve_reference() {
  case "${OP_PROFILE_READ_MODE-}:$1" in
    conditional-failure:op://fixture/conditional-network|conditional-failure:op://fixture/conditional-local)
      return 17
      ;;
  esac

  case "$1" in
    op://fixture/reload-first) printf '%s' 'fixture-reload-first' ;;
    op://fixture/reload-second) printf '%s' 'fixture-reload-second' ;;
    op://fixture/parallel-alpha) printf '%s' 'fixture-parallel-alpha' ;;
    op://fixture/parallel-bravo) printf '%s' 'fixture-parallel-bravo' ;;
    op://fixture/failure-alpha) printf '%s' 'fixture-failure-alpha' ;;
    op://fixture/failure-bravo) return 17 ;;
    op://fixture/empty) ;;
    op://fixture/malformed-alpha) printf '%s' 'fixture-malformed-alpha' ;;
    op://fixture/malformed-bravo) printf '%s' 'fixture-malformed-bravo' ;;
    op://fixture/conditional-alpha) printf '%s' 'fixture-conditional-alpha' ;;
    op://fixture/conditional-network) printf '%s' 'fixture-conditional-network' ;;
    op://fixture/conditional-local) printf '%s' 'fixture-conditional-local' ;;
    op://fixture/conditional-dependent) printf '%s' 'fixture-conditional-dependent' ;;
    op://fixture/prior-alpha) printf '%s' 'fixture-prior-alpha' ;;
    op://fixture/prior-bravo) printf '%s' 'fixture-prior-bravo' ;;
    op://fixture/current-gamma) printf '%s' 'fixture-current-gamma' ;;
    op://fixture/current-delta) return 23 ;;
    op://fixture/inherited-alpha) printf '%s' 'fixture-inherited-alpha' ;;
    op://fixture/mixed-alpha) printf '%s' 'fixture-mixed-alpha' ;;
    op://fixture/mixed-bravo) printf '%s' 'fixture-mixed-bravo' ;;
    op://fixture/mixed-failure) return 29 ;;
    op://fixture/readonly-target) printf '%s' 'fixture-readonly-target' ;;
    op://fixture/readonly-other) printf '%s' 'fixture-readonly-other' ;;
    op://fixture/unrelated-alpha) printf '%s' 'fixture-unrelated-alpha' ;;
    op://fixture/unset-target) printf '%s' 'fixture-unset-target' ;;
    op://fixture/var-target) printf '%s' 'fixture-var-target' ;;
    *) return 70 ;;
  esac
}

await_read_peer() {
  marker_dir="${OP_READ_BARRIER:?}"
  mkdir -p "$marker_dir" || exit 72
  marker="$marker_dir/$$"
  : > "$marker"
  attempts=0

  while :; do
    peer_count=0
    for peer in "$marker_dir"/*; do
      [ -e "$peer" ] || continue
      peer_count=$((peer_count + 1))
    done
    [ "$peer_count" -ge 2 ] && break
    attempts=$((attempts + 1))
    if [ "$attempts" -ge 200 ]; then
      rm -f "$marker"
      exit 73
    fi
    sleep 0.01
  done

}

case "${1-}" in
  vault)
    exit 0
    ;;
  read)
    shift
    reference=""
    for argument in "$@"; do
      reference="$argument"
    done
    record_operation read

    if [ -n "${OP_REJECT_CONCURRENT_READS-}" ]; then
      if ! mkdir "${OP_CONCURRENT_READ_LOCK:?}" 2>/dev/null; then
        exit 74
      fi
      sleep 0.1
      rmdir "${OP_CONCURRENT_READ_LOCK:?}"
    fi
    if [ -n "${OP_REQUIRE_READ_OVERLAP-}" ]; then
      await_read_peer
    fi
    resolve_reference "$reference"
    ;;
  run)
    shift
    account="${2-}"
    [ "${1-}" = --account ] && [ -n "$account" ] &&
      [ "${3-}" = --no-masking ] && [ "${4-}" = -- ] &&
      [ -n "${5-}" ] || exit 71
    case "$account" in
      fixture-account|fixture-second-account) ;;
      *) exit 75 ;;
    esac
    shift 4
    record_operation run
    if [ -n "${OP_ACCOUNTS-}" ]; then
      record_account "$account"
    fi

    run_lock=""
    assignments=""
    cleanup_run() {
      [ -z "$assignments" ] || rm -f "$assignments"
      [ -z "$run_lock" ] || rmdir "$run_lock" 2>/dev/null || true
    }
    trap cleanup_run EXIT HUP INT TERM
    if [ -n "${OP_REJECT_CONCURRENT_RUNS-}" ]; then
      run_lock="${OP_CONCURRENT_RUN_LOCK:?}"
      if ! mkdir "$run_lock" 2>/dev/null; then
        exit 76
      fi
      sleep 0.1
    fi

    assignments="$(umask 077; mktemp "${TMPDIR:-/tmp}/op-run.XXXXXX")" || exit 72
    if ! env | while IFS= read -r entry; do
      name="${entry%%=*}"
      reference="${entry#*=}"
      case "$reference" in
        op://fixture/*)
          value="$(resolve_reference "$reference")" || exit "$?"
          printf '%s\t%s\n' "$name" "$value" >> "$assignments"
          ;;
        op://*)
          exit 28
          ;;
      esac
    done
    then
      exit 17
    fi

    while IFS='	' read -r name value; do
      export "$name=$value" || exit 17
    done < "$assignments"
    rm -f "$assignments"
    assignments=""

    if [ "${OP_BATCH_OUTPUT_MODE-}" = malformed ]; then
      "$@" >/dev/null || exit "$?"
      printf '\0'
      exit 0
    fi
    "$@"
    child_status="$?"
    exit "$child_status"
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

cat > "$home_dir/.config/zsh/secret_batch_test_helper.zsh" <<'ZSH'
functions -c __secret_op_run_environment_allowed __secret_test_original_op_run_environment_allowed
function __secret_op_run_environment_allowed() {
  case "$1" in
    OP_OPERATIONS|OP_ACCOUNTS|OP_PROFILE_READ_MODE|OP_BATCH_OUTPUT_MODE|OP_REJECT_CONCURRENT_RUNS|OP_CONCURRENT_RUN_LOCK)
      return 0
      ;;
  esac
  __secret_test_original_op_run_environment_allowed "$@"
}
function __secret_use_single_process_batch() {
  return 0
}
ZSH

expect_operations() {
  local expected actual
  expected="$(printf '%s\n' "$@" | LC_ALL=C sort)"
  actual="$(LC_ALL=C sort "$op_operations")"
  if [[ "$actual" != "$expected" ]]; then
    echo "unexpected fixture operations" >&2
    return 1
  fi
}
expect_accounts() {
  local expected actual
  expected="$(printf '%s\n' "$@")"
  actual="$(<"$op_accounts")"
  if [[ "$actual" != "$expected" ]]; then
    echo "unexpected fixture accounts" >&2
    return 1
  fi
}

assert_no_secret_tmpdirs() {
  local label="$1"
  if compgen -G "$secret_tmp_dir/zsh-secret.*" >/dev/null; then
    echo "$label left a secret temporary directory" >&2
    return 1
  fi
}

write_failed_read_profile() {
  cat > "$secret_file" <<'SECRETS'
__secret_export_op_read TEST_FAILURE_ALPHA --account "$TEST_ACCOUNT" "op://fixture/failure-alpha" || return 1
__secret_export_op_read TEST_FAILURE_BRAVO --account "$TEST_ACCOUNT" "op://fixture/failure-bravo" || return 1
SECRETS
}

write_empty_profile() {
  cat > "$secret_file" <<'SECRETS'
__secret_export_op_read TEST_EMPTY_VALUE --account "$TEST_ACCOUNT" "op://fixture/empty" || return 1
SECRETS
}

write_malformed_profile() {
  cat > "$secret_file" <<'SECRETS'
__secret_export_op_read TEST_MALFORMED_ALPHA --account "$TEST_ACCOUNT" "op://fixture/malformed-alpha" || return 1
__secret_export_op_read TEST_MALFORMED_BRAVO --account "$TEST_ACCOUNT" "op://fixture/malformed-bravo" || return 1
SECRETS
}

write_mixed_account_profile() {
  local second_reference="$1"
  cat > "$secret_file" <<SECRETS
__secret_export_op_read TEST_MIXED_ALPHA --account "\$TEST_ACCOUNT" "op://fixture/mixed-alpha" || return 1
__secret_export_op_read TEST_MIXED_BRAVO --account "\$TEST_SECOND_ACCOUNT" "$second_reference" || return 1
(( ! \${+TEST_MIXED_ALPHA} && ! \${+TEST_MIXED_BRAVO} )) || return 1
SECRETS
}

write_non_op_reference_profile() {
  cat > "$secret_file" <<'SECRETS'
__secret_export_op_read TEST_NON_OP_VALUE --account "$TEST_ACCOUNT" "not-an-op-reference" || return 1
SECRETS
}

write_readonly_profile() {
  cat > "$secret_file" <<'SECRETS'
__secret_export_op_read TEST_READONLY_TARGET --account "$TEST_ACCOUNT" "op://fixture/readonly-target" || return 1
__secret_export_op_read TEST_READONLY_OTHER --account "$TEST_ACCOUNT" "op://fixture/readonly-other" || return 1
SECRETS
}

write_unrelated_reference_profile() {
  cat > "$secret_file" <<'SECRETS'
__secret_export_op_read TEST_UNRELATED_BATCH_VALUE --account "$TEST_ACCOUNT" "op://fixture/unrelated-alpha" || return 1
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
SECRETS
}

# --- a changed profile with the same inventory reloads its synthetic value ---
cat > "$secret_file" <<'SECRETS'
__secret_export_op_read TEST_RELOAD_VALUE --account "$TEST_ACCOUNT" "op://fixture/reload-first" || return 1
SECRETS
: > "$op_operations"
reload_stdout="$tmp_dir/reload.stdout"
reload_stderr="$tmp_dir/reload.stderr"
if ! env -i \
  HOME="$home_dir" \
  PATH="$bin_dir:/usr/bin:/bin" \
  TMPDIR="$secret_tmp_dir" \
  OP_OPERATIONS="$op_operations" \
  TEST_ACCOUNT="fixture-account" \
  REPO_ROOT="$repo_root" \
  "$zsh_bin" -f >"$reload_stdout" 2>"$reload_stderr" <<'ZSH'
source "$REPO_ROOT/roles/zsh/files/zsh/vars.secret_functions.zsh"
source "$HOME/.config/zsh/secret_batch_test_helper.zsh"
secret --quiet || exit 1
[[ "$TEST_RELOAD_VALUE" == 'fixture-reload-first' ]] || exit 1
[[ -n "${SECRETS_LOADED_SIGNATURE-}" ]] || exit 1
cat > "$HOME/.config/zsh/vars.secret" <<'SECRETS'
__secret_export_op_read TEST_RELOAD_VALUE --account "$TEST_ACCOUNT" "op://fixture/reload-second" || return 1
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
if ! expect_operations run run; then
  exit 1
fi
assert_no_secret_tmpdirs "successful batch"
echo "ok changed profile reloads"

# --- failed, empty, and malformed batches leave no partial exports or metadata ---
write_failed_read_profile
: > "$op_operations"
read_failure_stdout="$tmp_dir/read-failure.stdout"
read_failure_stderr="$tmp_dir/read-failure.stderr"
if ! env -i \
  HOME="$home_dir" \
  PATH="$bin_dir:/usr/bin:/bin" \
  TMPDIR="$secret_tmp_dir" \
  OP_OPERATIONS="$op_operations" \
  TEST_ACCOUNT="fixture-account" \
  REPO_ROOT="$repo_root" \
  "$zsh_bin" -f >"$read_failure_stdout" 2>"$read_failure_stderr" <<'ZSH'
source "$REPO_ROOT/roles/zsh/files/zsh/vars.secret_functions.zsh"
source "$HOME/.config/zsh/secret_batch_test_helper.zsh"
if secret --quiet; then
  exit 1
fi
for name in TEST_FAILURE_ALPHA TEST_FAILURE_BRAVO SECRETS_ALREADY_LOADED SECRETS_LOADED_AT SECRETS_LOADED_VARS SECRETS_LOADED_SIGNATURE; do
  (( ! ${+parameters[$name]} )) || exit 1
done
ZSH
then
  echo "failed batch left secret state" >&2
  exit 1
fi
if [[ -s "$read_failure_stdout" || -s "$read_failure_stderr" ]]; then
  echo "failed batch was not quiet" >&2
  exit 1
fi
if ! expect_operations run; then
  exit 1
fi
assert_no_secret_tmpdirs "failed batch"

write_empty_profile
: > "$op_operations"
empty_stdout="$tmp_dir/empty.stdout"
empty_stderr="$tmp_dir/empty.stderr"
if ! env -i \
  HOME="$home_dir" \
  PATH="$bin_dir:/usr/bin:/bin" \
  OP_OPERATIONS="$op_operations" \
  TEST_ACCOUNT="fixture-account" \
  REPO_ROOT="$repo_root" \
  "$zsh_bin" -f >"$empty_stdout" 2>"$empty_stderr" <<'ZSH'
source "$REPO_ROOT/roles/zsh/files/zsh/vars.secret_functions.zsh"
source "$HOME/.config/zsh/secret_batch_test_helper.zsh"
if secret --quiet; then
  exit 1
fi
for name in TEST_EMPTY_VALUE SECRETS_ALREADY_LOADED SECRETS_LOADED_AT SECRETS_LOADED_VARS SECRETS_LOADED_SIGNATURE; do
  (( ! ${+parameters[$name]} )) || exit 1
done
ZSH
then
  echo "empty batch left secret state" >&2
  exit 1
fi
if [[ -s "$empty_stdout" || -s "$empty_stderr" ]]; then
  echo "empty batch was not quiet" >&2
  exit 1
fi
if ! expect_operations run; then
  exit 1
fi

write_malformed_profile
: > "$op_operations"
malformed_stdout="$tmp_dir/malformed.stdout"
malformed_stderr="$tmp_dir/malformed.stderr"
if ! env -i \
  HOME="$home_dir" \
  PATH="$bin_dir:/usr/bin:/bin" \
  OP_OPERATIONS="$op_operations" \
  OP_BATCH_OUTPUT_MODE=malformed \
  TEST_ACCOUNT="fixture-account" \
  REPO_ROOT="$repo_root" \
  "$zsh_bin" -f >"$malformed_stdout" 2>"$malformed_stderr" <<'ZSH'
source "$REPO_ROOT/roles/zsh/files/zsh/vars.secret_functions.zsh"
source "$HOME/.config/zsh/secret_batch_test_helper.zsh"
if secret --quiet; then
  exit 1
fi
for name in TEST_MALFORMED_ALPHA TEST_MALFORMED_BRAVO SECRETS_ALREADY_LOADED SECRETS_LOADED_AT SECRETS_LOADED_VARS SECRETS_LOADED_SIGNATURE; do
  (( ! ${+parameters[$name]} )) || exit 1
done
ZSH
then
  echo "malformed batch left secret state" >&2
  exit 1
fi
if [[ -s "$malformed_stdout" || -s "$malformed_stderr" ]]; then
  echo "malformed batch was not quiet" >&2
  exit 1
fi
if ! expect_operations run; then
  exit 1
fi
echo "ok failed, empty, and malformed batches clear state"

# --- cleanup locals cannot shadow a valid secret target ---
cat > "$secret_file" <<'SECRETS'
__secret_export_op_read __secret_unset_target --account "$TEST_ACCOUNT" "op://fixture/unset-target" || return 1
__secret_export_op_read var --account "$TEST_ACCOUNT" "op://fixture/var-target" || return 1
SECRETS
: > "$op_operations"
unset_collision_stdout="$tmp_dir/unset-collision.stdout"
unset_collision_stderr="$tmp_dir/unset-collision.stderr"
if ! env -i \
  HOME="$home_dir" \
  PATH="$bin_dir:/usr/bin:/bin" \
  TMPDIR="$secret_tmp_dir" \
  OP_OPERATIONS="$op_operations" \
  TEST_ACCOUNT="fixture-account" \
  REPO_ROOT="$repo_root" \
  "$zsh_bin" -f >"$unset_collision_stdout" 2>"$unset_collision_stderr" <<'ZSH'
source "$REPO_ROOT/roles/zsh/files/zsh/vars.secret_functions.zsh"
source "$HOME/.config/zsh/secret_batch_test_helper.zsh"
secret --quiet || exit 1
[[ "$__secret_unset_target" == 'fixture-unset-target' ]] || exit 1
[[ "$var" == 'fixture-var-target' ]] || exit 1
secret --quiet --clear || exit 1
for name in __secret_unset_target var; do
  (( ! ${+parameters[$name]} )) || exit 1
done
secret --quiet || exit 1
cat > "$HOME/.config/zsh/vars.secret" <<'SECRETS'
__secret_export_op_read __secret_unset_target --account "$TEST_ACCOUNT" "op://fixture/unset-target" || return 1
__secret_export_op_read var --account "$TEST_ACCOUNT" "op://fixture/var-target" || return 1
__secret_export_op_read TEST_FAILURE_BRAVO --account "$TEST_ACCOUNT" "op://fixture/failure-bravo" || return 1
SECRETS
if secret --quiet --reload; then
  exit 1
fi
for name in __secret_unset_target var TEST_FAILURE_BRAVO SECRETS_ALREADY_LOADED SECRETS_LOADED_AT SECRETS_LOADED_VARS SECRETS_LOADED_SIGNATURE; do
  (( ! ${+parameters[$name]} )) || exit 1
done
cat > "$HOME/.config/zsh/vars.secret" <<'SECRETS'
export __secret_internal_direct='fixture-reserved-direct'
SECRETS
if secret --quiet; then
  exit 1
fi
(( ! ${+parameters[__secret_internal_direct]} )) || exit 1
cat > "$HOME/.config/zsh/vars.secret" <<'SECRETS'
__secret_export_op_read __SECRET_OP_BATCH_OUT --account "$TEST_ACCOUNT" "op://fixture/unset-target" || return 1
SECRETS
if secret --quiet; then
  exit 1
fi
(( ! ${+parameters[__SECRET_OP_BATCH_OUT]} )) || exit 1
ZSH
then
  echo "cleanup variable collision left secret state" >&2
  exit 1
fi
if [[ -s "$unset_collision_stdout" || -s "$unset_collision_stderr" ]]; then
  echo "cleanup variable collision check was not quiet" >&2
  exit 1
fi
if ! expect_operations run run run; then
  exit 1
fi
assert_no_secret_tmpdirs "cleanup collision"
echo "ok cleanup variable names do not shadow secret targets"

# --- inherited internal temp state cannot control recursive cleanup ---
protected_dir="$tmp_dir/protected-path"
protected_marker="$protected_dir/keep"
mkdir -p "$protected_dir"
: > "$protected_marker"
temp_state_stdout="$tmp_dir/temp-state.stdout"
temp_state_stderr="$tmp_dir/temp-state.stderr"
if ! env -i \
  HOME="$home_dir" \
  PATH="$bin_dir:/usr/bin:/bin" \
  __SECRET_OP_TMPDIR="$protected_dir" \
  __SECRET_OP_PIDS="12345" \
  __SECRET_OP_VARS="TEST_IMPORTED" \
  __SECRET_OP_OUT="fixture-imported" \
  __SECRET_OP_RC="fixture-imported" \
  __SECRET_OP_REF="fixture-imported" \
  __SECRET_OP_ACCOUNT="fixture-imported" \
  __SECRET_OP_BATCH_OUT="fixture-imported" \
  REPO_ROOT="$repo_root" \
  "$zsh_bin" -f >"$temp_state_stdout" 2>"$temp_state_stderr" <<'ZSH'
typeset -g inherited_process_calls=0
kill() { (( inherited_process_calls += 1 )); }
wait() { (( inherited_process_calls += 1 )); }
source "$REPO_ROOT/roles/zsh/files/zsh/vars.secret_functions.zsh"
secret --quiet --clear || exit 1
[[ -z "${__SECRET_OP_TMPDIR-}" ]] || exit 1
(( inherited_process_calls == 0 )) || exit 1
(( ${#__SECRET_OP_PIDS[@]} == 0 )) || exit 1
for name in __SECRET_OP_PIDS __SECRET_OP_VARS __SECRET_OP_OUT __SECRET_OP_RC __SECRET_OP_REF __SECRET_OP_ACCOUNT; do
  [[ "${parameters[$name]}" != *export* ]] || exit 1
done
ZSH
then
  echo "inherited temporary state cleanup failed" >&2
  exit 1
fi
if [[ ! -f "$protected_marker" ]]; then
  echo "inherited temporary state controlled recursive cleanup" >&2
  exit 1
fi
if [[ -s "$temp_state_stdout" || -s "$temp_state_stderr" ]]; then
  echo "inherited temporary state cleanup was not quiet" >&2
  exit 1
fi
echo "ok inherited temporary state is not trusted"

# --- agent startup clears inherited declared secrets without querying op ---
cat > "$secret_file" <<'SECRETS'
export TEST_AGENT_INHERITED='fixture-profile-value'
export __secret_internal_direct='fixture-reserved-profile-value'
SECRETS
: > "$op_operations"
agent_clear_stdout="$tmp_dir/agent-clear.stdout"
agent_clear_stderr="$tmp_dir/agent-clear.stderr"
if ! env -i \
  HOME="$home_dir" \
  PATH="$bin_dir:/usr/bin:/bin" \
  OP_OPERATIONS="$op_operations" \
  TEST_AGENT_INHERITED="fixture-inherited-value" \
  __secret_internal_direct="fixture-reserved-inherited-value" \
  SECRETS_ALREADY_LOADED=true \
  SECRETS_LOADED_AT="fixture-time" \
  SECRETS_LOADED_VARS=$'TEST_AGENT_INHERITED\n__secret_internal_direct' \
  SECRETS_LOADED_SIGNATURE="fixture-signature" \
  REPO_ROOT="$repo_root" \
  "$zsh_bin" -f >"$agent_clear_stdout" 2>"$agent_clear_stderr" <<'ZSH'
source "$REPO_ROOT/roles/zsh/files/zsh/vars.secret_functions.zsh"
is_agent_shell() { return 0; }
if is_agent_shell; then
  secret --quiet --clear >/dev/null 2>&1 || true
else
  exit 1
fi
for name in TEST_AGENT_INHERITED __secret_internal_direct SECRETS_ALREADY_LOADED SECRETS_LOADED_AT SECRETS_LOADED_VARS SECRETS_LOADED_SIGNATURE; do
  (( ! ${+parameters[$name]} )) || exit 1
done
ZSH
then
  echo "agent startup did not clear inherited secret state" >&2
  exit 1
fi
if [[ -s "$agent_clear_stdout" || -s "$agent_clear_stderr" ]]; then
  echo "agent inherited-state cleanup was not quiet" >&2
  exit 1
fi
if [[ -s "$op_operations" ]]; then
  echo "agent inherited-state cleanup queried 1Password" >&2
  exit 1
fi
echo "ok agent startup clears inherited secret state"

# --- mixed-account waves are serialized and commit only after every batch succeeds ---
write_mixed_account_profile "op://fixture/mixed-bravo"
: > "$op_operations"
: > "$op_accounts"
mixed_stdout="$tmp_dir/mixed.stdout"
mixed_stderr="$tmp_dir/mixed.stderr"
if ! env -i \
  HOME="$home_dir" \
  PATH="$bin_dir:/usr/bin:/bin" \
  OP_OPERATIONS="$op_operations" \
  OP_ACCOUNTS="$op_accounts" \
  OP_REJECT_CONCURRENT_RUNS=1 \
  OP_CONCURRENT_RUN_LOCK="$tmp_dir/mixed-run-lock" \
  TEST_ACCOUNT="fixture-account" \
  TEST_SECOND_ACCOUNT="fixture-second-account" \
  REPO_ROOT="$repo_root" \
  "$zsh_bin" -f >"$mixed_stdout" 2>"$mixed_stderr" <<'ZSH'
source "$REPO_ROOT/roles/zsh/files/zsh/vars.secret_functions.zsh"
source "$HOME/.config/zsh/secret_batch_test_helper.zsh"
secret --quiet || exit 1
[[ "$TEST_MIXED_ALPHA" == 'fixture-mixed-alpha' ]] || exit 1
[[ "$TEST_MIXED_BRAVO" == 'fixture-mixed-bravo' ]] || exit 1
[[ -n "${SECRETS_LOADED_SIGNATURE-}" ]] || exit 1
ZSH
then
  echo "mixed-account batches did not complete" >&2
  exit 1
fi
if [[ -s "$mixed_stdout" || -s "$mixed_stderr" ]]; then
  echo "mixed-account batches were not quiet" >&2
  exit 1
fi
if ! expect_operations run run || ! expect_accounts fixture-account fixture-second-account; then
  exit 1
fi

write_mixed_account_profile "op://fixture/mixed-failure"
: > "$op_operations"
: > "$op_accounts"
mixed_failure_stdout="$tmp_dir/mixed-failure.stdout"
mixed_failure_stderr="$tmp_dir/mixed-failure.stderr"
if ! env -i \
  HOME="$home_dir" \
  PATH="$bin_dir:/usr/bin:/bin" \
  OP_OPERATIONS="$op_operations" \
  OP_ACCOUNTS="$op_accounts" \
  OP_REJECT_CONCURRENT_RUNS=1 \
  OP_CONCURRENT_RUN_LOCK="$tmp_dir/mixed-failure-run-lock" \
  TEST_ACCOUNT="fixture-account" \
  TEST_SECOND_ACCOUNT="fixture-second-account" \
  REPO_ROOT="$repo_root" \
  "$zsh_bin" -f >"$mixed_failure_stdout" 2>"$mixed_failure_stderr" <<'ZSH'
source "$REPO_ROOT/roles/zsh/files/zsh/vars.secret_functions.zsh"
source "$HOME/.config/zsh/secret_batch_test_helper.zsh"
if secret --quiet; then
  exit 1
fi
for name in TEST_MIXED_ALPHA TEST_MIXED_BRAVO SECRETS_ALREADY_LOADED SECRETS_LOADED_AT SECRETS_LOADED_VARS SECRETS_LOADED_SIGNATURE; do
  (( ! ${+parameters[$name]} )) || exit 1
done
ZSH
then
  echo "mixed-account failure left secret state" >&2
  exit 1
fi
if [[ -s "$mixed_failure_stdout" || -s "$mixed_failure_stderr" ]]; then
  echo "mixed-account failure was not quiet" >&2
  exit 1
fi
if ! expect_operations run run || ! expect_accounts fixture-account fixture-second-account; then
  exit 1
fi
echo "ok mixed-account batches serialize and commit transactionally"

# --- invalid references are rejected before they can become shell values ---
write_non_op_reference_profile
: > "$op_operations"
non_op_stdout="$tmp_dir/non-op.stdout"
non_op_stderr="$tmp_dir/non-op.stderr"
if ! env -i \
  HOME="$home_dir" \
  PATH="$bin_dir:/usr/bin:/bin" \
  OP_OPERATIONS="$op_operations" \
  TEST_ACCOUNT="fixture-account" \
  REPO_ROOT="$repo_root" \
  "$zsh_bin" -f >"$non_op_stdout" 2>"$non_op_stderr" <<'ZSH'
source "$REPO_ROOT/roles/zsh/files/zsh/vars.secret_functions.zsh"
source "$HOME/.config/zsh/secret_batch_test_helper.zsh"
if secret --quiet; then
  exit 1
fi
for name in TEST_NON_OP_VALUE SECRETS_ALREADY_LOADED SECRETS_LOADED_AT SECRETS_LOADED_VARS SECRETS_LOADED_SIGNATURE; do
  (( ! ${+parameters[$name]} )) || exit 1
done
ZSH
then
  echo "non-op reference left secret state" >&2
  exit 1
fi
if [[ -s "$non_op_stdout" || -s "$non_op_stderr" ]]; then
  echo "non-op reference failure was not quiet" >&2
  exit 1
fi
echo "ok non-op references are rejected"

# --- readonly targets abort an otherwise valid batch without partial exports ---
write_readonly_profile
: > "$op_operations"
readonly_stdout="$tmp_dir/readonly.stdout"
readonly_stderr="$tmp_dir/readonly.stderr"
if ! env -i \
  HOME="$home_dir" \
  PATH="$bin_dir:/usr/bin:/bin" \
  OP_OPERATIONS="$op_operations" \
  TEST_ACCOUNT="fixture-account" \
  REPO_ROOT="$repo_root" \
  "$zsh_bin" -f >"$readonly_stdout" 2>"$readonly_stderr" <<'ZSH'
source "$REPO_ROOT/roles/zsh/files/zsh/vars.secret_functions.zsh"
source "$HOME/.config/zsh/secret_batch_test_helper.zsh"
typeset -r TEST_READONLY_TARGET=preexisting
if secret --quiet; then
  exit 1
fi
[[ "$TEST_READONLY_TARGET" == preexisting ]] || exit 1
for name in TEST_READONLY_OTHER SECRETS_ALREADY_LOADED SECRETS_LOADED_AT SECRETS_LOADED_VARS SECRETS_LOADED_SIGNATURE; do
  (( ! ${+parameters[$name]} )) || exit 1
done
ZSH
then
  echo "readonly target left secret state" >&2
  exit 1
fi
if [[ -s "$readonly_stdout" || -s "$readonly_stderr" ]]; then
  echo "readonly target failure was not quiet" >&2
  exit 1
fi
if [[ -s "$op_operations" ]]; then
  echo "readonly target triggered a secret operation" >&2
  exit 1
fi
echo "ok readonly targets prevent partial exports"

# --- the original nonbatch workers still roll back a failed batch ---
write_failed_read_profile
: > "$op_operations"
nonbatch_failure_stdout="$tmp_dir/nonbatch-failure.stdout"
nonbatch_failure_stderr="$tmp_dir/nonbatch-failure.stderr"
if ! env -i \
  HOME="$home_dir" \
  PATH="$bin_dir:/usr/bin:/bin" \
  OP_OPERATIONS="$op_operations" \
  TEST_ACCOUNT="fixture-account" \
  REPO_ROOT="$repo_root" \
  "$zsh_bin" -f >"$nonbatch_failure_stdout" 2>"$nonbatch_failure_stderr" <<'ZSH'
source "$REPO_ROOT/roles/zsh/files/zsh/vars.secret_functions.zsh"
__secret_use_single_process_batch() { return 1; }
if secret --quiet; then
  exit 1
fi
for name in TEST_FAILURE_ALPHA TEST_FAILURE_BRAVO SECRETS_ALREADY_LOADED SECRETS_LOADED_AT SECRETS_LOADED_VARS SECRETS_LOADED_SIGNATURE; do
  (( ! ${+parameters[$name]} )) || exit 1
done
ZSH
then
  echo "nonbatch failure left secret state" >&2
  exit 1
fi
if [[ -s "$nonbatch_failure_stdout" || -s "$nonbatch_failure_stderr" ]]; then
  echo "nonbatch failure was not quiet" >&2
  exit 1
fi
if ! expect_operations read read; then
  exit 1
fi
echo "ok nonbatch workers retain transactional rollback"

# --- unrelated unresolved references are excluded from the op-run environment ---
write_unrelated_reference_profile
: > "$op_operations"
unrelated_stdout="$tmp_dir/unrelated.stdout"
unrelated_stderr="$tmp_dir/unrelated.stderr"
if ! env -i \
  HOME="$home_dir" \
  PATH="$bin_dir:/usr/bin:/bin" \
  OP_OPERATIONS="$op_operations" \
  TEST_UNRELATED_REFERENCE="op://inaccessible/unrelated" \
  OP_SESSION_fixture="op://inaccessible/allowed-name" \
  TEST_ACCOUNT="fixture-account" \
  REPO_ROOT="$repo_root" \
  "$zsh_bin" -f >"$unrelated_stdout" 2>"$unrelated_stderr" <<'ZSH'
source "$REPO_ROOT/roles/zsh/files/zsh/vars.secret_functions.zsh"
source "$HOME/.config/zsh/secret_batch_test_helper.zsh"
secret --quiet || exit 1
[[ "$TEST_UNRELATED_BATCH_VALUE" == 'fixture-unrelated-alpha' ]] || exit 1
[[ "$TEST_UNRELATED_REFERENCE" == 'op://inaccessible/unrelated' ]] || exit 1
[[ "$OP_SESSION_fixture" == 'op://inaccessible/allowed-name' ]] || exit 1
ZSH
then
  echo "unrelated reference blocked a queued batch" >&2
  exit 1
fi
if [[ -s "$unrelated_stdout" || -s "$unrelated_stderr" ]]; then
  echo "unrelated reference batch was not quiet" >&2
  exit 1
fi
if ! expect_operations run; then
  exit 1
fi
echo "ok unrelated references are isolated from op run"

# --- a conditional failure stops before a dependent read ---
write_conditional_profile
: > "$op_operations"
conditional_stdout="$tmp_dir/conditional.stdout"
conditional_stderr="$tmp_dir/conditional.stderr"
if ! env -i \
  HOME="$home_dir" \
  PATH="$bin_dir:/usr/bin:/bin" \
  OP_OPERATIONS="$op_operations" \
  OP_PROFILE_READ_MODE=conditional-failure \
  TAILSCALE_IP_RESULT=failure \
  TEST_ACCOUNT="fixture-account" \
  REPO_ROOT="$repo_root" \
  "$zsh_bin" -f >"$conditional_stdout" 2>"$conditional_stderr" <<'ZSH'
source "$REPO_ROOT/roles/zsh/files/zsh/vars.secret_functions.zsh"
source "$HOME/.config/zsh/secret_batch_test_helper.zsh"
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
if ! expect_operations run; then
  exit 1
fi
echo "ok conditional failure stops dependent read"

# --- an explicit await completes one dependency wave before the next ---
write_conditional_profile
: > "$op_operations"
conditional_success_stdout="$tmp_dir/conditional-success.stdout"
conditional_success_stderr="$tmp_dir/conditional-success.stderr"
if ! env -i \
  HOME="$home_dir" \
  PATH="$bin_dir:/usr/bin:/bin" \
  OP_OPERATIONS="$op_operations" \
  TAILSCALE_IP_RESULT=failure \
  TEST_ACCOUNT="fixture-account" \
  REPO_ROOT="$repo_root" \
  "$zsh_bin" -f >"$conditional_success_stdout" 2>"$conditional_success_stderr" <<'ZSH'
source "$REPO_ROOT/roles/zsh/files/zsh/vars.secret_functions.zsh"
source "$HOME/.config/zsh/secret_batch_test_helper.zsh"
secret --quiet || exit 1
[[ "$TEST_CONDITIONAL_ALPHA" == 'fixture-conditional-alpha' ]] || exit 1
[[ "$TEST_CONDITIONAL_ENDPOINT" == 'fixture-conditional-local' ]] || exit 1
[[ "$TEST_CONDITIONAL_DERIVED" == 'fixture-conditional-local' ]] || exit 1
[[ "$TEST_CONDITIONAL_DEPENDENT" == 'fixture-conditional-dependent' ]] || exit 1
ZSH
then
  echo "conditional dependency waves did not complete" >&2
  exit 1
fi
if [[ -s "$conditional_success_stdout" || -s "$conditional_success_stderr" ]]; then
  echo "conditional dependency waves were not quiet" >&2
  exit 1
fi
if ! expect_operations run run; then
  exit 1
fi
echo "ok dependency waves preserve explicit await ordering"

# --- a failed explicit reload clears prior and current inventories ---
cat > "$secret_file" <<'SECRETS'
__secret_export_op_read TEST_PRIOR_ALPHA --account "$TEST_ACCOUNT" "op://fixture/prior-alpha" || return 1
__secret_export_op_read TEST_PRIOR_BRAVO --account "$TEST_ACCOUNT" "op://fixture/prior-bravo" || return 1
SECRETS
: > "$op_operations"
reload_failure_stdout="$tmp_dir/reload-failure.stdout"
reload_failure_stderr="$tmp_dir/reload-failure.stderr"
if ! env -i \
  HOME="$home_dir" \
  PATH="$bin_dir:/usr/bin:/bin" \
  OP_OPERATIONS="$op_operations" \
  TEST_ACCOUNT="fixture-account" \
  REPO_ROOT="$repo_root" \
  "$zsh_bin" -f >"$reload_failure_stdout" 2>"$reload_failure_stderr" <<'ZSH'
source "$REPO_ROOT/roles/zsh/files/zsh/vars.secret_functions.zsh"
source "$HOME/.config/zsh/secret_batch_test_helper.zsh"
secret --quiet || exit 1
[[ "$TEST_PRIOR_ALPHA" == 'fixture-prior-alpha' ]] || exit 1
[[ "$TEST_PRIOR_BRAVO" == 'fixture-prior-bravo' ]] || exit 1
cat > "$HOME/.config/zsh/vars.secret" <<'SECRETS'
__secret_export_op_read TEST_CURRENT_GAMMA --account "$TEST_ACCOUNT" "op://fixture/current-gamma" || return 1
__secret_export_op_read TEST_CURRENT_DELTA --account "$TEST_ACCOUNT" "op://fixture/current-delta" || return 1
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
if ! expect_operations run run; then
  exit 1
fi
echo "ok failed reload clears inventories"

# --- incomplete inherited metadata cannot suppress a required reload ---
cat > "$secret_file" <<'SECRETS'
__secret_export_op_read TEST_INHERITED_ALPHA --account "$TEST_ACCOUNT" "op://fixture/inherited-alpha" || return 1
SECRETS
: > "$op_operations"
inherited_stdout="$tmp_dir/inherited.stdout"
inherited_stderr="$tmp_dir/inherited.stderr"
if ! env -i \
  HOME="$home_dir" \
  PATH="$bin_dir:/usr/bin:/bin" \
  OP_OPERATIONS="$op_operations" \
  TEST_ACCOUNT="fixture-account" \
  SECRETS_ALREADY_LOADED=true \
  REPO_ROOT="$repo_root" \
  "$zsh_bin" -f >"$inherited_stdout" 2>"$inherited_stderr" <<'ZSH'
source "$REPO_ROOT/roles/zsh/files/zsh/vars.secret_functions.zsh"
source "$HOME/.config/zsh/secret_batch_test_helper.zsh"
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
if ! expect_operations run; then
  exit 1
fi
echo "ok incomplete inherited metadata reloads"

# --- Linux resolves one independent wave through exactly one op run ---
cat > "$secret_file" <<'SECRETS'
__secret_export_op_read TEST_PARALLEL_ALPHA --account "$TEST_ACCOUNT" "op://fixture/parallel-alpha" || return 1
__secret_export_op_read TEST_PARALLEL_BRAVO --account "$TEST_ACCOUNT" "op://fixture/parallel-bravo" || return 1
SECRETS
: > "$op_operations"
batch_stdout="$tmp_dir/batch.stdout"
batch_stderr="$tmp_dir/batch.stderr"
if ! env -i \
  HOME="$home_dir" \
  PATH="$bin_dir:/usr/bin:/bin" \
  OP_OPERATIONS="$op_operations" \
  OP_REJECT_CONCURRENT_READS=1 \
  OP_CONCURRENT_READ_LOCK="$tmp_dir/reject-read-lock" \
  TEST_ACCOUNT="fixture-account" \
  REPO_ROOT="$repo_root" \
  "$zsh_bin" -f >"$batch_stdout" 2>"$batch_stderr" <<'ZSH'
source "$REPO_ROOT/roles/zsh/files/zsh/vars.secret_functions.zsh"
source "$HOME/.config/zsh/secret_batch_test_helper.zsh"
secret --quiet || exit 1
[[ "$TEST_PARALLEL_ALPHA" == 'fixture-parallel-alpha' ]] || exit 1
[[ "$TEST_PARALLEL_BRAVO" == 'fixture-parallel-bravo' ]] || exit 1
ZSH
then
  echo "Linux batch secret load did not complete" >&2
  exit 1
fi
if [[ -s "$batch_stdout" || -s "$batch_stderr" ]]; then
  echo "Linux batch secret load was not quiet" >&2
  exit 1
fi
if ! expect_operations run; then
  exit 1
fi
echo "ok Linux batches a dependency wave in one op run"

# --- disabling Linux batching preserves overlapping Darwin-style op reads ---
: > "$op_operations"
overlap_stdout="$tmp_dir/overlap.stdout"
overlap_stderr="$tmp_dir/overlap.stderr"
if ! env -i \
  HOME="$home_dir" \
  PATH="$bin_dir:/usr/bin:/bin" \
  OP_OPERATIONS="$op_operations" \
  OP_REQUIRE_READ_OVERLAP=1 \
  OP_READ_BARRIER="$tmp_dir/read-barrier" \
  TEST_ACCOUNT="fixture-account" \
  REPO_ROOT="$repo_root" \
  "$zsh_bin" -f >"$overlap_stdout" 2>"$overlap_stderr" <<'ZSH'
source "$REPO_ROOT/roles/zsh/files/zsh/vars.secret_functions.zsh"
__secret_use_single_process_batch() { return 1; }
secret --quiet || exit 1
[[ "$TEST_PARALLEL_ALPHA" == 'fixture-parallel-alpha' ]] || exit 1
[[ "$TEST_PARALLEL_BRAVO" == 'fixture-parallel-bravo' ]] || exit 1
ZSH
then
  echo "Darwin-style overlapping secret reads did not complete" >&2
  exit 1
fi
if [[ -s "$overlap_stdout" || -s "$overlap_stderr" ]]; then
  echo "Darwin-style overlapping secret reads were not quiet" >&2
  exit 1
fi
if ! expect_operations read read; then
  exit 1
fi
echo "ok Darwin-style reads overlap when batching is disabled"

echo "ok secret loading"
