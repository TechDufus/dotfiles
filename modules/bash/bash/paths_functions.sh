#!/usr/bin/env bash

addToPath() {
    [[ -n "${1:-}" && -d "$1" ]] || return 0
    case ":$PATH:" in
        *":$1:"*) ;;
        *) export PATH="$PATH:$1" ;;
    esac
}

addToPathFront() {
    [[ -n "${1:-}" && -d "$1" ]] || return 0
    local remaining="$PATH" entry new_path="$1"
    # Move every existing occurrence to the front, retaining other entries verbatim.
    while :; do
        entry="${remaining%%:*}"
        [[ "$entry" == "$1" ]] || new_path="$new_path:$entry"
        [[ "$remaining" == *:* ]] || break
        remaining="${remaining#*:}"
    done
    export PATH="$new_path"
}

change_background() {
    dconf write /org/mate/desktop/background/picture-filename "'$HOME/anime/$(ls ~/anime| fzf)'"
}

die () {
    echo >&2 "$@"
    exit 1
}
