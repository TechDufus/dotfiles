#!/bin/bash
set -e

# Detect OS
case "$(uname -s)" in
  Darwin)
    # Uninstall Alacritty.app
    if [ -d "/Applications/Alacritty.app" ]; then
      __task "Removing Alacritty application"
      _cmd "sudo rm -rf /Applications/Alacritty.app"
      _task_done
    fi
    
    # Uninstall via Homebrew
    if command -v brew >/dev/null 2>&1 && brew list --cask alacritty >/dev/null 2>&1; then
      __task "Removing Alacritty via Homebrew"
      _cmd "brew uninstall --cask alacritty"
      _task_done
    fi
    ;;
    
  Linux)
    # Check distribution
    if [ -f /etc/os-release ]; then
      . /etc/os-release
      case "$ID" in
        ubuntu|debian)
          if dpkg -l | grep -q "^ii  alacritty"; then
            __task "Removing Alacritty via apt"
            _cmd "sudo apt-get remove -y alacritty"
            _task_done
          fi
          ;;
        fedora)
          if rpm -q alacritty >/dev/null 2>&1; then
            __task "Removing Alacritty via dnf"
            _cmd "sudo dnf remove -y alacritty"
            _task_done
          fi
          ;;
        arch)
          if pacman -Q alacritty >/dev/null 2>&1; then
            __task "Removing Alacritty via pacman"
            _cmd "sudo pacman -R --noconfirm alacritty"
            _task_done
          fi
          ;;
      esac
    fi
    
    # Check for cargo installation
    if [ -f "$HOME/.cargo/bin/alacritty" ]; then
      __task "Removing Alacritty installed via cargo"
      _cmd "cargo uninstall alacritty"
      _task_done
    fi
    ;;
esac

# Remove configuration files
if [ -d "$HOME/.config/alacritty" ]; then
  __task "Removing Alacritty configuration"
  _cmd "rm -rf $HOME/.config/alacritty"
  _task_done
fi

echo -e "${GREEN} [✓]  ${WHITE}Alacritty has been uninstalled${NC}"