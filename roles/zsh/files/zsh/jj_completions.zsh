#!/usr/bin/env zsh

_jj_lazy_completion() {
  local script
  script="$(command jj util completion zsh 2>/dev/null)" || return
  eval "$script"
  if (( $+functions[_jj] )); then
    _jj "$@"
  elif (( $+functions[compdef] )); then
    compdef _jj jj 2>/dev/null
    (( $+functions[_jj] )) && _jj "$@"
  fi
}

if command -v jj >/dev/null 2>&1 && (( $+functions[compdef] )); then
  compdef _jj_lazy_completion jj
fi
