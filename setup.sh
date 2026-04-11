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

# --- Install global npm packages ---

echo "==> Installing Claude Code and Codex..."
eval "$(nodenv init - bash)"
npm install -g @anthropic-ai/claude-code @openai/codex

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
