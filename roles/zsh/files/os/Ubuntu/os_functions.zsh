#!/usr/bin/env zsh

alias update='sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y'
if command -v task &> /dev/null; then
  alias update='task -g upgrade'
fi
