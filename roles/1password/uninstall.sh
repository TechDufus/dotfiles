#!/bin/bash
set -e

echo -e "${YELLOW} [!]  ${WHITE}This will remove 1Password and the CLI${NC}"
echo -e "${YELLOW}      ${WHITE}Make sure you have access to your vault elsewhere!${NC}"
read -p "$(echo -e ${YELLOW})Continue with 1Password removal? (y/N) ${NC}" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo -e "${YELLOW} [!]  ${WHITE}1Password removal cancelled${NC}"
  exit 0
fi

# Detect OS
case "$(uname -s)" in
  Darwin)
    # Close 1Password if running
    if pgrep -x "1Password" > /dev/null; then
      __task "Closing 1Password"
      _cmd "osascript -e 'quit app \"1Password 7\"' 2>/dev/null || osascript -e 'quit app \"1Password\"' 2>/dev/null || true"
      sleep 2
      _task_done
    fi
    
    # Uninstall 1Password app
    if [ -d "/Applications/1Password 7.app" ] || [ -d "/Applications/1Password.app" ]; then
      __task "Removing 1Password application"
      _cmd "sudo rm -rf '/Applications/1Password 7.app' '/Applications/1Password.app' 2>/dev/null || true"
      _task_done
    fi
    
    # Uninstall via Homebrew
    if command -v brew >/dev/null 2>&1; then
      if brew list --cask 1password >/dev/null 2>&1; then
        __task "Removing 1Password via Homebrew"
        _cmd "brew uninstall --cask 1password"
        _task_done
      fi
      if brew list --cask 1password-cli >/dev/null 2>&1; then
        __task "Removing 1Password CLI via Homebrew"
        _cmd "brew uninstall --cask 1password-cli"
        _task_done
      fi
    fi
    
    # Remove 1Password data
    __task "Removing 1Password data and preferences"
    _cmd "rm -rf '$HOME/Library/Application Support/1Password'" || true
    _cmd "rm -rf '$HOME/Library/Caches/com.agilebits.onepassword'" || true
    _cmd "rm -rf '$HOME/Library/Preferences/com.agilebits.onepassword.plist'" || true
    _cmd "rm -rf '$HOME/.config/op'" || true
    _task_done
    ;;
    
  Linux)
    # Remove 1Password CLI
    if [ -f "/usr/local/bin/op" ]; then
      __task "Removing 1Password CLI"
      _cmd "sudo rm -f /usr/local/bin/op"
      _task_done
    fi
    
    # Check distribution for GUI app
    if [ -f /etc/os-release ]; then
      . /etc/os-release
      case "$ID" in
        ubuntu|debian)
          if dpkg -l | grep -q "1password"; then
            __task "Removing 1Password via apt"
            _cmd "sudo apt-get remove -y 1password 1password-cli"
            _task_done
          fi
          ;;
        fedora)
          if rpm -q 1password >/dev/null 2>&1; then
            __task "Removing 1Password via dnf"
            _cmd "sudo dnf remove -y 1password 1password-cli"
            _task_done
          fi
          ;;
      esac
    fi
    
    # Remove config
    if [ -d "$HOME/.config/op" ]; then
      __task "Removing 1Password CLI configuration"
      _cmd "rm -rf $HOME/.config/op"
      _task_done
    fi
    ;;
esac

echo -e "${GREEN} [✓]  ${WHITE}1Password has been uninstalled${NC}"
echo -e "${YELLOW} [!]  ${WHITE}Remember to update your dotfiles to remove 1Password integration${NC}"