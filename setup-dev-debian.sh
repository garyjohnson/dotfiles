#!/bin/bash
set -e

# --- Colors & helpers ---

reset='\033[0m'
bold='\033[1m'
dim='\033[2m'
italic='\033[3m'

# the palette ✨
pink='\033[38;5;213m'
hotpink='\033[38;5;199m'
lavender='\033[38;5;183m'
lilac='\033[38;5;177m'
purple='\033[38;5;141m'
softpurple='\033[38;5;135m'
periwinkle='\033[38;5;147m'
rose='\033[38;5;211m'
peach='\033[38;5;217m'
mint='\033[38;5;158m'
skyblue='\033[38;5;117m'
white='\033[38;5;255m'
red='\033[38;5;204m'

step() {
  echo ""
  echo -e "  ${pink}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}"
  echo -e "  ${bold}${lilac}✿${reset} ${bold}${lavender}$1${reset}"
  echo -e "  ${pink}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}"
}

info()    { echo -e "  ${periwinkle}💜${reset} ${white}$1${reset}"; }
success() { echo -e "  ${mint}✨${reset} ${peach}$1${reset}"; }
skip()    { echo -e "  ${dim}${lavender}💤 $1${reset}"; }
warn()    { echo -e "  ${rose}🌸 $1${reset}"; }
err()     { echo -e "  ${red}💔 $1${reset}"; }
prompt()  { echo -en "  ${hotpink}▸${reset} $1"; }
link()    { echo -e "  ${dim}${purple}   $1 → $2${reset}"; }

# Resolve the dotfiles directory from script location
DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Validate environment ---

if [ -z "$HOME" ]; then
  err "HOME is not set"
  exit 1
fi

if [ "$(uname)" != "Linux" ]; then
  err "This script is for Debian/Linux only"
  exit 1
fi

echo ""
echo -e "  ${hotpink}♥${pink}♥${rose}♥${peach}♥${lavender}♥${lilac}♥${purple}♥${periwinkle}♥${skyblue}♥${mint}♥${pink}♥${hotpink}♥${rose}♥${peach}♥${lavender}♥${lilac}♥${purple}♥${periwinkle}♥${skyblue}♥${mint}♥${hotpink}♥${pink}♥${rose}♥${hotpink}♥${pink}♥${rose}♥${peach}♥${lavender}♥${lilac}♥${purple}♥${periwinkle}♥${skyblue}♥${mint}♥${pink}♥${hotpink}♥${rose}♥${peach}♥${lavender}♥${lilac}♥${purple}♥${periwinkle}♥${skyblue}♥${mint}♥${hotpink}♥${pink}♥${rose}♥${reset}"
echo ""
echo -e "       ${bold}${hotpink}🌺${reset}  ${bold}${pink}d o t f i l e s${reset}  ${bold}${hotpink}🌺${reset}"
echo -e "       ${italic}${lavender}~* setting up your headless dev environment *~${reset}"
echo ""
echo -e "  ${hotpink}♥${pink}♥${rose}♥${peach}♥${lavender}♥${lilac}♥${purple}♥${periwinkle}♥${skyblue}♥${mint}♥${pink}♥${hotpink}♥${rose}♥${peach}♥${lavender}♥${lilac}♥${purple}♥${periwinkle}♥${skyblue}♥${mint}♥${hotpink}♥${pink}♥${rose}♥${hotpink}♥${pink}♥${rose}♥${peach}♥${lavender}♥${lilac}♥${purple}♥${periwinkle}♥${skyblue}♥${mint}♥${pink}♥${hotpink}♥${rose}♥${peach}♥${lavender}♥${lilac}♥${purple}♥${periwinkle}♥${skyblue}♥${mint}♥${hotpink}♥${pink}♥${rose}♥${reset}"
echo ""
echo -e "  ${dim}${periwinkle}📂 $DOTFILES_DIR${reset}"

# --- apt bootstrap ---

step "📦 apt bootstrap"

info "Updating package list and installing essentials..."
sudo apt-get update -qq
sudo apt-get install -y zsh curl git build-essential tea libyaml-dev zlib1g-dev libssl-dev libreadline-dev libncurses5-dev libffi-dev libgdbm-dev mosh tmux unzip
success "apt packages installed!"

