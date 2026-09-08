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

# Load the host-local secret cache for every normal zsh invocation. The cache
# is plaintext and is only trusted when it and its containing directory are
# regular/current-user-owned paths with no group or other permissions. Ancestors
# must have trusted owners and no unsafe write access. Startup stays silent when
# the cache is missing, unreadable, unsafe, or fails to source.
_dotfiles_zsh_load_secret_cache() {
  local __secret_internal_cache_path="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/secrets.zsh"
  local __secret_internal_cache_dir="${__secret_internal_cache_path:h}"
  local __secret_internal_cache_ancestor
  local -A __secret_internal_cache_stat

  zmodload zsh/stat >/dev/null 2>&1 || return 0
  [[ "${__secret_internal_cache_path:a}" == "${__secret_internal_cache_path:A}" ]] || return 0

  __secret_internal_cache_ancestor="${__secret_internal_cache_dir:A}"
  while :; do
    [[ -d "$__secret_internal_cache_ancestor" && ! -L "$__secret_internal_cache_ancestor" ]] || return 0
    zstat -H __secret_internal_cache_stat -- "$__secret_internal_cache_ancestor" >/dev/null 2>&1 || return 0
    (( __secret_internal_cache_stat[uid] == EUID || __secret_internal_cache_stat[uid] == 0 )) || return 0
    (( (__secret_internal_cache_stat[mode] & 8#022) == 0 || (__secret_internal_cache_stat[mode] & 8#1000) != 0 )) || return 0
    [[ -e "$__secret_internal_cache_ancestor/.git" || -L "$__secret_internal_cache_ancestor/.git" ]] && return 0
    [[ "$__secret_internal_cache_ancestor" == / ]] && break
    __secret_internal_cache_ancestor="${__secret_internal_cache_ancestor:h}"
  done

  [[ -r "$__secret_internal_cache_path" && -f "$__secret_internal_cache_path" && ! -L "$__secret_internal_cache_path" ]] || return 0
  [[ -d "$__secret_internal_cache_dir" && ! -L "$__secret_internal_cache_dir" ]] || return 0
  zstat -H __secret_internal_cache_stat -- "$__secret_internal_cache_dir" >/dev/null 2>&1 || return 0
  (( __secret_internal_cache_stat[uid] == EUID && (__secret_internal_cache_stat[mode] & 8#077) == 0 )) || return 0
  zstat -H __secret_internal_cache_stat -- "$__secret_internal_cache_path" >/dev/null 2>&1 || return 0
  (( __secret_internal_cache_stat[uid] == EUID && (__secret_internal_cache_stat[mode] & 8#077) == 0 )) || return 0

  setopt localoptions noxtrace noverbose
  source "$__secret_internal_cache_path" >/dev/null 2>&1 || true
}
_dotfiles_zsh_load_secret_cache
unfunction _dotfiles_zsh_load_secret_cache

# Agent command strings are bash-flavored. Without this, unmatched globs
# abort the command instead of passing the literal pattern through.
if [[ -n "${CURSOR_AGENT:-}" || -n "${CLAUDECODE:-}" || -n "${CODEX_CI:-}" || -n "${CODEX_SANDBOX:-}" ]]; then
  setopt NO_NOMATCH
fi
