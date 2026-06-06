[[ -f ~/.profile-env ]] && . ~/.profile-env

# Homebrew (per-user install at ~/homebrew on macOS, /home/linuxbrew on Linux)
if [[ "$OSTYPE" == "darwin"* ]]; then
  eval "$($HOME/homebrew/bin/brew shellenv)"
  export PATH="$HOME/.local/bin:$HOME/homebrew/opt/libpq/bin:$PATH"
else
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  export PATH="$HOME/.local/bin:/home/linuxbrew/.linuxbrew/opt/libpq/bin:$PATH"
fi

# History
export HISTIGNORE='rm*:git*'
export HISTORY_IGNORE='(rm*|git*)'

# Ruby build config (fixes openssl@3 issue)
export RUBY_CONFIGURE_OPTS="--with-openssl-dir=$(brew --prefix openssl@3)"

# Rust
export PATH="$HOME/.cargo/bin:$PATH"

# Tool inits
eval "$(oh-my-posh init zsh --config $HOME/oh-my-posh-themes/custom-janedobbeleer.omp.json)"
eval "$(nodenv init - zsh)"
eval "$(rbenv init - zsh)"
eval "$(zoxide init zsh)"
source <(fzf --zsh)

# Colors
autoload -U colors && colors

# Rename iterm2 tab (macOS only)
if [[ "$OSTYPE" == "darwin"* ]]; then
  tabname() { echo -ne "\033]0;"${1}"\007"; }
fi

diffbranch() { vim -p $(git diff --name-only ${1} HEAD) -c "tabdo :Gdiff ${1}" }

moshdev() { mosh dev -- tmux new -A -s main }
moshdev3() { mosh dev3 -- tmux new -A -s main }

# stop bugging me LLMS!
export CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY=true
export FIRECRAWL_NO_TELEMETRY=1

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# howdoi — ask for a bash command in plain english and get it prefilled at the prompt
function howdoi() {
  # Bail if no query provided
  if [[ -z "$1" ]]; then
    echo "Usage: howdoi <what you want to do on the command line>"
    return 1
  fi

  # Suppress zsh job control noise (the [1] + done ... messages)
  setopt localoptions no_notify no_monitor

  # Build the constrained prompt so pi outputs only the command
  local prompt="$*"
  local pi_prompt="bash command to $prompt — output ONLY the raw single-line bash command, no markdown, no backticks, no explanation, just the command"

  # Run pi in the background, capture stdout to a temp file
  local tmpfile
  tmpfile=$(mktemp)
  pi -p --no-session --model "deepseek-ai/DeepSeek-V4-Flash" "$pi_prompt" 2>/dev/null >"$tmpfile" &
  local pid=$!
  disown $pid 2>/dev/null

  # Spinner while pi is running
  local spin='-\|/'
  local i=0
  while kill -0 $pid 2>/dev/null; do
    printf "\r  %c " "${spin:$i:1}"
    i=$(( (i + 1) % 4 ))
    sleep 0.1
  done

  # Clear the spinner line
  printf "\r          \r"

  # Read the first non-empty line from pi's output
  local cmd
  while IFS= read -r cmd && [[ -z "$cmd" ]]; do :; done <"$tmpfile"
  rm -f "$tmpfile"

  # Drop the command into the zsh line editor buffer so the user can press enter to run it
  if [[ -n "$cmd" ]]; then
    print -z "$cmd"
  fi
}

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