# --- zsh as default shell ---

step "🐚 zsh"

ZSH_PATH="$(which zsh)"
if [ "$SHELL" = "$ZSH_PATH" ]; then
  skip "zsh is already the default shell"
else
  info "Setting zsh as default shell..."
  chsh -s "$ZSH_PATH"
  success "zsh set as default shell (takes effect on next login)"
fi

# --- Linuxbrew ---

step "🍺 Homebrew (Linux)"

BREW_BIN="/home/linuxbrew/.linuxbrew/bin/brew"

if [ -f "$BREW_BIN" ]; then
  skip "Linuxbrew already installed"
else
  info "Installing Linuxbrew..."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  success "Linuxbrew installed!"
fi

eval "$($BREW_BIN shellenv)"

# --- Install packages from Brewfile ---

step "📦 Brew packages"

info "Running brew bundle... this might take a sec 🍩"
brew bundle --file="$DOTFILES_DIR/Brewfile"
success "All packages installed!"

# --- Symlink dotfiles ---

step "🔗 Symlinks"

symlink() {
  local src="$1"
  local dest="$2"
  local dest_dir
  dest_dir="$(dirname "$dest")"
  mkdir -p "$dest_dir"
  if [ -L "$dest" ] || { [ -d "$dest" ] && [ ! -L "$dest" ]; }; then
    rm -rf "$dest"
  fi
  ln -sf "$src" "$dest"
  link "$dest" "$src"
}

# Config files
symlink "$DOTFILES_DIR/.zshrc"         "$HOME/.zshrc"
symlink "$DOTFILES_DIR/.gitconfig"     "$HOME/.gitconfig"
symlink "$DOTFILES_DIR/.gitignore"     "$HOME/.gitignore"
symlink "$DOTFILES_DIR/.tmux.conf"     "$HOME/.tmux.conf"
symlink "$DOTFILES_DIR/.config/nvim"   "$HOME/.config/nvim"
symlink "$DOTFILES_DIR/oh-my-posh-themes" "$HOME/oh-my-posh-themes"

# Individual .local/bin scripts
symlink "$DOTFILES_DIR/.local/bin/until-fail"    "$HOME/.local/bin/until-fail"
symlink "$DOTFILES_DIR/.local/bin/until-success" "$HOME/.local/bin/until-success"
symlink "$DOTFILES_DIR/.local/bin/kagi"          "$HOME/.local/bin/kagi"

# Tool symlinks (typo-correctors and editor aliases)
mkdir -p "$HOME/.local/bin"
ln -sf "$(brew --prefix git)/bin/git"   "$HOME/.local/bin/gti"
ln -sf "$(brew --prefix neovim)/bin/nvim" "$HOME/.local/bin/vi"
ln -sf "$(brew --prefix neovim)/bin/nvim" "$HOME/.local/bin/vim"
info "gti → git, vi → nvim, vim → nvim (typo-proof aliases 🐾)"

# pi config — symlink shared configs, keep local runtime files
mkdir -p "$HOME/.pi/agent"
symlink "$DOTFILES_DIR/.pi/agent/models.json" "$HOME/.pi/agent/models.json"
symlink "$DOTFILES_DIR/.pi/agent/settings.json" "$HOME/.pi/agent/settings.json"
symlink "$DOTFILES_DIR/.pi/agent/themes" "$HOME/.pi/agent/themes"
if [[ -d "$DOTFILES_DIR/.pi/extensions" ]]; then
  symlink "$DOTFILES_DIR/.pi/extensions" "$HOME/.pi/extensions"
fi

# pi auth setup (copy template if auth.json doesn't exist)
if [[ ! -f "$HOME/.pi/agent/auth.json" ]]; then
  info "Setting up pi auth template..."
  cp "$DOTFILES_DIR/.pi/agent/auth.template.json" "$HOME/.pi/agent/auth.json"
  warn "Edit ~/.pi/agent/auth.json with your credentials"
fi
success "All linked up 💕"

# --- TPM (Tmux Plugin Manager) ---

step "🔌 TPM"

if [ -d "$HOME/.tmux/plugins/tpm" ]; then
  skip "TPM already installed"
else
  info "Cloning TPM..."
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
  success "TPM installed! Use prefix + I inside tmux to install plugins."
