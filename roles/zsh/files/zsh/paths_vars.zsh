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
addToPathFront "$HOME/.local/bin"
addToPathFront /usr/lib/ccache

if command -v rbenv >/dev/null 2>&1; then
  addToPathFront /opt/homebrew/opt/ruby/bin
fi
