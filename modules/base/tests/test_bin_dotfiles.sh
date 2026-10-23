#!/usr/bin/env bash
# Runs the real bin/dotfiles from a writable sandbox with fake HOME, XDG and all
# mise directories. Stubbed commands prevent network, sudo, or live package changes.
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BIN=$(cd "$HERE/../../.." && pwd)/bin/dotfiles
ORIG_PATH=$PATH
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
# Native mise canonicalizes module paths; fixture discovery must use the same root.
T=$(cd "$T" && pwd -P)

export HOME="$T/home" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
mkdir -p "$HOME" "$T/stub"
REAL_UNAME=$(command -v uname)
REAL_GIT=$(command -v git)
REAL_DATE=$(command -v date)

cat >"$T/stub/mise" <<'EOF'
#!/bin/sh
# --version answers from $MISE_VERSION_FILE (default: a passing version).
# 'bootstrap --only X ...' (a stage) is recorded in $MISE_CALLS_FILE; any bootstrap call
# overwrites $MISE_ARGV_FILE. Stage behaviour comes from the STUB_* variables.
if [ -n "${STUB_EXPECT_CWD:-}" ] && [ "$PWD" != "$STUB_EXPECT_CWD" ]; then
  echo "unexpected mise cwd: $PWD" >&2
  exit 15
fi
if [ "$1" = --version ]; then
  cat "$MISE_VERSION_FILE" 2>/dev/null || echo "2026.10.6 linux-x64 (2026-10-09)"
  exit 0
fi
if [ -n "${MISE_CONFIG_DIR:-}" ]; then
  printf 'config=%s\ndata=%s\nstate=%s\ncache=%s\n' \
    "$MISE_CONFIG_DIR" "$MISE_DATA_DIR" "$MISE_STATE_DIR" "$MISE_CACHE_DIR" >"$MISE_ENV_FILE"
  [ "$MISE_CONFIG_DIR/conf.d/base/mise.toml" -ef "$DOTFILES_DIR/modules/base/mise.toml" ] || { echo "candidate base module missing" >&2; exit 8; }
  if [ -n "${STUB_EXPECT_OVERRIDE:-}" ]; then
    [ "$MISE_CONFIG_DIR/config.toml" -ef "$STUB_EXPECT_OVERRIDE" ] || exit 9
  fi
  for module in ${STUB_FORBID_MODULE:-}; do
    [ ! -e "$MISE_CONFIG_DIR/conf.d/$module" ] || exit 12
  done
  if [ -n "${STUB_EXPECT_CONTEXT:-}" ]; then
    [ "$MISE_CONFIG_DIR" = "$STUB_EXPECT_CONTEXT" ] || exit 13
    [ -f "$MISE_CONFIG_DIR/adjacent.txt" ] || exit 14
  fi
  cat "$MISE_CONFIG_DIR/miserc.local.toml" >"$MISE_PROFILE_FILE"
fi
case "$1 $2" in
  "tasks ls") printf 'bootstrap\nbootstrap:alpha\nbootstrap:beta\nbootstrap:secrets\ntest:base\n'; exit 0 ;;
  "ls --missing") exit 0 ;;
  "bootstrap plan") echo "${STUB_PLAN_JSON:-{\}}"; exit 0 ;;
  "bootstrap user") echo "/usr/bin/zsh  /bin/bash  ${STUB_SHELL_STATE:-set}"; exit 0 ;;
  "dot status")
    case " $* " in *" --json "*) echo '{"files":[],"edits":[]}'; exit 0 ;; esac
    n=$(cat "$STUB_DOT_COUNT_FILE" 2>/dev/null || echo 0)
    if [ "$n" -gt 0 ]; then echo $((n - 1)) >"$STUB_DOT_COUNT_FILE"; exit 1; fi
    exit 0
    ;;
  "dot apply")
    printf '%s\n' "$@" >"$MISE_DOT_ARGV_FILE"
    if [ -n "${STUB_PREVIEW_ERROR:-}" ]; then
      printf '%b\n' "$STUB_PREVIEW_ERROR"
      exit "${STUB_PREVIEW_RC:-7}"
    fi
    # Like mise when targets exist and are not links: $STUB_REFUSE is a ':' list of them.
    [ -n "${STUB_REFUSE:-}" ] || exit 0
    echo "mise ERROR files: refusing to overwrite existing files (use --force):"
    echo "$STUB_REFUSE" | tr ':' '\n' | sed 's/^/  /'
    echo "mise ERROR Version: stub"
    echo "mise ERROR Run with --verbose or MISE_VERBOSE=1 for more information"
    exit 1
    ;;
esac
printf '%s\n' "$@" >"$MISE_ARGV_FILE"
echo "$*" >>"$MISE_CALLS_FILE"
[ -z "${STUB_BOOTSTRAP_RC:-}" ] || exit "$STUB_BOOTSTRAP_RC"
only="" prev="" dry=0
for a in "$@"; do
  [ "$prev" != --only ] || only=$a
  [ "$a" != --dry-run ] || dry=1
  prev=$a
done
[ -n "$only" ] || exit 0
echo "mise bootstrap: stub $only"
if [ "$only" = "${STUB_FAIL_ONLY:-}" ]; then echo "stub: boom in $only"; exit 3; fi
if [ "$dry" = 1 ]; then
  case $only in
    accounts,plugins,packages) printf 'mise pacman: 3 package(s) already installed\nsudo pacman -S --noconfirm --needed -- cowsay\n' ;;
    tools) echo 'mise npm:left-pad@1.3.0 ⇢ would install' ;;
  esac
fi
[ "$only" != task,final-hook ] || printf '%b' "${STUB_MODULES_OUT:-}"
exit 0
EOF
cat >"$T/stub/sudo" <<'EOF'
#!/bin/sh
# Records argv; 'sudo -n true' answers with $STUB_SUDO_N (0 = passwordless).
echo "$*" >>"$SUDO_LOG"
[ "$*" != "-n true" ] || exit "${STUB_SUDO_N:-0}"
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
cat >"$T/stub/git" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$GIT_ARGV_FILE"
exec "$REAL_GIT" "$@"
EOF
cat >"$T/stub/curl" <<'EOF'
#!/bin/sh
echo "$*" >>"$CURL_ARGV_FILE"
exit 90
EOF
cat >"$T/stub/date" <<'EOF'
#!/bin/sh
if [ "$*" = +%s ]; then echo 1234567890; else exec "$REAL_DATE" "$@"; fi
EOF
cat >"$T/stub/brew" <<'EOF'
#!/bin/sh
# Records argv; 'upgrade' installs the version in $STUB_BREW_UPGRADE_TO when set.
printf '%s\n' "$*" >>"$BREW_ARGV_FILE"
if [ "$1" = upgrade ] && [ -n "${STUB_BREW_UPGRADE_TO:-}" ]; then
  echo "$STUB_BREW_UPGRADE_TO" >"$MISE_VERSION_FILE"
fi
exit 0
EOF
chmod +x "$T/stub/"*

FAILS=0
CASE=""
fail() {
  echo "FAIL [$CASE]: $*" >&2
  FAILS=$((FAILS + 1))
}