fi

# --- Node via nodenv ---

step "🟢 Node"

eval "$(nodenv init - bash)"
node_max_major=24
latest_node=$(nodenv install -l | grep -E '^\s*[0-9]+\.[0-9]+\.[0-9]+$' | awk -v max="$node_max_major" '{gsub(/^ +/,"")} split($0,v,".") && v[1]+0 <= max' | tail -1 | tr -d ' ')
info "Latest: ${bold}$latest_node${reset}"
nodenv install -s "$latest_node"
nodenv global "$latest_node"
nodenv rehash
success "Node $latest_node 🐾"

# --- npm globals ---

step "📦 npm globals"

eval "$(nodenv init - bash)"
npm install -g --force codex @mariozechner/pi-coding-agent firecrawl-cli
nodenv rehash
success "npm globals installed!"

# --- Bun ---

step "🥯 Bun"

if command -v bun &>/dev/null; then
  info "Updating bun..."
  bun upgrade
  skip "Already installed — updated!"
else
  info "Installing Bun (requires unzip)..."
  curl -fsSL https://bun.com/install | bash
  success "Bun installed!"
fi

# --- Ruby via rbenv ---

step "💎 Ruby"

info "This may take a few minutes... grab a coffee ☕"
eval "$(rbenv init - bash)"
export RUBY_CONFIGURE_OPTS="--with-openssl-dir=$(brew --prefix openssl@3)"
latest_ruby=$(rbenv install -l | grep -E '^\s*[0-9]+\.[0-9]+\.[0-9]+$' | tail -1 | tr -d ' ')
info "Latest: ${bold}$latest_ruby${reset}"
rbenv install -s "$latest_ruby"
rbenv global "$latest_ruby"
success "Ruby $latest_ruby 💅✨"

# --- Rust via rustup ---

step "🦀 Rust"

if command -v rustup &>/dev/null; then
  info "Updating rustup and toolchain..."
  rustup update
  skip "Already installed — updated!"
else
  info "Installing Rust via rustup..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  source "$HOME/.cargo/env"
  success "Rust $(rustc --version | cut -d' ' -f2) installed 🦀"
fi

# --- Claude Code ---

step "🤖 Claude Code"

info "Installing via official install script..."
curl -fsSL https://claude.ai/install.sh | bash
success "Claude Code installed!"

# --- Skills ---

step "✨ Skills"

eval "$(nodenv init - bash)"
info "Installing firecrawl skills..."
npx --yes skills add -g firecrawl/cli -y
npx --yes skills add -g firecrawl/skills -y
info "Installing grill-me..."
npx --yes skills add -g mattpocock/skills --skill grill-me -y
success "Skills installed!"

# --- Git identity ---

step "👤 Git identity"

if [ -f "$HOME/.profile-env" ] && grep -q "GIT_AUTHOR_NAME" "$HOME/.profile-env"; then
  skip "Already configured in ~/.profile-env"
  grep "GIT_AUTHOR" "$HOME/.profile-env" | while read -r line; do
    echo -e "  ${dim}${lavender}$line${reset}"
  done
else
  prompt "Git author name [Gary Johnson]: "
  read git_name
  git_name="${git_name:-Gary Johnson}"
  prompt "Git author email: "
  read git_email

  cat >> "$HOME/.profile-env" <<EOF

# Git identity
export GIT_AUTHOR_NAME="$git_name"
export GIT_AUTHOR_EMAIL="$git_email"
export GIT_COMMITTER_NAME="$git_name"
export GIT_COMMITTER_EMAIL="$git_email"
EOF
  success "Written to ~/.profile-env"
fi

# --- SSH key ---

step "🔑 SSH key"

if [ -f "$HOME/.ssh/id_ed25519" ]; then
  skip "Key already exists at ~/.ssh/id_ed25519"
else
  info "Generating ed25519 key..."

  if [ -n "$git_email" ]; then
    ssh_email="$git_email"
  elif [ -f "$HOME/.profile-env" ] && grep -q "GIT_AUTHOR_EMAIL" "$HOME/.profile-env"; then
    ssh_email=$(grep "GIT_AUTHOR_EMAIL" "$HOME/.profile-env" | head -1 | sed 's/.*="\(.*\)"/\1/')
  else
    prompt "Email for SSH key: "
    read ssh_email
  fi

  ssh-keygen -t ed25519 -C "$ssh_email" -f "$HOME/.ssh/id_ed25519" -N ""
  success "Key generated! 🗝️"
