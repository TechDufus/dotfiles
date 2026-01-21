#!/usr/bin/env bash

# Get the absolute path of the dotfiles root directory
DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Source the functions script
# shellcheck source=/dev/null
source "$DOTFILES_ROOT/bin/functions"

__task "Uninstalling Borders (JankyBorders)"

# Detect OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    if command -v brew &> /dev/null && brew list borders &> /dev/null; then
        # Stop the service first
        _cmd "brew services stop borders"
        
        # Uninstall borders
        _cmd "brew uninstall borders"
        
        # Untap the formula if no other packages from it are installed
        if ! brew list | grep -q "FelixKratz/formulae"; then
            _cmd "brew untap FelixKratz/formulae"
        fi
    fi
    
    # Prompt before removing configuration
    if [[ -d "$HOME/.config/borders" ]]; then
        echo ""
        read -p "Remove borders configuration? [y/N] " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            _cmd "rm -rf $HOME/.config/borders"
        else
            echo "Configuration retained at: $HOME/.config/borders"
        fi
    fi
else
    echo "Borders is only supported on macOS"
fi

_task_done "Borders uninstalled"