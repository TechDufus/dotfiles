#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
zsh_bin="${ZSH_BIN:-zsh}"
loader="$repo_root/roles/zsh/files/zsh/vars.secret_functions.zsh"

if ! command -v "$zsh_bin" >/dev/null; then
  echo "SKIP: zsh not installed"
  exit 0
fi
zsh_bin="$(command -v "$zsh_bin")"

if [[ ! -f "$loader" ]]; then
  echo "missing secret loader: $loader" >&2
  exit 1
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
bin_dir="$tmp_dir/bin"
mkdir -p "$bin_dir"

cat > "$bin_dir/op" <<'OP'
#!/usr/bin/env sh
set -eu

operation_log="${OP_CONFIG_DIR:?}/operations"
rotation_file="${OP_CONFIG_DIR:?}/rotation"

record_operation() {
  lock_dir="$operation_log.lock"
  attempts=0
  until mkdir "$lock_dir" 2>/dev/null; do
    attempts=$((attempts + 1))
    [ "$attempts" -lt 400 ] || exit 72
    sleep 0.01
  done
  printf '%s\n' "$1" >> "$operation_log"
  rmdir "$lock_dir"
}

resolve_reference() {
  case "$1" in
    op://fixture/rotation)
      count=0
      [ ! -f "$rotation_file" ] || count="$(cat "$rotation_file")"
      count=$((count + 1))
      printf '%s\n' "$count" > "$rotation_file"
      printf 'fixture-rotation-%s' "$count"
      ;;
    op://fixture/literal-meta) printf '%s' "quote'double\"\$*?;[]\\" ;;
    op://fixture/literal-multiline) printf 'first line\nsecond line' ;;
    op://fixture/literal-empty) ;;
    op://fixture/literal-trailing)
      printf 'ends-with-newline\n'
      ;;
    op://fixture/status-value) printf '%s' 'fixture-status-value' ;;
    op://fixture/wave-alpha) printf '%s' 'fixture-wave-alpha' ;;
    op://fixture/wave-network) printf '%s' 'fixture-wave-network' ;;
    op://fixture/wave-local) printf '%s' 'fixture-wave-local' ;;
    op://fixture/wave-dependent) printf '%s' 'fixture-wave-dependent' ;;
    op://fixture/failure-alpha) printf '%s' 'fixture-failure-alpha' ;;
    op://fixture/failure-bravo) return 17 ;;
    op://fixture/previous-cache) printf '%s' 'fixture-previous-cache' ;;
    op://fixture/readonly-target) printf '%s' 'fixture-readonly-target' ;;
    op://fixture/readonly-other) printf '%s' 'fixture-readonly-other' ;;
    *) return 70 ;;
  esac
}

export_fixture() {
  name="$1"
  reference="$2"

  case "$reference" in
    op://fixture/literal-meta)
      export "$name=quote'double\"\$*?;[]\\"
      ;;
    op://fixture/literal-multiline)
      export "$name=first line
second line"
      ;;
    op://fixture/literal-empty)
      export "$name="
      ;;
    op://fixture/literal-trailing)
      export "$name=ends-with-newline
"
      ;;
    *)
      value="$(resolve_reference "$reference")" || return "$?"
      export "$name=$value"
      ;;
  esac
}

case "${1-}" in
  vault)
    record_operation vault
    exit 0
    ;;
  read)
    reference=""
    for argument in "$@"; do
      reference="$argument"
    done
    record_operation "read:$reference"
    resolve_reference "$reference"
    ;;
  run)
    shift
    [ "${1-}" = --account ] && [ -n "${2-}" ] || exit 71
    account="$2"
    shift 2
    [ "${1-}" != --no-masking ] || shift
    [ "${1-}" = -- ] || exit 71
    shift
    record_operation "run:$account"

    while IFS= read -r entry; do
      name="${entry%%=*}"
      reference="${entry#*=}"
      case "$reference" in
        op://fixture/*)
          export_fixture "$name" "$reference" || exit "$?"
          ;;
      esac
    done <<EOF
