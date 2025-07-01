#!/usr/bin/env zsh

DOTFILES_ROLES_DIR="$HOME/.dotfiles/roles"

# Function to handle tab completion for dotfiles command
_dotfiles() {
    local -a roles
    local curcontext="$curcontext" state line
    typeset -A opt_args

    # Define the command line options
    _arguments -C \
        '-t[Run specific roles]:role:->roles' \
        '--skip-tags[Skip specific roles]:role:->roles' \
        '--check[Run in check mode (dry run)]' \
        '--list-tags[List all available tags]' \
        '-v[Verbose mode (can be specified multiple times)]' \
        '-vv[More verbose output]' \
        '-vvv[Most verbose output]' \
        '*:argument:->args'

    case $state in
        roles)
            # Get list of roles from the roles directory
            roles=(${(f)"$(find $DOTFILES_ROLES_DIR -maxdepth 1 -type d -exec basename {} \; | grep -v '^roles$' | sort)"})

            # Support comma-separated values
            if [[ -n "${words[CURRENT]}" && "${words[CURRENT]}" == *,* ]]; then
                # Handle comma-separated completions
                local prefix="${words[CURRENT]%,*},"
                local suffix="${words[CURRENT]##*,}"
                _describe -t roles 'role' roles -P "$prefix" -S ','
            else
                _describe -t roles 'role' roles -S ','
            fi
            ;;
    esac
}

# Register the completion function with compdef
compdef _dotfiles dotfiles

