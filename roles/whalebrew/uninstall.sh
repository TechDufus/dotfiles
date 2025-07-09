#!/bin/bash
set -e

# Detect OS
case "$(uname -s)" in
  Darwin)
    # Remove whalebrew packages first
    if command -v whalebrew >/dev/null 2>&1; then
      __task "Removing whalebrew packages"
      if whalebrew list 2>/dev/null | xargs -I {} whalebrew uninstall {} 2>/dev/null; then
        _task_done
      else
        _task_done  # Still mark as done even if no packages
      fi
    fi
    
    # Uninstall via Homebrew
    if command -v brew >/dev/null 2>&1; then
      __task "Removing whalebrew via Homebrew"
      _cmd "brew uninstall whalebrew"
      _task_done
    fi
    
    # Clean up directories
    if [ -d "/opt/whalebrew" ]; then
      __task "Removing /opt/whalebrew directory"
      _cmd "sudo rm -rf /opt/whalebrew"
      _task_done
    fi
    ;;
    
  Linux)
    echo -e "${YELLOW} [!]  ${WHITE}Linux uninstall not implemented for whalebrew${NC}"
    ;;
esac