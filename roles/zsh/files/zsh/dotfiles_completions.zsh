#!/usr/bin/env zsh

DOTFILES_ROLES_DIR="$HOME/.dotfiles/roles"

# Function to handle tab completion
_complete_tags() {
    local cur_word tags_list
    cur_word="${words[CURRENT]}"

    # Find directories in the specified directory and store them in tags_list
    tags_list=($(find "$DOTFILES_ROLES_DIR" -maxdepth 1 -type d -exec basename {} \;))

    # Add -t and --skip-tags as options
    if [[ "${cur_word}" == -* ]]; then
        compadd -W "-t --skip-tags"
    else
        # Add directories as completion options
        compadd "${tags_list[@]}"
    fi
}

# Register the completion function with compdef
compdef _complete_tags dotfiles

