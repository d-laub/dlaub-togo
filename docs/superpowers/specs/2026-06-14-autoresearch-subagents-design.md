# autoresearch-setup: subagent model

**Date:** 2026-06-14
**Skill:** `autoresearch-setup`
**Status:** approved

## Problem

An autoresearch loop runs indefinitely overnight. The current `program.md` has
a single session doing everything: reading `train.py`, writing N variant files,
launching the batch, waiting, reading all log files and dynamics CSVs, forming
the next hypothesis, and repeating. Both variant writing and result
reading/analysis contribute equally to context growth per iteration. Over 20+
batches a session accumulates tens of thousands of tokens of tool call output —
log data, CSV content, and generated code — making long runs impractical.

## Goal

Keep main-session context at O(n × ~150 tokens) for n batches, with no change
to the underlying harness/launcher infrastructure.

## Design

### Role split

| Role | Session | Responsibilities |
|---|---|---|
| **Main orchestrator** | Long-lived main session | Reads `findings.md` once at setup. Forms hypotheses from compact summaries. Invokes Agent tool once per batch. Never reads log files, writes variants, or touches dynamics CSVs. |
| **Batch subagent** | One per iteration, discarded after | Reads `train.py` + `findings.md`. Writes N variants. Launches and waits. Reads all logs + dynamics. Appends to `findings.md`. Returns compact summary. |
| **Dynamics-analyst subagent** | On-demand, called from batch subagent | Unchanged. Fires when dynamics look anomalous. |

### Briefing format (orchestrator → batch subagent)

The Agent tool prompt includes:

```
Batch {{N}} | current best: {{metric}} ({{commit}})
Hypothesis: <your hypothesis for this batch>
Variants: <brief description of the ladder or N distinct ideas>

1. Read findings.md and train.py for context.
2. Write train_0.py .. train_{{N-1}}.py. Give each a one-line module docstring
   (becomes the results.tsv description).
3. Run: {{run_command}}
4. Read results.tsv and each variant's run_dynamics.csv snapshot header.
   If dynamics look anomalous, dispatch a dynamics-analyst subagent with the
   variant path and your specific question.
5. Append findings to findings.md: wins, dead ends, dynamics observations,
   updated noise floor if relevant, open ideas.
6. Return the compact summary — nothing else.
```

### Compact summary format (batch subagent → orchestrator)

```
batch: N
winner: vK | metric: X.XXX | delta: +/-X.XXX vs prior best | status: keep/discard/none
variants:
  v0: <docstring> → X.XXX | keep/discard/crash
  v1: <docstring> → X.XXX | keep/discard/crash
dynamics: <one line per variant — convergence, anomalies, plateaus, notable series>
findings_appended: yes
```

`status: none` means no variant beat the running best. The orchestrator
accumulates these compact summaries and reasons from them — it never opens a log
file.

### Orchestrator loop (replaces "The experiment loop" in program.md)

```
LOOP FOREVER:

1. Form a hypothesis from compact summaries + findings.md (read once at setup).
2. Invoke batch subagent via Agent tool with the briefing above.
3. Receive compact summary.
4. Go to 1.
```

The "NEVER STOP" rule becomes: do not pause between batch subagent calls without
being halted by the human.

## Changes to the skill

### `SKILL.md`

Add "Subagent model" section (after Workflow, before Anti-cheat) summarising the
three roles and pointing to `program.md` for the contracts.

Add two rows to "Common Mistakes":
- Reading log files or dynamics CSVs in the main orchestrator loop → delegate to batch subagent
- Batch subagent returning raw log excerpts → summary must match compact schema

### `templates/program.md`

Replace "The experiment loop" section with the orchestrator loop documented
above. Update "NEVER STOP" and "When you do stop" to reflect the new model
(stopping = not invoking the next batch subagent; findings.md was written by the
subagents throughout).

### No changes

`harness.py`, `train.py`, `launcher.py`, `dynamics.py`, `kernels.py` templates
are unchanged. The subagent model is purely an orchestration layer on top of the
existing infrastructure.

## Out of scope

- Changing the briefing into a structured schema (plain prose is enough; the
  compact summary is the only machine-read output)
- Splitting large batches (N > 4) across multiple subagents (the launcher already
  handles parallelism; the subagent just writes files and reads results)
- Making the dynamics-analyst subagent structured (it is on-demand and already
  documented)
