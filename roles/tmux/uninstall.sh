#!/bin/bash
set -e

# Detect OS
case "$(uname -s)" in
  Darwin)
    # Uninstall tmux via Homebrew
    if command -v brew >/dev/null 2>&1 && brew list tmux >/dev/null 2>&1; then
      __task "Removing tmux via Homebrew"
      _cmd "brew uninstall tmux"
      _task_done
    fi
    ;;
    
  Linux)
    # Check distribution
    if [ -f /etc/os-release ]; then
      . /etc/os-release
      case "$ID" in
        ubuntu|debian)
          if dpkg -l | grep -q "^ii  tmux"; then
            __task "Removing tmux via apt"
            _cmd "sudo apt-get remove -y tmux"
            _task_done
          fi
          ;;
        fedora)
          if rpm -q tmux >/dev/null 2>&1; then
            __task "Removing tmux via dnf"
            _cmd "sudo dnf remove -y tmux"
            _task_done
          fi
          ;;
        arch)
          if pacman -Q tmux >/dev/null 2>&1; then
            __task "Removing tmux via pacman"
            _cmd "sudo pacman -R --noconfirm tmux"
            _task_done
          fi
          ;;
      esac
    fi
    ;;
esac

# Remove TPM (Tmux Plugin Manager)
if [ -d "$HOME/.tmux/plugins/tpm" ]; then
  __task "Removing Tmux Plugin Manager"
  _cmd "rm -rf $HOME/.tmux/plugins"
  _task_done
fi

# Remove tmux configuration
if [ -f "$HOME/.tmux.conf" ]; then
  __task "Removing tmux configuration"
  _cmd "rm -f $HOME/.tmux.conf"
  _task_done
fi

# Remove tmux directory if empty
if [ -d "$HOME/.tmux" ] && [ -z "$(ls -A $HOME/.tmux)" ]; then
  __task "Removing empty .tmux directory"
  _cmd "rmdir $HOME/.tmux"
  _task_done
fi

# Kill any running tmux sessions
if command -v tmux >/dev/null 2>&1 && tmux list-sessions >/dev/null 2>&1; then
  echo -e "${YELLOW} [!]  ${WHITE}Active tmux sessions detected. They will continue running.${NC}"
  echo -e "${YELLOW}      ${WHITE}To kill all sessions, run: ${BOLD}tmux kill-server${NC}"
fi

echo -e "${GREEN} [✓]  ${WHITE}Tmux and its configurations have been removed${NC}"