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
  echo -e "  ${CYAN}-h, --help${NC}     Display this help message"
  echo ""
  echo -e "${YELLOW}Examples:${NC}"
  echo -e "  ${CYAN}secret${NC}         # Load secret vars"
  echo -e "  ${CYAN}secret -c${NC}      # Clear secret vars"
  echo -e "  ${CYAN}secret -r${NC}      # Reload secret vars"
  echo -e "  ${CYAN}secret -l${NC}      # List loaded secret vars"
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

function secret() {
  local action="load"
  
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
      if [[ -n "$SECRETS_ALREADY_LOADED" ]] && [[ "$SECRETS_ALREADY_LOADED" = true ]]; then
        echo -e " ${GREEN}[${CHECK_MARK}${GREEN}] Secrets are loaded${NC}"
        # Show timestamp if available
        if [[ -n "$SECRETS_LOADED_AT" ]]; then
          echo -e " ${CYAN}   Loaded at: ${YELLOW}$SECRETS_LOADED_AT${NC}"
        fi
      else
        echo -e " ${YELLOW}[${WARNING}${YELLOW}] Secrets are not loaded${NC}"
      fi
      return
      ;;
      
    list)
      if [[ -z "$SECRETS_ALREADY_LOADED" ]] || [[ "$SECRETS_ALREADY_LOADED" != true ]]; then
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
      # Already unloaded
      if [[ -z "$SECRETS_ALREADY_LOADED" ]]; then
        echo -e " ${GREEN}[${CHECK_MARK}${GREEN}] Secrets already unloaded${NC}"
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
          # Debug: show what we're trying to unset
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
      __task "${ARROW} ${YELLOW}Reloading secrets..."
      _task_done
      secret --clear && secret
      return
      ;;
      
    load)
      # Already loaded
      if [[ -n "$SECRETS_ALREADY_LOADED" ]] && [[ "$SECRETS_ALREADY_LOADED" = true ]]; then
        echo -e " ${GREEN}[${CHECK_MARK}${GREEN}] Secrets already loaded${NC}"
        return
      fi
      
      # Check prerequisites
      if ! __op_check; then
        return 1
      fi
      
      local secret_file="$HOME/.config/zsh/vars.secret"
      if [[ ! -f "$secret_file" ]]; then
        echo -e "${RED}Error: Secret file not found: ${YELLOW}$secret_file${NC}" >&2
        return 1
      fi
      
      __task "Loading secrets..."

      local error_log
      error_log="$(mktemp)"
      local xtrace_on=0
      [[ -o xtrace ]] && xtrace_on=1
      unsetopt xtrace

      if source "$secret_file" 2>"$error_log"; then
        (( xtrace_on )) && setopt xtrace
        if [[ -s "$error_log" ]]; then
          _task_done
          echo -e " ${YELLOW}[${WARNING}${YELLOW}] Loaded with 1Password warnings (secret values were not printed).${NC}"
        else
          _task_done
        fi
        
        export SECRETS_ALREADY_LOADED=true
        export SECRETS_LOADED_AT=$(date '+%Y-%m-%d %H:%M:%S')
        
        # Count loaded vars
        local vars=$(__get_secret_vars)
        local count=0
        if [[ -n "$vars" ]]; then
          while IFS= read -r var; do
            [[ -n "${(P)var}" ]] && ((count++))
          done <<< "$vars"
        fi
        echo -e " ${GREEN}Loaded ${count} secret variable(s)${NC}"
      else
        (( xtrace_on )) && setopt xtrace
        __task "${X_MARK}${RED} Failed to load secrets"
        _clear_task
        if [[ -s "$error_log" ]]; then
          echo -e "${RED}1Password reported errors while loading secrets. Values were not printed.${NC}"
        fi
        rm -f "$error_log"
        return 1
      fi
      
      rm -f "$error_log"
      return
      ;;
  esac
}

# A marked Herd shell loads secrets only for its first OMP call.
if [[ "${OMP_HERD_LOAD_SECRETS-}" == "1" ]]; then
  unset OMP_HERD_LOAD_SECRETS

  function omp() {
    local canonical_omp

    if ! secret >/dev/null 2>&1; then
      print -ru2 -- "Error: unable to load secrets; OMP was not started"
      return 1
    fi

    canonical_omp="$(whence -p omp)"
    if [[ -z "$canonical_omp" ]]; then
      print -ru2 -- "Error: OMP was not found after loading secrets"
      return 1
    fi
    unfunction omp

    "$canonical_omp" "$@"
  }
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
      '-h:Display help'
      '--help:Display help'
    )
    _describe 'secret options' options
  }
  compdef _secret secret
fi
