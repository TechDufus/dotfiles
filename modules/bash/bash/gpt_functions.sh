#!/usr/bin/env bash

function gpt-commit() {
  if [[ -n "$1" && "$1" != "-b" ]]; then
    echo "Invalid argument. Usage: gpt-commit [-b branch_name]"
    return 1
  fi

  if [[ "$1" == "-b" && -n "$2" ]]; then
    git diff "$2" | sgpt "generate commit message for these changes, keep the summary message to 50 chars max, and list extra details below in markdown"
  else
    git diff | sgpt "generate commit message for these changes, keep the summary message to 50 chars max, and list extra details below in markdown"
  fi
}
