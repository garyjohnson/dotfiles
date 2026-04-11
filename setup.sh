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

if [ "$(uname)" != "Darwin" ]; then
  err "This script is for macOS only"
  exit 1
fi

echo ""
echo -e "  ${hotpink}♥${pink}♥${rose}♥${peach}♥${lavender}♥${lilac}♥${purple}♥${periwinkle}♥${skyblue}♥${mint}♥${pink}♥${hotpink}♥${rose}♥${peach}♥${lavender}♥${lilac}♥${purple}♥${periwinkle}♥${skyblue}♥${mint}♥${hotpink}♥${pink}♥${rose}♥${reset}"
echo ""
echo -e "       ${bold}${hotpink}🌺${reset}  ${bold}${pink}d o t f i l e s${reset}  ${bold}${hotpink}🌺${reset}"
echo -e "       ${italic}${lavender}~* setting up your new machine *~${reset}"
echo ""
echo -e "  ${hotpink}♥${pink}♥${rose}♥${peach}♥${lavender}♥${lilac}♥${purple}♥${periwinkle}♥${skyblue}♥${mint}♥${pink}♥${hotpink}♥${rose}♥${peach}♥${lavender}♥${lilac}♥${purple}♥${periwinkle}♥${skyblue}♥${mint}♥${hotpink}♥${pink}♥${rose}♥${reset}"
echo ""
echo -e "  ${dim}${periwinkle}📂 $DOTFILES_DIR${reset}"

# --- Install Homebrew to ~/homebrew ---

step "🍺 Homebrew"

if [ ! -f "$HOME/homebrew/bin/brew" ]; then
  info "Installing Homebrew to ~/homebrew..."
  mkdir -p "$HOME/homebrew"
  curl -L https://github.com/Homebrew/brew/tarball/master | tar xz --strip-components 1 -C "$HOME/homebrew"
  success "Homebrew installed!"
else
  skip "Homebrew already installed at ~/homebrew"
fi

eval "$($HOME/homebrew/bin/brew shellenv)"

# --- Install packages from Brewfile ---

step "📦 Brew packages"

info "Running brew bundle... this might take a sec 🍩"
mkdir -p "$HOME/Applications"
export HOMEBREW_CASK_OPTS="--appdir=$HOME/Applications"
brew bundle --file="$DOTFILES_DIR/Brewfile"
success "All packages installed!"

# --- Install 1Password to /Applications ---

step "🔐 1Password"

info "Installing to /Applications (it needs to live there, it's picky 💅)"
brew install --cask 1password --appdir=/Applications
success "1Password ready to go 🤫"

# --- Symlink dotfiles ---

step "🔗 Symlinks"

symlink() {
  local src="$1"
  local dest="$2"
  local dest_dir
  dest_dir="$(dirname "$dest")"
  mkdir -p "$dest_dir"
  ln -sf "$src" "$dest"
  link "$dest" "$src"
}

# Config files
symlink "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"
symlink "$DOTFILES_DIR/.gitconfig" "$HOME/.gitconfig"
symlink "$DOTFILES_DIR/.gitignore" "$HOME/.gitignore"
symlink "$DOTFILES_DIR/.tmux.conf" "$HOME/.tmux.conf"
symlink "$DOTFILES_DIR/.config/nvim" "$HOME/.config/nvim"
symlink "$DOTFILES_DIR/oh-my-posh-themes" "$HOME/oh-my-posh-themes"

# Individual .local/bin scripts
symlink "$DOTFILES_DIR/.local/bin/allow-exec" "$HOME/.local/bin/allow-exec"
symlink "$DOTFILES_DIR/.local/bin/until-fail" "$HOME/.local/bin/until-fail"
symlink "$DOTFILES_DIR/.local/bin/until-success" "$HOME/.local/bin/until-success"
symlink "$DOTFILES_DIR/.local/bin/iterm-open" "$HOME/.local/bin/iterm-open"

# Tool symlinks (typo-correctors and editor aliases)
ln -sf "$HOME/homebrew/bin/git" "$HOME/.local/bin/gti"
ln -sf "$HOME/homebrew/bin/nvim" "$HOME/.local/bin/vi"
ln -sf "$HOME/homebrew/bin/nvim" "$HOME/.local/bin/vim"
info "gti → git, vi → nvim, vim → nvim (typo-proof aliases 🐾)"

# AI config
symlink "$DOTFILES_DIR/.claude/settings.json" "$HOME/.claude/settings.json"
success "All linked up 💕"

# --- Install latest Node via nodenv ---

step "🟢 Node"

eval "$(nodenv init - bash)"
latest_node=$(nodenv install -l | grep -E '^\s*[0-9]+\.[0-9]+\.[0-9]+$' | tail -1 | tr -d ' ')
info "Latest: ${bold}$latest_node${reset}"
nodenv install -s "$latest_node"
nodenv global "$latest_node"
success "Node $latest_node 🐾"

# --- Install latest Ruby via rbenv ---

step "💎 Ruby"

info "This may take a few minutes... grab a coffee ☕"
eval "$(rbenv init - bash)"
export RUBY_CONFIGURE_OPTS="--with-openssl-dir=$(brew --prefix openssl@3)"
latest_ruby=$(rbenv install -l | grep -E '^\s*[0-9]+\.[0-9]+\.[0-9]+$' | tail -1 | tr -d ' ')
info "Latest: ${bold}$latest_ruby${reset}"
rbenv install -s "$latest_ruby"
rbenv global "$latest_ruby"
success "Ruby $latest_ruby 💅✨"

# --- Install Claude Code ---

step "🤖 Claude Code"

if command -v claude &>/dev/null; then
  skip "Already installed 💜"
else
  info "Installing..."
  curl -fsSL https://claude.ai/install.sh | bash
  success "Claude Code installed!"
