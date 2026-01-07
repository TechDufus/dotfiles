#!/usr/bin/env zsh

# NVM (Node Version Manager) Configuration
# Uses lazy loading for faster shell startup (~200-400ms improvement)

export NVM_DIR="$HOME/.nvm"

# Lazy load nvm - only loads when nvm/node/npm/npx is first called
_nvm_lazy_load() {
  unset -f nvm node npm npx yarn pnpm 2>/dev/null
  
  if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    source "$NVM_DIR/nvm.sh"
    
    # Load bash completion
    [[ -s "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"
    
    # Setup .nvmrc auto-switching after nvm is loaded
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
    # Check current directory on first load
    load-nvmrc
  fi
}

# Create lazy wrapper functions
nvm() {
  _nvm_lazy_load
  nvm "$@"
}

node() {
  _nvm_lazy_load
  node "$@"
}

npm() {
  _nvm_lazy_load
  npm "$@"
}

npx() {
  _nvm_lazy_load
  npx "$@"
}

yarn() {
  _nvm_lazy_load
  yarn "$@"
}

pnpm() {
  _nvm_lazy_load
  pnpm "$@"
}