#!/bin/bash
set -e

echo -e "${YELLOW} [!]  ${WHITE}This will remove Podman and all containers/images${NC}"
read -p "$(echo -e ${YELLOW})Continue with Podman removal? (y/N) ${NC}" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo -e "${YELLOW} [!]  ${WHITE}Podman removal cancelled${NC}"
  exit 0
fi

# Detect OS
case "$(uname -s)" in
  Darwin)
    # Stop Podman machine if running
    if command -v podman >/dev/null 2>&1 && podman machine list 2>/dev/null | grep -q "Currently running"; then
      __task "Stopping Podman machine"
      _cmd "podman machine stop"
      _task_done
    fi
    
    # Remove Podman machine
    if command -v podman >/dev/null 2>&1 && podman machine list 2>/dev/null | grep -q "podman-machine-default"; then
      __task "Removing Podman machine"
      _cmd "podman machine rm -f"
      _task_done
    fi
    
    # Uninstall via Homebrew
    if command -v brew >/dev/null 2>&1 && brew list podman >/dev/null 2>&1; then
      __task "Removing Podman via Homebrew"
      _cmd "brew uninstall podman"
      _task_done
    fi
    
    # Uninstall Podman Desktop if installed
    if [ -d "/Applications/Podman Desktop.app" ]; then
      __task "Removing Podman Desktop"
      _cmd "sudo rm -rf '/Applications/Podman Desktop.app'"
      _task_done
    fi
    ;;
    
  Linux)
    # Check distribution
    if [ -f /etc/os-release ]; then
      . /etc/os-release
      case "$ID" in
        ubuntu|debian)
          if dpkg -l | grep -q "^ii  podman"; then
            __task "Removing Podman via apt"
            _cmd "sudo apt-get remove -y podman"
            _task_done
          fi
          ;;
        fedora)
          if rpm -q podman >/dev/null 2>&1; then
            __task "Removing Podman via dnf"
            _cmd "sudo dnf remove -y podman"
            _task_done
          fi
          ;;
        arch)
          if pacman -Q podman >/dev/null 2>&1; then
            __task "Removing Podman via pacman"
            _cmd "sudo pacman -R --noconfirm podman"
            _task_done
          fi
          ;;
      esac
    fi
    ;;
esac

# Remove Podman configuration
if [ -d "$HOME/.config/containers" ]; then
  __task "Removing Podman configuration"
  _cmd "rm -rf $HOME/.config/containers"
  _task_done
fi

if [ -d "$HOME/.local/share/containers" ]; then
  __task "Removing Podman data"
  _cmd "rm -rf $HOME/.local/share/containers"
  _task_done
fi

echo -e "${GREEN} [✓]  ${WHITE}Podman has been uninstalled${NC}"