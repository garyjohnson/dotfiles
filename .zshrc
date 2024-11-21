source ~/.profile

export HISTIGNORE='rm*:git*'
export HISTORY_IGNORE='(rm*|git*)'

# nodenv
eval "$(nodenv init -)"
# rbenv
eval "$(~/.rbenv/bin/rbenv init - zsh)"

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
