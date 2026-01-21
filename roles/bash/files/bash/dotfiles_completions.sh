#!/usr/bin/env bash

DOTFILES_ROLES_DIR="$HOME/.dotfiles/roles"

# Function to handle tab completion for dotfiles
_dotfiles() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    
    # Main options
    opts="-h --help --version -t --skip-tags --uninstall --delete --check --list-tags -v -vv -vvv"
    
    case "${prev}" in
        -t|--skip-tags)
            # All roles
            local roles=$(find "$DOTFILES_ROLES_DIR" -maxdepth 1 -type d -exec basename {} \; | grep -v '^roles$' | sort)
            COMPREPLY=($(compgen -W "${roles}" -- ${cur}))
            return 0
            ;;
        --uninstall)
            # Only roles with uninstall.sh
            local uninstallable=$(find "$DOTFILES_ROLES_DIR" -maxdepth 1 -type d -exec test -f {}/uninstall.sh \; -print | xargs -n1 basename | sort)
            COMPREPLY=($(compgen -W "${uninstallable}" -- ${cur}))
            return 0
            ;;
        --delete)
            # All roles (delete works with or without uninstall.sh)
            local roles=$(find "$DOTFILES_ROLES_DIR" -maxdepth 1 -type d -exec basename {} \; | grep -v '^roles$' | sort)
            COMPREPLY=($(compgen -W "${roles}" -- ${cur}))
            return 0
            ;;
    esac
    
    # If no special case, show main options
    COMPREPLY=($(compgen -W "${opts}" -- ${cur}))
}

# Register the completion function
complete -F _dotfiles dotfiles

