#!/usr/bin/env bash
#
# photos-logs.sh
#
# Tail the osxphotos → SMB backup logs. Defaults to following the most recent
# sync log live (tail -f).
#
#   photos-logs.sh          # follow the latest sync log live
#   photos-logs.sh -n 200   # show last 200 lines (no follow)
#   photos-logs.sh -l       # the launchd log instead of the latest sync log
#   photos-logs.sh -h       # help
#
set -euo pipefail

LOG_DIR="$HOME/osxphotos_logs"
MODE="sync"      # 'sync' | 'launchd'
FOLLOW=1         # default: follow live
LINES="50"       # used only when not following

usage() {
  cat <<EOF
Usage: photos-logs.sh [options]

Tail the osxphotos backup logs. By default, follows the most recent sync log
live (tail -f).

Options:
  -n <num>      Show the last <num> lines, no follow (default 50)
  -l            Tail the launchd log instead of the latest sync log
  -f            Follow live (the default)
  -h, --help    Show this help
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    -l)               MODE="launchd"; shift ;;
    -n)               LINES="$2"; FOLLOW=0; shift 2 ;;
    -f)               FOLLOW=1; shift ;;
    -h|--help)        usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [ ! -d "$LOG_DIR" ]; then
  echo "No log directory yet: $LOG_DIR (run the setup script first)" >&2
  exit 1
fi

if [ "$MODE" = "launchd" ]; then
  TARGET="$LOG_DIR/launchd.log"
  [ -f "$TARGET" ] || { echo "No launchd log yet: $TARGET" >&2; exit 1; }
else
  TARGET="$(ls -t "$LOG_DIR"/sync-*.log 2>/dev/null | head -1 || true)"
  if [ -z "$TARGET" ]; then
    echo "No sync logs found in $LOG_DIR" >&2
    exit 1
  fi
fi

if [ "$FOLLOW" -eq 1 ]; then
  echo "Following: $(basename "$TARGET")"
  tail -f "$TARGET"
else
  echo "==> $(basename "$TARGET") <=="
  tail -n "$LINES" "$TARGET"
fi
