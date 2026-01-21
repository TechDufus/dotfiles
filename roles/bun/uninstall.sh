#!/bin/bash
set -e

# Remove bun installation directory
if [ -d "$HOME/.bun" ]; then
  __task "Removing bun installation"
  _cmd "rm -rf $HOME/.bun"
  _task_done
fi

# Remove bun cache directory if exists
if [ -d "$HOME/.cache/bun" ]; then
  __task "Removing bun cache"
  _cmd "rm -rf $HOME/.cache/bun"
  _task_done
fi

echo -e "${GREEN} [✓]  ${WHITE}bun has been uninstalled${NC}"
