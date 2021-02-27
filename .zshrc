source ~/.profile

# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"

export HISTIGNORE='rm*:git*'
export HISTORY_IGNORE='(rm*|git*)'

# Rename iterm2 tab
tabname() { echo -ne "\033]0;"${1}"\007"; }

# Enable colors and change prompt
autoload -U colors && colors

# Load version control information
autoload -Uz vcs_info
precmd() { vcs_info }

# Format the vcs_info_msg_0_ variable
zstyle ':vcs_info:git:*' formats '(%b)'

# Set up the prompt (with git branch name)
setopt PROMPT_SUBST

# Color
PROMPT='%{$fg[magenta]%}%n@%m%{$fg[green]%} ${PWD##*/} %{$fg[yellow]%}${vcs_info_msg_0_}%{$reset_color%}> '
