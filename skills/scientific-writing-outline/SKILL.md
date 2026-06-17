---
name: scientific-writing-outline
description: Use when story.md is settled and you need a venue-appropriate, fully-backed manuscript outline. Stage 2 of scientific-writing — produces outline.md + references.md, with every bullet backed by a repo pointer or a web-verified citation.
metadata:
  type: technique
---

# Scientific Writing — Stage 2: Outline

## Overview
Turn `story.md` into a bulleted outline whose every claim is backed — by a concrete repo artifact (results bullets) or a web-verified citation (background bullets). Multi-pass, modeled on `superpowers:executing-plans`. Outputs `outline.md` + `references.md` in the story dir.

**Foundational rule: no bullet without backing. Inventing a citation or a number to fill a bullet is the cardinal failure of this stage.**

## Step 0 — confirm the venue
Ask the user the target journal/format (e.g. Nature/Science/Cell biological article; CS conference; BMC-style software article). This selects the section scaffold. Record the choice + rationale in the `outline.md` header. Common scaffolds:
- Nature/Cell biological: Abstract, Intro, Results, Discussion, Methods.
- BMC software article: Background, Implementation, Results, Conclusions.
- CS conference: Abstract, Intro, Related Work, Method, Experiments, Conclusion.

## Multi-pass loop (per block of ~3–8 bullets)
1. **Implement** — write the bullets for the current section block.
2. **Story review** — consistent with `story.md`'s thesis/beats? Are non-result (background/motivation) bullets backed by literature?
3. **Technical review** — is each result bullet backed by a named repo artifact (script/result CSV/plot/notebook)? Is every "magic number" (e.g. an RNA-seq count threshold, an x-fold ratio) backed by a principled source — an in-repo empirical result or a citation? Add the pointer inline. Also name the figure panel each result bullet maps to (e.g. `Fig. 2C`) so Stage 3 can attach the callout without inventing one.
4. **Citation web-check** — for each new citation, dispatch a subagent (parallelize with `superpowers:dispatching-parallel-agents`) to verify via web: (a) does the paper exist (authors, venue, year)? (b) does its content support the specific claim? Log every verdict to `references.md`.

## Final review (whole outline)
- Sections/bullets coherent with each other; everything ties back to the thesis and `story.md`.
- Every bullet has a backing pointer (repo artifact) or a `references.md` entry marked verified.
- Then **hand off to the user**, explicitly listing any ambiguities/concerns raised during review (e.g. a number you couldn't back, a citation that only partially supports its claim).

## outline.md header template
```markdown
# Outline — <title>
Venue: <journal/format>   |   Chosen because: <rationale>   |   Scaffold: <sections>
Backing legend: [repo: <path>] | [cite: <key> ✓verified]
```

## references.md template
```markdown
| key | citation | exists? | supports claim? | claim it backs | source URL |
|-----|----------|---------|-----------------|----------------|------------|
```

## Red flags — STOP and fix
- A bullet you can't point to an artifact or verified citation for → mark UNBACKED and flag to user; do not paper over it.
- "I'll verify citations later" → verify now; that's this stage's job.
- Citing a paper from memory without the web-check → not allowed.
- Picking a section scaffold before confirming the venue → ask first.

| Rationalization | Reality |
|---|---|
| "We're behind schedule, skip the web-check" | Unverified citations are the #1 retraction risk. The check IS the work. |
| "This number is obviously right" | If it's a result, it has a repo artifact. Point to it or flag it. |
| "The reviewer will catch bad cites" | Your job is to not ship them. |

## Next stage
Once the user approves `outline.md`, invoke `scientific-writing-draft`.
