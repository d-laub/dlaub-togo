# Global CLAUDE.md sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a `global_claude.md` in the repo and have `setup_bash.sh` idempotently sync it into `~/.claude/CLAUDE.md`.

**Architecture:** `global_claude.md` (single source of truth, wrapped in sentinel markers) is appended into `~/.claude/CLAUDE.md` after stripping any prior copy of the marked block. Idempotent and self-updating; preserves other content in the target file.

**Tech Stack:** Bash, `awk`. No build/test framework — verification is a bash idempotency check.

## Global Constraints

- Marker strings must be exactly `<!-- BEGIN dlaub-togo:global_claude.md -->` and `<!-- END dlaub-togo:global_claude.md -->`.
- `global_claude.md` content is verbatim from the design spec (`docs/superpowers/specs/2026-06-17-global-claude-md-design.md`).
- `cat global_claude.md` uses a repo-relative path, consistent with existing `setup_bash.sh` steps.
- Do not touch `@RTK.md` handling — managed by `rtk init --global`.

---

### Task 1: Create `global_claude.md` and update `setup_bash.sh`

**Files:**
- Create: `global_claude.md` (repo root)
- Modify: `setup_bash.sh` (replace current lines 33–34 mkdir + printf overwrite; keep `rtk init --global`)

**Interfaces:**
- Produces: a repo-root `global_claude.md` whose first line is the subagent-driven-development instruction, wrapped in the BEGIN/END markers; `setup_bash.sh` reads it via `cat global_claude.md`.

- [ ] **Step 1: Create `global_claude.md`**

Write this file at the repo root, verbatim:

````markdown
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
````

- [ ] **Step 2: Replace the overwrite logic in `setup_bash.sh`**

Find these three lines (currently lines 33–35):

```bash
mkdir -p "${HOME}/.claude"
printf '%s\n' 'When using superpowers:subagent-driven-development, always use Sonnet for implementation tasks.' > "${HOME}/.claude/CLAUDE.md"
rtk init --global
```

Replace with:

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

- [ ] **Step 3: Verify idempotency + non-destruction in a sandbox**

Run this self-contained check (uses a temp HOME and the real `global_claude.md`/`awk` logic):

```bash
cd "$(git rev-parse --show-toplevel)"
TMP="$(mktemp -d)"
CLAUDE_MD="${TMP}/CLAUDE.md"
sync() {
  touch "${CLAUDE_MD}"
  awk '/<!-- BEGIN dlaub-togo:global_claude.md -->/{skip=1} !skip; /<!-- END dlaub-togo:global_claude.md -->/{skip=0}' "${CLAUDE_MD}" > "${CLAUDE_MD}.tmp"
  cat global_claude.md >> "${CLAUDE_MD}.tmp"
  mv "${CLAUDE_MD}.tmp" "${CLAUDE_MD}"
}
printf '%s\n' '@RTK.md' > "${CLAUDE_MD}"   # pre-existing unrelated content
sync; sync; sync                            # three runs
echo "--- BEGIN-marker count (expect 1):"; grep -c 'BEGIN dlaub-togo' "${CLAUDE_MD}"
echo "--- @RTK.md preserved (expect 1):"; grep -c '@RTK.md' "${CLAUDE_MD}"
rm -rf "${TMP}"
```

Expected output:
```
--- BEGIN-marker count (expect 1):
1
--- @RTK.md preserved (expect 1):
1
```

- [ ] **Step 4: Commit**

```bash
git add global_claude.md setup_bash.sh
git commit -m "Add global_claude.md and sync it idempotently in setup_bash.sh"
```
