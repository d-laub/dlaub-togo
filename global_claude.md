<!-- BEGIN dlaub-togo:global_claude.md -->
When using superpowers:subagent-driven-development, always use Sonnet for implementation tasks.

# Coding principles

Defaults for real work; relax for one-off/throwaway scripts — don't gold-plate a
prototype. There should be one — and preferably only one — obvious way to do it.

## Types
- **Make invalid states unrepresentable** — encode constraints in types over
  defensive runtime checks; prefer enums/newtypes/non-nullable to stringly-typed
  or optional-everything.
- **Permissive inputs, specific outputs** — accept the broadest reasonable type
  (`Iterable`, `Sequence`, protocols), return the most concrete one.
- **Generics when input/output/state types are coupled** — express the link, don't
  widen to `Any` or duplicate classes.
- **Fail fast: compile-time > runtime errors** — strict type checkers/linters as
  gates (`pyrefly` for Python, `clippy`+`rustfmt` for Rust).
- **`returns` for error handling off hot paths** — `Result`/`Maybe`/fluent pipelines
  over ad-hoc exceptions/`None`. (See the `returns` skill.)

## Design
- **Measure, don't guess** — decisions must be principled, never arbitrary. E.g.
  don't filter RNA-seq at `TPM >= 1` by convention; pick a threshold the count
  distribution justifies.
- **Don't reinvent wheels** — generic/familiar/foundational? A package likely exists.
- **Easy perf wins in numerical/tabular code** — Python loops over arrays or rows are
  a code smell; reach for vectorized NumPy or Polars expressions first (whichever fits
  the data), Numba when that's not enough, Rust/PyO3 for hot paths.
- **DRY & YAGNI.**

## Tooling
- **`pixi`** for envs/deps (see the `pixi` skill); **`uv`** for one-off scripts with
  niche deps (avoid sprawling to >6 pixi envs); **`dvc`** for data.

# Maintained packages
I maintain **seqpro**, **genoray**, **genvarloader**, **genvarformer** — treat bugs
and features in these as first-party, not external deps.
<!-- END dlaub-togo:global_claude.md -->
