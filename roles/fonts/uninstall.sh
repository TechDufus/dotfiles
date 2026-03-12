#!/bin/bash
set -e

echo -e "${YELLOW} [!]  ${WHITE}This will remove BerkeleyMono Nerd Font files installed by this role${NC}"
read -p "$(echo -e ${YELLOW})Remove BerkeleyMono Nerd Font files? (y/N) ${NC}" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo -e "${YELLOW} [!]  ${WHITE}Font removal cancelled${NC}"
  exit 0
fi

# Detect OS
case "$(uname -s)" in
  Darwin)
    # Remove from user font directory
    if ls ~/Library/Fonts/BerkeleyMonoNerdFont-*.otf >/dev/null 2>&1; then
      __task "Removing BerkeleyMono Nerd Font files from user directory"
      _cmd "rm -f ~/Library/Fonts/BerkeleyMonoNerdFont-*.otf"
      _task_done
    fi
    ;;
    
  Linux)
    # Remove from user font directory
    if ls ~/.local/share/fonts/BerkeleyMonoNerdFont-*.otf >/dev/null 2>&1; then
      __task "Removing BerkeleyMono Nerd Font files from user directory"
      _cmd "rm -f ~/.local/share/fonts/BerkeleyMonoNerdFont-*.otf"
      _task_done
    fi
    
    # Update font cache
    if command -v fc-cache >/dev/null 2>&1; then
      __task "Updating font cache"
      _cmd "fc-cache -f"
      _task_done
    fi
    ;;
esac

echo -e "${GREEN} [✓]  ${WHITE}BerkeleyMono Nerd Font files have been uninstalled${NC}"
