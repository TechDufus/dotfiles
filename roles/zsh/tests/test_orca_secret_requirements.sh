#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
zsh_bin="${ZSH_BIN:-zsh}"

if ! command -v "$zsh_bin" >/dev/null; then
  echo "SKIP: zsh not installed"
  exit 0
fi
zsh_bin="$(command -v "$zsh_bin")"

# Every case starts with env -i and a temporary HOME. This deliberately isolates
# the suite from any Orca or secret markers inherited from a calling agent.
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
bin_dir="$tmp_dir/bin"
home_dir="$tmp_dir/home"
secret_file="$home_dir/.config/zsh/vars.secret"
op_reads="$tmp_dir/op.reads"
mkdir -p "$bin_dir" "$home_dir/.config/zsh"
cp "$repo_root/roles/zsh/files/zsh/vars.secret_functions.zsh" \
  "$home_dir/.config/zsh/vars.secret_functions.zsh"

cat > "$bin_dir/op" <<'OP'
#!/usr/bin/env sh
record_read() {
  _line="$1"
  _lock="${OP_READS:?}.lock"
  _n=0
  while ! mkdir "$_lock" 2>/dev/null; do
    _n=$((_n + 1))
    if [ "$_n" -gt 400 ]; then
      exit 72
    fi
    sleep 0.01
  done
  printf '%s\n' "$_line" >> "${OP_READS:?}"
  rmdir "$_lock"
}

case "${1-}" in
  vault)
    exit 0
    ;;
  read)
    reference=""
    for argument in "$@"; do
      reference="$argument"
    done
    if [ -n "${OP_READ_SLEEP-}" ]; then
      sleep "$OP_READ_SLEEP"
    fi
    record_read "$reference"
    case "${OP_PROFILE_READ_MODE-}:${reference}" in
      conditional-failure:op://orca-regression/cond-tailscale|conditional-failure:op://orca-regression/cond-local)
        exit 17
        ;;
      conditional-empty:op://orca-regression/cond-tailscale|conditional-empty:op://orca-regression/cond-local)
        exit 0
        ;;
      intermediate-late-failure:op://orca-regression/synthetic-item/field)
        exit 17
        ;;
    esac
    case "$reference" in
      op://orca-regression/strict-alpha) printf '%s\n' 'strict-alpha-value' ;;
      op://orca-regression/strict-bravo) printf '%s\n' 'strict-bravo-value' ;;
      op://orca-regression/read-fail-alpha) printf '%s\n' 'partial-read-value' ;;
      op://orca-regression/read-fail-bravo) exit 17 ;;
      op://orca-regression/empty-value) ;;
      op://orca-regression/prior-alpha) printf '%s\n' 'prior-alpha-value' ;;
      op://orca-regression/prior-bravo) printf '%s\n' 'prior-bravo-value' ;;
      op://orca-regression/current-gamma) printf '%s\n' 'partial-current-value' ;;
      op://orca-regression/current-delta) exit 23 ;;
      op://orca-regression/inherited-alpha) printf '%s\n' 'inherited-alpha-value' ;;
      op://orca-regression/signature-first) printf '%s\n' 'signature-first-value' ;;
      op://orca-regression/signature-second) printf '%s\n' 'signature-second-value' ;;
      op://orca-regression/parallel-alpha) printf '%s\n' 'parallel-alpha-value' ;;
      op://orca-regression/parallel-bravo) printf '%s\n' 'parallel-bravo-value' ;;
      op://orca-regression/cond-alpha) printf '%s\n' 'cond-alpha-value' ;;
      op://orca-regression/cond-tailscale) printf '%s\n' 'cond-tailscale-value' ;;
      op://orca-regression/cond-local) printf '%s\n' 'cond-local-value' ;;
      op://orca-regression/cond-dependent) printf '%s\n' 'cond-dependent-value' ;;
      op://orca-regression/item-name) printf '%s\n' 'synthetic-item' ;;
      op://orca-regression/item-alpha) printf '%s\n' 'item-alpha-value' ;;
      op://orca-regression/synthetic-item/field) printf '%s\n' 'item-field-value' ;;
      *) exit 70 ;;
    esac
    exit 0
    ;;
  *)
    exit 71
    ;;
esac
OP
chmod +x "$bin_dir/op"

