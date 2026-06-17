# Global CLAUDE.md sync — design

## Goal

Ship a `global_claude.md` file in this repo that captures David's coding zen and
environment preferences, and have `setup_bash.sh` idempotently sync it into the
machine's global `~/.claude/CLAUDE.md` (creating that file if absent). This
replaces the current `setup_bash.sh` behavior of overwriting `~/.claude/CLAUDE.md`
with a single hard-coded line.

## Approach

- **Single source of truth:** `global_claude.md` holds *all* global instructions —
  the existing `superpowers:subagent-driven-development` → Sonnet line plus the
  coding principles. Editing one file is the only thing needed to change global
  instructions.
- **Sentinel-marker block:** the file's content is wrapped in
  `<!-- BEGIN dlaub-togo:global_claude.md -->` / `<!-- END dlaub-togo:global_claude.md -->`
  markers. `setup_bash.sh` strips any existing block between those markers from
  `~/.claude/CLAUDE.md`, then appends the current file. This is idempotent (no
  duplication on re-run) *and* self-updating (edits propagate on the next run).
- **Non-destructive:** other content in `~/.claude/CLAUDE.md` (notably the
  `@RTK.md` import added by `rtk init --global`) is preserved; only the marked
  block is replaced.
- **Terseness matters:** CLAUDE.md loads every session, so content is compressed
  to bold lead-ins plus only the specifics that teach (the RNA-seq threshold
  example, the NumPy→Numba→Rust performance ladder, concrete tool names).

## Files

### New: `global_claude.md` (repo root)

Verbatim content to ship:

```markdown
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
- **Easy perf wins in numerical code** — Python loops over arrays are a code smell;
  vectorized NumPy first, Numba when that's not enough, Rust/PyO3 for hot paths.
- **DRY & YAGNI.**

## Tooling
- **`pixi`** for envs/deps (see the `pixi` skill); **`uv`** for one-off scripts with
  niche deps (avoid sprawling to >6 pixi envs); **`dvc`** for data.

# Maintained packages
I maintain **seqpro**, **genoray**, **genvarloader**, **genvarformer** — treat bugs
and features in these as first-party, not external deps.
<!-- END dlaub-togo:global_claude.md -->
```

### Changed: `setup_bash.sh`

Replace the current lines:

```bash
mkdir -p "${HOME}/.claude"
printf '%s\n' 'When using superpowers:subagent-driven-development, always use Sonnet for implementation tasks.' > "${HOME}/.claude/CLAUDE.md"
rtk init --global
```

with:

```bash
# LLM global instructions: idempotently sync global_claude.md into ~/.claude/CLAUDE.md
CLAUDE_MD="${HOME}/.claude/CLAUDE.md"
mkdir -p "${HOME}/.claude"
touch "${CLAUDE_MD}"
# strip any previously-synced block (inclusive of markers), then append the current one
awk '/<!-- BEGIN dlaub-togo:global_claude.md -->/{skip=1} !skip; /<!-- END dlaub-togo:global_claude.md -->/{skip=0}' "${CLAUDE_MD}" > "${CLAUDE_MD}.tmp"
cat global_claude.md >> "${CLAUDE_MD}.tmp"
mv "${CLAUDE_MD}.tmp" "${CLAUDE_MD}"
rtk init --global
```

The `cat global_claude.md` uses a repo-relative path, consistent with other
`setup_bash.sh` steps (e.g. `cp statusline-command.sh ...`, `cat aliases.sh >> ...`).

## Verification

- Run `setup_bash.sh` on a machine with no `~/.claude/CLAUDE.md` → file created
  containing exactly the marked block.
- Run again → no duplication; block content identical.
- Pre-seed `~/.claude/CLAUDE.md` with unrelated content (e.g. `@RTK.md`) → that
  content survives; only the marked block is added/replaced.
- Edit `global_claude.md`, re-run → the block in `~/.claude/CLAUDE.md` reflects
  the edit.

## Out of scope

- No changes to `@RTK.md` handling — that import is managed by `rtk init --global`.
- The `returns` and `pixi` skills referenced in the content are added separately
  (the `returns` skill is being authored in `dlaub-togo/skills`).
