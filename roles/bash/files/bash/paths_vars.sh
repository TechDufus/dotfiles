#!/usr/bin/env bash

addToPath /usr/local/go/bin
addToPath $GOPATH/bin
addToPath $HOME/go/bin
addToPath $HOME/.dotfiles/bin
addToPath $HOME/.cargo/bin
addToPath $HOME/.local/bin
# ccache
addToPathFront /usr/lib/ccache
