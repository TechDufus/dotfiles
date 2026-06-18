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
calls="$tmp_dir/omp.calls"
mkdir -p "$bin_dir"
: > "$calls"

cat > "$bin_dir/omp" <<'OMP'
#!/usr/bin/env sh
printf '%s\n' "$*" >> "$OMP_CALLS"
if [ "$1" = "completions" ] && [ "$2" = "zsh" ]; then
  printf '%s\n' '_omp() { print -r -- completed >> "$OMP_CALLS"; }'
else
  exit 2
fi
OMP
chmod +x "$bin_dir/omp"

OMP_CALLS="$calls" \
PATH="$bin_dir:$PATH" \
REPO_ROOT="$repo_root" \
"$zsh_bin" -f <<'ZSH'
set -e

compdef() {
  [[ "$1" == "_omp_lazy_completion" && "$2" == "omp" ]]
  typeset -g OMP_COMPDEF_REGISTERED=1
}

source "$REPO_ROOT/roles/zsh/files/zsh/omp_completions.zsh"

if (( ! OMP_COMPDEF_REGISTERED )); then
  print -ru2 "omp completion was not registered"
  exit 1
fi

if [[ -s "$OMP_CALLS" ]]; then
  print -ru2 "omp was invoked during shell startup"
  exit 1
fi

_omp_lazy_completion
actual="$(<"$OMP_CALLS")"
expected=$'completions zsh\ncompleted'
if [[ "$actual" != "$expected" ]]; then
  print -ru2 "unexpected omp calls: $actual"
  exit 1
fi
ZSH
