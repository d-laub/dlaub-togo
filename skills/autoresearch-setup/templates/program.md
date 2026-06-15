# autoresearch — program

This is the experiment loop for the autoresearch harness. The LLM owns the full
training loop, not just the model + hyperparameters.

**Task**: {{task_description}}
**Primary metric**: `{{primary_metric}}` (higher = better; the FIRST line of every
variant's summary block).
**Fixed subset**: {{fixed_subset}} — held constant by `harness.py` so every variant
is comparable.
**Per-variant budget**: {{budget_min}} minutes of wall-clock (excluding
startup/eval).

## Setup

To start a session:

1. **Agree on a run tag** and **branch per run**: propose a tag based on today's
   date (e.g. `mar5`). Create a fresh branch `git checkout -b autoresearch/<tag>`
   from the current tip — it must not already exist.
2. **Read `findings.md` FIRST.** It is the living cross-session log: confirmed
   wins, confirmed dead ends, the noise floor, and open ideas. Read it before you
   form any hypothesis so you don't re-explore known dead ends. You will append to
   it when the session ends.
3. **Read the in-scope files** for full context. The repo is small:
   - `harness.py` — FIXED. Owns data loading + the metric + the fixed subset +
     `ExperimentSpec`/`TrainContext` contracts + the summary block. **Do not edit.**
   - `train.py` — the canonical current-best variant. You author per-batch siblings
     (`train_0.py .. train_{N-1}.py`); the launcher promotes the winner back into
     `train.py`.
   - `dynamics.py` — the recorder + two-tier dynamics writer/loader. Read-only.
   - `launcher.py` — owns dispatch + keep/discard + commit. **Do not edit.**
4. **Verify the data exists** (whatever `harness.py` loads for {{fixed_subset}}).
   If absent, ask the human to run the prep pipeline.
5. **Initialize `results.tsv`**: the launcher creates and owns it. Start the
   session fresh so it stays short enough to scan.
6. **Confirm and go.**

## Authoring variants

For each batch, write `train_0.py .. train_{N-1}.py` (one per parallel slot). Each
is a full copy of the `train.py` structure with your experimental changes. Give
each a one-line module docstring — it becomes the `description` column in
`results.tsv` and the commit message. Do **not** `git add` them; the launcher
deletes them at end-of-batch.

### The contract you MUST satisfy

Implement `build_spec`, `_eval_forward`, and `_train_fn` exactly as `harness.py`
requires:

1. `build_spec()` returns
   `ExperimentSpec(cfg, max_items, model, train_fn=_train_fn, eval_forward=_eval_forward)`.
2. `eval_forward(model, batch) -> torch.Tensor` returns predictions **in the shape
   the harness metric expects** — the harness scorer reads the target out of
   `batch` and reduces preds+target to the scalar `{{primary_metric}}`, so your
   output shape must line up with that reduction.
3. Inside `train_fn`, call `ctx.score(PRIMARY_VAL_KIND, ctx.model)` **at least
   once** during/after training — the harness reads `score.best(PRIMARY_VAL_KIND)`
   as the optimization metric. If the harness exposes a diagnostic split too,
   score it as well.
4. **Respect `ctx.budget_sec`** — stop the loop as soon as the wall-clock budget is
   exhausted (see the budget check in `train.py`).

### What you CAN do

Inside each `train_k.py` you own everything except the harness contract:

- Replace the model class entirely. Any `nn.Module` works.
- Own the optimizer, scheduler, loss, gradient clipping, AMP, EMA/SWA, curriculum,
  multi-phase training, custom batching — the whole loop.
- Toggle feature flags / architecture knobs through `cfg` (the harness threads
  `cfg` into its data builders and you read it back in `build_spec`/`train_fn`).
- Add custom dynamics: `ctx.recorder.log("name", value)` becomes a column in
  `run_dynamics.csv`. Extra series are cheap — log freely.

### What you CANNOT do

- **Do NOT edit `harness.py`.** It owns the data subset and the metric. Editing it
  (the metric, the fixed subset, the seed, the constants) silently breaks
  comparability with every prior result. It is cheating, not progress.
- **Do NOT edit `launcher.py` or `dynamics.py`.** The harness owns dispatch,
  keep/discard, and commits; the recorder format is fixed. Touching
  `launcher.py`'s keep/discard logic, the winner threshold, or its metric parsing
  (or `dynamics.py`'s recording) is cheating exactly like editing the metric in
  `harness.py` — relaxing the threshold or adding a "fallback" parse manufactures a
  "win" that isn't real. It is cheating, not progress.
- **Do NOT inspect or fit to the validation / held-out targets inside `train.py`.**
  Reading the val targets to derive a transform, a normalization, a bias, or a
  "smart init" is leakage **even if you derive rather than copy the values**. The
  only legitimate channel to the val set is `ctx.score(...)`, which lives in the
  harness.
- **NO `torch.compile`.** Under a short fixed budget, trace + autotune burns the
  whole budget every run. Use pre-tuned kernels from `kernels.py` instead (ship a
  saved Helion/Triton config; never `.autotune()` at run time).
- Do **not** install new packages or add dependencies. Use only what is already
  available in the environment.

### LR scheduling under variable batch sizes

If the data pipeline uses a packing/variable-size sampler, batch sizes vary
substantially step-to-step. A **step-based** scheduler (e.g. `LambdaLR` keyed to a
guessed `total_steps`) is wrong: the step count depends on packing efficiency and
can't be predicted from epochs — too long keeps LR at peak the whole run (val
metric can sign-flip), too short floors LR before convergence. Schedule in
**item-units** instead (cosine horizon = `instances_per_epoch * target_epochs`) and
scale per-step LR by `batch_size / reference_batch_size`. The budget is wall-clock,
not step count, so `target_epochs` is the lever: pick the largest value that still
reaches the cosine knee inside the budget. (Skip this section if your sampler emits
fixed-size batches.)

## Dynamics log format + two-tier read

Each variant writes a full-resolution `run_dynamics.csv` (no downsampling) into its
own log dir (`logs/v{k}/run_dynamics.csv`, next to its `run.log` — the launcher
sets `AUTORES_RUN_DIR` so parallel variants don't clobber a shared file; a
standalone run with no launcher writes `run_dynamics.csv` in the cwd). Read it in
two tiers:

**Snapshot tier (read by eye).** The `#`-comment header:
- `# [meta]` — `num_steps`, `crashed`, `budget_sec` (diagnostics may add more).
- one `# [stats]` line per series — `n first final min@step max@step` (3 sig figs).
- one `# [legend]` line per series — what the column means.
This answers most quick questions ("did it converge? did grad blow up?") at a glance.

**Full-resolution tier (load it).** The wide CSV body below the header: one row per
step (sorted union of all series' steps), one column per recorder series in
canonical-then-first-logged order; empty cell where a series wasn't logged at that
step (so `{{primary_metric}}` is sparse). For anything deeper than the header, load
it:

```python
from dynamics import load_run_dynamics
rd = load_run_dynamics("<variant log dir>/run_dynamics.csv")
rd.meta      # dict[str,str]
rd.legend    # dict[str,str]
rd.stats     # pl.DataFrame (per-series first/final/min@/max@)
rd.series    # wide pl.DataFrame (step + one col per series; null = not logged)
rd.per_entity()  # pl.DataFrame|None — optional per-entity parquet sibling
```

If the harness writes a per-entity breakdown, it lands in a
`dynamics_per_entity.parquet` sibling referenced from a `# [per-entity]` header line.
The generic templates do **not** emit this parquet — `rd.per_entity()` returns
`None` unless you wire a writer into your harness for per-entity breakdowns.

## Output / summary format

Each variant's `run.log` ends with the summary block emitted by `harness.emit_summary`.
The format is load-bearing: the launcher greps `^{{primary_metric}}:` and reads
field 2, so the primary metric MUST be the FIRST printed line:

```
---
{{primary_metric}}:   <value>
training_seconds:     <value>
total_seconds:        <value>
peak_vram_mb:         <value>
num_steps:            <value>
num_params_M:         <value>
depth:                <value>
```

`{{primary_metric}}` is the optimization target. The other fields are diagnostic.

## results.tsv schema

Tab-separated (NOT comma-separated). 4 columns:

```
commit	metric	status	description
```

The launcher appends one row per variant per batch. `status` is one of `keep`,
`discard`, or `crash` (a `parse_error` is also possible if the summary is
unreadable). Do NOT hand-edit `results.tsv` — the launcher owns it.

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

## NEVER STOP

Once the loop has begun (after setup), do **not** pause to ask the human whether to
continue. The human may be asleep and expects you to keep working *indefinitely*
until manually stopped. With N parallel slots and ~{{budget_min}} min/batch, an
overnight session yields a large stack of results to wake up to.

**When you do stop** (the human halts you), before signing off **update
`findings.md`** with everything net-new from this session — confirmed wins,
surprising negatives, fresh noise-floor evidence, new open ideas, and the current
best (metric + commit). Commit the update. This is how knowledge survives across
branches and sessions.