expect_read_set() {
  local expected actual
  expected="$(printf '%s\n' "$@" | sort)"
  actual="$(sort "$op_reads")"
  if [[ "$actual" != "$expected" ]]; then
    echo "unexpected op reads" >&2
    echo "expected:" >&2
    printf '%s\n' "$expected" >&2
    echo "actual:" >&2
    printf '%s\n' "$actual" >&2
    return 1
  fi
}

cat > "$bin_dir/tailscale" <<'TAILSCALE'
#!/usr/bin/env sh
case "${TAILSCALE_IP_RESULT-}" in
  success)
    exit 0
    ;;
  *)
    exit 1
    ;;
esac
TAILSCALE
chmod +x "$bin_dir/tailscale"

write_strict_secrets() {
  cat > "$secret_file" <<'SECRETS'
__secret_export_op_read ORCA_TEST_STRICT_ALPHA --account "$MY_ACCOUNT" "op://orca-regression/strict-alpha" || return 1
__secret_export_op_read ORCA_TEST_STRICT_BRAVO --account "$MY_ACCOUNT" "op://orca-regression/strict-bravo" || return 1
SECRETS
}

write_read_failure_secrets() {
  cat > "$secret_file" <<'SECRETS'
__secret_export_op_read ORCA_TEST_READ_FAIL_ALPHA --account "$MY_ACCOUNT" "op://orca-regression/read-fail-alpha" || return 1
__secret_export_op_read ORCA_TEST_READ_FAIL_BRAVO --account "$MY_ACCOUNT" "op://orca-regression/read-fail-bravo" || return 1
SECRETS
}

write_empty_value_secrets() {
  cat > "$secret_file" <<'SECRETS'
__secret_export_op_read ORCA_TEST_EMPTY_VALUE --account "$MY_ACCOUNT" "op://orca-regression/empty-value" || return 1
SECRETS
}

write_conditional_secrets() {
  cat > "$secret_file" <<'SECRETS'
__secret_export_op_read ORCA_TEST_COND_ALPHA --account "$MY_ACCOUNT" "op://orca-regression/cond-alpha" || return 1
if command -v tailscale >/dev/null 2>&1 && tailscale ip -4 >/dev/null 2>&1; then
  __secret_export_op_read ORCA_TEST_COND_ENDPOINT --account "$MY_ACCOUNT" "op://orca-regression/cond-tailscale" || return 1
else
  __secret_export_op_read ORCA_TEST_COND_ENDPOINT --account "$MY_ACCOUNT" "op://orca-regression/cond-local" || return 1
fi
__secret_await_op_reads || return 1
export ORCA_TEST_COND_DERIVED="$ORCA_TEST_COND_ENDPOINT"
__secret_export_op_read ORCA_TEST_COND_DEPENDENT --account "$MY_ACCOUNT" "op://orca-regression/cond-dependent" || return 1
SECRETS
}

write_intermediate_secrets() {
  cat > "$secret_file" <<'SECRETS'
__secret_export_op_read ORCA_TEST_ITEM_ALPHA --account "$MY_ACCOUNT" "op://orca-regression/item-alpha" || return 1
local ORCA_TEST_ITEM_NAME
ORCA_TEST_ITEM_NAME="$(__secret_op_read --account "$MY_ACCOUNT" "op://orca-regression/item-name")" || return 1
__secret_await_op_reads || return 1
__secret_export_op_read ORCA_TEST_ITEM_FIELD --account "$MY_ACCOUNT" "op://orca-regression/${ORCA_TEST_ITEM_NAME}/field" || return 1
SECRETS
}

# --- a changed profile with the same inventory reloads its synthetic value ---
cat > "$secret_file" <<'SECRETS'
__secret_export_op_read ORCA_TEST_SIGNATURE_VALUE --account "$MY_ACCOUNT" "op://orca-regression/signature-first" || return 1
SECRETS
: > "$op_reads"
signature_stdout="$tmp_dir/signature.stdout"
signature_stderr="$tmp_dir/signature.stderr"
env -i \
  HOME="$home_dir" \
  PATH="$bin_dir:/usr/bin:/bin" \
  OP_READS="$op_reads" \
  MY_ACCOUNT="orca-regression-account" \
  ORCA_PANE_KEY="orca-regression-pane" \
  REPO_ROOT="$repo_root" \
  "$zsh_bin" -f >"$signature_stdout" 2>"$signature_stderr" <<'ZSH'