gitc() { git -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"; }

# Fresh sandbox per case: sets C, DOTFILES_DIR, MISE_DIR, SYSROOT.
new_case() {
  CASE=$1
  C="$T/case"
  rm -rf "$C"
  mkdir -p "$C/xdg" "$C/sysroot/etc" "$C/work" "$C/tmp"
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
  : >"$C/mise.calls"
  : >"$C/sudo.log"
  : >"$C/brew.argv"
  : >"$C/git.argv"
  : >"$C/curl.argv"
  : >"$C/mise.dot.argv"
  if OUT=$(cd "$C/work" && env -i \
    HOME="$HOME" TMPDIR="$C/tmp" PATH="$T/stub:$ORIG_PATH" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null \
    XDG_CONFIG_HOME="$C/xdg/config" XDG_DATA_HOME="$C/xdg/data" \
    XDG_STATE_HOME="$C/xdg/state" XDG_CACHE_HOME="$C/xdg/cache" \
    MISE_SYSTEM_CONFIG_DIR="$C/mise/system" \
    MISE_CONFIG_DIR="$MISE_DIR" MISE_DATA_DIR="$C/mise/data" \
    MISE_STATE_DIR="$C/mise/state" MISE_CACHE_DIR="$C/mise/cache" \
    DOTFILES_DIR="$DOTFILES_DIR" DOTFILES_SYSROOT="$SYSROOT" \
    MISE_ARGV_FILE="$C/mise.argv" MISE_CALLS_FILE="$C/mise.calls" REAL_UNAME="$REAL_UNAME" \
    MISE_VERSION_FILE="$C/mise.version" BREW_ARGV_FILE="$C/brew.argv" \
    REAL_GIT="$REAL_GIT" REAL_DATE="$REAL_DATE" GIT_ARGV_FILE="$C/git.argv" CURL_ARGV_FILE="$C/curl.argv" \
    MISE_ENV_FILE="$C/mise.env" MISE_PROFILE_FILE="$C/mise.profile" \
    MISE_DOT_ARGV_FILE="$C/mise.dot.argv" \
    SUDO_LOG="$C/sudo.log" STUB_DOT_COUNT_FILE="$C/dot.count" \
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

init_repo() { # init_repo <dir>: repo with one commit (incl. modules/base/mise.toml), no upstream
  git init -q -b main "$1"
  echo one >"$1/f"
  mkdir -p "$1/modules/base"
  printf 'min_version = "2026.10.6"\n\n[tasks.bootstrap]\nrun = "true"\n' >"$1/modules/base/mise.toml"
  git -C "$1" add f modules
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
new_case arch-plus-home-omarchy-dir
printf 'ID=arch\n' >"$SYSROOT/etc/os-release"
mkdir -p "$C/home/.local/share/omarchy"
run_df HOME="$C/home" --profile
expect_rc 0
expect_eq "$OUT" omarchy profile
new_case cachyos-plus-home-omarchy-dir
printf 'ID=cachyos\n' >"$SYSROOT/etc/os-release"
mkdir -p "$C/home/.local/share/omarchy"
run_df HOME="$C/home" --profile
expect_rc 0
expect_eq "$OUT" omarchy profile
new_case override-home-omarchy-dir
printf 'ID=arch\n' >"$SYSROOT/etc/os-release"
mkdir -p "$C/home/.local/share/omarchy"
run_df HOME="$C/home" DOTFILES_PROFILE=cachyos --profile
expect_rc 0
expect_eq "$OUT" cachyos profile
detect ubuntu-rejected ubuntu "FAIL:unsupported machine (ubuntu)"
detect no-os-release - "FAIL:unsupported machine (unknown)"
detect override-macos ubuntu macos DOTFILES_PROFILE=macos
detect override-bogus cachyos "FAIL:unsupported machine (bogus)" DOTFILES_PROFILE=bogus
detect darwin-arm64 - macos STUB_UNAME_S=Darwin STUB_UNAME_M=arm64
detect darwin-intel - "FAIL:unsupported machine (Intel Mac)" STUB_UNAME_S=Darwin STUB_UNAME_M=x86_64

# ---- persistent machine purpose; setters must never provision ----
expect_no_provisioning() {
  local file
  for file in mise.calls mise.argv mise.dot.argv git.argv curl.argv brew.argv sudo.log; do
    expect_eq "$(cat "$C/$file")" "" "config-only operation leaves $file empty"
  done
  [ ! -e "$C/xdg/state/dotfiles" ] || fail "config-only operation wrote bootstrap state"
}

new_case purpose-default-query
run_df --purpose
expect_rc 0
expect_eq "$OUT" personal "absent purpose defaults to personal without OS detection"
expect_no_provisioning
[ ! -e "$C/xdg/config" ] || fail "purpose query created configuration"

new_case purpose-set-without-mise-or-checkout
mkdir -p "$C/path" "$MISE_DIR/conf.d"
for cmd in bash cmp cat mkdir mktemp mv rm; do
  tool=$(command -v "$cmd") || fail "test needs $cmd on PATH"
  [ -z "$tool" ] || ln -s "$tool" "$C/path/$cmd"
done
echo retained >"$MISE_DIR/conf.d/user.toml"
echo '[settings]' >"$MISE_DIR/config.toml"
run_df DOTFILES_PROFILE=macos PATH="$C/path" --set-purpose work
expect_rc 0
expect_no_provisioning
expect_eq "$(cat "$C/xdg/config/dotfiles/purpose")" work "saved work purpose"
expect_contains "$(cat "$MISE_DIR/miserc.local.toml")" 'env = ["work"]' "macOS native purpose selection"
[ ! -e "$DOTFILES_DIR" ] || fail "setter created a checkout"
[ ! -L "$MISE_DIR/conf.d" ] || fail "setter replaced conf.d"
expect_eq "$(cat "$MISE_DIR/conf.d/user.toml")" retained "setter preserves existing discovery ownership"
expect_eq "$(cat "$MISE_DIR/config.toml")" '[settings]' "setter preserves global overrides"
touch -t 200001010000 "$C/xdg/config/dotfiles/purpose" "$MISE_DIR/miserc.local.toml"
touch -t 200101010000 "$C/ref"
PURPOSE_BEFORE=$(cksum "$C/xdg/config/dotfiles/purpose")
MISERC_BEFORE=$(cksum "$MISE_DIR/miserc.local.toml")
run_df DOTFILES_PROFILE=macos PATH="$C/path" --set-purpose=work
expect_rc 0
expect_no_provisioning
expect_eq "$(cksum "$C/xdg/config/dotfiles/purpose")" "$PURPOSE_BEFORE" "repeated setter preserves purpose bytes"
expect_eq "$(cksum "$MISE_DIR/miserc.local.toml")" "$MISERC_BEFORE" "repeated setter preserves discovery bytes"
[ ! "$C/xdg/config/dotfiles/purpose" -nt "$C/ref" ] || fail "repeated setter rewrote purpose"
[ ! "$MISE_DIR/miserc.local.toml" -nt "$C/ref" ] || fail "repeated setter rewrote mise settings"
run_df --purpose
expect_rc 0
expect_eq "$OUT" work "query retains work across invocations"
expect_no_provisioning
init_repo "$DOTFILES_DIR"
run_df DOTFILES_PROFILE=cachyos
expect_rc 0
expect_contains "$(cat "$MISE_DIR/miserc.local.toml")" 'env = ["cachyos", "work"]' "ordinary apply persists purpose and distro selection"
run_df DOTFILES_PROFILE=omarchy --set-purpose personal
expect_rc 0
expect_no_provisioning
expect_contains "$(cat "$MISE_DIR/miserc.local.toml")" 'env = ["omarchy", "personal"]' "switching purpose preserves Linux profile"
run_df --purpose
expect_rc 0
expect_eq "$OUT" personal "personal switch persists"

new_case purpose-home-config-fallback
run_df HOME="$C/home" XDG_CONFIG_HOME= DOTFILES_PROFILE=macos --set-purpose work
expect_rc 0
expect_eq "$(cat "$C/home/.config/dotfiles/purpose")" work "unset XDG config uses HOME"
run_df HOME="$C/home" XDG_CONFIG_HOME= --purpose
expect_rc 0
expect_eq "$OUT" work "HOME-scoped query reads saved value"

for bad_args in \
  "--purpose=work" "--purpose work" "--set-purpose" "--set-purpose=" "--set-purpose business" \
  "--set-purpose work --dry-run" "--dry-run --set-purpose=work" \
  "--set-purpose work --plain" "--set-purpose work --profile" \
  "--set-purpose work --help" "--set-purpose work --only tools" \
  "--set-purpose work --set-purpose personal" "--purpose --set-purpose work"; do
  new_case "purpose-invalid-arguments-$bad_args"
  # shellcheck disable=SC2086
  run_df DOTFILES_PROFILE=cachyos $bad_args
  expect_rc 1
  expect_no_provisioning
  [ ! -e "$C/xdg/config" ] || fail "invalid arguments wrote configuration"
done

new_case purpose-discovery-write-fails
run_df DOTFILES_PROFILE=cachyos --set-purpose work
expect_rc 0
MISERC_BEFORE=$(cksum "$MISE_DIR/miserc.local.toml")
mkdir "$C/path"
cat >"$C/path/mktemp" <<'EOF'
#!/bin/sh
case "$1" in */.miserc.*) exit 73 ;; esac
exec "$REAL_MKTEMP" "$@"
EOF
chmod +x "$C/path/mktemp"
run_df DOTFILES_PROFILE=cachyos PATH="$C/path:$T/stub:$ORIG_PATH" REAL_MKTEMP="$(command -v mktemp)" --set-purpose personal
expect_rc 1
expect_no_provisioning
expect_eq "$(cksum "$MISE_DIR/miserc.local.toml")" "$MISERC_BEFORE" "failed discovery write preserves prior settings"
case $OUT in *"purpose set to"*) fail "setter claimed activation after a discovery write failure" ;; esac

for stored_kind in empty unknown multiline extra-newline nul; do
  new_case "purpose-invalid-stored-$stored_kind"
  mkdir -p "$C/xdg/config/dotfiles"
  case $stored_kind in
    empty) : >"$C/xdg/config/dotfiles/purpose" ;;
    unknown) printf 'private-invalid-value\n' >"$C/xdg/config/dotfiles/purpose" ;;
    multiline) printf 'work\npersonal\n' >"$C/xdg/config/dotfiles/purpose" ;;
    extra-newline) printf 'work\n\n' >"$C/xdg/config/dotfiles/purpose" ;;
    nul) printf 'work\0\n' >"$C/xdg/config/dotfiles/purpose" ;;
  esac
  PURPOSE_BEFORE=$(cksum "$C/xdg/config/dotfiles/purpose")
  for operation in query setter apply preview; do
    case $operation in
      query) purpose_args=(--purpose) ;;
      setter) purpose_args=(--set-purpose personal) ;;
      apply) purpose_args=() ;;
      preview) purpose_args=(--dry-run) ;;
    esac
    run_df DOTFILES_PROFILE=cachyos ${purpose_args[@]+"${purpose_args[@]}"}
    expect_rc 1
    expect_contains "$ERR" "invalid purpose" "malformed state rejected before setup"
    case $OUT$ERR in *private-invalid-value*) fail "diagnostic disclosed invalid stored contents" ;; esac
    expect_no_provisioning
    expect_eq "$(cksum "$C/xdg/config/dotfiles/purpose")" "$PURPOSE_BEFORE" "invalid state remains untouched"
    [ ! -e "$MISE_DIR" ] || fail "invalid stored purpose created mise configuration"
  done
