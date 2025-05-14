# Enable the subsequent settings only in interactive sessions
case $- in
  *i*) ;;
    *) return;;
esac

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='nvim'
else
  export EDITOR='nvim'
fi

if [[ -f "$HOME/.config/bash/.bash_private" ]]; then
    source "$HOME/.config/bash/.bash_private"
fi

for file in $HOME/.config/bash/*.sh; do
  source "$file"
done

[ -f ~/.bash_lumen ] && source ~/.bash_lumen
[ -f ~/.fzf.bash ]   && source ~/.fzf.bash

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion


greetings="neofetch nerdfetch"
# if greeting bin exists, run it and stop evaluating the rest
if [[ -z "$TMUX" ]]; then
  for greeting in $greetings; do
    if command -v $greeting &> /dev/null; then
      $greeting
      break
    fi
  done
fi

if [[ -f ~/.raftrc ]]; then source ~/.raftrc; fi

# eval "$(oh-my-posh init bash --config ~/.config/oh-my-posh/themes/craver.json)"
eval "$(starship init bash)"

# If ssh'ing then automatically attach to the tmux session if it exists
if [[ $- =~ i ]] && [[ -z "$TMUX" ]] && [[ -n "$SSH_TTY" ]]; then
  tmux attach-session || tmux new-session
fi