fi

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
if [ ! -f "$HOME/.ssh/config" ]; then
  cat > "$HOME/.ssh/config" <<EOF
Host github.com
  AddKeysToAgent yes
  IdentitiesOnly yes
  IdentityFile ~/.ssh/id_ed25519

Host forgejo.app.usefulbits.io
  AddKeysToAgent yes
  IdentitiesOnly yes
  IdentityFile ~/.ssh/id_ed25519
EOF
  chmod 600 "$HOME/.ssh/config"
  success "Written ~/.ssh/config"
else
  skip "~/.ssh/config already exists"
fi

eval "$(ssh-agent -s)" > /dev/null 2>&1
ssh-add "$HOME/.ssh/id_ed25519" 2>/dev/null || true

step "🐙 GitHub SSH"

if gh auth status &>/dev/null; then
  skip "Already logged into GitHub"
else
  info "Log in via browser (a URL + one-time code will appear)..."
  gh auth login -w -p https
fi
gh ssh-key add "$HOME/.ssh/id_ed25519.pub" --title "$(hostname)-$(date +%Y%m%d)" 2>/dev/null \
  && success "SSH key added to GitHub 🎉" \
  || skip "SSH key already on GitHub"

# --- Done ---

echo ""
echo -e "  ${hotpink}♥${pink}♥${rose}♥${peach}♥${lavender}♥${lilac}♥${purple}♥${periwinkle}♥${skyblue}♥${mint}♥${pink}♥${hotpink}♥${rose}♥${peach}♥${lavender}♥${lilac}♥${purple}♥${periwinkle}♥${skyblue}♥${mint}♥${hotpink}♥${pink}♥${rose}♥${hotpink}♥${pink}♥${rose}♥${peach}♥${lavender}♥${lilac}♥${purple}♥${periwinkle}♥${skyblue}♥${mint}♥${pink}♥${hotpink}♥${rose}♥${peach}♥${lavender}♥${lilac}♥${purple}♥${periwinkle}♥${skyblue}♥${mint}♥${hotpink}♥${pink}♥${rose}♥${reset}"
echo ""
echo -e "       ${bold}${hotpink}🌺${reset}  ${bold}${pink}a l l   d o n e !${reset}  ${bold}${hotpink}🌺${reset}"
echo -e "       ${italic}${lavender}~* your dev environment is ready to go *~${reset}"
echo ""
echo -e "  ${hotpink}♥${pink}♥${rose}♥${peach}♥${lavender}♥${lilac}♥${purple}♥${periwinkle}♥${skyblue}♥${mint}♥${pink}♥${hotpink}♥${rose}♥${peach}♥${lavender}♥${lilac}♥${purple}♥${periwinkle}♥${skyblue}♥${mint}♥${hotpink}♥${pink}♥${rose}♥${hotpink}♥${pink}♥${rose}♥${peach}♥${lavender}♥${lilac}♥${purple}♥${periwinkle}♥${skyblue}♥${mint}♥${pink}♥${hotpink}♥${rose}♥${peach}♥${lavender}♥${lilac}♥${purple}♥${periwinkle}♥${skyblue}♥${mint}♥${hotpink}♥${pink}♥${rose}♥${reset}"
echo ""
echo -e "  ${bold}${rose}📝 Manual steps remaining:${reset}"
echo -e "  ${lilac}🌷${reset} Add SSH key to Forgejo:"
echo -e "     ${bold}https://forgejo.app.usefulbits.io/user/settings/keys${reset}"
echo -e "  ${purple}🌷${reset} Fill in ${bold}~/.profile-env${reset} with API keys (ANTHROPIC_API_KEY, etc.)"
echo -e "  ${periwinkle}🌷${reset} Coolify: no CLI available — manage via web dashboard"
echo -e "  ${pink}🌷${reset} Start tmux, then use ${bold}prefix + I${reset} to install any future plugins"
echo ""
echo -e "  ${mint}Open a new shell (or source ~/.zshrc) to pick up the new config 💕${reset}"
echo ""
