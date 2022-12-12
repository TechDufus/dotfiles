#!/usr/bin/env bash

addToPath() {
    if [[ "$PATH" != *"$1"* ]]; then
        export PATH=$PATH:$1
    fi
}

addToPathFront() {
    if [[ "$PATH" != *"$1"* ]]; then
        export PATH=$1:$PATH
    fi
}

change_background() {
    dconf write /org/mate/desktop/background/picture-filename "'$HOME/anime/$(ls ~/anime| fzf)'"
}

die () {
    echo >&2 "$@"
    exit 1
}
