#!/bin/bash
set -e

# Detect OS
case "$(uname -s)" in
  Darwin)
    # Uninstall via Homebrew
    if command -v brew >/dev/null 2>&1 && brew list bat >/dev/null 2>&1; then
      __task "Removing bat via Homebrew"
      _cmd "brew uninstall bat"
      _task_done
    fi
    ;;
    
  Linux)
    # Check distribution
    if [ -f /etc/os-release ]; then
      . /etc/os-release
      case "$ID" in
        ubuntu|debian)
          if dpkg -l | grep -q "^ii  bat"; then
            __task "Removing bat via apt"
            _cmd "sudo apt-get remove -y bat"
            _task_done
          fi
          ;;
        fedora)
          if rpm -q bat >/dev/null 2>&1; then
            __task "Removing bat via dnf"
            _cmd "sudo dnf remove -y bat"
            _task_done
          fi
          ;;
        arch)
          if pacman -Q bat >/dev/null 2>&1; then
            __task "Removing bat via pacman"
            _cmd "sudo pacman -R --noconfirm bat"
            _task_done
          fi
          ;;
      esac
    fi
    ;;
esac

# Remove configuration files if they exist
if [ -f "$HOME/.config/bat/config" ]; then
  __task "Removing bat configuration"
  _cmd "rm -rf $HOME/.config/bat"
  _task_done
fi

echo -e "${GREEN} [✓]  ${WHITE}bat has been uninstalled${NC}"