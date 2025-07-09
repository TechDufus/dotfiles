#!/bin/bash
set -e

# Detect OS
case "$(uname -s)" in
  Darwin)
    # Uninstall via Homebrew
    if command -v brew >/dev/null 2>&1 && brew list btop >/dev/null 2>&1; then
      __task "Removing btop via Homebrew"
      _cmd "brew uninstall btop"
      _task_done
    fi
    ;;
    
  Linux)
    # Check distribution
    if [ -f /etc/os-release ]; then
      . /etc/os-release
      case "$ID" in
        ubuntu|debian)
          if dpkg -l | grep -q "^ii  btop"; then
            __task "Removing btop via apt"
            _cmd "sudo apt-get remove -y btop"
            _task_done
          fi
          ;;
        fedora)
          if rpm -q btop >/dev/null 2>&1; then
            __task "Removing btop via dnf"
            _cmd "sudo dnf remove -y btop"
            _task_done
          fi
          ;;
        arch)
          if pacman -Q btop >/dev/null 2>&1; then
            __task "Removing btop via pacman"
            _cmd "sudo pacman -R --noconfirm btop"
            _task_done
          fi
          ;;
      esac
    fi
    ;;
esac

# Remove configuration files if they exist
if [ -d "$HOME/.config/btop" ]; then
  __task "Removing btop configuration"
  _cmd "rm -rf $HOME/.config/btop"
  _task_done
fi

echo -e "${GREEN} [✓]  ${WHITE}btop has been uninstalled${NC}"
