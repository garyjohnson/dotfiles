#!/usr/bin/env bash
set -euo pipefail

payload="${HERDR_PLUGIN_EVENT_JSON:?worktreeinclude-sync: missing HERDR_PLUGIN_EVENT_JSON}"
worktree_path=$(printf '%s' "$payload" | jq -r '.data.worktree.path')
main_root=$(printf '%s' "$payload" | jq -r '.data.workspace.worktree.repo_root')

if [ -z "$worktree_path" ] || [ "$worktree_path" = "null" ]; then
  echo "worktreeinclude-sync: no worktree path in event payload, skipping" >&2
  exit 0
fi

if [ -z "$main_root" ] || [ "$main_root" = "null" ]; then
  echo "worktreeinclude-sync: no repo_root in event payload, skipping" >&2
  exit 0
fi

include_file="$worktree_path/.worktreeinclude"
if [ ! -f "$include_file" ]; then
  exit 0
fi

if [ "$main_root" = "$worktree_path" ]; then
  exit 0
fi

while IFS= read -r rel || [ -n "$rel" ]; do
  rel="${rel%%$'\r'}"
  [ -z "$rel" ] && continue
  case "$rel" in \#*) continue ;; esac

  src="$main_root/$rel"
  dest="$worktree_path/$rel"

  if [ -f "$src" ] && [ ! -e "$dest" ]; then
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
    echo "worktreeinclude-sync: copied $rel into $worktree_path" >&2
  fi
done < "$include_file"
