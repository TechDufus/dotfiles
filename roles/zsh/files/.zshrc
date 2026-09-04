is_ssh_session() {
  [[ -n "$SSH_CONNECTION" || -n "$SSH_CLIENT" || -n "$SSH_TTY" ]]
}

# True for interactive shells with a controlling terminal.
# During zsh startup, stdin can be the sourced file and Powerlevel10k instant
# prompt can temporarily redirect stdout/stderr, so fd checks are not reliable.
is_tty() {
  [[ -o interactive && -n "${TTY:-}" && -w "$TTY" ]]
}

is_cursor_agent() {
  [[ -n "${CURSOR_AGENT:-}" ]]
}

is_agent_shell() {
  [[ -n "${CURSOR_AGENT:-}" || -n "${CLAUDECODE:-}" || -n "${CODEX_CI:-}" || -n "${CODEX_SANDBOX:-}" ]]
}

is_herdr_session() {
  [[ -n "${HERDR_ENV:-}" || -n "${HERDR_WORKSPACE_ID:-}" ]]
}

if is_ssh_session; then
  # REASON: When sshing via ghostty, the remote terminal borks,
  # so we need to set TERM to xterm-256color
  export TERM=xterm-256color
fi

export EDITOR="nvim"
export VISUAL="nvim"

setopt EXTENDED_GLOB
setopt INTERACTIVE_COMMENTS

# Instant prompt and p10k both need a real TTY and break agent output.
if ! is_agent_shell && is_tty; then
  if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
  fi
fi

# Herdr (and tmux, if present) can preserve an exported FPATH from an older
# Homebrew zsh install. Keep fpath shell-local before plugins autoload.
typeset +x FPATH
typeset -gU fpath
_dotfiles_zsh_function_dirs=(
  $HOME/.local/share/zsh/site-functions(N-/)
  $HOME/.local/share/zsh/$ZSH_VERSION/functions(N-/)
  $HOME/.local/share/zsh/functions(N-/)
  $HOME/.local/share/zsh/functions/*(N-/)
  $HOME/.local/share/zsh/functions/*/*(N-/)
  /usr/local/share/zsh/site-functions(N-/)
  /opt/homebrew/share/zsh/site-functions(N-/)
  /usr/share/zsh/site-functions(N-/)
  /usr/share/zsh/vendor-functions(N-/)
  /usr/share/zsh/vendor-completions(N-/)
  /opt/homebrew/opt/zsh/share/zsh/functions(N-/)
  /usr/local/opt/zsh/share/zsh/functions(N-/)
  /usr/share/zsh/$ZSH_VERSION/functions(N-/)
  /usr/share/zsh/functions(N-/)
  /usr/share/zsh/functions/*(N-/)
  /usr/share/zsh/functions/*/*(N-/)
  /usr/local/share/zsh/functions(N-/)
  /usr/local/share/zsh/functions/*(N-/)
  /usr/local/share/zsh/functions/*/*(N-/)
)
if (( ${#_dotfiles_zsh_function_dirs} )); then
  fpath=($_dotfiles_zsh_function_dirs $fpath)
fi
unset _dotfiles_zsh_function_dirs

ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

if ! is_agent_shell; then
  if [[ ! -d "$ZINIT_HOME" ]]; then
    mkdir -p "$(dirname "$ZINIT_HOME")"
    git clone --depth 1 https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
  fi
  source "${ZINIT_HOME}/zinit.zsh"

  # Powerlevel10k starts gitstatus, which requires a real terminal.
  if is_tty; then
    zinit ice depth=1; zinit light romkatv/powerlevel10k
  fi

  zinit light zsh-users/zsh-completions

  zinit snippet OMZL::async_prompt.zsh
  zinit snippet OMZL::git.zsh
  zinit snippet OMZP::git
  zinit snippet OMZP::sudo
  zinit snippet OMZP::ssh
  zinit snippet OMZP::aliases
  if grep -qE '^ID(_LIKE)?=.*(arch|cachyos)' /etc/os-release 2>/dev/null; then
    zinit snippet OMZP::archlinux
  fi
  # Powerlevel10k already renders AWS. Keep Oh My Zsh's AWS plugin from
  # installing a fallback RPROMPT that leaks as literal $(aws_prompt_info)
  # when prompt tooling is skipped for non-TTY startup paths.
  SHOW_AWS_PROMPT=false
  zinit snippet OMZP::aws
  zinit snippet OMZP::command-not-found

  _zinit_completions="${ZINIT_HOME:h}/completions"
  if [[ -d "$_zinit_completions" ]]; then
    command find "$_zinit_completions" -type l ! -exec test -e {} \; -delete 2>/dev/null
  fi
  unset _zinit_completions
fi

autoload -U +X bashcompinit && bashcompinit
autoload -Uz compinit
_zcompdump="${ZDOTDIR:-$HOME}/.zcompdump"
if [[ ! -e "$_zcompdump" || -n $_zcompdump(#qN.mh+24) ]]; then
  compinit -d "$_zcompdump"
else
  compinit -C -d "$_zcompdump"
fi
unset _zcompdump

if ! is_agent_shell; then
  zinit cdreplay -q

  if is_tty; then
    # fzf keybindings before fzf-tab so Tab stays with fzf-tab.
    if command -v fzf >/dev/null 2>&1; then
      eval "$(fzf --zsh)"
    fi

    zinit light Aloxaf/fzf-tab
    zinit light zsh-users/zsh-autosuggestions
    zinit light zsh-users/zsh-syntax-highlighting

    [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

    bindkey -e
    bindkey '^p' history-search-backward
    bindkey '^n' history-search-forward
    bindkey '^[w' kill-region
    bindkey '^[[3~' delete-char
    bindkey '^[OH' beginning-of-line
    bindkey '^[OF' end-of-line
  fi
fi

if is_agent_shell; then
  unset HISTFILE
  SAVEHIST=0
else
  HISTSIZE=50000
  HISTFILE=~/.zsh_history
  SAVEHIST=$HISTSIZE
  HISTDUP=erase
  setopt appendhistory
  setopt sharehistory
  setopt EXTENDED_HISTORY
  setopt HIST_EXPIRE_DUPS_FIRST
  setopt hist_ignore_space
  setopt hist_ignore_all_dups
  setopt hist_save_no_dups
  setopt hist_ignore_dups
  setopt hist_find_no_dups
  setopt HIST_REDUCE_BLANKS
fi

zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'

for file in $HOME/.config/zsh/*.zsh(N); do
  case "${file:t}" in
    paths_functions.zsh|paths_vars.zsh) continue ;;
  esac
  source "$file"
done

# Load secrets for normal interactive terminals without blocking shell startup
# when 1Password is unavailable or locked. Agent shells clear inherited state.
if is_agent_shell; then
  secret --quiet --clear >/dev/null 2>&1 || true
elif is_tty; then
  secret --quiet >/dev/null 2>&1 || true
fi


if [[ -f ~/.raftrc ]]; then source ~/.raftrc; fi

unalias zi 2>/dev/null || true
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

# Keep fpath shell-local so Herdr/tmux panes never inherit stale zsh function paths.
typeset +x FPATH
