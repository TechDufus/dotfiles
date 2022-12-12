#!/usr/bin/env bash

addToPath /usr/local/go/bin
addToPath $GOPATH/bin
addToPath $HOME/go/bin
addToPath $HOME/.dotfiles/bin

# ccache
addToPathFront /usr/lib/ccache
