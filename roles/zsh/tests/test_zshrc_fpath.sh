#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
zsh_bin="${ZSH_BIN:-zsh}"

if ! command -v "$zsh_bin" >/dev/null; then
  echo "zsh is required for this test" >&2
  exit 1
fi
zsh_bin="$(command -v "$zsh_bin")"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

home_dir="$tmp_dir/home"
no_zoxide_bin="$tmp_dir/no-zoxide-bin"
data_dir="$tmp_dir/data"
bin_dir="$tmp_dir/bin"
stale_fpath="$tmp_dir/stale-zsh-functions"

mkdir -p \
  "$home_dir/.config/zsh" \
  "$data_dir/zinit/zinit.git" \
  "$data_dir/zinit/completions" \
  "$bin_dir" \
  "$no_zoxide_bin" \
  "$stale_fpath"

printf ': noop\n' > "$home_dir/.config/zsh/noop.zsh"
cp "$repo_root/roles/zsh/files/.zshrc" "$home_dir/.zshrc"

cat > "$data_dir/zinit/zinit.git/zinit.zsh" <<'ZINIT'
for fn in is-at-least colors add-zsh-hook bashcompinit compinit _main_complete _approximate; do
  found=0
  for dir in $fpath; do
    [[ -r "$dir/$fn" ]] && found=1
  done
  if (( ! found )); then
    print -ru2 "missing zsh function before zinit load: $fn"
    exit 125
  fi
done

zinit() { :; }
alias zi='zinit'
ZINIT

cat > "$bin_dir/zoxide" <<'ZOXIDE'
#!/usr/bin/env sh
if [ "${1:-}" = "init" ] && [ "${2:-}" = "zsh" ]; then
  printf '%s\n' 'zoxide() { :; }'
fi
ZOXIDE
ln -s "$(command -v find)" "$no_zoxide_bin/find"
chmod +x "$bin_dir/zoxide"

# shellcheck disable=SC2016
HOME="$home_dir" \
XDG_DATA_HOME="$data_dir" \
ZDOTDIR="$home_dir" \
PATH="$bin_dir:$PATH" \
FPATH="$stale_fpath" \
"$zsh_bin" -i -c '
  for fn in is-at-least colors add-zsh-hook bashcompinit compinit _main_complete _approximate; do
    found=0
    for dir in $fpath; do
      [[ -r "$dir/$fn" ]] && found=1
    done
    if (( ! found )); then
      print -ru2 "missing zsh function after startup: $fn"
      exit 1
    fi
  done

  if [[ ${(t)FPATH} == *export* ]]; then
    print -ru2 "FPATH is still exported: ${(t)FPATH}"
    exit 1
  fi
'

startup_output="$(
  HOME="$home_dir" \
  XDG_DATA_HOME="$data_dir" \
  ZDOTDIR="$home_dir" \
  PATH="$no_zoxide_bin" \
  FPATH="$stale_fpath" \
  "$zsh_bin" -i -c ':' 2>&1
)"
if [[ "$startup_output" == *zoxide* ]]; then
  printf '%s\n' "$startup_output" >&2
  exit 1
fi