$(env)
EOF

    exec "$@"
    ;;
  *)
    exit 71
    ;;
esac
OP
chmod +x "$bin_dir/op"

fail() {
  echo "test_secret_loading: $*" >&2
  exit 1
}

new_case() {
  local name="$1"

  case_dir="$tmp_dir/$name"
  home_dir="$case_dir/home"
  run_tmp_dir="$case_dir/tmp"
  state_dir="$case_dir/state"
  op_config_dir="$case_dir/op-config"
  op_log="$op_config_dir/operations"

  mkdir -p "$home_dir/.config/zsh" "$run_tmp_dir" "$state_dir" "$op_config_dir"
  cp "$loader" "$home_dir/.config/zsh/vars.secret_functions.zsh"
  : > "$op_log"
}

write_recipe() {
  cat > "$home_dir/.config/zsh/vars.secret"
}

run_zsh() {
  env -i \
    HOME="$home_dir" \
    TMPDIR="$run_tmp_dir" \
    XDG_STATE_HOME="$state_dir" \
    PATH="$bin_dir:/usr/bin:/bin" \
    OP_ACCOUNT=fixture-account \
    OP_CONFIG_DIR="$op_config_dir" \
    OSTYPE=linux-gnu \
    "$zsh_bin" -df
}

operation_count() {
  local prefix="$1" line count=0
  while IFS= read -r line; do
    if [[ "$line" == "$prefix"* ]]; then
      ((count += 1))
    fi
  done < "$op_log"
  printf '%s\n' "$count"
}

expect_operation_count() {
  local prefix="$1" expected="$2" actual
  actual="$(operation_count "$prefix")"
  [[ "$actual" == "$expected" ]] ||
    fail "expected $expected $prefix operation(s), found $actual"
}

expect_no_operations() {
  [[ ! -s "$op_log" ]] || fail "unexpected op invocation"
}

assert_quiet_output() {
  local stdout="$1" stderr="$2"
  [[ ! -s "$stdout" && ! -s "$stderr" ]] ||
    fail "--quiet produced user-interface output"
}

assert_private_cache() {
  local cache="$state_dir/zsh/secrets.zsh"
  local cache_dir="$state_dir/zsh"
  local cache_dir_mode

  [[ -f "$cache" && ! -L "$cache" ]] || fail "cache is not a regular file"
  [[ "$(stat -c '%a' "$cache")" == 600 ]] || fail "cache is not mode 0600"
  [[ -d "$cache_dir" && ! -L "$cache_dir" ]] || fail "cache directory is unsafe"
  cache_dir_mode="$(stat -c '%a' "$cache_dir")"
  [[ "$cache_dir_mode" =~ ^[0-7]00$ ]] || fail "cache directory is not private"
}

assert_cache_exports() {
  local cache="$state_dir/zsh/secrets.zsh"
  local line name metadata=1
  declare -A expected=()
  declare -A seen=()

  for name in "$@"; do
    expected["$name"]=1
  done

  # Name comments precede the first export.  Do not mistake lines in a
  # shell-quoted multiline value for another cache statement.
  while IFS= read -r line || [[ -n "$line" ]]; do
    (( metadata )) || continue
    case "$line" in
      '# zsh-secret-cache-format: 1')
        ;;
      '# zsh-secret-name: '*)
        name="${line#\# zsh-secret-name: }"
        [[ -n "${expected[$name]-}" ]] || fail "cache names undeclared $name"
        [[ -z "${seen[$name]-}" ]] || fail "cache names $name more than once"
        seen["$name"]=1
        ;;
      export\ *)
        metadata=0
        ;;
      *)
        fail "cache contains a non-export statement"
        ;;
    esac
  done < "$cache"

  for name in "$@"; do
    [[ -n "${seen[$name]-}" ]] || fail "cache omits $name"
  done
}

