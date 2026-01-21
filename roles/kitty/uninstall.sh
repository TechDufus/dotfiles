#!/bin/bash
set -e

# Detect OS
case "$(uname -s)" in
  Darwin)
    # Close Kitty if running
    if pgrep -x "kitty" > /dev/null; then
      __task "Closing Kitty"
      _cmd "osascript -e 'quit app \"kitty\"'"
      sleep 2
      _task_done
    fi
    
    # Uninstall Kitty.app
    if [ -d "/Applications/kitty.app" ]; then
      __task "Removing Kitty application"
      _cmd "sudo rm -rf /Applications/kitty.app"
      _task_done
    fi
    
    # Uninstall via Homebrew
    if command -v brew >/dev/null 2>&1 && brew list --cask kitty >/dev/null 2>&1; then
      __task "Removing Kitty via Homebrew"
      _cmd "brew uninstall --cask kitty"
      _task_done
    fi
    ;;
    
  Linux)
    # Check distribution
    if [ -f /etc/os-release ]; then
      . /etc/os-release
      case "$ID" in
        ubuntu|debian)
          if dpkg -l | grep -q "^ii  kitty"; then
            __task "Removing Kitty via apt"
            _cmd "sudo apt-get remove -y kitty"
            _task_done
          fi
          ;;
        fedora)
          if rpm -q kitty >/dev/null 2>&1; then
            __task "Removing Kitty via dnf"
            _cmd "sudo dnf remove -y kitty"
            _task_done
          fi
          ;;
        arch)
          if pacman -Q kitty >/dev/null 2>&1; then
            __task "Removing Kitty via pacman"
            _cmd "sudo pacman -R --noconfirm kitty"
            _task_done
          fi
          ;;
      esac
    fi
    ;;
esac

# Remove configuration files
if [ -d "$HOME/.config/kitty" ]; then
  __task "Removing Kitty configuration"
  _cmd "rm -rf $HOME/.config/kitty"
  _task_done
fi

echo -e "${GREEN} [✓]  ${WHITE}Kitty has been uninstalled${NC}"