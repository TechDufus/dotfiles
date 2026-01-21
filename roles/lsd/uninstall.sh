#!/bin/bash
set -e

# Detect OS
case "$(uname -s)" in
  Darwin)
    # Uninstall via Homebrew
    if command -v brew >/dev/null 2>&1 && brew list lsd >/dev/null 2>&1; then
      __task "Removing lsd via Homebrew"
      _cmd "brew uninstall lsd"
      _task_done
    fi
    ;;
    
  Linux)
    # Check distribution
    if [ -f /etc/os-release ]; then
      . /etc/os-release
      case "$ID" in
        ubuntu|debian)
          if dpkg -l | grep -q "^ii  lsd"; then
            __task "Removing lsd via apt"
            _cmd "sudo apt-get remove -y lsd"
            _task_done
          fi
          ;;
        fedora)
          if rpm -q lsd >/dev/null 2>&1; then
            __task "Removing lsd via dnf"
            _cmd "sudo dnf remove -y lsd"
            _task_done
          fi
          ;;
        arch)
          if pacman -Q lsd >/dev/null 2>&1; then
            __task "Removing lsd via pacman"
            _cmd "sudo pacman -R --noconfirm lsd"
            _task_done
          fi
          ;;
      esac
    fi
    ;;
esac

# Remove configuration files if they exist
if [ -d "$HOME/.config/lsd" ]; then
  __task "Removing lsd configuration"
  _cmd "rm -rf $HOME/.config/lsd"
  _task_done
fi

echo -e "${GREEN} [✓]  ${WHITE}lsd has been uninstalled${NC}"
