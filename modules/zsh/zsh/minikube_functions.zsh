#!/usr/bin/env zsh

_minikube_lazy_completion() {
  local script
  script="$(command minikube completion zsh 2>/dev/null)" || return
  eval "$script"
  (( $+functions[_minikube] )) && _minikube "$@"
}

if command -v minikube >/dev/null 2>&1 && (( $+functions[compdef] )); then
  compdef _minikube_lazy_completion minikube
fi
