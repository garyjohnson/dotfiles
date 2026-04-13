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

if [ "$(uname -m)" != "arm64" ]; then
  err "This script is for Apple Silicon only"
  exit 1
fi

echo ""
echo -e "  ${hotpink}♥${pink}♥${rose}♥${peach}♥${lavender}♥${lilac}♥${purple}♥${periwinkle}♥${skyblue}♥${mint}♥${pink}♥${hotpink}♥${rose}♥${peach}♥${lavender}♥${lilac}♥${purple}♥${periwinkle}♥${skyblue}♥${mint}♥${hotpink}♥${pink}♥${rose}♥${hotpink}♥${pink}♥${rose}♥${peach}♥${lavender}♥${lilac}♥${purple}♥${periwinkle}♥${skyblue}♥${mint}♥${pink}♥${hotpink}♥${rose}♥${peach}♥${lavender}♥${lilac}♥${purple}♥${periwinkle}♥${skyblue}♥${mint}♥${hotpink}♥${pink}♥${rose}♥${reset}"
echo ""
echo -e "       ${bold}${hotpink}🧠${reset}  ${bold}${pink}h e a d l e s s${reset}  ${bold}${hotpink}🧠${reset}"
echo -e "       ${italic}${lavender}~* turning this mac into an LLM server *~${reset}"
echo ""
echo -e "  ${hotpink}♥${pink}♥${rose}♥${peach}♥${lavender}♥${lilac}♥${purple}♥${periwinkle}♥${skyblue}♥${mint}♥${pink}♥${hotpink}♥${rose}♥${peach}♥${lavender}♥${lilac}♥${purple}♥${periwinkle}♥${skyblue}♥${mint}♥${hotpink}♥${pink}♥${rose}♥${hotpink}♥${pink}♥${rose}♥${peach}♥${lavender}♥${lilac}♥${purple}♥${periwinkle}♥${skyblue}♥${mint}♥${pink}♥${hotpink}♥${rose}♥${peach}♥${lavender}♥${lilac}♥${purple}♥${periwinkle}♥${skyblue}♥${mint}♥${hotpink}♥${pink}♥${rose}♥${reset}"
echo ""
echo -e "  ${dim}${periwinkle}📂 $DOTFILES_DIR${reset}"

# --- GPU memory split ---

step "🧠 GPU memory split"

total_ram_bytes=$(sysctl -n hw.memsize)
total_ram_gb=$((total_ram_bytes / 1024 / 1024 / 1024))
info "Detected ${bold}${total_ram_gb}GB${reset}${white} total unified memory"

prompt "Reserve how much for the system? [10]: "
read system_reserve_gb
system_reserve_gb="${system_reserve_gb:-10}"

# Validate it's a number and within range
if ! [[ "$system_reserve_gb" =~ ^[0-9]+$ ]] || [ "$system_reserve_gb" -ge "$total_ram_gb" ] || [ "$system_reserve_gb" -lt 4 ]; then
  err "System reserve must be a number between 4 and $((total_ram_gb - 1))"
  exit 1
fi

gpu_mb=$(( (total_ram_gb - system_reserve_gb) * 1024 ))
info "GPU allocation: ${bold}$((total_ram_gb - system_reserve_gb))GB${reset}${white} (${gpu_mb}MB)"
info "System reserve: ${bold}${system_reserve_gb}GB${reset}"

sysctl_line="iogpu.wired_limit_mb=${gpu_mb}"

if [ -f /etc/sysctl.conf ] && grep -q "iogpu.wired_limit_mb" /etc/sysctl.conf; then
  current=$(grep "iogpu.wired_limit_mb" /etc/sysctl.conf | tail -1)
  if [ "$current" = "$sysctl_line" ]; then
    skip "Already set to ${gpu_mb}MB in /etc/sysctl.conf"
  else
    info "Updating /etc/sysctl.conf (was: $current)"
    sudo sed -i '' "s/^iogpu\.wired_limit_mb=.*/$sysctl_line/" /etc/sysctl.conf
    success "Updated GPU memory split (reboot required)"
  fi
else
  info "Writing /etc/sysctl.conf..."
  echo -e "# GPU memory allocation for LLM inference\n${sysctl_line}" | sudo tee /etc/sysctl.conf > /dev/null
  success "GPU memory split configured (reboot required)"
