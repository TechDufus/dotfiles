#!/usr/bin/env zsh

# Defer loading 1Password CLI plugins until after shell initialization
# This prevents the popup from appearing during shell startup
_load_op_plugins() {
  if [[ -f "$HOME/.config/op/plugins.sh" ]]; then
    source "$HOME/.config/op/plugins.sh"
  fi
}

# Use zsh's precmd hook to load after shell is fully initialized
# This runs once before the first prompt is displayed
precmd_functions+=(_load_op_plugins)

# Remove the function from precmd after first run to avoid repeated loading
_load_op_plugins_once() {
  _load_op_plugins
  # Remove this function from precmd_functions
  precmd_functions=(${precmd_functions[@]/_load_op_plugins_once})
}

# Replace the function in the array
precmd_functions=(${precmd_functions[@]/_load_op_plugins})
precmd_functions+=(_load_op_plugins_once)
