#!/usr/bin/env zsh

alias k=kubectl
alias kc='kubectl config use-context'
alias kns='kubectl config set-context --current --namespace'
alias kgns='kubectl get namespaces'
alias kgn='kubectl get nodes'
alias kga='kubectl get all'
alias kgs='kubectl get service'
alias kd='kubectl describe'
alias kl='kubectl logs'
alias ka='kubectl apply'
alias ktp='kubectl top pods'
alias kexec='kubectl exec -it --'

_kubectl_lazy_completion() {
  local script
  script="$(command kubectl completion zsh 2>/dev/null)" || return
  eval "$script"
  (( $+functions[_kubectl] )) && _kubectl "$@"
}

if command -v kubectl >/dev/null 2>&1 && (( $+functions[compdef] )); then
  compdef _kubectl_lazy_completion kubectl k
fi