source "$REPO_ROOT/roles/zsh/files/zsh/vars.secret_functions.zsh"
secret --quiet || exit 1
[[ "$ORCA_TEST_SIGNATURE_VALUE" == 'signature-first-value' ]] || exit 1
[[ -n "${SECRETS_LOADED_SIGNATURE-}" ]] || exit 1
cat > "$HOME/.config/zsh/vars.secret" <<'SECRETS'
__secret_export_op_read ORCA_TEST_SIGNATURE_VALUE --account "$MY_ACCOUNT" "op://orca-regression/signature-second" || return 1
SECRETS
secret --quiet || exit 1
[[ "$ORCA_TEST_SIGNATURE_VALUE" == 'signature-second-value' ]] || exit 1
[[ -n "${SECRETS_LOADED_SIGNATURE-}" ]] || exit 1
ZSH
if [[ -s "$signature_stdout" || -s "$signature_stderr" ]]; then
  echo "changed profile reload was not quiet" >&2
  exit 1
fi
if ! expect_read_set \
  'op://orca-regression/signature-first' \
  'op://orca-regression/signature-second'; then
  echo "changed profile did not perform the expected synthetic reads" >&2
  exit 1
fi
echo "ok changed profile reloads same inventory"

# --- Orca startup loads synthetic secrets ---
write_strict_secrets
: > "$op_reads"
success_stdout="$tmp_dir/success.stdout"
success_stderr="$tmp_dir/success.stderr"
env -i \
  HOME="$home_dir" \
  PATH="$bin_dir:/usr/bin:/bin" \
  OP_READS="$op_reads" \
  MY_ACCOUNT="orca-regression-account" \
  ORCA_PANE_KEY="orca-regression-pane" \
  CURSOR_AGENT=1 \
  REPO_ROOT="$repo_root" \
  "$zsh_bin" -f >"$success_stdout" 2>"$success_stderr" <<'ZSH'
source "$REPO_ROOT/roles/zsh/files/.zshrc"
[[ "$ORCA_TEST_STRICT_ALPHA" == 'strict-alpha-value' ]] || exit 1
[[ "$ORCA_TEST_STRICT_BRAVO" == 'strict-bravo-value' ]] || exit 1
[[ "${SECRETS_ALREADY_LOADED-}" == true ]] || exit 1
[[ -n "${SECRETS_LOADED_VARS-}" ]] || exit 1
[[ -n "${SECRETS_LOADED_SIGNATURE-}" ]] || exit 1
ZSH
if [[ -s "$success_stdout" || -s "$success_stderr" ]]; then
  echo "Orca startup guard was not silent" >&2
  exit 1
fi
if ! expect_read_set \
  'op://orca-regression/strict-alpha' \
  'op://orca-regression/strict-bravo'; then
  echo "Orca startup guard did not perform the expected synthetic reads" >&2
  exit 1
fi
echo "ok Orca startup guard loads synthetic secrets"

# --- Orca startup fails closed before the command body when loading fails ---
write_read_failure_secrets
: > "$op_reads"
startup_failure_body="$tmp_dir/startup-failure.body"
startup_failure_stdout="$tmp_dir/startup-failure.stdout"
startup_failure_stderr="$tmp_dir/startup-failure.stderr"
: > "$startup_failure_body"
if env -i \
  HOME="$home_dir" \
  PATH="$bin_dir:/usr/bin:/bin" \
  OP_READS="$op_reads" \
  BODY_CALLS="$startup_failure_body" \
  MY_ACCOUNT="orca-regression-account" \
  ORCA_PANE_KEY="orca-regression-pane" \
  CURSOR_AGENT=1 \
  REPO_ROOT="$repo_root" \
  "$zsh_bin" -f >"$startup_failure_stdout" 2>"$startup_failure_stderr" <<'ZSH'
source "$REPO_ROOT/roles/zsh/files/.zshrc"
print -r -- command-body >> "$BODY_CALLS"
ZSH
then
  echo "Orca startup guard accepted a failed secret load" >&2
  exit 1
fi
if [[ -s "$startup_failure_stdout" || -s "$startup_failure_body" ]]; then
  echo "Orca startup guard wrote stdout or ran the command body" >&2
  exit 1
