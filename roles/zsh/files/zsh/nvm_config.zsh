#!/usr/bin/env zsh

# NVM (Node Version Manager) Configuration
# Direct loading - more reliable for MCP servers and subprocesses

export NVM_DIR="$HOME/.nvm"

# Load NVM directly if available
if [[ -s "$NVM_DIR/nvm.sh" ]]; then
  source "$NVM_DIR/nvm.sh"

  # Load bash completion
  [[ -s "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"

  # Setup .nvmrc auto-switching
  autoload -U add-zsh-hook

  load-nvmrc() {
    local nvmrc_path="$(nvm_find_nvmrc)"

    if [[ -n "$nvmrc_path" ]]; then
      local nvmrc_node_version=$(nvm version "$(cat "${nvmrc_path}")")

      if [[ "$nvmrc_node_version" = "N/A" ]]; then
        nvm install
      elif [[ "$nvmrc_node_version" != "$(nvm version)" ]]; then
        nvm use
      fi
    elif [[ -n "$(PWD=$OLDPWD nvm_find_nvmrc)" ]] && [[ "$(nvm version)" != "$(nvm version default)" ]]; then
      echo "Reverting to nvm default version"
      nvm use default
    fi
  }

  add-zsh-hook chpwd load-nvmrc
  # Check current directory on initial load
  load-nvmrc
fi