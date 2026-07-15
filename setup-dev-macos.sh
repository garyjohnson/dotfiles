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
echo -e "  ${hotpink}♥${pink}♥${rose}♥${peach}♥${lavender}♥${lilac}♥${purple}♥${periwinkle}♥${skyblue}♥${mint}♥${pink}♥${hotpink}♥${rose}♥${peach}♥${lavender}♥${lilac}♥${purple}♥${periwinkle}♥${skyblue}♥${mint}♥${hotpink}♥${pink}♥${rose}♥${hotpink}♥${pink}♥${rose}♥${peach}♥${lavender}♥${lilac}♥${purple}♥${periwinkle}♥${skyblue}♥${mint}♥${pink}♥${hotpink}♥${rose}♥${peach}♥${lavender}♥${lilac}♥${purple}♥${periwinkle}♥${skyblue}♥${mint}♥${hotpink}♥${pink}♥${rose}♥${reset}"
echo ""
echo -e "       ${bold}${hotpink}🌺${reset}  ${bold}${pink}d o t f i l e s${reset}  ${bold}${hotpink}🌺${reset}"
echo -e "       ${italic}${lavender}~* setting up your new machine *~${reset}"
echo ""
echo -e "  ${hotpink}♥${pink}♥${rose}♥${peach}♥${lavender}♥${lilac}♥${purple}♥${periwinkle}♥${skyblue}♥${mint}♥${pink}♥${hotpink}♥${rose}♥${peach}♥${lavender}♥${lilac}♥${purple}♥${periwinkle}♥${skyblue}♥${mint}♥${hotpink}♥${pink}♥${rose}♥${hotpink}♥${pink}♥${rose}♥${peach}♥${lavender}♥${lilac}♥${purple}♥${periwinkle}♥${skyblue}♥${mint}♥${pink}♥${hotpink}♥${rose}♥${peach}♥${lavender}♥${lilac}♥${purple}♥${periwinkle}♥${skyblue}♥${mint}♥${hotpink}♥${pink}♥${rose}♥${reset}"
echo ""
echo -e "  ${dim}${periwinkle}📂 $DOTFILES_DIR${reset}"

# --- Hostname ---
# Set explicitly so mDNS doesn't pick up some mangled/auto-generated name
# (macOS will sometimes grab whatever it finds on the network at first boot).

step "💻 Hostname"

current_hostname="$(scutil --get LocalHostName 2>/dev/null || hostname -s)"
prompt "Hostname [$current_hostname]: "
read desired_hostname
desired_hostname="${desired_hostname:-$current_hostname}"
hostname_changed=false

for attr in HostName LocalHostName ComputerName; do
  current_val="$(scutil --get "$attr" 2>/dev/null || true)"
  if [ "$desired_hostname" = "$current_val" ]; then
    skip "$attr already set to $current_val"
  else
    sudo scutil --set "$attr" "$desired_hostname"
    hostname_changed=true
  fi
done

if [ "$hostname_changed" = true ]; then
  success "Hostname set to $desired_hostname 💻"
fi

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

# --- Kagi CLI (from upstream install script) ---

step "🔑 Kagi CLI"

if command -v kagi &>/dev/null; then
  skip "kagi already installed at $(which kagi)"
else
  info "Installing kagi CLI from upstream..."
  curl -fsSL https://raw.githubusercontent.com/Microck/kagi-cli/main/scripts/install.sh | sh
  success "kagi CLI installed!"
fi

# --- Install 1Password to /Applications ---

step "🔐 1Password"

if [ -d "/Applications/1Password.app" ]; then
  skip "Already installed in /Applications"
else
  info "Installing to /Applications (it needs to live there, it's picky 💅)"
  brew install --cask 1password --appdir=/Applications
  success "1Password ready to go 🤫"
fi

# --- Symlink dotfiles ---

step "🔗 Symlinks"

