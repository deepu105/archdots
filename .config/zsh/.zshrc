# Minimal Zsh setup.

autoload -Uz compinit
compinit

setopt auto_cd
setopt auto_pushd
setopt pushd_ignore_dups
setopt hist_ignore_dups
setopt share_history

HISTFILE="$ZDOTDIR/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000

bindkey -e
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init --cmd cd zsh)"
fi

if command -v fzf >/dev/null 2>&1; then
  source <(fzf --zsh)
fi

if [[ -f "$HOME/.profile" ]]; then
  source "$HOME/.profile"
fi

if [[ -s /usr/bin/niri ]]; then
  source <(niri completions zsh)
fi
