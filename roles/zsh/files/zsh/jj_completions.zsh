#!/usr/bin/env zsh

if command -v jj &> /dev/null; then
  source <(jj util completion zsh)
fi