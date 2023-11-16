#!/usr/bin/env bash

function nisshfs() {
    local remote_dir='/'
    if [ ! -d ~/.sshfs ]; then mkdir ~/.sshfs > /dev/null 2>&1; fi
    if [ ! -d ~/.sshfs/$1 ]; then mkdir ~/.sshfs/$1 > /dev/null 2>&1; fi
    if [ ! -z $2 ]; then remote_dir=$2; fi
    sshfs -o default_permissions $1:$remote_dir $HOME/.sshfs/$1
    nvim $HOME/.sshfs/$1
    fusermount -zu $HOME/.sshfs/$1
    rm -rf $HOME/.sshfs/$1
}


# give nisshfs ssh tab completion for servers in ~/.ssh/config
function _nisshfs() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    opts=$(grep -E '^Host ' ~/.ssh/config | awk '{print $2}')
    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
    return 0
}
complete -F _nisshfs nisshfs
