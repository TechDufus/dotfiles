#!/usr/bin/env zsh

alias bt='btop'
alias comment-header='toilet -f pagga -S'
alias i='explorer.exe'
alias ncdu='ncdu --color dark -e -q --exclude-caches --exclude-kernfs -L'
alias c='clear'
alias p='podman'

monitors() {
  emulate -L zsh
  local connector="${2:-HDMI-A-1}"
  case "${1:-status}" in
    status|show) kscreen-doctor --outputs ;;
    wake|enable) kscreen-doctor "output.${connector}.enable" ;;
    bounce|refresh) "$HOME/.local/bin/plasma-output-wakeup" --connector "$connector" --delay 0 --settle "${3:-2}" ;;
    *) print -u2 "usage: monitors [status|wake [connector]|bounce [connector] [settle]]"; return 2 ;;
  esac
}