fi

# --- Sleep prevention ---

step "😴 Sleep prevention"

info "Configuring pmset to prevent sleep on AC and battery..."
sudo pmset -a displaysleep 0 sleep 0 disablesleep 1 standby 0 autopoweroff 0
sudo pmset -a lowpowermode 0
sudo pmset -a tcpkeepalive 1
success "Sleep disabled on all power sources"

# --- Remote Login (SSH) ---

step "🔑 SSH (Remote Login)"

if sudo systemsetup -getremotelogin 2>/dev/null | grep -q "On"; then
  skip "Remote Login already enabled"
else
  info "Enabling Remote Login..."
  sudo systemsetup -setremotelogin on
  success "SSH enabled"
fi

# --- Screen Sharing ---

step "🖥️  Screen Sharing"

if launchctl list 2>/dev/null | grep -q "com.apple.screensharing"; then
  skip "Screen Sharing already enabled"
else
  info "Enabling Screen Sharing..."
  sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.screensharing.plist 2>/dev/null \
    || sudo defaults write /var/db/launchd.db/com.apple.launchd/overrides.plist com.apple.screensharing -dict Disabled -bool false
  success "Screen Sharing enabled"
fi

# --- Auto-login ---

step "🔓 Auto-login"

current_user="$(whoami)"

if defaults read /Library/Preferences/com.apple.loginwindow autoLoginUser 2>/dev/null | grep -q "$current_user"; then
  skip "Auto-login already configured for $current_user"
else
  # Check for FileVault
  if fdesetup status 2>/dev/null | grep -q "On"; then
    warn "FileVault is enabled — auto-login won't work until it's disabled"
    warn "Disable via: sudo fdesetup disable"
  fi

  info "Setting auto-login for ${bold}$current_user${reset}"
  sudo defaults write /Library/Preferences/com.apple.loginwindow autoLoginUser "$current_user"
  success "Auto-login configured for $current_user"
fi

# --- 1Password ---

step "🔐 1Password"

if [ -d "/Applications/1Password.app" ]; then
  skip "Already installed in /Applications"
else
  info "Installing to /Applications (it needs to live there, it's picky 💅)"
  brew install --cask 1password --appdir=/Applications
  success "1Password installed!"
fi

if command -v op &>/dev/null; then
  skip "1Password CLI already installed"
else
  info "Installing 1Password CLI..."
  brew install 1password-cli
  success "1Password CLI installed!"
fi

# --- LM Studio ---

step "🤖 LM Studio"

lm_studio_path=""
if [ -d "$HOME/Applications/LM Studio.app" ]; then
  lm_studio_path="$HOME/Applications/LM Studio.app"
elif [ -d "/Applications/LM Studio.app" ]; then
  lm_studio_path="/Applications/LM Studio.app"
fi

if [ -n "$lm_studio_path" ]; then
  skip "LM Studio already installed at $lm_studio_path"
else
  info "Installing LM Studio..."
  brew install --cask lm-studio
  # Find where it ended up
  if [ -d "$HOME/Applications/LM Studio.app" ]; then
    lm_studio_path="$HOME/Applications/LM Studio.app"
  elif [ -d "/Applications/LM Studio.app" ]; then
    lm_studio_path="/Applications/LM Studio.app"
  fi
  success "LM Studio installed!"
fi

# Add as login item
if [ -n "$lm_studio_path" ]; then
  info "Adding LM Studio as a login item..."
  osascript -e "tell application \"System Events\" to make login item at end with properties {path:\"$lm_studio_path\"}" 2>/dev/null \
    && success "LM Studio will start on login" \
    || skip "Login item may already exist"
fi

# --- Xcode Command Line Tools ---

step "🔨 Xcode CLI Tools"

if xcode-select -p &>/dev/null; then
  skip "Already installed at $(xcode-select -p)"
else
  info "Installing Xcode Command Line Tools..."
  xcode-select --install
  info "Waiting for installation to complete..."
  until xcode-select -p &>/dev/null; do
    sleep 5
  done
  success "Xcode CLI Tools installed!"
fi

# --- iTerm2 preferences ---

step "🖥️  iTerm2"

