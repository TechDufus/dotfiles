#!/bin/bash
set -e

# Detect OS
case "$(uname -s)" in
  Darwin)
    # Uninstall via Homebrew
    if command -v brew >/dev/null 2>&1 && brew list gh >/dev/null 2>&1; then
      __task "Removing GitHub CLI via Homebrew"
      _cmd "brew uninstall gh"
      _task_done
    fi
    ;;
    
  Linux)
    # Check distribution
    if [ -f /etc/os-release ]; then
      . /etc/os-release
      case "$ID" in
        ubuntu|debian)
          if dpkg -l | grep -q "^ii  gh"; then
            __task "Removing GitHub CLI via apt"
            _cmd "sudo apt-get remove -y gh"
            _task_done
          fi
          ;;
        fedora)
          if rpm -q gh >/dev/null 2>&1; then
            __task "Removing GitHub CLI via dnf"
            _cmd "sudo dnf remove -y gh"
            _task_done
          fi
          ;;
        arch)
          if pacman -Q github-cli >/dev/null 2>&1; then
            __task "Removing GitHub CLI via pacman"
            _cmd "sudo pacman -R --noconfirm github-cli"
            _task_done
          fi
          ;;
      esac
    fi
    ;;
esac

# Remove configuration and auth
if [ -d "$HOME/.config/gh" ]; then
  echo -e "${YELLOW} [?]  ${WHITE}Remove GitHub CLI configuration and authentication?${NC}"
  read -p "$(echo -e ${YELLOW})Remove gh config? (y/N) ${NC}" -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    __task "Removing GitHub CLI configuration"
    _cmd "rm -rf $HOME/.config/gh"
    _task_done
  fi
fi

# Remove any gh extensions
if [ -d "$HOME/.local/share/gh/extensions" ]; then
  __task "Removing GitHub CLI extensions"
  _cmd "rm -rf $HOME/.local/share/gh"
  _task_done
fi

echo -e "${GREEN} [✓]  ${WHITE}GitHub CLI has been uninstalled${NC}"