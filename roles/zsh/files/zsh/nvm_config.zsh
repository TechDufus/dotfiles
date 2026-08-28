#!/usr/bin/env zsh

# NVM is expensive. Load it on first use or when entering a directory with
# .nvmrc, not on every shell start. MCP servers do not source this file.

export NVM_DIR="$HOME/.nvm"

if [[ -s "$NVM_DIR/nvm.sh" ]]; then
  _dotfiles_load_nvm() {
    unset -f nvm node npm npx _dotfiles_load_nvm
    source "$NVM_DIR/nvm.sh"
    [[ -s "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"
  }

  nvm() {
    _dotfiles_load_nvm
    nvm "$@"
  }
  node() {
    _dotfiles_load_nvm
    node "$@"
  }
  npm() {
    _dotfiles_load_nvm
    npm "$@"
  }
  npx() {
    _dotfiles_load_nvm
    npx "$@"
  }

  autoload -U add-zsh-hook
  load-nvmrc() {
    if (( ! $+functions[nvm_find_nvmrc] )); then
      [[ -f .nvmrc ]] || return 0
      _dotfiles_load_nvm
    fi

    local nvmrc_path
    nvmrc_path="$(nvm_find_nvmrc)"
    if [[ -n "$nvmrc_path" ]]; then
      local nvmrc_node_version
      nvmrc_node_version="$(nvm version "$(cat "${nvmrc_path}")")"
      if [[ "$nvmrc_node_version" = "N/A" ]]; then
        echo "nvm: node $(cat "${nvmrc_path}") is not installed. Run: nvm install"
      elif [[ "$nvmrc_node_version" != "$(nvm version)" ]]; then
        nvm use
      fi
    elif [[ -n "$(PWD=$OLDPWD nvm_find_nvmrc)" ]] && [[ "$(nvm version)" != "$(nvm version default)" ]]; then
      echo "Reverting to nvm default version"
      nvm use default
    fi
  }
  add-zsh-hook chpwd load-nvmrc
fi
