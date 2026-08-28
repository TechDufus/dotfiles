# Loaded for every zsh, including non-interactive Cursor/agent commands.
# Keep this file tiny, silent, and free of prompts or plugin managers.

if [[ -x /opt/homebrew/bin/brew ]]; then
  case ":${PATH}:" in
    *:/opt/homebrew/bin:*) ;;
    *) eval "$(/opt/homebrew/bin/brew shellenv)" ;;
  esac
fi

# Agent command strings are bash-flavored. Without this, unmatched globs
# abort the command instead of passing the literal pattern through.
if [[ -n "${CURSOR_AGENT:-}" ]]; then
  setopt NO_NOMATCH
fi
