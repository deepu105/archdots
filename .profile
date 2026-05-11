# Minimal profile for Arch + niri + local AI development.

export EDITOR=nvim
export VISUAL=nvim

export LLAMA_CPP_REPO="${LLAMA_CPP_REPO:-$HOME/Workspace/llms/llama.cpp}"
export LLAMA_MODEL_ROOT="${LLAMA_MODEL_ROOT:-$HOME/Models}"
export LLAMA_HOST="${LLAMA_HOST:-127.0.0.1}"
export LLAMA_PORT="${LLAMA_PORT:-18080}"
export LLAMA_AMDGPU_TARGETS="${LLAMA_AMDGPU_TARGETS:-gfx1151}"

export OLLAMA_HOST="${OLLAMA_HOST:-localhost}"
export OLLAMA_PORT="${OLLAMA_PORT:-11434}"
export OLLAMA_MODELS="${OLLAMA_MODELS:-$HOME/Models/ollama}"

# Prefer Wayland for Electron apps.
export ELECTRON_OZONE_PLATFORM_HINT=wayland

path=(
  $path
  $HOME/.local/bin
  $HOME/.cargo/bin
  $HOME/.npm-global/bin
  $HOME/scripts
)
typeset -U path
export PATH

alias sysinfo='fastfetch'
alias updateSys='topgrade'
alias llamaServer='$HOME/archdots/scripts/llama_server.sh'
alias buildLlamaCpp='$HOME/archdots/scripts/update_llama_cpp.sh'

alias ls='eza --git --icons --color=always --group-directories-first'
alias l='ls -lahg'
alias ll='ls -lh'
alias la='ls -lah'
alias grep='rg'
alias top='btop'
alias vi='nvim'
alias vim='nvim'

alias paru='paru --color=always'
alias yay='paru --color=always'
alias pi='paru -S'
alias ps='paru -Ss'
alias pq='paru -Qi'

alias g='git'
alias gst='git status'
alias gss='git status -s'
alias ga='git add'
alias gcmsg='git commit -m'
alias gd='git diff'
alias gl='git pull'
alias gp='git push'