done

for target_kind in symlink dangling-symlink directory fifo parent-symlink parent-file miserc-symlink miserc-directory; do
  new_case "purpose-unsafe-$target_kind"
  mkdir -p "$C/xdg/config/dotfiles"
  echo unrelated >"$C/unrelated"
  case $target_kind in
    symlink) ln -s "$C/unrelated" "$C/xdg/config/dotfiles/purpose" ;;
    dangling-symlink) ln -s "$C/missing" "$C/xdg/config/dotfiles/purpose" ;;
    directory) mkdir "$C/xdg/config/dotfiles/purpose" ;;
    fifo) mkfifo "$C/xdg/config/dotfiles/purpose" ;;
    parent-symlink)
      rmdir "$C/xdg/config/dotfiles"
      mkdir "$C/other"
      ln -s "$C/other" "$C/xdg/config/dotfiles"
      ;;
    parent-file)
      rmdir "$C/xdg/config/dotfiles"
      echo unrelated >"$C/xdg/config/dotfiles"
      ;;
    miserc-symlink)
      mkdir "$MISE_DIR"
      ln -s "$C/unrelated" "$MISE_DIR/miserc.local.toml"
      ;;
    miserc-directory) mkdir -p "$MISE_DIR/miserc.local.toml" ;;
  esac
  run_df DOTFILES_PROFILE=cachyos --set-purpose work
  expect_rc 1
  expect_contains "$ERR" "unsafe" "unsafe target rejected"
  expect_no_provisioning
  expect_eq "$(cat "$C/unrelated")" unrelated "setter preserves unrelated target"
  [ ! -e "$C/missing" ] || fail "setter followed dangling purpose link"
  if [ "$target_kind" = miserc-symlink ] || [ "$target_kind" = miserc-directory ]; then
    [ ! -e "$C/xdg/config/dotfiles/purpose" ] || fail "unsafe discovery target changed purpose"
  fi
done

# ---- conf.d link, miserc, mise argv ----

new_case fresh-link
init_repo "$DOTFILES_DIR"
run_df DOTFILES_PROFILE=cachyos
expect_rc 0
[ -L "$MISE_DIR/conf.d" ] || fail "conf.d is not a symlink"
expect_eq "$(readlink "$MISE_DIR/conf.d")" "$DOTFILES_DIR/modules" "conf.d target"
expect_contains "$(cat "$MISE_DIR/miserc.local.toml")" 'env = ["cachyos", "personal"]' "distro and default purpose selection"

# Rerun must not rewrite an unchanged miserc.
touch -t 200001010000 "$MISE_DIR/miserc.local.toml"
touch -t 200101010000 "$C/ref"
run_df DOTFILES_PROFILE=cachyos
expect_rc 0
if [ "$MISE_DIR/miserc.local.toml" -nt "$C/ref" ]; then fail "miserc rewritten though unchanged"; fi
# A changed profile must rewrite it.
run_df DOTFILES_PROFILE=omarchy
expect_rc 0
expect_contains "$(cat "$MISE_DIR/miserc.local.toml")" 'env = ["omarchy", "personal"]' "miserc after profile change"

new_case existing-real-conf-d
init_repo "$DOTFILES_DIR"
mkdir -p "$MISE_DIR/conf.d"
echo keep >"$MISE_DIR/conf.d/mine.toml"
run_df DOTFILES_PROFILE=cachyos
expect_rc 0
[ -L "$MISE_DIR/conf.d" ] || fail "conf.d not relinked"
expect_eq "$(readlink "$MISE_DIR/conf.d")" "$DOTFILES_DIR/modules" "conf.d target"
BACKUPS=$(find "$MISE_DIR" -maxdepth 1 -name 'conf.d.pre-dotfiles.*')
expect_eq "$(cat "$BACKUPS/original/mine.toml" 2>/dev/null || true)" keep "backed-up file content"
expect_contains "$OUT" "$BACKUPS" "backup path announced"

new_case correct-link-no-backup
init_repo "$DOTFILES_DIR"
mkdir -p "$MISE_DIR"
ln -s "$DOTFILES_DIR/modules" "$MISE_DIR/conf.d"
run_df DOTFILES_PROFILE=cachyos
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
  run_df DOTFILES_PROFILE=macos
  expect_rc 0
  expect_contains "$(cat "$MISE_DIR/miserc.local.toml")" 'env = ["personal"]' "macos purpose selection"
fi

# ---- pull rules ----
setup_remote() { # clone of a bare remote becomes DOTFILES_DIR; seed pushes later commits
  git init -q --bare -b main "$C/remote.git"
  git clone -q "$C/remote.git" "$C/seed" 2>/dev/null
  git -C "$C/seed" checkout -q -b main
  mkdir -p "$C/seed/modules/base"
  printf 'min_version = "2026.10.6"\n' >"$C/seed/modules/base/mise.toml"
  echo one >"$C/seed/f"
  git -C "$C/seed" add f modules
  gitc -C "$C/seed" commit -q -m one
  git -C "$C/seed" push -q -u origin main
  git clone -q "$C/remote.git" "$DOTFILES_DIR"
  echo two >"$C/seed/f"
  gitc -C "$C/seed" commit -q -am two
  git -C "$C/seed" push -q origin main
}

new_case pull-fast-forward
setup_remote
run_df DOTFILES_PROFILE=cachyos
expect_rc 0
expect_eq "$(git -C "$DOTFILES_DIR" rev-parse HEAD)" "$(git -C "$C/seed" rev-parse HEAD)" "HEAD after pull"

new_case pull-skipped-local-changes
setup_remote
echo dirty >"$DOTFILES_DIR/f"
OLD=$(git -C "$DOTFILES_DIR" rev-parse HEAD)
run_df DOTFILES_PROFILE=cachyos
expect_rc 0
expect_contains "$OUT" "local changes" "message"
expect_eq "$(git -C "$DOTFILES_DIR" rev-parse HEAD)" "$OLD" "HEAD unchanged"
expect_eq "$(cat "$DOTFILES_DIR/f")" dirty "local edit preserved"

new_case pull-skipped-no-upstream
init_repo "$DOTFILES_DIR"
run_df DOTFILES_PROFILE=cachyos
expect_rc 0
expect_contains "$OUT" "no upstream for main" "message"

# ---- first-run preflight must not prepare or mutate the machine ----
new_case dry-run-first-use
init_repo "$DOTFILES_DIR"
OLD=$(git -C "$DOTFILES_DIR" rev-parse HEAD)
run_df DOTFILES_PROFILE=macos --dry-run --only tools,task --locked
expect_rc 0
expect_eq "$(cat "$C/brew.argv")" "" "preflight does not invoke Homebrew"
expect_eq "$(cat "$C/sudo.log")" "" "preflight does not invoke sudo"
expect_eq "$(cat "$C/curl.argv")" "" "preflight does not download prerequisites"
expect_eq "$(cat "$C/git.argv")" "" "plain preflight does not sync the checkout"
expect_eq "$(git -C "$DOTFILES_DIR" rev-parse HEAD)" "$OLD" "checkout unchanged"
[ ! -e "$MISE_DIR" ] || fail "first preflight created live mise configuration"
[ ! -e "$C/xdg/config/dotfiles/purpose" ] || fail "first preflight persisted default purpose"
expect_eq "$(tr '\n' ' ' <"$C/mise.argv")" "bootstrap --yes --dry-run --only tools,task --locked " "selection and lock flags reach preview"
expect_contains "$(cat "$C/mise.profile")" 'env = ["personal"]' "macOS candidate purpose"
expect_contains "$(cat "$C/mise.env")" "data=$C/mise/data" "installed-tool data is preserved"
expect_contains "$(cat "$C/mise.env")" "state=$C/mise/state" "installed-tool state is preserved"
expect_contains "$(cat "$C/mise.env")" "cache=$C/mise/cache" "metadata cache location is preserved"
expect_eq "$(find "$C/tmp" -mindepth 1 | wc -l | tr -d ' ')" 0 "scratch configuration is removed after preview"

