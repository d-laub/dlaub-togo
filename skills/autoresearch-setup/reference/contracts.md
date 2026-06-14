# Harness ↔ train.py I/O contract

The harness (`harness.py`) is **fixed**: it owns data loading, the metric, the
score bookkeeping, crash trapping, and the stdout summary block. `train.py` is
**hackable**: it owns the model, optimizer, scheduler, loss, and training loop.
The two meet through exactly three things `train.build_spec()` hands back, plus a
few objects the harness hands `train_fn` at runtime. This file is the authority
for those interfaces — names are taken verbatim from `templates/harness.py`,
`templates/train.py`, and `templates/dynamics.py`.

If you only read one section, read **`eval_forward` output shape** — that is the
contract people most often get wrong.

---

## `ExperimentSpec` — what `build_spec()` returns

`build_spec()` (in `train.py`) constructs and returns one frozen `ExperimentSpec`.
The harness's `run_experiment(spec)` consumes every field.

| Field | Type | Meaning |
|---|---|---|
| `cfg` | `dict[str, Any]` | Free-form project config. Feature flags, architecture knobs, window size, encoding strategy — anything `train.py` wants threaded into the harness data builders (`build_train_dataloader(cfg)` / `build_val_dataloaders(cfg)`) and read back inside `train_fn`. The harness does not interpret it beyond passing it to the builders. |
| `max_items` | `int` | Fixed per-batch item budget (e.g. for a packing sampler). Held constant for comparability. |
| `model` | `nn.Module` | Your model. The harness introspects it: `num_params_M` = `sum(p.numel())/1e6`, and `depth` via `_introspect_depth` (reads `model.n_layers` if you set it, else counts `nn.TransformerEncoderLayer`s). It is `fabric.setup`'d before `train_fn` runs. |
| `train_fn` | `TrainFn` = `Callable[[TrainContext], TrainResult]` | Your training loop. |
| `eval_forward` | `EvalForward` = `Callable[[nn.Module, dict[str, Any]], torch.Tensor]` | Forward pass used by the harness scorer. See shape contract below. |

> Project variants may add fields (the cis harness adds `flat_pack: bool = False`)
> or rename `cfg` to a typed config object (cis/trans use `flags: FeatureFlags`).
> The five core fields above always exist.

---

## `TrainContext` — what `train_fn` receives

