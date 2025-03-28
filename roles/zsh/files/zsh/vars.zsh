#!/usr/bin/env zsh

# color codes
export RESTORE='\033[0m'
export NC='\033[0m'
export BOLD='\033[1m'
export BLACK='\033[00;30m'
export RED='\033[00;31m'
export GREEN='\033[00;32m'
export YELLOW='\033[00;33m'
export BLUE='\033[00;34m'
export PURPLE='\033[00;35m'
export CYAN='\033[00;36m'
export SEA="\\033[38;5;49m"
export LIGHTGRAY='\033[00;37m'
export LBLACK='\033[01;30m'
export LRED='\033[01;31m'
export LGREEN='\033[01;32m'
export LYELLOW='\033[01;33m'
export LBLUE='\033[01;34m'
export LPURPLE='\033[01;35m'
export LCYAN='\033[01;36m'
export WHITE='\033[01;37m'
export OVERWRITE='\e[1A\e[K'

export COLOR_ESC=$(printf '\033')
export COLOR_BOLD=${COLOR_ESC}$(printf '[1m')

#emoji codes
export CHECK_MARK="${GREEN}\xE2\x9C\x94${NC}"
export X_MARK="${RED}\xE2\x9C\x96${NC}"
export PIN="${RED}\xF0\x9F\x93\x8C${NC}"
export CLOCK="${GREEN}\xE2\x8C\x9B${NC}"
export ARROW="${SEA}\xE2\x96\xB6${NC}"
export BOOK="${RED}\xF0\x9F\x93\x8B${NC}"
export HOT="${ORANGE}\xF0\x9F\x94\xA5${NC}"
export WARNING="${RED}\xF0\x9F\x9A\xA8${NC}"
export RIGHT_ANGLE="${GREEN}\xE2\x88\x9F${NC}"

export GH_DASH_CONFIG="$HOME/.config/gh-dash/config.yaml"

export DF_HOME="$HOME/dev/raft/data-fabric"
export RDP_HOME="$HOME/dev/raft/rdp-operator"
export DF_INFRA_HOME="$HOME/dev/raft/df-infra"
export DFDEV_GIT_PROTOCOL="ssh"
export AWS_PROFILE="Raft"

