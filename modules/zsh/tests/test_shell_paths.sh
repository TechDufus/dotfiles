#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
bash_bin="$(command -v "${BASH_BIN:-/bin/bash}")"
zsh_bin="$(command -v "${ZSH_BIN:-zsh}")"
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-shell-paths.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT

home_dir="$tmp_dir/home with spaces"
mkdir -p "$home_dir" "$tmp_dir/work" "$tmp_dir/config" "$tmp_dir/cache" \
  "$tmp_dir/state" "$tmp_dir/runtime" "$tmp_dir/data" "$tmp_dir/system-config"

# One shared behavioral contract, sourced with each shell's real implementation.
cat > "$tmp_dir/check-paths" <<'CHECK'
set -eu
source "$HELPERS"

assert_equal() {
  if [[ "$1" != "$2" ]]; then
    printf '%s\nexpected: %s\nactual:   %s\n' "$3" "$2" "$1" >&2
    exit 1
  fi
}

first="$CASE_ROOT/first"
other="$CASE_ROOT/other"
target="$CASE_ROOT/shim [candidate]"
missing="$CASE_ROOT/missing"
PATH="$first:$target:$other::$target:$first:"
addToPathFront "$target"
assert_equal "$PATH" "$target:$first:$other::$first:" \
  'prepend must promote an existing directory, removing only its duplicates'
addToPathFront "$target"
assert_equal "$PATH" "$target:$first:$other::$first:" \
  'repeated prepend must preserve ordering and empty PATH entries'

PATH="$first:$other"
addToPathFront "$target"
assert_equal "$PATH" "$target:$first:$other" \
  'prepend must add a new directory with spaces and pattern characters'
original="$PATH"
addToPathFront "$missing"
addToPathFront ''
addToPathFront
addToPath "$missing"
addToPath ''
addToPath
assert_equal "$PATH" "$original" 'missing and empty directories must not alter PATH'

PATH="$target-extra:$first"
addToPath "$target"
assert_equal "$PATH" "$target-extra:$first:$target" \
  'append must compare complete entries rather than substrings'
addToPath "$target"
assert_equal "$PATH" "$target-extra:$first:$target" 'append must not duplicate entries'

# Exercise actual paths_vars files with both new and inherited tool paths.
# These files are only inspected via command lookup; no fixture binary is run.
for data_mode in explicit fallback; do
  if [[ "$data_mode" == explicit ]]; then
    export XDG_DATA_HOME="$CASE_ROOT/data"
    shims="$XDG_DATA_HOME/mise/shims"
  else
    unset XDG_DATA_HOME
    shims="$HOME/.local/share/mise/shims"
  fi
  wrappers="$HOME/.local/bin"
  old="$CASE_ROOT/old-homebrew/bin"
  for inherited in fresh inherited; do
    if [[ "$inherited" == fresh ]]; then
      PATH="$old:$other"
    else
      PATH="$old:$shims:$other:$wrappers:$shims"
    fi
    source "$PATH_VARS"
    assert_equal "$(command -v dotfiles-path-runtime)" "$shims/dotfiles-path-runtime" \
      'mise tools must resolve ahead of old Homebrew runtimes'
    assert_equal "$(command -v dotfiles-path-wrapper)" "$wrappers/dotfiles-path-wrapper" \
      'intentional local wrappers must resolve ahead of mise shims'
    assert_equal "$(command -v dotfiles-path-unrelated)" "$other/dotfiles-path-unrelated" \
      'unrelated executable entries must survive startup ordering'
    case ":$PATH:" in
      *":$wrappers:$shims:$old:$other:"*) ;;
      *) printf 'unexpected shell path ordering: %s\n' "$PATH" >&2; exit 1 ;;
    esac
    original="$PATH"
    source "$PATH_VARS"
    assert_equal "$PATH" "$original" 'sourcing path configuration twice must be idempotent'
    # Shadowing is intentional, not a reason to delete either executable.
    [[ -f "$old/dotfiles-path-runtime" && -f "$shims/dotfiles-path-wrapper" ]]
  done
done

if [[ "$SHELL_KIND" == bash ]]; then
  optional_tools='magnitude minimax lmstudio'
else
  optional_tools='magnitude grok'
fi
# Use the shell's whitespace-splitting mechanism explicitly (Zsh does not split
# scalar parameters by default).
for tool in magnitude minimax lmstudio grok; do
  case " $optional_tools " in *" $tool "*) ;; *) continue ;; esac
  if [[ "$OPTIONAL_MODE" == present ]]; then
    assert_equal "$(command -v "dotfiles-path-$tool")" "$HOME/.$tool/bin/dotfiles-path-$tool" \
      'existing optional CLI directories must remain discoverable'
  else
    if command -v "dotfiles-path-$tool" >/dev/null 2>&1; then
      printf 'absent optional tool unexpectedly resolved: %s\n' "$tool" >&2
      exit 1
    fi
    case ":$PATH:" in
      *":$HOME/.$tool/bin:"*) printf 'missing optional directory added to PATH\n' >&2; exit 1 ;;
    esac
  fi
done

if [[ "$SHELL_KIND" == zsh ]]; then
  # Load the real completion setup without plugins, user startup, or applications.
  # Interactive configuration need not support nounset.
  set +u
  # Do not allow an unrelated host installation to run during config sourcing.
  zoxide() { :; }
  PATH="$PATH:/usr/bin:/bin"
  source "$ZSHRC"
  if [[ "$OPTIONAL_MODE" == present ]]; then
    assert_equal "${_comps[dotfiles-grok]:-}" _dotfiles_grok \
      'Grok completions must be registered by the existing compinit'
  elif (( ${+_comps[dotfiles-grok]} )); then
    printf 'missing Grok completion directory unexpectedly registered a command\n' >&2
    exit 1
  fi
