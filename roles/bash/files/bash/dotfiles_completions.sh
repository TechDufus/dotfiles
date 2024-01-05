#!/usr/bin/env bash

DOTFILES_ROLES_DIR="$HOME/.dotfiles/roles"

# Function to handle tab completion
_complete_tags() {
    local cur_word tags_list
    cur_word="${COMP_WORDS[COMP_CWORD]}"
    tags_list=$(find "$DOTFILES_ROLES_DIR" -maxdepth 1 -type d -printf "%f\n")

    COMPREPLY=($(compgen -W "${tags_list}" -- "${cur_word}"))
}

# Register the completion function for the -t flag
# This isn't perfect, as -t and --skip-tags show up in the completion list
complete -F _complete_tags -o nospace -W "-t --skip-tags" dotfiles

