#!/bin/bash
set -e

# Detect OS
case "$(uname -s)" in
  Darwin)
    # Uninstall via Homebrew
    if command -v brew >/dev/null 2>&1 && brew list terraform >/dev/null 2>&1; then
      __task "Removing terraform via Homebrew"
      _cmd "brew uninstall terraform"
      _task_done
    fi
    ;;
    
  Linux)
    # Check distribution
    if [ -f /etc/os-release ]; then
      . /etc/os-release
      case "$ID" in
        ubuntu|debian)
          if dpkg -l | grep -q "^ii  terraform"; then
            __task "Removing terraform via apt"
            _cmd "sudo apt-get remove -y terraform"
            _task_done
          fi
          ;;
        fedora)
          if rpm -q terraform >/dev/null 2>&1; then
            __task "Removing terraform via dnf"
            _cmd "sudo dnf remove -y terraform"
            _task_done
          fi
          ;;
        arch)
          if pacman -Q terraform >/dev/null 2>&1; then
            __task "Removing terraform via pacman"
            _cmd "sudo pacman -R --noconfirm terraform"
            _task_done
          fi
          ;;
      esac
    fi
    ;;
esac

# Remove configuration files if they exist
if [ -d "$HOME/.config/terraform" ]; then
  __task "Removing terraform configuration"
  _cmd "rm -rf $HOME/.config/terraform"
  _task_done
fi

echo -e "${GREEN} [✓]  ${WHITE}terraform has been uninstalled${NC}"
