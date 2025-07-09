#!/bin/bash
set -e

# Detect OS
case "$(uname -s)" in
  Darwin)
    # Uninstall k9s via Homebrew
    if command -v brew >/dev/null 2>&1 && brew list k9s >/dev/null 2>&1; then
      __task "Removing k9s via Homebrew"
      _cmd "brew uninstall k9s"
      _task_done
    fi
    
    # Remove configuration files
    K9S_CONFIG_DIR="$HOME/Library/Application Support/k9s"
    if [ -d "$K9S_CONFIG_DIR" ]; then
      __task "Removing k9s configuration files"
      _cmd "rm -rf \"$K9S_CONFIG_DIR\""
      _task_done
    fi
    ;;
    
  Linux)
    # Remove k9s binary
    if [ -f "/usr/local/bin/k9s" ]; then
      __task "Removing k9s binary"
      _cmd "sudo rm -f /usr/local/bin/k9s"
      _task_done
    fi
    
    # Remove configuration files
    if [ -d "$HOME/.config/k9s" ]; then
      __task "Removing k9s configuration files"
      _cmd "rm -rf $HOME/.config/k9s"
      _task_done
    fi
    ;;
esac