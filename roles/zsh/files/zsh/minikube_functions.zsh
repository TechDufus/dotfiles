#!/usr/bin/env zsh

if [ -x "$(command -v minikube)" ]; then
  source <(minikube completion zsh)
fi