# Default and explicit reloads always refresh rather than trusting an existing
# cache. The fixtures deliberately include shell-sensitive and byte-boundary
# values so the cache must be safe to source directly in a fresh shell.
new_case refresh-and-cache
write_recipe <<'ZSH'
__secret_export_op_read TEST_ROTATION --account "$OP_ACCOUNT" "op://fixture/rotation" || return 1
__secret_export_op_read TEST_LITERAL_META --account "$OP_ACCOUNT" "op://fixture/literal-meta" || return 1
__secret_export_op_read TEST_LITERAL_MULTILINE --account "$OP_ACCOUNT" "op://fixture/literal-multiline" || return 1
__secret_export_op_read TEST_LITERAL_EMPTY --account "$OP_ACCOUNT" "op://fixture/literal-empty" || return 1
__secret_export_op_read TEST_LITERAL_TRAILING --account "$OP_ACCOUNT" "op://fixture/literal-trailing" || return 1
ZSH

refresh_stdout="$case_dir/refresh.stdout"
refresh_stderr="$case_dir/refresh.stderr"
if ! run_zsh >"$refresh_stdout" 2>"$refresh_stderr" <<'ZSH'
source "$HOME/.config/zsh/vars.secret_functions.zsh"
secret --quiet
[[ "$TEST_ROTATION" == fixture-rotation-1 ]] || exit 1
secret --quiet
[[ "$TEST_ROTATION" == fixture-rotation-2 ]] || exit 1
secret --quiet --reload
[[ "$TEST_ROTATION" == fixture-rotation-3 ]] || exit 1
ZSH
then
  fail "default refresh did not load the expected fixture values"
fi
assert_quiet_output "$refresh_stdout" "$refresh_stderr"
expect_operation_count 'run:' 3
assert_private_cache
assert_cache_exports \
  TEST_ROTATION \
  TEST_LITERAL_META \
  TEST_LITERAL_MULTILINE \
  TEST_LITERAL_EMPTY \
  TEST_LITERAL_TRAILING

# The refresh/import path must mute xtrace and verbose before a resolved value
# can appear in a traced assignment or exported cache statement.
trace_stdout="$case_dir/trace.stdout"
trace_stderr="$case_dir/trace.stderr"
if ! run_zsh >"$trace_stdout" 2>"$trace_stderr" <<'ZSH'
source "$HOME/.config/zsh/vars.secret_functions.zsh"
setopt xtrace verbose
secret --quiet
unsetopt xtrace verbose
[[ "$TEST_ROTATION" == fixture-rotation-4 ]] || exit 1
setopt xtrace verbose
__secret_source_literal_file "$XDG_STATE_HOME/zsh/secrets.zsh"
unsetopt xtrace verbose
[[ "$TEST_LITERAL_TRAILING" == $'ends-with-newline\n' ]] || exit 1
ZSH
then
  fail "traced refresh/import did not preserve fixture values"
fi
trace_output="$(cat "$trace_stdout" "$trace_stderr")"
[[ "$trace_output" != *fixture-rotation-* &&
   "$trace_output" != *'quote'\''double'* &&
   "$trace_output" != *ends-with-newline* ]] ||
  fail "xtrace or verbose exposed a resolved value"
expect_operation_count 'run:' 4

cache_stdout="$case_dir/cache.stdout"
cache_stderr="$case_dir/cache.stderr"
if ! run_zsh >"$cache_stdout" 2>"$cache_stderr" <<'ZSH'
source "$XDG_STATE_HOME/zsh/secrets.zsh"
[[ "$TEST_ROTATION" == fixture-rotation-4 ]] || exit 1
[[ "$TEST_LITERAL_META" == $'quote\'double"$*?;[]\\' ]] || exit 1
[[ "$TEST_LITERAL_MULTILINE" == $'first line\nsecond line' ]] || exit 1
(( ${+TEST_LITERAL_EMPTY} )) && [[ -z "$TEST_LITERAL_EMPTY" ]] || exit 1
[[ "$TEST_LITERAL_TRAILING" == $'ends-with-newline\n' ]] || exit 1
ZSH
then
  fail "cache did not round-trip sourceable literal exports"
