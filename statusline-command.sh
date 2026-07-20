#!/usr/bin/env bash
input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name')
DIR=$(echo "$input" | jq -r '.workspace.current_dir')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')

CYAN='\033[36m'; GREEN='\033[32m'; YELLOW='\033[33m'; RED='\033[31m'; RESET='\033[0m'

# Pick bar color based on context usage
if [ "$PCT" -ge 90 ]; then BAR_COLOR="$RED"
elif [ "$PCT" -ge 70 ]; then BAR_COLOR="$YELLOW"
else BAR_COLOR="$GREEN"; fi

FILLED=$((PCT / 10)); EMPTY=$((10 - FILLED))
printf -v FILL "%${FILLED}s"; printf -v PAD "%${EMPTY}s"
BAR="${FILL// /█}${PAD// /░}"

MINS=$((DURATION_MS / 60000)); SECS=$(((DURATION_MS % 60000) / 1000))

BRANCH=""
GIT_DIR=$(git rev-parse --git-dir 2>/dev/null)
if [ -n "$GIT_DIR" ] && [[ "$GIT_DIR" == */worktrees/* ]]; then
  # Linked git worktree: its branch is authoritative. jj would resolve up to the
  # parent (colocated) repo and print stale, unrelated bookmarks, so skip jj here.
  BRANCH=" | 🌿 $(git branch --show-current 2>/dev/null)"
elif jj root --ignore-working-copy > /dev/null 2>&1; then
  # jj repo (colocated repos also have .git, so jj is checked before plain git).
  # --ignore-working-copy keeps the frequent statusline render read-only (no
  # snapshot/mutation). 🥢 distinguishes jj from git's 🌿. local_bookmarks drops
  # remote-tracking noise (e.g. main@origin). Prefer a local bookmark on @; else
  # the nearest ancestor bookmark plus short change id (bookmark@changeid); else
  # just the change id.
  NAME=$(jj log --no-graph --ignore-working-copy -r @ -T local_bookmarks 2>/dev/null | head -1)
  if [ -z "$NAME" ]; then
    CID=$(jj log --no-graph --ignore-working-copy -r @ -T 'change_id.shortest(8)' 2>/dev/null)
    NEAR=$(jj log --no-graph --ignore-working-copy -r 'heads(::@ & bookmarks())' -T local_bookmarks 2>/dev/null | head -1)
    if [ -n "$NEAR" ]; then NAME="$NEAR@$CID"; else NAME=$CID; fi
  fi
  BRANCH=" | 🥢 $NAME"
elif [ -n "$GIT_DIR" ]; then
  BRANCH=" | 🌿 $(git branch --show-current 2>/dev/null)"
fi

echo -e "${CYAN}[$MODEL]${RESET} 📁 ${DIR##*/}$BRANCH"
echo -e "${BAR_COLOR}${BAR}${RESET} ${PCT}% | ⏱️ ${MINS}m ${SECS}s"
