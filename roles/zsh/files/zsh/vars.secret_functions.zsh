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
  echo -e "  ${CYAN}-q, --quiet${NC}    Load or skip without status text"
  echo -e "  ${CYAN}-h, --help${NC}     Display this help message"
  echo ""
  echo -e "${YELLOW}Examples:${NC}"
  echo -e "  ${CYAN}secret${NC}         # Load secret vars"
  echo -e "  ${CYAN}secret -c${NC}      # Clear secret vars"
  echo -e "  ${CYAN}secret -r${NC}      # Reload secret vars"
  echo -e "  ${CYAN}secret -l${NC}      # List loaded secret vars"
  echo -e "  ${CYAN}with-secrets agent${NC}  # Load once, then exec an agent"
}

function __secret_already_loaded() {
  [[ "${SECRETS_ALREADY_LOADED:-}" == true ]]
}

function __secret_skip_requested() {
  [[ "${ORCA_SKIP_SECRETS:-}" == 1 || "${SECRET_SKIP:-}" == 1 ]]
}

function __secret_in_agent_shell() {
  (( ${+functions[is_agent_shell]} )) && is_agent_shell
}

# Check if 1Password CLI is available and authenticated
function __op_check() {
  if ! command -v op &>/dev/null; then
    echo -e "${RED}Error: 1Password CLI (op) not found${NC}" >&2
    echo -e "${YELLOW}Install 1Password CLI with Homebrew (brew install --cask 1password-cli) or your distro package, then rerun the 1password role.${NC}" >&2
    return 1
  fi

  local op_account="${OP_ACCOUNT:-my.1password.com}"
  if ! op vault list --account "$op_account" --format json >/dev/null 2>&1; then
    echo -e "${RED}Error: Not signed in to 1Password${NC}" >&2
    echo -e "${YELLOW}Sign in with: ${CYAN}eval \$(op signin)${NC}" >&2
    return 1
  fi

  return 0
}

function __op_ready() {
  local op_account="${OP_ACCOUNT:-my.1password.com}"
  command -v op &>/dev/null || return 1
  op vault list --account "$op_account" --format json >/dev/null 2>&1
}

# Extract secret var names from the secrets file
function __get_secret_vars() {
  local secret_file="$HOME/.config/zsh/vars.secret"

  if [[ ! -f "$secret_file" ]]; then
    echo -e "${RED}Error: Secret file not found: ${YELLOW}$secret_file${NC}" >&2
    return 1
  fi

  # Only list exported env vars and de-duplicate names while preserving file order.
  awk '
    /^[[:space:]]*export[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=/ {
      var = $0
      sub(/^[[:space:]]*export[[:space:]]+/, "", var)
      sub(/[[:space:]]*=.*/, "", var)
      if (!seen[var]++) {
        print var
      }
    }
  ' "$secret_file"
}

function __secret_source_file() {
  local secret_file="$HOME/.config/zsh/vars.secret"
  [[ -f "$secret_file" ]] || return 1

  local error_log
  error_log="$(mktemp)" || return 1
  local xtrace_on=0
  [[ -o xtrace ]] && xtrace_on=1
  unsetopt xtrace

  if source "$secret_file" 2>"$error_log"; then
    (( xtrace_on )) && setopt xtrace
    rm -f "$error_log"
    export SECRETS_ALREADY_LOADED=true
    export SECRETS_LOADED_AT="$(date '+%Y-%m-%d %H:%M:%S')"
    return 0
  fi

  (( xtrace_on )) && setopt xtrace
  rm -f "$error_log"
  return 1
}

# Quiet, fail-closed load for wrappers. Skip flags and an existing load are success.
function __secret_ensure_loaded() {
  if __secret_skip_requested || __secret_already_loaded; then
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
      if [[ -z "$SECRETS_ALREADY_LOADED" ]]; then
        (( quiet )) || echo -e " ${GREEN}[${CHECK_MARK}${GREEN}] Secrets already unloaded${NC}"
        return
      fi

      if (( quiet )); then
        local secret_vars
        secret_vars=$(__get_secret_vars) || return 1
        [[ -n "$secret_vars" ]] || return 1
        while IFS= read -r var; do
          [[ -n "$var" && "$var" != *"="* ]] && unset "$var"
        done <<< "$secret_vars"
        unset SECRETS_ALREADY_LOADED
        unset SECRETS_LOADED_AT
        return
      fi

      __task "Clearing secret vars..."
      local secret_vars=$(__get_secret_vars)
      if [[ -z "$secret_vars" ]]; then
        echo -e "${RED}Error: Could not detect secret variables${NC}" >&2
        _clear_task
        return 1
      fi

      local count=0
      while IFS= read -r var; do
        if [[ -n "$var" ]]; then
          if [[ "$var" =~ "=" ]]; then
            echo -e "${RED}Error: Variable name contains '=': ${YELLOW}$var${NC}" >&2
            continue
          fi
          __task "${RIGHT_ANGLE}${GREEN} Unsetting: ${YELLOW}$var"
          unset "$var" 2>/dev/null || echo -e "${RED}Failed to unset: ${YELLOW}$var${NC}" >&2
          ((count++))
        fi
      done <<< "$secret_vars"

      unset SECRETS_ALREADY_LOADED
      unset SECRETS_LOADED_AT
      _task_done
      echo -e " ${GREEN}Cleared ${count} secret variable(s)${NC}"
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
        __op_ready || return 1
        [[ -f "$HOME/.config/zsh/vars.secret" ]] || return 1
        __secret_source_file
        return
      fi

      if ! __op_check; then
        return 1
      fi

      local secret_file="$HOME/.config/zsh/vars.secret"
      if [[ ! -f "$secret_file" ]]; then
        echo -e "${RED}Error: Secret file not found: ${YELLOW}$secret_file${NC}" >&2
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
      echo -e "${RED}1Password reported errors while loading secrets. Values were not printed.${NC}"
      return 1
      ;;
  esac
}

# Load into this shell, or load once and replace the process with a command.
function with-secrets() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    print -r -- "Usage: with-secrets [command [args...]]"
    print -r -- "  no command  Load secrets into the current shell"
    print -r -- "  command     Load secrets once, then exec the command"
    print -r -- "Opt out with ORCA_SKIP_SECRETS=1 or SECRET_SKIP=1"
    return
  fi

  if ! __secret_ensure_loaded; then
    print -ru2 -- "Error: unable to load secrets"
    return 1
  fi

  (( $# == 0 )) && return 0
  exec "$@"
}

# A marked Herd shell loads secrets only for its first OMP call.
if [[ "${OMP_HERD_LOAD_SECRETS-}" == "1" ]]; then
  unset OMP_HERD_LOAD_SECRETS
  __secret_wrap_once omp OMP
fi

# Interactive Orca shells: one-shot wrap of agent launchers. Not startup autoload.
# Agent zsh -c never reaches here (.zshrc). Orca should exec: with-secrets <agent>
if [[ -o interactive && -n "${ORCA_PANE_KEY:-}" ]] && ! __secret_in_agent_shell; then
  if [[ "${OMP_HERD_LOAD_SECRETS-}" != "1" ]]; then
    for _secret_agent in omp agent codex claude opencode; do
      __secret_wrap_once "$_secret_agent"
    done
    unset _secret_agent
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
