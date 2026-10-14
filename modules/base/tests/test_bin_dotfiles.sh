#!/usr/bin/env bash
# Runs the real bin/dotfiles in a sandbox (temp HOME/XDG/DOTFILES_DIR/DOTFILES_SYSROOT,
# stub mise/uname/brew first on PATH). No network, no sudo, nothing outside the temp dir.
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BIN=$(cd "$HERE/../../.." && pwd)/bin/dotfiles
ORIG_PATH=$PATH
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

export HOME="$T/home" GIT_CONFIG_NOSYSTEM=1
mkdir -p "$HOME" "$T/stub"
REAL_UNAME=$(command -v uname)

cat >"$T/stub/mise" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" >"$MISE_ARGV_FILE"
exit 0
EOF
cat >"$T/stub/uname" <<'EOF'
#!/bin/sh
case "$1" in
  -s) [ -z "${STUB_UNAME_S:-}" ] || { echo "$STUB_UNAME_S"; exit 0; } ;;
  -m) [ -z "${STUB_UNAME_M:-}" ] || { echo "$STUB_UNAME_M"; exit 0; } ;;
esac
exec "$REAL_UNAME" "$@"
EOF
printf '#!/bin/sh\nexit 0\n' >"$T/stub/brew"
chmod +x "$T/stub/mise" "$T/stub/uname" "$T/stub/brew"

FAILS=0
CASE=""
fail() {
  echo "FAIL [$CASE]: $*" >&2
  FAILS=$((FAILS + 1))
}

gitc() { git -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false "$@"; }

# Fresh sandbox per case: sets C, DOTFILES_DIR, MISE_DIR, SYSROOT.
new_case() {
  CASE=$1
  C="$T/case"
  rm -rf "$C"
  mkdir -p "$C/xdg" "$C/sysroot/etc"
  DOTFILES_DIR="$C/dotfiles"
  SYSROOT="$C/sysroot"
  MISE_DIR="$C/xdg/config/mise"
}

OUT="" ERR="" RC=0
# run_df [NAME=value ...] [args...]: run the real script with a scrubbed environment.
# NAME=value words (upper-case names) are added to the environment; the rest are script args.
run_df() {
  local envs=() args=() a
  for a in "$@"; do
    case $a in
      [A-Z_]*=*) envs+=("$a") ;;
      *) args+=("$a") ;;
    esac
  done
  : >"$C/mise.argv"
  if OUT=$(env -i \
    HOME="$HOME" PATH="$T/stub:$ORIG_PATH" GIT_CONFIG_NOSYSTEM=1 \
    XDG_CONFIG_HOME="$C/xdg/config" XDG_DATA_HOME="$C/xdg/data" \
    XDG_STATE_HOME="$C/xdg/state" XDG_CACHE_HOME="$C/xdg/cache" \
    DOTFILES_DIR="$DOTFILES_DIR" DOTFILES_SYSROOT="$SYSROOT" \
    MISE_ARGV_FILE="$C/mise.argv" REAL_UNAME="$REAL_UNAME" \
    STUB_UNAME_S=Linux STUB_UNAME_M=x86_64 \
    ${envs[@]+"${envs[@]}"} \
    "$BIN" ${args[@]+"${args[@]}"} 2>"$C/stderr"); then
    RC=0
  else
    RC=$?
  fi
  ERR=$(cat "$C/stderr")
}

expect_eq() { [ "$1" = "$2" ] || fail "$3: expected '$2', got '$1'"; }
expect_rc() { [ "$RC" -eq "$1" ] || fail "exit status: expected $1, got $RC (stderr: $ERR)"; }
expect_contains() { case $1 in *"$2"*) ;; *) fail "$3: '$2' not in '$1'" ;; esac; }

init_repo() { # init_repo <dir>: repo with one commit, no upstream
  git init -q -b main "$1"
  echo one >"$1/f"
  git -C "$1" add f
  gitc -C "$1" commit -q -m one
}

# ---- profile detection ----
detect() { # detect <name> <os-release-ID|-> <expected-profile|FAIL:msg> [extra run_df words]
  local name=$1 id=$2 want=$3
  shift 3
  new_case "$name"
  [ "$id" = - ] || printf 'ID=%s\n' "$id" >"$SYSROOT/etc/os-release"
  run_df "$@" --profile
  case $want in
    FAIL:*)
      expect_rc 1
      expect_contains "$ERR" "${want#FAIL:}" stderr
      ;;
    *)
      expect_rc 0
      expect_eq "$OUT" "$want" profile
      ;;
  esac
}

detect omarchy-id omarchy omarchy
detect cachyos-id cachyos cachyos
new_case cachyos-plus-omarchy-dir
printf 'ID=cachyos\n' >"$SYSROOT/etc/os-release"
mkdir -p "$SYSROOT/usr/share/omarchy"
run_df --profile
expect_rc 0
expect_eq "$OUT" omarchy profile
detect ubuntu-rejected ubuntu "FAIL:unsupported machine (ubuntu)"
detect no-os-release - "FAIL:unsupported machine (unknown)"
detect override-macos ubuntu macos DOTFILES_PROFILE=macos
detect override-bogus cachyos "FAIL:unsupported machine (bogus)" DOTFILES_PROFILE=bogus
detect darwin-arm64 - macos STUB_UNAME_S=Darwin STUB_UNAME_M=arm64
detect darwin-intel - "FAIL:unsupported machine (Intel Mac)" STUB_UNAME_S=Darwin STUB_UNAME_M=x86_64

# ---- conf.d link, miserc, mise argv ----
EXPECTED_RC='# written by bin/dotfiles; set DOTFILES_PROFILE to override
auto_env = true
env = ["cachyos"]'

