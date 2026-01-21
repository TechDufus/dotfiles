#!/bin/bash
set -e

# Remove Neovim configuration symlink
if [ -L "$HOME/.config/nvim" ]; then
  __task "Removing Neovim configuration symlink"
  _cmd "rm -f $HOME/.config/nvim"
  _task_done
elif [ -d "$HOME/.config/nvim" ]; then
  # If it's a directory (not symlink), back it up
  __task "Backing up and removing Neovim configuration"
  _cmd "mv $HOME/.config/nvim $HOME/.config/nvim.uninstall-backup"
  _task_done
  echo -e "${YELLOW} [!]  ${WHITE}Your nvim config was backed up to ~/.config/nvim.uninstall-backup${NC}"
fi

# Remove Neovim data and cache
if [ -d "$HOME/.local/share/nvim" ]; then
  __task "Removing Neovim data directory"
  _cmd "rm -rf $HOME/.local/share/nvim"
  _task_done
fi

if [ -d "$HOME/.local/state/nvim" ]; then
  __task "Removing Neovim state directory"
  _cmd "rm -rf $HOME/.local/state/nvim"
  _task_done
fi

if [ -d "$HOME/.cache/nvim" ]; then
  __task "Removing Neovim cache"
  _cmd "rm -rf $HOME/.cache/nvim"
  _task_done
fi

# Offer to remove Neovim itself
echo -e "${YELLOW} [?]  ${WHITE}Would you like to remove Neovim itself? (not just configs)${NC}"
read -p "$(echo -e ${YELLOW})Remove Neovim binary? (y/N) ${NC}" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  case "$(uname -s)" in
    Darwin)
      if command -v brew >/dev/null 2>&1 && brew list neovim >/dev/null 2>&1; then
        __task "Removing Neovim via Homebrew"
        _cmd "brew uninstall neovim"
        _task_done
      fi
      ;;
      
    Linux)
      if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
          ubuntu|debian)
            if dpkg -l | grep -q "^ii  neovim"; then
              __task "Removing Neovim via apt"
              _cmd "sudo apt-get remove -y neovim"
              _task_done
            fi
            ;;
          fedora)
            if rpm -q neovim >/dev/null 2>&1; then
              __task "Removing Neovim via dnf"
              _cmd "sudo dnf remove -y neovim"
              _task_done
            fi
            ;;
          arch)
            if pacman -Q neovim >/dev/null 2>&1; then
              __task "Removing Neovim via pacman"
              _cmd "sudo pacman -R --noconfirm neovim"
              _task_done
            fi
            ;;
        esac
      fi
      
      # Check for AppImage installation
      if [ -f "$HOME/.local/bin/nvim" ]; then
        __task "Removing Neovim AppImage"
        _cmd "rm -f $HOME/.local/bin/nvim"
        _task_done
      fi
      ;;
  esac
fi

echo -e "${GREEN} [✓]  ${WHITE}Neovim configurations have been removed${NC}"