fi
if [[ "$(<"$startup_failure_stderr")" != 'Error: required Orca secrets are unavailable; closing pane' ]]; then
  echo "Orca startup guard error was not generic" >&2
  cat "$startup_failure_stderr" >&2
  exit 1
fi
if ! expect_read_set \
  'op://orca-regression/read-fail-alpha' \
  'op://orca-regression/read-fail-bravo'; then
  echo "Orca startup guard did not use the fake op fixture" >&2
  exit 1
fi
echo "ok Orca startup guard fails closed"

# --- an individual read failure rolls back partial state and blocks the body ---
write_read_failure_secrets
: > "$op_reads"
: > "$tmp_dir/read-failure.body"
read_failure_stdout="$tmp_dir/read-failure.stdout"
read_failure_stderr="$tmp_dir/read-failure.stderr"
if env -i \
  HOME="$home_dir" \
  PATH="$bin_dir:/usr/bin:/bin" \
  OP_READS="$op_reads" \
  BODY_CALLS="$tmp_dir/read-failure.body" \
  MY_ACCOUNT="orca-regression-account" \
  ORCA_PANE_KEY="orca-regression-pane" \
  REPO_ROOT="$repo_root" \
  "$zsh_bin" -f >"$read_failure_stdout" 2>"$read_failure_stderr" <<'ZSH'
source "$REPO_ROOT/roles/zsh/files/zsh/vars.secret_functions.zsh"
assert_no_loaded_state() {
  local name
  for name in SECRETS_ALREADY_LOADED SECRETS_LOADED_AT SECRETS_LOADED_VARS SECRETS_LOADED_SIGNATURE; do
    (( ! ${+parameters[$name]} )) || return 1
  done
}
if secret --quiet; then
  print -r -- command-body >> "$BODY_CALLS"
fi
if (( ${+parameters[ORCA_TEST_READ_FAIL_ALPHA]} || ${+parameters[ORCA_TEST_READ_FAIL_BRAVO]} )); then
  exit 1
fi
assert_no_loaded_state
exit 42
ZSH
then
  echo "quiet secret loading succeeded after an individual read failure" >&2
  exit 1
else
  status=$?
  if (( status != 42 )); then
    echo "individual read failure test assertions failed" >&2
    exit "$status"
  fi
fi
if [[ -s "$read_failure_stdout" ]]; then
  echo "individual read failure leaked stdout" >&2
  exit 1
fi
if [[ -s "$read_failure_stderr" ]]; then
  echo "individual read failure leaked stderr" >&2
  exit 1
fi
if [[ -s "$tmp_dir/read-failure.body" ]]; then
  echo "command body ran after a failed quiet secret load" >&2
  exit 1
fi
if ! expect_read_set \
  'op://orca-regression/read-fail-alpha' \
  'op://orca-regression/read-fail-bravo'; then
  echo "individual read failure did not use the fake op fixture" >&2
  exit 1
fi
echo "ok quiet secret read failure rolls back and blocks command body"

# --- an empty direct read fails without setting any loaded metadata ---
write_empty_value_secrets
: > "$op_reads"
empty_stdout="$tmp_dir/empty.stdout"
empty_stderr="$tmp_dir/empty.stderr"
if env -i \
  HOME="$home_dir" \
  PATH="$bin_dir:/usr/bin:/bin" \
  OP_READS="$op_reads" \
  MY_ACCOUNT="orca-regression-account" \
  ORCA_PANE_KEY="orca-regression-pane" \
  REPO_ROOT="$repo_root" \
  "$zsh_bin" -f >"$empty_stdout" 2>"$empty_stderr" <<'ZSH'
source "$REPO_ROOT/roles/zsh/files/zsh/vars.secret_functions.zsh"
if secret --quiet; then
  exit 1
fi
if (( ${+parameters[ORCA_TEST_EMPTY_VALUE]} )); then
  exit 1
fi
for name in SECRETS_ALREADY_LOADED SECRETS_LOADED_AT SECRETS_LOADED_VARS SECRETS_LOADED_SIGNATURE; do
  (( ! ${+parameters[$name]} )) || exit 1
done
exit 42
ZSH
then
  echo "quiet secret loading succeeded after an empty read" >&2
  exit 1
else
  status=$?
  if (( status != 42 )); then
    echo "empty secret read test assertions failed" >&2
    exit "$status"
  fi
