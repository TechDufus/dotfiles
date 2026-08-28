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
mkdir -p "$HOME/.config/zsh" "$HOME/.bun/bin" "$HOME/.local/bin" "$HOME/go/bin"
cp "$repo_root/roles/zsh/files/.zshenv" "$HOME/.zshenv"
cp "$repo_root/roles/zsh/files/zsh/paths_functions.zsh" "$HOME/.config/zsh/paths_functions.zsh"
cp "$repo_root/roles/zsh/files/zsh/paths_vars.zsh" "$HOME/.config/zsh/paths_vars.zsh"
cp "$repo_root/roles/zsh/files/zsh/nvm_config.zsh" "$HOME/.config/zsh/nvm_config.zsh"

env -u CURSOR_AGENT PATH="/usr/bin:/bin" CURSOR_AGENT=1 "$zsh_bin" -c '[[ -o nomatch ]] && exit 1 || exit 0'
env -u CURSOR_AGENT PATH="/usr/bin:/bin" CLAUDECODE=1 "$zsh_bin" -c '[[ -o nomatch ]] && exit 1 || exit 0'
env -u CURSOR_AGENT PATH="/usr/bin:/bin" "$zsh_bin" -c '[[ -o nomatch ]] || exit 1'
env -u CURSOR_AGENT PATH="/usr/bin:/bin" "$zsh_bin" -c '
  [[ "$PATH" == *"$HOME/.bun/bin"* ]] || { print -ru2 "missing bun bin"; exit 1; }
  [[ "$PATH" == *"$HOME/.local/bin"* ]] || { print -ru2 "missing local bin"; exit 1; }
  [[ "$PATH" == *"$HOME/go/bin"* ]] || { print -ru2 "missing go bin"; exit 1; }
  (( $+functions[load-nvmrc] )) && { print -ru2 "zshenv sourced nvm hook"; exit 1; }
  exit 0
'
