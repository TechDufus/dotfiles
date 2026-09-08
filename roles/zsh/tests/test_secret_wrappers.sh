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
tool_calls="$tmp_dir/tool.calls"
op_calls="$tmp_dir/op.calls"
mkdir -p "$home_dir/.config/zsh" "$state_dir/zsh" "$data_dir" "$cache_dir" "$bin_dir"
chmod 700 "$state_dir/zsh"
cp "$repo_root/roles/zsh/files/.zshenv" "$home_dir/.zshenv"
cp "$repo_root/roles/zsh/files/zsh/paths_functions.zsh" "$home_dir/.config/zsh/paths_functions.zsh"
cp "$repo_root/roles/zsh/files/zsh/paths_vars.zsh" "$home_dir/.config/zsh/paths_vars.zsh"
cp "$repo_root/roles/zsh/files/zsh/vars.secret_functions.zsh" \
  "$home_dir/.config/zsh/vars.secret_functions.zsh"

cat > "$state_dir/zsh/secrets.zsh" <<'CACHE'
export DIRECT_TOOL_CACHE_DUMMY='private-cache-value'
CACHE
chmod 600 "$state_dir/zsh/secrets.zsh"

for tool in gh aws omp; do
  cat > "$bin_dir/$tool" <<'TOOL'
#!/usr/bin/env sh
printf '%s cache=<%s> inherited=<%s> argc=<%s>\n' \
  "$(basename "$0")" "${DIRECT_TOOL_CACHE_DUMMY-}" "${DIRECT_TOOL_INHERITED_DUMMY-}" "$#" >> "$TOOL_CALLS"
TOOL
  chmod +x "$bin_dir/$tool"
done

cat > "$bin_dir/op" <<'OP'
#!/usr/bin/env sh
printf 'op %s\n' "$*" >> "$OP_CALLS"
exit 99
OP
chmod +x "$bin_dir/op"

common_env=(
  "HOME=$home_dir"
  "ZDOTDIR=$home_dir"
  "XDG_STATE_HOME=$state_dir"
  "XDG_DATA_HOME=$data_dir"
  "XDG_CACHE_HOME=$cache_dir"
  "XDG_CONFIG_HOME=$home_dir/.config"
  "PATH=$bin_dir:/usr/bin:/bin"
  "TERM=dumb"
  "TOOL_CALLS=$tool_calls"
  "OP_CALLS=$op_calls"
)

: > "$tool_calls"
: > "$op_calls"
env -i \
  "${common_env[@]}" "$zsh_bin" -i -c '
    source "$HOME/.config/zsh/vars.secret_functions.zsh"
    for tool in gh aws omp; do
      (( ! ${+functions[$tool]} )) || { print -ru2 -- "$tool intercepted direct execution"; exit 1; }
    done
    gh status
    aws configure list
    omp --help
  '

expected=$'gh cache=<private-cache-value> inherited=<> argc=<1>\naws cache=<private-cache-value> inherited=<> argc=<2>\nomp cache=<private-cache-value> inherited=<> argc=<1>'
if [[ "$(<"$tool_calls")" != "$expected" ]]; then
  echo "direct tools did not receive the ordinary cache environment" >&2
  cat "$tool_calls" >&2
  exit 1
fi
if [[ -s "$op_calls" ]]; then
  echo "direct tools invoked op" >&2
  cat "$op_calls" >&2
  exit 1
fi

: > "$tool_calls"
env -i \
  CURSOR_AGENT=1 DIRECT_TOOL_INHERITED_DUMMY=agent-inherited \
  "${common_env[@]}" "$zsh_bin" -i -c '
    is_agent_shell() { [[ -n "${CURSOR_AGENT:-}" ]]; }
    source "$HOME/.config/zsh/vars.secret_functions.zsh"
    (( ! ${+functions[gh]} )) || { print -ru2 -- "gh intercepted agent execution"; exit 1; }
    gh status
  '
if [[ "$(<"$tool_calls")" != 'gh cache=<private-cache-value> inherited=<agent-inherited> argc=<1>' ]]; then
  echo "agent-marked direct tool did not inherit the ordinary environment" >&2
  cat "$tool_calls" >&2
  exit 1
fi
if [[ -s "$op_calls" ]]; then
  echo "agent-marked direct tool invoked op" >&2
  cat "$op_calls" >&2
  exit 1
fi
