#!/usr/bin/env bash
# Sync SSH keys, git signing data and fonts from 1Password, then regenerate the git identity.
# 1Password stays the source of truth: files are rewritten only when their content differs.
# Never prints secret values; always exits 0.
set -uo pipefail

ACCOUNT=my.1password.com
GIT_DIR=$HOME/.config/git
SSH_DIR=$HOME/.ssh
IDENTITY=$GIT_DIR/identity.gitconfig
SIGNERS=$GIT_DIR/allowed_signers
FALLBACK_EMAIL=techdufus@users.noreply.github.com

warn() { echo "secrets: $*" >&2; }

# macOS has no GNU timeout; perl's alarm survives exec and bounds op there.
# stdin is detached so op never waits on a terminal prompt.
run_timeout() {
  local secs=$1
  shift
  if command -v timeout >/dev/null 2>&1; then
    timeout "$secs" "$@" </dev/null
  else
    perl -e 'alarm shift; exec @ARGV' "$secs" "$@" </dev/null
  fi
}

op_read() { run_timeout 30 op read --account "$ACCOUNT" "$@"; }

# write_if_changed DEST MODE: content on stdin; temp file + atomic mv, only when it differs.
write_if_changed() {
  local dest=$1 mode=$2 tmp
  tmp=$(mktemp "$dest.XXXXXX") || return 1
  if ! cat >"$tmp" || ! chmod "$mode" "$tmp"; then
    rm -f "$tmp"
    return 1
  fi
  if [ -f "$dest" ] && [ ! -L "$dest" ] && cmp -s "$tmp" "$dest"; then
    rm -f "$tmp"
    chmod "$mode" "$dest" 2>/dev/null
    return 0
  fi
  mv -f "$tmp" "$dest"
}

mkdir -p "$GIT_DIR" || { warn "cannot create $GIT_DIR, skipped"; exit 0; }

op_ok=0
if ! command -v op >/dev/null 2>&1; then
  warn "1Password CLI not installed; skipping"
elif ! run_timeout 20 op vault list --account "$ACCOUNT" >/dev/null 2>&1; then
  warn "1Password locked; skipping"
else
  op_ok=1
fi

email=""
if [ "$op_ok" = 1 ]; then
  install -d -m 700 "$SSH_DIR"

  # Key pair: write only when both reads succeed.
  if priv=$(op_read 'op://Personal/TechDufus SSH/private_key?ssh-format=openssh') &&
    pub=$(op_read 'op://Personal/TechDufus SSH/public_key') &&
    [ -n "$priv" ] && [ -n "$pub" ]; then
    printf '%s\n' "$priv" | write_if_changed "$SSH_DIR/id_ed25519" 0600 || warn "could not write id_ed25519, skipped"
    printf '%s' "$pub" | write_if_changed "$SSH_DIR/id_ed25519.pub" 0644 || warn "could not write id_ed25519.pub, skipped"
  else
    warn "SSH key read failed, skipped"
  fi
  unset priv pub

  if signers=$(op_read 'op://Personal/TechDufus SSH/allowed_signers') && [ -n "$signers" ]; then
    printf '%s\n' "$signers" | write_if_changed "$SIGNERS" 0600 || warn "could not write allowed_signers, skipped"
  else
    warn "allowed_signers read failed, skipped"
  fi
  unset signers

  email=$(op_read 'op://Personal/GitHub/email' 2>/dev/null) || email=""

  # BerkeleyMono Nerd Font: fetched only when a file is missing.
  case $(uname -s) in
    Darwin) font_dir=$HOME/Library/Fonts ;;
    *) font_dir=$HOME/.local/share/fonts ;;
  esac
  fonts_written=0
  for field in BerkeleyMonoNerdFont-Regular BerkeleyMonoNerdFont-Italic BerkeleyMonoNerdFont-Bold BerkeleyMonoNerdFont-BoldItalic; do
    [ -f "$font_dir/$field.otf" ] && continue
    mkdir -p "$font_dir"
    if op_read --out-file "$font_dir/$field.otf" --file-mode 0644 "op://Private/BerkeleyMono Fonts/$field" >/dev/null 2>&1; then
      fonts_written=1
    else
      rm -f "$font_dir/$field.otf"
      warn "could not fetch $field, skipped"
    fi
  done
  if [ "$fonts_written" = 1 ] && [ "$(uname -s)" != Darwin ] && command -v fc-cache >/dev/null 2>&1; then
    fc-cache -f "$font_dir"
  fi
fi

# Without 1Password, keep the email already recorded in the identity file.
if [ -z "$email" ] && [ -f "$IDENTITY" ]; then
  email=$(git config -f "$IDENTITY" user.email 2>/dev/null) || email=""
fi

{
  echo "[user]"
  [ -n "$email" ] && printf '\temail = %s\n' "$email"
  if [ -f "$SSH_DIR/id_ed25519.pub" ]; then
    printf '\tsigningkey = ~/.ssh/id_ed25519.pub\n'
    printf '[gpg]\n\tformat = ssh\n[commit]\n\tgpgsign = true\n[tag]\n\tgpgsign = true\n'
  fi
  if [ -f "$SIGNERS" ]; then
    printf '[gpg "ssh"]\n\tallowedSignersFile = ~/.config/git/allowed_signers\n'
  fi
} | write_if_changed "$IDENTITY" 0644 || warn "could not write identity.gitconfig, skipped"

if command -v jj >/dev/null 2>&1; then
  if [ -z "$(jj config get user.email 2>/dev/null)" ]; then
    jj config set --user user.email "${email:-$FALLBACK_EMAIL}" || warn "could not set jj user.email, skipped"
  fi
fi

exit 0