fi
if [[ -s "$empty_stdout" ]]; then
  echo "empty secret read leaked stdout" >&2
  exit 1
fi
if [[ -s "$empty_stderr" ]]; then
  echo "empty secret read leaked stderr" >&2
  exit 1
fi
if [[ "$(<"$op_reads")" != 'op://orca-regression/empty-value' ]]; then
  echo "empty secret read did not use the fake op fixture" >&2
  exit 1
fi
echo "ok empty direct read does not set loaded metadata"

# --- both conditional profile reads fail closed for failed and empty responses ---
for tailscale_result in success failure; do
  for read_mode in conditional-failure conditional-empty; do
    write_conditional_secrets
    : > "$op_reads"
    profile_body="$tmp_dir/conditional-${tailscale_result}-${read_mode}.body"
    profile_stdout="$tmp_dir/conditional-${tailscale_result}-${read_mode}.stdout"
    profile_stderr="$tmp_dir/conditional-${tailscale_result}-${read_mode}.stderr"
    : > "$profile_body"
    if env -i \
      HOME="$home_dir" \
      PATH="$bin_dir:/usr/bin:/bin" \
      OP_READS="$op_reads" \
      OP_PROFILE_READ_MODE="$read_mode" \
      TAILSCALE_IP_RESULT="$tailscale_result" \
      BODY_CALLS="$profile_body" \
      ORCA_PANE_KEY="orca-regression-pane" \
      REPO_ROOT="$repo_root" \
      "$zsh_bin" -f >"$profile_stdout" 2>"$profile_stderr" <<'ZSH'
source "$REPO_ROOT/roles/zsh/files/zsh/vars.secret_functions.zsh"
if secret --quiet; then
  print -r -- command-body >> "$BODY_CALLS"
fi
for name in ORCA_TEST_COND_ENDPOINT ORCA_TEST_COND_DEPENDENT SECRETS_ALREADY_LOADED SECRETS_LOADED_AT SECRETS_LOADED_VARS SECRETS_LOADED_SIGNATURE; do
  (( ! ${+parameters[$name]} )) || exit 1
done
exit 42
ZSH
    then
      echo "conditional profile read unexpectedly succeeded" >&2
      exit 1
    else
      status=$?
      if (( status != 42 )); then
        echo "conditional profile read assertions failed" >&2
        exit "$status"
      fi
    fi
    if [[ -s "$profile_stdout" || -s "$profile_body" ]]; then
      echo "conditional profile read wrote stdout or ran the command body" >&2
      exit 1
    fi
    if [[ -s "$profile_stderr" ]]; then
      echo "conditional profile read leaked stderr" >&2
      exit 1
    fi
    if [[ "$tailscale_result" == success ]]; then
      endpoint_ref='op://orca-regression/cond-tailscale'
    else
      endpoint_ref='op://orca-regression/cond-local'
    fi
    if ! grep -Fxq "$endpoint_ref" "$op_reads"; then
      echo "conditional profile read did not request $endpoint_ref" >&2
      exit 1
    fi
    if grep -Fxq 'op://orca-regression/cond-dependent' "$op_reads"; then
      echo "conditional profile read continued into a later dependent read" >&2
      exit 1
    fi
  done
done
echo "ok conditional profile reads fail closed"

# --- an unexported profile intermediate cannot survive a later read failure ---
write_intermediate_secrets
: > "$op_reads"
intermediate_body="$tmp_dir/intermediate-late-failure.body"
intermediate_stdout="$tmp_dir/intermediate-late-failure.stdout"
intermediate_stderr="$tmp_dir/intermediate-late-failure.stderr"
: > "$intermediate_body"
if env -i \
  HOME="$home_dir" \
  PATH="$bin_dir:/usr/bin:/bin" \
  OP_READS="$op_reads" \
  OP_PROFILE_READ_MODE=intermediate-late-failure \
  BODY_CALLS="$intermediate_body" \
  ORCA_PANE_KEY="orca-regression-pane" \
  REPO_ROOT="$repo_root" \
  "$zsh_bin" -f >"$intermediate_stdout" 2>"$intermediate_stderr" <<'ZSH'
source "$REPO_ROOT/roles/zsh/files/zsh/vars.secret_functions.zsh"
if secret --quiet; then
  print -r -- command-body >> "$BODY_CALLS"
