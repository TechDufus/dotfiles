#!/bin/bash
set -e

# Detect OS
case "$(uname -s)" in
  Darwin)
    # Uninstall via Homebrew
    if command -v brew >/dev/null 2>&1 && brew list tmate >/dev/null 2>&1; then
      __task "Removing tmate via Homebrew"
      _cmd "brew uninstall tmate"
      _task_done
    fi
    ;;
    
  Linux)
    # Check distribution
    if [ -f /etc/os-release ]; then
      . /etc/os-release
      case "$ID" in
        ubuntu|debian)
          if dpkg -l | grep -q "^ii  tmate"; then
            __task "Removing tmate via apt"
            _cmd "sudo apt-get remove -y tmate"
            _task_done
          fi
          ;;
        fedora)
          if rpm -q tmate >/dev/null 2>&1; then
            __task "Removing tmate via dnf"
            _cmd "sudo dnf remove -y tmate"
            _task_done
          fi
          ;;
        arch)
          if pacman -Q tmate >/dev/null 2>&1; then
            __task "Removing tmate via pacman"
            _cmd "sudo pacman -R --noconfirm tmate"
            _task_done
          fi
          ;;
      esac
    fi
    ;;
esac

# Remove configuration files if they exist
if [ -d "$HOME/.config/tmate" ]; then
  __task "Removing tmate configuration"
  _cmd "rm -rf $HOME/.config/tmate"
  _task_done
fi

echo -e "${GREEN} [✓]  ${WHITE}tmate has been uninstalled${NC}"
