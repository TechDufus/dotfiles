#!/bin/bash
set -e

# Store current shell before changing
CURRENT_SHELL=$(echo $SHELL)

# Remove Zinit if installed
if [ -d "${HOME}/.local/share/zinit" ]; then
  __task "Removing Zinit"
  _cmd "rm -rf ${HOME}/.local/share/zinit"
  _task_done
fi

# Remove zsh configurations
if [ -f "$HOME/.zshrc" ]; then
  __task "Removing .zshrc"
  # Backup just in case
  _cmd "cp $HOME/.zshrc $HOME/.zshrc.uninstall-backup"
  _cmd "rm -f $HOME/.zshrc"
  _task_done
fi

if [ -f "$HOME/.p10k.zsh" ]; then
  __task "Removing Powerlevel10k configuration"
  _cmd "rm -f $HOME/.p10k.zsh"
  _task_done
fi

# Remove custom zsh configurations
if [ -d "$HOME/.config/zsh" ]; then
  __task "Removing custom zsh configurations"
  _cmd "rm -rf $HOME/.config/zsh"
  _task_done
fi

# Remove zsh history file if it exists
if [ -f "$HOME/.zsh_history" ]; then
  __task "Removing zsh history"
  _cmd "rm -f $HOME/.zsh_history"
  _task_done
fi

# Remove zsh cache directory
if [ -d "$HOME/.cache/zsh" ]; then
  __task "Removing zsh cache"
  _cmd "rm -rf $HOME/.cache/zsh"
  _task_done
fi

# If current shell is zsh and bash is available, offer to change it back
if [[ "$CURRENT_SHELL" == */zsh ]] && command -v bash >/dev/null 2>&1; then
  echo -e "${YELLOW} [?]  ${WHITE}Your current shell is zsh. Would you like to change it back to bash?${NC}"
  read -p "$(echo -e ${YELLOW})Change shell to bash? (y/N) ${NC}" -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    __task "Changing default shell to bash"
    if [[ "$OSTYPE" == "darwin"* ]]; then
      _cmd "sudo chsh -s /bin/bash $USER"
    else
      _cmd "sudo chsh -s $(which bash) $USER"
    fi
    _task_done
    echo -e "${YELLOW} [!]  ${WHITE}Shell changed. Please log out and back in for the change to take effect.${NC}"
  fi
fi

echo -e "${GREEN} [✓]  ${WHITE}ZSH configurations have been removed${NC}"