#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
zsh_bin="${ZSH_BIN:-zsh}"

if ! command -v "$zsh_bin" >/dev/null; then
  echo "SKIP: zsh not installed"
  exit 0
fi
zsh_bin="$(command -v "$zsh_bin")"
unset SECRETS_ALREADY_LOADED SECRETS_LOADED_AT SECRETS_LOADED_VARS SECRETS_LOADED_SIGNATURE \
  OMP_HERD_LOAD_SECRETS CURSOR_AGENT CLAUDECODE CODEX_CI CODEX_SANDBOX

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

bin_dir="$tmp_dir/bin"
home_dir="$tmp_dir/home"
mkdir -p "$bin_dir" "$home_dir/.config/zsh"

cp "$repo_root/roles/zsh/files/zsh/vars.secret_functions.zsh" \
  "$home_dir/.config/zsh/vars.secret_functions.zsh"
printf '%s\n' 'export SECRET_WRAPPER_MARKER=from-file' \
  > "$home_dir/.config/zsh/vars.secret"

cat > "$bin_dir/gh" <<'GH'
#!/usr/bin/env sh
printf 'gh-loaded=<%s> marker=<%s>\n' "${SECRETS_ALREADY_LOADED-}" \
  "${SECRET_WRAPPER_MARKER-}" >> "$WRAPPER_CALLS"
GH
chmod +x "$bin_dir/gh"

cat > "$bin_dir/aws" <<'AWS'
#!/usr/bin/env sh
printf 'aws-loaded=<%s> marker=<%s>\n' "${SECRETS_ALREADY_LOADED-}" \
  "${SECRET_WRAPPER_MARKER-}" >> "$WRAPPER_CALLS"
AWS
chmod +x "$bin_dir/aws"

cat > "$bin_dir/omp" <<'OMP'
#!/usr/bin/env sh
exit 0
OMP
chmod +x "$bin_dir/omp"

# --- active wrappers stay absent outside interactive human shells ---
PATH="$bin_dir:$PATH" \
HOME="$home_dir" \
"$zsh_bin" -f <<'ZSH'
source "$HOME/.config/zsh/vars.secret_functions.zsh"
for tool in gh aws omp; do
  if (( ${+functions[$tool]} )); then
    print -ru2 -- "$tool wrapper installed in non-interactive shell"
    exit 1
  fi
done
ZSH
echo "ok no wrappers in non-interactive shell"

PATH="$bin_dir:$PATH" \
HOME="$home_dir" \
CURSOR_AGENT=1 \
"$zsh_bin" -if -c '
function is_agent_shell() { [[ -n "${CURSOR_AGENT:-}" ]]; }
source "$HOME/.config/zsh/vars.secret_functions.zsh"
for tool in gh aws omp; do
  if (( ${+functions[$tool]} )); then
    print -ru2 -- "$tool wrapper installed in agent shell"
    exit 1
  fi
done
'
echo "ok no wrappers in agent shell"

PATH="$bin_dir:$PATH" \
HOME="$home_dir" \
"$zsh_bin" -if -c '
source "$HOME/.config/zsh/vars.secret_functions.zsh"
for tool in gh aws; do
  if (( ! ${+functions[$tool]} )); then
    print -ru2 -- "$tool wrapper missing from interactive human shell"
    exit 1
  fi
done
if (( ${+functions[omp]} )); then
  print -ru2 -- "OMP wrapper installed without Herd marker"
  exit 1
fi
'
echo "ok interactive human shell installs active wrappers"

# --- each active wrapper loads once, then delegates directly ---
for tool in gh aws; do
  wrapper_calls="$tmp_dir/$tool.calls"
  secret_loads="$tmp_dir/$tool.loads"
  : > "$wrapper_calls"
  : > "$secret_loads"
  PATH="$bin_dir:$PATH" \
  HOME="$home_dir" \
  TOOL="$tool" \
  WRAPPER_CALLS="$wrapper_calls" \
  SECRET_LOADS="$secret_loads" \
  "$zsh_bin" -if -c '
source "$HOME/.config/zsh/vars.secret_functions.zsh"
function secret() {
  print -r -- load >> "$SECRET_LOADS"
  __secret_source_file
}
"$TOOL"
if (( ${+functions[$TOOL]} )); then
  print -ru2 -- "$TOOL wrapper was not removed after loading"
  exit 1
fi
"$TOOL"
'
  if [[ "$(<"$secret_loads")" != 'load' ]]; then
    echo "$tool wrapper did not load secrets exactly once" >&2
    cat "$secret_loads" >&2
    exit 1
  fi
  printf -v expected '%s-loaded=<true> marker=<from-file>\n%s-loaded=<true> marker=<from-file>' \
    "$tool" "$tool"
  if [[ "$(<"$wrapper_calls")" != "$expected" ]]; then
    echo "$tool calls did not inherit the loaded marker" >&2
    cat "$wrapper_calls" >&2
    exit 1
  fi
  echo "ok lazy $tool wrapper"
done

echo "ok secret wrappers"
