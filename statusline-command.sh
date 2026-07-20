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
if jj root --ignore-working-copy > /dev/null 2>&1; then
  # jj takes priority: colocated repos also have .git. --ignore-working-copy
  # keeps the frequent statusline render read-only (no snapshot/mutation).
  # Show the nearest ancestor bookmark (git-branch analog), else short change id.
  NAME=$(jj log --no-graph --ignore-working-copy -r 'heads(::@ & bookmarks())' -T bookmarks 2>/dev/null | head -1)
  [ -z "$NAME" ] && NAME=$(jj log --no-graph --ignore-working-copy -r @ -T 'change_id.shortest(8)' 2>/dev/null)
  BRANCH=" | 🌿 $NAME"
elif git rev-parse --git-dir > /dev/null 2>&1; then
  BRANCH=" | 🌿 $(git branch --show-current 2>/dev/null)"
fi

echo -e "${CYAN}[$MODEL]${RESET} 📁 ${DIR##*/}$BRANCH"
echo -e "${BAR_COLOR}${BAR}${RESET} ${PCT}% | ⏱️ ${MINS}m ${SECS}s"
