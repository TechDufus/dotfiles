#!/usr/bin/env bash
set -uo pipefail

# Homebrew's llvm is keg-only; link its clangd into ~/.local/bin. A [dotfiles] entry
# cannot do this: its source only exists once llvm is installed, so every dry run fails.
dst="$HOME/.local/bin/clangd"
prefix="$(brew --prefix llvm 2>/dev/null)" || prefix=""
src="${prefix:+$prefix/bin/clangd}"

if [ -z "$src" ] || [ ! -x "$src" ]; then
  echo "clangd: brew llvm not installed, skipped"
elif [ -e "$dst" ] && [ ! -L "$dst" ]; then
  echo "clangd: $dst is not a link, skipped"
elif [ "$(readlink "$dst" 2>/dev/null)" != "$src" ]; then
  mkdir -p "${dst%/*}" && ln -sfn "$src" "$dst" || echo "clangd: linking $dst failed, skipped"
fi
exit 0
