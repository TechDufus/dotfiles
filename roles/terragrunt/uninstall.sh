#!/bin/bash
set -e

# Detect OS
case "$(uname -s)" in
  Darwin)
    # Uninstall via Homebrew
    if command -v brew >/dev/null 2>&1 && brew list terragrunt >/dev/null 2>&1; then
      __task "Removing terragrunt via Homebrew"
      _cmd "brew uninstall terragrunt"
      _task_done
    fi
    ;;
    
  Linux)
    # Check distribution
    if [ -f /etc/os-release ]; then
      . /etc/os-release
      case "$ID" in
        ubuntu|debian)
          if dpkg -l | grep -q "^ii  terragrunt"; then
            __task "Removing terragrunt via apt"
            _cmd "sudo apt-get remove -y terragrunt"
            _task_done
          fi
          ;;
        fedora)
          if rpm -q terragrunt >/dev/null 2>&1; then
            __task "Removing terragrunt via dnf"
            _cmd "sudo dnf remove -y terragrunt"
            _task_done
          fi
          ;;
        arch)
          if pacman -Q terragrunt >/dev/null 2>&1; then
            __task "Removing terragrunt via pacman"
            _cmd "sudo pacman -R --noconfirm terragrunt"
            _task_done
          fi
          ;;
      esac
    fi
    ;;
esac

# Remove configuration files if they exist
if [ -d "$HOME/.config/terragrunt" ]; then
  __task "Removing terragrunt configuration"
  _cmd "rm -rf $HOME/.config/terragrunt"
  _task_done
fi

echo -e "${GREEN} [✓]  ${WHITE}terragrunt has been uninstalled${NC}"
