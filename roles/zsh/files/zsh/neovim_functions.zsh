#!/usr/bin/env zsh

function __nisshfs_usage() {
    echo -e "${ARROW} ${YELLOW}Usage: nisshfs -s <server> [-d remote_dir]${NC}"
}

function nisshfs() {
    local remote_dir='/'
    local server=''
    local OPTIND=1
    local mountpoint
    while getopts "hd:s:" opt; do
        case ${opt} in
            h )
                __nisshfs_usage
                return 0
                ;;
            d )
                remote_dir=$OPTARG
                ;;
            s )
                server=$OPTARG
                ;;
            \? )
                echo -e "${WARNING} ${YELLOW}Invalid option${NC}"
                __nisshfs_usage
                return 1
                ;;
        esac
    done
    if [[ -z $server ]]; then
        __nisshfs_usage
        return 1
    fi
    mkdir -p "$HOME/.sshfs/$server"
    mountpoint="$HOME/.sshfs/$server"
    sshfs -o default_permissions "$server:$remote_dir" "$mountpoint"
    nvim "$mountpoint"
    if [[ "$OSTYPE" == darwin* ]]; then
        umount "$mountpoint"
    else
        fusermount -zu "$mountpoint"
    fi
    rm -rf "$mountpoint"
}

_nisshfs() {
    local -a hosts
    hosts=(${(f)"$(awk '/^Host / && $2 !~ /[*?]/ { print $2 }' "$HOME/.ssh/config" 2>/dev/null)"})
    _describe 'host' hosts
}

if (( $+functions[compdef] )); then
    compdef _nisshfs nisshfs
fi
