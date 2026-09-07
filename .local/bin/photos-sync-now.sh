#!/usr/bin/env bash
#
# photos-sync-now.sh
#
# Trigger an immediate osxphotos → SMB backup sync. Uses `launchctl kickstart`
# on the already-loaded LaunchAgent, so the manual run is the SAME
# launchd-managed job as the scheduled one. launchd never runs two instances
# of a single label → no overlap with a scheduled run, no lockfile needed.
#
# If a run is already in progress, this does nothing (and tells you).
#
#   photos-sync-now.sh       # kick off a sync now (if not already running)
#   photos-sync-now.sh -h    # help
#
set -euo pipefail

LABEL="com.garyjohnson.osxphotos-backup"
TARGET="gui/$(id -u)/$LABEL"

usage() {
  cat <<EOF
Usage: photos-sync-now.sh

Trigger an immediate osxphotos backup sync via launchd. Uses launchctl
kickstart on the loaded LaunchAgent, so it's the same single launchd-managed
job as the scheduled runs — no overlap, no lockfile. Does nothing if a run is
already in progress.
EOF
}

[ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] && { usage; exit 0; }

# launchctl list prints: PID<tab>Status<tab>Label. PID is "-" when not running.
line="$(launchctl list | awk -v l="$LABEL" '$3==l')"
if [ -z "$line" ]; then
  echo "LaunchAgent '$LABEL' is not loaded. Run the setup script first." >&2
  exit 1
fi

pid="$(printf '%s' "$line" | awk '{print $1}')"
if [ "$pid" != "-" ]; then
  echo "sync already running (PID $pid) — not starting another. Watch: photos-logs.sh"
  exit 0
fi

launchctl kickstart "$TARGET"
echo "sync kicked off. Watch it live: photos-logs.sh"
