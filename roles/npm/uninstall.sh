#!/bin/bash
set -e

# Remove global npm packages
if command -v npm >/dev/null 2>&1; then
  # Get list of globally installed packages (excluding npm itself)
  GLOBAL_PACKAGES=$(npm list -g --depth=0 --parseable 2>/dev/null | grep -v '/npm$' | grep -v '^/' | sed 's/.*\///' || true)
  
  if [ -n "$GLOBAL_PACKAGES" ]; then
    echo -e "${YELLOW} [?]  ${WHITE}Remove globally installed npm packages?${NC}"
    echo "$GLOBAL_PACKAGES" | sed 's/^/      - /'
    read -p "$(echo -e ${YELLOW})Remove global packages? (y/N) ${NC}" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      __task "Removing global npm packages"
      echo "$GLOBAL_PACKAGES" | xargs -r npm uninstall -g
      _task_done
    fi
  fi
fi

# Remove npmrc configuration
if [ -f "$HOME/.npmrc" ]; then
  __task "Removing npm configuration"
  _cmd "rm -f $HOME/.npmrc"
  _task_done
fi

# Remove npm cache
if [ -d "$HOME/.npm" ]; then
  __task "Removing npm cache"
  _cmd "rm -rf $HOME/.npm"
  _task_done
fi

# Note: We don't remove npm/node itself as it might be managed by nvm or needed by the system
echo -e "${GREEN} [✓]  ${WHITE}npm packages and configuration have been cleaned up${NC}"
echo -e "${YELLOW} [!]  ${WHITE}Note: npm/node itself was not removed (may be managed by nvm)${NC}"