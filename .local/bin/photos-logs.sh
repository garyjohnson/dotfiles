#!/usr/bin/env bash
#
# photos-logs.sh
#
# Tail the osxphotos → SMB backup logs. Defaults to the most recent sync log.
#
#   photos-logs.sh          # tail -f the latest sync log
#   photos-logs.sh -n 200   # last 200 lines (with follow via -f)
#   photos-logs.sh -l       # tail the launchd log instead
#   photos-logs.sh -h       # help
#
set -euo pipefail

LOG_DIR="$HOME/osxphotos_logs"
MODE="sync"      # 'sync' | 'launchd'
FOLLOW=""        # set when -f passed
LINES="50"       # default tail line count (ignored when following)

usage() {
  cat <<EOF
Usage: photos-logs.sh [options]

Tail the osxphotos backup logs.

Options:
  -l            Tail the launchd log instead of the latest sync log
  -n <num>      Show the last <num> lines (default 50; for use without -f)
  -f            Follow the log live (tail -f)
  -h, --help    Show this help
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    -l)               MODE="launchd"; shift ;;
    -n)               LINES="$2"; shift 2 ;;
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

if [ -n "$FOLLOW" ]; then
  echo "Following: $(basename "$TARGET")"
  tail -f "$TARGET"
else
  echo "==> $(basename "$TARGET") <=="
  tail -n "$LINES" "$TARGET"
fi
