# Scientific Writing Skill Suite Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **REQUIRED BACKGROUND:** This plan builds *skills*, not application code. Each skill is built with `superpowers:writing-skills` TDD: the "failing test" is a subagent pressure/application scenario run WITHOUT the skill (RED, document baseline behavior verbatim); the "implementation" is writing the SKILL.md; the "passing test" is re-running the scenario WITH the skill (GREEN). Read `superpowers:writing-skills` before starting.

**Goal:** Build a 4-skill suite (`scientific-writing` orchestrator + `-story`, `-outline`, `-draft` stages) plus a TDD-built `dlaub-style.md` that take an LLM from a code+results repo to a journal-ready manuscript draft in the user's voice.

**Architecture:** Three sequential stage skills, each writing a durable artifact into the *consuming* repo at `docs/writing/<story-slug>/` (`story.md`, `outline.md`+`references.md`, `draft.md`). A thin orchestrator routes between them and resumes from existing artifacts. Style is a swappable reference file under the draft skill.

**Tech Stack:** Markdown skill docs in `dlaub-togo/skills/`; subagent scenarios via the Agent/Task tool (general-purpose subagents) for TDD; git for commits. No runtime code, no pytest.

---

## File Structure

| File | Responsibility |
|---|---|
| `skills/scientific-writing/SKILL.md` | Orchestrator: 3-stage flow, routing, resume-from-artifacts |
| `skills/scientific-writing-story/SKILL.md` | Stage 1: map research cloud, converge, write `story.md` |
| `skills/scientific-writing-outline/SKILL.md` | Stage 2: venue scaffold, multi-pass bulleting, citation verification |
| `skills/scientific-writing-draft/SKILL.md` | Stage 3: section-by-section prose, style + fidelity review |
| `skills/scientific-writing-draft/styles/dlaub-style.md` | The user's distilled scientific voice (TDD-built) |

**Build order:** style guide first (riskiest TDD, draft depends on it) → story → outline → draft → orchestrator last (only routes once the others exist).

**Testing convention used in every task below:** "Dispatch a subagent" = use the Agent tool with `subagent_type: general-purpose`. For RED, the subagent gets ONLY the scenario prompt. For GREEN, the subagent additionally gets the relevant SKILL.md / style file content pasted into its prompt (subagents do not auto-load skills). Record the subagent's verbatim output in the commit message or a scratch note so regressions are visible.

---

## Task 1: `dlaub-style.md` (TDD-built style guide)

**Files:**
- Create: `skills/scientific-writing-draft/styles/dlaub-style.md`
- Reference (read-only, in consuming repo `gvl-paper`): `text/manuscript.md`, `text/supplement.md`

- [ ] **Step 1: Establish ground-truth tells from the real manuscript**

Read these held-out reference paragraphs from `gvl-paper/text/manuscript.md` (Results lines 46, 48, 50; Background lines 28, 30, 32) and the Methods register in `text/supplement.md`. Note the concrete, checkable tells (used as the GREEN rubric):

1. Claim/topic-first sentences — finding stated before evidence.
2. Quantification as a range with "up to N×" (`up to 1,000 times faster`, `300-1,000x`, `190-450x`), and each headline number is paired with the **named dataset** and the **resource budget** (`64 CPUs, 16 GB RAM`).
3. Every Results claim ends with a **bold figure callout** — `(**Fig. 2C**)`, `(**Supp. Fig. 1A**)`.
4. Declarative, low-hedging voice; active (`we developed`, `GVL achieves`, `we benchmarked`). Hedging reserved for genuinely forward-looking claims (`should result in`, `may complement`).
5. Background is citation-dense (≈1 citation per claim) and follows motivation → gap → `Here, we introduce …`.
6. Abbreviations defined once in parentheses, then reused (`GenVarLoader (GVL)`, `Sparse Variant (SVAR)`).
7. Concrete cost/impact framing (`1.97 petabytes`, `$50,000 per month`).
8. Methods register (from supplement): step-ordered, tool+version explicit, reproducible imperative.

- [ ] **Step 2: RED — baseline a subagent WITHOUT the style guide**

Dispatch a subagent with ONLY this prompt:

