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

## Section structure — Steps 3–12
This stage is Steps 3–12 of the fifteen steps (detail: `scientific-writing/fifteen-steps.md`). Build every section from **lists first, prose never**, and give each section its required shape:
- **Methods (Steps 3–5).** A numbered method list, one per line mirroring the code, each with a *to-clause* rationale ("*To estimate richness*, rarefaction was performed"). Every method leads to a result; every result traces to a method.
- **Results (Step 5).** One observation/measurement/statistic per bullet, clear and unembellished — each backed by a repo artifact + figure panel (the loop already enforces this).
- **Introduction (Step 6 — CARS).** The first three paragraphs are the three moves, in order: **Territory** (general context, centrality, prior work) → **Niche** (the gap — what existing knowledge lacks) → **Occupy** (a clear objectives/hypotheses statement linking to methods and results).
- **Discussion (Steps 7–9).** Two halves. First half = **findings**: results placed in interpretive context, each tied to a problem raised in the Introduction (**findings ≠ results**). Second half = **problem→response pairs**: list caveats/limitations/objections (Step 8), each with **one** paired response (Step 9, 1:1). Do not dump caveats as a flat "limitations" list.
- **Closing paragraph (Step 10).** Give it its own thesis, connected to the main one. **End on a positive note; never end on a caveat or "need for further research."** Close on a declaration of the main finding, a new question, or a concrete application.

**Purpose statements (Step 11).** Give *every planned paragraph* a one-line purpose statement naming its role in advancing the thesis (e.g. "This paragraph justifies the Cormack–Jolly–Seber model over band recovery"). These carry into the draft as topic-sentence seeds — record one per planned paragraph in `outline.md`.

**Figures (Step 12).** Order figures by the narrative arc; cut any that doesn't illuminate the thesis. Each caption's topic sentence is a *complete sentence* readable as the figure's title (not a label), and the sequence of caption topic sentences should read as an abbreviation of the whole narrative.

## Multi-pass loop (per block of ~3–8 bullets)
1. **Implement** — write the bullets for the current section block.
2. **Story review** — consistent with `story.md`'s thesis/beats? Are non-result (background/motivation) bullets backed by literature?
3. **Technical review** — is each result bullet backed by a named repo artifact (script/result CSV/plot/notebook)? Is every "magic number" (e.g. an RNA-seq count threshold, an x-fold ratio) backed by a principled source — an in-repo empirical result or a citation? Add the pointer inline. Also name the figure panel each result bullet maps to (e.g. `Fig. 2C`) so Stage 3 can attach the callout without inventing one.
4. **Citation web-check** — for each new citation, dispatch a subagent (parallelize with `superpowers:dispatching-parallel-agents`) to verify via web: (a) does the paper exist (authors, venue, year)? (b) does its content support the specific claim? Log every verdict to `references.md`.

## Final review (whole outline)
- Sections/bullets coherent with each other; everything ties back to the thesis and `story.md`.
- Every bullet has a backing pointer (repo artifact) or a `references.md` entry marked verified.
- **Connector test (Step 7):** put the results list beside the findings list and draw a line from each result to the finding it supports. No result may lead to no finding, and no finding may be unsupported by a result — fix any unconnected item by adding the missing partner, connecting it, or cutting it.
- Every planned paragraph has a purpose statement (Step 11); the Introduction's first three paragraphs are the three CARS moves; the Discussion is findings then problem→response pairs.
- Then **hand off to the user**, explicitly listing any ambiguities/concerns raised during review (e.g. a number you couldn't back, a citation that only partially supports its claim).

## outline.md header template
```markdown
# Outline — <title>
Venue: <journal/format>   |   Chosen because: <rationale>   |   Scaffold: <sections>
Backing legend: [repo: <path>] | [cite: <key> ✓verified]

## <Section>
**Purpose (¶1): <one-line Step-11 purpose statement>**
- <bullet>  [repo: <path> → Fig. 2C] | [cite: <key> ✓verified]
**Purpose (¶2): <…>**
- <bullet> …
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
