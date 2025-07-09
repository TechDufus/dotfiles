#!/bin/bash
set -e

# Detect OS
case "$(uname -s)" in
  Darwin)
    # Uninstall via Homebrew
    if command -v brew >/dev/null 2>&1 && brew list zoxide >/dev/null 2>&1; then
      __task "Removing zoxide via Homebrew"
      _cmd "brew uninstall zoxide"
      _task_done
    fi
    ;;
    
  Linux)
    # Check distribution
    if [ -f /etc/os-release ]; then
      . /etc/os-release
      case "$ID" in
        ubuntu|debian)
          if dpkg -l | grep -q "^ii  zoxide"; then
            __task "Removing zoxide via apt"
            _cmd "sudo apt-get remove -y zoxide"
            _task_done
          fi
          ;;
        fedora)
          if rpm -q zoxide >/dev/null 2>&1; then
            __task "Removing zoxide via dnf"
            _cmd "sudo dnf remove -y zoxide"
            _task_done
          fi
          ;;
        arch)
          if pacman -Q zoxide >/dev/null 2>&1; then
            __task "Removing zoxide via pacman"
            _cmd "sudo pacman -R --noconfirm zoxide"
            _task_done
          fi
          ;;
      esac
    fi
    ;;
esac

# Remove configuration files if they exist
if [ -d "$HOME/.config/zoxide" ]; then
  __task "Removing zoxide configuration"
  _cmd "rm -rf $HOME/.config/zoxide"
  _task_done
fi

echo -e "${GREEN} [✓]  ${WHITE}zoxide has been uninstalled${NC}"
