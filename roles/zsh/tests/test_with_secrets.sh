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

bin_dir="$tmp_dir/bin"
home_dir="$tmp_dir/home"
mkdir -p "$bin_dir" "$home_dir/.config/zsh" "$home_dir/.local/bin"

cp "$repo_root/roles/zsh/files/zsh/vars.secret_functions.zsh" \
  "$home_dir/.config/zsh/vars.secret_functions.zsh"
cp "$repo_root/roles/zsh/files/bin/with-secrets" "$home_dir/.local/bin/with-secrets"
chmod +x "$home_dir/.local/bin/with-secrets"
printf '%s\n' 'export WITH_SECRETS_SENTINEL=from-file' > "$home_dir/.config/zsh/vars.secret"

cat > "$bin_dir/op" <<'OP'
#!/usr/bin/env sh
if [ "${1-}" = "vault" ]; then
  exit 0
fi
exit 1
OP
chmod +x "$bin_dir/op"

cat > "$bin_dir/probe" <<'PROBE'
#!/usr/bin/env sh
{
  printf 'sentinel=<%s>\n' "${WITH_SECRETS_SENTINEL-}"
  printf 'loaded=<%s>\n' "${SECRETS_ALREADY_LOADED-}"
  printf 'argc=<%s>\n' "$#"
  for arg in "$@"; do
    printf 'arg=<%s>\n' "$arg"
  done
} >> "$PROBE_CALLS"
PROBE
chmod +x "$bin_dir/probe"

cat > "$bin_dir/gh" <<'GH'
#!/usr/bin/env sh
printf 'gh-loaded=<%s>\n' "${SECRETS_ALREADY_LOADED-}" >> "$GH_CALLS"
GH
chmod +x "$bin_dir/gh"

cat > "$bin_dir/omp" <<'OMP'
#!/usr/bin/env sh
printf 'omp-ran=<%s>\n' "${SECRETS_ALREADY_LOADED-}" >> "${OMP_CALLS:-/dev/null}"
OMP
chmod +x "$bin_dir/omp"

# --- function: skip does not call secret, execs command ---
skip_calls="$tmp_dir/skip.calls"
: > "$skip_calls"
PATH="$bin_dir:$PATH" \
HOME="$home_dir" \
PROBE_CALLS="$skip_calls" \
REPO_ROOT="$repo_root" \
"$zsh_bin" -f <<'ZSH'
source "$HOME/.config/zsh/vars.secret_functions.zsh"
typeset -g secret_calls=0
function secret() {
  secret_calls=$(( secret_calls + 1 ))
  return 1
}
ORCA_SKIP_SECRETS=1
with-secrets probe 'two words'
print -ru2 -- "with-secrets returned after skip exec"
exit 1
ZSH
if [[ "$(<"$skip_calls")" != $'sentinel=<>\nloaded=<>\nargc=<1>\narg=<two words>' ]]; then
  echo "skip path did not exec probe with original argv" >&2
  cat "$skip_calls" >&2
  exit 1
fi
echo "ok skip exec"

# --- function: load once, inherit, exec ---
load_calls="$tmp_dir/load.calls"
load_stdout="$tmp_dir/load.stdout"
load_stderr="$tmp_dir/load.stderr"
: > "$load_calls"
PATH="$bin_dir:$PATH" \
HOME="$home_dir" \
PROBE_CALLS="$load_calls" \
"$zsh_bin" -f >"$load_stdout" 2>"$load_stderr" <<'ZSH' || true
source "$HOME/.config/zsh/vars.secret_functions.zsh"
with-secrets probe '' '--literal=*?[x]'
print -ru2 -- "with-secrets returned after exec"
exit 1
ZSH
if [[ "$(<"$load_calls")" != $'sentinel=<from-file>\nloaded=<true>\nargc=<2>\narg=<>\narg=<--literal=*?[x]>' ]]; then
  echo "load path did not exec probe with inherited secrets" >&2
  cat "$load_calls" >&2
  echo "stdout:" >&2
  cat "$load_stdout" >&2
  echo "stderr:" >&2
  cat "$load_stderr" >&2
  exit 1
fi
if [[ -s "$load_stdout" ]]; then
  echo "quiet load leaked stdout" >&2
  cat "$load_stdout" >&2
  exit 1
fi
echo "ok function exec inherit"

# --- function: fail closed ---
fail_stdout="$tmp_dir/fail.stdout"
fail_stderr="$tmp_dir/fail.stderr"
PATH="$bin_dir:$PATH" \
HOME="$home_dir" \
"$zsh_bin" -f >"$fail_stdout" 2>"$fail_stderr" <<'ZSH' || true
source "$HOME/.config/zsh/vars.secret_functions.zsh"
function secret() {
  print -r -- 'secret stdout'
  print -ru2 -- 'secret stderr'
  return 23
}
if with-secrets probe fail-arg; then
  print -ru2 -- "with-secrets succeeded after secret failure"
  exit 1
