#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
zsh_bin="${ZSH_BIN:-zsh}"

if ! command -v "$zsh_bin" >/dev/null; then
  echo "SKIP: zsh not installed"
  exit 0
fi
if ! command -v script >/dev/null; then
  echo "SKIP: script not installed"
  exit 0
fi
zsh_bin="$(command -v "$zsh_bin")"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

home_dir="$tmp_dir/home"
data_dir="$tmp_dir/data"
cache_dir="$tmp_dir/cache"
state_dir="$tmp_dir/state"
zinit_dir="$data_dir/zinit/zinit.git"

mkdir -p \
  "$home_dir/.config/zsh" \
  "$cache_dir" \
  "$state_dir" \
  "$zinit_dir" \
  "$data_dir/zinit/completions"

cp "$repo_root/roles/zsh/files/.zshrc" "$home_dir/.zshrc"
: > "$home_dir/.config/zsh/noop.zsh"

cat > "$zinit_dir/zinit.zsh" <<'ZINIT'
zinit() {
  if [[ "$*" == "light romkatv/powerlevel10k" ]]; then
    p10k() { :; }
    _p9k_precmd() { :; }
    PROMPT='p10k> '
  fi
}
alias zi='zinit'
ZINIT

stdin_file="$tmp_dir/stdin.zsh"
: > "$stdin_file"
check='(( $+functions[p10k] )) && (( $+functions[_p9k_precmd] )) && [[ $PROMPT == p10k\>\  ]]'

run_pty() {
  local cmd="$1"
  local -a fixture_env=(env -i HOME="$home_dir" ZDOTDIR="$home_dir"
    XDG_DATA_HOME="$data_dir" XDG_CACHE_HOME="$cache_dir" XDG_STATE_HOME="$state_dir"
    PATH=/usr/bin:/bin TERM=xterm-256color SHELL=/bin/sh)
  case "$(uname -s)" in
    Darwin) "${fixture_env[@]}" script -q /dev/null sh -c "$cmd" >/dev/null ;;
    *) "${fixture_env[@]}" script -qfc "$cmd" /dev/null >/dev/null ;;
  esac
}

# shellcheck disable=SC2016
run_pty "env -i TERM=xterm-256color HOME='$home_dir' XDG_DATA_HOME='$data_dir' XDG_CACHE_HOME='$cache_dir' XDG_STATE_HOME='$state_dir' ZDOTDIR='$home_dir' PATH='/usr/bin:/bin' '$zsh_bin' -i -c '$check'"
run_pty "env -i TERM=xterm-256color HOME='$home_dir' XDG_DATA_HOME='$data_dir' XDG_CACHE_HOME='$cache_dir' XDG_STATE_HOME='$state_dir' ZDOTDIR='$home_dir' PATH='/usr/bin:/bin' '$zsh_bin' -i -c '$check' < '$stdin_file'"
run_pty "env -i TERM=xterm-256color HOME='$home_dir' XDG_DATA_HOME='$data_dir' XDG_CACHE_HOME='$cache_dir' XDG_STATE_HOME='$state_dir' ZDOTDIR='$home_dir' PATH='/usr/bin:/bin' '$zsh_bin' -i -c '$check' > '$tmp_dir/stdout' 2> '$tmp_dir/stderr'"
