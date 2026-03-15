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

case "$(uname -s)" in
  Darwin)
    if command -v brew >/dev/null 2>&1 && brew list --cask codex >/dev/null 2>&1; then
      __task "Removing Codex via Homebrew cask"
      _cmd "brew uninstall --cask codex"
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
