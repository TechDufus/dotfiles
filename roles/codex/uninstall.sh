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

managed_agents_dir="$(cd "$(dirname "$0")/files/agents" 2>/dev/null && pwd)"

if [ -n "$managed_agents_dir" ] && [ -d "$HOME/.codex/agents" ]; then
  for managed_source in "$managed_agents_dir"/*.toml; do
    [ -e "$managed_source" ] || continue

    agent_path="$HOME/.codex/agents/$(basename "$managed_source")"
    [ -e "$agent_path" ] || [ -L "$agent_path" ] || continue

    __task "Removing Codex custom agent $(basename "$agent_path")"
    _cmd "rm -f $agent_path"
    _task_done
  done

  if [ -f "$HOME/.codex/agents/.managed-by-dotfiles.json" ]; then
    __task "Removing Codex custom agent manifest"
    _cmd "rm -f $HOME/.codex/agents/.managed-by-dotfiles.json"
    _task_done
  fi
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
