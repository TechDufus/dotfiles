#!/usr/bin/env zsh

addToPath() {
  [[ -n "$1" && -d "$1" ]] || return
  case ":$PATH:" in
    *":$1:"*) ;;
    *) export PATH="$PATH:$1" ;;
  esac
}

addToPathFront() {
  [[ -n "$1" && -d "$1" ]] || return
  case ":$PATH:" in
    *":$1:"*) ;;
    *) export PATH="$1:$PATH" ;;
  esac
}

die() {
  print -ru2 -- "$@"
  return 1
}
