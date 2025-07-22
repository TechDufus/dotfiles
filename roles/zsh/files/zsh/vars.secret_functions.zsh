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
    echo -e "${YELLOW}Install with: ${CYAN}curl -sS https://downloads.1password.com/linux/edge/op.zip | gunzip -c > op && sudo mv op /usr/local/bin/op && sudo chmod +x /usr/local/bin/op${NC}" >&2
    return 1
  fi

  # Check if signed in
  if ! op account list &>/dev/null; then
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

  # Extract export statements, handling both simple and command substitution exports
  # Also handle non-export variable assignments like MY_ACCOUNT
  # Use awk for more reliable cross-platform parsing
  awk -F'=' '/^[[:space:]]*(export[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*=/ {
    # Remove leading whitespace and "export" keyword
    gsub(/^[[:space:]]*(export[[:space:]]+)?/, "", $1)
    print $1
  }' "$secret_file"
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
      
      # Create a temporary file to capture errors
      local error_log=$(mktemp)
      
      # Source the secrets file and capture any errors
      if source "$secret_file" 2>"$error_log"; then
        if [[ -s "$error_log" ]]; then
          # There were warnings but it succeeded
          _task_done
          echo -e " ${YELLOW}[${WARNING}${YELLOW}] Loaded with warnings:${NC}"
          while IFS= read -r line; do
            echo -e "   ${YELLOW}${line}${NC}"
          done < "$error_log"
        else
          # Clean success
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
        # Failed to source
        __task "${X_MARK}${RED} Failed to load secrets"
        _clear_task
        if [[ -s "$error_log" ]]; then
          echo -e "${RED}Errors:${NC}"
          while IFS= read -r line; do
            echo -e "  ${RED}${line}${NC}"
          done < "$error_log"
        fi
        rm -f "$error_log"
        return 1
      fi
      
      rm -f "$error_log"
      return
      ;;
  esac
}

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