new_case dry-run-previews-replacement-not-old-conf-d
init_repo "$DOTFILES_DIR"
mkdir -p "$C/xdg/config/dotfiles"
printf 'work\n' >"$C/xdg/config/dotfiles/purpose"
PURPOSE_BEFORE=$(cksum "$C/xdg/config/dotfiles/purpose")
mkdir -p "$MISE_DIR/conf.d/private"
printf '[tools]\nnode = "22"\n' >"$MISE_DIR/conf.d/personal.toml"
printf '[tools]\ngo = "1.24"\n' >"$MISE_DIR/conf.d/private/mise.toml"
printf '# existing profile override\n' >"$MISE_DIR/miserc.local.toml"
touch -t 200001010000 "$MISE_DIR/miserc.local.toml"
touch -t 200101010000 "$C/ref"
run_df DOTFILES_PROFILE=cachyos "STUB_FORBID_MODULE=personal.toml private" --dry-run
expect_rc 0
[ -d "$MISE_DIR/conf.d" ] && [ ! -L "$MISE_DIR/conf.d" ] || fail "preflight replaced live conf.d"
expect_eq "$(cat "$MISE_DIR/conf.d/personal.toml")" '[tools]
node = "22"' "discarded configuration remains untouched on disk"
expect_eq "$(cat "$MISE_DIR/miserc.local.toml")" '# existing profile override' "live profile untouched"
[ ! "$MISE_DIR/miserc.local.toml" -nt "$C/ref" ] || fail "live profile was rewritten"
expect_eq "$(find "$MISE_DIR" -name '*.pre-dotfiles.*' | wc -l | tr -d ' ')" 0 "preflight creates no backups"
expect_contains "$(cat "$C/mise.profile")" 'env = ["cachyos", "work"]' "scratch preview selects the saved purpose"
expect_eq "$(cksum "$C/xdg/config/dotfiles/purpose")" "$PURPOSE_BEFORE" "scratch preview preserves saved purpose"

# Config-relative adjacent resources require their original configuration context.
new_case dry-run-retained-global-needs-original-context
init_repo "$DOTFILES_DIR"
mkdir -p "$MISE_DIR"
printf '[dotfiles]\n"~/.config/context-link" = { source = "adjacent.txt" }\n' >"$MISE_DIR/config.toml"
echo adjacent-resource >"$MISE_DIR/adjacent.txt"
run_df DOTFILES_PROFILE=cachyos --dry-run
expect_rc 1
expect_contains "$ERR" "cannot faithfully preview" "unsupported relocation fails explicitly"
expect_contains "$ERR" "isolated HOME/MISE_CONFIG_DIR" "actionable isolated-rehearsal guidance"
expect_eq "$(cat "$C/mise.calls")" "" "ambiguous configuration never reaches bootstrap"
[ ! -e "$MISE_DIR/conf.d" ] || fail "rejected preflight configured live mise"
ln -s "$DOTFILES_DIR/modules" "$MISE_DIR/conf.d"
run_df DOTFILES_PROFILE=cachyos --set-purpose personal
expect_rc 0
run_df DOTFILES_PROFILE=cachyos STUB_EXPECT_CONTEXT="$MISE_DIR" STUB_EXPECT_OVERRIDE="$MISE_DIR/config.toml" --dry-run
expect_rc 0
expect_contains "$(cat "$C/mise.env")" "config=$MISE_DIR" "configured preview keeps original configuration context"
expect_eq "$(cat "$MISE_DIR/adjacent.txt")" adjacent-resource "adjacent resource remains available"
[ ! -L "$MISE_DIR/config.toml" ] || fail "configured preview replaced the original file with a scratch reference"

# A legacy owned profile cannot be relocated around retained global resources.
printf '# written by bin/dotfiles; set DOTFILES_PROFILE to override\nauto_env = true\nenv = ["cachyos"]\n' >"$MISE_DIR/miserc.local.toml"
MISERC_BEFORE=$(cksum "$MISE_DIR/miserc.local.toml")
CONFIG_BEFORE=$(cksum "$MISE_DIR/config.toml")
PURPOSE_BEFORE=$(cksum "$C/xdg/config/dotfiles/purpose")
run_df DOTFILES_PROFILE=cachyos --dry-run
expect_rc 1
expect_contains "$ERR" "cannot faithfully preview" "legacy selection does not silently relocate retained globals"
expect_contains "$ERR" "dotfiles --set-purpose personal" "legacy settings have config-only upgrade guidance"
expect_eq "$(cksum "$MISE_DIR/miserc.local.toml")" "$MISERC_BEFORE" "rejected preview preserves legacy discovery"
expect_eq "$(cksum "$C/xdg/config/dotfiles/purpose")" "$PURPOSE_BEFORE" "rejected preview preserves saved purpose"
run_df DOTFILES_PROFILE=cachyos --set-purpose work
expect_rc 0
expect_no_provisioning
PURPOSE_BEFORE=$(cksum "$C/xdg/config/dotfiles/purpose")
MISERC_BEFORE=$(cksum "$MISE_DIR/miserc.local.toml")
touch -t 200001010000 "$C/xdg/config/dotfiles/purpose" "$MISE_DIR/miserc.local.toml"
touch -t 200101010000 "$C/ref"
run_df DOTFILES_PROFILE=cachyos STUB_EXPECT_CONTEXT="$MISE_DIR" STUB_EXPECT_OVERRIDE="$MISE_DIR/config.toml" --dry-run
expect_rc 0
expect_eq "$(cksum "$C/xdg/config/dotfiles/purpose")" "$PURPOSE_BEFORE" "configured preview preserves purpose"
expect_eq "$(cksum "$MISE_DIR/miserc.local.toml")" "$MISERC_BEFORE" "configured preview preserves discovery"
expect_eq "$(cksum "$MISE_DIR/config.toml")" "$CONFIG_BEFORE" "upgrade and preview preserve retained global config"
[ ! "$C/xdg/config/dotfiles/purpose" -nt "$C/ref" ] || fail "configured preview rewrote purpose"
[ ! "$MISE_DIR/miserc.local.toml" -nt "$C/ref" ] || fail "configured preview rewrote discovery"

for selected_var in MISE_GLOBAL_CONFIG_FILE MISE_CONFIG_FILE; do
  for mode in apply dry-run; do
    new_case "selected-global-rejected-$selected_var-$mode"
    init_repo "$DOTFILES_DIR"
    echo '[settings]' >"$C/user-global.toml"
    args=()
    [ "$mode" != dry-run ] || args+=(--dry-run)
    run_df DOTFILES_PROFILE=cachyos "$selected_var=$C/user-global.toml" ${args[@]+"${args[@]}"}
    expect_rc 1
    expect_contains "$ERR" "unset it" "custom selected global file has actionable guidance"
    expect_eq "$(cat "$C/git.argv")" "" "unsupported global file is rejected before repo sync"
    expect_eq "$(cat "$C/mise.calls")" "" "unsupported global file never reaches bootstrap"
    [ ! -e "$MISE_DIR" ] || fail "unsupported global file caused live setup changes"
  done
done

# Opt-in native consumer proof, using only a caller-supplied trusted mise binary.
# Native fixtures exercise config discovery and preview only: no install/apply/task runs.
if [ -n "${DOTFILES_TEST_REAL_MISE:-}" ]; then
  new_case native-purpose-selection
  init_repo "$DOTFILES_DIR"
  mkdir -p "$C/native"
  ln -s "$DOTFILES_TEST_REAL_MISE" "$C/native/mise"
  cat >>"$DOTFILES_DIR/modules/base/mise.toml" <<'EOF'
