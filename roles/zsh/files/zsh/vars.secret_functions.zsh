#!/usr/bin/env zsh

function __secret_usage() {
  echo -e "${YELLOW}Usage: ${CYAN}secret [options]${NC}"
  echo ""
  echo -e "${YELLOW}Description:${NC}"
  echo -e "  Load or unload secret environment variables from 1Password."
  echo ""
  echo -e "${YELLOW}Options:${NC}"
  echo -e "  ${CYAN}-c, --clear${NC}    Clear secret vars"
  echo -e "  ${CYAN}-r, --reload${NC}   Reload secret vars"
  echo -e "  ${CYAN}-l, --list${NC}     List loaded secret vars (names only)"
  echo -e "  ${CYAN}-s, --status${NC}   Show secret loading status"
  echo -e "  ${CYAN}-q, --quiet${NC}    Load without status text"
  echo -e "  ${CYAN}-h, --help${NC}     Display this help message"
  echo ""
  echo -e "${YELLOW}Examples:${NC}"
  echo -e "  ${CYAN}secret${NC}         # Load secret vars"
  echo -e "  ${CYAN}secret -c${NC}      # Clear secret vars"
  echo -e "  ${CYAN}secret -r${NC}      # Reload secret vars"
  echo -e "  ${CYAN}secret -l${NC}      # List loaded secret vars"
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

function __secret_file_signature() {
  [[ -r "$1" ]] || return 1
  cksum < "$1" 2>/dev/null
}

function __secret_metadata_present() {
  [[ -n "${SECRETS_ALREADY_LOADED-}" ||
     -n "${SECRETS_LOADED_AT-}" ||
     -n "${SECRETS_LOADED_VARS-}" ||
     -n "${SECRETS_LOADED_SIGNATURE-}" ]]
}

function __secret_in_agent_shell() {
  (( ${+functions[is_agent_shell]} )) && is_agent_shell
}

# Check if 1Password CLI is available and authenticated
function __op_check() {
  if ! command -v op &>/dev/null; then
    print -ru2 -- 'Error: unable to load secrets'
    return 1
  fi

  local op_account="${OP_ACCOUNT:-my.1password.com}"
  if ! op vault list --account "$op_account" --format json >/dev/null 2>&1; then
    print -ru2 -- 'Error: unable to load secrets'
    return 1
  fi

  return 0
}

function __op_ready() {
  local op_account="${OP_ACCOUNT:-my.1password.com}"
  command -v op &>/dev/null || return 1
  op vault list --account "$op_account" --format json >/dev/null 2>&1
}

# Extract exported variable names, preserving their first declaration order.
function __get_secret_vars() {
  local secret_file="$HOME/.config/zsh/vars.secret"

  if [[ ! -f "$secret_file" ]]; then
    echo -e "${RED}Error: Secret file not found: ${YELLOW}$secret_file${NC}" >&2
    return 1
  fi

  awk '
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
  ' "$secret_file"
}

function __secret_inventory_names_valid() {
  local __secret_internal_inventory="$1"
  local __secret_internal_name

  [[ -n "$__secret_internal_inventory" ]] || return 1
  while IFS= read -r __secret_internal_name; do
    __secret_var_name_valid "$__secret_internal_name" || return 1
  done <<< "$__secret_internal_inventory"
}

function __secret_unset_vars() {
  [[ -n "$1" ]] || return 0
  __SECRET_INTERNAL_UNSET_STATUS=0
  while IFS= read -r __SECRET_INTERNAL_UNSET_TARGET; do
    [[ -z "$__SECRET_INTERNAL_UNSET_TARGET" ]] && continue
    __secret_shell_var_name_valid "$__SECRET_INTERNAL_UNSET_TARGET" || continue
    if [[ "${parameters[$__SECRET_INTERNAL_UNSET_TARGET]-}" == *readonly* ]] ||
       ! unset "$__SECRET_INTERNAL_UNSET_TARGET" 2>/dev/null; then
      __SECRET_INTERNAL_UNSET_STATUS=1
      break
    fi
  done <<< "$1"

  if (( __SECRET_INTERNAL_UNSET_STATUS )); then
    unset __SECRET_INTERNAL_UNSET_TARGET __SECRET_INTERNAL_UNSET_STATUS
    return 1
  fi
  unset __SECRET_INTERNAL_UNSET_TARGET __SECRET_INTERNAL_UNSET_STATUS
}

# Clear both the current profile and the inventory from the last successful load.
function __secret_clear_state() {
  __secret_reset_pending_reads
  if [[ -f "$HOME/.config/zsh/vars.secret" ]]; then
    set -- "${SECRETS_LOADED_VARS-}" "$(__get_secret_vars 2>/dev/null)" 0
  else
    set -- "${SECRETS_LOADED_VARS-}" "" 0
  fi

  __secret_unset_vars "$1" || set -- "$1" "$2" 1
  __secret_unset_vars "$2" || set -- "$1" "$2" 1
  unset SECRETS_ALREADY_LOADED
  unset SECRETS_LOADED_AT
  unset SECRETS_LOADED_VARS
  unset SECRETS_LOADED_SIGNATURE
  return "$3"
}

function __secret_inventory_is_loaded() {
  local inventory="$1"
  local var

  [[ -n "$inventory" ]] || return 1
  while IFS= read -r var; do
    __secret_var_name_valid "$var" || return 1
    (( ${+parameters[$var]} )) || return 1
  done <<< "$inventory"
}

function __secret_already_loaded() {
  local signature

  if [[ "${SECRETS_ALREADY_LOADED:-}" == true &&
        -n "${SECRETS_LOADED_VARS-}" &&
        -n "${SECRETS_LOADED_SIGNATURE-}" ]] &&
     signature="$(__secret_file_signature "$HOME/.config/zsh/vars.secret")" &&
     [[ "$signature" == "$SECRETS_LOADED_SIGNATURE" ]] &&
     __secret_inventory_is_loaded "$SECRETS_LOADED_VARS"; then
    return 0
  fi

  if __secret_metadata_present; then
    __secret_clear_state
  fi
  return 1
}

# Never trust bookkeeping imported from a parent process.
unset __SECRET_OP_OUT __SECRET_OP_RC __SECRET_OP_REF __SECRET_OP_ACCOUNT
unset __SECRET_OP_VARS __SECRET_OP_PIDS __SECRET_OP_TMPDIR __SECRET_OP_BATCH_OUT
typeset -gA __SECRET_OP_OUT=()
typeset -gA __SECRET_OP_RC=()
typeset -gA __SECRET_OP_REF=()
typeset -gA __SECRET_OP_ACCOUNT=()
typeset -ga __SECRET_OP_VARS=()
typeset -ga __SECRET_OP_PIDS=()
typeset -g +x __SECRET_OP_TMPDIR=''
typeset -g +x __SECRET_OP_BATCH_OUT=''

function __secret_op_pending_dir() {
  if [[ -z "${__SECRET_OP_TMPDIR-}" ]]; then
    __SECRET_OP_TMPDIR="$(umask 077; mktemp -d "${TMPDIR:-/tmp}/zsh-secret.XXXXXX")" || return 1
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
  local pid

  setopt localoptions nomonitor
  for pid in "${__SECRET_OP_PIDS[@]}"; do
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
  done
  if [[ -n "${__SECRET_OP_TMPDIR-}" ]]; then
    case "$__SECRET_OP_TMPDIR" in
      "${TMPDIR:-/tmp}"/zsh-secret.*)
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
}

