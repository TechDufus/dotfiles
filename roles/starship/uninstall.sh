#!/bin/bash
set -e

# Detect OS
case "$(uname -s)" in
  Darwin)
    # Uninstall via Homebrew
    if command -v brew >/dev/null 2>&1 && brew list starship >/dev/null 2>&1; then
      __task "Removing starship via Homebrew"
      _cmd "brew uninstall starship"
      _task_done
    fi
    ;;
    
  Linux)
    # Check distribution
    if [ -f /etc/os-release ]; then
      . /etc/os-release
      case "$ID" in
        ubuntu|debian)
          if dpkg -l | grep -q "^ii  starship"; then
            __task "Removing starship via apt"
            _cmd "sudo apt-get remove -y starship"
            _task_done
          fi
          ;;
        fedora)
          if rpm -q starship >/dev/null 2>&1; then
            __task "Removing starship via dnf"
            _cmd "sudo dnf remove -y starship"
            _task_done
          fi
          ;;
        arch)
          if pacman -Q starship >/dev/null 2>&1; then
            __task "Removing starship via pacman"
            _cmd "sudo pacman -R --noconfirm starship"
            _task_done
          fi
          ;;
      esac
    fi
    ;;
esac

# Remove configuration files if they exist
if [ -d "$HOME/.config/starship.toml" ]; then
  __task "Removing starship configuration"
  _cmd "rm -rf $HOME/.config/starship.toml"
  _task_done
fi

echo -e "${GREEN} [✓]  ${WHITE}starship has been uninstalled${NC}"
