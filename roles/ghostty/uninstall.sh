#!/bin/bash
set -e

# macOS only - Ghostty is currently macOS exclusive
case "$(uname -s)" in
  Darwin)
    # Close Ghostty if running
    if pgrep -x "Ghostty" > /dev/null; then
      __task "Closing Ghostty"
      _cmd "osascript -e 'quit app \"Ghostty\"'"
      sleep 2
      _task_done
    fi
    
    # Uninstall Ghostty.app
    if [ -d "/Applications/Ghostty.app" ]; then
      __task "Removing Ghostty application"
      _cmd "sudo rm -rf /Applications/Ghostty.app"
      _task_done
    fi
    
    # Uninstall via Homebrew (if available as cask)
    if command -v brew >/dev/null 2>&1 && brew list --cask ghostty >/dev/null 2>&1; then
      __task "Removing Ghostty via Homebrew"
      _cmd "brew uninstall --cask ghostty"
      _task_done
    fi
    
    # Remove configuration
    if [ -f "$HOME/.config/ghostty/config" ]; then
      __task "Removing Ghostty configuration"
      _cmd "rm -rf $HOME/.config/ghostty"
      _task_done
    fi
    
    # Remove support files
    if [ -d "$HOME/Library/Application Support/com.mitchellh.ghostty" ]; then
      __task "Removing Ghostty support files"
      _cmd "rm -rf '$HOME/Library/Application Support/com.mitchellh.ghostty'"
      _task_done
    fi
    ;;
    
  *)
    echo -e "${YELLOW} [!]  ${WHITE}Ghostty is currently only available for macOS${NC}"
    ;;
esac

echo -e "${GREEN} [✓]  ${WHITE}Ghostty has been uninstalled${NC}"