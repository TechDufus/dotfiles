#!/usr/bin/env zsh

_kwctl_lazy_completion() {
  local script
  script="$(command kwctl completions -s zsh 2>/dev/null)" \
    || script="$(command kwctl completions -s bash 2>/dev/null)" \
    || return
  eval "$script"
  if (( $+functions[_kwctl] )); then
    _kwctl "$@"
  fi
}

if command -v kwctl >/dev/null 2>&1 && (( $+functions[compdef] )); then
  compdef _kwctl_lazy_completion kwctl
fi
