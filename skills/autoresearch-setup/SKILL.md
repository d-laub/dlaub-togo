---
name: autoresearch-setup
description: Use when setting up an autonomous ML experimentation harness (an "autoresearch" loop) — a fixed harness that owns data + metrics plus a hackable training script an LLM iterates on under a fixed time budget. Use when scaffolding harness.py/train.py/program.md, designing structured training-dynamics logging for agents to read, or enforcing that experiments cannot game the metric.
metadata:
  type: technique
---

# Autoresearch Setup

## Overview

An **autoresearch harness** lets an LLM iterate autonomously on an ML problem under
a fixed time budget. It is a two-file split:

- **`harness.py` — FIXED.** Owns data loading, the train/val split, the fixed
  fast-iteration subset, and the metric. The LLM never edits it.
- **`train.py` — hackable.** Owns the model, optimizer, scheduler, loss, and
  training loop. The LLM rewrites it freely, subject only to the harness's I/O
  contract (`build_spec` → `ExperimentSpec`, `eval_forward`, `train_fn`).

**Core invariant: `harness.py` owns data + the metric and is never edited;
`train.py` owns everything else under the contract.** This is what makes results
across variants and sessions comparable. Violating the letter of the
immutable-harness rule is violating the spirit of comparable, honest results.

## Workflow

### 1. Brainstorming gate (REQUIRED)

Invoke `superpowers:brainstorming` and resolve **all six** items before scaffolding:

1. **Metric** — and its exact computation (what reduces preds+target to the scalar).
2. **Data** — source, train/val split, and the fixed fast-iteration subset.
3. **I/O contract** — the harness↔train interface (`eval_forward` output shape).
4. **Time budget** — per-variant wall-clock.
5. **Compute backend** — cluster/GPU layout (LocalMultiGPU vs Sbatch).
6. **Fixed-vs-editable boundary** — exactly what lives in `harness.py`.

**Do not guess these, and do not skip the gate even under time pressure.** "Skip
the questions, I'm in a hurry" is NOT license to guess — resolve the six fast
instead. A harness built on guessed answers produces incomparable, worthless runs;
that is slower than the gate, not faster.

### 2. Scaffold

Copy `templates/` into the target project at the agreed location, then:

- **Fill `# TODO(autoresearch):` markers** from the gate answers in `harness.py`,
  `train.py`, `launcher.py`, and `kernels.py` (kernels.py only as kernels mature —
  empty is fine).
- **Copy as-is** (no edits): `dynamics.py`.
- **Fill `{{placeholders}}`**: `program.md`.
- **Start empty / append-only**: `findings.md`.

### 3. Wire the contract

Read **`reference/contracts.md`** for the exact `eval_forward` output shape and the
`ExperimentSpec` / `TrainContext` fields. Do not reverse-engineer the shape from
source — the contract reference is the authority (the eval_forward shape is the
single thing agents most often get wrong). See `reference/examples.md` for two
worked harnesses (cis full parallel; trans minimal single-run).

### 4. Run the loop

Hand off to the project's filled-in `program.md` — the autonomous experiment-loop
manual.

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

> [!WARNING]
> **Red Flags — STOP.** Any of these is cheating, not progress:
> - Editing ANYTHING in `harness.py`.
> - Touching a `# FIXED` / `# TODO(autoresearch)`-pinned constant (metric, subset,
>   seed).
> - Importing or inspecting validation / held-out data inside `train.py` —
>   **including reading held-out target VALUES and fitting to them. "Deriving"
>   them is still leakage.**
> - Calling `torch.compile`, or adding a runtime `.autotune()`.
> - Editing `launcher.py`'s keep/discard logic, winner threshold, or metric parse.

The only legitimate channel to the val/held-out set is `ctx.score(...)`, which
lives in the harness.

### Rationalizations and reality

| Excuse | Reality |
|---|---|
| "Budget's almost up, I'll just relax the scorer threshold" | Changing the metric makes every prior result incomparable. The metric is the experiment's ground truth. |
| "The val set is small; let me add a few train items to reduce noise" | It leaks signal and inflates the score, AND makes every prior result incomparable — they were measured on different train/val data. Noise floor is part of the result. |
| "I'll move this 'fixed' constant into train.py so I can tune it" | If it moved, comparability broke silently. Fixed means fixed; change it only by starting a new branch + editing harness.py deliberately. |
| "I'll peek at val to pick which examples to weight" | That's val leakage. eval_forward sees val only through the harness scorer. |
| "torch.compile would make this fit the budget" | Trace+autotune burns the budget every run; prohibited. Use pre-tuned kernels.py. |
| "I didn't copy the held-out targets — I derived the function from them, so it generalizes" | Reading held-out target values and fitting to them IS leakage, derived or copied. The held-out set must only be touched through the harness scorer. A model that "fits the held-out relationship" has memorized the test, not learned the task. |

## Quick Reference

| File | Role | Editable? |
|---|---|---|
| `harness.py` | FIXED — data + metric + contracts | No |
| `train.py` | Hackable training loop | Yes |
| `launcher.py` | FIXED — dispatch, keep/discard, results.tsv | No |
| `dynamics.py` | Two-tier dynamics recorder | No (copy as-is) |
| `program.md` | Experiment-loop manual | Project-fills placeholders |
| `findings.md` | Living cross-session findings log | Append only |
| `kernels.py` | Pre-tuned kernels only | Yes (additively) |

### Cross-references

- `superpowers:brainstorming` — the required gate (workflow step 1).
- `helion-jagged-and-autotuning` — ship pre-tuned kernels; never runtime-autotune.
- `pixi` — environment setup for running the harness.

## Common Mistakes

| Mistake | Fix |
|---|---|
| Guessing the metric/split/budget instead of gating | Run `superpowers:brainstorming` first; resolve all six items |
| `eval_forward` shape mismatch (silently uncomparable metric) | Read `reference/contracts.md`; return what the harness scorer's metric consumes |
| Logging only a final number | Use the two-tier `dynamics.py` recorder (snapshot header + wide body) |
| Editing `launcher.py` to manufacture a win | Launcher is FIXED; relaxing keep/discard or the parse is cheating |
| "Deriving" held-out targets in train.py | Leakage. Touch the held-out set only via `ctx.score(...)` |
| Reading log files or dynamics CSVs in the main orchestrator loop | Delegate to the batch subagent; the main context should only ever see compact summaries |
| Batch subagent returning raw log excerpts in its summary | The summary must match the compact schema — one line per variant plus one dynamics line per variant, nothing else |
