#!/bin/bash
set -e

# Python role manages pip packages and configurations
# We don't want to uninstall Python itself as it's often a system dependency

# Remove pip packages installed in user directory
if [ -d "$HOME/.local/lib/python*/site-packages" ]; then
  echo -e "${YELLOW} [?]  ${WHITE}Remove pip packages installed in user directory?${NC}"
  read -p "$(echo -e ${YELLOW})Remove user pip packages? (y/N) ${NC}" -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    __task "Removing user pip packages"
    _cmd "rm -rf $HOME/.local/lib/python*/site-packages"
    _cmd "rm -rf $HOME/.local/bin/pip*"
    _task_done
  fi
fi

# Remove pip cache
if [ -d "$HOME/.cache/pip" ]; then
  __task "Removing pip cache"
  _cmd "rm -rf $HOME/.cache/pip"
  _task_done
fi

# Remove any Python virtual environments in common locations
if [ -d "$HOME/venvs" ] || [ -d "$HOME/.virtualenvs" ]; then
  echo -e "${YELLOW} [?]  ${WHITE}Remove Python virtual environments?${NC}"
  read -p "$(echo -e ${YELLOW})Remove virtual environments? (y/N) ${NC}" -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    __task "Removing Python virtual environments"
    [ -d "$HOME/venvs" ] && _cmd "rm -rf $HOME/venvs"
    [ -d "$HOME/.virtualenvs" ] && _cmd "rm -rf $HOME/.virtualenvs"
    _task_done
  fi
fi

echo -e "${GREEN} [✓]  ${WHITE}Python user packages and configurations have been cleaned up${NC}"
echo -e "${YELLOW} [!]  ${WHITE}Note: Python itself was not removed as it may be a system dependency${NC}"