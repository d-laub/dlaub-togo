---
name: scientific-writing
description: Use when writing or continuing a scientific manuscript/paper from a code+results repository — the entry point that routes through fact-finding (story), outlining, and drafting. Use when the user says "write/work on my paper/manuscript".
metadata:
  type: technique
---

# Scientific Writing (orchestrator)

## Overview
A three-stage pipeline from a code+results repo to a manuscript draft. Each stage owns a skill and a durable artifact under `docs/writing/<story-slug>/` in the consuming repo. This skill routes to the right stage and resumes from whatever artifacts already exist.

## Stages
| Stage | Skill | Reads | Writes |
|------|-------|-------|--------|
| 1. Story | `scientific-writing-story` | the repo | `story.md` |
| 2. Outline | `scientific-writing-outline` | `story.md` | `outline.md`, `references.md` |
| 3. Draft | `scientific-writing-draft` | `outline.md`, `references.md`, `story.md`, style guide | `draft.md` |

## Routing
1. Look in `docs/writing/*/` for existing artifacts.
2. Resume at the first incomplete stage:
   - no `story.md` → invoke `scientific-writing-story`.
   - `story.md` but no `outline.md` → invoke `scientific-writing-outline`.
   - `outline.md` but no `draft.md` → invoke `scientific-writing-draft`.
   - `draft.md` already exists → all stages complete; ask the user whether to revise `draft.md` (re-enter `scientific-writing-draft`) or stop.
3. If the user names a stage explicitly, honor that.
4. Confirm the target story dir with the user when more than one exists.

Approval is the user's verbal confirmation in the conversation, not an on-disk marker. Artifact *existence* drives which stage you resume at; *approval* gates advancing from one stage to the next (each stage skill ends with "once the user approves, invoke the next stage").

Always announce which stage you're entering and why before invoking it.
