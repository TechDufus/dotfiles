#!/bin/bash
set -e

echo -e "${YELLOW} [!]  ${WHITE}This will remove Nerd Fonts installed by this role${NC}"
read -p "$(echo -e ${YELLOW})Remove Nerd Fonts? (y/N) ${NC}" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo -e "${YELLOW} [!]  ${WHITE}Font removal cancelled${NC}"
  exit 0
fi

# Detect OS
case "$(uname -s)" in
  Darwin)
    # Remove from user font directory
    if ls ~/Library/Fonts/*Nerd*.ttf >/dev/null 2>&1 || ls ~/Library/Fonts/*Nerd*.otf >/dev/null 2>&1; then
      __task "Removing Nerd Fonts from user directory"
      _cmd "rm -f ~/Library/Fonts/*Nerd*.ttf ~/Library/Fonts/*Nerd*.otf"
      _task_done
    fi
    
    # Remove via Homebrew
    if command -v brew >/dev/null 2>&1; then
      for font in $(brew list --cask | grep font-.*-nerd-font); do
        __task "Removing $font via Homebrew"
        _cmd "brew uninstall --cask $font"
        _task_done
      done
    fi
    ;;
    
  Linux)
    # Remove from user font directory
    if ls ~/.local/share/fonts/*Nerd*.ttf >/dev/null 2>&1 || ls ~/.local/share/fonts/*Nerd*.otf >/dev/null 2>&1; then
      __task "Removing Nerd Fonts from user directory"
      _cmd "rm -f ~/.local/share/fonts/*Nerd*.ttf ~/.local/share/fonts/*Nerd*.otf"
      _task_done
    fi
    
    # Remove from system directory if installed there
    if ls /usr/share/fonts/*Nerd*.ttf >/dev/null 2>&1 || ls /usr/share/fonts/*Nerd*.otf >/dev/null 2>&1; then
      __task "Removing Nerd Fonts from system directory"
      _cmd "sudo rm -f /usr/share/fonts/*Nerd*.ttf /usr/share/fonts/*Nerd*.otf"
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

echo -e "${GREEN} [✓]  ${WHITE}Nerd Fonts have been uninstalled${NC}"