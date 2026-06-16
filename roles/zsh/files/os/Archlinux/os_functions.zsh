#!/usr/bin/env zsh

# Arch Linux specific package management helpers.
# Prefer the installed AUR helper when present so one command updates repo and AUR packages.
if command -v paru >/dev/null 2>&1; then
  alias update='paru -Syu --noconfirm'
elif command -v yay >/dev/null 2>&1; then
  alias update='yay -Syu --noconfirm'
else
  alias update='sudo pacman -Syu --noconfirm'
fi

alias pacorphans='pacman -Qtdq'
alias pacclean='sudo pacman -Sc --noconfirm'

clean-system() {
  echo "Removing orphaned packages..."
  local orphans
  orphans=(${(f)"$(pacman -Qtdq 2>/dev/null)"})
  if (( ${#orphans} )); then
    sudo pacman -Rns --noconfirm -- "${orphans[@]}"
  else
    echo "No orphaned packages found."
  fi

  echo "Cleaning pacman cache..."
  sudo pacman -Sc --noconfirm

  echo "Vacuuming journal logs older than 3 days..."
  sudo journalctl --vacuum-time=3d

  echo "System cleanup complete!"
}
