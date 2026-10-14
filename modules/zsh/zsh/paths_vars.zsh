#!/usr/bin/env zsh

if command -v brew >/dev/null 2>&1; then
  addToPath /opt/homebrew/bin
fi

addToPath /usr/local/go/bin
[[ -n "${GOPATH:-}" ]] && addToPath "$GOPATH/bin"
addToPath "$HOME/go/bin"
addToPath "$HOME/.bun/bin"
addToPath "$HOME/.dotfiles/bin"
addToPath "$HOME/.cargo/bin"
addToPath /opt/whalebrew/bin
addToPathFront "${XDG_DATA_HOME:-$HOME/.local/share}/mise/shims"
addToPathFront "$HOME/.local/bin"
addToPathFront /usr/lib/ccache
