#!/usr/bin/env zsh

addToPath() {
  [[ -n "${1:-}" && -d "$1" ]] || return 0
  case ":$PATH:" in
    *":$1:"*) ;;
    *) export PATH="$PATH:$1" ;;
  esac
}

addToPathFront() {
  [[ -n "${1:-}" && -d "$1" ]] || return 0
  local remaining="$PATH" entry new_path="$1"
  # Move every existing occurrence to the front, retaining other entries verbatim.
  while :; do
    entry="${remaining%%:*}"
    [[ "$entry" == "$1" ]] || new_path="$new_path:$entry"
    [[ "$remaining" == *:* ]] || break
    remaining="${remaining#*:}"
  done
  export PATH="$new_path"
}

die() {
  print -ru2 -- "$@"
  return 1
}
