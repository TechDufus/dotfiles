#!/bin/bash
set -e

# Detect OS
case "$(uname -s)" in
  Darwin)
    # Uninstall via Homebrew
    if command -v brew >/dev/null 2>&1 && brew list fzf >/dev/null 2>&1; then
      __task "Removing fzf via Homebrew"
      _cmd "brew uninstall fzf"
      _task_done
    fi
    ;;
    
  Linux)
    # Check distribution
    if [ -f /etc/os-release ]; then
      . /etc/os-release
      case "$ID" in
        ubuntu|debian)
          if dpkg -l | grep -q "^ii  fzf"; then
            __task "Removing fzf via apt"
            _cmd "sudo apt-get remove -y fzf"
            _task_done
          fi
          ;;
        fedora)
          if rpm -q fzf >/dev/null 2>&1; then
            __task "Removing fzf via dnf"
            _cmd "sudo dnf remove -y fzf"
            _task_done
          fi
          ;;
        arch)
          if pacman -Q fzf >/dev/null 2>&1; then
            __task "Removing fzf via pacman"
            _cmd "sudo pacman -R --noconfirm fzf"
            _task_done
          fi
          ;;
      esac
    fi
    
    # Check for git installation
    if [ -d "$HOME/.fzf" ]; then
      __task "Removing fzf git installation"
      _cmd "$HOME/.fzf/uninstall" || true
      _cmd "rm -rf $HOME/.fzf"
      _task_done
    fi
    ;;
esac

# Remove shell integration files
if [ -f "$HOME/.fzf.bash" ]; then
  __task "Removing fzf shell integration files"
  _cmd "rm -f $HOME/.fzf.bash $HOME/.fzf.zsh"
  _task_done
fi

echo -e "${GREEN} [✓]  ${WHITE}fzf has been uninstalled${NC}"