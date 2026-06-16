# Polars Sharp-Edges Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a minimal `polars` skill that catches the one sharp edge agents reliably miss — the keyword-only `maintain_order` argument of `DataFrame.join` / `LazyFrame.join`.

**Architecture:** A single-file reference skill at `skills/polars/SKILL.md` in the `dlaub-togo` repo. Built via the writing-skills TDD cycle: establish a failing baseline (subagent omits `maintain_order` on an order-sensitive join), write the minimal skill, verify a fresh subagent now passes `maintain_order` explicitly. Deliberately covers only the `maintain_order` edge — the rest of polars is well-covered by LLM training data, and extra content would dilute discovery.

**Tech Stack:** Markdown + YAML frontmatter (agentskills.io skill format). Polars (Python). Subagents for testing.

---

## Background: the sharp edge

`DataFrame.join` (and `LazyFrame.join`) takes a keyword-only `maintain_order` argument:

```
maintain_order : {'none', 'left', 'right', 'left_right', 'right_left'}
```

- `'none'` is the **default**. Row order of the result is **not guaranteed** and may differ across polars versions, runs, or data sizes.
- `'left'` / `'right'` preserve that frame's order; `'left_right'` / `'right_left'` preserve both in priority order.

The trap: with small data the result usually *happens* to come back in left-frame order, so tests pass. On larger data (multi-threaded hash joins) the order changes, silently breaking any downstream code that assumes positional alignment. This has broken multiple real downstream uses.

## File Structure

- Create: `skills/polars/SKILL.md` (absolute: `/Users/david/projects/dlaub-togo/skills/polars/SKILL.md`) — the entire skill (self-contained, no supporting files). It joins the existing project skills under `skills/` and is committed to the `dlaub-togo` repo.

---

### Task 1: RED — Establish the failing baseline

Confirm that a subagent WITHOUT the skill omits `maintain_order` on an order-sensitive join. This is "watch the test fail." Do not write the skill until you have observed this.

**Files:**
- None (observation only — record findings in your task notes)

- [ ] **Step 1: Dispatch a baseline subagent with the order-sensitive scenario**

Use the Agent tool (`subagent_type: general-purpose`). Do NOT mention the skill, `maintain_order`, or ordering. Use this exact prompt:

```
You are working in a Python project that uses polars.

I have two polars DataFrames:

    df = pl.DataFrame({
        "sample_id": [...],   # ~50k rows, in a specific order I care about
        "value": [...],
    })
    meta = pl.DataFrame({
        "sample_id": [...],   # same ids, arbitrary order
        "group": [...],
    })

`df` is already sorted the way my downstream code expects. I have a separate
numpy array `weights` that is aligned positionally to df's current row order.

I want to attach the `group` column from `meta` onto `df` so that I can then do
`df.with_columns(weight=pl.Series(weights))`. Write the code to produce the
joined DataFrame. Return only the code.
```

- [ ] **Step 2: Record the baseline behavior verbatim**

Capture the subagent's code and note:
- Did it call `.join(...)` with NO `maintain_order`? (Expected: yes — this is the failure.)
- Did it assume the join preserves `df`'s row order? (Expected: yes.)
- Any rationalization about ordering (e.g. "left joins keep left order")? Record the exact wording — it becomes a Common-Mistakes row.

Expected outcome: the subagent writes `df.join(meta, on="sample_id", how="left")` (no `maintain_order`) and then positionally attaches `weights`, which is the latent bug.

- [ ] **Step 3: Confirm RED before proceeding**

If the baseline subagent already passed `maintain_order="left"` unprompted, STOP — the skill may be unnecessary or the scenario too leading. Re-read the scenario and make it more realistic rather than writing a skill nobody needs. Otherwise, proceed to Task 2.

---

### Task 2: GREEN — Write the minimal skill

**Files:**
- Create: `skills/polars/SKILL.md`

- [ ] **Step 1: Write the skill file**

Write `/Users/david/projects/dlaub-togo/skills/polars/SKILL.md` with exactly this content:

````markdown
---
name: polars
description: Use when writing or modifying Python code that calls polars `DataFrame.join` or `LazyFrame.join` and any downstream step depends on the result's row order — attaching a looked-up column back onto order-sensitive data, positional alignment with a numpy array or `pl.Series`, `hstack`, or reproducible output. Skip for joins whose output you immediately re-sort or treat as an unordered set.
---

# Polars sharp edges

Most of polars is well covered by training data. This skill documents only the
edges that don't surface in small-data tests and so get missed.

## `join` does not preserve row order by default

`DataFrame.join` and `LazyFrame.join` take a **keyword-only** `maintain_order`
argument that defaults to `'none'`:

```python
# ❌ Result row order is NOT guaranteed. It may match the left frame on small
#    data, then differ on larger data, across runs, or across polars versions.
result = df.join(meta, on="sample_id", how="left")

# ✅ Preserve the left frame's order explicitly when downstream code relies on it.
result = df.join(meta, on="sample_id", how="left", maintain_order="left")
```

