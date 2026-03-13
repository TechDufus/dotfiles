#!/bin/bash
set -e

if [ -f "$HOME/.codex/config.toml.backup" ]; then
  __task "Restoring backup Codex config.toml"
  _cmd "mv $HOME/.codex/config.toml.backup $HOME/.codex/config.toml"
  _task_done
elif [ -L "$HOME/.codex/config.toml" ]; then
  __task "Removing Codex config.toml symlink"
  _cmd "rm -f $HOME/.codex/config.toml"
  _task_done
fi

if [ -f "$HOME/.codex/AGENTS.md.backup" ]; then
  __task "Restoring backup Codex AGENTS.md"
  _cmd "mv $HOME/.codex/AGENTS.md.backup $HOME/.codex/AGENTS.md"
  _task_done
elif [ -L "$HOME/.codex/AGENTS.md" ]; then
  __task "Removing Codex AGENTS.md symlink"
  _cmd "rm -f $HOME/.codex/AGENTS.md"
  _task_done
fi

if [ -L "$HOME/.codex/notify-peon.sh" ] || [ -f "$HOME/.codex/notify-peon.sh" ]; then
  __task "Removing legacy Codex peon notify hook"
  _cmd "rm -f $HOME/.codex/notify-peon.sh"
  _task_done
fi

if [ -d "$HOME/.openpeon" ]; then
  __task "Removing legacy Peon data directory"
  _cmd "rm -rf $HOME/.openpeon"
  _task_done
fi

if [ -d "$HOME/.local/share/codex-peon" ]; then
  __task "Removing legacy Codex peon install directory"
  _cmd "rm -rf $HOME/.local/share/codex-peon"
  _task_done
fi

case "$(uname -s)" in
  Darwin)
    if command -v brew >/dev/null 2>&1 && brew list --cask codex >/dev/null 2>&1; then
      __task "Removing Codex via Homebrew cask"
      _cmd "brew uninstall --cask codex"
      _task_done
    fi
    if command -v brew >/dev/null 2>&1 && brew list peonping/tap/peon-ping >/dev/null 2>&1; then
      __task "Removing legacy peon-ping formula"
      _cmd "brew uninstall peonping/tap/peon-ping"
      _task_done
    fi
    if command -v brew >/dev/null 2>&1 && brew tap | grep -qx 'peonping/tap'; then
      __task "Removing legacy peon-ping tap"
      _cmd "brew untap peonping/tap"
      _task_done
    fi
    ;;
  Linux)
    if [ -x "$HOME/.local/bin/codex" ]; then
      __task "Removing Codex binary from ~/.local/bin"
      _cmd "rm -f $HOME/.local/bin/codex"
      _task_done
    fi
    ;;
esac

echo -e "${GREEN} [✓]  ${WHITE}codex has been uninstalled${NC}"
