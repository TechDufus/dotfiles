#!/usr/bin/env bash
# Install the 1Password app and CLI when missing. Deliberately not in [bootstrap.packages]:
# one failed package install stops the whole mise run, and nothing else in dotfiles needs
# 1Password to finish (modules/secrets skips until it is signed in). This step only warns.
set -uo pipefail

if [ "$(uname -s)" = Darwin ]; then
  # Leave a hand-installed app alone: Homebrew refuses to replace an app it did not install.
  [ -d /Applications/1Password.app ] || brew install --cask 1password ||
    echo "1password: app install failed, skipped"
  command -v op >/dev/null 2>&1 || brew install --cask 1password-cli ||
    echo "1password: CLI install failed, skipped"
  exit 0
fi

missing=()
for pkg in 1password 1password-cli; do
  pacman -Q "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
done
[ "${#missing[@]}" -eq 0 ] && exit 0

if pacman -Si "${missing[@]}" >/dev/null 2>&1; then
  # A configured repo ships them (Omarchy's does).
  sudo pacman -S --needed --noconfirm "${missing[@]}" || echo "1password: pacman install failed, skipped"
elif command -v paru >/dev/null 2>&1; then
  paru -S --needed --noconfirm --skipreview "${missing[@]}" || echo "1password: AUR install failed, skipped"
elif command -v yay >/dev/null 2>&1; then
  yay -S --needed --noconfirm "${missing[@]}" || echo "1password: AUR install failed, skipped"
else
  echo "1password: not in any repo and no AUR helper (paru or yay) found, skipped"
fi
exit 0
