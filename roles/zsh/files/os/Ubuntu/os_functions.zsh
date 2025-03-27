#!/usr/bin/env zsh

alias update='sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y'
# if nala is installed, use it
if [ -x "$(command -v nala)" ]; then
  source <(nala --show-completion)
  alias update='sudo nala upgrade -y && sudo nala autoremove -y && sudo nala clean'
fi
