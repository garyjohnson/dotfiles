[[ -f ~/.profile-env ]] && . ~/.profile-env

export HISTIGNORE='rm*:git*'
export HISTORY_IGNORE='(rm*|git*)'

export PATH="$HOME/.local/bin:$PATH"
export PLAYDATE_SDK_PATH='/Users/garyjohnson/Developer/PlaydateSDK'
export PATH="$PATH:/opt/homebrew/opt/libpq/bin"

tabname() { echo -ne "\033]0;"${1}"\007"; }
diffbranch() { vim -p $(git diff --name-only ${1} HEAD) -c "tabdo :Gdiff ${1}" }