[dotfiles]
"~/PURPOSE_SHARED_PROOF" = { source = "shared.txt" }
EOF
  echo shared >"$DOTFILES_DIR/modules/base/shared.txt"
  for layer in work personal cachyos omarchy; do
    printf '[dotfiles]\n"~/PURPOSE_%s_PROOF" = { source = "%s.txt" }\n' "$layer" "$layer" >"$DOTFILES_DIR/modules/base/mise.$layer.toml"
    echo "$layer" >"$DOTFILES_DIR/modules/base/$layer.txt"
  done
  for distro in cachyos omarchy; do
    for purpose in work personal; do
      run_df DOTFILES_PROFILE="$distro" --set-purpose "$purpose"
      expect_rc 0
      PURPOSE_BEFORE=$(cksum "$C/xdg/config/dotfiles/purpose")
      MISERC_BEFORE=$(cksum "$MISE_DIR/miserc.local.toml")
      # First preview uses scratch because the config-only setter never links conf.d.
      run_df DOTFILES_PROFILE="$distro" PATH="$C/native:$T/stub:$ORIG_PATH" MISE_OFFLINE=1 MISE_TRUSTED_CONFIG_PATHS="$C" --plain --dry-run --only dotfiles
      expect_rc 0
      expect_contains "$OUT$ERR" "PURPOSE_SHARED_PROOF" "native preview retains shared target"
      expect_contains "$OUT$ERR" "PURPOSE_${distro}_PROOF" "native preview retains Linux distro target"
      expect_contains "$OUT$ERR" "PURPOSE_${purpose}_PROOF" "native preview selects saved-purpose target"
      if [ "$purpose" = work ]; then other=personal; else other=work; fi
      case $OUT$ERR in *"PURPOSE_${other}_PROOF"*) fail "native preview selected the other purpose's target" ;; esac
      expect_eq "$(cksum "$C/xdg/config/dotfiles/purpose")" "$PURPOSE_BEFORE" "native preview preserves classification"
      expect_eq "$(cksum "$MISE_DIR/miserc.local.toml")" "$MISERC_BEFORE" "native preview preserves live discovery"
      [ ! -e "$HOME/PURPOSE_SHARED_PROOF" ] || fail "native preview deployed shared dotfile"
      [ ! -e "$HOME/PURPOSE_${purpose}_PROOF" ] || fail "native preview deployed purpose dotfile"
    done
  done

  new_case native-source-relative-preview
  init_repo "$DOTFILES_DIR"
  mkdir -p "$MISE_DIR" "$C/native"
  ln -s "$DOTFILES_TEST_REAL_MISE" "$C/native/mise"
  printf '[dotfiles]\n"~/.config/context-link" = { source = "adjacent.txt" }\n' >"$MISE_DIR/config.toml"
  echo adjacent-resource >"$MISE_DIR/adjacent.txt"
  CONFIG_BEFORE=$(cksum "$MISE_DIR/config.toml")
  RESOURCE_BEFORE=$(cksum "$MISE_DIR/adjacent.txt")
  run_df DOTFILES_PROFILE=cachyos PATH="$C/native:$T/stub:$ORIG_PATH" MISE_OFFLINE=1 MISE_TRUSTED_CONFIG_PATHS="$C" --plain --dry-run --only dotfiles
  expect_rc 1
  expect_contains "$ERR" "cannot faithfully preview" "native unconfigured context is rejected"
  expect_eq "$(cksum "$MISE_DIR/config.toml")" "$CONFIG_BEFORE" "rejected native preview leaves retained config unchanged"
  expect_eq "$(cksum "$MISE_DIR/adjacent.txt")" "$RESOURCE_BEFORE" "rejected native preview leaves adjacent resource unchanged"
  [ ! -e "$MISE_DIR/conf.d" ] || fail "rejected native preview configured live mise"
  [ ! -e "$HOME/.config/context-link" ] || fail "rejected native preview deployed a target"
  ln -s "$DOTFILES_DIR/modules" "$MISE_DIR/conf.d"
  run_df DOTFILES_PROFILE=cachyos --set-purpose personal
  expect_rc 0
  run_df DOTFILES_PROFILE=cachyos PATH="$C/native:$T/stub:$ORIG_PATH" MISE_OFFLINE=1 MISE_TRUSTED_CONFIG_PATHS="$C" --plain --dry-run --only dotfiles
  expect_rc 0
  expect_contains "$OUT$ERR" "$MISE_DIR/adjacent.txt" "native consumer resolves the adjacent source in its original context"
  [ ! -e "$HOME/.config/context-link" ] || fail "native preview deployed a target"
  expect_eq "$(cat "$MISE_DIR/adjacent.txt")" adjacent-resource "native preview leaves adjacent resource unchanged"

  # The audit's real project fixture: a local tool, source-relative dotfile and
  # overriding root bootstrap task must not leak into an ordinary machine run.
  cat >"$DOTFILES_DIR/modules/base/mise.toml" <<'EOF'
min_version = "2026.10.6"
[tasks.bootstrap]
run = "mise run --jobs 1 'bootstrap:*'"
[tasks."bootstrap:HOME_CONTEXT_PROOF"]
run = "touch {{env.HOME}}/HOME_BOOTSTRAP_MUST_NOT_RUN"
EOF
  cat >"$C/work/mise.toml" <<'EOF'
[tools]
node = "22.0.0"
[dotfiles]
"~/PROJECT_DOTFILE_CWD_PROOF" = { source = "adjacent.txt" }
[tasks.bootstrap]
run = "echo PROJECT_ROOT_BOOTSTRAP_MUST_NOT_RUN > \"{{env.HOME}}/PROJECT_ROOT_BOOTSTRAP_MUST_NOT_RUN\""
[tasks."bootstrap:UNRELATED_CWD_PROOF"]
run = "touch {{env.HOME}}/PROJECT_CHILD_BOOTSTRAP_MUST_NOT_RUN"
EOF
  echo project-resource >"$C/work/adjacent.txt"
  echo existing-project-target >"$HOME/PROJECT_DOTFILE_CWD_PROOF"
  native_preview() {
    run_df DOTFILES_PROFILE=cachyos PATH="$C/native:$T/stub:$ORIG_PATH" \
      MISE_OFFLINE=1 MISE_TASK_RUN_AUTO_INSTALL=0 MISE_TRUSTED_CONFIG_PATHS="$C" "$@" --dry-run
  }
  expect_home_context() {
    expect_rc 0
    case $OUT$ERR in
      *PROJECT_* | *UNRELATED_CWD_PROOF* | *node@22.0.0*)
        fail "caller project contaminated the home preview: $OUT$ERR" ;;
    esac
  }
  native_preview --plain
  expect_home_context
  # Native mise emits tool/task dry-run previews on stderr, unlike some dotfile output.
  expect_contains "$OUT$ERR" "mise run --jobs 1 'bootstrap:*'" "home root bootstrap task selected"
  expect_contains "$OUT$ERR" "$MISE_DIR/adjacent.txt" "home preview retains original source-relative config"

  # Every supported directory-flag spelling retains caller-relative semantics.
  for cd_form in short long long-equals short-attached; do
    case $cd_form in
      short) context_args=(-C .) ;;
      long) context_args=(--cd .) ;;
      long-equals) context_args=(--cd=.) ;;
      short-attached) context_args=(-C.) ;;
    esac
    native_preview --plain "${context_args[@]}"
    expect_rc 0
    expect_contains "$OUT$ERR" "$C/work/adjacent.txt" "explicit context resolves project-relative source"
    expect_contains "$OUT$ERR" "node@22.0.0" "explicit context selects project tool"
    expect_contains "$OUT$ERR" "PROJECT_ROOT_BOOTSTRAP_MUST_NOT_RUN" "explicit context selects project bootstrap"
    # Existing target requires the same project's conflict probe to request force.
    expect_contains "$OUT$ERR" "PROJECT_DOTFILE_CWD_PROOF" "explicit context previews the conflicting project target"
  done
  native_preview --plain -C "$HOME"
  expect_home_context
  native_preview DOTFILES_UI=1 --only dotfiles,tools,task
  expect_home_context
  expect_contains "$OUT$ERR" "HOME_CONTEXT_PROOF" "UI task discovery uses the home context"
  expect_eq "$(cat "$HOME/PROJECT_DOTFILE_CWD_PROOF")" existing-project-target "all previews preserve the conflicting target"
  [ ! -e "$HOME/HOME_BOOTSTRAP_MUST_NOT_RUN" ] || fail "home bootstrap task executed during preview"
  [ ! -e "$HOME/PROJECT_ROOT_BOOTSTRAP_MUST_NOT_RUN" ] || fail "project root task executed during preview"
  [ ! -e "$HOME/PROJECT_CHILD_BOOTSTRAP_MUST_NOT_RUN" ] || fail "project child task executed during preview"
  [ ! -e "$HOME/.config/context-link" ] || fail "context previews deployed the global link"
  [ ! -e "$C/mise/data/installs" ] || fail "context previews installed a tool"
  rm "$HOME/PROJECT_DOTFILE_CWD_PROOF"
else
  echo "SKIP native source-relative preview: set DOTFILES_TEST_REAL_MISE to a trusted mise executable" >&2
fi

