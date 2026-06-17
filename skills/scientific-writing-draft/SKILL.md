---
name: scientific-writing-draft
description: Use when outline.md is approved and you need full manuscript prose in the user's voice. Stage 3 of scientific-writing — drafts section-by-section against a selected style guide with fidelity review, producing draft.md.
metadata:
  type: technique
---

# Scientific Writing — Stage 3: Draft

## Overview
Turn the approved `outline.md` into full prose in the user's voice. Section-by-section, multi-pass. Output `draft.md` in the story dir. **Every sentence traces to an outline bullet — drafting does not introduce new claims.**

## Load context first
Read: `story.md`, `outline.md`, `references.md`, and the selected style guide.
Default style: `styles/dlaub-style.md` (this skill's directory). If multiple styles exist in `styles/`, ask the user which to use.

## Multi-pass loop (per section)
1. **Write** prose for the section from its `outline.md` bullets, applying the style guide.
2. **Style review** — check the draft against the style guide's checklist (for dlaub-style: claim-first; ranges as "up to N×" tied to dataset+resources; every Results sentence ends in a bold figure callout; no non-forward-looking hedging; abbreviations defined once).
3. **Fidelity review** — every claim still traces to an `outline.md` bullet and its backing pointer/`references.md` entry. No new unbacked claims, no dropped figure callouts, no altered numbers.
4. Next section.

## Output
- `draft.md` with citation markers and figure callouts preserved exactly as in the outline.
- After all sections: a short handoff noting any spots where the outline was thin and prose had to stretch.

## Red flags — STOP
- A sentence with a claim not in `outline.md` → remove it or send the claim back to Stage 2.
- A number changed from the outline → revert; outline numbers are the source of truth.
- Generic/hedged voice → re-run style review against the guide.

## Done
Hand `draft.md` to the user for review.
