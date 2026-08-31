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

function __secret_var_name_valid() {
  [[ "$1" =~ '^[A-Za-z_][A-Za-z0-9_]*$' ]]
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

function __secret_unset_vars() {
  local vars="$1"
  local var

  [[ -n "$vars" ]] || return 0
  while IFS= read -r var; do
    [[ -z "$var" ]] && continue
    __secret_var_name_valid "$var" || continue
    unset "$var" 2>/dev/null || return 1
  done <<< "$vars"
}

# Clear both the current profile and the inventory from the last successful load.
function __secret_clear_state() {
  local current_vars=""
  local previous_vars="${SECRETS_LOADED_VARS-}"
  local clear_status=0

  if [[ -f "$HOME/.config/zsh/vars.secret" ]]; then
    current_vars="$(__get_secret_vars 2>/dev/null)" || clear_status=1
  fi

  __secret_unset_vars "$previous_vars" || clear_status=1
  __secret_unset_vars "$current_vars" || clear_status=1
  unset SECRETS_ALREADY_LOADED
  unset SECRETS_LOADED_AT
  unset SECRETS_LOADED_VARS
  unset SECRETS_LOADED_SIGNATURE
  return "$clear_status"
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

# Read one non-empty 1Password value without exposing it on a failure path.
function __secret_op_read() {
  local value

  value="$(op read "$@")" || return 1
  [[ -n "$value" ]] || return 1
  print -r -- "$value"
}

# Export one non-empty 1Password value while preserving op's failure status.
function __secret_export_op_read() {
  local var="$1"
  local value

  (( $# >= 2 )) || return 1
  __secret_var_name_valid "$var" || return 1
  shift
  value="$(__secret_op_read "$@")" || return 1
  export "$var=$value"
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

  # A stale inventory may contain vars removed from the current profile.
  __secret_clear_state
  error_log="$(mktemp)" || return 1
  [[ -o xtrace ]] && xtrace_on=1
  unsetopt xtrace

  if source "$secret_file" 2>"$error_log"; then
    (( xtrace_on )) && setopt xtrace
    rm -f "$error_log"
    if __secret_inventory_is_loaded "$inventory"; then
      export SECRETS_LOADED_VARS="$inventory"
      export SECRETS_LOADED_SIGNATURE="$signature"
      export SECRETS_ALREADY_LOADED=true
      export SECRETS_LOADED_AT="$(date '+%Y-%m-%d %H:%M:%S')"
      return 0
    fi
  else
    (( xtrace_on )) && setopt xtrace
    rm -f "$error_log"
  fi

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
  __secret_wrap_once omp OMP
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