new_case dry-run-does-not-pull
setup_remote
OLD=$(git -C "$DOTFILES_DIR" rev-parse HEAD)
run_df DOTFILES_PROFILE=cachyos --dry-run
expect_rc 0
expect_eq "$(git -C "$DOTFILES_DIR" rev-parse HEAD)" "$OLD" "preflight does not fast-forward"
expect_eq "$(cat "$C/git.argv")" "" "preflight does not invoke git sync"
new_case dry-run-preserves-config-selection
init_repo "$DOTFILES_DIR"
run_df DOTFILES_PROFILE=cachyos --dry-run --env work --only dotfiles
expect_rc 0
expect_contains "$(tr '\n' ' ' <"$C/mise.dot.argv")" "--env work" "safety probe uses requested environment"
expect_contains "$(tr '\n' ' ' <"$C/mise.argv")" "--env work --only dotfiles" "bootstrap retains the same selection"
[ ! -e "$MISE_DIR" ] || fail "environment-selected preflight wrote live config"

for unsafe_arg in --prompt-vars --adopt=example.invalid/config; do
  new_case "dry-run-rejects-$unsafe_arg"
  init_repo "$DOTFILES_DIR"
  run_df DOTFILES_PROFILE=macos --dry-run "$unsafe_arg"
  expect_rc 1
  expect_eq "$(cat "$C/mise.calls")" "" "stateful modes do not reach bootstrap"
  expect_eq "$(cat "$C/git.argv")" "" "stateful modes do not sync a checkout"
  expect_eq "$(cat "$C/curl.argv")" "" "stateful modes do not download"
  [ ! -e "$MISE_DIR" ] || fail "rejected preflight mode wrote live config"
done


new_case dry-run-old-mise-no-upgrade
init_repo "$DOTFILES_DIR"
echo '2026.9.1 macos-arm64' >"$C/mise.version"
run_df DOTFILES_PROFILE=macos --dry-run
expect_rc 1
expect_contains "$ERR" "brew upgrade mise" "actionable manual upgrade guidance"
expect_eq "$(cat "$C/brew.argv")" "" "old mise does not trigger upgrade"
expect_eq "$(cat "$C/mise.calls")" "" "old mise does not run bootstrap"
expect_eq "$(cat "$C/git.argv")" "" "old mise does not sync checkout"
[ ! -e "$MISE_DIR" ] || fail "old mise preflight wrote live config"

new_case dry-run-missing-checkout
run_df DOTFILES_PROFILE=macos --dry-run
expect_rc 1
expect_contains "$ERR" "local checkout" "actionable checkout guidance"
expect_eq "$(cat "$C/git.argv")" "" "missing checkout does not trigger clone"
expect_eq "$(cat "$C/curl.argv")" "" "missing checkout does not download"
[ ! -e "$MISE_DIR" ] || fail "missing checkout preflight wrote live config"

new_case dry-run-missing-mise
init_repo "$DOTFILES_DIR"
mkdir "$C/path"
# Keep basic shell utilities and mutation-denying stubs, but no mise or real PATH.
for cmd in bash uname sed; do ln -s "$(command -v "$cmd")" "$C/path/$cmd"; done
for cmd in brew curl sudo git; do ln -s "$T/stub/$cmd" "$C/path/$cmd"; done
run_df DOTFILES_PROFILE=macos PATH="$C/path" --dry-run
expect_rc 1
expect_contains "$ERR" "mise" "missing prerequisite is named"
expect_eq "$(cat "$C/brew.argv")" "" "missing mise does not trigger install"
expect_eq "$(cat "$C/sudo.log")" "" "missing mise does not invoke sudo"
expect_eq "$(cat "$C/curl.argv")" "" "missing mise does not download"
[ ! -e "$MISE_DIR" ] || fail "missing mise preflight wrote live config"

# ---- mise version guard ----
# set_mise_version <version>: what the stub mise reports for --version.
set_mise_version() { echo "$1 linux-x64 (2026-01-01)" >"$C/mise.version"; }

new_case mise-version-equal
init_repo "$DOTFILES_DIR"
set_mise_version 2026.10.6
run_df DOTFILES_PROFILE=cachyos --dry-run
expect_rc 0
expect_eq "$(tr '\n' ' ' <"$C/mise.argv")" "bootstrap --yes --dry-run " "mise argv"

new_case mise-version-numeric-compare
init_repo "$DOTFILES_DIR"
set_mise_version 2026.10.10
run_df DOTFILES_PROFILE=cachyos --dry-run
expect_rc 0
expect_eq "$(tr '\n' ' ' <"$C/mise.argv")" "bootstrap --yes --dry-run " "mise argv"

new_case mise-version-longer-field-count
init_repo "$DOTFILES_DIR"
set_mise_version 2027.1
run_df DOTFILES_PROFILE=cachyos --dry-run
expect_rc 0
expect_eq "$(tr '\n' ' ' <"$C/mise.argv")" "bootstrap --yes --dry-run " "mise argv"

new_case mise-version-too-old-linux
init_repo "$DOTFILES_DIR"
set_mise_version 2026.9.1
run_df DOTFILES_PROFILE=cachyos --dry-run
expect_rc 1
expect_contains "$ERR" "mise 2026.9.1 is older than 2026.10.6" stderr
expect_contains "$ERR" "pacman -Syu" "upgrade hint"
expect_eq "$(cat "$C/mise.argv")" "" "mise bootstrap must not run"
expect_eq "$(cat "$C/brew.argv")" "" "brew must not run on Linux"

new_case mise-version-non-numeric
init_repo "$DOTFILES_DIR"
set_mise_version dev
run_df DOTFILES_PROFILE=cachyos --dry-run
expect_rc 1
expect_eq "$(cat "$C/mise.argv")" "" "unverifiable mise cannot preview"

new_case mise-version-no-min-line
init_repo "$DOTFILES_DIR"
printf '[tasks.bootstrap]\nrun = "true"\n' >"$DOTFILES_DIR/modules/base/mise.toml"
set_mise_version 2020.1.1
run_df DOTFILES_PROFILE=cachyos --dry-run
expect_rc 1
expect_eq "$(cat "$C/mise.argv")" "" "unknown minimum cannot preview"

new_case mise-version-no-base-file
init_repo "$DOTFILES_DIR"
rm "$DOTFILES_DIR/modules/base/mise.toml"
set_mise_version 2020.1.1
run_df DOTFILES_PROFILE=cachyos --dry-run
expect_rc 1
expect_eq "$(cat "$C/mise.argv")" "" "missing candidate config cannot preview"

# macOS cases reach brew only through the stub, and only when the real
# /opt/homebrew/bin/brew (whose shellenv would shadow the stubs) is absent.
if [ -x /opt/homebrew/bin/brew ]; then
  echo "SKIP macos mise version cases: /opt/homebrew/bin/brew exists on this machine" >&2
else
  new_case mise-version-old-macos-upgrade-fixes
  init_repo "$DOTFILES_DIR"
  set_mise_version 2026.9.1
  run_df DOTFILES_PROFILE=macos STUB_BREW_UPGRADE_TO="2026.10.10 macos-arm64 (2026-10-09)"
  expect_rc 0
  expect_eq "$(cat "$C/brew.argv")" "upgrade mise" "brew argv"
  expect_eq "$(tr '\n' ' ' <"$C/mise.argv")" "bootstrap --yes " "mise argv"

  new_case mise-version-old-macos-still-old
  init_repo "$DOTFILES_DIR"
  set_mise_version 2026.9.1
  run_df DOTFILES_PROFILE=macos
  expect_rc 1
  expect_eq "$(cat "$C/brew.argv")" "upgrade mise" "brew argv (upgraded once)"
  expect_contains "$ERR" "mise 2026.9.1 is older than 2026.10.6" stderr
  expect_contains "$ERR" "brew upgrade mise" "upgrade hint"
  expect_eq "$(cat "$C/mise.argv")" "" "mise bootstrap must not run"

  new_case mise-version-current-macos-no-brew
  init_repo "$DOTFILES_DIR"
  set_mise_version 2026.10.10
  run_df DOTFILES_PROFILE=macos --dry-run
  expect_rc 0
  expect_eq "$(cat "$C/brew.argv")" "" "brew must not run when mise is current"
fi

# ---- UI mode (DOTFILES_UI=1: no terminal, no animation, just the final lines) ----
STAGE_CALLS='bootstrap --yes --only accounts,plugins,packages
bootstrap --yes --only files,services,firewall,compose
bootstrap --yes --only repos,dotfiles
bootstrap --yes --only mise-shell-activate,macos-defaults,macos-launchd-agents,linux-systemd-units,user
bootstrap --yes --only tools
bootstrap --yes --only task,final-hook'
calls() { cat "$C/mise.calls"; }
ui_case() { # ui_case <name> [run_df words]: fresh repo, cachyos, UI forced
  local name=$1
  shift
  new_case "$name"
  init_repo "$DOTFILES_DIR"
  run_df DOTFILES_PROFILE=cachyos DOTFILES_UI=1 "$@"
}

