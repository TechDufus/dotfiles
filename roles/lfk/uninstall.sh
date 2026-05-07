#!/bin/bash
set -e

case "$(uname -s)" in
  Darwin)
    if command -v brew >/dev/null 2>&1 && brew list lfk >/dev/null 2>&1; then
      __task "Removing lfk via Homebrew"
      _cmd "brew uninstall lfk"
      _task_done
    fi
    ;;

  Linux)
    if [ -f "/usr/local/bin/lfk" ]; then
      __task "Removing system lfk binary"
      _cmd "sudo rm -f /usr/local/bin/lfk"
      _task_done
    fi

    if [ -f "$HOME/.local/bin/lfk" ]; then
      __task "Removing user-local lfk binary"
      _cmd "rm -f $HOME/.local/bin/lfk"
      _task_done
    fi
    ;;
esac

if [ -d "$HOME/.config/lfk" ]; then
  __task "Removing lfk configuration files"
  _cmd "rm -rf $HOME/.config/lfk"
  _task_done
fi
