# Autoresearch Subagent Model Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure the `autoresearch-setup` skill so the experiment loop runs as a main orchestrator that dispatches one batch subagent per iteration, keeping main-session context at O(n × ~150 tokens) for n batches.

**Architecture:** Documentation-only change to two markdown files. `templates/program.md` gets a rewritten experiment-loop section plus briefing/compact-summary contracts. `SKILL.md` gets a new "Subagent model" section and two "Common Mistakes" rows. No Python templates change — the subagent model is a pure orchestration layer on top of the existing harness/launcher/dynamics infrastructure.

**Tech Stack:** Markdown. Verification is by `grep`/`Read`, not a test runner.

**Reference spec:** `docs/superpowers/specs/2026-06-14-autoresearch-subagents-design.md`

---

## File Structure

- **Modify:** `skills/autoresearch-setup/templates/program.md` — replace "The experiment loop" and "NEVER STOP" sections; add a new "Batch subagent contract" section (briefing + compact summary). This file is the per-project loop manual the orchestrator follows.
- **Modify:** `skills/autoresearch-setup/SKILL.md` — add a "Subagent model" section after the Workflow section (before "Anti-cheat discipline"); add two rows to the "Common Mistakes" table.

No new files. No Python edits.

---

## Task 1: Add the batch subagent contract section to program.md

This task inserts a new section documenting the briefing format and compact
summary schema. It goes immediately before the existing "## The experiment loop"
section so the loop (rewritten in Task 2) can reference it.

**Files:**
- Modify: `skills/autoresearch-setup/templates/program.md` (insert before line beginning `## The experiment loop`)

- [ ] **Step 1: Insert the new section**

Use Edit. The `old_string` is the existing experiment-loop heading and its first line; the `new_string` prepends the new section before it.

`old_string`:
```
## The experiment loop

LOOP FOREVER:
```

`new_string`:
````
## Batch subagent contract

The main session is the **orchestrator**: it forms hypotheses and dispatches one
**batch subagent** (via the Agent tool) per iteration. The batch subagent owns
everything file-heavy — reading `train.py`, writing variants, launching, waiting,
reading logs + dynamics, appending to `findings.md` — and returns only a compact
summary. The orchestrator never reads a log file or writes variant code, so its
context grows ~150 tokens per batch instead of accumulating every run's output.

### Briefing (orchestrator → batch subagent)

Pass this as the Agent-tool prompt, filling the angle-bracket fields:

```
Batch {{N}} | current best: {{metric}} ({{commit}})
Hypothesis: <your hypothesis for this batch>
Variants: <brief description of the ladder or N distinct ideas>

1. Read findings.md and train.py for context.
2. Write train_0.py .. train_{{N-1}}.py implementing the hypothesis. Give each a
   one-line module docstring (it becomes the results.tsv description). Do NOT
   `git add` them — the launcher deletes them at end-of-batch.
3. Run: {{run_command}}  (redirect everything; do NOT use `tee`)
4. Read results.tsv and each variant's run_dynamics.csv snapshot header. If
   dynamics look anomalous (loss spike, plateau, grad blow-up, OOM crash),
   dispatch a dynamics-analyst sub-agent with the variant path and your specific
   question.
5. Append findings to findings.md: confirmed wins, dead ends, dynamics
   observations, updated noise-floor evidence if relevant, open ideas.
6. Return the compact summary below — nothing else.
```

The batch subagent must obey the same anti-cheat rules as the orchestrator: no
editing `harness.py`/`launcher.py`/`dynamics.py`, no val leakage, no
`torch.compile`. Restate them in the briefing if the subagent has no other access
to this program.md.

### Compact summary (batch subagent → orchestrator)

The subagent returns exactly this block and nothing else:

```
batch: N
winner: vK | metric: X.XXX | delta: +/-X.XXX vs prior best | status: keep/discard/none
variants:
  v0: <docstring> → X.XXX | keep/discard/crash
  v1: <docstring> → X.XXX | keep/discard/crash
dynamics: <one line per variant — convergence, anomalies, plateaus, notable series>
findings_appended: yes
```

- `delta` is relative to the running best at the **start** of this batch.
- `status: none` means no variant beat the running best — that is data, not a
  failure.
- A crashed variant is `status: crash` with metric `nan`; note the failure mode
  in the `dynamics` line.

## The experiment loop

LOOP FOREVER:
````

- [ ] **Step 2: Verify the section landed**

Run: `grep -n "## Batch subagent contract" skills/autoresearch-setup/templates/program.md`
Expected: one matching line, located before the line matching `## The experiment loop`.

Run: `grep -n "^## The experiment loop" skills/autoresearch-setup/templates/program.md`
Expected: line number greater than the "Batch subagent contract" line.