> Write one ~120-word Results paragraph for a bioinformatics software methods paper from these bullets:
> - Benchmarked storage of personalized genomes: GVL vs two compressed FASTA files, 1000 Genomes Project.
> - GVL used 3.1 GB; FASTA used 6.3 TB.
> - Throughput: GVL vs bcftools reading FASTA, 2 kbp–1 Mbp sequence lengths, 64 CPUs and 16 GB RAM.
> - GVL was 300–1,000x faster and exceeded NVIDIA A100 input bandwidth.
> - Supporting figures: storage = Fig 2A, throughput = Fig 2C.

Record the output. **Expected RED failures** (document which occur): no/inconsistent figure callouts, hedging filler ("In order to evaluate…"), numbers not paired with dataset+resources, passive voice, ratio not framed as "up to N×".

- [ ] **Step 3: Write `dlaub-style.md`**

Write the file with this structure and content:

````markdown
---
name: dlaub-style
description: David Laub's scientific-manuscript voice for bioinformatics software/methods papers. Loaded by scientific-writing-draft when drafting prose.
metadata:
  type: reference
---

# dlaub-style — Scientific Manuscript Voice

Distilled from `manuscript.md` (published GenVarLoader paper) + `supplement.md` Methods.
Apply when drafting Background/Results/Conclusions prose and Methods.

## Core voice
- **Claim-first.** Lead each paragraph and most sentences with the finding or point; follow with evidence. Not "To test X, we did Y, and saw Z" — instead "Z (we did Y to test X)".
- **Declarative, active, low-hedging.** "We developed", "GVL achieves", "we benchmarked". Reserve hedges ("should", "may", "can be pursued") for genuinely forward-looking/speculative claims only.
- **Compact.** No throat-clearing ("It is important to note", "In order to"). Cut filler.

## Quantification (the signature tell)
- Report headline results as a **range with "up to N×"**: "up to 1,000 times faster", "300–1,000x speed-up", "190–450x", "over 2,000-fold reduction".
- **Pair every headline number with (a) the named dataset and (b) the resource budget.** e.g. "Using up to 64 CPUs and 16 GB of total RAM … on the TCGA dataset".
- Use concrete cost/scale framing where it lands: "1.97 petabytes", "$50,000 per month".

## Figure discipline (Results)
- **Every result claim ends in a bold figure callout**: `(**Fig. 2C**)`, `(**Fig. 2A**)`, `(**Supp. Fig. 1A**)`.
- One claim → one figure panel. If a claim has no figure, it is probably not a Results claim.

## Background
- Citation-dense: ≈one citation per factual claim.
- Arc: prior work/motivation → the gap/limitation → "Here, we introduce **<Tool>** (<TLA>), which …".

## Abbreviations
- Define once at first use in parentheses: "GenVarLoader (GVL)", "Sparse Variant (SVAR) format", "whole genome sequencing (WGS)". Reuse the short form thereafter.

## Methods register (from supplement)
- Step-ordered and reproducible; name tools **with versions/flags**; imperative/past-tense procedure ("We converted VCFs to SVAR using …").

## Quick checklist before finishing a paragraph
- [ ] Does it lead with the claim?
- [ ] Is every headline number a range tied to a dataset + resource budget?
- [ ] Does every Results sentence end in a bold figure callout?
- [ ] Any hedging that isn't forward-looking? Cut it.
- [ ] First use of each abbreviation defined?
````

- [ ] **Step 4: GREEN — re-run the scenario WITH the guide**

Dispatch a fresh subagent with the Step 2 prompt PLUS the full `dlaub-style.md` content pasted in and the instruction "Follow dlaub-style.md." Verify the output now: leads with claims, frames the ratio as "300–1,000x", pairs numbers with dataset+resources, ends throughput/storage sentences with `(**Fig. 2C**)`/`(**Fig. 2A**)`, no hedging filler. If a tell is missing, add an explicit rule/example to the guide and re-run.

- [ ] **Step 5: Commit**

```bash
cd /cellar/users/dlaub/projects/dlaub-togo
git add skills/scientific-writing-draft/styles/dlaub-style.md
git commit -m "feat(scientific-writing): TDD-built dlaub-style guide"
```

---

## Task 2: `scientific-writing-story` (Stage 1)

**Files:**
- Create: `skills/scientific-writing-story/SKILL.md`

- [ ] **Step 1: RED — baseline WITHOUT the skill**

Dispatch a subagent with ONLY:

