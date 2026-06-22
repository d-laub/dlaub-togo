---
name: scientific-writing-draft
description: Use when outline.md is approved and you need full manuscript prose in the user's voice. Stage 3 of scientific-writing — produces draft.md from the outline, then enforces the style guide in a separate final pass.
metadata:
  type: technique
---

# Scientific Writing — Stage 3: Draft

## Overview
Turn the approved `outline.md` into full prose, then enforce the style guide in a separate pass. Two phases:
1. **Draft** — section-by-section prose from the outline, in the user's voice. Content fidelity is the priority.
2. **Style correction** — a dedicated subagent re-reads the full style guide with fresh context and corrects the whole draft.

Why split them: during a long drafting conversation the style guide drifts out of context and its rules stop being applied. A final subagent whose only context is the style guide + the draft applies the guide cleanly.

**Every sentence traces to an outline bullet — drafting does not introduce new claims.**

## Load context first
Read: `story.md`, `outline.md`, `references.md`, and the selected style guide.
Default style: `styles/dlaub-style.md` (this skill's directory). If multiple styles exist in `styles/`, ask the user which to use. Record the chosen guide's path — Phase 2 needs it.

## Phase 1 — Draft (per section)
1. **Write** prose for the section from its `outline.md` bullets, in the voice of the selected style guide.
2. **Fidelity review** — every claim still traces to an `outline.md` bullet and its backing pointer/`references.md` entry. No new unbacked claims, no dropped figure callouts, no altered numbers.
3. Next section.

Write `draft.md` in the story dir. Do not run the full style checklist here — that is Phase 2's job. A rough-but-faithful draft is the correct Phase 1 output.

## Phase 2 — Style correction (dedicated subagent)
After the complete draft exists, dispatch ONE subagent whose only context is the style guide and the draft. This is required, not optional: do not hand-polish style inline in this conversation, because the guide has already drifted out of context here.

Dispatch a subagent with this task:

> Read `<path-to-selected-style-guide>` in full, then read `<story-dir>/draft.md`.
> Apply every rule in the style guide to the entire draft, working its end-of-guide checklist paragraph by paragraph.
> Make **style-only** edits, in place in `draft.md`:
> - Do NOT add, remove, or alter any claim.
> - Do NOT change any number, citation marker, or figure callout (text or position).
> - Do NOT change section structure or headings.
> Return a short list of the categories of change you made (e.g. "removed 6 em-dashes, de-hedged 4 sentences, fixed 2 repeated figure callouts").

When the subagent returns, skim its change list and spot-check that no numbers or callouts moved.

## Output
- `draft.md` with citation markers and figure callouts preserved exactly as in the outline.
- After Phase 2: a short handoff noting any spots where the outline was thin and prose had to stretch, plus the subagent's style-change summary.

## Red flags — STOP
- A sentence with a claim not in `outline.md` → remove it or send the claim back to Stage 2.
- A number changed from the outline → revert; outline numbers are the source of truth.
- Skipping the Phase 2 subagent and hand-styling inline → the style guide has drifted out of context; dispatch the subagent.
- The style subagent changed a number, citation, or figure callout → revert that edit; the pass is style-only.

## Done
Hand `draft.md` to the user for review.
