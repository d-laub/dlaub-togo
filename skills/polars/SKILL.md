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
larger data. Code that aligns the join output positionally (`hstack`, assigning a
numpy array or `pl.Series`, indexing) then breaks silently in production.

`how="left"` does **not** save you: it controls which keys are kept, not row
order. A left join can still reorder its output relative to the left frame.

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
| `df.join(meta, on="id")` then `hstack` / assigning a positional array or `Series` | Pass `maintain_order="left"` — the join may reorder relative to the array. |
| "A left join keeps the left frame's order" | False. `how="left"` controls which keys are kept, not row order. Order is governed by `maintain_order`. |
| Trusting order because a small test passed | Small data hides reordering. Set `maintain_order` rather than relying on observed behavior. |
| `df.join(meta, "id", maintain_order="left")` positionally | `maintain_order` is keyword-only — pass it as a keyword. |
| Reaching for `maintain_order` on every join | Only needed when order matters downstream. Omit it (faster) when you re-sort or treat output as a set. |