fi
assert_quiet_output "$cache_stdout" "$cache_stderr"
expect_operation_count 'run:' 4

echo "ok refreshes ignore cache and cache literals round-trip"

# Cache metadata powers inspection and clearing.  These actions must never
# reach op and must not reveal fixture values.
new_case metadata-actions
write_recipe <<'ZSH'
__secret_export_op_read TEST_CACHE_STATUS --account "$OP_ACCOUNT" "op://fixture/status-value" || return 1
ZSH

if ! run_zsh >"$case_dir/load.stdout" 2>"$case_dir/load.stderr" <<'ZSH'
source "$HOME/.config/zsh/vars.secret_functions.zsh"
secret --quiet
ZSH
then
  fail "could not create cache for metadata actions"
fi
assert_quiet_output "$case_dir/load.stdout" "$case_dir/load.stderr"
: > "$op_log"

if ! run_zsh >"$case_dir/status.stdout" 2>"$case_dir/status.stderr" <<'ZSH'
source "$HOME/.config/zsh/vars.secret_functions.zsh"
secret --status
ZSH
then
  fail "status failed against a valid cache"
fi
expect_no_operations
status_output="$(<"$case_dir/status.stdout")"
[[ "$status_output" == *'Secrets cache: ready (1 variables)'* ]] ||
  fail "status omitted cache metadata"