defaults write com.googlecode.iterm2 PrefsCustomFolder -string "$DOTFILES_DIR/iterm"
defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true
success "iTerm2 configured 💅"

# --- Dock ---

step "🚢 Dock"

info "Clearing default apps from dock..."
defaults write com.apple.dock persistent-apps -array

dock_add() {
  defaults write com.apple.dock persistent-apps -array-add \
    "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>$1</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>"
}

# iTerm2 first — check both install locations
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

# Finder is always pinned by macOS, no need to add it
dock_add "/Applications/Safari.app"
dock_add "/System/Applications/System Settings.app"

# Disable widgets on desktop
defaults write com.apple.WindowManager EnableStandardClickToShowDesktop -bool false 2>/dev/null || true
defaults write com.apple.WindowManager StandardHideDesktopIcons -bool true 2>/dev/null || true

killall Dock 2>/dev/null || true
success "Dock cleaned up — only the essentials 💅"

# --- Install headless toggle script ---

step "🔧 Headless toggle"

mkdir -p "$DOTFILES_DIR/.local/bin"
info "Installing headless toggle to .local/bin..."

# Symlink the toggle script
mkdir -p "$HOME/.local/bin"
if [ -L "$HOME/.local/bin/headless" ]; then
  rm "$HOME/.local/bin/headless"
fi
ln -sf "$DOTFILES_DIR/.local/bin/headless" "$HOME/.local/bin/headless"
success "Toggle installed — use 'headless on' or 'headless off'"

# --- Done ---

echo ""
echo -e "  ${hotpink}♥${pink}♥${rose}♥${peach}♥${lavender}♥${lilac}♥${purple}♥${periwinkle}♥${skyblue}♥${mint}♥${pink}♥${hotpink}♥${rose}♥${peach}♥${lavender}♥${lilac}♥${purple}♥${periwinkle}♥${skyblue}♥${mint}♥${hotpink}♥${pink}♥${rose}♥${hotpink}♥${pink}♥${rose}♥${peach}♥${lavender}♥${lilac}♥${purple}♥${periwinkle}♥${skyblue}♥${mint}♥${pink}♥${hotpink}♥${rose}♥${peach}♥${lavender}♥${lilac}♥${purple}♥${periwinkle}♥${skyblue}♥${mint}♥${hotpink}♥${pink}♥${rose}♥${reset}"
echo ""
echo -e "       ${bold}${hotpink}🧠${reset}  ${bold}${pink}r e a d y   t o   s e r v e${reset}  ${bold}${hotpink}🧠${reset}"
echo -e "       ${italic}${lavender}~* your LLM server is almost ready *~${reset}"
echo ""
echo -e "  ${hotpink}♥${pink}♥${rose}♥${peach}♥${lavender}♥${lilac}♥${purple}♥${periwinkle}♥${skyblue}♥${mint}♥${pink}♥${hotpink}♥${rose}♥${peach}♥${lavender}♥${lilac}♥${purple}♥${periwinkle}♥${skyblue}♥${mint}♥${hotpink}♥${pink}♥${rose}♥${hotpink}♥${pink}♥${rose}♥${peach}♥${lavender}♥${lilac}♥${purple}♥${periwinkle}♥${skyblue}♥${mint}♥${pink}♥${hotpink}♥${rose}♥${peach}♥${lavender}♥${lilac}♥${purple}♥${periwinkle}♥${skyblue}♥${mint}♥${hotpink}♥${pink}♥${rose}♥${reset}"
echo ""
echo -e "  ${bold}${rose}📝 Manual steps:${reset}"
echo -e "  ${lilac}🌷${reset} Reboot to apply GPU memory split"
echo -e "  ${purple}🌷${reset} Open 1Password, sign in, then go to:"
echo -e "     ${bold}Settings → Developer → \"Integrate with 1Password CLI\"${reset}"
echo -e "  ${periwinkle}🌷${reset} Open LM Studio, download a model, and enable the API server"
echo -e "  ${pink}🌷${reset} In LM Studio settings, enable ${bold}\"Start server on app launch\"${reset}"
echo -e "  ${skyblue}🌷${reset} Verify with: ${bold}curl http://localhost:1234/v1/models${reset}"
echo ""
echo -e "  ${mint}Use 'headless on/off' to toggle server mode 💕${reset}"
echo ""
