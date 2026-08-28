#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
zsh_bin="${ZSH_BIN:-zsh}"

if ! command -v "$zsh_bin" >/dev/null; then
  echo "SKIP: zsh not installed"
  exit 0
fi
zsh_bin="$(command -v "$zsh_bin")"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

export HOME="$tmp_dir/home"
export ZDOTDIR="$HOME"
mkdir -p "$HOME"
cp "$repo_root/roles/zsh/files/.zshenv" "$HOME/.zshenv"

env -u CURSOR_AGENT PATH="/usr/bin:/bin" CURSOR_AGENT=1 "$zsh_bin" -c '[[ -o nomatch ]] && exit 1 || exit 0'
env -u CURSOR_AGENT PATH="/usr/bin:/bin" "$zsh_bin" -c '[[ -o nomatch ]] || exit 1'
