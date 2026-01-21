#!/bin/bash
set -e

# Detect OS
case "$(uname -s)" in
  Darwin)
    # Uninstall via Homebrew
    if command -v brew >/dev/null 2>&1 && brew list helm >/dev/null 2>&1; then
      __task "Removing helm via Homebrew"
      _cmd "brew uninstall helm"
      _task_done
    fi
    ;;
    
  Linux)
    # Check distribution
    if [ -f /etc/os-release ]; then
      . /etc/os-release
      case "$ID" in
        ubuntu|debian)
          if dpkg -l | grep -q "^ii  helm"; then
            __task "Removing helm via apt"
            _cmd "sudo apt-get remove -y helm"
            _task_done
          fi
          ;;
        fedora)
          if rpm -q helm >/dev/null 2>&1; then
            __task "Removing helm via dnf"
            _cmd "sudo dnf remove -y helm"
            _task_done
          fi
          ;;
        arch)
          if pacman -Q helm >/dev/null 2>&1; then
            __task "Removing helm via pacman"
            _cmd "sudo pacman -R --noconfirm helm"
            _task_done
          fi
          ;;
      esac
    fi
    ;;
esac

# Remove configuration files if they exist
if [ -d "$HOME/.config/helm" ]; then
  __task "Removing helm configuration"
  _cmd "rm -rf $HOME/.config/helm"
  _task_done
fi

echo -e "${GREEN} [✓]  ${WHITE}helm has been uninstalled${NC}"
