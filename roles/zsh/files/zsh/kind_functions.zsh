#!/usr/bin/env zsh

if [ -x "$(command -v kind)" ]; then
  source <(kind completion zsh)
fi

