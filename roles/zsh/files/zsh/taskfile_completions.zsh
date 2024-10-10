#!/usr/bin/env zsh

if [ -x "$(command -v task)" ]; then
  eval "$(task --completion zsh)"
fi
