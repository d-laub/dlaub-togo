# Worked-example harnesses

Two real autoresearch harnesses built on this same contract. They live in a
**private repo (`gvf-germ-som`)**, so treat the descriptions below as the durable
reference — they are written to be useful even if you cannot open the files. Both
implement the I/O contract documented in `contracts.md` (`build_spec` →
`ExperimentSpec`; `eval_forward`; `train_fn` → `TrainResult`; `emit_summary` grep
contract; the `run_dynamics.csv` two-tier format).

## cis — full parallel harness

`src/gvf_germ_som/autoresearch/` (`prepare.py`, `train.py`, `_launcher.py`,
`_clusters.py`, `_dynamics.py`, `_pergene_writer.py`, `program.md`).

The complete, batteries-included variant. The fixed `prepare.py` harness pins a
single train window (chr16) + a single val window (chr17), builds the
`CisGeneRegData` datamodules, and defines the score as `PearsonND` nan-mean over
gene tokens — `eval_forward` returns one prediction per gene token aligned with
`batch["rna"]["expr"]` (this is the worked shape example in `contracts.md`). On
top of the base contract it adds: a **parallel batch launcher** (`_launcher.py` +
`_clusters.py`) that fans N variant subprocesses across N GPUs (sbatch on Carter,
`Popen` on Runpod), parses each variant's summary block, appends a row to
`results.tsv`, and does **linear keep/discard** (commits a variant only if it
beats the running best); a **two-tier dynamics** system (`_dynamics.py` snapshot
header + wide CSV) with an optional **per-gene Pearson parquet**
(`_pergene_writer.py`, schema `epoch, step, split, gene_id, r`) surfaced through
`RunDynamics.per_gene()`; and a `DynamicBatchSizeCosineLRScheduler` that schedules
LR in *item-units* rather than steps to cope with the heavy-tailed batch sizes a
packing sampler produces. Its `program.md` is the full autonomous-loop playbook
(branch-per-session, author `train_0..N-1.py`, launch, keep/discard, dispatch a
`dynamics-analyst` sub-agent for deep dives, never stop until told).

## trans — minimal single-run harness

`src/gvf_germ_som/trans/autoresearch/` (`prepare.py`, `train.py`, `program.md`).

A stripped-down single-run variant of the same pattern, for a **GRN-edge model**
(`PromoterTrunk` + `SetTransformerCombiner` over graph-regulatory-network edges).
The fixed `prepare.py` builds `TransGeneRegData` datamodules (chr16 train /
chr17 val), and its score computes per-gene Pearson by accumulating flat
`(instance,)` pred/target tensors plus gene-ID strings — here the batch is a
**tuple**, so the scorer reads `batch[3]` (targets) and `batch[5]` (gene IDs) and
`eval_forward` consumes `batch[:3]`. It reuses cis's `_dynamics.py` (`Recorder`,
`write_dynamics_csv`) rather than re-implementing it. There is **no parallel
launcher and no keep/discard** — you run one variant at a time via
`python -m gvf_germ_som.trans.autoresearch` (env knobs `AUTORES_VARIANT`,
`AUTORES_BUDGET_MIN`, `AUTORES_LR`, `AUTORES_TOTAL_ITEMS`). Its `program.md` is
deliberately minimal: fixed-subset table, feature-flag table, dynamics-series
table, the summary block, and a "change exactly one thing from `train.py`"
variant-authoring convention. Use trans as the template when you want the
contract without the full multi-GPU orchestration.
