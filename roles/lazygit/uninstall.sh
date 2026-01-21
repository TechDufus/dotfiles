#!/bin/bash
set -e

# Detect OS
case "$(uname -s)" in
  Darwin)
    # Uninstall via Homebrew
    if command -v brew >/dev/null 2>&1 && brew list lazygit >/dev/null 2>&1; then
      __task "Removing lazygit via Homebrew"
      _cmd "brew uninstall lazygit"
      _task_done
    fi
    ;;
    
  Linux)
    # Check distribution
    if [ -f /etc/os-release ]; then
      . /etc/os-release
      case "$ID" in
        ubuntu|debian)
          if dpkg -l | grep -q "^ii  lazygit"; then
            __task "Removing lazygit via apt"
            _cmd "sudo apt-get remove -y lazygit"
            _task_done
          fi
          ;;
        fedora)
          if rpm -q lazygit >/dev/null 2>&1; then
            __task "Removing lazygit via dnf"
            _cmd "sudo dnf remove -y lazygit"
            _task_done
          fi
          ;;
        arch)
          if pacman -Q lazygit >/dev/null 2>&1; then
            __task "Removing lazygit via pacman"
            _cmd "sudo pacman -R --noconfirm lazygit"
            _task_done
          fi
          ;;
      esac
    fi
    ;;
esac

# Remove configuration files if they exist
if [ -d "$HOME/.config/lazygit" ]; then
  __task "Removing lazygit configuration"
  _cmd "rm -rf $HOME/.config/lazygit"
  _task_done
fi

echo -e "${GREEN} [✓]  ${WHITE}lazygit has been uninstalled${NC}"