fi

# --- Install Codex ---

step "🧬 Codex"

info "Installing..."
brew install --cask codex
success "Codex installed!"

# --- App Store installs ---

step "🏪 App Store"

mas install 497799835 || warn "Xcode: already installed or App Store sign-in required"
mas install 441258766 || warn "Magnet: already installed or App Store sign-in required"
mas install 1569813296 || warn "1Password for Safari: already installed or App Store sign-in required"
success "App Store done 🛒"

# --- Xcode post-install ---

step "🔨 Xcode"

if command -v xcodebuild &>/dev/null; then
  if ! xcodebuild -license check &>/dev/null; then
    info "Accepting Xcode license (the one nobody reads lol)..."
    sudo xcodebuild -license accept 2>/dev/null || warn "Xcode license may need manual acceptance"
  else
    skip "License already accepted"
  fi
  xcodebuild -runFirstLaunch 2>/dev/null || true
  success "Xcode configured!"
fi

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

# --- SSH key setup ---

step "🔑 SSH key"

# Generate key if needed
if [ -f "$HOME/.ssh/id_ed25519" ]; then
  skip "Key already exists at ~/.ssh/id_ed25519"
else
  info "Generating ed25519 key..."

  # Use git email if available, otherwise prompt
  if [ -n "$git_email" ]; then
    ssh_email="$git_email"
  elif [ -f "$HOME/.profile-env" ] && grep -q "GIT_AUTHOR_EMAIL" "$HOME/.profile-env"; then
    ssh_email=$(grep "GIT_AUTHOR_EMAIL" "$HOME/.profile-env" | head -1 | sed 's/.*="\(.*\)"/\1/')
  else
    prompt "Email for SSH key: "
    read ssh_email
  fi

  ssh-keygen -t ed25519 -C "$ssh_email" -f "$HOME/.ssh/id_ed25519"
  success "Key generated! 🗝️"
fi

# Configure SSH for GitHub and Forgejo
mkdir -p "$HOME/.ssh"
if [ ! -f "$HOME/.ssh/config" ]; then
  cat > "$HOME/.ssh/config" <<EOF
Host github.com
  AddKeysToAgent yes
  UseKeychain yes
  IdentitiesOnly yes
  IdentityFile ~/.ssh/id_ed25519

Host forgejo.app.usefulbits.io
  AddKeysToAgent yes
  UseKeychain yes
  IdentitiesOnly yes
  IdentityFile ~/.ssh/id_ed25519
EOF
  success "Written ~/.ssh/config"
else
  skip "~/.ssh/config already exists"
fi

# Add key to ssh-agent
eval "$(ssh-agent -s)"
ssh-add --apple-use-keychain "$HOME/.ssh/id_ed25519" 2>/dev/null

step "🐙 GitHub SSH"

if gh auth status &>/dev/null; then
  skip "Already logged into GitHub"
else
  info "Opening browser to log in... 🌐"
  gh auth login -w -p https
fi
gh ssh-key add "$HOME/.ssh/id_ed25519.pub" --title "$(hostname)-$(date +%Y%m%d)" 2>/dev/null \
  && success "SSH key added to GitHub 🎉" \
  || skip "SSH key already on GitHub"

step "🦎 Forgejo SSH"

pbcopy < "$HOME/.ssh/id_ed25519.pub"
info "Public key copied to clipboard 📋"
info "Add it here → ${bold}${hotpink}https://forgejo.app.usefulbits.io/user/settings/keys${reset}"
prompt "Press Enter after adding the key: "
read

# --- macOS defaults ---

step "🍎 macOS defaults"

source "$DOTFILES_DIR/.macos"
success "Defaults applied ✨"

# --- iTerm2 config ---

step "🖥️  iTerm2"

defaults write com.googlecode.iterm2 PrefsCustomFolder -string "$DOTFILES_DIR/iterm"
defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true
success "iTerm2 configured 💅"

# --- Done ---

echo ""
echo -e "  ${hotpink}♥${pink}♥${rose}♥${peach}♥${lavender}♥${lilac}♥${purple}♥${periwinkle}♥${skyblue}♥${mint}♥${pink}♥${hotpink}♥${rose}♥${peach}♥${lavender}♥${lilac}♥${purple}♥${periwinkle}♥${skyblue}♥${mint}♥${hotpink}♥${pink}♥${rose}♥${reset}"
echo ""
echo -e "       ${bold}${hotpink}🌺${reset}  ${bold}${pink}a l l   d o n e !${reset}  ${bold}${hotpink}🌺${reset}"
echo -e "       ${italic}${lavender}~* your machine is ready to go *~${reset}"
echo ""
echo -e "  ${hotpink}♥${pink}♥${rose}♥${peach}♥${lavender}♥${lilac}♥${purple}♥${periwinkle}♥${skyblue}♥${mint}♥${pink}♥${hotpink}♥${rose}♥${peach}♥${lavender}♥${lilac}♥${purple}♥${periwinkle}♥${skyblue}♥${mint}♥${hotpink}♥${pink}♥${rose}♥${reset}"
echo ""
echo -e "  ${bold}${rose}📝 Manual steps remaining:${reset}"
echo -e "  ${lilac}🌷${reset} Activate VoiceInk license"
echo -e "  ${purple}🌷${reset} Configure Cap → ${bold}https://cap.app.usefulbits.io${reset}"
echo -e "  ${periwinkle}🌷${reset} Add Trilium PWA to dock from Safari:"
echo -e "     ${bold}https://trilium-gary.app.usefulbits.io/${reset}"
echo -e "  ${pink}🌷${reset} Install 1Password extension for Chrome"
echo ""
echo -e "  ${mint}Open a new terminal to pick up the new shell config 💕${reset}"
echo ""
