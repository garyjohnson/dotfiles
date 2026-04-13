[[ -f ~/.profile-env ]] && . ~/.profile-env

# Homebrew (per-user install at ~/homebrew)
eval "$($HOME/homebrew/bin/brew shellenv)"

# PATH
export PATH="$HOME/.local/bin:$HOME/homebrew/opt/libpq/bin:$PATH"

# History
export HISTIGNORE='rm*:git*'
export HISTORY_IGNORE='(rm*|git*)'

# Ruby build config (fixes openssl@3 issue)
export RUBY_CONFIGURE_OPTS="--with-openssl-dir=$(brew --prefix openssl@3)"

# Tool inits
eval "$(oh-my-posh init zsh --config $HOME/oh-my-posh-themes/custom-janedobbeleer.omp.json)"
eval "$(nodenv init - zsh)"
eval "$(rbenv init - zsh)"
eval "$(zoxide init zsh)"
source <(fzf --zsh)

# Colors
autoload -U colors && colors

# Rename iterm2 tab
tabname() { echo -ne "\033]0;"${1}"\007"; }

diffbranch() { vim -p $(git diff --name-only ${1} HEAD) -c "tabdo :Gdiff ${1}" }

moshdev() { mosh devts -- tmux new -A -s main }
