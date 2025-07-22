#!/usr/bin/env zsh

# Source 1Password CLI plugins if available
if [[ -f "$HOME/.config/op/plugins.sh" ]]; then
  source "$HOME/.config/op/plugins.sh"
fi
