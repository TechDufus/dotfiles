#!/bin/bash
set -e

# Note: We only remove git configurations, not git itself
# as git is often a system dependency

# Remove global git configuration
if [ -f "$HOME/.gitconfig" ]; then
  __task "Removing global git configuration"
  _cmd "rm -f $HOME/.gitconfig"
  _task_done
fi

# Remove git config directory
if [ -d "$HOME/.config/git" ]; then
  __task "Removing git config directory"
  _cmd "rm -rf $HOME/.config/git"
  _task_done
fi

# Remove git-delta if installed (macOS only)
case "$(uname -s)" in
  Darwin)
    if command -v brew >/dev/null 2>&1 && brew list git-delta >/dev/null 2>&1; then
      __task "Removing git-delta via Homebrew"
      _cmd "brew uninstall git-delta"
      _task_done
    fi
    ;;
esac

# Check if user wants to remove git credentials
if command -v git >/dev/null 2>&1; then
  # Check if credentials are stored
  if git config --global credential.helper >/dev/null 2>&1; then
    echo -e "${YELLOW} [?]  ${WHITE}Git credentials are currently stored. Remove them?${NC}"
    read -p "$(echo -e ${YELLOW})Remove git credentials? (y/N) ${NC}" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      __task "Removing git credentials"
      _cmd "git config --global --unset credential.helper" || true
      
      # Remove macOS keychain entries if on macOS
      if [[ "$OSTYPE" == "darwin"* ]]; then
        _cmd "git credential-osxkeychain erase" <<< $'protocol=https\nhost=github.com\n\n' || true
      fi
      _task_done
    fi
  fi
fi

echo -e "${GREEN} [✓]  ${WHITE}Git configurations have been removed${NC}"
echo -e "${YELLOW} [!]  ${WHITE}Note: Git itself was not removed as it may be needed by other tools${NC}"