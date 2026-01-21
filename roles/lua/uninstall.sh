#!/bin/bash
set -e

# Detect OS
case "$(uname -s)" in
  Darwin)
    # Uninstall via Homebrew
    if command -v brew >/dev/null 2>&1 && brew list lua >/dev/null 2>&1; then
      __task "Removing lua via Homebrew"
      _cmd "brew uninstall lua"
      _task_done
    fi
    ;;
    
  Linux)
    # Check distribution
    if [ -f /etc/os-release ]; then
      . /etc/os-release
      case "$ID" in
        ubuntu|debian)
          if dpkg -l | grep -q "^ii  lua"; then
            __task "Removing lua via apt"
            _cmd "sudo apt-get remove -y lua"
            _task_done
          fi
          ;;
        fedora)
          if rpm -q lua >/dev/null 2>&1; then
            __task "Removing lua via dnf"
            _cmd "sudo dnf remove -y lua"
            _task_done
          fi
          ;;
        arch)
          if pacman -Q lua >/dev/null 2>&1; then
            __task "Removing lua via pacman"
            _cmd "sudo pacman -R --noconfirm lua"
            _task_done
          fi
          ;;
      esac
    fi
    ;;
esac

# Remove configuration files if they exist
if [ -d "$HOME/.config/lua" ]; then
  __task "Removing lua configuration"
  _cmd "rm -rf $HOME/.config/lua"
  _task_done
fi

echo -e "${GREEN} [✓]  ${WHITE}lua has been uninstalled${NC}"