ui_case ui-stage-order
expect_rc 0
expect_eq "$(calls)" "$STAGE_CALLS" "stage invocations"
expect_contains "$OUT" "◆ dotfiles" "header"
expect_contains "$OUT" "cachyos ·" "header profile"
expect_contains "$OUT" "no upstream for main" "repo warning line"
expect_contains "$OUT" "✓ converged in" "footer"
expect_contains "$OUT" "$C/xdg/state/dotfiles/last-run.log" "log path in footer"
for s in packages system dotfiles shell tools modules; do expect_contains "$OUT" "✓ $s" "stage line $s"; done
case $OUT in *$'\033'*) fail "escape sequences without a terminal" ;; esac
LOGF="$C/xdg/state/dotfiles/last-run.log"
expect_contains "$(cat "$LOGF")" "profile: cachyos" "log header"
expect_contains "$(cat "$LOGF")" '$ mise bootstrap --yes --only files,services,firewall,compose' "stage command in log"
expect_contains "$(cat "$LOGF")" "mise bootstrap: stub tools" "stage output in log"
expect_contains "$OUT" "✓ packages   done" "result without plan details"
expect_eq "$(calls | grep -c 'only repos,dotfiles')" 1 "no second pass when converged"
if [ "$(id -u)" -ne 0 ]; then expect_eq "$(cat "$C/sudo.log")" "-n true" "a valid sudo ticket is not renewed"; fi

ui_case ui-only-dotfiles --only dotfiles
expect_rc 0
expect_eq "$(calls)" "bootstrap --yes --only dotfiles" "--only dotfiles"
expect_contains "$OUT" "✓ dotfiles" "dotfiles stage line"
case $OUT in *"✓ tools"*) fail "tools stage shown for --only dotfiles" ;; esac

ui_case ui-only-equals --only=tools,task
expect_eq "$(calls)" "bootstrap --yes --only tools
bootstrap --yes --only task" "--only=tools,task"

ui_case ui-skip-tools --skip tools
expect_rc 0
expect_eq "$(calls)" "$(printf '%s\n' "$STAGE_CALLS" | grep -v 'only tools$')" "--skip tools"
case $OUT in *"✓ tools"*) fail "tools stage shown for --skip tools" ;; esac

ui_case ui-shell-chsh STUB_SHELL_STATE=differs
expect_rc 0
expect_contains "$OUT" "chsh may ask for your password" "shell stage on the terminal when chsh runs"
expect_eq "$(calls)" "$STAGE_CALLS" "stage invocations with an attended shell stage"
case $(cat "$C/xdg/state/dotfiles/last-run.log") in
  *"--only mise-shell-activate,macos-defaults,macos-launchd-agents,linux-systemd-units,user (on the terminal"*) ;;
  *) fail "attended shell stage not noted in the log" ;;
esac
ui_case ui-shell-set
case $OUT in *chsh*) fail "chsh note shown although the shell is already set" ;; esac


ui_case ui-failure STUB_FAIL_ONLY=files,services,firewall,compose
expect_rc 3
expect_eq "$(calls)" "$(printf '%s\n' "$STAGE_CALLS" | sed -n 1,2p)" "no stage after the failed one"
expect_contains "$OUT" "✓ packages" "stage before the failure"
expect_contains "$OUT" "✗ system" "failed stage line"
expect_contains "$OUT" "stub: boom in files,services,firewall,compose" "log tail in the box"
expect_contains "$OUT" "$C/xdg/state/dotfiles/last-run.log" "log path"
expect_contains "$OUT" "✗ failed in" "footer"
expect_contains "$(cat "$C/xdg/state/dotfiles/last-run.log")" '$ mise bootstrap --yes --only files,services,firewall,compose' "stage command in log"

MODULES_OUT='[bootstrap:alpha] $ ./bootstrap.sh\nalpha fine\n[bootstrap:beta] sources up-to-date, skipping\n[bootstrap:secrets] $ ./bootstrap.sh\nsecrets: 1Password locked, skipped\n'
PLAN='{"resources":[{"id":{"kind":"package","name":"pacman:jq"},"action":"noop"},{"id":{"kind":"package","name":"pacman:bat"},"action":"create"},{"id":{"kind":"file","name":"/etc/x"},"action":"noop"}]}'
ui_case ui-module-warnings "STUB_MODULES_OUT=$MODULES_OUT" "STUB_PLAN_JSON=$PLAN"
expect_rc 0
expect_contains "$OUT" "✓ modules" "modules stage line"
expect_contains "$OUT" "2 ran · 1 up to date" "modules result"
expect_contains "$OUT" "! secrets" "warning names the module"
expect_contains "$OUT" "1Password locked, skipped" "warning message"
case $OUT in *"! beta"*) fail "an up-to-date task is not a warning" ;; esac
if command -v jq >/dev/null 2>&1; then
  expect_contains "$OUT" "1 present · 1 installed: bat" "package result"
  expect_contains "$OUT" "1 file unchanged" "system file result"
else
  echo "SKIP plan details: jq missing" >&2
fi

# dot status --missing failing once: permission entries on merge-created files need a second pass.
new_case ui-second-pass
init_repo "$DOTFILES_DIR"
echo 1 >"$C/dot.count"
run_df DOTFILES_PROFILE=cachyos DOTFILES_UI=1 -j 2 --force-dotfiles --yes
expect_rc 0
DOTFILES_CALL='bootstrap --yes --only repos,dotfiles -j 2 --force-dotfiles'
expect_eq "$(calls | sed -n 3,4p)" "$DOTFILES_CALL
$DOTFILES_CALL" "dotfiles stage runs twice, flags on both"
expect_eq "$(calls | wc -l | tr -d ' ')" 7 "other stages run once"

for plain_args in "--plain" "-v" "--prompt-secrets" "--only bogus" "--only dotfiles --skip tools"; do
  new_case "plain-trigger $plain_args"
  init_repo "$DOTFILES_DIR"
  # shellcheck disable=SC2086
  run_df DOTFILES_PROFILE=cachyos DOTFILES_UI=1 $plain_args
  expect_rc 0
  want="bootstrap --yes ${plain_args#--plain}"
  expect_eq "$(calls)" "${want% }" "single plain exec for '$plain_args'"
  case $OUT in *"◆ dotfiles"*) fail "UI header in plain mode for '$plain_args'" ;; esac
done
new_case plain-ui-disabled
init_repo "$DOTFILES_DIR"
run_df DOTFILES_PROFILE=cachyos DOTFILES_UI=0
expect_eq "$(calls)" "bootstrap --yes" "DOTFILES_UI=0 stays plain"

new_case home-context-plain
init_repo "$DOTFILES_DIR"
run_df DOTFILES_PROFILE=cachyos STUB_EXPECT_CWD="$HOME" --only dotfiles
expect_rc 0
new_case home-context-ui
init_repo "$DOTFILES_DIR"
run_df DOTFILES_PROFILE=cachyos DOTFILES_UI=1 STUB_EXPECT_CWD="$HOME"
expect_rc 0

ui_case ui-dry-run --dry-run
expect_rc 0
expect_eq "$(calls)" "$(printf '%s\n' "$STAGE_CALLS" | sed 's/$/ --dry-run/')" "every stage gets --dry-run"
expect_contains "$OUT" "dry run" "dry-run badge and footer"
expect_contains "$OUT" "✓ dry run in" "footer"
expect_contains "$OUT" "1 change" "packages change count"
expect_contains "$OUT" "sudo pacman -S --noconfirm --needed -- cowsay" "change line"
expect_contains "$OUT" "npm:left-pad@1.3.0 ⇢ would install" "tools change line"
expect_contains "$OUT" "✓ system     no changes" "unchanged stage"
expect_contains "$OUT" "would run 3 tasks" "module task count"
expect_contains "$OUT" "alpha beta secrets" "module task names"
case $OUT in *"mise bootstrap:"*) fail "section headers leak into the dry-run output" ;; esac
expect_eq "$(cat "$C/sudo.log")" "" "dry-run does not authenticate sudo"
[ ! -e "$C/xdg/state/dotfiles" ] || fail "dry-run wrote live wrapper state"

if [ "$(id -u)" -eq 0 ]; then
  echo "SKIP sudo priming: running as root" >&2
else
  ui_case ui-sudo-primed STUB_SUDO_N=1
  expect_contains "$(cat "$C/sudo.log")" "-v" "sudo -v runs when no ticket exists"
  expect_contains "$OUT" "password needed" "sudo line"
  ui_case ui-sudo-not-needed STUB_SUDO_N=1 --only tools,dotfiles
  expect_eq "$(cat "$C/sudo.log")" "" "no sudo for parts that need none"
fi

usage_out=$(env -i HOME="$HOME" PATH="$T/stub:$ORIG_PATH" "$BIN" --help)
expect_contains "$usage_out" "--plain" "help documents --plain"
expect_contains "$usage_out" "last-run.log" "help names the log"

