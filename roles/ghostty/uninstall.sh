#!/usr/bin/env bash

# Get the absolute path of the dotfiles root directory
DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Source the functions script
# shellcheck source=/dev/null
source "$DOTFILES_ROOT/bin/functions"

__task "Uninstalling Ghostty"

# Detect OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    # Check for nightly version first
    if command -v brew &> /dev/null && brew list --cask ghostty@tip &> /dev/null; then
        _cmd "brew uninstall --cask ghostty@tip"
    # Check for regular version
    elif command -v brew &> /dev/null && brew list --cask ghostty &> /dev/null; then
        _cmd "brew uninstall --cask ghostty"
    fi
    
    # Prompt before removing configuration
    if [[ -d "$HOME/.config/ghostty" ]]; then
        echo ""
        read -p "Remove Ghostty configuration? [y/N] " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            _cmd "rm -rf $HOME/.config/ghostty"
        else
            echo "Configuration retained at: $HOME/.config/ghostty"
        fi
    fi
    
    # Also check for legacy config location
    if [[ -d "$HOME/Library/Application Support/com.mitchellh.ghostty" ]]; then
        echo ""
        read -p "Remove legacy Ghostty configuration? [y/N] " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            _cmd "rm -rf \"$HOME/Library/Application Support/com.mitchellh.ghostty\""
        else
            echo "Legacy configuration retained"
        fi
    fi
else
    echo "Ghostty uninstall not implemented for this OS"
fi

_task_done "Ghostty uninstalled"