> You are in a research repo (`gvl-paper`) that benchmarks a dataloader. It contains parallel/abandoned experiment dirs (e.g. `bin_gvl061`, `bin_gvl027`, an abandoned "buffered" mode). Produce a `story.md` that captures the paper's single linear story.

**Expected RED failures** (document): jumps straight to writing without inventorying the repo or distinguishing kept vs. dropped experiments; invents a thesis without user confirmation; no beat→artifact mapping; treats abandoned threads as part of the story.

- [ ] **Step 2: Write `scientific-writing-story/SKILL.md`**

````markdown
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
````

- [ ] **Step 3: GREEN — verify WITH the skill**

Dispatch a subagent with the Step 1 prompt PLUS the SKILL.md content. Verify it now: proposes dispatching Explore agents to inventory first, asks the user to confirm thesis + in/out split before writing, and the `story.md` it sketches includes the beat→artifact table and a Dropped section. If it still skips the mapping or invents a thesis, strengthen the "Red flags — STOP" section and re-run.

- [ ] **Step 4: Commit**

```bash
cd /cellar/users/dlaub/projects/dlaub-togo
git add skills/scientific-writing-story/SKILL.md
git commit -m "feat(scientific-writing): stage 1 story skill"
```

---

## Task 3: `scientific-writing-outline` (Stage 2)

**Files:**
- Create: `skills/scientific-writing-outline/SKILL.md`

- [ ] **Step 1: RED — baseline the discipline WITHOUT the skill (under pressure)**

Dispatch a subagent with ONLY:

> Here is `story.md` for a dataloader paper [paste a 6-line story stub with a thesis + 3 beats, one beat citing "we are ~1000x faster" and one non-result claim "FASTA storage of personal genomes is the standard approach"]. We're behind schedule — quickly produce an outline.md of Results bullets for a Nature Methods submission, including the relevant background citations.

**Expected RED failures** (document): invents citations or asserts the "1000x" number without pointing at a repo artifact; produces bullets with no backing pointers; does not web-verify citations; uses Nature `Intro/Results/Discussion` or a generic scaffold without confirming the venue.

- [ ] **Step 2: Write `scientific-writing-outline/SKILL.md`**

````markdown
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
3. **Technical review** — is each result bullet backed by a named repo artifact (script/result CSV/plot/notebook)? Is every "magic number" (e.g. an RNA-seq count threshold, an x-fold ratio) backed by a principled source — an in-repo empirical result or a citation? Add the pointer inline.
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
````

- [ ] **Step 3: GREEN — verify WITH the skill (re-run under the same pressure)**

Dispatch a subagent with the Step 1 prompt PLUS the SKILL.md content. Verify it now: asks/states the venue scaffold before bulleting, attaches a repo-pointer to the "1000x" result bullet (or flags it UNBACKED), refuses to assert citations without a web-check (proposes verification subagents + a `references.md` entry), and surfaces unbacked items to the user instead of inventing backing. If it still invents a citation or skips verification under the schedule pressure, add the specific rationalization to the table and re-run.

- [ ] **Step 4: Commit**

```bash
cd /cellar/users/dlaub/projects/dlaub-togo
git add skills/scientific-writing-outline/SKILL.md
git commit -m "feat(scientific-writing): stage 2 outline skill"
```

---

## Task 4: `scientific-writing-draft` (Stage 3)

**Files:**
- Create: `skills/scientific-writing-draft/SKILL.md`
- (Already present from Task 1: `skills/scientific-writing-draft/styles/dlaub-style.md`)

- [ ] **Step 1: RED — baseline WITHOUT the skill**

Dispatch a subagent with ONLY:

> Here is a Results section block from `outline.md` [paste 4 backed bullets: storage 3.1GB vs 6.3TB on 1000 Genomes (Fig 2A); throughput 300–1000x vs bcftools, 64 CPUs/16GB, 2kbp–1Mbp (Fig 2C); each bullet tagged with its repo pointer]. Write the Results prose.

**Expected RED failures** (document): generic academic voice (passive, hedged, throat-clearing); drops the figure callouts; doesn't frame ratios as "up to N×"; doesn't pair numbers with dataset+resources; may introduce a claim not in the bullets.

- [ ] **Step 2: Write `scientific-writing-draft/SKILL.md`**

````markdown
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
````

