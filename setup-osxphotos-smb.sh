#!/bin/bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# setup-osxphotos-smb.sh
#
# Idempotent setup for backing up an Apple Photos library to an SMB share
# using osxphotos. On re-run it updates the installed script, plist, and
# credentials file in place, and restarts the LaunchAgent if anything changed.
#
# Prompts (interactively) for the SMB username + password once and writes them
# into a local credentials file that the sync script then reads directly. No
# keychain involvement, so launchd runs never need to re-enter creds or unlock
# anything. The creds file is chmod 600 (owner-only).
# ─────────────────────────────────────────────────────────────────────────────

# --- Colors & helpers (matches the rest of the dotfiles ✨) ------------------

reset='\033[0m'
bold='\033[1m'
dim='\033[2m'
italic='\033[3m'

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

step()    { echo ""; echo -e "  ${pink}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}"; echo -e "  ${bold}${lilac}✿${reset} ${bold}${lavender}$1${reset}"; echo -e "  ${pink}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}"; }
info()    { echo -e "  ${periwinkle}💜${reset} ${white}$1${reset}"; }
success() { echo -e "  ${mint}✨${reset} ${peach}$1${reset}"; }
skip()    { echo -e "  ${dim}${lavender}💤 $1${reset}"; }
warn()    { echo -e "  ${rose}🌸 $1${reset}"; }
err()     { echo -e "  ${red}💔 $1${reset}"; exit 1; }
prompt()  { echo -en "  ${hotpink}▸${reset} $1"; }
link()    { echo -e "  ${dim}${purple}   $1 → $2${reset}"; }

# ─────────────────────────────────────────────────────────────────────────────
#  EDITABLE CONFIG  (everything machine/OS-specific is here)
# ─────────────────────────────────────────────────────────────────────────────

# These are defaults only — everything user-facing is prompted at setup,
# with the value below shown as the default. Running the script asks for
# server/share/library/creds/etc; no editing required.
SERVER=""                # e.g. "truenas.local" or "192.168.1.50" (prompted)
SHARE=""                 # e.g. "photos" (prompted)

# Where the Photos library lives (on the SSD / external drive). Default below;
# re-prompted at setup with a sensible guess.
PHOTOS_LIBRARY="$HOME/Photos/Photos Library.photoslibrary"

# Where to mount the SMB share locally, and the subfolder to export into.
MOUNT_POINT="/Volumes/osxphotos-backup"
SUB_DIR="osxphotos"               # exported photos live in $MOUNT_POINT/$SUB_DIR

# Local state: the osxphotos export database (tracks what's already exported)
# and per-run logs. These live on the local disk, NOT on the SMB share.
STATE_DIR="$HOME/osxphotos_state"
EXPORT_DB="$STATE_DIR/osxphotos_export.db"
LOG_DIR="$HOME/osxphotos_logs"

# Credentials file (owner-only) that setup writes and the sync script sources.
# This is the single source of truth for SMB username + password.
CONFIG_DIR="$HOME/.config/osxphotos-backup"
CREDS_FILE="$CONFIG_DIR/smb.conf"

# Install locations (the files this script writes and keeps up to date).
INSTALL_BIN="$HOME/.local/bin/sync-osxphotos-backup.sh"
PLIST_LABEL="com.garyjohnson.osxphotos-backup"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_LABEL.plist"
SYNC_INTERVAL_SECONDS=$((5 * 60 * 60))   # every 5 hours

# ─────────────────────────────────────────────────────────────────────────────

if [ "$(uname)" != "Darwin" ]; then
  err "This script is for macOS only"
fi

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_SYNC_SCRIPT="$DOTFILES_DIR/sync-osxphotos-backup.sh.template"

if [ ! -f "$SRC_SYNC_SCRIPT" ]; then
  err "Template not found: $SRC_SYNC_SCRIPT"
fi

# Read a single `VAR="value"` assignment back out of the installed sync script,
# so re-runs can default to what was already configured (no need to re-type).
read_back() {
  local var="$1"
  sed -n "s/^${var}=\"\(.*\)\"$/\1/p" "$INSTALL_BIN" 2>/dev/null | head -1
}