[[ "$status_output" != *fixture-status-value* && "$status_output" != *op://* ]] ||
  fail "status exposed a cached value or reference"

if ! run_zsh >"$case_dir/list.stdout" 2>"$case_dir/list.stderr" <<'ZSH'
source "$HOME/.config/zsh/vars.secret_functions.zsh"
secret --list
ZSH
then
  fail "list failed against a valid cache"
fi
expect_no_operations
list_output="$(<"$case_dir/list.stdout")"
[[ "$list_output" == *TEST_CACHE_STATUS* ]] || fail "list omitted cached variable name"
[[ "$list_output" != *fixture-status-value* && "$list_output" != *op://* ]] ||
  fail "list exposed a cached value or reference"

clear_stdout="$case_dir/clear.stdout"
clear_stderr="$case_dir/clear.stderr"
if ! run_zsh >"$clear_stdout" 2>"$clear_stderr" <<'ZSH'
source "$HOME/.config/zsh/vars.secret_functions.zsh"
source "$XDG_STATE_HOME/zsh/secrets.zsh"
export TEST_UNMANAGED=survives
secret --clear --quiet
(( ! ${+TEST_CACHE_STATUS} )) || exit 1
[[ "$TEST_UNMANAGED" == survives ]] || exit 1
[[ ! -e "$XDG_STATE_HOME/zsh/secrets.zsh" ]] || exit 1
ZSH
then
  fail "clear did not remove only managed variables and its safe cache"
fi
assert_quiet_output "$clear_stdout" "$clear_stderr"
expect_no_operations

echo "ok metadata actions avoid op and clear only cached names"

# A Linux producer resolves independent reads in one batch, stops at an
# explicit await, and retains both parent state and the prior cache if that
# awaited batch fails.
new_case linux-waves
write_recipe <<'ZSH'
__secret_export_op_read TEST_WAVE_ALPHA --account "$OP_ACCOUNT" "op://fixture/wave-alpha" || return 1
if [[ "${TEST_ENDPOINT_MODE-}" == network ]]; then
  __secret_export_op_read TEST_WAVE_ENDPOINT --account "$OP_ACCOUNT" "op://fixture/wave-network" || return 1
else
  __secret_export_op_read TEST_WAVE_ENDPOINT --account "$OP_ACCOUNT" "op://fixture/wave-local" || return 1
fi
__secret_await_op_reads || return 1
export TEST_WAVE_DERIVED="derived:$TEST_WAVE_ENDPOINT"
__secret_export_op_read TEST_WAVE_DEPENDENT --account "$OP_ACCOUNT" "op://fixture/wave-dependent" || return 1
ZSH

if ! run_zsh >"$case_dir/waves.stdout" 2>"$case_dir/waves.stderr" <<'ZSH'
source "$HOME/.config/zsh/vars.secret_functions.zsh"
export TEST_ENDPOINT_MODE=network
secret --quiet
[[ "$TEST_WAVE_ALPHA" == fixture-wave-alpha ]] || exit 1
[[ "$TEST_WAVE_ENDPOINT" == fixture-wave-network ]] || exit 1
[[ "$TEST_WAVE_DERIVED" == derived:fixture-wave-network ]] || exit 1
[[ "$TEST_WAVE_DEPENDENT" == fixture-wave-dependent ]] || exit 1
before_cache="$(<"$XDG_STATE_HOME/zsh/secrets.zsh")"

cat > "$HOME/.config/zsh/vars.secret" <<'RECIPE'
__secret_export_op_read TEST_WAVE_ALPHA --account "$OP_ACCOUNT" "op://fixture/failure-alpha" || return 1
__secret_export_op_read TEST_WAVE_BROKEN --account "$OP_ACCOUNT" "op://fixture/failure-bravo" || return 1
__secret_await_op_reads || return 1
export TEST_AFTER_FAILED_AWAIT=must-not-exist
RECIPE

if secret --quiet; then
  exit 1
fi
[[ "$TEST_WAVE_ALPHA" == fixture-wave-alpha ]] || exit 1
[[ "$TEST_WAVE_ENDPOINT" == fixture-wave-network ]] || exit 1
[[ "$TEST_WAVE_DERIVED" == derived:fixture-wave-network ]] || exit 1
[[ "$TEST_WAVE_DEPENDENT" == fixture-wave-dependent ]] || exit 1
(( ! ${+TEST_AFTER_FAILED_AWAIT} )) || exit 1
[[ "$(<"$XDG_STATE_HOME/zsh/secrets.zsh")" == "$before_cache" ]] || exit 1
ZSH
then
  fail "Linux waves did not commit or roll back transactionally"
fi
expect_operation_count 'run:' 3
assert_private_cache

echo "ok Linux batches conditional await waves and rolls failures back"

# Import preflight happens before publishing: a readonly target in the current
# shell must leave both its prior variables and the existing cache untouched.
new_case readonly-publication
write_recipe <<'ZSH'
__secret_export_op_read TEST_CACHE_PREVIOUS --account "$OP_ACCOUNT" "op://fixture/previous-cache" || return 1
ZSH

if ! run_zsh >"$case_dir/readonly.stdout" 2>"$case_dir/readonly.stderr" <<'ZSH'
source "$HOME/.config/zsh/vars.secret_functions.zsh"
secret --quiet
[[ "$TEST_CACHE_PREVIOUS" == fixture-previous-cache ]] || exit 1
before_cache="$(<"$XDG_STATE_HOME/zsh/secrets.zsh")"
readonly TEST_READONLY_TARGET=parent-value

cat > "$HOME/.config/zsh/vars.secret" <<'RECIPE'
__secret_export_op_read TEST_READONLY_TARGET --account "$OP_ACCOUNT" "op://fixture/readonly-target" || return 1
__secret_export_op_read TEST_READONLY_OTHER --account "$OP_ACCOUNT" "op://fixture/readonly-other" || return 1
RECIPE

if secret --quiet; then
  exit 1
fi
[[ "$TEST_READONLY_TARGET" == parent-value ]] || exit 1
[[ "$TEST_CACHE_PREVIOUS" == fixture-previous-cache ]] || exit 1
[[ "$(<"$XDG_STATE_HOME/zsh/secrets.zsh")" == "$before_cache" ]] || exit 1
ZSH
then
  fail "readonly preflight allowed cache publication or changed parent values"
fi
expect_operation_count 'run:' 1

echo "ok readonly targets prevent cache publication"

# Cache destinations must be rejected before an unsafe path can receive
# exported values.  Both cases still run with fresh, isolated shell homes.
new_case git-worktree-refusal
worktree_dir="$case_dir/worktree"
mkdir -p "$worktree_dir/.git"
state_dir="$worktree_dir/state"
mkdir -p "$state_dir"
write_recipe <<'ZSH'
__secret_export_op_read TEST_UNSAFE_GIT --account "$OP_ACCOUNT" "op://fixture/status-value" || return 1
ZSH

if run_zsh >"$case_dir/git.stdout" 2>"$case_dir/git.stderr" <<'ZSH'
source "$HOME/.config/zsh/vars.secret_functions.zsh"
secret --quiet
ZSH
then
  fail "accepted a cache path inside a Git worktree"
fi
[[ ! -e "$state_dir/zsh/secrets.zsh" ]] || fail "wrote cache inside a Git worktree"

new_case symlink-state-refusal
real_state_dir="$case_dir/real-state"
rmdir "$state_dir"
mkdir -p "$real_state_dir"
ln -s "$real_state_dir" "$state_dir"
write_recipe <<'ZSH'
__secret_export_op_read TEST_UNSAFE_SYMLINK --account "$OP_ACCOUNT" "op://fixture/status-value" || return 1
ZSH

if run_zsh >"$case_dir/symlink.stdout" 2>"$case_dir/symlink.stderr" <<'ZSH'
source "$HOME/.config/zsh/vars.secret_functions.zsh"
secret --quiet
ZSH
then
  fail "accepted a symlinked XDG state path"
fi
[[ ! -e "$real_state_dir/zsh/secrets.zsh" ]] || fail "wrote cache through a symlinked state path"

echo "ok unsafe cache destinations are refused"

# A private cache below a non-sticky world-writable ancestor is unsafe even
# when its immediate state and zsh directories have restrictive modes.
new_case unsafe-ancestor-refusal
unsafe_ancestor="$case_dir/unsafe-ancestor"
mkdir -p "$unsafe_ancestor"
chmod 777 "$unsafe_ancestor"
state_dir="$unsafe_ancestor/state"
mkdir -p "$state_dir/zsh"
chmod 700 "$state_dir" "$state_dir/zsh"
cat > "$state_dir/zsh/secrets.zsh" <<'ZSH'
# zsh-secret-cache-format: 1
# zsh-secret-name: TEST_UNSAFE_ANCESTOR
export TEST_UNSAFE_ANCESTOR=fixture-existing-cache
ZSH
chmod 600 "$state_dir/zsh/secrets.zsh"
write_recipe <<'ZSH'
__secret_export_op_read TEST_UNSAFE_ANCESTOR --account "$OP_ACCOUNT" "op://fixture/status-value" || return 1
ZSH

if run_zsh >"$case_dir/unsafe-refresh.stdout" 2>"$case_dir/unsafe-refresh.stderr" <<'ZSH'
source "$HOME/.config/zsh/vars.secret_functions.zsh"
secret --quiet
ZSH
then
  fail "refreshed through a non-sticky world-writable cache ancestor"
fi
expect_no_operations
[[ "$(<"$state_dir/zsh/secrets.zsh")" == $'# zsh-secret-cache-format: 1\n# zsh-secret-name: TEST_UNSAFE_ANCESTOR\nexport TEST_UNSAFE_ANCESTOR=fixture-existing-cache' ]] ||
  fail "unsafe-ancestor refresh changed the existing cache"
[[ "$(stat -c '%a' "$state_dir")" == 700 && "$(stat -c '%a' "$state_dir/zsh")" == 700 ]] ||
  fail "unsafe-ancestor refresh changed private cache parents"

if ! run_zsh >"$case_dir/unsafe-status.stdout" 2>"$case_dir/unsafe-status.stderr" <<'ZSH'
source "$HOME/.config/zsh/vars.secret_functions.zsh"
if secret --status; then
  exit 1
fi
ZSH
then
  fail "status accepted an unsafe cache ancestor"
fi
expect_no_operations
[[ "$(<"$case_dir/unsafe-status.stdout")" == *'Secrets cache: unavailable'* ]] ||
  fail "status did not report the unsafe cache as unavailable"

if ! run_zsh >"$case_dir/unsafe-list.stdout" 2>"$case_dir/unsafe-list.stderr" <<'ZSH'
source "$HOME/.config/zsh/vars.secret_functions.zsh"
if secret --list; then
  exit 1
fi
ZSH
then
  fail "list accepted an unsafe cache ancestor"
fi
expect_no_operations
[[ ! -s "$case_dir/unsafe-list.stdout" ]] ||
  fail "list read names from an unsafe cache"

if ! run_zsh >"$case_dir/unsafe-clear.stdout" 2>"$case_dir/unsafe-clear.stderr" <<'ZSH'
source "$HOME/.config/zsh/vars.secret_functions.zsh"
source "$XDG_STATE_HOME/zsh/secrets.zsh"
before_cache="$(<"$XDG_STATE_HOME/zsh/secrets.zsh")"
if secret --clear --quiet; then
  exit 1
fi
[[ "$TEST_UNSAFE_ANCESTOR" == fixture-existing-cache ]] || exit 1
[[ "$(<"$XDG_STATE_HOME/zsh/secrets.zsh")" == "$before_cache" ]] || exit 1
ZSH
then
  fail "clear changed state below an unsafe cache ancestor"
fi
expect_no_operations
[[ "$(stat -c '%a' "$state_dir")" == 700 && "$(stat -c '%a' "$state_dir/zsh")" == 700 ]] ||
  fail "unsafe-ancestor clear changed private cache parents"

echo "ok non-sticky world-writable cache ancestors are refused"

# A sticky shared parent remains safe when the XDG state child is private.
new_case sticky-ancestor-allowed
sticky_ancestor="$case_dir/sticky-ancestor"
mkdir -p "$sticky_ancestor"
chmod 1777 "$sticky_ancestor"
state_dir="$sticky_ancestor/state"
mkdir -p "$state_dir"
chmod 700 "$state_dir"
write_recipe <<'ZSH'
export TEST_STICKY_ANCESTOR=fixture-sticky-ancestor
ZSH
if ! run_zsh <<'ZSH'
source "$HOME/.config/zsh/vars.secret_functions.zsh"
secret --quiet || exit 1
[[ "$TEST_STICKY_ANCESTOR" == fixture-sticky-ancestor ]] || exit 1
ZSH
then
  fail "rejected a private cache below a sticky shared ancestor"
fi
assert_private_cache
expect_no_operations

echo "ok sticky shared cache ancestors retain private-cache behavior"

# Recipe names must never shadow the refresher's own dynamic-scope locals.
new_case control-name-collisions
chmod 755 "$state_dir"
write_recipe <<'ZSH'
export output="$HOME/forbidden.zsh"
export inventory=fixture-inventory
export name=fixture-name
export value=fixture-value
export cache=fixture-cache
export success=fixture-success
export action=fixture-action
export quiet=fixture-quiet
export REPLY=fixture-reply
ZSH
if ! run_zsh <<'ZSH'
source "$HOME/.config/zsh/vars.secret_functions.zsh"
secret --quiet || exit 1
[[ "$output" == "$HOME/forbidden.zsh" && ! -e "$output" ]] || exit 1
for target in inventory name value cache success action quiet; do
  [[ "${(P)target}" == "fixture-$target" ]] || exit 1
done
[[ "$REPLY" == fixture-reply ]] || exit 1
print 'invalid recipe syntax &&' > "$HOME/.config/zsh/vars.secret"
secret --quiet --clear || exit 1
for target in output inventory name value cache success action quiet REPLY; do
  (( ! ${+parameters[$target]} )) || exit 1
done
ZSH
then
  fail "recipe names shadowed control state or cache-only clear read the recipe"
fi
[[ "$(stat -c '%a' "$state_dir")" == 755 ]] || fail "changed existing XDG state permissions"
echo "ok ordinary names do not shadow controls and clear is cache-only"

# Non-Linux reads preserve final newlines; caller TMPDIR is never used for
# our secret-bearing files when it happens to point into a public worktree.
new_case private-read-temporaries
mkdir -p "$case_dir/public/.git" "$case_dir/public/tmp"
run_tmp_dir="$case_dir/public/tmp"
write_recipe <<'ZSH'
__secret_export_op_read TEST_TRAILING --account "$OP_ACCOUNT" "op://fixture/literal-trailing" || return 1
ZSH
if ! run_zsh <<'ZSH'
source "$HOME/.config/zsh/vars.secret_functions.zsh"
OSTYPE=darwin
secret --quiet || exit 1
[[ "$TEST_TRAILING" == $'ends-with-newline\n' ]] || exit 1
typeset -a remaining_tmp_files=("$TMPDIR"/*(DN))
(( ${#remaining_tmp_files} == 0 )) || exit 1
ZSH
then
  fail "non-Linux read lost bytes or used an unsafe caller TMPDIR"
fi
echo "ok non-Linux values and private refresh temporaries"

# A cancelled refresh must leave the previous cache, remove staged values,
# and release its kernel lock so the next explicit refresh can succeed.
new_case interrupted-refresh
write_recipe <<'ZSH'
export TEST_INTERRUPT=fixture-old
ZSH
run_zsh <<'ZSH'
source "$HOME/.config/zsh/vars.secret_functions.zsh"
secret --quiet || exit 1
ZSH
write_recipe <<'ZSH'
export TEST_INTERRUPT=fixture-new
print ready > "$OP_CONFIG_DIR/ready"
sleep 15
ZSH
env -i HOME="$home_dir" TMPDIR="$run_tmp_dir" XDG_STATE_HOME="$state_dir" \
  PATH="$bin_dir:/usr/bin:/bin" OP_CONFIG_DIR="$op_config_dir" \
  python3 - "$zsh_bin" <<'PY'
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

cache = Path(os.environ["XDG_STATE_HOME"]) / "zsh/secrets.zsh"
ready = Path(os.environ["OP_CONFIG_DIR"]) / "ready"
before = cache.read_bytes()
command = [sys.argv[1], "-dfc", 'source "$HOME/.config/zsh/vars.secret_functions.zsh"; secret --quiet']
process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True)
try:
    deadline = time.monotonic() + 5
    while not ready.exists() and process.poll() is None and time.monotonic() < deadline:
        time.sleep(0.01)
    assert ready.exists(), "refresh did not enter the producer"
    os.killpg(process.pid, signal.SIGINT)
    process.communicate(timeout=5)
    assert process.returncode != 0, "cancelled refresh reported success"
finally:
    if process.poll() is None:
        os.killpg(process.pid, signal.SIGKILL)
        process.communicate()
assert cache.read_bytes() == before, "cancelled refresh replaced the cache"
assert {entry.name for entry in cache.parent.iterdir()} == {"secrets.zsh", ".secrets.lock"}, "staged secret files survived cancellation"
recipe = Path(os.environ["HOME"]) / ".config/zsh/vars.secret"
recipe.write_text("export TEST_INTERRUPT=fixture-retry\n")
retry = subprocess.run(command, capture_output=True, timeout=8)
assert retry.returncode == 0, "cancelled refresh stranded its lock"
PY
echo "ok cancellation preserves cache, cleans staged values, and releases lock"

echo "ok secret loading"
