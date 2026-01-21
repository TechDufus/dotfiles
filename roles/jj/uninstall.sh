#!/bin/bash
set -e

# Detect OS
case "$(uname -s)" in
  Darwin)
    # Uninstall via Homebrew
    if command -v brew >/dev/null 2>&1 && brew list jj >/dev/null 2>&1; then
      __task "Removing jj via Homebrew"
      _cmd "brew uninstall jj"
      _task_done
    fi
    ;;
    
  Linux)
    # Check distribution
    if [ -f /etc/os-release ]; then
      . /etc/os-release
      case "$ID" in
        ubuntu|debian)
          if dpkg -l | grep -q "^ii  jj"; then
            __task "Removing jj via apt"
            _cmd "sudo apt-get remove -y jj"
            _task_done
          fi
          ;;
        fedora)
          if rpm -q jj >/dev/null 2>&1; then
            __task "Removing jj via dnf"
            _cmd "sudo dnf remove -y jj"
            _task_done
          fi
          ;;
        arch)
          if pacman -Q jj >/dev/null 2>&1; then
            __task "Removing jj via pacman"
            _cmd "sudo pacman -R --noconfirm jj"
            _task_done
          fi
          ;;
      esac
    fi
    ;;
esac

# Remove configuration files if they exist
if [ -d "$HOME/.config/jj" ]; then
  __task "Removing jj configuration"
  _cmd "rm -rf $HOME/.config/jj"
  _task_done
fi

echo -e "${GREEN} [✓]  ${WHITE}jj has been uninstalled${NC}"
