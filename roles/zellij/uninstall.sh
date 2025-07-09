#!/bin/bash
set -e

# Detect OS
case "$(uname -s)" in
  Darwin)
    # Uninstall via Homebrew
    if command -v brew >/dev/null 2>&1 && brew list zellij >/dev/null 2>&1; then
      __task "Removing zellij via Homebrew"
      _cmd "brew uninstall zellij"
      _task_done
    fi
    ;;
    
  Linux)
    # Check distribution
    if [ -f /etc/os-release ]; then
      . /etc/os-release
      case "$ID" in
        ubuntu|debian)
          if dpkg -l | grep -q "^ii  zellij"; then
            __task "Removing zellij via apt"
            _cmd "sudo apt-get remove -y zellij"
            _task_done
          fi
          ;;
        fedora)
          if rpm -q zellij >/dev/null 2>&1; then
            __task "Removing zellij via dnf"
            _cmd "sudo dnf remove -y zellij"
            _task_done
          fi
          ;;
        arch)
          if pacman -Q zellij >/dev/null 2>&1; then
            __task "Removing zellij via pacman"
            _cmd "sudo pacman -R --noconfirm zellij"
            _task_done
          fi
          ;;
      esac
    fi
    ;;
esac

# Remove configuration files if they exist
if [ -d "$HOME/.config/zellij" ]; then
  __task "Removing zellij configuration"
  _cmd "rm -rf $HOME/.config/zellij"
  _task_done
fi

echo -e "${GREEN} [✓]  ${WHITE}zellij has been uninstalled${NC}"
