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
# --version answers from $MISE_VERSION_FILE (default: a passing version).
# 'bootstrap --only X ...' (a stage) is recorded in $MISE_CALLS_FILE; any bootstrap call
# overwrites $MISE_ARGV_FILE. Stage behaviour comes from the STUB_* variables.
if [ "$1" = --version ]; then
  cat "$MISE_VERSION_FILE" 2>/dev/null || echo "2026.10.6 linux-x64 (2026-10-09)"
  exit 0
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
    # Like mise when targets exist and are not links: $STUB_REFUSE is a ':' list of them.
    [ -n "${STUB_REFUSE:-}" ] || exit 0
    echo "mise ERROR files: refusing to overwrite existing files (use --force):"
    echo "$STUB_REFUSE" | tr ':' '\n' | sed 's/^/  /'
    echo "mise ERROR Version: stub"
    exit 1
    ;;
esac
printf '%s\n' "$@" >"$MISE_ARGV_FILE"
echo "$*" >>"$MISE_CALLS_FILE"
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
cat >"$T/stub/brew" <<'EOF'
#!/bin/sh
# Records argv; 'upgrade' installs the version in $STUB_BREW_UPGRADE_TO when set.
printf '%s\n' "$*" >>"$BREW_ARGV_FILE"
if [ "$1" = upgrade ] && [ -n "${STUB_BREW_UPGRADE_TO:-}" ]; then
  echo "$STUB_BREW_UPGRADE_TO" >"$MISE_VERSION_FILE"
fi
exit 0
EOF
chmod +x "$T/stub/mise" "$T/stub/uname" "$T/stub/brew" "$T/stub/sudo"

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
  : >"$C/mise.calls"
  : >"$C/sudo.log"
  : >"$C/brew.argv"
  if OUT=$(env -i \
    HOME="$HOME" PATH="$T/stub:$ORIG_PATH" GIT_CONFIG_NOSYSTEM=1 \
    XDG_CONFIG_HOME="$C/xdg/config" XDG_DATA_HOME="$C/xdg/data" \
    XDG_STATE_HOME="$C/xdg/state" XDG_CACHE_HOME="$C/xdg/cache" \
    DOTFILES_DIR="$DOTFILES_DIR" DOTFILES_SYSROOT="$SYSROOT" \
    MISE_ARGV_FILE="$C/mise.argv" MISE_CALLS_FILE="$C/mise.calls" REAL_UNAME="$REAL_UNAME" \
    MISE_VERSION_FILE="$C/mise.version" BREW_ARGV_FILE="$C/brew.argv" \
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
expect_contains "$(cat "$C/xdg/state/dotfiles/last-run.log")" "args: --dry-run" "log header names the arguments"

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
  find "$SB_CONFIG" -maxdepth 2 -name '*.pre-dotfiles.*' | sed "s|^$T/home/||; s/\.pre-dotfiles\.[0-9]*$/.pre-dotfiles.N/" | sort | tr '\n' ' '
}
REFUSE='STUB_REFUSE=~/.config/ghostty/config:~/.config/nvim'
MOVED='.config/ghostty/config.pre-dotfiles.N .config/nvim.pre-dotfiles.N '

new_case conflicts-plain
init_repo "$DOTFILES_DIR"
seed_conflicts
run_df DOTFILES_PROFILE=cachyos "$REFUSE"
expect_rc 0
expect_eq "$(backups)" "$MOVED" "refused targets moved aside"
expect_eq "$(cat "$SB_CONFIG"/ghostty/config.pre-dotfiles.*)" omarchy "moved file keeps its content"
expect_eq "$(cat "$SB_CONFIG"/nvim.pre-dotfiles.*/init.lua)" starter "moved directory keeps its content"
expect_contains "$OUT" "moved ~/.config/nvim to ~/.config/nvim.pre-dotfiles." "plain message"
expect_eq "$(tr '\n' ' ' <"$C/mise.argv")" "bootstrap --yes " "no --force-dotfiles after moving"

new_case conflicts-dry-run
init_repo "$DOTFILES_DIR"
seed_conflicts
run_df DOTFILES_PROFILE=cachyos "$REFUSE" --dry-run
expect_rc 0
expect_eq "$(backups)" "" "a dry run moves nothing"
expect_contains "$OUT" "would move ~/.config/ghostty/config" "dry run reports"
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
expect_contains "$OUT" "moved ~/.config/nvim aside" "UI row"
expect_contains "$OUT" "kept as <path>.pre-dotfiles." "UI note"
expect_eq "$(calls)" "$STAGE_CALLS" "stages unchanged, no --force-dotfiles"
rm -rf "$SB_CONFIG"

if [ "$FAILS" -ne 0 ]; then
  echo "test_bin_dotfiles: $FAILS failure(s)" >&2
  exit 1
fi
echo "test_bin_dotfiles: all passed"
