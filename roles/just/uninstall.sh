#!/bin/bash
set -e

# Detect OS
case "$(uname -s)" in
  Darwin)
    # Uninstall via Homebrew
    if command -v brew >/dev/null 2>&1 && brew list just >/dev/null 2>&1; then
      __task "Removing just via Homebrew"
      _cmd "brew uninstall just"
      _task_done
    fi
    ;;
    
  Linux)
    # Check distribution
    if [ -f /etc/os-release ]; then
      . /etc/os-release
      case "$ID" in
        ubuntu|debian)
          if dpkg -l | grep -q "^ii  just"; then
            __task "Removing just via apt"
            _cmd "sudo apt-get remove -y just"
            _task_done
          fi
          ;;
        fedora)
          if rpm -q just >/dev/null 2>&1; then
            __task "Removing just via dnf"
            _cmd "sudo dnf remove -y just"
            _task_done
          fi
          ;;
        arch)
          if pacman -Q just >/dev/null 2>&1; then
            __task "Removing just via pacman"
            _cmd "sudo pacman -R --noconfirm just"
            _task_done
          fi
          ;;
      esac
    fi
    ;;
esac

# Remove configuration files if they exist
if [ -d "$HOME/.config/just" ]; then
  __task "Removing just configuration"
  _cmd "rm -rf $HOME/.config/just"
  _task_done
fi

echo -e "${GREEN} [✓]  ${WHITE}just has been uninstalled${NC}"
