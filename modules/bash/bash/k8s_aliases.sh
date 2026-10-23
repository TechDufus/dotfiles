#!/usr/bin/env bash

alias kctx='kubectl config use-context $(kubectl config get-contexts -o name | fzf)'
alias k=kubectl
source <(kubectl completion bash)
complete -F __start_kubectl k