The danger is that the default *usually looks ordered* on the small inputs you
test with — polars only reorders once the multi-threaded hash join kicks in on
larger data. Code that aligns the join output positionally (assigning a numpy
array or `pl.Series`, `hstack`, indexing) then breaks silently in production.

**Rule:** if anything after the join depends on row order, pass `maintain_order`
explicitly. Don't infer order from observed behavior.

## `maintain_order` values

| Value | Meaning |
|---|---|
| `'none'` (default) | No guaranteed order; fastest. May change across versions/runs/data size. |
| `'left'` | Preserve the left frame's row order. |
| `'right'` | Preserve the right frame's row order. |
| `'left_right'` | Preserve left order first, then right. |
| `'right_left'` | Preserve right order first, then left. |

For "join a lookup table onto my frame and keep my frame's order" — the common
case — use `maintain_order="left"`.

## Common mistakes

| Mistake | Fix |
|---|---|
| `df.join(meta, on="id")` then attaching a positional array/`Series` | Pass `maintain_order="left"` — the default order is not guaranteed. |
| "A left join keeps the left frame's order" | False. `how="left"` controls which keys are kept, not row order. Order is governed by `maintain_order`. |
| Trusting order because a small test passed | Small data hides reordering. Set `maintain_order` rather than relying on observed behavior. |
| `df.join(meta, "id", maintain_order="left")` positionally | `maintain_order` is keyword-only — pass it as a keyword. |
| Reaching for `maintain_order` on every join | Only needed when order matters downstream. Omit it (faster) when you re-sort or treat output as a set. |
````

- [ ] **Step 2: Verify the frontmatter and word count**

Run:

```bash
head -3 skills/polars/SKILL.md
awk '/^---$/{c++; next} c==1{n+=length($0)+1} c>=2{exit} END{print "frontmatter chars (approx):", n}' skills/polars/SKILL.md
wc -w skills/polars/SKILL.md
```

Expected:
- Line 1 is `---`, line 2 begins `name: polars`, line 3 begins `description: Use when`.
- Frontmatter well under 1024 chars.
- Word count comfortably under 500 (this skill is intentionally tiny).

---

### Task 3: GREEN — Verify a subagent now complies

Run the same scenario WITH the skill available and confirm the fix.

**Files:**
- None (verification only)

- [ ] **Step 1: Dispatch a fresh subagent that can use the skill**

Use the Agent tool (`subagent_type: general-purpose`). Prepend this line to the EXACT scenario prompt from Task 1, Step 1:

```
Before answering, check your available skills (use the Skill tool) for any that apply to this task and follow them.
```

(The scenario text itself stays identical — still no mention of `maintain_order` or ordering.)

- [ ] **Step 2: Confirm GREEN**

Inspect the returned code. Expected:
- It invokes the `polars` skill (or otherwise produces a join with `maintain_order="left"`).
- The join is `df.join(meta, on="sample_id", how="left", maintain_order="left")`.

If the subagent still omits `maintain_order`, the skill failed its test. REFACTOR: identify the new rationalization, add an explicit Common-Mistakes row countering it, and re-run this task. Do not declare success until a subagent passes.

- [ ] **Step 3: Spot-check discovery framing**

Confirm the `description` reads as triggering conditions only (starts with "Use when", names `join`/row order/positional alignment) and does NOT summarize the skill's body. This keeps Claude from acting on the description alone and skipping the skill content.

---

### Task 4: Deploy — commit the skill

**Files:**
- Commit: `skills/polars/SKILL.md` (and optionally this plan)

- [ ] **Step 1: Confirm the skill is in place**

```bash
ls -la skills/polars/SKILL.md
```

Expected: file exists alongside the other project skills (`autoresearch-setup/`, `pixi/`, etc.).

- [ ] **Step 2: Commit the skill**

```bash
git add skills/polars/SKILL.md docs/superpowers/plans/2026-06-16-polars-sharp-edges-skill.md
git commit -m "skills: add polars skill for join maintain_order sharp edge"
```

Expected: commit succeeds on `main` (or a feature branch per your workflow).

---

## Self-Review

**Spec coverage:** The spec asks for an extremely minimal polars skill covering exactly one sharp edge — `maintain_order` on `DataFrame.join`. Task 2 produces a skill covering only that edge, with the non-determinism-on-large-data warning the user emphasized. ✅

**Placeholder scan:** The skill content is given in full; test scenarios are given verbatim; commands have expected output. No TBD/TODO/"add appropriate X". ✅

**Type/name consistency:** Skill name `polars`, path `~/.claude/skills/polars/SKILL.md`, and argument `maintain_order` with values `none`/`left`/`right`/`left_right`/`right_left` are used consistently across all tasks. ✅
