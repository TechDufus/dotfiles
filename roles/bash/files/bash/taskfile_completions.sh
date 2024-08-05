#!/usr/bin/env bash

if [ -x "$(command -v task)" ]; then
  if [ -d "${HOME}/.task" ]; then
    if [ -d "${HOME}/.task/completions" ]; then
      source "${HOME}/.task/completions/task.bash"
    fi
  fi
fi
