#!/usr/bin/env zsh

alias update='sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y'
if command -v nala >/dev/null 2>&1; then
  _nala_lazy_completion() {
    local script
    script="$(command nala --show-completion zsh 2>/dev/null)" || return
    eval "$script"
    (( $+functions[_nala] )) && _nala "$@"
  }
  if (( $+functions[compdef] )); then
    compdef _nala_lazy_completion nala
  fi
  alias update='sudo nala upgrade -y && sudo nala autoremove -y && sudo nala clean'
fi