new_case fresh-link
init_repo "$DOTFILES_DIR"
run_df DOTFILES_PROFILE=cachyos --dry-run
expect_rc 0
[ -L "$MISE_DIR/conf.d" ] || fail "conf.d is not a symlink"
expect_eq "$(readlink "$MISE_DIR/conf.d")" "$DOTFILES_DIR/modules" "conf.d target"
expect_eq "$(cat "$MISE_DIR/miserc.local.toml")" "$EXPECTED_RC" "miserc content"
expect_eq "$(tr '\n' ' ' <"$C/mise.argv")" "bootstrap --yes --dry-run " "mise argv"

# Rerun must not rewrite an unchanged miserc.
touch -t 200001010000 "$MISE_DIR/miserc.local.toml"
touch -t 200101010000 "$C/ref"
run_df DOTFILES_PROFILE=cachyos --dry-run
expect_rc 0
if [ "$MISE_DIR/miserc.local.toml" -nt "$C/ref" ]; then fail "miserc rewritten though unchanged"; fi
# A changed profile must rewrite it.
run_df DOTFILES_PROFILE=omarchy --dry-run
expect_rc 0
expect_contains "$(cat "$MISE_DIR/miserc.local.toml")" 'env = ["omarchy"]' "miserc after profile change"

new_case existing-real-conf-d
init_repo "$DOTFILES_DIR"
mkdir -p "$MISE_DIR/conf.d"
echo keep >"$MISE_DIR/conf.d/mine.toml"
run_df DOTFILES_PROFILE=cachyos --dry-run
expect_rc 0
[ -L "$MISE_DIR/conf.d" ] || fail "conf.d not relinked"
expect_eq "$(readlink "$MISE_DIR/conf.d")" "$DOTFILES_DIR/modules" "conf.d target"
BACKUPS=$(find "$MISE_DIR" -maxdepth 1 -name 'conf.d.pre-dotfiles.*')
case $BACKUPS in
  "$MISE_DIR"/conf.d.pre-dotfiles.[0-9]*) ;;
  *) fail "expected exactly one conf.d.pre-dotfiles.<epoch>, got '$BACKUPS'" ;;
esac
case $BACKUPS in *$'\n'*) fail "more than one backup: $BACKUPS" ;; esac
expect_eq "$(cat "$BACKUPS/mine.toml" 2>/dev/null || true)" keep "backed-up file content"
expect_contains "$OUT" "$BACKUPS" "backup path announced"

new_case correct-link-no-backup
init_repo "$DOTFILES_DIR"
mkdir -p "$MISE_DIR"
ln -s "$DOTFILES_DIR/modules" "$MISE_DIR/conf.d"
run_df DOTFILES_PROFILE=cachyos --dry-run
expect_rc 0
expect_eq "$(find "$MISE_DIR" -maxdepth 1 -name 'conf.d.pre-dotfiles.*' | wc -l | tr -d ' ')" 0 "backup count"
expect_eq "$(readlink "$MISE_DIR/conf.d")" "$DOTFILES_DIR/modules" "conf.d target"

# The macOS full run reaches brew only through the stub, and only when the real
# /opt/homebrew/bin/brew (whose shellenv would shadow the stubs) is absent.
if [ -x /opt/homebrew/bin/brew ]; then
  echo "SKIP macos miserc: /opt/homebrew/bin/brew exists on this machine" >&2
else
  new_case macos-miserc
  init_repo "$DOTFILES_DIR"
  run_df DOTFILES_PROFILE=macos --dry-run
  expect_rc 0
  expect_eq "$(cat "$MISE_DIR/miserc.local.toml")" '# written by bin/dotfiles; set DOTFILES_PROFILE to override
auto_env = true
env = []' "macos miserc content"
fi

# ---- pull rules ----
setup_remote() { # clone of a bare remote becomes DOTFILES_DIR; seed pushes later commits
  git init -q --bare -b main "$C/remote.git"
  git clone -q "$C/remote.git" "$C/seed" 2>/dev/null
  git -C "$C/seed" checkout -q -b main
  echo one >"$C/seed/f"
  git -C "$C/seed" add f
  gitc -C "$C/seed" commit -q -m one
  git -C "$C/seed" push -q -u origin main
  git clone -q "$C/remote.git" "$DOTFILES_DIR"
  echo two >"$C/seed/f"
  gitc -C "$C/seed" commit -q -am two
  git -C "$C/seed" push -q origin main
}

new_case pull-fast-forward
setup_remote
run_df DOTFILES_PROFILE=cachyos --dry-run
expect_rc 0
expect_eq "$(git -C "$DOTFILES_DIR" rev-parse HEAD)" "$(git -C "$C/seed" rev-parse HEAD)" "HEAD after pull"

new_case pull-skipped-local-changes
setup_remote
echo dirty >"$DOTFILES_DIR/f"
OLD=$(git -C "$DOTFILES_DIR" rev-parse HEAD)
run_df DOTFILES_PROFILE=cachyos --dry-run
expect_rc 0
expect_contains "$OUT" "local changes" "message"
expect_eq "$(git -C "$DOTFILES_DIR" rev-parse HEAD)" "$OLD" "HEAD unchanged"
expect_eq "$(cat "$DOTFILES_DIR/f")" dirty "local edit preserved"

new_case pull-skipped-no-upstream
init_repo "$DOTFILES_DIR"
run_df DOTFILES_PROFILE=cachyos --dry-run
expect_rc 0
expect_contains "$OUT" "no upstream for main" "message"

if [ "$FAILS" -ne 0 ]; then
  echo "test_bin_dotfiles: $FAILS failure(s)" >&2
  exit 1
fi
echo "test_bin_dotfiles: all passed"
