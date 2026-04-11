#!/bin/bash
set -e

# Resolve the dotfiles directory from script location
DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Validate environment ---

if [ -z "$HOME" ]; then
  echo "ERROR: \$HOME is not set"
  exit 1
fi

if [ "$(uname)" != "Darwin" ]; then
  echo "ERROR: This script is designed for macOS"
  exit 1
fi

echo "==> Dotfiles directory: $DOTFILES_DIR"

# --- Install Homebrew to ~/homebrew ---

if [ ! -f "$HOME/homebrew/bin/brew" ]; then
  echo "==> Installing Homebrew to ~/homebrew..."
  mkdir -p "$HOME/homebrew"
  curl -L https://github.com/Homebrew/brew/tarball/master | tar xz --strip-components 1 -C "$HOME/homebrew"
else
  echo "==> Homebrew already installed at ~/homebrew"
fi

eval "$($HOME/homebrew/bin/brew shellenv)"

# --- Install packages from Brewfile ---

echo "==> Running brew bundle..."
mkdir -p "$HOME/Applications"
export HOMEBREW_CASK_OPTS="--appdir=$HOME/Applications"
brew bundle --file="$DOTFILES_DIR/Brewfile"

# --- Symlink dotfiles ---

echo "==> Symlinking dotfiles..."

symlink() {
  local src="$1"
  local dest="$2"
  local dest_dir
  dest_dir="$(dirname "$dest")"
  mkdir -p "$dest_dir"
  ln -sf "$src" "$dest"
  echo "  $dest -> $src"
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
echo "  gti -> git, vi -> nvim, vim -> nvim"

# AI config
symlink "$DOTFILES_DIR/.claude/settings.json" "$HOME/.claude/settings.json"

# --- Install latest Node via nodenv ---

echo "==> Installing latest Node..."
eval "$(nodenv init - bash)"
latest_node=$(nodenv install -l | grep -E '^\s*[0-9]+\.[0-9]+\.[0-9]+$' | tail -1 | tr -d ' ')
echo "  Latest Node: $latest_node"
nodenv install -s "$latest_node"
nodenv global "$latest_node"

# --- Install latest Ruby via rbenv ---

echo "==> Installing latest Ruby (this may take a few minutes)..."
eval "$(rbenv init - bash)"
export RUBY_CONFIGURE_OPTS="--with-openssl-dir=$(brew --prefix openssl@3)"
latest_ruby=$(rbenv install -l | grep -E '^\s*[0-9]+\.[0-9]+\.[0-9]+$' | tail -1 | tr -d ' ')
echo "  Latest Ruby: $latest_ruby"
rbenv install -s "$latest_ruby"
rbenv global "$latest_ruby"

# --- Install Claude Code ---

echo "==> Installing Claude Code..."
curl -fsSL https://claude.ai/install.sh | bash

# --- Install Codex ---

echo "==> Installing Codex..."
brew install --cask codex

# --- App Store installs ---

echo "==> Installing App Store apps..."
mas install 497799835 || echo "  Xcode: already installed or App Store sign-in required"
mas install 441258766 || echo "  Magnet: already installed or App Store sign-in required"

# --- Xcode post-install ---

if command -v xcodebuild &>/dev/null; then
  echo "==> Configuring Xcode..."
  sudo xcodebuild -license accept 2>/dev/null || echo "  Xcode license may need manual acceptance"
  xcodebuild -runFirstLaunch 2>/dev/null || true
fi

# --- Git identity ---

echo "==> Configuring git identity..."
if [ -f "$HOME/.profile-env" ] && grep -q "GIT_AUTHOR_NAME" "$HOME/.profile-env"; then
  echo "  Git identity already configured in ~/.profile-env:"
  grep "GIT_AUTHOR" "$HOME/.profile-env"
else
  read -p "  Git author name [Gary Johnson]: " git_name
  git_name="${git_name:-Gary Johnson}"
  read -p "  Git author email: " git_email

  cat >> "$HOME/.profile-env" <<EOF

# Git identity
export GIT_AUTHOR_NAME="$git_name"
export GIT_AUTHOR_EMAIL="$git_email"
export GIT_COMMITTER_NAME="$git_name"
export GIT_COMMITTER_EMAIL="$git_email"
EOF
  echo "  Written to ~/.profile-env"
fi

# --- SSH key setup ---

# Generate key if needed
if [ -f "$HOME/.ssh/id_ed25519" ]; then
  echo "==> SSH key already exists at ~/.ssh/id_ed25519"
else
  echo "==> Generating SSH key..."

  # Use git email if available, otherwise prompt
  if [ -n "$git_email" ]; then
    ssh_email="$git_email"
  elif [ -f "$HOME/.profile-env" ] && grep -q "GIT_AUTHOR_EMAIL" "$HOME/.profile-env"; then
    ssh_email=$(grep "GIT_AUTHOR_EMAIL" "$HOME/.profile-env" | head -1 | sed 's/.*="\(.*\)"/\1/')
  else
    read -p "  Email for SSH key: " ssh_email
  fi

  ssh-keygen -t ed25519 -C "$ssh_email" -f "$HOME/.ssh/id_ed25519"
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
  echo "  Written ~/.ssh/config"
else
  echo "  ~/.ssh/config already exists"
fi

# Add key to ssh-agent
eval "$(ssh-agent -s)"
ssh-add --apple-use-keychain "$HOME/.ssh/id_ed25519" 2>/dev/null

# Add key to GitHub
echo ""
echo "==> Adding SSH key to GitHub..."
if gh auth status &>/dev/null; then
  echo "  Already logged into GitHub"
else
  gh auth login -w -p ssh
fi
gh ssh-key add "$HOME/.ssh/id_ed25519.pub" --title "$(hostname)-$(date +%Y%m%d)" 2>/dev/null \
  && echo "  SSH key added to GitHub" \
  || echo "  SSH key already exists on GitHub"

# Add key to Forgejo
echo ""
echo "==> Adding SSH key to Forgejo..."
if ssh -T git@forgejo.app.usefulbits.io 2>&1 | grep -q "Welcome"; then
  echo "  SSH key already configured on Forgejo"
else
  pbcopy < "$HOME/.ssh/id_ed25519.pub"
  echo "  Public key copied to clipboard. Add it at:"
  echo "    https://forgejo.app.usefulbits.io/user/settings/keys"
  read -p "  Press Enter after adding the key..."
fi

# --- macOS defaults ---

echo "==> Applying macOS defaults..."
source "$DOTFILES_DIR/.macos"

# --- iTerm2 config ---

echo "==> Configuring iTerm2..."
defaults write com.googlecode.iterm2 PrefsCustomFolder -string "$DOTFILES_DIR/iterm"
defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true

# --- Done ---

echo ""
echo "==> Setup complete!"
echo ""
echo "Manual steps remaining:"
echo "  - Activate VoiceInk license"
echo "  - Configure Cap to point at https://cap.app.usefulbits.io"
echo "  - Add Trilium PWA to dock from Safari: https://trilium-gary.app.usefulbits.io/"
echo ""
echo "Open a new terminal to pick up the new shell config."