step "🔧 osxphotos + SMB backup setup"

# --- 1. Install osxphotos via pipx -------------------------------------------

step "🐍 osxphotos"

if command -v pipx >/dev/null 2>&1; then
  :
else
  info "pipx not found — installing..."
  if command -v brew >/dev/null 2>&1; then
    brew install pipx && pipx ensurepath
  else
    err "pipx missing and Homebrew not available. Install pipx first."
  fi
fi

if command -v osxphotos >/dev/null 2>&1; then
  skip "osxphotos already installed: $(osxphotos --version 2>/dev/null || true)"
else
  info "Installing osxphotos..."
  pipx install osxphotos
  success "osxphotos installed!"
fi

# --- 2. SMB server + share (prompted, defaults from prior run) --------------

step "🗄 SMB server + share"

default_server="$( [ -f "$INSTALL_BIN" ] && read_back SERVER || printf '%s' "$SERVER" )"
default_share="$( [ -f "$INSTALL_BIN" ] && read_back SHARE || printf '%s' "$SHARE" )"

prompt "SMB server (hostname or IP) [${default_server}]: "
read -r server_in
SERVER="${server_in:-$default_server}"
[ -n "$SERVER" ] || err "SMB server is required."

prompt "SMB share name [${default_share}]: "
read -r share_in
SHARE="${share_in:-$default_share}"
[ -n "$SHARE" ] || err "SMB share name is required."

success "Will export to //${SERVER}/${SHARE}/${SUB_DIR}"

# --- 3. Photos library location (prompt, with a sensible default) ------------

step "📚 Photos library"

# On re-runs, default to the library path currently baked into the installed
# script so the user can just hit Enter. First run: $HOME/Photos default.
prev_library="$( [ -f "$INSTALL_BIN" ] && read_back PHOTOS_LIBRARY || true )"
DEFAULT_LIBRARY="${prev_library:-${PHOTOS_LIBRARY}}"

prompt "Photos library path [$DEFAULT_LIBRARY]: "
read -r library_in
PHOTOS_LIBRARY="${library_in:-$DEFAULT_LIBRARY}"
[ -n "$PHOTOS_LIBRARY" ] || err "Photos library path is required."

if [ -f "$PHOTOS_LIBRARY/database/Photos.sqlite" ]; then
  success "Photos library found at $PHOTOS_LIBRARY"
else
  warn "No Photos.sqlite at $PHOTOS_LIBRARY — continuing anyway; the sync will"
  warn "verify at runtime."
fi

# --- 4. Collect / store SMB credentials in a local config file ---------------

step "🔐 SMB credentials"

mkdir -p "$CONFIG_DIR"

# Load any existing credentials so we can default to them on re-runs.
stored_user=""
stored_pass=""
if [ -f "$CREDS_FILE" ]; then
  # shellcheck disable=SC1090
  . "$CREDS_FILE"
  stored_user="${SMB_USER:-}"
  stored_pass="${SMB_PASS:-}"
fi

CHANGE_CREDS="no"
if [ -n "$stored_user" ]; then
  skip "Existing credentials on file for user '$stored_user' at $CREDS_FILE"
  prompt "Update SMB username/password? [y/N]: "
  read -r CHANGE_CREDS
fi

if [ -n "$stored_user" ] && [ "$CHANGE_CREDS" != "y" ] && [ "$CHANGE_CREDS" != "Y" ]; then
  SMB_USER="$stored_user"
  SMB_PASS="$stored_pass"
  info "Keeping existing credentials for '$SMB_USER'."
else
  prompt "SMB username [${SMB_USER:-$stored_user}]: "
  read -r username_in
  SMB_USER="${username_in:-${SMB_USER:-$stored_user}}"
  [ -n "$SMB_USER" ] || err "SMB username is required."

  prompt "SMB password (input hidden): "
  read -rs SMB_PASS
  echo
  [ -n "$SMB_PASS" ] || err "SMB password is required."

  # Write the credentials file (owner-only). Single source of truth for sync.
  umask 077
  {
    echo "SMB_USER='$(printf '%s' "$SMB_USER" | sed "s/'/'\\''/g")"
    echo "SMB_PASS='$(printf '%s' "$SMB_PASS" | sed "s/'/'\\''/g")"
  } > "$CREDS_FILE"
  chmod 600 "$CREDS_FILE"
  success "SMB credentials written to $CREDS_FILE (chmod 600)."