- [ ] **Step 3: GREEN — verify WITH the skill + style guide**

Dispatch a subagent with the Step 1 prompt PLUS both `SKILL.md` and `dlaub-style.md`. Verify the prose: claim-first, "300–1,000x" framing, numbers paired with 1000 Genomes + 64 CPUs/16 GB, every sentence ends in `(**Fig. 2A**)`/`(**Fig. 2C**)`, no invented claims. If style isn't reached, confirm whether the gap is in the style guide (fix Task 1) or the draft skill's review step.

- [ ] **Step 4: Commit**

```bash
cd /cellar/users/dlaub/projects/dlaub-togo
git add skills/scientific-writing-draft/SKILL.md
git commit -m "feat(scientific-writing): stage 3 draft skill"
```

---

## Task 5: `scientific-writing` (orchestrator) + integration check

**Files:**
- Create: `skills/scientific-writing/SKILL.md`

- [ ] **Step 1: RED — routing/resume scenario WITHOUT the orchestrator**

Dispatch a subagent with ONLY:

> A repo has `docs/writing/gvl-paper/story.md` already written but no `outline.md`. The user says "let's keep working on my paper." What do you do?

**Expected RED failure** (document): no awareness of a staged pipeline; may restart from scratch, re-do the story, or guess; doesn't detect that stage 1 is done and stage 2 is next.

- [ ] **Step 2: Write `scientific-writing/SKILL.md`**

````markdown
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
   - `story.md` but no approved `outline.md` → invoke `scientific-writing-outline`.
   - `outline.md` but no `draft.md` → invoke `scientific-writing-draft`.
3. If the user names a stage explicitly, honor that.
4. Confirm the target story dir with the user when more than one exists.

Always announce which stage you're entering and why before invoking it.
````

- [ ] **Step 3: GREEN — verify routing WITH the orchestrator**

Dispatch a subagent with the Step 1 prompt PLUS the orchestrator SKILL.md. Verify: it detects `story.md` exists and `outline.md` does not, announces "Stage 1 done, entering Stage 2", and invokes `scientific-writing-outline` rather than restarting. If it still restarts, sharpen the Routing steps and re-run.

- [ ] **Step 4: Integration consistency check (no subagent)**

Verify cross-references resolve and names match exactly across all five files:
- Orchestrator's stage table names match the three skill `name:` fields.
- Stage 1 "Next stage" points to `scientific-writing-outline`; Stage 2 → `scientific-writing-draft`.
- Artifact filenames (`story.md`, `outline.md`, `references.md`, `draft.md`) are identical everywhere.
- `scientific-writing-draft` references `styles/dlaub-style.md` and the file exists.

Fix any mismatch inline.

- [ ] **Step 5: Commit**

```bash
cd /cellar/users/dlaub/projects/dlaub-togo
git add skills/scientific-writing/SKILL.md
git commit -m "feat(scientific-writing): orchestrator + cross-skill integration"
```

---

## Task 6: Push

- [ ] **Step 1: Push to main**

```bash
cd /cellar/users/dlaub/projects/dlaub-togo
git push origin main
```

- [ ] **Step 2: Report** the five new files and a one-line summary of each TDD RED→GREEN result to the user.

---

## Self-Review (completed by plan author)

**Spec coverage:** ✓ all 4 skills + style guide (spec §"Package layout"), all 4 artifacts (§"Shared artifacts"), all 3 stage behaviors, the dlaub-style TDD cycle, and the testing-scope priorities (stage-2 discipline + stage-3 style get pressure tests; stage-1 + orchestrator get application tests). Style sources = manuscript.md + supplement Methods ✓. Citation ledger = references.md ✓. Out-of-scope items are not built ✓.

**Placeholder scan:** No "TBD"/"implement later". Subagent prompts and full SKILL.md bodies are inlined. The one bracketed item ("paste a 6-line story stub" / "paste 4 backed bullets") is a deliberate instruction to the executor to construct a realistic fixture from the story stub, not a content gap.

**Name consistency:** Skill names `scientific-writing`, `scientific-writing-story`, `scientific-writing-outline`, `scientific-writing-draft`, and `dlaub-style` are used identically in frontmatter, the orchestrator table, cross-references, and commit messages. Artifact names consistent across tasks. Task 5 Step 4 explicitly re-checks this.
