eval "$(oh-my-posh init zsh --config $HOME/oh-my-posh-themes/custom-janedobbeleer.omp.json)"

source <(fzf --zsh)

source ~/.profile

export HISTIGNORE='rm*:git*'
export HISTORY_IGNORE='(rm*|git*)'

# Rename iterm2 tab
tabname() { echo -ne "\033]0;"${1}"\007"; }

diffbranch() { vim -p $(git diff --name-only ${1} HEAD) -c "tabdo :Gdiff ${1}" }

# Enable colors and change prompt
autoload -U colors && colors

