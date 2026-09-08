#!/usr/bin/env zsh

function __secret_usage() {
  cat <<'EOF'
Usage: secret [options]

Refresh the local secret cache from the trusted vars.secret recipe.

Options:
  -c, --clear    Delete the local cache and clear managed vars in this shell
  -r, --reload   Refresh the local cache (same as secret)
  -l, --list     List cached variable names without fetching
  -s, --status   Show local cache status without fetching
  -q, --quiet    Suppress refresh/status output
  -h, --help     Display this help message
EOF
}

function __secret_shell_var_name_valid() {
  [[ "$1" =~ '^[A-Za-z_][A-Za-z0-9_]*$' ]]
}

function __secret_var_name_valid() {
  __secret_shell_var_name_valid "$1" || return 1
  case "$1" in
    __secret_internal_*|__SECRET_INTERNAL_*|__SECRET_OP_*|SECRETS_*)
      return 1
      ;;
  esac
}

# Extract the variables the recipe explicitly declares, preserving first-seen
# order.  The recipe itself is trusted and executable; this inventory limits
# the cache to its declared exports rather than the producer environment.
function __get_secret_vars() {
  emulate -L zsh
  local __secret_internal_secret_file="$HOME/.config/zsh/vars.secret"

  [[ -f "$__secret_internal_secret_file" ]] || return 1
  LC_ALL=C awk '
    function remember(var) {
      if (!seen[var]++) {
        print var
      }
    }

    /^[[:space:]]*export[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=/ {
      var = $0
      sub(/^[[:space:]]*export[[:space:]]+/, "", var)
      sub(/[[:space:]]*=.*/, "", var)
      remember(var)
    }

    /^[[:space:]]*__secret_export_op_read[[:space:]]+[A-Za-z_][A-Za-z0-9_]*([[:space:]]|$)/ {
      var = $0
      sub(/^[[:space:]]*__secret_export_op_read[[:space:]]+/, "", var)
      sub(/[[:space:]].*/, "", var)
      remember(var)
    }
  ' "$__secret_internal_secret_file"
}

function __secret_inventory_names_valid() {
  emulate -L zsh
  local __secret_internal_inventory="$1"
  local __secret_internal_name

  [[ -n "$__secret_internal_inventory" ]] || return 1
  while IFS= read -r __secret_internal_name; do
    __secret_var_name_valid "$__secret_internal_name" || return 1
  done <<< "$__secret_internal_inventory"
}

function __secret_inventory_merge() {
  emulate -L zsh
  local __secret_internal_inventory __secret_internal_name
  local -A __secret_internal_seen

  for __secret_internal_inventory in "$@"; do
    [[ -n "$__secret_internal_inventory" ]] || continue
    while IFS= read -r __secret_internal_name; do
      __secret_var_name_valid "$__secret_internal_name" || return 1
      if [[ -z "${__secret_internal_seen[$__secret_internal_name]-}" ]]; then
        __secret_internal_seen[$__secret_internal_name]=1
        print -r -- "$__secret_internal_name"
      fi
    done <<< "$__secret_internal_inventory"
  done
}

# Print names from the first inventory which do not occur in the second.
function __secret_inventory_difference() {
  emulate -L zsh
  local __secret_internal_old_inventory="$1"
  local __secret_internal_new_inventory="$2"
  local __secret_internal_name
  local -A __secret_internal_retained

  [[ -n "$__secret_internal_new_inventory" ]] && while IFS= read -r __secret_internal_name; do
    __secret_var_name_valid "$__secret_internal_name" || return 1
    __secret_internal_retained[$__secret_internal_name]=1
  done <<< "$__secret_internal_new_inventory"

  [[ -n "$__secret_internal_old_inventory" ]] || return 0
  while IFS= read -r __secret_internal_name; do
    __secret_var_name_valid "$__secret_internal_name" || return 1
    [[ -n "${__secret_internal_retained[$__secret_internal_name]-}" ]] || print -r -- "$__secret_internal_name"
  done <<< "$__secret_internal_old_inventory"
}

function __secret_inventory_same() {
  emulate -L zsh
  local __secret_internal_expected="$1"
  local __secret_internal_actual="$2"
  local __secret_internal_name
  local -A __secret_internal_expected_names __secret_internal_actual_names

  while IFS= read -r __secret_internal_name; do
    __secret_var_name_valid "$__secret_internal_name" || return 1
    [[ -z "${__secret_internal_expected_names[$__secret_internal_name]-}" ]] || return 1
    __secret_internal_expected_names[$__secret_internal_name]=1
  done <<< "$__secret_internal_expected"
  while IFS= read -r __secret_internal_name; do
    __secret_var_name_valid "$__secret_internal_name" || return 1
    [[ -z "${__secret_internal_actual_names[$__secret_internal_name]-}" ]] || return 1
    __secret_internal_actual_names[$__secret_internal_name]=1
  done <<< "$__secret_internal_actual"
  (( ${#__secret_internal_expected_names} == ${#__secret_internal_actual_names} )) || return 1
  for __secret_internal_name in ${(k)__secret_internal_expected_names}; do
    [[ -n "${__secret_internal_actual_names[$__secret_internal_name]-}" ]] || return 1
  done
}

function __secret_names_can_be_set() {
  emulate -L zsh
  local __secret_internal_inventory="$1"
  local __secret_internal_name

  [[ -n "$__secret_internal_inventory" ]] || return 0
  while IFS= read -r __secret_internal_name; do
    __secret_var_name_valid "$__secret_internal_name" || return 1
    [[ "${parameters[$__secret_internal_name]-}" == *readonly* ]] && return 1
  done <<< "$__secret_internal_inventory"
  return 0
}

function __secret_names_can_be_unset() {
  emulate -L zsh
  local __secret_internal_inventory="$1"
  local __secret_internal_name

  [[ -n "$__secret_internal_inventory" ]] || return 0
  while IFS= read -r __secret_internal_name; do
    __secret_var_name_valid "$__secret_internal_name" || return 1
    (( ${+parameters[$__secret_internal_name]} )) || continue
    [[ "${parameters[$__secret_internal_name]}" == *readonly* ]] && return 1
  done <<< "$__secret_internal_inventory"
  return 0
}

function __secret_unset_vars() {
  emulate -L zsh
  unsetopt xtrace verbose
  local __secret_internal_inventory="$1"
  local __secret_internal_name

  __secret_names_can_be_unset "$__secret_internal_inventory" || return 1
  [[ -n "$__secret_internal_inventory" ]] || return 0
  while IFS= read -r __secret_internal_name; do
    (( ${+parameters[$__secret_internal_name]} )) || continue
    unset "$__secret_internal_name" || return 1
  done <<< "$__secret_internal_inventory"
}

# Do not trust queue bookkeeping inherited from another shell.
unset __SECRET_OP_OUT __SECRET_OP_RC __SECRET_OP_REF __SECRET_OP_ACCOUNT
unset __SECRET_OP_VARS __SECRET_OP_PIDS __SECRET_OP_TMPDIR __SECRET_OP_BATCH_OUT
unset __SECRET_INTERNAL_READ_VALUE
typeset -gA __SECRET_OP_OUT=()
typeset -gA __SECRET_OP_RC=()
typeset -gA __SECRET_OP_REF=()
typeset -gA __SECRET_OP_ACCOUNT=()
typeset -ga __SECRET_OP_VARS=()
typeset -ga __SECRET_OP_PIDS=()
typeset -g +x __SECRET_OP_TMPDIR=''
typeset -g +x __SECRET_OP_BATCH_OUT=''
typeset -g +x __SECRET_INTERNAL_READ_VALUE=''

function __secret_op_pending_dir() {
  emulate -L zsh
  unsetopt xtrace verbose
  if [[ -z "${__SECRET_OP_TMPDIR-}" ]]; then
    __SECRET_OP_TMPDIR="$(umask 077; mktemp -d "${__SECRET_INTERNAL_TMP_ROOT:-${TMPDIR:-/tmp}}/zsh-secret.XXXXXX")" || return 1
  fi
}

# The desktop CLI client cannot safely overlap Linux requests.
function __secret_use_single_process_batch() {
  [[ "${OSTYPE-}" == linux* ]]
}

# Keep op run isolated from unrelated exported secret references.
function __secret_op_run_environment_allowed() {
  case "$1" in
    HOME|PATH|TMPDIR|XDG_RUNTIME_DIR|XDG_CONFIG_HOME|XDG_CACHE_HOME|XDG_DATA_HOME|XDG_STATE_HOME|DBUS_SESSION_BUS_ADDRESS|DISPLAY|WAYLAND_DISPLAY|XAUTHORITY|TERM|LANG|LANGUAGE|LC_*|TZ|USER|LOGNAME|SHELL|XDG_SESSION_*|XDG_CURRENT_DESKTOP|DESKTOP_SESSION|OP_ACCOUNT|OP_BIOMETRIC_AUTH|OP_CACHE_DIR|OP_CONFIG_DIR|OP_CONNECT_HOST|OP_CONNECT_TOKEN|OP_DEBUG|OP_FORMAT|OP_INCLUDE_ARCHIVE|OP_ISO_TIMESTAMPS|OP_PASSWORD|OP_SERVICE_ACCOUNT_TOKEN|OP_SESSION|OP_SESSION_*|OP_USER_AGENT)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

function __secret_reset_pending_reads() {
  emulate -L zsh
  unsetopt xtrace verbose
  local __secret_internal_pid

  setopt nomonitor
  for __secret_internal_pid in "${__SECRET_OP_PIDS[@]}"; do
    kill "$__secret_internal_pid" 2>/dev/null || true
    wait "$__secret_internal_pid" 2>/dev/null || true
  done
  if [[ -n "${__SECRET_OP_TMPDIR-}" ]]; then
    case "$__SECRET_OP_TMPDIR" in
      "${__SECRET_INTERNAL_TMP_ROOT:-${TMPDIR:-/tmp}}"/zsh-secret.*)
        rm -rf -- "$__SECRET_OP_TMPDIR"
        ;;
    esac
  fi
  unset __SECRET_OP_TMPDIR
  __SECRET_OP_VARS=()
  __SECRET_OP_PIDS=()
  __SECRET_OP_OUT=()
  __SECRET_OP_RC=()
  __SECRET_OP_REF=()
  __SECRET_OP_ACCOUNT=()
  unset __SECRET_OP_BATCH_OUT
  unset __SECRET_INTERNAL_READ_VALUE
}

function __secret_unset_pending_read_vars() {
  emulate -L zsh
  unsetopt xtrace verbose
  local __secret_internal_target

  for __secret_internal_target in "${__SECRET_OP_VARS[@]}"; do
    __secret_var_name_valid "$__secret_internal_target" || continue
    [[ "${parameters[$__secret_internal_target]-}" == *readonly* ]] && continue
    unset "$__secret_internal_target" 2>/dev/null || true
  done
}

# Read one non-empty 1Password value without exposing it on an error path.
# Recipes use this only for intermediate trusted values; declared exports use
# the queued helper below so cache serialization can preserve their bytes.
function __secret_op_read() {
  emulate -L zsh
  unsetopt xtrace verbose
  local __secret_internal_value

  __secret_internal_value="$(op read "$@")" || return 1
  [[ -n "$__secret_internal_value" ]] || return 1
  print -r -- "$__secret_internal_value"
}

# Queue one 1Password read.  Await before expanding a queued variable.
function __secret_export_op_read() {
  emulate -L zsh
  unsetopt xtrace verbose
  local __secret_internal_var="$1"
  local __secret_internal_out_file __secret_internal_rc_file __secret_internal_account __secret_internal_reference

  if __secret_use_single_process_batch; then
    if (( $# != 4 )) ||
       ! __secret_var_name_valid "$__secret_internal_var" ||
       [[ "$2" != --account || -z "$3" || "$4" != op://* ]] ||
       [[ "${parameters[$__secret_internal_var]-}" == *readonly* ||
          -n "${__SECRET_OP_REF[$__secret_internal_var]-}" ||
          -n "${__SECRET_OP_ACCOUNT[$__secret_internal_var]-}" ]]; then
      __secret_unset_pending_read_vars
      __secret_reset_pending_reads
      return 1
    fi

    __secret_internal_account="$3"
    __secret_internal_reference="$4"
    __secret_op_pending_dir || {
      __secret_unset_pending_read_vars
      __secret_reset_pending_reads
      return 1
    }
    __SECRET_OP_ACCOUNT[$__secret_internal_var]="$__secret_internal_account"
    __SECRET_OP_REF[$__secret_internal_var]="$__secret_internal_reference"
    __SECRET_OP_VARS+=("$__secret_internal_var")
    return 0
  fi

  (( $# >= 2 )) || return 1
  __secret_var_name_valid "$__secret_internal_var" || return 1
  shift
  setopt nomonitor
  __secret_op_pending_dir || return 1
  __secret_internal_out_file="$__SECRET_OP_TMPDIR/$__secret_internal_var.out"
  __secret_internal_rc_file="$__SECRET_OP_TMPDIR/$__secret_internal_var.rc"

  (
    unsetopt xtrace verbose 2>/dev/null
    set +e
    op read "$@" > "$__secret_internal_out_file"
    print -r -- "$?" > "$__secret_internal_rc_file"
  ) &
  __SECRET_OP_PIDS+=("$!")
  __SECRET_OP_VARS+=("$__secret_internal_var")
  __SECRET_OP_OUT[$__secret_internal_var]="$__secret_internal_out_file"
  __SECRET_OP_RC[$__secret_internal_var]="$__secret_internal_rc_file"
}

# Resolve a Linux wave without overlapping desktop CLI clients. References are
# grouped by account; account batches run serially and commit transactionally.
function __secret_await_op_run_batch() {
  emulate -L zsh
  unsetopt xtrace verbose
  local __secret_internal_account __secret_internal_expected_var __secret_internal_received_var __secret_internal_value __secret_internal_extra
  local __secret_internal_failed=0
  local -a __secret_internal_accounts __secret_internal_account_vars
  local -A __secret_internal_seen_accounts __secret_internal_values

  (( ${#__SECRET_OP_VARS[@]} )) || return 0
  if [[ -z "${__SECRET_OP_TMPDIR-}" ]] ||
     (( ${#__SECRET_OP_REF[@]} != ${#__SECRET_OP_VARS[@]} )) ||
     (( ${#__SECRET_OP_ACCOUNT[@]} != ${#__SECRET_OP_VARS[@]} )) ||
     (( ${#__SECRET_OP_PIDS[@]} )); then
    __secret_unset_pending_read_vars
    __secret_reset_pending_reads
    return 1
  fi

  for __secret_internal_expected_var in "${__SECRET_OP_VARS[@]}"; do
    __secret_internal_account="${__SECRET_OP_ACCOUNT[$__secret_internal_expected_var]-}"
    if ! __secret_var_name_valid "$__secret_internal_expected_var" ||
       [[ "${parameters[$__secret_internal_expected_var]-}" == *readonly* ||
          -z "$__secret_internal_account" || "${__SECRET_OP_REF[$__secret_internal_expected_var]-}" != op://* ]]; then
      __secret_unset_pending_read_vars
      __secret_reset_pending_reads
      return 1
    fi
    if [[ -z "${__secret_internal_seen_accounts[$__secret_internal_account]-}" ]]; then
      __secret_internal_accounts+=("$__secret_internal_account")
      __secret_internal_seen_accounts[$__secret_internal_account]=1
    fi
  done

  for __secret_internal_account in "${__secret_internal_accounts[@]}"; do
    __secret_internal_account_vars=()
    for __secret_internal_expected_var in "${__SECRET_OP_VARS[@]}"; do
      [[ "${__SECRET_OP_ACCOUNT[$__secret_internal_expected_var]}" == "$__secret_internal_account" ]] && __secret_internal_account_vars+=("$__secret_internal_expected_var")
    done

    __SECRET_OP_BATCH_OUT="$(umask 077; mktemp "$__SECRET_OP_TMPDIR/batch.XXXXXX")" 2>/dev/null || {
      __secret_internal_failed=1
      break
    }
    (
      unsetopt xtrace verbose 2>/dev/null
      set -- ${(k)parameters[(R)*-export*]}
      while (( $# )); do
        if ! __secret_op_run_environment_allowed "$1" || [[ "${(P)1}" == op://* ]]; then
          typeset -g +x "$1" 2>/dev/null || exit 1
        fi
        shift
      done
      for __secret_internal_expected_var in "${__secret_internal_account_vars[@]}"; do
        typeset -gx "$__secret_internal_expected_var=${__SECRET_OP_REF[$__secret_internal_expected_var]}" || exit 1
      done
      exec op run --account "$__secret_internal_account" --no-masking -- zsh -fc '
        emulate -LR zsh
        unsetopt xtrace verbose
        while (( $# )); do
          printf "%s\0%s\0" "$1" "${(P)1}" || exit 1
          shift
        done
      ' zsh "${__secret_internal_account_vars[@]}"
    ) > "$__SECRET_OP_BATCH_OUT" 2>/dev/null || __secret_internal_failed=1

    if (( ! __secret_internal_failed )); then
      {
        for __secret_internal_expected_var in "${__secret_internal_account_vars[@]}"; do
          __secret_internal_received_var=''
          __secret_internal_value=''
          if ! IFS= read -r -d $'\0' __secret_internal_received_var ||
             ! IFS= read -r -d $'\0' __secret_internal_value ||
             [[ "$__secret_internal_received_var" != "$__secret_internal_expected_var" ]]; then
            __secret_internal_failed=1
            break
          fi
          __secret_internal_values[$__secret_internal_expected_var]="$__secret_internal_value"
        done
        if (( ! __secret_internal_failed )); then
          __secret_internal_extra=''
          if IFS= read -r -d $'\0' __secret_internal_extra || [[ -n "$__secret_internal_extra" ]]; then
            __secret_internal_failed=1
          fi
        fi
        (( ! __secret_internal_failed ))
      } < "$__SECRET_OP_BATCH_OUT" || __secret_internal_failed=1
    fi

    rm -f -- "$__SECRET_OP_BATCH_OUT"
    unset __SECRET_OP_BATCH_OUT
    (( __secret_internal_failed )) && break
  done

  if (( ! __secret_internal_failed )); then
    for __secret_internal_expected_var in "${__SECRET_OP_VARS[@]}"; do
      if ! typeset -gx "$__secret_internal_expected_var=${__secret_internal_values[$__secret_internal_expected_var]}"; then
        __secret_internal_failed=1
        break
      fi
    done
  fi
  (( __secret_internal_failed )) && __secret_unset_pending_read_vars
  __secret_reset_pending_reads
  (( ! __secret_internal_failed ))
}

# Read a regular file exactly into internal state.  `read -d NUL` preserves
# terminal newlines when EOF follows the value, unlike command substitution.
# A successful `op read` may legitimately produce an empty exported value.
function __secret_read_file_exact() {
  emulate -L zsh
  unsetopt xtrace verbose
  local __secret_internal_file="$1"

  __SECRET_INTERNAL_READ_VALUE=''
  [[ -f "$__secret_internal_file" && ! -L "$__secret_internal_file" ]] || return 1
  IFS= read -r -d $'\0' __SECRET_INTERNAL_READ_VALUE < "$__secret_internal_file" || true
}

# Wait for queued reads and export every value, or export none from this wave.
function __secret_await_op_reads() {
  emulate -L zsh
  unsetopt xtrace verbose
  if __secret_use_single_process_batch; then
    __secret_await_op_run_batch
    return $?
  fi

  local __secret_internal_var __secret_internal_pid __secret_internal_rc __secret_internal_value
  local __secret_internal_failed=0
  local -A __secret_internal_values

  for __secret_internal_pid in "${__SECRET_OP_PIDS[@]}"; do
    wait "$__secret_internal_pid" || true
  done

  for __secret_internal_var in "${__SECRET_OP_VARS[@]}"; do
    __secret_internal_rc="$(<"${__SECRET_OP_RC[$__secret_internal_var]}")" 2>/dev/null || __secret_internal_rc=''
    if [[ "$__secret_internal_rc" != 0 || "${parameters[$__secret_internal_var]-}" == *readonly* ]] ||
       ! __secret_read_file_exact "${__SECRET_OP_OUT[$__secret_internal_var]}"; then
      __secret_internal_failed=1
      break
    fi
    __secret_internal_value="$__SECRET_INTERNAL_READ_VALUE"
    __secret_internal_values[$__secret_internal_var]="$__secret_internal_value"
  done

  if (( ! __secret_internal_failed )); then
    for __secret_internal_var in "${__SECRET_OP_VARS[@]}"; do
      if ! typeset -gx "$__secret_internal_var=${__secret_internal_values[$__secret_internal_var]}"; then
        __secret_internal_failed=1
        break
      fi
    done
  fi
  (( __secret_internal_failed )) && __secret_unset_pending_read_vars
  __secret_reset_pending_reads
  (( ! __secret_internal_failed ))
}

function __secret_cache_path() {
  emulate -L zsh
  local __secret_internal_state_home="${XDG_STATE_HOME:-$HOME/.local/state}"

  [[ -n "$__secret_internal_state_home" ]] || return 1
  [[ "$__secret_internal_state_home" == /* ]] || __secret_internal_state_home="$PWD/$__secret_internal_state_home"
  print -r -- "${__secret_internal_state_home:a}/zsh/secrets.zsh"
}

# `[[ -O ]]` establishes ownership; the mode check keeps a cache or cache
# directory from being readable or writable by another account.  BSD and GNU
# stat spell the portable permission query differently.
function __secret_path_is_owner_private() {
  emulate -L zsh
  local __secret_internal_path="$1"
  local __secret_internal_mode

  [[ -e "$__secret_internal_path" && ! -L "$__secret_internal_path" && -O "$__secret_internal_path" ]] || return 1
  __secret_internal_mode="$(command stat -f '%Lp' "$__secret_internal_path" 2>/dev/null)" ||
    __secret_internal_mode="$(command stat -c '%a' "$__secret_internal_path" 2>/dev/null)" || return 1
  [[ "$__secret_internal_mode" == <-> ]] || return 1
  (( (8#$__secret_internal_mode & 8#77) == 0 ))
}

# Every existing cache-directory ancestor must be a real directory owned by
# this user or root.  A sticky directory is safe despite group/other writes
# because the checked child path is still owned by this user or root.
function __secret_cache_ancestors_trusted() {
  emulate -L zsh
  local __secret_internal_directory="$1"
  local -A __secret_internal_stat

  [[ -n "$__secret_internal_directory" && "$__secret_internal_directory" == /* ]] || return 1
  [[ "${__secret_internal_directory:a}" == "${__secret_internal_directory:A}" ]] || return 1
  zmodload zsh/stat || return 1
  while :; do
    if [[ -e "$__secret_internal_directory" || -L "$__secret_internal_directory" ]]; then
      [[ -d "$__secret_internal_directory" && ! -L "$__secret_internal_directory" ]] || return 1
      zstat -H __secret_internal_stat -- "$__secret_internal_directory" || return 1
      (( __secret_internal_stat[uid] == EUID || __secret_internal_stat[uid] == 0 )) || return 1
      (( (__secret_internal_stat[mode] & 8#022) == 0 || (__secret_internal_stat[mode] & 8#1000) != 0 )) || return 1
    fi
    [[ "$__secret_internal_directory" == "${__secret_internal_directory:h}" ]] && break
    __secret_internal_directory="${__secret_internal_directory:h}"
  done
  return 0
}

# A `.git` directory or worktree pointer in any ancestor proves this cache
# destination is inside a Git worktree.  This does not rely on ignore rules.
function __secret_path_is_in_git_worktree() {
  emulate -L zsh
  local __secret_internal_directory="${1:A}"

  [[ -n "$__secret_internal_directory" ]] || return 1
  while :; do
    [[ -e "$__secret_internal_directory/.git" || -L "$__secret_internal_directory/.git" ]] && return 0
    [[ "$__secret_internal_directory" == "${__secret_internal_directory:h}" ]] && break
    __secret_internal_directory="${__secret_internal_directory:h}"
  done
  return 1
}

# The caller receives the canonical cache file in __SECRET_INTERNAL_REPLY.  The XDG state root
# and its zsh child are made private before any secret temporary is created.
function __secret_prepare_cache_path() {
  emulate -L zsh
  unsetopt xtrace verbose
  local __secret_internal_requested __secret_internal_state_dir __secret_internal_cache_dir
  local -A __secret_internal_stat

  __secret_internal_requested="$(__secret_cache_path)" || return 1
  [[ "${__secret_internal_requested:a}" == "${__secret_internal_requested:A}" ]] || return 1
  __secret_internal_cache_dir="${__secret_internal_requested:h}"
  __secret_internal_state_dir="${__secret_internal_cache_dir:h}"
  __secret_cache_ancestors_trusted "$__secret_internal_cache_dir" || return 1
  __secret_path_is_in_git_worktree "$__secret_internal_cache_dir" && return 1
  zmodload zsh/stat || return 1
  if [[ ! -e "$__secret_internal_state_dir" && ! -L "$__secret_internal_state_dir" ]]; then
    (umask 077; mkdir -p -- "$__secret_internal_state_dir") || return 1
  fi
  [[ -d "$__secret_internal_state_dir" && ! -L "$__secret_internal_state_dir" && -O "$__secret_internal_state_dir" ]] || return 1
  zstat -H __secret_internal_stat -- "$__secret_internal_state_dir" || return 1
  (( (__secret_internal_stat[mode] & 8#022) == 0 )) || return 1
  __secret_cache_ancestors_trusted "$__secret_internal_cache_dir" || return 1
  if [[ ! -e "$__secret_internal_cache_dir" && ! -L "$__secret_internal_cache_dir" ]]; then
    (umask 077; mkdir -p -- "$__secret_internal_cache_dir") || return 1
  fi
  [[ -d "$__secret_internal_cache_dir" ]] || return 1
  __secret_path_is_owner_private "$__secret_internal_cache_dir" || return 1
  [[ "${__secret_internal_requested:a}" == "${__secret_internal_requested:A}" ]] || return 1
  __SECRET_INTERNAL_REPLY="${__secret_internal_requested:a}"
  if [[ -e "$__SECRET_INTERNAL_REPLY" || -L "$__SECRET_INTERNAL_REPLY" ]]; then
    [[ -f "$__SECRET_INTERNAL_REPLY" ]] || return 1
    __secret_path_is_owner_private "$__SECRET_INTERNAL_REPLY" || return 1
  fi
  return 0
}
function __secret_cache_file_safe() {
  emulate -L zsh
  local __secret_internal_cache="$1"
  local __secret_internal_cache_dir

  [[ -n "$__secret_internal_cache" ]] || return 1
  [[ "$__secret_internal_cache" == "${__secret_internal_cache:A}" ]] || return 1
  __secret_internal_cache_dir="${__secret_internal_cache:h}"
  __secret_cache_ancestors_trusted "$__secret_internal_cache_dir" || return 1
  __secret_path_is_owner_private "$__secret_internal_cache" || return 1
  __secret_path_is_owner_private "$__secret_internal_cache_dir" || return 1
  __secret_path_is_in_git_worktree "$__secret_internal_cache_dir" && return 1
  return 0
}

# Cache name metadata is comment-only so startup remains an ordinary export
# source file.  Reading it never expands or executes a cached value.
function __secret_cache_inventory_file() {
  emulate -L zsh
  local __secret_internal_cache="$1"
  local __secret_internal_line __secret_internal_name
  local __secret_internal_metadata=1
  local -A __secret_internal_seen

  [[ -f "$__secret_internal_cache" && ! -L "$__secret_internal_cache" && -O "$__secret_internal_cache" ]] || return 1
  while IFS= read -r __secret_internal_line; do
    if (( __secret_internal_metadata )); then
      case "$__secret_internal_line" in
        '# zsh-secret-cache-format: 1')
          ;;
        '# zsh-secret-name: '*)
          __secret_internal_name="${__secret_internal_line#\# zsh-secret-name: }"
          __secret_var_name_valid "$__secret_internal_name" || return 1
          [[ -z "${__secret_internal_seen[$__secret_internal_name]-}" ]] || return 1
          __secret_internal_seen[$__secret_internal_name]=1
          print -r -- "$__secret_internal_name"
          ;;
        *)
          # Generated metadata precedes the first export.  Never interpret
          # lines inside a shell-quoted multiline value as metadata.
          __secret_internal_metadata=0
          ;;
      esac
    fi
  done < "$__secret_internal_cache"
  (( ${#__secret_internal_seen} ))
}

function __secret_existing_cache_inventory() {
  emulate -L zsh
  local __secret_internal_cache

  __secret_internal_cache="$(__secret_cache_path)" || return 1
  __secret_cache_file_safe "$__secret_internal_cache" || return 1
  __secret_cache_inventory_file "$__secret_internal_cache"
}

function __secret_acquire_cache_lock() {
  emulate -L zsh
  unsetopt xtrace verbose
  local __secret_internal_cache_dir="$1"
  local __secret_internal_lock_file="${__secret_internal_cache_dir}/.secrets.lock"
  local __secret_internal_fd

  [[ -d "$__secret_internal_cache_dir" && ! -L "$__secret_internal_cache_dir" ]] || return 1
  __secret_cache_ancestors_trusted "$__secret_internal_cache_dir" || return 1
  __secret_path_is_owner_private "$__secret_internal_cache_dir" || return 1
  zmodload zsh/system || return 1
  if [[ ! -e "$__secret_internal_lock_file" && ! -L "$__secret_internal_lock_file" ]]; then
    (umask 077; setopt noclobber; : > "$__secret_internal_lock_file") 2>/dev/null || true
  fi
  [[ -f "$__secret_internal_lock_file" ]] || return 1
  __secret_path_is_owner_private "$__secret_internal_lock_file" || return 1
  zsystem flock -t 5 -f __secret_internal_fd "$__secret_internal_lock_file" || return 1
  __SECRET_INTERNAL_REPLY="$__secret_internal_fd"
}
function __secret_release_cache_lock() {
  emulate -L zsh
  unsetopt xtrace verbose
  [[ "$1" == <-> ]] || return 1
  zsystem flock -u "$1"
}
# Serialize only selected names in an ordinary sourceable zsh export file.
# `(qq)` yields a single-quoted shell literal, so values are data when sourced,
# including quotes, metacharacters, empty strings, newlines, and final newlines.
function __secret_write_cache_from_recipe() {
  emulate -L zsh
  unsetopt xtrace verbose
  setopt localtraps
  trap 'return 130' INT
  trap 'return 143' TERM
  local __secret_internal_output="$1" __secret_internal_inventory="$2"
  local __secret_internal_secret_file="$HOME/.config/zsh/vars.secret"
  local __secret_internal_name __secret_internal_value
  local __SECRET_INTERNAL_TMP_ROOT="${__secret_internal_output:h}"
  local -x TMPDIR="$__SECRET_INTERNAL_TMP_ROOT"

  [[ -f "$__secret_internal_secret_file" ]] || return 1
  __secret_reset_pending_reads
  {
    source "$__secret_internal_secret_file" > /dev/null 2>&1 || return 1
    __secret_await_op_reads || return 1
    {
      print -r -- '# zsh-secret-cache-format: 1'
      while IFS= read -r __secret_internal_name; do
        __secret_var_name_valid "$__secret_internal_name" || return 1
        print -r -- "# zsh-secret-name: $__secret_internal_name" || return 1
      done <<< "$__secret_internal_inventory"
      while IFS= read -r __secret_internal_name; do
        (( ${+parameters[$__secret_internal_name]} )) || return 1
        [[ "${parameters[$__secret_internal_name]}" == *export* ]] || return 1
        __secret_internal_value="${(P)__secret_internal_name}"
        print -r -- "export ${__secret_internal_name}=${(qq)__secret_internal_value}" || return 1
      done <<< "$__secret_internal_inventory"
    } > "$__secret_internal_output" || return 1
    chmod 600 -- "$__secret_internal_output" || return 1
  } always {
    __secret_reset_pending_reads
  }
}
# Snapshot only managed targets.  It is private temporary data used solely to
# restore this shell if applying a generated cache or publishing it fails.
function __secret_snapshot_vars() {
  emulate -L zsh
  unsetopt xtrace verbose
  local __secret_internal_output="$1"
  local __secret_internal_inventory="$2"
  local __secret_internal_name __secret_internal_value __secret_internal_attributes

  {
    while IFS= read -r __secret_internal_name; do
      __secret_var_name_valid "$__secret_internal_name" || return 1
      if (( ${+parameters[$__secret_internal_name]} )); then
        __secret_internal_value="${(P)__secret_internal_name}"
        __secret_internal_attributes="${parameters[$__secret_internal_name]}"
        if [[ "$__secret_internal_attributes" == *export* ]]; then
          print -r -- "export ${__secret_internal_name}=${(qq)__secret_internal_value}"
        else
          print -r -- "typeset -g +x ${__secret_internal_name}=${(qq)__secret_internal_value}"
        fi
      else
        print -r -- "unset ${__secret_internal_name}"
      fi
    done <<< "$__secret_internal_inventory"
  } > "$__secret_internal_output" || return 1
  chmod 600 -- "$__secret_internal_output"
}

function __secret_source_literal_file() {
  emulate -L zsh
  unsetopt xtrace verbose
  local __secret_internal_cache="$1"

  source "$__secret_internal_cache" > /dev/null 2>&1
}

# Refresh in two phases: an isolated producer resolves the trusted recipe into
# a private temporary cache; only then does the parent import and atomically
# replace the old cache.  No cache or variables are cleared before production.
function __secret_refresh() {
  emulate -L zsh
  unsetopt xtrace verbose
  setopt localtraps
  trap 'return 130' INT
  trap 'return 143' TERM
  local __secret_internal_inventory __secret_internal_cache __secret_internal_cache_dir __secret_internal_lock_fd
  local __secret_internal_old_inventory='' __secret_internal_all_inventory __secret_internal_removed_inventory __secret_internal_generated_inventory
  local __secret_internal_cache_tmp='' __secret_internal_restore_tmp=''
  local __secret_internal_imported=0 __secret_internal_published=0

  __secret_internal_inventory="$(__get_secret_vars)" || return 1
  __secret_inventory_names_valid "$__secret_internal_inventory" || return 1
  __secret_prepare_cache_path || return 1
  __secret_internal_cache="$__SECRET_INTERNAL_REPLY"
  __secret_internal_cache_dir="${__secret_internal_cache:h}"
  __secret_acquire_cache_lock "$__secret_internal_cache_dir" || return 1
  __secret_internal_lock_fd="$__SECRET_INTERNAL_REPLY"
  {
    if [[ -e "$__secret_internal_cache" || -L "$__secret_internal_cache" ]]; then
      __secret_cache_file_safe "$__secret_internal_cache" || return 1
      __secret_internal_old_inventory="$(__secret_cache_inventory_file "$__secret_internal_cache")" || return 1
    fi
    __secret_internal_all_inventory="$(__secret_inventory_merge "$__secret_internal_old_inventory" "$__secret_internal_inventory")" || return 1
    __secret_internal_removed_inventory="$(__secret_inventory_difference "$__secret_internal_old_inventory" "$__secret_internal_inventory")" || return 1
    __secret_names_can_be_set "$__secret_internal_inventory" || return 1
    __secret_names_can_be_unset "$__secret_internal_removed_inventory" || return 1
    __secret_internal_cache_tmp="$(umask 077; mktemp "$__secret_internal_cache_dir/.secrets.zsh.XXXXXX")" || return 1
    __secret_internal_restore_tmp="$(umask 077; mktemp "$__secret_internal_cache_dir/.secrets.restore.XXXXXX")" || return 1
    __secret_snapshot_vars "$__secret_internal_restore_tmp" "$__secret_internal_all_inventory" || return 1
    ( __secret_write_cache_from_recipe "$__secret_internal_cache_tmp" "$__secret_internal_inventory" ) > /dev/null 2>&1 || return 1
    __secret_internal_generated_inventory="$(__secret_cache_inventory_file "$__secret_internal_cache_tmp")" || return 1
    __secret_inventory_same "$__secret_internal_inventory" "$__secret_internal_generated_inventory" || return 1
    # Complete the short in-memory/disk commit without a partial signal rollback.
    trap '' INT TERM
    __secret_internal_imported=1
    __secret_source_literal_file "$__secret_internal_cache_tmp" || return 1
    __secret_unset_vars "$__secret_internal_removed_inventory" || return 1
    mv -f -- "$__secret_internal_cache_tmp" "$__secret_internal_cache" || return 1
    __secret_internal_cache_tmp=''
    __secret_internal_published=1
  } always {
    if (( __secret_internal_imported && ! __secret_internal_published )); then
      __secret_source_literal_file "$__secret_internal_restore_tmp" || true
    fi
    [[ -n "$__secret_internal_cache_tmp" ]] && rm -f -- "$__secret_internal_cache_tmp"
    [[ -n "$__secret_internal_restore_tmp" ]] && rm -f -- "$__secret_internal_restore_tmp"
    __secret_release_cache_lock "$__secret_internal_lock_fd" >/dev/null 2>&1 || true
  }
  (( __secret_internal_published ))
}
function __secret_clear_state() {
  emulate -L zsh
  unsetopt xtrace verbose
  setopt localtraps
  trap 'return 130' INT
  trap 'return 143' TERM
  local __secret_internal_cache __secret_internal_cache_dir __secret_internal_inventory __secret_internal_lock_fd
  local __secret_internal_restore_tmp=''
  local __secret_internal_changed=0 __secret_internal_complete=0

  __secret_internal_cache="$(__secret_cache_path)" || return 1
  [[ "${__secret_internal_cache:a}" == "${__secret_internal_cache:A}" ]] || return 1
  __secret_internal_cache_dir="${__secret_internal_cache:h}"
  __secret_cache_ancestors_trusted "$__secret_internal_cache_dir" || return 1
  __secret_path_is_in_git_worktree "$__secret_internal_cache_dir" && return 1
  [[ -e "$__secret_internal_cache_dir" || -L "$__secret_internal_cache_dir" ]] || return 0
  [[ -d "$__secret_internal_cache_dir" ]] || return 1
  __secret_path_is_owner_private "$__secret_internal_cache_dir" || return 1
  __secret_acquire_cache_lock "$__secret_internal_cache_dir" || return 1
  __secret_internal_lock_fd="$__SECRET_INTERNAL_REPLY"
  {
    [[ -e "$__secret_internal_cache" || -L "$__secret_internal_cache" ]] || return 0
    __secret_cache_file_safe "$__secret_internal_cache" || return 1
    __secret_internal_inventory="$(__secret_cache_inventory_file "$__secret_internal_cache")" || return 1
    __secret_names_can_be_unset "$__secret_internal_inventory" || return 1
    __secret_internal_restore_tmp="$(umask 077; mktemp "$__secret_internal_cache_dir/.secrets.restore.XXXXXX")" || return 1
    __secret_snapshot_vars "$__secret_internal_restore_tmp" "$__secret_internal_inventory" || return 1
    trap '' INT TERM
    __secret_internal_changed=1
    __secret_unset_vars "$__secret_internal_inventory" || return 1
    rm -f -- "$__secret_internal_cache" || return 1
    __secret_internal_complete=1
  } always {
    if (( __secret_internal_changed && ! __secret_internal_complete )); then
      __secret_source_literal_file "$__secret_internal_restore_tmp" || true
    fi
    [[ -n "$__secret_internal_restore_tmp" ]] && rm -f -- "$__secret_internal_restore_tmp"
    __secret_release_cache_lock "$__secret_internal_lock_fd" >/dev/null 2>&1 || true
  }
  (( __secret_internal_complete ))
}
function __secret_status() {
  emulate -L zsh
  local __secret_internal_cache __secret_internal_inventory __secret_internal_count=0 __secret_internal_name

  __secret_internal_cache="$(__secret_cache_path)" || return 1
  if ! __secret_cache_file_safe "$__secret_internal_cache" ||
     ! __secret_internal_inventory="$(__secret_cache_inventory_file "$__secret_internal_cache")"; then
    print -r -- 'Secrets cache: unavailable'
    return 1
  fi
  while IFS= read -r __secret_internal_name; do
    (( __secret_internal_count++ ))
  done <<< "$__secret_internal_inventory"
  print -r -- "Secrets cache: ready (${__secret_internal_count} variables)"
  print -r -- "Cache path: $__secret_internal_cache"
}

function __secret_list() {
  emulate -L zsh
  local __secret_internal_inventory

  __secret_internal_inventory="$(__secret_existing_cache_inventory)" || return 1
  print -r -- "$__secret_internal_inventory"
}

function secret() {
  emulate -L zsh
  unsetopt xtrace verbose
  local __secret_internal_action='refresh'
  local __secret_internal_quiet=0
  local __secret_internal_inventory __secret_internal_count=0 __secret_internal_name

  while (( $# )); do
    case "$1" in
      -c|--clear)
        __secret_internal_action='clear'
        ;;
      -r|--reload)
        __secret_internal_action='refresh'
        ;;
      -l|--list)
        __secret_internal_action='list'
        ;;
      -s|--status)
        __secret_internal_action='status'
        ;;
      -q|--quiet)
        __secret_internal_quiet=1
        ;;
      -h|--help)
        __secret_usage
        return 0
        ;;
      *)
        (( __secret_internal_quiet )) || print -ru2 -- 'Error: unknown secret option'
        return 1
        ;;
    esac
    shift
  done

  case "$__secret_internal_action" in
    refresh)
      if ! __secret_refresh; then
        (( __secret_internal_quiet )) || print -ru2 -- 'Error: unable to refresh secrets'
        return 1
      fi
      if (( ! __secret_internal_quiet )); then
        __secret_internal_inventory="$(__secret_existing_cache_inventory)" || return 1
        while IFS= read -r __secret_internal_name; do
          (( __secret_internal_count++ ))
        done <<< "$__secret_internal_inventory"
        print -r -- "Secrets refreshed: ${__secret_internal_count} variables"
      fi
      ;;
    clear)
      if ! __secret_clear_state; then
        (( __secret_internal_quiet )) || print -ru2 -- 'Error: unable to clear secrets safely'
        return 1
      fi
      (( __secret_internal_quiet )) || print -r -- 'Secrets cache cleared'
      ;;
    status)
      if (( __secret_internal_quiet )); then
        __secret_cache_path >/dev/null || return 1
        __secret_existing_cache_inventory >/dev/null
      else
        __secret_status
      fi
      ;;
    list)
      if (( __secret_internal_quiet )); then
        __secret_existing_cache_inventory >/dev/null
      elif ! __secret_list; then
        print -ru2 -- 'Error: no safe secret cache is available'
        return 1
      fi
      ;;
  esac
}

if [[ -n "$ZSH_VERSION" && -n "${functions[compdef]}" ]]; then
  _secret() {
    local -a __secret_internal_options
    __secret_internal_options=(
      '-c:Clear the local secret cache and current shell vars'
      '--clear:Clear the local secret cache and current shell vars'
      '-r:Refresh the local secret cache'
      '--reload:Refresh the local secret cache'
      '-l:List cached secret variable names'
      '--list:List cached secret variable names'
      '-s:Show local secret cache status'
      '--status:Show local secret cache status'
      '-q:Suppress output'
      '--quiet:Suppress output'
      '-h:Display help'
      '--help:Display help'
    )
    _describe 'secret options' __secret_internal_options
  }
  compdef _secret secret
fi
