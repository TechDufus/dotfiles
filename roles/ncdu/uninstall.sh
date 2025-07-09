#!/bin/bash
set -e

# Detect OS
case "$(uname -s)" in
  Darwin)
    # Uninstall via Homebrew
    if command -v brew >/dev/null 2>&1 && brew list ncdu >/dev/null 2>&1; then
      __task "Removing ncdu via Homebrew"
      _cmd "brew uninstall ncdu"
      _task_done
    fi
    ;;
    
  Linux)
    # Check distribution
    if [ -f /etc/os-release ]; then
      . /etc/os-release
      case "$ID" in
        ubuntu|debian)
          if dpkg -l | grep -q "^ii  ncdu"; then
            __task "Removing ncdu via apt"
            _cmd "sudo apt-get remove -y ncdu"
            _task_done
          fi
          ;;
        fedora)
          if rpm -q ncdu >/dev/null 2>&1; then
            __task "Removing ncdu via dnf"
            _cmd "sudo dnf remove -y ncdu"
            _task_done
          fi
          ;;
        arch)
          if pacman -Q ncdu >/dev/null 2>&1; then
            __task "Removing ncdu via pacman"
            _cmd "sudo pacman -R --noconfirm ncdu"
            _task_done
          fi
          ;;
      esac
    fi
    ;;
esac

# Remove configuration files if they exist
if [ -d "$HOME/.config/ncdu" ]; then
  __task "Removing ncdu configuration"
  _cmd "rm -rf $HOME/.config/ncdu"
  _task_done
fi

echo -e "${GREEN} [✓]  ${WHITE}ncdu has been uninstalled${NC}"
