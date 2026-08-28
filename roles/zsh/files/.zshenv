# Loaded for every zsh, including non-interactive Cursor/agent commands.
# Keep this file tiny, silent, and free of prompts or plugin managers.

if [[ -x /opt/homebrew/bin/brew ]]; then
  case ":${PATH}:" in
    *:/opt/homebrew/bin:*) ;;
    *) eval "$(/opt/homebrew/bin/brew shellenv)" ;;
  esac
fi

# PATH lives in paths_vars.zsh. Interactive .zshrc skips those files so the
# list is not duplicated. Agent `zsh -c` never reaches .zshrc.
_dotfiles_zsh_config="${HOME}/.config/zsh"
if [[ -r "${_dotfiles_zsh_config}/paths_functions.zsh" && -r "${_dotfiles_zsh_config}/paths_vars.zsh" ]]; then
  source "${_dotfiles_zsh_config}/paths_functions.zsh"
  source "${_dotfiles_zsh_config}/paths_vars.zsh"
fi
unset _dotfiles_zsh_config

# Agent command strings are bash-flavored. Without this, unmatched globs
# abort the command instead of passing the literal pattern through.
if [[ -n "${CURSOR_AGENT:-}" || -n "${CLAUDECODE:-}" || -n "${CODEX_CI:-}" || -n "${CODEX_SANDBOX:-}" ]]; then
  setopt NO_NOMATCH
fi