fi
for name in ORCA_TEST_ITEM_NAME ORCA_TEST_ITEM_FIELD SECRETS_ALREADY_LOADED SECRETS_LOADED_AT SECRETS_LOADED_VARS SECRETS_LOADED_SIGNATURE; do
  (( ! ${+parameters[$name]} )) || exit 1
done
exit 42
ZSH
then
  echo "intermediate rollback unexpectedly succeeded" >&2
  exit 1
else
  status=$?
  if (( status != 42 )); then
    echo "intermediate rollback assertions failed" >&2
    exit "$status"
  fi
fi
if [[ -s "$intermediate_stdout" || -s "$intermediate_body" ]]; then
  echo "intermediate rollback wrote stdout or ran the command body" >&2
  exit 1
fi
if [[ -s "$intermediate_stderr" ]]; then
  echo "intermediate rollback leaked stderr" >&2
  exit 1
fi
if ! grep -Fxq 'op://orca-regression/item-name' "$op_reads"; then
  echo "intermediate rollback did not read the interpolated item name" >&2
  exit 1
fi
if ! grep -Fxq 'op://orca-regression/synthetic-item/field' "$op_reads"; then
  echo "intermediate rollback did not reach the later synthetic failure" >&2
  exit 1
fi
echo "ok intermediate rollback clears function-local profile state"

# --- an explicit reload failure clears current and prior inventory ---
cat > "$secret_file" <<'SECRETS'
__secret_export_op_read ORCA_TEST_PRIOR_ALPHA --account "$MY_ACCOUNT" "op://orca-regression/prior-alpha" || return 1
__secret_export_op_read ORCA_TEST_PRIOR_BRAVO --account "$MY_ACCOUNT" "op://orca-regression/prior-bravo" || return 1
SECRETS
: > "$op_reads"
rollback_stdout="$tmp_dir/rollback.stdout"
rollback_stderr="$tmp_dir/rollback.stderr"
if env -i \
  HOME="$home_dir" \
  PATH="$bin_dir:/usr/bin:/bin" \
  OP_READS="$op_reads" \
  MY_ACCOUNT="orca-regression-account" \
  ORCA_PANE_KEY="orca-regression-pane" \
  REPO_ROOT="$repo_root" \
  "$zsh_bin" -f >"$rollback_stdout" 2>"$rollback_stderr" <<'ZSH'
source "$REPO_ROOT/roles/zsh/files/zsh/vars.secret_functions.zsh"
secret --quiet || exit 1
[[ "$ORCA_TEST_PRIOR_ALPHA" == 'prior-alpha-value' ]] || exit 1
[[ "$ORCA_TEST_PRIOR_BRAVO" == 'prior-bravo-value' ]] || exit 1
[[ "$SECRETS_LOADED_VARS" == *ORCA_TEST_PRIOR_ALPHA* ]] || exit 1
[[ "$SECRETS_LOADED_VARS" == *ORCA_TEST_PRIOR_BRAVO* ]] || exit 1
[[ -n "${SECRETS_LOADED_SIGNATURE-}" ]] || exit 1
cat > "$HOME/.config/zsh/vars.secret" <<'SECRETS'
__secret_export_op_read ORCA_TEST_CURRENT_GAMMA --account "$MY_ACCOUNT" "op://orca-regression/current-gamma" || return 1
__secret_export_op_read ORCA_TEST_CURRENT_DELTA --account "$MY_ACCOUNT" "op://orca-regression/current-delta" || return 1
SECRETS
if secret --quiet --reload; then
  exit 1
fi
for name in ORCA_TEST_PRIOR_ALPHA ORCA_TEST_PRIOR_BRAVO ORCA_TEST_CURRENT_GAMMA ORCA_TEST_CURRENT_DELTA; do
  (( ! ${+parameters[$name]} )) || exit 1
done
for name in SECRETS_ALREADY_LOADED SECRETS_LOADED_AT SECRETS_LOADED_VARS SECRETS_LOADED_SIGNATURE; do
  (( ! ${+parameters[$name]} )) || exit 1
done
exit 42
ZSH
then
  echo "explicit reload succeeded after a partial load" >&2
  exit 1
else
  status=$?
  if (( status != 42 )); then
    echo "explicit reload test assertions failed" >&2
    exit "$status"
  fi
fi
if [[ -s "$rollback_stdout" ]]; then
  echo "explicit reload leaked stdout" >&2
  exit 1
