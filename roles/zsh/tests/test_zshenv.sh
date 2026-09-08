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

home_dir="$tmp_dir/home"
state_dir="$tmp_dir/state"
data_dir="$tmp_dir/data"
cache_dir="$tmp_dir/cache"
bin_dir="$tmp_dir/bin"
secret_cache="$state_dir/zsh/secrets.zsh"
mkdir -p "$home_dir/.config/zsh" "$home_dir/.bun/bin" "$home_dir/.local/bin" \
  "$home_dir/go/bin" "$state_dir/zsh" "$data_dir" "$cache_dir" "$bin_dir"
chmod 700 "$state_dir/zsh"
cp "$repo_root/roles/zsh/files/.zshenv" "$home_dir/.zshenv"
cp "$repo_root/roles/zsh/files/zsh/paths_functions.zsh" "$home_dir/.config/zsh/paths_functions.zsh"
cp "$repo_root/roles/zsh/files/zsh/paths_vars.zsh" "$home_dir/.config/zsh/paths_vars.zsh"
cp "$repo_root/roles/zsh/files/zsh/nvm_config.zsh" "$home_dir/.config/zsh/nvm_config.zsh"

cat > "$secret_cache" <<'CACHE'
export ZSHENV_CACHE_DUMMY='cache-visible'
print -- 'cache-output-must-stay-silent'
CACHE
chmod 600 "$secret_cache"

common_env=(
  "HOME=$home_dir"
  "ZDOTDIR=$home_dir"
  "XDG_STATE_HOME=$state_dir"
  "XDG_DATA_HOME=$data_dir"
  "XDG_CACHE_HOME=$cache_dir"
  "XDG_CONFIG_HOME=$home_dir/.config"
  "PATH=$bin_dir:/usr/bin:/bin"
  "TERM=dumb"
)

run_clean_zsh() {
  env -i "${common_env[@]}" "$zsh_bin" "$@"
}

run_clean_zsh_at_state() {
  local alternate_state_dir="$1"
  local -a alternate_env=("${common_env[@]}")
  shift
  alternate_env[2]="XDG_STATE_HOME=$alternate_state_dir"
  env -i "${alternate_env[@]}" "$zsh_bin" "$@"
}

run_clean_zsh -c '[[ -o nomatch ]] || exit 1'
if ! safe_startup_output="$(run_clean_zsh -c '
  [[ "$PATH" == *"$HOME/.bun/bin"* ]] || { print -ru2 "missing bun bin"; exit 1; }
  [[ "$PATH" == *"$HOME/.local/bin"* ]] || { print -ru2 "missing local bin"; exit 1; }
  [[ "$PATH" == *"$HOME/go/bin"* ]] || { print -ru2 "missing go bin"; exit 1; }
  [[ "$ZSHENV_CACHE_DUMMY" == cache-visible ]] || { print -ru2 "safe cache was not loaded"; exit 1; }
  (( $+functions[load-nvmrc] )) && { print -ru2 "zshenv sourced nvm hook"; exit 1; }
  (( $+functions[secret] )) && { print -ru2 "zshenv loaded secret functions"; exit 1; }
  exit 0
' 2>&1)"; then
  printf '%s\n' "$safe_startup_output" >&2
  exit 1
fi
if [[ -n "$safe_startup_output" ]]; then
  echo "safe cache produced startup output" >&2
  exit 1
fi

env -i \
  CURSOR_AGENT=1 ZSHENV_INHERITED_DUMMY=survives-agent-marker \
  "${common_env[@]}" "$zsh_bin" -c '
    [[ -o nomatch ]] && exit 1
    [[ "$ZSHENV_CACHE_DUMMY" == cache-visible ]] || exit 1
    [[ "$ZSHENV_INHERITED_DUMMY" == survives-agent-marker ]] || exit 1
  '

xtrace_output="$(run_clean_zsh -x -c '[[ -o xtrace ]]' 2>&1)"
if [[ "$xtrace_output" == *cache-visible* ]]; then
  echo "xtrace exposed a cache value" >&2
  exit 1
fi
verbose_output="$(run_clean_zsh -v -c '[[ -o verbose ]]' 2>&1)"
if [[ "$verbose_output" == *cache-visible* ]]; then
  echo "verbose startup exposed a cache value" >&2
  exit 1
fi

rm -f "$secret_cache"
if ! run_clean_zsh -c '[[ -z ${ZSHENV_CACHE_DUMMY+x} ]]' >"$tmp_dir/missing.out" 2>"$tmp_dir/missing.err"; then
  echo "missing cache broke startup" >&2
  exit 1
fi
if [[ -s "$tmp_dir/missing.out" || -s "$tmp_dir/missing.err" ]]; then
  echo "missing cache produced startup output" >&2
  exit 1
fi

