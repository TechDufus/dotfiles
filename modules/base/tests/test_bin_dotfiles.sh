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
# --version answers from $MISE_VERSION_FILE (default: a passing version); other argv is recorded.
if [ "$1" = --version ]; then
  cat "$MISE_VERSION_FILE" 2>/dev/null || echo "2026.10.6 linux-x64 (2026-10-09)"
  exit 0
fi
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
cat >"$T/stub/brew" <<'EOF'
#!/bin/sh
# Records argv; 'upgrade' installs the version in $STUB_BREW_UPGRADE_TO when set.
printf '%s\n' "$*" >>"$BREW_ARGV_FILE"
if [ "$1" = upgrade ] && [ -n "${STUB_BREW_UPGRADE_TO:-}" ]; then
  echo "$STUB_BREW_UPGRADE_TO" >"$MISE_VERSION_FILE"
fi
exit 0
EOF
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
  : >"$C/brew.argv"
  if OUT=$(env -i \
    HOME="$HOME" PATH="$T/stub:$ORIG_PATH" GIT_CONFIG_NOSYSTEM=1 \
    XDG_CONFIG_HOME="$C/xdg/config" XDG_DATA_HOME="$C/xdg/data" \
    XDG_STATE_HOME="$C/xdg/state" XDG_CACHE_HOME="$C/xdg/cache" \
    DOTFILES_DIR="$DOTFILES_DIR" DOTFILES_SYSROOT="$SYSROOT" \
    MISE_ARGV_FILE="$C/mise.argv" REAL_UNAME="$REAL_UNAME" \
    MISE_VERSION_FILE="$C/mise.version" BREW_ARGV_FILE="$C/brew.argv" \
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
expect_rc 0
expect_eq "$(tr '\n' ' ' <"$C/mise.argv")" "bootstrap --yes --dry-run " "mise argv"

new_case mise-version-no-min-line
init_repo "$DOTFILES_DIR"
printf '[tasks.bootstrap]\nrun = "true"\n' >"$DOTFILES_DIR/modules/base/mise.toml"
set_mise_version 2020.1.1
run_df DOTFILES_PROFILE=cachyos --dry-run
expect_rc 0
expect_eq "$(tr '\n' ' ' <"$C/mise.argv")" "bootstrap --yes --dry-run " "mise argv"

new_case mise-version-no-base-file
init_repo "$DOTFILES_DIR"
rm "$DOTFILES_DIR/modules/base/mise.toml"
set_mise_version 2020.1.1
run_df DOTFILES_PROFILE=cachyos --dry-run
expect_rc 0
expect_eq "$(tr '\n' ' ' <"$C/mise.argv")" "bootstrap --yes --dry-run " "mise argv"

# macOS cases reach brew only through the stub, and only when the real
# /opt/homebrew/bin/brew (whose shellenv would shadow the stubs) is absent.
if [ -x /opt/homebrew/bin/brew ]; then
  echo "SKIP macos mise version cases: /opt/homebrew/bin/brew exists on this machine" >&2
else
  new_case mise-version-old-macos-upgrade-fixes
  init_repo "$DOTFILES_DIR"
  set_mise_version 2026.9.1
  run_df DOTFILES_PROFILE=macos STUB_BREW_UPGRADE_TO="2026.10.10 macos-arm64 (2026-10-09)" --dry-run
  expect_rc 0
  expect_eq "$(cat "$C/brew.argv")" "upgrade mise" "brew argv"
  expect_eq "$(tr '\n' ' ' <"$C/mise.argv")" "bootstrap --yes --dry-run " "mise argv"

  new_case mise-version-old-macos-still-old
  init_repo "$DOTFILES_DIR"
  set_mise_version 2026.9.1
  run_df DOTFILES_PROFILE=macos --dry-run
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

if [ "$FAILS" -ne 0 ]; then
  echo "test_bin_dotfiles: $FAILS failure(s)" >&2
  exit 1
fi
echo "test_bin_dotfiles: all passed"
