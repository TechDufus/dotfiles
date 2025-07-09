#!/bin/bash
set -e

# Remove Oh My Bash if installed
if [ -d "$HOME/.oh-my-bash" ]; then
  __task "Removing Oh My Bash"
  _cmd "rm -rf $HOME/.oh-my-bash"
  _task_done
fi

# Backup current .bashrc if it exists and restore original
if [ -f "$HOME/.bashrc" ]; then
  __task "Restoring original .bashrc"
  if [ -f "$HOME/.bashrc.pre-oh-my-bash" ]; then
    _cmd "mv $HOME/.bashrc.pre-oh-my-bash $HOME/.bashrc"
  else
    # Create minimal .bashrc
    cat > "$HOME/.bashrc" << 'EOF'
# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# User specific aliases and functions
EOF
  fi
  _task_done
fi

# Remove custom bash configurations
if [ -d "$HOME/.config/bash" ]; then
  __task "Removing custom bash configurations"
  _cmd "rm -rf $HOME/.config/bash"
  _task_done
fi

# Remove .profile if it was created by the role
if [ -f "$HOME/.profile" ] && grep -q "oh-my-bash" "$HOME/.profile" 2>/dev/null; then
  __task "Removing .profile"
  _cmd "rm -f $HOME/.profile"
  _task_done
fi

echo -e "${GREEN} [✓]  ${WHITE}Bash configurations have been removed${NC}"