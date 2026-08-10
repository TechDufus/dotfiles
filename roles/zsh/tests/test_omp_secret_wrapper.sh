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
mkdir -p "$bin_dir"

cat > "$bin_dir/omp" <<'OMP'
#!/usr/bin/env sh
{
  if [ -n "${SECRET_CALLS-}" ]; then
    if [ -s "$SECRET_CALLS" ]; then
      printf 'secret-before-omp=<yes>\n'
    else
      printf 'secret-before-omp=<no>\n'
    fi
  fi
  printf 'sentinel=<%s>\n' "${OMP_SECRET_SENTINEL-}"
  printf 'argc=<%s>\n' "$#"
  for arg in "$@"; do
    printf 'arg=<%s>\n' "$arg"
  done
} >> "$OMP_CALLS"
OMP
chmod +x "$bin_dir/omp"

no_marker_calls="$tmp_dir/no-marker.calls"
: > "$no_marker_calls"
PATH="$bin_dir:$PATH" \
OMP_BIN="$bin_dir/omp" \
OMP_CALLS="$no_marker_calls" \
REPO_ROOT="$repo_root" \
OMP_SECRET_SENTINEL='' \
"$zsh_bin" -f <<'ZSH'
unset OMP_HERD_LOAD_SECRETS
source "$REPO_ROOT/roles/zsh/files/zsh/vars.secret_functions.zsh"

if (( ${+functions[omp]} )); then
  print -ru2 -- "omp wrapper installed without marker"
  exit 1
fi
if [[ "$(whence -p omp)" != "$OMP_BIN" ]]; then
  print -ru2 -- "ordinary omp resolution changed without marker"
  exit 1
fi

typeset -g secret_calls=0
function secret() {
  secret_calls=$(( secret_calls + 1 ))
  return 1
}

omp 'ordinary argument'
if (( secret_calls != 0 )); then
  print -ru2 -- "secret ran without marker"
  exit 1
fi

expected=$'sentinel=<>\nargc=<1>\narg=<ordinary argument>'
if [[ "$(<"$OMP_CALLS")" != "$expected" ]]; then
  print -ru2 -- "ordinary omp argv changed without marker"
  exit 1
fi
ZSH

success_calls="$tmp_dir/success.calls"
success_secret_calls="$tmp_dir/success.secret.calls"
success_stdout="$tmp_dir/success.stdout"
success_stderr="$tmp_dir/success.stderr"
: > "$success_calls"
: > "$success_secret_calls"
PATH="$bin_dir:$PATH" \
OMP_BIN="$bin_dir/omp" \
OMP_CALLS="$success_calls" \
SECRET_CALLS="$success_secret_calls" \
REPO_ROOT="$repo_root" \
"$zsh_bin" -f >"$success_stdout" 2>"$success_stderr" <<'ZSH'
typeset -gx OMP_HERD_LOAD_SECRETS=1
source "$REPO_ROOT/roles/zsh/files/zsh/vars.secret_functions.zsh"

if (( ${+OMP_HERD_LOAD_SECRETS} )); then
  print -ru2 -- "secret marker was not consumed"
  exit 1
fi
if (( ! ${+functions[omp]} )); then
  print -ru2 -- "omp wrapper was not installed"
  exit 1
fi

typeset -g secret_calls=0
function secret() {
  secret_calls=$(( secret_calls + 1 ))
  print -r -- 'fake success secret stdout'
  print -ru2 -- 'fake success secret stderr'
  print -r -- called >> "$SECRET_CALLS"
  export OMP_SECRET_SENTINEL='fake-exported-sentinel'
}

omp 'two words' '' '--literal=*?[x]' 'dollar$semi;quotes"'
if (( secret_calls != 1 )); then
  print -ru2 -- "secret did not run exactly once"
  exit 1
fi
if (( ${+functions[omp]} )); then
  print -ru2 -- "omp wrapper was not removed"
  exit 1
fi

expected=$'secret-before-omp=<yes>\nsentinel=<fake-exported-sentinel>\nargc=<4>\narg=<two words>\narg=<>\narg=<--literal=*?[x]>\narg=<dollar$semi;quotes">'
if [[ "$(<"$OMP_CALLS")" != "$expected" ]]; then
  print -ru2 -- "omp did not receive original argv and exported sentinel"
  exit 1
fi

omp 'after wrapper'
if (( secret_calls != 1 )); then
  print -ru2 -- "secret ran after one-shot wrapper removal"
  exit 1
fi
expected+=$'\nsecret-before-omp=<yes>\nsentinel=<fake-exported-sentinel>\nargc=<1>\narg=<after wrapper>'
if [[ "$(<"$OMP_CALLS")" != "$expected" ]]; then
  print -ru2 -- "ordinary omp resolution was not restored"
  exit 1
fi
ZSH

if [[ -s "$success_stdout" || -s "$success_stderr" ]]; then
  echo "secret output leaked after successful loading" >&2
  exit 1
fi
if [[ "$(<"$success_secret_calls")" != 'called' ]]; then
  echo "secret success call log was unexpected" >&2
  exit 1
fi

failure_calls="$tmp_dir/failure.calls"
failure_stdout="$tmp_dir/failure.stdout"
failure_stderr="$tmp_dir/failure.stderr"
: > "$failure_calls"
PATH="$bin_dir:$PATH" \
OMP_CALLS="$failure_calls" \
REPO_ROOT="$repo_root" \
"$zsh_bin" -f >"$failure_stdout" 2>"$failure_stderr" <<'ZSH'
typeset -gx OMP_HERD_LOAD_SECRETS=1
source "$REPO_ROOT/roles/zsh/files/zsh/vars.secret_functions.zsh"

typeset -g secret_attempts=0
function secret() {
  secret_attempts=$(( secret_attempts + 1 ))
  if (( secret_attempts == 1 )); then
    print -r -- 'fake secret stdout'
    print -ru2 -- 'fake secret stderr'
    return 23
  fi
  export OMP_SECRET_SENTINEL='retry-exported-sentinel'
}

if omp 'failed-secret-argument'; then
  print -ru2 -- "omp succeeded after secret failure"
  exit 1
fi
if (( ! ${+functions[omp]} )); then
  print -ru2 -- "omp wrapper was removed after secret failure"
  exit 1
fi

omp 'retry argument'
if (( secret_attempts != 2 )); then
  print -ru2 -- "secret was not retried exactly once"
  exit 1
fi
if (( ${+functions[omp]} )); then
  print -ru2 -- "omp wrapper remained after successful retry"
  exit 1
fi
ZSH

if [[ -s "$failure_stdout" ]]; then
  echo "secret stdout leaked after failed loading" >&2
  exit 1
fi

expected=$'sentinel=<retry-exported-sentinel>\nargc=<1>\narg=<retry argument>'
if [[ "$(<"$failure_calls")" != "$expected" ]]; then
  echo "external omp did not run exactly once after successful secret retry" >&2
  exit 1
fi
if [[ "$(<"$failure_stderr")" != 'Error: unable to load secrets; OMP was not started' ]]; then
  echo "secret failure error was not generic and values-free" >&2
  exit 1
fi
