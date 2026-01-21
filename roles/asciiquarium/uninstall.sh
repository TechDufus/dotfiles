#!/bin/bash
set -e

# Detect OS
case "$(uname -s)" in
  Darwin)
    # Uninstall via Homebrew
    if command -v brew >/dev/null 2>&1 && brew list asciiquarium >/dev/null 2>&1; then
      __task "Removing asciiquarium via Homebrew"
      _cmd "brew uninstall asciiquarium"
      _task_done
    fi
    ;;
    
  Linux)
    # Check distribution
    if [ -f /etc/os-release ]; then
      . /etc/os-release
      case "$ID" in
        ubuntu|debian)
          if dpkg -l | grep -q "^ii  asciiquarium"; then
            __task "Removing asciiquarium via apt"
            _cmd "sudo apt-get remove -y asciiquarium"
            _task_done
          fi
          ;;
        fedora)
          if rpm -q asciiquarium >/dev/null 2>&1; then
            __task "Removing asciiquarium via dnf"
            _cmd "sudo dnf remove -y asciiquarium"
            _task_done
          fi
          ;;
        arch)
          if pacman -Q asciiquarium >/dev/null 2>&1; then
            __task "Removing asciiquarium via pacman"
            _cmd "sudo pacman -R --noconfirm asciiquarium"
            _task_done
          fi
          ;;
      esac
    fi
    ;;
esac

# Remove configuration files if they exist
if [ -d "$HOME/.config/asciiquarium" ]; then
  __task "Removing asciiquarium configuration"
  _cmd "rm -rf $HOME/.config/asciiquarium"
  _task_done
fi

echo -e "${GREEN} [✓]  ${WHITE}asciiquarium has been uninstalled${NC}"
