---
name: scientific-writing-story
description: Use when starting a scientific manuscript from a code+results repo and you need to separate the real paper from the "research cloud" of parallel/abandoned experiments. Stage 1 of scientific-writing — produces story.md.
metadata:
  type: technique
---

# Scientific Writing — Stage 1: Find the Story

## Overview
A research repo accumulates parallel and abandoned experiments. Before any outline or prose, establish ONE linear story: the thesis, the experiments that support it, and an explicit record of what was dropped. Output: `docs/writing/<story-slug>/story.md` in the consuming repo.

**Do not write the story from your own assumptions. Map the repo, then converge with the user.**

## Method backbone — Steps 1–2
This stage is Steps 1–2 of the fifteen steps (detail: `scientific-writing/fifteen-steps.md`):
- **Step 1 — main point.** The thesis is *one short declarative sentence* (subject + verb) that scopes the phenomenon and gives focus. Every later paragraph must illuminate it. It need not become the final title.
- **Step 2 — narrative arc.** The arc answers *what did we want to learn, why, what did we do, what do we know now*, and follows the key transitions (question→answer, theory→evidence, data→interpretation). **Prefer a two-part structure** — the most memorable and publishable shape. Confirm which two-part scheme fits when you converge with the user (e.g. experiment 1 + experiment 2; simple model + complicated model; experiment + model to explain it; model + experiment to test it; observed pattern + model to explain it).

## Process

1. **Map the research cloud.** Dispatch `Explore` subagents (read-only) to inventory:
   experiments/scripts, `results/`, `figures/`, notebooks, git log, and CLAUDE.md.
   Use `superpowers:dispatching-parallel-agents` if there are independent areas.
   Goal: a list of every experiment/result thread, each tagged *candidate-main* vs *possibly-dropped*.
2. **Converge with the user, ONE question at a time.** Confirm: the working title, the single thesis, which threads are IN, which are DROPPED. Prefer multiple-choice. Do not proceed to writing until the user confirms the thesis and the in/out split.
3. **Write `story.md`** (template below).

## story.md template
```markdown
# <Working title>
slug: <kebab-case-slug>

## Thesis
<one or two sentences — the single claim the paper makes>

## Narrative arc (linear)
Two-part scheme: <which Step-2 scheme, e.g. "experiment + model to explain it">
1. <beat> 2. <beat> 3. <beat> …  (the logical order the paper will argue in)

## Beat → artifacts
| Beat | Supporting artifacts (scripts / results / plots / notebooks) |
|------|------|
| <beat> | `path/to/script.py`, `results/x.csv`, `figures/y.svg` |

## Dropped / out of scope
- <thread> — why dropped (user-confirmed)
```

## Red flags — STOP
- Writing `story.md` before mapping the repo → map first.
- Asserting a thesis the user hasn't confirmed → ask.
- A beat with no backing artifact → either find it or it's not a beat.
- An abandoned experiment silently included → it goes in Dropped.

## Next stage
Once the user approves `story.md`, invoke `scientific-writing-outline`.
