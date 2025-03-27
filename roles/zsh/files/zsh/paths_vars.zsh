#!/usr/bin/env zsh

if [ -x $(command -v brew) ]; then
  addToPath /opt/homebrew/bin
fi

addToPath /usr/local/go/bin
addToPath $GOPATH/bin
addToPath $HOME/go/bin
addToPath $HOME/.dotfiles/bin
addToPath $HOME/.cargo/bin
addToPath /opt/whalebrew/bin
addToPathFront $HOME/.local/bin
# ccache
addToPathFront /usr/lib/ccache

if [ -x $(command -v rbenv) ]; then
  addToPathFront /opt/homebrew/opt/ruby/bin
fi
