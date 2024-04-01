source ~/.profile

export HISTIGNORE='rm*:git*'
export HISTORY_IGNORE='(rm*|git*)'

# Rename iterm2 tab
tabname() { echo -ne "\033]0;"${1}"\007"; }

diffbranch() { vim -p $(git diff --name-only ${1} HEAD) -c "tabdo :Gdiff ${1}" }

# Enable colors and change prompt
autoload -U colors && colors

printf "Loading oh-my-posh..."
eval "$(oh-my-posh --init --shell zsh --config $HOME/oh-my-posh-themes/custom-janedobbeleer.omp.json)"
printf "\033[K\033[100D"

# for any local overrides
export PATH="$HOME/.local/bin:$PATH"

export PLAYDATE_SDK_PATH='/Users/garyjohnson/Developer/PlaydateSDK'
export PATH="$PATH:/opt/homebrew/opt/libpq/bin"
# export PATH="/opt/homebrew/opt/libpq/bin:$PATH"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"