# Private cache files are still unsafe below a swappable ancestor.
shared_parent="$tmp_dir/shared-parent"
shared_state_dir="$shared_parent/state"
mkdir -p "$shared_state_dir/zsh"
chmod 777 "$shared_parent"
chmod 700 "$shared_state_dir" "$shared_state_dir/zsh"
printf '%s\n' "export ZSHENV_ANCESTOR_DUMMY='trusted-sticky-cache'" \
  > "$shared_state_dir/zsh/secrets.zsh"
chmod 600 "$shared_state_dir/zsh/secrets.zsh"
if ! ancestor_output="$(
  run_clean_zsh_at_state "$shared_state_dir" \
    -c '[[ -z ${ZSHENV_ANCESTOR_DUMMY+x} ]]' 2>&1
)"; then
  echo "non-sticky writable ancestor was accepted or broke startup" >&2
  exit 1
fi
if [[ -n "$ancestor_output" ]]; then
  echo "unsafe ancestor produced startup output" >&2
  exit 1
fi

# Sticky protection is sufficient when the parent and child have trusted owners.
chmod 1777 "$shared_parent"
if ! sticky_output="$(
  run_clean_zsh_at_state "$shared_state_dir" \
    -c '[[ "$ZSHENV_ANCESTOR_DUMMY" == trusted-sticky-cache ]]' 2>&1
)"; then
  echo "trusted sticky ancestor prevented safe cache loading" >&2
  exit 1
fi
if [[ -n "$sticky_output" ]]; then
  echo "safe sticky ancestor produced startup output" >&2
  exit 1
fi

worktree_state_dir="$tmp_dir/worktree/.local/state"
mkdir -p "$worktree_state_dir/zsh" "$tmp_dir/worktree/.git"
chmod 700 "$worktree_state_dir/zsh"
printf '%s\n' "export ZSHENV_WORKTREE_DUMMY='worktree'" \
  > "$worktree_state_dir/zsh/secrets.zsh"
chmod 600 "$worktree_state_dir/zsh/secrets.zsh"
if ! worktree_output="$(
  run_clean_zsh_at_state "$worktree_state_dir" \
    -c '[[ -z ${ZSHENV_WORKTREE_DUMMY+x} ]]' 2>&1
)"; then
  echo "worktree cache broke startup" >&2
  exit 1
fi
if [[ -n "$worktree_output" ]]; then
  echo "worktree cache produced startup output" >&2
  exit 1
fi

redirect_target_state_dir="$tmp_dir/redirect-target"
redirect_state_dir="$tmp_dir/redirect-state"
mkdir -p "$redirect_target_state_dir/zsh"
chmod 700 "$redirect_target_state_dir/zsh"
ln -s "$redirect_target_state_dir" "$redirect_state_dir"
printf '%s\n' "export ZSHENV_REDIRECT_DUMMY='redirected'" \
  > "$redirect_target_state_dir/zsh/secrets.zsh"
chmod 600 "$redirect_target_state_dir/zsh/secrets.zsh"
if ! redirect_output="$(
  run_clean_zsh_at_state "$redirect_state_dir" \
    -c '[[ -z ${ZSHENV_REDIRECT_DUMMY+x} ]]' 2>&1
)"; then
  echo "redirected cache broke startup" >&2
  exit 1
fi
if [[ -n "$redirect_output" ]]; then
  echo "redirected cache produced startup output" >&2
  exit 1
fi

rm -f "$secret_cache"

printf '%s\n' "export ZSHENV_UNSAFE_DUMMY='symlink'" > "$tmp_dir/unsafe-target.zsh"
ln -s "$tmp_dir/unsafe-target.zsh" "$secret_cache"
if ! run_clean_zsh -c '[[ -z ${ZSHENV_UNSAFE_DUMMY+x} ]]' >"$tmp_dir/symlink.out" 2>"$tmp_dir/symlink.err"; then
  echo "symlink cache broke startup" >&2
  exit 1
fi
if [[ -s "$tmp_dir/symlink.out" || -s "$tmp_dir/symlink.err" ]]; then
  echo "symlink cache produced startup output" >&2
  exit 1
fi

rm -f "$secret_cache"
printf '%s\n' "export ZSHENV_UNSAFE_DUMMY='group-readable'" > "$secret_cache"
chmod 640 "$secret_cache"
if ! run_clean_zsh -c '[[ -z ${ZSHENV_UNSAFE_DUMMY+x} ]]' >"$tmp_dir/mode.out" 2>"$tmp_dir/mode.err"; then
  echo "group-readable cache broke startup" >&2
  exit 1
fi
if [[ -s "$tmp_dir/mode.out" || -s "$tmp_dir/mode.err" ]]; then
  echo "group-readable cache produced startup output" >&2
  exit 1
fi
