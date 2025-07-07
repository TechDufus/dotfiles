#!/usr/bin/env zsh

# NVM (Node Version Manager) Configuration
# This file sets up nvm for use in zsh

# Set NVM directory
export NVM_DIR="$HOME/.nvm"

# Load nvm if it exists
if [[ -s "$NVM_DIR/nvm.sh" ]]; then
  # Load nvm
  source "$NVM_DIR/nvm.sh"
  
  # Load nvm bash_completion
  if [[ -s "$NVM_DIR/bash_completion" ]]; then
    source "$NVM_DIR/bash_completion"
  fi
fi

# Auto-use .nvmrc if it exists in a directory
# This function runs on directory change
autoload -U add-zsh-hook
load-nvmrc() {
  local nvmrc_path="$(nvm_find_nvmrc)"
  
  if [ -n "$nvmrc_path" ]; then
    local nvmrc_node_version=$(nvm version "$(cat "${nvmrc_path}")")
    
    if [ "$nvmrc_node_version" = "N/A" ]; then
      nvm install
    elif [ "$nvmrc_node_version" != "$(nvm version)" ]; then
      nvm use
    fi
  elif [ -n "$(PWD=$OLDPWD nvm_find_nvmrc)" ] && [ "$(nvm version)" != "$(nvm version default)" ]; then
    echo "Reverting to nvm default version"
    nvm use default
  fi
}

# Only add the hook if nvm is loaded
if command -v nvm &>/dev/null; then
  add-zsh-hook chpwd load-nvmrc
  # Load on initial shell startup
  load-nvmrc
fi

# Lazy load nvm to speed up shell startup (optional optimization)
# Uncomment the following section if you want faster shell startup
# and comment out the direct sourcing above

# lazy_load_nvm() {
#   unset -f nvm node npm npx
#   export NVM_DIR="$HOME/.nvm"
#   [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
#   [ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"
# }
# 
# nvm() {
#   lazy_load_nvm
#   nvm "$@"
# }
# 
# node() {
#   lazy_load_nvm
#   node "$@"
# }
# 
# npm() {
#   lazy_load_nvm
#   npm "$@"
# }
# 
# npx() {
#   lazy_load_nvm
#   npx "$@"
# }