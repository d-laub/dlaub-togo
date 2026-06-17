# Scientific Writing Skill Suite — Design

**Date:** 2026-06-17
**Status:** Approved (brainstorming complete)
**Author:** David Laub + Claude

## Purpose

A set of skills that take an LLM working inside a *code + results* project repo from
a sprawling "research cloud" to a journal-ready manuscript draft written in the
user's scientific voice. Three sequential stages, each producing a durable artifact,
with a thin orchestrator that routes between them and supports resuming mid-pipeline.

Built and maintained in the personal skills repo
`/cellar/users/dlaub/projects/dlaub-togo` (`https://github.com/d-laub/dlaub-togo`,
branch `main`). The skills *operate on* whatever consuming repo the LLM is invoked in
(e.g. `gvl-paper`); artifacts are written into that consuming repo.

## Package layout (4 skills, flat namespace)

```
dlaub-togo/skills/
  scientific-writing/            SKILL.md   # orchestrator / router (short)
  scientific-writing-story/      SKILL.md   # stage 1: fact-find + linear story
  scientific-writing-outline/    SKILL.md   # stage 2: outline + citation checks
  scientific-writing-draft/      SKILL.md   # stage 3: full draft
                                 styles/dlaub-style.md   # TDD-built style guide
```

- **Orchestrator** (`scientific-writing`): thin router. Explains the 3-stage flow,
  tells the LLM which stage skill to invoke (via the Skill tool), and checks which
  artifacts already exist in the story dir so the pipeline can resume mid-way.
- **`styles/`** is a directory so additional voices can be added/selected later;
  `dlaub-style.md` is the default and the only one built now.

## Shared artifacts

Live in the **consuming** repo at `docs/writing/<story-slug>/`:

| File | Stage | Contents |
|---|---|---|
| `story.md` | 1 | Thesis; linear narrative arc; table mapping each story beat → backing artifacts (scripts / result CSVs / plots / notebooks); explicit **Dropped / out-of-scope** list |
| `outline.md` | 2 | Header documenting journal/format choices + rationale; section scaffold for that venue; bulleted claims with pointers to backing artifacts or citations |
| `references.md` | 2 | Citation ledger: each citation → exists? content-supports-claim? verdict + source URL |
| `draft.md` | 3 | Full prose draft; citation markers + artifact pointers preserved |

`<story-slug>` is a kebab-case slug derived from the working title, confirmed with the
user in stage 1.

## Stage 1 — `scientific-writing-story` (fact-finding + linear story)

Type: technique / convergence (brainstorming-flavored).

1. **Map the research cloud.** Dispatch `Explore` subagents to survey experiments,
   scripts, `results/`, `figures/`, notebooks, git history, and CLAUDE.md. Goal: an
   inventory of parallel/abandoned threads vs. the main line.
2. **Converge with the user**, one question at a time: confirm the thesis, what
   experiments/results are *in* the story, and what ideas/experiments were *dropped*.
3. **Write `story.md`**: big-picture thesis, the linear narrative arc, a beat→artifact
   mapping table, and an explicit Dropped/out-of-scope section.

Success: a human-confirmed `story.md` whose every story beat points at concrete repo
artifacts, and whose dropped list reflects the user's actual intent.

## Stage 2 — `scientific-writing-outline` (outline + citation verification)

Type: discipline (no unbacked bullets; verify every citation) + multi-pass technique
modeled on `superpowers:executing-plans`.

1. **Confirm journal/format/setting** (e.g. Nature/Science/Cell biological articles
   vs. a CS conference vs. BMC-style software article). This selects the section
   scaffold. Record the choice + rationale in the `outline.md` header.
2. **Fill the outline in multi-pass blocks** of ~3–8 bullets (LLM infers count):
   - **implement** — write the bullets.
   - **story review** — consistent with `story.md`? Are non-result bullets backed by
     literature/citations?
   - **technical review** — are result bullets backed by repo experiments/code/plots?
     Are "magic numbers" (e.g. an RNA-seq count threshold) backed by principled
     evidence — empirical in-repo result or citation?
   - **citation web-check** — for each citation: (a) does it exist (real paper,
     authors, venue, year)? (b) does its content support the claim? Run as **parallel
     subagents** (independent, web-bound). Log verdicts to `references.md`.
3. **Final review** across the whole outline: sections/bullets coherent with each
   other, everything ties back to the thesis and `story.md`, every bullet backed by a
   validated pointer or a verified citation.
4. **Handoff** to the user, explicitly flagging ambiguities/concerns surfaced during
   self-review.

Success: an outline where every bullet is either backed by a repo pointer or a
citation verified in `references.md`, section scaffold matches the chosen venue, and
concerns are surfaced rather than buried.

## Stage 3 — `scientific-writing-draft` (full draft)

Type: implementation + style-adherence discipline; multi-pass per section.

1. **Load context**: `story.md`, `outline.md`, `references.md`, and the selected style
   (`styles/dlaub-style.md`).
2. **Draft section-by-section**, multi-pass:
   - **write** prose from the section's bullets.
   - **style review** against `dlaub-style.md`.
   - **fidelity review** — claims still backed by their `outline.md`/`references.md`
     pointers; no new unbacked claims introduced.
3. **Output `draft.md`**, preserving citation markers and artifact pointers.

Success: a draft that reads in the user's voice (passes style review against held-out
manuscript paragraphs) and introduces no claim absent from the verified outline.

## `dlaub-style.md` — built via writing-skills TDD

Sources: `text/manuscript.md` (primary, published voice) + Methods prose from
`text/supplement.md` (separate methods register).

TDD cycle:
- **RED** — a subagent writes a Results (and a Methods) paragraph from bullets
  *without* the guide. Capture concrete divergences from the real manuscript.
- **GREEN** — write `dlaub-style.md` encoding the observed tells, e.g.:
  - claim-first sentences;
  - quantify with "up to N×" + named dataset + resource budget ("64 CPUs, 16 GB RAM");
  - every Results sentence ends in a figure callout;
  - declarative, low-hedging register;
  - Background is citation-dense;
  - abbreviation discipline (define once, then use).
- **REFACTOR** — re-test the subagent *with* the guide against held-out manuscript
  paragraphs; close gaps until output is stylistically indistinguishable.

## Testing scope (Iron Law: test before deploy)

RED/GREEN per skill, rigor concentrated where it matters most:
- **Stage 2 discipline** — pressure-test "no unbacked bullet" and "verify every
  citation" (agent under time/sunk-cost pressure must not invent backing or skip the
  web-check).
- **Stage 3 style adherence** — the `dlaub-style.md` TDD loop above.
- **Stage 1 + orchestrator** — lighter application-scenario tests: can the agent map a
  research cloud and converge; does the router send work to the right stage and resume
  correctly from existing artifacts.

## Out of scope

- Submission formatting / LaTeX / journal templating.
- Reference-manager integration (Zotero/BibTeX export).
- Figure generation (figures already exist in the consuming repo).
- Rebuttal/response-to-reviewers writing (different register; excluded from style
  source).