fi

# --- 5. Render the sync script from the template -----------------------------

step "📝 Sync script"

mkdir -p "$(dirname "$INSTALL_BIN")"

tmp_sync="$(mktemp)"
sed \
  -e "s|__SERVER__|$SERVER|g" \
  -e "s|__SHARE__|$SHARE|g" \
  -e "s|__MOUNT_POINT__|$MOUNT_POINT|g" \
  -e "s|__SUB_DIR__|$SUB_DIR|g" \
  -e "s|__PHOTOS_LIBRARY__|$PHOTOS_LIBRARY|g" \
  -e "s|__EXPORT_DB__|$EXPORT_DB|g" \
  -e "s|__STATE_DIR__|$STATE_DIR|g" \
  -e "s|__LOG_DIR__|$LOG_DIR|g" \
  -e "s|__CREDS_FILE__|$CREDS_FILE|g" \
  "$SRC_SYNC_SCRIPT" > "$tmp_sync"

if [ -f "$INSTALL_BIN" ] && cmp -s "$tmp_sync" "$INSTALL_BIN"; then
  skip "Sync script already up to date at $INSTALL_BIN"
  rm -f "$tmp_sync"
else
  mv "$tmp_sync" "$INSTALL_BIN"
  chmod +x "$INSTALL_BIN"
  success "Sync script installed/updated at $INSTALL_BIN"
fi
link "$INSTALL_BIN" "(rendered from $SRC_SYNC_SCRIPT)"

# --- 6. Render the launchd plist from the template ---------------------------

step "⏱ LaunchAgent"

mkdir -p "$(dirname "$PLIST_PATH")"
PLIST_SRC="$DOTFILES_DIR/com.garyjohnson.osxphotos-backup.plist.template"

tmp_plist="$(mktemp)"
sed \
  -e "s|__LABEL__|$PLIST_LABEL|g" \
  -e "s|__PROGRAM__|$INSTALL_BIN|g" \
  -e "s|__INTERVAL__|$SYNC_INTERVAL_SECONDS|g" \
  -e "s|__USER__|$USER|g" \
  "$PLIST_SRC" > "$tmp_plist"

if [ -f "$PLIST_PATH" ] && cmp -s "$tmp_plist" "$PLIST_PATH"; then
  skip "LaunchAgent plist already up to date at $PLIST_PATH"
  rm -f "$tmp_plist"
else
  # Unload current agent before replacing, so we can cleanly reload.
  launchctl bootout "gui/$(id -u)/$PLIST_LABEL" >/dev/null 2>&1 || true
  mv "$tmp_plist" "$PLIST_PATH"
  success "LaunchAgent plist installed/updated at $PLIST_PATH"
fi
link "$PLIST_PATH" "(rendered from $PLIST_SRC)"

# --- 7. Load / reload the agent ----------------------------------------------

step "🚀 LaunchAgent activation"

if launchctl list "$PLIST_LABEL" >/dev/null 2>&1; then
  skip "LaunchAgent '$PLIST_LABEL' already loaded."
else
  launchctl bootstrap "gui/$(id -u)" "$PLIST_PATH"
  if launchctl list "$PLIST_LABEL" >/dev/null 2>&1; then
    success "LaunchAgent loaded. It will run on an interval of $((SYNC_INTERVAL_SECONDS / 3600)) hours."
  else
    warn "LaunchAgent did not load. Try: launchctl bootstrap gui/$(id -u) $PLIST_PATH"
  fi
fi

# --- 8. First-run dry check --------------------------------------------------

step "🎬 First run"

info "All set. Triggering an immediate sync now..."
"$INSTALL_BIN"

success "Done! Watch progress with: tail -f $LOG_DIR/\$(ls -t $LOG_DIR | head -1)"
echo ""
warn "Reminder: grant Full Disk Access to the osxphotos Python binary so launchd"
warn "runs can read the Photos library. Find it with:"
info "   head -1 \$(which osxphotos)"
echo ""
