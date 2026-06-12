is_ssh_session() {
  [[ -n "$SSH_CONNECTION" || -n "$SSH_CLIENT" || -n "$SSH_TTY" ]]
}

if is_ssh_session; then
  # REASON: When sshing via ghostty, the remote terminal borks,
  # so we need to set TERM to xterm-256color
  export TERM=xterm-256color
fi

# Set default editor for OpenCode and other tools
export EDITOR="nvim"
export VISUAL="nvim"

# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

if [[ -f "/opt/homebrew/bin/brew" ]] then
  # If you're using macOS, you'll want this enabled
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# tmux can preserve an exported FPATH from an older Homebrew zsh install.
# Repair fpath before zinit/plugins autoload standard functions.
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


# Set the directory we want to store zinit and plugins
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

# Download Zinit, if it's not there yet
if [ ! -d "$ZINIT_HOME" ]; then
  mkdir -p "$(dirname $ZINIT_HOME)"
  git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

# Source/Load zinit
source "${ZINIT_HOME}/zinit.zsh"

# Add in Powerlevel10k
zinit ice depth=1; zinit light romkatv/powerlevel10k

# Add in zsh plugins
zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light Aloxaf/fzf-tab
# zinit ice depth=1; zinit light jeffreytse/zsh-vi-mode
# zsh-fzf-history-search
zinit ice lucid wait'0'; zinit light joshskidmore/zsh-fzf-history-search

# Add in snippets
# Needed for loading next git.zsh without [_defer_async_git_register:4: command not found: _omz_register_handler errors]
zinit snippet OMZL::async_prompt.zsh
zinit snippet OMZL::git.zsh
zinit snippet OMZP::git
zinit snippet OMZP::sudo
zinit snippet OMZP::ssh
zinit snippet OMZP::aliases
zinit snippet OMZP::globalias
zinit snippet OMZP::archlinux
zinit snippet OMZP::aws
zinit snippet OMZP::kubectl
zinit snippet OMZP::kubectx
zinit snippet OMZP::command-not-found

# Load completions
# Prune dangling symlinks left by zinit plugin updates (zinit doesn't clean these up)
command find "${ZINIT_HOME:h}/completions" -type l ! -exec test -e {} \; -delete 2>/dev/null
autoload -U +X bashcompinit && bashcompinit
autoload -Uz compinit && compinit

# Let zinit replay its captured completions
zinit cdreplay -q

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Keybindings
bindkey -e
bindkey '^p' history-search-backward
bindkey '^n' history-search-forward
bindkey '^[w' kill-region
bindkey '^n' forward-word # auto-accept partial suggestion from zsh-autosuggestion
bindkey '^[[3~' delete-char
bindkey '^[OH' beginning-of-line
bindkey '^[OF' end-of-line


# History
HISTSIZE=10000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups

# Completion styling
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'


# All custom functions and completions
for file in $HOME/.config/zsh/*.zsh; do
  source "$file"
done

if [[ -f ~/.raftrc ]]; then source ~/.raftrc; fi


# Shell integrations
if [[ -f ~/.fzf.zsh ]]; then
  source ~/.fzf.zsh
  eval "$(fzf --zsh)"
fi
# zi is defined by zinit as alias zi='zinit'. Unalias it to use with zoxide.
unalias zi 2>/dev/null || true
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

# Keep fpath shell-local so tmux panes never inherit stale zsh function paths.
typeset +x FPATH
