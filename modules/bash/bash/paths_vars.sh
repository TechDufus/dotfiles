#!/usr/bin/env bash

addToPath /usr/local/go/bin
[[ -n "${GOPATH:-}" ]] && addToPath "$GOPATH/bin"
addToPath "$HOME/go/bin"
addToPath "$HOME/.dotfiles/bin"
addToPath "$HOME/.cargo/bin"
addToPath "$HOME/.bun/bin"
addToPath "$HOME/.magnitude/bin"
addToPath "$HOME/.minimax/bin"
addToPath "$HOME/.lmstudio/bin"
# macOS app-managed links must not shadow configured runtimes; Linux/Omarchy
# wrappers intentionally remain ahead of mise.
if [[ "$OSTYPE" == darwin* ]]; then
  addToPathFront "$HOME/.local/bin"
  addToPathFront "${XDG_DATA_HOME:-$HOME/.local/share}/mise/shims"
else
  addToPathFront "${XDG_DATA_HOME:-$HOME/.local/share}/mise/shims"
  addToPathFront "$HOME/.local/bin"
fi
# ccache
addToPathFront /usr/lib/ccache
