#!/bin/bash
set -e

# Detect OS
case "$(uname -s)" in
  Darwin)
    # Uninstall via Homebrew
    if command -v brew >/dev/null 2>&1 && brew list tldr >/dev/null 2>&1; then
      __task "Removing tldr via Homebrew"
      _cmd "brew uninstall tldr"
      _task_done
    fi
    ;;
    
  Linux)
    # Check distribution
    if [ -f /etc/os-release ]; then
      . /etc/os-release
      case "$ID" in
        ubuntu|debian)
          if dpkg -l | grep -q "^ii  tldr"; then
            __task "Removing tldr via apt"
            _cmd "sudo apt-get remove -y tldr"
            _task_done
          fi
          ;;
        fedora)
          if rpm -q tldr >/dev/null 2>&1; then
            __task "Removing tldr via dnf"
            _cmd "sudo dnf remove -y tldr"
            _task_done
          fi
          ;;
        arch)
          if pacman -Q tldr >/dev/null 2>&1; then
            __task "Removing tldr via pacman"
            _cmd "sudo pacman -R --noconfirm tldr"
            _task_done
          fi
          ;;
      esac
    fi
    ;;
esac

# Remove configuration files if they exist
if [ -d "$HOME/.cache/tldr" ]; then
  __task "Removing tldr configuration"
  _cmd "rm -rf $HOME/.cache/tldr"
  _task_done
fi

echo -e "${GREEN} [✓]  ${WHITE}tldr has been uninstalled${NC}"