fi
CHECK

mkdir -p "$tmp_dir/first" "$tmp_dir/other" "$tmp_dir/shim [candidate]" \
  "$tmp_dir/shim [candidate]-extra" "$tmp_dir/old-homebrew/bin" \
  "$home_dir/.local/bin" "$home_dir/.local/share/mise/shims" \
  "$tmp_dir/data/mise/shims"
for directory in "$tmp_dir/old-homebrew/bin" "$tmp_dir/data/mise/shims" \
  "$home_dir/.local/share/mise/shims"; do
  printf '#!/bin/sh\nexit 99\n' > "$directory/dotfiles-path-runtime"
  chmod +x "$directory/dotfiles-path-runtime"
done
for directory in "$tmp_dir/data/mise/shims" "$home_dir/.local/share/mise/shims" \
  "$home_dir/.local/bin"; do
  printf '#!/bin/sh\nexit 99\n' > "$directory/dotfiles-path-wrapper"
  chmod +x "$directory/dotfiles-path-wrapper"
done
printf '#!/bin/sh\nexit 99\n' > "$tmp_dir/other/dotfiles-path-unrelated"
chmod +x "$tmp_dir/other/dotfiles-path-unrelated"

# The POSIX profile must preserve optional login paths without interactive Bash.
cat > "$tmp_dir/check-profile" <<'PROFILE'
set -eu
PATH="$HOME/.local/bin:$XDG_DATA_HOME/mise/shims:$CASE_ROOT/other"
original="$PATH"
. "$PROFILE"
for tool in docker lmstudio; do
  if [ "$OPTIONAL_MODE" = present ]; then
    actual="$(command -v "dotfiles-path-$tool")"
    [ "$actual" = "$HOME/.$tool/bin/dotfiles-path-$tool" ]
  else
    [ "$PATH" = "$original" ]
  fi
done
[ "$(command -v dotfiles-path-runtime)" = "$XDG_DATA_HOME/mise/shims/dotfiles-path-runtime" ]
[ "$(command -v dotfiles-path-wrapper)" = "$HOME/.local/bin/dotfiles-path-wrapper" ]
original="$PATH"
. "$PROFILE"
[ "$PATH" = "$original" ]
PROFILE

isolated_env() {
  env -i HOME="$home_dir" ZDOTDIR="$tmp_dir/zsh-$optional" \
    XDG_CONFIG_HOME="$tmp_dir/config" XDG_CACHE_HOME="$tmp_dir/cache" \
    XDG_DATA_HOME="$tmp_dir/data" XDG_STATE_HOME="$tmp_dir/state" \
    XDG_RUNTIME_DIR="$tmp_dir/runtime" \
    MISE_CONFIG_DIR="$tmp_dir/config/mise" MISE_CACHE_DIR="$tmp_dir/cache/mise" \
    MISE_DATA_DIR="$tmp_dir/data/mise" MISE_STATE_DIR="$tmp_dir/state/mise" \
    MISE_SYSTEM_CONFIG_DIR="$tmp_dir/system-config" \
    MISE_GLOBAL_CONFIG_FILE="$tmp_dir/config/mise/config.toml" \
    CURSOR_AGENT=1 SSH_CONNECTION= SSH_CLIENT= SSH_TTY= LS_COLORS= \
    PATH=/usr/bin:/bin CASE_ROOT="$tmp_dir" OPTIONAL_MODE="$optional" \
    PROFILE="$repo_root/modules/bash/profile" ZSHRC="$repo_root/modules/zsh/zshrc" \
    "$@"
}

for optional in missing present; do
  mkdir -p "$tmp_dir/zsh-$optional"
  if [[ "$optional" == present ]]; then
    for tool in magnitude minimax lmstudio grok docker; do
      directory="$home_dir/.$tool/bin"
      mkdir -p "$directory"
      for executable in "dotfiles-path-$tool" dotfiles-path-runtime dotfiles-path-wrapper; do
        printf '#!/bin/sh\nexit 99\n' > "$directory/$executable"
        chmod +x "$directory/$executable"
      done
    done
    mkdir -p "$home_dir/.grok/completions/zsh"
    printf '#compdef dotfiles-grok\n_dotfiles_grok() { :; }\n' \
      > "$home_dir/.grok/completions/zsh/_dotfiles_grok"
  fi
  for shell in bash zsh; do
    if [[ "$shell" == bash ]]; then
      shell_bin="$bash_bin"
      shell_args=(--noprofile --norc)
      extension=sh
    else
      shell_bin="$zsh_bin"
      shell_args=(-df)
      extension=zsh
    fi
    (
      cd "$tmp_dir/work"
      isolated_env SHELL_KIND="$shell" \
        HELPERS="$repo_root/modules/$shell/$shell/paths_functions.$extension" \
        PATH_VARS="$repo_root/modules/$shell/$shell/paths_vars.$extension" \
        "$shell_bin" "${shell_args[@]}" "$tmp_dir/check-paths"
    )
  done
  (
    cd "$tmp_dir/work"
    isolated_env /bin/sh "$tmp_dir/check-profile"
  )
done

printf '%s\n' 'shell PATH behavioral tests passed (Bash, Zsh, and POSIX profile)'
