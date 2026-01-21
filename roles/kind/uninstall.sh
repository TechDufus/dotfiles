#!/bin/bash
set -e

# Detect OS
case "$(uname -s)" in
  Darwin)
    # Uninstall via Homebrew
    if command -v brew >/dev/null 2>&1 && brew list kind >/dev/null 2>&1; then
      __task "Removing kind via Homebrew"
      _cmd "brew uninstall kind"
      _task_done
    fi
    ;;
    
  Linux)
    # Check distribution
    if [ -f /etc/os-release ]; then
      . /etc/os-release
      case "$ID" in
        ubuntu|debian)
          if dpkg -l | grep -q "^ii  kind"; then
            __task "Removing kind via apt"
            _cmd "sudo apt-get remove -y kind"
            _task_done
          fi
          ;;
        fedora)
          if rpm -q kind >/dev/null 2>&1; then
            __task "Removing kind via dnf"
            _cmd "sudo dnf remove -y kind"
            _task_done
          fi
          ;;
        arch)
          if pacman -Q kind >/dev/null 2>&1; then
            __task "Removing kind via pacman"
            _cmd "sudo pacman -R --noconfirm kind"
            _task_done
          fi
          ;;
      esac
    fi
    ;;
esac

# Remove configuration files if they exist
if [ -d "$HOME/.config/kind" ]; then
  __task "Removing kind configuration"
  _cmd "rm -rf $HOME/.config/kind"
  _task_done
fi

echo -e "${GREEN} [✓]  ${WHITE}kind has been uninstalled${NC}"