fi
ZSH
if [[ -s "$fail_stdout" ]]; then
  echo "failed with-secrets leaked stdout" >&2
  cat "$fail_stdout" >&2
  exit 1
fi
if [[ "$(<"$fail_stderr")" != 'Error: unable to load secrets' ]]; then
  echo "failed with-secrets error was not generic" >&2
  cat "$fail_stderr" >&2
  exit 1
fi
echo "ok function fail closed"

# --- launcher script ---
script_calls="$tmp_dir/script.calls"
: > "$script_calls"
PATH="$bin_dir:$PATH" \
HOME="$home_dir" \
PROBE_CALLS="$script_calls" \
"$home_dir/.local/bin/with-secrets" probe 'script arg'
if [[ "$(<"$script_calls")" != $'sentinel=<from-file>\nloaded=<true>\nargc=<1>\narg=<script arg>' ]]; then
  echo "with-secrets script did not exec with inherited secrets" >&2
  cat "$script_calls" >&2
  exit 1
fi
echo "ok script exec inherit"

script_skip="$tmp_dir/script-skip.calls"
: > "$script_skip"
PATH="$bin_dir:$PATH" \
HOME="$home_dir" \
PROBE_CALLS="$script_skip" \
ORCA_SKIP_SECRETS=1 \
"$home_dir/.local/bin/with-secrets" probe skipped
if [[ "$(<"$script_skip")" != $'sentinel=<>\nloaded=<>\nargc=<1>\narg=<skipped>' ]]; then
  echo "with-secrets script skip still loaded secrets" >&2
  cat "$script_skip" >&2
  exit 1
fi
echo "ok script skip"

if "$home_dir/.local/bin/with-secrets" >/dev/null 2>"$tmp_dir/script-usage.err"; then
  echo "with-secrets script accepted no command" >&2
  exit 1
fi
if ! grep -q 'Usage: with-secrets' "$tmp_dir/script-usage.err"; then
  echo "with-secrets script missing usage" >&2
  cat "$tmp_dir/script-usage.err" >&2
  exit 1
fi
echo "ok script usage"

# --- no wrappers in non-interactive shells ---
PATH="$bin_dir:$PATH" \
HOME="$home_dir" \
ORCA_PANE_KEY=pane-1 \
"$zsh_bin" -f <<'ZSH'
source "$HOME/.config/zsh/vars.secret_functions.zsh"
if (( ${+functions[gh]} )); then
  print -ru2 -- "gh wrapper installed in non-interactive shell"
  exit 1
fi
if (( ${+functions[omp]} )); then
  print -ru2 -- "omp wrapper installed in non-interactive Orca shell"
  exit 1
fi
ZSH
echo "ok no non-interactive wrappers"

# --- interactive Orca wraps agents, not in agent shells ---
PATH="$bin_dir:$PATH" \
HOME="$home_dir" \
ORCA_PANE_KEY=pane-1 \
"$zsh_bin" -if -c '
source "$HOME/.config/zsh/vars.secret_functions.zsh"
if (( ! ${+functions[omp]} )); then
  print -ru2 -- "interactive Orca shell did not wrap omp"
  exit 1
fi
if (( ! ${+functions[gh]} )); then
  print -ru2 -- "interactive shell did not wrap gh"
  exit 1
fi
'
echo "ok interactive Orca wrappers"

PATH="$bin_dir:$PATH" \
HOME="$home_dir" \
ORCA_PANE_KEY=pane-1 \
CURSOR_AGENT=1 \
"$zsh_bin" -if -c '
function is_agent_shell() { [[ -n "${CURSOR_AGENT:-}" ]]; }
source "$HOME/.config/zsh/vars.secret_functions.zsh"
if (( ${+functions[gh]} )); then
  print -ru2 -- "agent shell wrapped gh"
  exit 1
fi
if (( ${+functions[omp]} )); then
  print -ru2 -- "agent shell wrapped omp"
  exit 1
fi
'
echo "ok agent shell skips wrappers"

# --- lazy gh in interactive shell loads once ---
gh_calls="$tmp_dir/gh.calls"
: > "$gh_calls"
PATH="$bin_dir:$PATH" \
HOME="$home_dir" \
GH_CALLS="$gh_calls" \
"$zsh_bin" -if -c '
source "$HOME/.config/zsh/vars.secret_functions.zsh"
gh
if (( ${+functions[gh]} )); then
  print -ru2 -- "gh wrapper was not removed after success"
  exit 1
fi
gh
'
if [[ "$(<"$gh_calls")" != $'gh-loaded=<true>\ngh-loaded=<true>' ]]; then
  echo "lazy gh did not inherit secrets on both calls" >&2
  cat "$gh_calls" >&2
  exit 1
fi
echo "ok lazy gh"

echo "ok with-secrets"