fi
if [[ -s "$rollback_stderr" ]]; then
  echo "explicit reload leaked stderr" >&2
  exit 1
fi
if ! expect_read_set \
  'op://orca-regression/prior-alpha' \
  'op://orca-regression/prior-bravo' \
  'op://orca-regression/current-gamma' \
  'op://orca-regression/current-delta'; then
  echo "rollback did not read the expected synthetic variables" >&2
  exit 1
fi
echo "ok explicit reload failure clears current and prior inventory"

# --- a bare inherited marker must reload without inventory state ---
cat > "$secret_file" <<'SECRETS'
__secret_export_op_read ORCA_TEST_INHERITED_ALPHA --account "$MY_ACCOUNT" "op://orca-regression/inherited-alpha" || return 1
SECRETS
: > "$op_reads"
inherited_stdout="$tmp_dir/inherited.stdout"
inherited_stderr="$tmp_dir/inherited.stderr"
env -i \
  HOME="$home_dir" \
  PATH="$bin_dir:/usr/bin:/bin" \
  OP_READS="$op_reads" \
  MY_ACCOUNT="orca-regression-account" \
  ORCA_PANE_KEY="orca-regression-pane" \
  SECRETS_ALREADY_LOADED=true \
  REPO_ROOT="$repo_root" \
  "$zsh_bin" -f >"$inherited_stdout" 2>"$inherited_stderr" <<'ZSH'
source "$REPO_ROOT/roles/zsh/files/zsh/vars.secret_functions.zsh"
secret --quiet || exit 1
[[ "$ORCA_TEST_INHERITED_ALPHA" == 'inherited-alpha-value' ]] || exit 1
ZSH
if [[ -s "$inherited_stdout" || -s "$inherited_stderr" ]]; then
  echo "reload after incomplete inherited state was not quiet" >&2
  exit 1
fi
if [[ "$(<"$op_reads")" != 'op://orca-regression/inherited-alpha' ]]; then
  echo "inherited marker did not force a synthetic reload" >&2
  exit 1
fi
echo "ok inherited marker without metadata reloads"

# --- independent reads overlap instead of running one at a time ---
cat > "$secret_file" <<'SECRETS'
__secret_export_op_read ORCA_TEST_PARALLEL_ALPHA --account "$MY_ACCOUNT" "op://orca-regression/parallel-alpha" || return 1
__secret_export_op_read ORCA_TEST_PARALLEL_BRAVO --account "$MY_ACCOUNT" "op://orca-regression/parallel-bravo" || return 1
SECRETS
: > "$op_reads"
parallel_stdout="$tmp_dir/parallel.stdout"
parallel_stderr="$tmp_dir/parallel.stderr"
parallel_start="$(python3 -c 'import time; print(time.time())')"
env -i \
  HOME="$home_dir" \
  PATH="$bin_dir:/usr/bin:/bin" \
  OP_READS="$op_reads" \
  OP_READ_SLEEP="0.4" \
  MY_ACCOUNT="orca-regression-account" \
  REPO_ROOT="$repo_root" \
  "$zsh_bin" -f >"$parallel_stdout" 2>"$parallel_stderr" <<'ZSH'
source "$REPO_ROOT/roles/zsh/files/zsh/vars.secret_functions.zsh"
secret --quiet || exit 1
[[ "$ORCA_TEST_PARALLEL_ALPHA" == 'parallel-alpha-value' ]] || exit 1
[[ "$ORCA_TEST_PARALLEL_BRAVO" == 'parallel-bravo-value' ]] || exit 1
ZSH
parallel_end="$(python3 -c 'import time; print(time.time())')"
if [[ -s "$parallel_stdout" || -s "$parallel_stderr" ]]; then
  echo "parallel secret load was not quiet" >&2
  exit 1
fi
if ! expect_read_set \
  'op://orca-regression/parallel-alpha' \
  'op://orca-regression/parallel-bravo'; then
  echo "parallel secret load did not perform the expected synthetic reads" >&2
  exit 1
fi
if ! python3 -c "import sys; sys.exit(0 if (float('$parallel_end') - float('$parallel_start')) < 0.7 else 1)"; then
  echo "independent secret reads did not overlap" >&2
  exit 1
fi
echo "ok independent secret reads overlap"

echo "ok Orca secret requirements"
