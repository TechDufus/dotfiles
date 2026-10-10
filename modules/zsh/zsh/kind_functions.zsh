#!/usr/bin/env zsh

_kind_lazy_completion() {
  local script
  script="$(command kind completion zsh 2>/dev/null)" || return
  eval "$script"
  (( $+functions[_kind] )) && _kind "$@"
}

if command -v kind >/dev/null 2>&1 && (( $+functions[compdef] )); then
  compdef _kind_lazy_completion kind
fi
