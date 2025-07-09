#!/bin/bash
set -e

echo -e "${YELLOW} [!]  ${WHITE}This will remove Docker and all containers/images${NC}"
echo -e "${YELLOW}      ${WHITE}Make sure to backup any important data first!${NC}"
read -p "$(echo -e ${YELLOW})Continue with Docker removal? (y/N) ${NC}" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo -e "${YELLOW} [!]  ${WHITE}Docker removal cancelled${NC}"
  exit 0
fi

# Detect OS
case "$(uname -s)" in
  Darwin)
    # Stop Docker Desktop if running
    if pgrep -x "Docker" > /dev/null; then
      __task "Stopping Docker Desktop"
      _cmd "osascript -e 'quit app \"Docker\"'"
      sleep 2
      _task_done
    fi
    
    # Uninstall Docker Desktop
    if [ -d "/Applications/Docker.app" ]; then
      __task "Removing Docker Desktop application"
      _cmd "sudo rm -rf /Applications/Docker.app"
      _task_done
    fi
    
    # Remove Docker CLI via Homebrew
    if command -v brew >/dev/null 2>&1 && brew list docker >/dev/null 2>&1; then
      __task "Removing docker CLI via Homebrew"
      _cmd "brew uninstall docker"
      _task_done
    fi
    
    # Clean up Docker data
    if [ -d "$HOME/Library/Containers/com.docker.docker" ]; then
      __task "Removing Docker Desktop data"
      _cmd "rm -rf $HOME/Library/Containers/com.docker.docker"
      _cmd "rm -rf $HOME/Library/Application\ Support/Docker\ Desktop"
      _cmd "rm -rf $HOME/Library/Group\ Containers/group.com.docker"
      _cmd "rm -rf $HOME/Library/Preferences/com.docker.docker.plist"
      _cmd "rm -rf $HOME/.docker"
      _task_done
    fi
    ;;
    
  Linux)
    # Stop Docker service
    if systemctl is-active --quiet docker; then
      __task "Stopping Docker service"
      _cmd "sudo systemctl stop docker"
      _cmd "sudo systemctl disable docker"
      _task_done
    fi
    
    # Check distribution
    if [ -f /etc/os-release ]; then
      . /etc/os-release
      case "$ID" in
        ubuntu|debian)
          if dpkg -l | grep -q "docker-ce\|docker.io"; then
            __task "Removing Docker via apt"
            _cmd "sudo apt-get remove -y docker docker-engine docker.io containerd runc docker-ce docker-ce-cli"
            _cmd "sudo apt-get purge -y docker-ce docker-ce-cli containerd.io"
            _task_done
          fi
          ;;
        fedora)
          if rpm -q docker-ce >/dev/null 2>&1; then
            __task "Removing Docker via dnf"
            _cmd "sudo dnf remove -y docker-ce docker-ce-cli containerd.io"
            _task_done
          fi
          ;;
        arch)
          if pacman -Q docker >/dev/null 2>&1; then
            __task "Removing Docker via pacman"
            _cmd "sudo pacman -R --noconfirm docker"
            _task_done
          fi
          ;;
      esac
    fi
    
    # Remove Docker data
    if [ -d "/var/lib/docker" ]; then
      __task "Removing Docker data (requires sudo)"
      _cmd "sudo rm -rf /var/lib/docker"
      _cmd "sudo rm -rf /var/lib/containerd"
      _task_done
    fi
    
    # Remove Docker group
    if getent group docker >/dev/null 2>&1; then
      __task "Removing docker group"
      _cmd "sudo groupdel docker"
      _task_done
    fi
    ;;
esac

# Remove docker config
if [ -d "$HOME/.docker" ]; then
  __task "Removing Docker configuration"
  _cmd "rm -rf $HOME/.docker"
  _task_done
fi

echo -e "${GREEN} [✓]  ${WHITE}Docker has been uninstalled${NC}"
echo -e "${YELLOW} [!]  ${WHITE}You may need to restart your system for all changes to take effect${NC}"