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
moshdev2() { mosh dev2 -- tmux new -A -s main }
moshdev3() { mosh dev3 -- tmux new -A -s main }
hdev3() { herdr --remote dev3 }

# stop bugging me LLMS!
export CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY=true
export FIRECRAWL_NO_TELEMETRY=1

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# AWS via 1Password — every `aws` call resolves creds from the vault (Touch ID gated),
# nothing static lives in ~/.aws/credentials
function aws() {
  local profile="${AWS_PROFILE:-panda-mobile}"
  local args=("$@")
  local passthrough=()
  local i=1
  while (( i <= $#args )); do
    if [[ "${args[$i]}" == "--profile" && -n "${args[$((i + 1))]}" ]]; then
      profile="${args[$((i + 1))]}"
      (( i += 2 ))
    else
      passthrough+=("${args[$i]}")
      (( i += 1 ))
    fi
  done

  local envfile="$HOME/.config/aws/op-${profile}.env"
  if [[ ! -f "$envfile" ]]; then
    echo "aws: no 1Password env file for profile '$profile' at $envfile" >&2
    return 1
  fi

  op run --env-file="$envfile" -- command aws "${passthrough[@]}"
}

# howdoi — ask for a bash command in plain english and get it prefilled at the prompt
function howdoi() {
  if [[ -z "$1" ]]; then
    echo "Usage: howdoi <what you want to do on the command line>"
    return 1
  fi

  local cmd harness
  case "${LLM_HARNESS:-pi}" in
    pi)    harness=(pi -p --no-session --model "deepseek-ai/DeepSeek-V4-Flash") ;;
    claude) harness=(claude -p) ;;
    codex) harness=(codex exec) ;;
    *)     echo "Invalid LLM_HARNESS: ${LLM_HARNESS} (valid: pi, claude, codex)" >&2; return 1 ;;
  esac

  # Ask the harness for a bash command, then grab the first non-blank line
  cmd=$("${harness[@]}" "bash command to $* — output ONLY the raw single-line bash command, no markdown, no backticks, no explanation, just the command" 2>/dev/null | sed -n '/[^[:space:]]/p' | head -1)

  # Inject the command into the zsh line editor buffer so the user can press enter to run it
  if [[ -n "$cmd" ]]; then
    print -z "$cmd"
  fi
}

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
