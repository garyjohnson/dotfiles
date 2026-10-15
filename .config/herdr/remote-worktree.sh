#!/bin/zsh
# Open a worktree for a remote branch, tracking origin/<branch>.
# If a worktree already has the branch checked out, focus/reopen it instead.

fail() { print -u2 "\n$1"; read -k1 "?Press any key to close…"; exit 1; }

read "b?Remote branch: "
b="${b#origin/}"                 # tolerate pasting "origin/foo"
b="${b// /}"
[[ -z "$b" ]] && exit 0

# Existing worktree for this branch? Match on branch, not folder name.
existing=$(git worktree list --porcelain | awk -v ref="branch refs/heads/$b" '
  /^worktree / { path = substr($0, 10) }
  $0 == ref    { print path; exit }')

if [[ -n "$existing" ]]; then
  herdr worktree open --path "$existing" --focus >/dev/null || fail "Failed to open $existing"
  exit 0
fi

git fetch origin "$b" || fail "Couldn't fetch origin/$b. Check the branch name."

# A local branch with no worktree gets checked out as-is (herdr ignores --base),
# so make sure it tracks origin/<branch>.
if git show-ref --verify --quiet "refs/heads/$b"; then
  git rev-parse --abbrev-ref "$b@{upstream}" >/dev/null 2>&1 \
    || git branch --set-upstream-to="origin/$b" "$b" >/dev/null
fi

# herdr fails if the target directory already exists (e.g. left behind after the
# worktree was removed), so pick the path ourselves and deal with leftovers.
git worktree prune
repo=$(basename "$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")")
wt_path="$HOME/.herdr/worktrees/$repo/${(L)b//\//-}"   # herdr lowercases + replaces /

if [[ -e "$wt_path" ]]; then
  # Still a registered worktree (on some other branch)? Just open it.
  live=$(git worktree list --porcelain | grep -Fxi "worktree $wt_path")
  if [[ -n "$live" ]]; then
    herdr worktree open --path "${live#worktree }" --focus >/dev/null \
      || fail "Failed to open ${live#worktree }"
    exit 0
  fi

  print "\n$wt_path already exists (leftover, not a worktree)."
  read -k1 "choice?[r]emove it, [s]uffix new path, [c]ancel: "; print
  case "$choice" in
    r|R) rm -rf "$wt_path" || fail "Couldn't remove $wt_path" ;;
    s|S) n=2; while [[ -e "$wt_path-$n" ]]; do (( n++ )); done; wt_path="$wt_path-$n" ;;
    *)   exit 0 ;;
  esac
fi

herdr worktree create --branch "$b" --base "origin/$b" --path "$wt_path" --focus >/dev/null \
  || fail "herdr worktree create failed for $b"