function __secret_unset_pending_read_vars() {
  local __secret_pending_target

  for __secret_pending_target in "${__SECRET_OP_VARS[@]}"; do
    __secret_var_name_valid "$__secret_pending_target" || continue
    [[ "${parameters[$__secret_pending_target]-}" == *readonly* ]] && continue
    unset "$__secret_pending_target" 2>/dev/null || true
  done
}

# Read one non-empty 1Password value without exposing it on a failure path.
function __secret_op_read() {
  local value

  value="$(op read "$@")" || return 1
  [[ -n "$value" ]] || return 1
  print -r -- "$value"
}

# Queue one 1Password read. The value is not exported until
# __secret_await_op_reads; await before expanding a queued variable.
function __secret_export_op_read() {
  local var="$1"
  local out_file rc_file
  local account reference

  if __secret_use_single_process_batch; then
    if (( $# != 4 )) ||
       ! __secret_var_name_valid "$var" ||
       [[ "$2" != --account || -z "$3" || "$4" != op://* ]] ||
       [[ "${parameters[$var]-}" == *readonly* ||
          -n "${__SECRET_OP_REF[$var]-}" ||
          -n "${__SECRET_OP_ACCOUNT[$var]-}" ]]; then
      __secret_unset_pending_read_vars
      __secret_reset_pending_reads
      return 1
    fi

    account="$3"
    reference="$4"

    __secret_op_pending_dir || {
      __secret_unset_pending_read_vars
      __secret_reset_pending_reads
      return 1
    }
    __SECRET_OP_ACCOUNT[$var]="$account"
    __SECRET_OP_REF[$var]="$reference"
    __SECRET_OP_VARS+=("$var")
    return 0
  fi

  (( $# >= 2 )) || return 1
  __secret_var_name_valid "$var" || return 1
  shift
  setopt localoptions nomonitor
  __secret_op_pending_dir || return 1
  out_file="$__SECRET_OP_TMPDIR/$var.out"
  rc_file="$__SECRET_OP_TMPDIR/$var.rc"

  (
    unsetopt xtrace 2>/dev/null
    set +e
    op read "$@" > "$out_file"
    print -r -- "$?" > "$rc_file"
  ) &
  __SECRET_OP_PIDS+=($!)
  __SECRET_OP_VARS+=("$var")
  __SECRET_OP_OUT[$var]="$out_file"
  __SECRET_OP_RC[$var]="$rc_file"
}


# Resolve a Linux wave without overlapping desktop CLI clients. References are
# grouped by account; account batches run serially and commit transactionally.
function __secret_await_op_run_batch() {
  local account expected_var received_var value extra
  local failed=0
  local -a accounts account_vars
  local -A seen_accounts values
  setopt localoptions noxtrace

  (( ${#__SECRET_OP_VARS[@]} )) || return 0
  if [[ -z "${__SECRET_OP_TMPDIR-}" ]] ||
     (( ${#__SECRET_OP_REF[@]} != ${#__SECRET_OP_VARS[@]} )) ||
     (( ${#__SECRET_OP_ACCOUNT[@]} != ${#__SECRET_OP_VARS[@]} )) ||
     (( ${#__SECRET_OP_PIDS[@]} )); then
    __secret_unset_pending_read_vars
    __secret_reset_pending_reads
    return 1
  fi
  for expected_var in "${__SECRET_OP_VARS[@]}"; do
    account="${__SECRET_OP_ACCOUNT[$expected_var]-}"
    if ! __secret_var_name_valid "$expected_var" ||
       [[ "${parameters[$expected_var]-}" == *readonly* ||
          -z "$account" || "${__SECRET_OP_REF[$expected_var]-}" != op://* ]]; then
      __secret_unset_pending_read_vars
      __secret_reset_pending_reads
      return 1
    fi
    if [[ -z "${seen_accounts[$account]-}" ]]; then
      accounts+=("$account")
      seen_accounts[$account]=1
    fi
  done

  for account in "${accounts[@]}"; do
    account_vars=()
    for expected_var in "${__SECRET_OP_VARS[@]}"; do
      if [[ "${__SECRET_OP_ACCOUNT[$expected_var]}" == "$account" ]]; then
        account_vars+=("$expected_var")
      fi
    done

    __SECRET_OP_BATCH_OUT="$(umask 077; mktemp "$__SECRET_OP_TMPDIR/batch.XXXXXX")" 2>/dev/null || {
      failed=1
      break
    }
    (
      unsetopt xtrace 2>/dev/null
      set -- ${(k)parameters[(R)*-export*]}
      while (( $# )); do
        if ! __secret_op_run_environment_allowed "$1" ||
           [[ "${(P)1}" == op://* ]]; then
          typeset -g +x "$1" 2>/dev/null || exit 1
        fi
        shift
      done
      for expected_var in "${account_vars[@]}"; do
        typeset -gx "$expected_var=${__SECRET_OP_REF[$expected_var]}" || exit 1
      done
      exec op run --account "$account" --no-masking -- zsh -fc '
        emulate -LR zsh
        while (( $# )); do
          printf "%s\0%s\0" "$1" "${(P)1}" || exit 1
          shift
        done
      ' zsh "${account_vars[@]}"
    ) > "$__SECRET_OP_BATCH_OUT" 2>/dev/null || failed=1

    if (( ! failed )); then
      {
        for expected_var in "${account_vars[@]}"; do
          received_var=''
          value=''
          if ! IFS= read -r -d $'\0' received_var ||
             ! IFS= read -r -d $'\0' value ||
             [[ "$received_var" != "$expected_var" || -z "$value" ]]; then
            failed=1
            break
          fi
          values[$expected_var]="$value"
        done
        if (( ! failed )); then
          extra=''
          if IFS= read -r -d $'\0' extra || [[ -n "$extra" ]]; then
            failed=1
          fi
        fi
        (( ! failed ))
      } < "$__SECRET_OP_BATCH_OUT" || failed=1
    fi

    rm -f "$__SECRET_OP_BATCH_OUT"
    unset __SECRET_OP_BATCH_OUT
    (( failed )) && break
  done

  if (( ! failed )); then
    for expected_var in "${__SECRET_OP_VARS[@]}"; do
      if ! typeset -gx "$expected_var=${values[$expected_var]}"; then
        failed=1
        break
      fi
    done
  fi
  (( failed )) && __secret_unset_pending_read_vars

  __secret_reset_pending_reads
  (( ! failed ))
}
# Wait for queued reads and export every value, or export none from this batch.
function __secret_await_op_reads() {
  if __secret_use_single_process_batch; then
    __secret_await_op_run_batch
    return $?
  fi

  local var pid rc value
  local failed=0

  for pid in "${__SECRET_OP_PIDS[@]}"; do
    wait "$pid" || true
  done

  for var in "${__SECRET_OP_VARS[@]}"; do
    rc="$(<"${__SECRET_OP_RC[$var]}")" 2>/dev/null || rc=""
    value="$(<"${__SECRET_OP_OUT[$var]}")" 2>/dev/null || value=""
    if [[ "$rc" != 0 || -z "$value" ||
          "${parameters[$var]-}" == *readonly* ]]; then
      failed=1
      break
    fi
  done

  if (( ! failed )); then
    for var in "${__SECRET_OP_VARS[@]}"; do
      value="$(<"${__SECRET_OP_OUT[$var]}")"
      if ! typeset -gx "$var=$value"; then
        failed=1
        break
      fi
    done
  fi
  (( failed )) && __secret_unset_pending_read_vars

  __secret_reset_pending_reads
  (( ! failed ))
}

function __secret_source_file() {
  local secret_file="$HOME/.config/zsh/vars.secret"
  local inventory
  local signature
  local AWS_CREDS_ITEM
  local error_log
  local xtrace_on=0

  [[ -f "$secret_file" ]] || {
    __secret_clear_state
    return 1
  }
  signature="$(__secret_file_signature "$secret_file")" || {
    __secret_clear_state
    return 1
  }
  inventory="$(__get_secret_vars 2>/dev/null)" || {
    __secret_clear_state
    return 1
  }
  [[ -n "$inventory" ]] || {
    __secret_clear_state
    return 1
  }
  __secret_inventory_names_valid "$inventory" || {
    __secret_clear_state
    return 1
  }

  # A stale inventory may contain vars removed from the current profile.
  __secret_clear_state || return 1
  error_log="$(mktemp)" || return 1
  [[ -o xtrace ]] && xtrace_on=1
  unsetopt xtrace
  setopt localoptions nomonitor

  if source "$secret_file" 2>"$error_log" && __secret_await_op_reads; then
    rm -f "$error_log"
    if __secret_inventory_is_loaded "$inventory"; then
      (( xtrace_on )) && setopt xtrace
      export SECRETS_LOADED_VARS="$inventory"
      export SECRETS_LOADED_SIGNATURE="$signature"
      export SECRETS_ALREADY_LOADED=true
      export SECRETS_LOADED_AT="$(date '+%Y-%m-%d %H:%M:%S')"
      return 0
    fi
  else
    rm -f "$error_log"
  fi

  (( xtrace_on )) && setopt xtrace
  __secret_clear_state
  return 1
}

# Quiet, fail-closed load for wrappers.
function __secret_ensure_loaded() {
  if __secret_already_loaded 2>/dev/null; then
    return 0
  fi
  secret --quiet >/dev/null 2>&1
}

function __secret_wrap_once() {
  local name="$1"
  local started_label="${2:-$1}"

  [[ "$name" =~ '^[A-Za-z_][A-Za-z0-9_-]*$' ]] || return 1
  (( ${+functions[$name]} )) && return 0
  whence -p "$name" >/dev/null 2>&1 || return 0

  functions[$name]="
    if ! __secret_ensure_loaded; then
      print -ru2 -- 'Error: unable to load secrets; ${started_label} was not started'
      return 1
    fi
    unfunction ${name}
    local canonical
    canonical=\$(whence -p ${name})
    if [[ -z \$canonical ]]; then
      print -ru2 -- 'Error: ${started_label} was not found after loading secrets'
      return 1
    fi
    \"\$canonical\" \"\$@\"
  "
}

function secret() {
  local action="load"
  local quiet=0

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -c|--clear)
        action="clear"
        shift
        ;;
      -r|--reload)
        action="reload"
        shift
        ;;
      -l|--list)
        action="list"
        shift
        ;;
      -s|--status)
        action="status"
        shift
        ;;
      -q|--quiet)
        quiet=1
        shift
        ;;
      -h|--help)
        __secret_usage
        return
        ;;
      *)
        echo -e "${RED}Unknown option: ${YELLOW}$1${NC}" >&2
        echo -e "Use ${CYAN}secret --help${NC} for usage information" >&2
        return 1
        ;;
    esac
  done

  case "$action" in
    status)
      if __secret_already_loaded; then
        echo -e " ${GREEN}[${CHECK_MARK}${GREEN}] Secrets are loaded${NC}"
        if [[ -n "$SECRETS_LOADED_AT" ]]; then
          echo -e " ${CYAN}   Loaded at: ${YELLOW}$SECRETS_LOADED_AT${NC}"
        fi
      else
        echo -e " ${YELLOW}[${WARNING}${YELLOW}] Secrets are not loaded${NC}"
      fi
      return
      ;;

    list)
      if ! __secret_already_loaded; then
        echo -e " ${YELLOW}[${WARNING}${YELLOW}] Secrets are not loaded${NC}"
        return 1
      fi

      echo -e " ${GREEN}Loaded secret variables:${NC}"
      local vars=$(__get_secret_vars)
      if [[ -n "$vars" ]]; then
        while IFS= read -r var; do
          if [[ -n "${(P)var}" ]]; then
            echo -e "   ${CYAN}${var}${NC} ${GREEN}✓${NC}"
          else
            echo -e "   ${CYAN}${var}${NC} ${RED}✗${NC}"
          fi
        done <<< "$vars"
      fi
      return
      ;;

    clear)
      if (( quiet )); then
        __secret_clear_state
        return
      fi

      __task "Clearing secret vars..."
      if __secret_clear_state; then
        _task_done
        echo -e " ${GREEN}Cleared secret variables${NC}"
      else
        _clear_task
        print -ru2 -- 'Error: unable to clear secret variables'
        return 1
      fi
      return
      ;;

    reload)
      if (( quiet )); then
        secret --quiet --clear && secret --quiet
        return
      fi
      __task "${ARROW} ${YELLOW}Reloading secrets..."
      _task_done
      secret --clear && secret
      return
      ;;

    load)
      if __secret_already_loaded; then
        (( quiet )) || echo -e " ${GREEN}[${CHECK_MARK}${GREEN}] Secrets already loaded${NC}"
        return
      fi

      if (( quiet )); then
        if ! __op_ready; then
          __secret_clear_state
          return 1
        fi
        if [[ ! -f "$HOME/.config/zsh/vars.secret" ]]; then
          __secret_clear_state
          return 1
        fi
        __secret_source_file
        return
      fi

      if ! __op_check; then
        __secret_clear_state
        return 1
      fi

      local secret_file="$HOME/.config/zsh/vars.secret"
      if [[ ! -f "$secret_file" ]]; then
        __secret_clear_state
        print -ru2 -- 'Error: unable to load secrets'
        return 1
      fi

      __task "Loading secrets..."
      if __secret_source_file; then
        _task_done
        local vars=$(__get_secret_vars)
        local count=0
        if [[ -n "$vars" ]]; then
          while IFS= read -r var; do
            [[ -n "${(P)var}" ]] && ((count++))
          done <<< "$vars"
        fi
        echo -e " ${GREEN}Loaded ${count} secret variable(s)${NC}"
        return
      fi

      __task "${X_MARK}${RED} Failed to load secrets"
      _clear_task
      print -ru2 -- 'Error: unable to load secrets'
      return 1
      ;;
  esac
}

# A marked Herd shell loads secrets only for its first OMP call.
if [[ "${OMP_HERD_LOAD_SECRETS-}" == "1" ]]; then
  unset OMP_HERD_LOAD_SECRETS
  if ! __secret_in_agent_shell; then
    __secret_wrap_once omp OMP
  fi
fi

# Interactive human shells only. Never wrap tools in agent shells (each zsh -c
# would re-query 1Password).
if [[ -o interactive ]] && ! __secret_in_agent_shell; then
  for _secret_tool in gh aws; do
    __secret_wrap_once "$_secret_tool"
  done
  unset _secret_tool
fi

# Add completion for the secret function
if [[ -n "$ZSH_VERSION" ]] && [[ -n "${functions[compdef]}" ]]; then
  _secret() {
    local -a options
    options=(
      '-c:Clear secret vars'
      '--clear:Clear secret vars'
      '-r:Reload secret vars'
      '--reload:Reload secret vars'
      '-l:List loaded secret vars'
      '--list:List loaded secret vars'
      '-s:Show secret loading status'
      '--status:Show secret loading status'
      '-q:Load without status text'
      '--quiet:Load without status text'
      '-h:Display help'
      '--help:Display help'
    )
    _describe 'secret options' options
  }
  compdef _secret secret
fi