# ---- targets mise refuses to replace with a link (a fresh Omarchy's own configs) ----
SB_CONFIG="$T/home/.config" # the sandbox HOME's .config, never the real one
seed_conflicts() {
  rm -rf "$SB_CONFIG"
  mkdir -p "$SB_CONFIG/ghostty" "$SB_CONFIG/nvim"
  echo omarchy >"$SB_CONFIG/ghostty/config"
  echo starter >"$SB_CONFIG/nvim/init.lua"
}
backups() { # moved-aside paths under .config, timestamps replaced by N
  find "$SB_CONFIG" -maxdepth 2 -name '*.pre-dotfiles.*' | sed "s|^$T/home/||; s/\.pre-dotfiles\.[0-9]*\.[^/]*$/.pre-dotfiles.N/" | sort | tr '\n' ' '
}
REFUSE='STUB_REFUSE=~/.config/ghostty/config:~/.config/nvim'
MOVED='.config/ghostty/config.pre-dotfiles.N .config/nvim.pre-dotfiles.N '

new_case conflicts-plain
init_repo "$DOTFILES_DIR"
seed_conflicts
run_df DOTFILES_PROFILE=cachyos "$REFUSE"
expect_rc 0
expect_eq "$(backups)" "$MOVED" "refused targets moved aside"
expect_eq "$(cat "$SB_CONFIG"/ghostty/config.pre-dotfiles.*/original)" omarchy "moved file keeps its content"
expect_eq "$(cat "$SB_CONFIG"/nvim.pre-dotfiles.*/original/init.lua)" starter "moved directory keeps its content"
[ ! -e "$SB_CONFIG/ghostty/config" ] && [ ! -e "$SB_CONFIG/nvim" ] || fail "conflicts were not cleared"
expect_eq "$(tr '\n' ' ' <"$C/mise.argv")" "bootstrap --yes " "no --force-dotfiles after moving"

new_case conflicts-dry-run
init_repo "$DOTFILES_DIR"
seed_conflicts
run_df DOTFILES_PROFILE=cachyos "$REFUSE" --dry-run
expect_rc 0
expect_eq "$(backups)" "" "a dry run moves nothing"
expect_eq "$(cat "$SB_CONFIG/ghostty/config")" omarchy "dry-run preserves the original file"
expect_eq "$(cat "$SB_CONFIG/nvim/init.lua")" starter "dry-run preserves the original directory"
expect_eq "$(tr '\n' ' ' <"$C/mise.argv")" "bootstrap --yes --force-dotfiles --dry-run " "preview as if moved"

new_case conflicts-without-dotfiles
init_repo "$DOTFILES_DIR"
seed_conflicts
run_df DOTFILES_PROFILE=cachyos "$REFUSE" --only tools
expect_eq "$(backups)" "" "--only tools leaves them in place"

new_case conflicts-ui
init_repo "$DOTFILES_DIR"
seed_conflicts
run_df DOTFILES_PROFILE=cachyos DOTFILES_UI=1 "$REFUSE"
expect_rc 0
expect_eq "$(backups)" "$MOVED" "UI moves them too"
[ ! -e "$SB_CONFIG/nvim" ] || fail "UI apply did not clear the conflict"
expect_eq "$(calls)" "$STAGE_CALLS" "stages unchanged, no --force-dotfiles"

# A partial refusal list must not be treated as permission to move any target.
for preview_kind in unrelated combined trailing duplicate nested missing traversal wrong-status; do
  new_case "conflicts-preview-$preview_kind"
  init_repo "$DOTFILES_DIR"
  seed_conflicts
  preview_rc=1
  header='mise ERROR files: refusing to overwrite existing files (use --force):'
  trailer='mise ERROR Version: stub\nmise ERROR Run with --verbose or MISE_VERBOSE=1 for more information'
  case $preview_kind in
    unrelated) preview='mise ERROR invalid configuration'; preview_rc=7 ;;
    combined) preview="$header\n  ~/.config/ghostty/config\nmise ERROR files: sources do not exist:\n  missing\n$trailer" ;;
    trailing) preview="$header\n  ~/.config/ghostty/config\n$trailer\nmise ERROR unexpected failure" ;;
    duplicate) preview="$header\n  ~/.config/ghostty/config\n  ~/.config/ghostty/config\n$trailer" ;;
    nested) preview="$header\n  ~/.config/nvim\n  ~/.config/nvim/init.lua\n$trailer" ;;
    missing) preview="$header\n  ~/.config/ghostty/config\n  ~/.config/not-present\n$trailer" ;;
    traversal) preview="$header\n  ~/.config/ghostty/config\n  ~/.config/nvim/../nvim\n$trailer" ;;
    wrong-status) preview="$header\n  ~/.config/ghostty/config\n$trailer"; preview_rc=9 ;;
  esac
  run_df DOTFILES_PROFILE=cachyos "STUB_PREVIEW_ERROR=$preview" "STUB_PREVIEW_RC=$preview_rc"
  expect_rc "$preview_rc"
  expect_contains "$(cat "$C/mise.dot.argv")" "--dry-run" "negative control reaches dotfile preview"
  expect_eq "$(cat "$SB_CONFIG/ghostty/config")" omarchy "preview failure preserves original file"
  expect_eq "$(cat "$SB_CONFIG/nvim/init.lua")" starter "preview failure preserves original directory"
  expect_eq "$(backups)" "" "preview failure does not move even an earlier valid target"
  expect_eq "$(cat "$C/mise.calls")" "" "preview failure never proceeds to bootstrap"
done

new_case conflicts-unique-backups-even-on-apply-failure
init_repo "$DOTFILES_DIR"
seed_conflicts
# A previous backup, including a nonempty directory, is never reused as a
# destination. The date stub deliberately gives every run the same timestamp.
mkdir "$SB_CONFIG/ghostty/config.pre-dotfiles.1234567890"
echo oldest >"$SB_CONFIG/ghostty/config.pre-dotfiles.1234567890/keep"
run_df DOTFILES_PROFILE=cachyos "$REFUSE" STUB_BOOTSTRAP_RC=5
expect_rc 5
expect_eq "$(cat "$SB_CONFIG/ghostty/config.pre-dotfiles.1234567890/keep")" oldest "prior backup survives failed apply"
[ ! -e "$SB_CONFIG/ghostty/config.pre-dotfiles.1234567890/config" ] || fail "new original nested in an old backup"
expect_eq "$(cat "$SB_CONFIG"/ghostty/config.pre-dotfiles.1234567890.*/original)" omarchy "failed apply keeps file backup"
expect_eq "$(cat "$SB_CONFIG"/nvim.pre-dotfiles.*/original/init.lua)" starter "failed apply keeps directory backup"
mkdir -p "$SB_CONFIG/nvim"
echo second >"$SB_CONFIG/ghostty/config"
echo second-tree >"$SB_CONFIG/nvim/init.lua"
run_df DOTFILES_PROFILE=cachyos "$REFUSE"
expect_rc 0
expect_eq "$(find "$SB_CONFIG/ghostty" -name original -type f | wc -l | tr -d ' ')" 2 "same-second runs reserve separate file backups"
expect_eq "$(cat "$SB_CONFIG"/ghostty/config.pre-dotfiles.1234567890.*/original | sort)" 'omarchy
second' "every file original survives"
expect_eq "$(cat "$SB_CONFIG"/nvim.pre-dotfiles.*/original/init.lua | sort)" 'second-tree
starter' "every directory original survives"
expect_eq "$(cat "$SB_CONFIG/ghostty/config.pre-dotfiles.1234567890/keep")" oldest "prior backup remains unchanged"

new_case conf-d-unique-backups
init_repo "$DOTFILES_DIR"
mkdir -p "$MISE_DIR/conf.d" "$MISE_DIR/conf.d.pre-dotfiles.1234567890"
echo oldest >"$MISE_DIR/conf.d.pre-dotfiles.1234567890/keep"
echo first >"$MISE_DIR/conf.d/personal.toml"
run_df DOTFILES_PROFILE=cachyos --only tools
expect_rc 0
rm "$MISE_DIR/conf.d"
mkdir "$MISE_DIR/conf.d"
echo second >"$MISE_DIR/conf.d/personal.toml"
run_df DOTFILES_PROFILE=cachyos --only tools
expect_rc 0
expect_eq "$(cat "$MISE_DIR"/conf.d.pre-dotfiles.1234567890.*/original/personal.toml | sort)" 'first
second' "every prior conf.d survives same-second runs"
expect_eq "$(cat "$MISE_DIR/conf.d.pre-dotfiles.1234567890/keep")" oldest "legacy conf.d backup untouched"
rm -rf "$SB_CONFIG"

if [ "$FAILS" -ne 0 ]; then
  echo "test_bin_dotfiles: $FAILS failure(s)" >&2
  exit 1
fi
echo "test_bin_dotfiles: all passed"
