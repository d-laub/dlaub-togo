#!/usr/bin/env bash

set -euo pipefail

# LLM global instructions: idempotently sync global_claude.md into ~/.claude/CLAUDE.md
# Resolve global_claude.md relative to this script so it works from any cwd.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_MD="${HOME}/.claude/CLAUDE.md"
mkdir -p "${HOME}/.claude"
touch "${CLAUDE_MD}"
# strip any previously-synced block (inclusive of markers), then append the current one
awk '/<!-- BEGIN dlaub-togo:global_claude.md -->/{skip=1} !skip; /<!-- END dlaub-togo:global_claude.md -->/{skip=0}' "${CLAUDE_MD}" > "${CLAUDE_MD}.tmp"
cat "${SCRIPT_DIR}/global_claude.md" >> "${CLAUDE_MD}.tmp"
mv "${CLAUDE_MD}.tmp" "${CLAUDE_MD}"
