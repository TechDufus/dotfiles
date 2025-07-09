#!/bin/bash
set -e

# Detect OS
case "$(uname -s)" in
  Darwin)
    # Uninstall via Homebrew
    if command -v brew >/dev/null 2>&1 && brew list go >/dev/null 2>&1; then
      __task "Removing Go via Homebrew"
      _cmd "brew uninstall go"
      _task_done
    fi
    ;;
    
  Linux)
    # Check for manual installation in /usr/local/go
    if [ -d "/usr/local/go" ]; then
      __task "Removing Go from /usr/local"
      _cmd "sudo rm -rf /usr/local/go"
      _task_done
    fi
    
    # Check distribution package managers
    if [ -f /etc/os-release ]; then
      . /etc/os-release
      case "$ID" in
        ubuntu|debian)
          if dpkg -l | grep -q "^ii  golang-go"; then
            __task "Removing Go via apt"
            _cmd "sudo apt-get remove -y golang-go"
            _task_done
          fi
          ;;
        fedora)
          if rpm -q golang >/dev/null 2>&1; then
            __task "Removing Go via dnf"
            _cmd "sudo dnf remove -y golang"
            _task_done
          fi
          ;;
        arch)
          if pacman -Q go >/dev/null 2>&1; then
            __task "Removing Go via pacman"
            _cmd "sudo pacman -R --noconfirm go"
            _task_done
          fi
          ;;
      esac
    fi
    ;;
esac

# Remove GOPATH directory
if [ -n "$GOPATH" ] && [ -d "$GOPATH" ]; then
  echo -e "${YELLOW} [?]  ${WHITE}Remove GOPATH directory ($GOPATH)?${NC}"
  echo -e "${YELLOW}      ${WHITE}This contains your Go workspace and packages${NC}"
  read -p "$(echo -e ${YELLOW})Remove GOPATH? (y/N) ${NC}" -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    __task "Removing GOPATH directory"
    _cmd "rm -rf $GOPATH"
    _task_done
  fi
elif [ -d "$HOME/go" ]; then
  echo -e "${YELLOW} [?]  ${WHITE}Remove default Go workspace ($HOME/go)?${NC}"
  read -p "$(echo -e ${YELLOW})Remove Go workspace? (y/N) ${NC}" -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    __task "Removing Go workspace"
    _cmd "rm -rf $HOME/go"
    _task_done
  fi
fi

# Remove Go module cache
if [ -d "$HOME/.cache/go-build" ]; then
  __task "Removing Go build cache"
  _cmd "rm -rf $HOME/.cache/go-build"
  _task_done
fi

echo -e "${GREEN} [✓]  ${WHITE}Go has been uninstalled${NC}"