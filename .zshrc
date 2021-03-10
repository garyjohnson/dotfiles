source ~/.profile

# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"

export HISTIGNORE='rm*:git*'
export HISTORY_IGNORE='(rm*|git*)'

# Rename iterm2 tab
tabname() { echo -ne "\033]0;"${1}"\007"; }

# Enable colors and change prompt
autoload -U colors && colors

printf "Loading oh-my-posh..."
eval "$(oh-my-posh --init --shell zsh --config $HOME/oh-my-posh-themes/custom-janedobbeleer.omp.json)"
printf "\033[K\033[100D"