- [ ] **Step 3: Commit**

```bash
git add skills/autoresearch-setup/templates/program.md
git commit -m "autoresearch: add batch subagent briefing + summary contract to program.md"
```

---

## Task 2: Rewrite the experiment loop and NEVER STOP sections in program.md

Replace the old single-session loop body (steps 1–6) and the trailing crash
paragraph with the orchestrator loop. Then update "NEVER STOP" to reflect that
stopping means not dispatching the next batch subagent, and that findings.md is
written by the subagents throughout.

**Files:**
- Modify: `skills/autoresearch-setup/templates/program.md` (the body under `## The experiment loop` through the end of the `## NEVER STOP` section)

- [ ] **Step 1: Replace the loop body**

Use Edit.

`old_string` (the current loop body — everything from the first numbered step through the crash paragraph):
```
1. **Read `findings.md`** + the git state (branch / tip / `tail results.tsv`) so you
   know the current best and what's already been tried.
2. **Form a hypothesis.** One idea per variant; make the N variants span the
   hypothesis (e.g. a ladder over one knob, or N distinct ideas).
3. **Author N variants** `train_0.py .. train_{N-1}.py` per the contract above.
4. **Launch the batch**: `{{run_command}}` (redirect everything; do NOT use `tee`).
5. **Read the result**: `tail results.tsv` and `git log --oneline`. For a quick
   look, read the `# [stats]` header of each variant's `run_dynamics.csv`. For
   deeper questions (loss spikes, grad instability, val/train divergence, plateau,
   per-entity convergence), load the full series via `load_run_dynamics` or dispatch
   the `dynamics-analyst` sub-agent on-demand with the variant's path and your
   specific question.
6. **Keep/discard is already done** — the launcher committed the winner if it beat
   the running best. You decide *what to try next*. Go to 1 with a new batch.

A variant crash is recorded as `status=crash` with metric `nan` and never beats the
running best; the dynamics `# [meta]` header carries `crashed=true` and partial
series survive (written from a `finally` block). Inspect the tail of the variant's
`run.log` for the stack trace, then iterate.
```

`new_string`:
```
The orchestrator never reads a log file, writes a variant, or touches a dynamics
CSV directly — that is the batch subagent's job (see **Batch subagent contract**
above). The orchestrator accumulates only compact summaries.

1. **Form a hypothesis** from your accumulated compact summaries and the
   `findings.md` you read once at setup. Make the N variants span the hypothesis
   (a ladder over one knob, or N distinct ideas).
2. **Dispatch the batch subagent** via the Agent tool using the briefing in
   **Batch subagent contract**. Fill `{{N}}`, current best metric + commit, the
   hypothesis, and the variant descriptions.
3. **Receive the compact summary.** Keep/discard already happened inside the
   subagent's run — the launcher committed the winner if it beat the running best.
   Read the summary's `winner`/`delta`/`status` and `dynamics` lines.
4. **Decide what to try next** from the summary alone. Go to 1 with a new batch.

A `status: none` result (no variant beat the running best) is data, not a failure
— form a new hypothesis and continue. A `status: crash` variant scored `nan` and
never beats the best; the subagent's `dynamics` line carries the failure mode, and
the subagent already inspected the `run.log` tail if it needed the stack trace.
```

- [ ] **Step 2: Update the NEVER STOP section**

Use Edit.

`old_string`:
```
Once the loop has begun (after setup), do **not** pause to ask the human whether to
continue. The human may be asleep and expects you to keep working *indefinitely*
until manually stopped. With N parallel slots and ~{{budget_min}} min/batch, an
overnight session yields a large stack of results to wake up to.

**When you do stop** (the human halts you), before signing off **update
`findings.md`** with everything net-new from this session — confirmed wins,
surprising negatives, fresh noise-floor evidence, new open ideas, and the current
best (metric + commit). Commit the update. This is how knowledge survives across
branches and sessions.
```

`new_string`:
```
Once the loop has begun (after setup), do **not** pause to ask the human whether to
continue between batches. The human may be asleep and expects you to keep
dispatching batch subagents *indefinitely* until manually stopped. With N parallel
slots and ~{{budget_min}} min/batch, an overnight session yields a large stack of
results to wake up to.