The harness builds this and passes it to `spec.train_fn(ctx)`. All objects are
already wired to the accelerator (model and loaders are `fabric.setup`'d).

| Field | Type | What you may call |
|---|---|---|
| `fabric` | `L.Fabric` | `fabric.backward(loss)`, `fabric.clip_gradients(model, optimizer, max_norm=...)`, `fabric.setup_optimizers(optimizer)`, `fabric.device`. Do **not** call `fabric.setup` on the model again — it is already set up. |
| `model` | `nn.Module` | The `fabric.setup`'d model. Train it. |
| `train_loader` | `DataLoader` | The fixed train loader the harness built from `cfg`. Iterate it. |
| `val_loaders` | `dict[str, DataLoader]` | Keyed by val "kind". One key must be `PRIMARY_VAL_KIND`. You normally do not iterate these directly — `score` does. |
| `budget_sec` | `float` | Wall-clock budget (`budget_min * 60`). You **must** respect it: check `time.monotonic() - t0 >= ctx.budget_sec` and stop. |
| `score` | `ScoreFn` | Stateful scorer (below). |
| `recorder` | `Recorder` | `recorder.log(name, value, step=None)` to add a time-series point; `recorder.last_step()` for the current max step index. Series become columns in `run_dynamics.csv`. |

### `ScoreFn`

```python
score(kind: str, model: nn.Module) -> float   # runs eval, returns metric, updates running best for `kind`
score.best(kind: str) -> float                 # current running best (max) for `kind`
```

Calling `score(kind, model)` iterates `val_loaders[kind]`, calls
`spec.eval_forward(model, batch)` per batch, computes the project metric, returns
the scalar, updates the harness-owned running **max** for that kind, and logs
`val_metric/<kind>` to the recorder. It saves/restores `model.training`, so you
don't need to toggle `eval()`/`train()` around it.

---

## `eval_forward(model, batch) -> Tensor` — the shape contract

This is the single contract that was the documented pain point. State it precisely:

> **`eval_forward` MUST return predictions in the exact shape the harness metric
> consumes.** The harness scorer reads the target out of `batch` and reduces
> `(preds, target)` to the scalar metric. If your preds don't align with the
> target the metric pulls from `batch`, the metric is wrong (or raises) and the
> result is silently uncomparable.

The shape is **not** documented as a number — it is *defined by the metric call
inside the harness's `_make_score_fn`*. In the generic template that metric is a
`TODO`, so the rule is: **read `_make_score_fn` in your `harness.py`, find where
it reads the target from `batch` and where it feeds `preds` into the metric, and
return whatever lines up with that.**

`eval_forward` is also the right thing to reuse as the forward pass inside your
`train_fn` (the template calls `_eval_forward(model, batch)` in the train loop),
which keeps train and eval forward identical.

### Worked example (cis harness)

In the cis harness `_make_score_fn` does, per validation batch:

```python
preds = eval_forward(model, batch)          # YOUR output
obs   = batch["rna"]["expr"]                 # the target the harness reads
metric.update(
    preds=preds,
    targets=obs,
    idx=(batch["indices"]["r_idx"], batch["indices"]["s_idx"]),
)
```

So in the cis project `eval_forward` must return **one scalar prediction per gene
token, aligned with `batch["rna"]["expr"]`** (a `Nested`/`Tensor` matching that
target's shape) — because `PearsonND` compares `preds` against `obs` grouped by
`idx`. That is the concrete meaning of "match the metric's expected shape": the
target the scorer reads (`batch["rna"]["expr"]`) dictates the output shape, not a
fixed dimension you can memorize. The cis program states the same rule plainly:
`eval_forward(model, batch) -> Tensor` returns a tensor matching
`batch["rna"]["expr"]` shape so the fixed `PearsonND` scorer works.

> The `batch` structure is project-specific. cis passes a `dict` (`batch["rna"]`,
> `batch["indices"]`); trans passes a tuple and the scorer reads `batch[3]` (obs)
> and `batch[5]` (gene IDs). Always read your own `_make_score_fn` to learn the
> batch layout and the target key.

---

## `train_fn(ctx) -> TrainResult`

Your training loop. Return `TrainResult(num_steps: int, training_seconds: float)`.

Hard requirements:

1. **Call `ctx.score(kind, model)` at least once** (with `kind = PRIMARY_VAL_KIND`),
   so the harness has a running best to read. `run_experiment` reports
   `score.best(PRIMARY_VAL_KIND)` as the optimization metric; if you never score,
   it stays `nan` → reported as `0.0`. The canonical loop scores periodically
   (every `val_every` steps), at epoch end, and once more after the loop so the
   final best is fresh.
2. **Respect `ctx.budget_sec`.** Break out of the loop once wall-clock exceeds it.
3. Drive training with `ctx.fabric` (`backward`, `clip_gradients`,
   `setup_optimizers`) — not raw `loss.backward()`.

Everything else (optimizer, scheduler, loss, AMP, EMA, curriculum, custom
batching, extra `recorder.log` series) is yours.

---

## Dynamics CSV format (`run_dynamics.csv`)

`run_experiment` flushes the recorder to `run_dynamics.csv` in a `finally` block
(so it survives crashes — partial series are still written). Two-tier file:

### Header (snapshot tier — read by eye)

```
# dynamics v3 — autores run <ISO timestamp>
# [meta] num_steps=... crashed=... budget_sec=...
# [stats] <series> n=.. first=.. final=.. min=..@<step> max=..@<step>     (one per series)
# [legend] <series> = <description>                                        (one per series)
# [per-entity] final <split> mean=.. median=..                            (optional, diagnostic)
```

- `# [meta]` — run-level key/values.
- `# [stats]` — per-series at-a-glance summary: count, first, final, nan-safe
  `min@step` / `max@step` (3 sig figs; exact values are in the body).
- `# [legend]` — per-series description; the primary metric line is tagged
  `— PRIMARY`.

### Body (full tier)

A wide CSV: one row per step (sorted union of all series' step indices), one
column per series in canonical-then-first-logged order (`step,train_loss,
val_metric,lr,grad_norm,...`). A cell is empty where that series wasn't logged at
that step (sparse series like `val_metric/*` have mostly-empty columns).

### Reading it

- **Snapshot tier**: just read the `# [stats]` / `# [legend]` header lines. They
  answer most "did it converge / did loss spike / what was final r" questions.
- **Full tier**: `load_run_dynamics(path)` → `RunDynamics(meta, legend, stats,
  series, per_entity_header, path)`:

  ```python
  from dynamics import load_run_dynamics
  rd = load_run_dynamics("run_dynamics.csv")
  rd.meta              # dict[str, str]
  rd.legend            # dict[str, str]
  rd.stats             # pl.DataFrame (name, n, first, final, min, min_step, max, max_step)
  rd.series            # wide pl.DataFrame (step + one Float64 col per series; null = not logged)
  rd.per_entity()      # pl.DataFrame | None — reads sibling dynamics_per_entity.parquet if present
  ```

  `.per_entity()` returns `None` when no `dynamics_per_entity.parquet` sits next
  to the CSV; projects that emit per-gene/per-class breakdowns (cis writes a
  per-gene parquet) populate it.

---

## The `emit_summary` grep contract

`emit_summary(metrics)` prints the summary block to stdout. **The launcher greps
`^<primary_metric>:` and reads field 2 (the value).** Therefore:

- The **primary metric MUST be the first printed line** of the block (after the
  `---` separator). In the generic template it is `val_metric:`; cis/trans use
  `pearson_r:` and place the supplementary `pearson_r_train_val:` after it.
- Renaming the primary metric requires renaming it in **all coupled spots** or
  you get a `KeyError` on first run: (1) the printed key in `emit_summary`, (2) the
  matching key in `run_experiment`'s return dict, and (3) the local that feeds
  that key. Keep them in lockstep.
- The block prints one `<name>: <value>` line per metric; values are floats
  except `num_steps`/`depth` (ints).

---

## `PRIMARY_VAL_KIND`

Module-level constant in `harness.py` naming the primary validation kind (generic
default `"val"`; cis `"val-val"`, trans `"val-val"`). It is the key
`run_experiment` passes to `score.best(...)` for the reported metric, and **must
be one of the keys in `build_val_dataloaders`'s returned dict** — otherwise
`score.best(PRIMARY_VAL_KIND)` raises `KeyError`.
