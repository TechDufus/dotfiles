#!/bin/bash
set -e

# Remove NVM
if [ -d "$HOME/.nvm" ]; then
  # Unload nvm from current shell if loaded
  if command -v nvm >/dev/null 2>&1; then
    __task "Unloading nvm from current shell"
    nvm unload || true
    _task_done
  fi
  
  __task "Removing nvm installation"
  _cmd "rm -rf $HOME/.nvm"
  _task_done
fi

# Remove nvm lines from shell configs
__task "Removing nvm from shell configurations"
for file in ~/.bashrc ~/.zshrc ~/.profile; do
  if [ -f "$file" ]; then
    # Remove nvm export and source lines
    sed -i.bak '/export NVM_DIR/d' "$file" 2>/dev/null || sed -i '' '/export NVM_DIR/d' "$file"
    sed -i.bak '/\. "\$NVM_DIR\/nvm\.sh"/d' "$file" 2>/dev/null || sed -i '' '/\. "\$NVM_DIR\/nvm\.sh"/d' "$file"
    sed -i.bak '/\. "\$NVM_DIR\/bash_completion"/d' "$file" 2>/dev/null || sed -i '' '/\. "\$NVM_DIR\/bash_completion"/d' "$file"
    rm -f "$file.bak"
  fi
done
_task_done

# Check for globally installed node versions
if [ -d "$HOME/.nvm/versions" ]; then
  echo -e "${YELLOW} [!]  ${WHITE}Note: Any Node.js versions installed via nvm have been removed${NC}"
  echo -e "${YELLOW}      ${WHITE}You may want to install Node.js via your system package manager${NC}"
fi

echo -e "${GREEN} [✓]  ${WHITE}nvm has been uninstalled${NC}"