`findings.md` is kept current by the batch subagents — each appends its net-new
wins, negatives, noise-floor evidence, and open ideas before returning. **When you
do stop** (the human halts you), verify the last batch subagent reported
`findings_appended: yes`; if a batch was interrupted before it could append, write
the missing findings yourself from that batch's compact summary and commit. This is
how knowledge survives across branches and sessions.
```

- [ ] **Step 3: Verify no stale references remain**

Run: `grep -n "Author N variants\|Read the result\|expects you to keep working" skills/autoresearch-setup/templates/program.md`
Expected: no matches (all three old phrases are gone).

Run: `grep -n "Dispatch the batch subagent\|compact summaries\|findings_appended: yes" skills/autoresearch-setup/templates/program.md`
Expected: matches present (new content landed).

- [ ] **Step 4: Commit**

```bash
git add skills/autoresearch-setup/templates/program.md
git commit -m "autoresearch: rewrite experiment loop as orchestrator + batch subagent"
```

---

## Task 3: Add the Subagent model section to SKILL.md

Insert a new section after the Workflow section (which ends with "Hand off to the
project's filled-in `program.md`…") and before "## Anti-cheat discipline".

**Files:**
- Modify: `skills/autoresearch-setup/SKILL.md` (insert before the line `## Anti-cheat discipline`)

- [ ] **Step 1: Insert the section**

Use Edit.

`old_string`:
```
## Anti-cheat discipline
```

`new_string`:
```
## Subagent model

An autoresearch run can iterate for hours. To keep the main session's context flat
over a long run, the loop is split:

- **Main orchestrator** — the long-lived session. Reads `findings.md` once at
  setup, forms hypotheses, dispatches one batch subagent per iteration, and
  accumulates only the compact summaries each returns. It never reads log files,
  writes variant code, or touches dynamics CSVs. Context grows ~150 tokens/batch.
- **Batch subagent** — one per iteration, discarded after it returns. Owns variant
  writing, launch, wait, result + dynamics reading, and the `findings.md` append.
  Returns the compact summary and exits.
- **Dynamics-analyst subagent** — dispatched on-demand from *within* the batch
  subagent when a variant's dynamics look anomalous. Unchanged.

See the project's `program.md` ("Batch subagent contract") for the briefing format
and the compact-summary schema.

## Anti-cheat discipline
```

- [ ] **Step 2: Verify**

Run: `grep -n "## Subagent model\|## Anti-cheat discipline" skills/autoresearch-setup/SKILL.md`
Expected: "## Subagent model" appears immediately before "## Anti-cheat discipline".

- [ ] **Step 3: Commit**

```bash
git add skills/autoresearch-setup/SKILL.md
git commit -m "autoresearch: document subagent model in SKILL.md"
```

---

## Task 4: Add Common Mistakes rows to SKILL.md

Append two rows to the "Common Mistakes" table at the end of SKILL.md.

**Files:**
- Modify: `skills/autoresearch-setup/SKILL.md` (the final "Common Mistakes" table)

- [ ] **Step 1: Append the rows**

Use Edit. The `old_string` is the current last row of the table; the `new_string`
re-states it and adds two rows after it.

`old_string`:
```
| "Deriving" held-out targets in train.py | Leakage. Touch the held-out set only via `ctx.score(...)` |
```

`new_string`:
```
| "Deriving" held-out targets in train.py | Leakage. Touch the held-out set only via `ctx.score(...)` |
| Reading log files or dynamics CSVs in the main orchestrator loop | Delegate to the batch subagent; the main context should only ever see compact summaries |
| Batch subagent returning raw log excerpts in its summary | The summary must match the compact schema — one line per variant plus one dynamics line per variant, nothing else |
```

- [ ] **Step 2: Verify**

Run: `grep -n "Reading log files or dynamics CSVs\|Batch subagent returning raw log" skills/autoresearch-setup/SKILL.md`
Expected: both rows present.

- [ ] **Step 3: Commit**

```bash
git add skills/autoresearch-setup/SKILL.md
git commit -m "autoresearch: add subagent Common Mistakes rows"
```

---

## Final verification

- [ ] **Step 1: Confirm both files are internally consistent**

Run: `grep -rn "Batch subagent contract" skills/autoresearch-setup/`
Expected: the SKILL.md "Subagent model" section references it AND program.md
defines it (the cross-reference resolves).

- [ ] **Step 2: Confirm no broken anchors / leftover single-session language**

Run: `grep -rn "Author N variants\|keep working \*indefinitely\*" skills/autoresearch-setup/`
Expected: no matches.

- [ ] **Step 3: Final review read**

Read `skills/autoresearch-setup/templates/program.md` start-to-finish once and
confirm the "Authoring variants" section (which still instructs writing
`train_k.py`) reads coherently as instructions the **batch subagent** follows —
the briefing in step 2 tells the subagent to write those files, so that section is
now the subagent's reference, not the orchestrator's. No edit required unless it
reads as contradictory; if it does, add a one-line note at the top of "Authoring
variants" saying it is the batch subagent's reference.