symlink() {
  local src="$1"
  local dest="$2"
  local dest_dir
  dest_dir="$(dirname "$dest")"
  mkdir -p "$dest_dir"
  # If dest already exists as a symlink or real directory, remove it first.
  # Otherwise `ln -sf dir existing_dir` creates a symlink *inside* the dir.
  if [ -L "$dest" ] || { [ -d "$dest" ] && [ ! -L "$dest" ]; }; then
    rm -rf "$dest"
  fi
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
symlink "$DOTFILES_DIR/agents/AGENTS.md"      "$HOME/AGENTS.md"

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

# pi config — symlink shared configs, keep local runtime files
mkdir -p "$HOME/.pi/agent"
symlink "$DOTFILES_DIR/.pi/agent/models.json" "$HOME/.pi/agent/models.json"
symlink "$DOTFILES_DIR/.pi/agent/settings.json" "$HOME/.pi/agent/settings.json"
symlink "$DOTFILES_DIR/.pi/agent/themes" "$HOME/.pi/agent/themes"
symlink "$DOTFILES_DIR/.pi/agent/extensions" "$HOME/.pi/agent/extensions"

# pi auth setup (copy template if auth.json doesn't exist)
if [[ ! -f "$HOME/.pi/agent/auth.json" ]]; then
  info "Setting up pi auth template..."
  cp "$DOTFILES_DIR/.pi/agent/auth.template.json" "$HOME/.pi/agent/auth.json"
  warn "Edit ~/.pi/agent/auth.json with your credentials"
fi
success "All linked up 💕"

# --- Lua rocks (Neovim plugin deps) ---

step "🪨 Luarocks"

if luarocks --lua-version 5.1 --local list 2>/dev/null | grep -q "^magick"; then
  skip "magick already installed"
else
  info "Installing magick (required for image.nvim inline images)..."
  luarocks --lua-version 5.1 --local install magick
  success "magick installed 🖼️"
fi

# --- Install latest Node via nodenv ---

step "🟢 Node"

eval "$(nodenv init - bash)"
existing_node=$(nodenv versions --bare 2>/dev/null | grep -v '^system$')
if [ -n "$existing_node" ]; then
  skip "Node already managed by nodenv ($(nodenv global 2>/dev/null || echo $existing_node))"
else
  node_max_major=24
  latest_node=$(nodenv install -l | grep -E '^\s*[0-9]+\.[0-9]+\.[0-9]+$' | awk -v max="$node_max_major" '{gsub(/^ +/,"")} split($0,v,".") && v[1]+0 <= max' | tail -1 | tr -d ' ')
  info "Latest: ${bold}$latest_node${reset}"
  nodenv install -s "$latest_node"
  nodenv global "$latest_node"
  success "Node $latest_node 🐾"
fi

# --- npm globals ---

step "📦 npm globals"

eval "$(nodenv init - bash)"
npm install -g --force @openai/codex @earendil-works/pi-coding-agent firecrawl-cli
nodenv rehash
success "npm globals installed!"

# --- Bun ---

step "🥯 Bun"

if command -v bun &>/dev/null; then
  info "Updating bun..."
  bun upgrade
  skip "Already installed — updated!"
else
  info "Installing Bun..."
  curl -fsSL https://bun.com/install | bash
  success "Bun installed!"
fi

# --- Install latest Ruby via rbenv ---

step "💎 Ruby"

eval "$(rbenv init - bash)"
existing_ruby=$(rbenv versions --bare 2>/dev/null | grep -v '^system$')
if [ -n "$existing_ruby" ]; then
  skip "Ruby already managed by rbenv ($(rbenv global 2>/dev/null || echo $existing_ruby))"
else
  info "This may take a few minutes... grab a coffee ☕"
  export RUBY_CONFIGURE_OPTS="--with-openssl-dir=$(brew --prefix openssl@3)"
  latest_ruby=$(rbenv install -l | grep -E '^\s*[0-9]+\.[0-9]+\.[0-9]+$' | tail -1 | tr -d ' ')
  info "Latest: ${bold}$latest_ruby${reset}"
  rbenv install -s "$latest_ruby"
  rbenv global "$latest_ruby"
  success "Ruby $latest_ruby 💅✨"
fi

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

# --- Dev SSH keys from 1Password ---

step "🔑 Dev SSH keys from 1Password"

# Ensure 1Password CLI is connected
if ! echo "n" | op account list &>/dev/null; then
  warn "1Password CLI is not connected."
  info "Open ${bold}1Password → Settings → Developer${reset}"
  info "and turn on ${bold}\"Integrate with 1Password CLI\"${reset}"
  prompt "Press Enter once that's enabled: "
  read
fi

if ! echo "n" | op account list &>/dev/null; then
  err "Still can't reach 1Password — skipping Dev SSH keys"
else
  for item in "Dev SSH:dev_id_ed25519" "Dev3 SSH:dev3_id_ed25519"; do
    op_name="${item%%:*}"
    key_name="${item##*:}"

    if [ -f "$HOME/.ssh/$key_name" ]; then
      skip "$op_name key already exists at ~/.ssh/$key_name"
    else
      info "Fetching $op_name key from 1Password..."
      # op wraps field values in quotes; strip them and any blank lines
      op item get "$op_name" --fields "private key" --reveal \
        | awk 'NR==1{sub(/^\"/,\"\")} END{sub(/\"$/,\"\")} {print}' | awk 'NF' > "$HOME/.ssh/$key_name"
      op item get "$op_name" --fields "public key" \
        | awk 'NR==1{sub(/^\"/,\"\")} END{sub(/\"$/,\"\")} {print}' > "$HOME/.ssh/$key_name.pub"
      chmod 600 "$HOME/.ssh/$key_name"
      chmod 644 "$HOME/.ssh/$key_name.pub"
      success "$op_name key saved to ~/.ssh/$key_name 🗝️"
    fi
  done

  # Append Dev host configs if not already present
  for entry in "dev:dev_id_ed25519" "dev3:dev3_id_ed25519"; do
    host="${entry%%:*}"
    key_name="${entry##*:}"
    if grep -q "^Host ${host}$" "$HOME/.ssh/config" 2>/dev/null; then
      skip "$host SSH config already present"
    else
      cat >> "$HOME/.ssh/config" <<HOSTEOF

Host $host
  AddKeysToAgent yes
  UseKeychain yes
  HostName $host
  User garyjohnson
  IdentityFile ~/.ssh/${key_name}
HOSTEOF
      success "$host SSH config added"
    fi
  done
fi


# --- Home VPN (L2TP/IPsec) ---

step "🔒 Home VPN"

if scutil --nc list 2>/dev/null | grep -q "Home VPN"; then
  skip "Home VPN already configured"
else
  # Ensure 1Password CLI is connected
  if ! echo "n" | op account list &>/dev/null; then
    warn "1Password CLI is not connected."
    info "Open ${bold}1Password → Settings → Developer${reset}"
    info "and turn on ${bold}\"Integrate with 1Password CLI\"${reset}"
    prompt "Press Enter once that's enabled: "
    read
  fi

  # Verify it worked
  if ! echo "n" | op account list &>/dev/null; then
    err "Still can't reach 1Password — skipping VPN setup"
  else

  info "Fetching VPN credentials from 1Password..."
  vpn_server="$(op item get 'Home VPN' --fields 'server address')"
  vpn_user="$(op item get 'Home VPN' --fields 'username')"
  vpn_pass="$(op item get 'Home VPN' --fields 'password')"
  vpn_psk="$(op item get 'Home VPN' --fields 'pre-shared key')"

  vpn_uuid="$(uuidgen)"
  vpn_payload_uuid="$(uuidgen)"
  vpn_profile="/tmp/home-vpn-$$.mobileconfig"

  cat > "$vpn_profile" <<VPNEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>PayloadContent</key>
  <array>
    <dict>
      <key>PayloadType</key>
      <string>com.apple.vpn.managed</string>
      <key>PayloadVersion</key>
      <integer>1</integer>
      <key>PayloadIdentifier</key>
      <string>io.usefulbits.vpn.l2tp</string>
      <key>PayloadUUID</key>
      <string>$vpn_payload_uuid</string>
      <key>PayloadDisplayName</key>
      <string>Home VPN</string>
      <key>UserDefinedName</key>
      <string>Home VPN</string>
      <key>VPNType</key>
      <string>L2TP</string>
      <key>PPP</key>
      <dict>
        <key>AuthName</key>
        <string>$vpn_user</string>
        <key>AuthPassword</key>
        <string>$vpn_pass</string>
        <key>CommRemoteAddress</key>
        <string>$vpn_server</string>
      </dict>
      <key>IPSec</key>
      <dict>
        <key>AuthenticationMethod</key>
        <string>SharedSecret</string>
        <key>SharedSecret</key>
        <string>$vpn_psk</string>
      </dict>
    </dict>
  </array>
  <key>PayloadDisplayName</key>
  <string>Home VPN</string>
  <key>PayloadIdentifier</key>
  <string>io.usefulbits.vpn</string>
  <key>PayloadType</key>
  <string>Configuration</string>
  <key>PayloadUUID</key>
  <string>$vpn_uuid</string>
  <key>PayloadVersion</key>
  <integer>1</integer>
</dict>
</plist>
VPNEOF

  info "Opening VPN profile for installation..."
  open "$vpn_profile"
  info "Install the profile in ${bold}System Settings → Privacy & Security → Profiles${reset}"
  prompt "Press Enter after installing the profile: "
  read
  rm -f "$vpn_profile"
  success "Home VPN configured 🏠"

  fi
fi

# --- macOS defaults ---

step "🍎 macOS defaults"

source "$DOTFILES_DIR/.macos"
success "Defaults applied ✨"

# --- Dock ---

step "🚢 Dock"

info "Clearing default apps from dock..."
defaults write com.apple.dock persistent-apps -array

dock_add() {
  local app_path
  app_path="$(readlink -f "$1" 2>/dev/null || echo "$1")"
  local app_name
  app_name="$(basename "$app_path" .app)"
  defaults write com.apple.dock persistent-apps -array-add \
    "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>file://$app_path/</string><key>_CFURLStringType</key><integer>15</integer></dict><key>file-label</key><string>$app_name</string><key>file-type</key><integer>41</integer></dict><key>tile-type</key><string>file-tile</string></dict>"
}

# Finder is always pinned by macOS, no need to add it

# Applications folder stack (shows as "Apps" with grid display)
defaults write com.apple.dock persistent-others -array \
  "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>file:///Applications/</string><key>_CFURLStringType</key><integer>15</integer></dict><key>file-label</key><string>Apps</string><key>file-type</key><integer>2</integer></dict><key>tile-type</key><string>directory-tile</string></dict>"

# iTerm2 — check both install locations
iterm_path=""
if [ -d "$HOME/Applications/iTerm.app" ]; then
  iterm_path="$HOME/Applications/iTerm.app"
elif [ -d "/Applications/iTerm.app" ]; then
  iterm_path="/Applications/iTerm.app"
fi

if [ -n "$iterm_path" ]; then
  dock_add "$iterm_path"
else
  warn "iTerm2 not found — install it and add to dock manually"
fi

# Fastmail — installed to ~/Applications via Homebrew cask
fastmail_path=""
if [ -d "$HOME/Applications/Fastmail.app" ]; then
  fastmail_path="$HOME/Applications/Fastmail.app"
elif [ -d "/Applications/Fastmail.app" ]; then
  fastmail_path="/Applications/Fastmail.app"
fi

if [ -n "$fastmail_path" ]; then
  dock_add "$fastmail_path"
else
  warn "Fastmail not found — install it and add to dock manually"
fi

dock_add "/Applications/Safari.app"
dock_add "/System/Applications/Messages.app"

defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock magnification -bool true
defaults write com.apple.dock largesize -int 98

killall Dock 2>/dev/null || true
success "Dock cleaned up — auto-hidden, magnified, only the essentials 💅"

# --- iTerm2 config ---

step "🖥️  iTerm2"

defaults write com.googlecode.iterm2 PrefsCustomFolder -string "$DOTFILES_DIR/iterm"
defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true
success "iTerm2 configured 💅"

# --- Done ---

echo ""
echo -e "  ${hotpink}♥${pink}♥${rose}♥${peach}♥${lavender}♥${lilac}♥${purple}♥${periwinkle}♥${skyblue}♥${mint}♥${pink}♥${hotpink}♥${rose}♥${peach}♥${lavender}♥${lilac}♥${purple}♥${periwinkle}♥${skyblue}♥${mint}♥${hotpink}♥${pink}♥${rose}♥${hotpink}♥${pink}♥${rose}♥${peach}♥${lavender}♥${lilac}♥${purple}♥${periwinkle}♥${skyblue}♥${mint}♥${pink}♥${hotpink}♥${rose}♥${peach}♥${lavender}♥${lilac}♥${purple}♥${periwinkle}♥${skyblue}♥${mint}♥${hotpink}♥${pink}♥${rose}♥${reset}"
echo ""
echo -e "       ${bold}${hotpink}🌺${reset}  ${bold}${pink}a l l   d o n e !${reset}  ${bold}${hotpink}🌺${reset}"
echo -e "       ${italic}${lavender}~* your machine is ready to go *~${reset}"
echo ""
echo -e "  ${hotpink}♥${pink}♥${rose}♥${peach}♥${lavender}♥${lilac}♥${purple}♥${periwinkle}♥${skyblue}♥${mint}♥${pink}♥${hotpink}♥${rose}♥${peach}♥${lavender}♥${lilac}♥${purple}♥${periwinkle}♥${skyblue}♥${mint}♥${hotpink}♥${pink}♥${rose}♥${hotpink}♥${pink}♥${rose}♥${peach}♥${lavender}♥${lilac}♥${purple}♥${periwinkle}♥${skyblue}♥${mint}♥${pink}♥${hotpink}♥${rose}♥${peach}♥${lavender}♥${lilac}♥${purple}♥${periwinkle}♥${skyblue}♥${mint}♥${hotpink}♥${pink}♥${rose}♥${reset}"
echo ""
echo -e "  ${bold}${rose}📝 Manual steps remaining:${reset}"
echo -e "  ${lilac}🌷${reset} Activate VoiceInk license"
echo -e "  ${purple}🌷${reset} Configure Cap → ${bold}https://cap.app.usefulbits.io${reset}"
echo -e "  ${periwinkle}🌷${reset} Add Trilium PWA to dock from Safari:"
echo -e "     ${bold}https://trilium-gary.app.usefulbits.io/${reset}"
echo -e "  ${pink}🌷${reset} Install 1Password extension for Chrome"
echo -e "  ${skyblue}🌷${reset} Log in to Forgejo:  ${bold}tea login add -n forgejo -u https://forgejo.app.usefulbits.io${reset}"
echo -e "     ${bold}https://forgejo.app.usefulbits.io/user/settings/keys${reset}"
echo ""
echo -e "  ${mint}Open a new terminal to pick up the new shell config 💕${reset}"
echo ""
