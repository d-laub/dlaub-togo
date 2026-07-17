---
name: performant-py-rust
description: Use when making Python or Rust code faster, optimizing a slow function or hot loop, chasing a performance bottleneck, or deciding whether to vectorize / parallelize / rewrite in Rust — before changing any code to improve its speed. Covers CPU-bound and IO-bound work (single-thread, multicore, async); not GPU.
---

# Performant Python & Rust

## Core principle

**Every optimization is a hypothesis; a benchmark is the only thing that confirms it.**

Never optimize code you haven't measured, and never keep a change that doesn't move a benchmark you trust. Fast-but-wrong is worthless, so correctness is re-checked on every change. This is TDD for speed: the correctness oracle and the benchmark are your test; the optimization is the code that has to pass both.

The failure this skill prevents is not laziness — it's **skipping steps that feel unnecessary because the answer seems obvious**: guessing input sizes, guessing the hot spot, asserting "this should be faster," and shipping without confirming the win scales. On a toy loop you get away with it. On real code you optimize the wrong axis, at the wrong hot spot, and can't prove you helped.

## The workflow

Copy this checklist into your working notes and fill each slot in before moving on. **A blank slot means you're guessing.**

```
Optimization run:
- [ ] Phase 0 — Target: <e.g. "32×20k batch < 50 ms">   Evidence this code is the bottleneck: <...>
- [ ] Phase 1 — Dimensions table filled   Dominating dim: <...>   Bound: <cpu | memory | io>
- [ ] Phase 2 — Target O(<...>) along <dim>   Approach: <lever>
- [ ] Phase 3 — Correctness oracle ✓   Parameterized benchmark ✓   Baseline: <number + units>
- [ ] Phase 4 — Profiled hot spot: <...>   change → re-measure → correctness ✓ (repeat)   Stopped because: <...>
```

### Phase 0 — Is optimization warranted?

The cheapest optimization is the one you don't do. Before anything:

- Is there a **measured** problem or a **concrete target** (a latency, throughput, or memory budget)?
- Is this code actually on the hot path?

If nothing has measured this as slow, stop and measure first, or don't optimize it (YAGNI). Don't gold-plate a prototype or a cold path.

**Artifact:** one sentence — the target, and the evidence this code is the bottleneck.

### Phase 1 — Characterize the workload

Performance is meaningless without knowing what runs through the code.

- List **every input dimension**: rows, columns, sequence length, batch size, number of variants, alphabet size, file size, request rate…
- For each, get the **realistic range and the max**, and mark which dimension(s) **dominate or grow without bound** in real use. This one decision drives the whole design — optimize the wrong axis and the work is wasted.
- Determine the **bound**: is the work **CPU-bound**, **memory-bandwidth-bound**, or **IO/latency-bound**? This picks the levers in Phase 2 (and decides parallelism vs. concurrency).

**Do not fabricate sizes.** Derive them from the code and the data, and confirm the ranges with the user — they know the real workload; you are guessing. If you genuinely cannot reach the user, write each assumed range down as an explicit assumption and make the Phase-3 harness **sweep** it rather than hardcoding one guess.

**Artifact — dimensions table:**

| dimension | typical | max | grows? | notes |
|-----------|---------|-----|--------|-------|
| n_genes   | 20,000  | 60,000 | fixed | dominates inner cost |
| n_samples | 32      | ~1,000 | grows per study | parallelizable |

### Phase 2 — Design for the dominating dimension

- Aim for the best **practical** asymptotic behavior along the dominating dimension(s).
- **Practical caveats beat pure asymptotics.** Constant factors, cache behavior, and SIMD-friendliness usually decide the winner at real sizes. Don't reach for galactic algorithms (Strassen matmul and friends) whose crossover point is past your real N. Pick **memory layout for the access pattern**: contiguous arrays, struct-of-arrays over array-of-structs, avoid pointer-chasing.
- **Match the lever to the bound:**

| Bound | Lever |
|-------|-------|
| CPU-bound, Python | Climb the ladder only as far as the target needs: **vectorized NumPy/Polars → Numba → Rust/PyO3.** Stop at the first rung that hits the target. |
| CPU-bound, either | **Data parallelism** (rayon in Rust; multiprocessing/joblib or a GIL-releasing extension in Python) — only *after* single-thread is tuned. |
| IO/latency-bound | **Concurrency**, not cores: async (asyncio/tokio) or threads to overlap waits. |
| Memory-bandwidth-bound | Fewer passes, fewer allocations, better layout. More cores won't help. |

**Artifact:** one line — `target O(<...>) along <dim>; approach: <lever>`.

### Phase 3 — Build the harness before optimizing

Two artifacts, both **before** you touch the code for speed. See `tools.md` for tool specifics.

1. **Correctness oracle.** Keep the current/naive implementation as the reference. Assert every candidate's output equals it — exactly, or to a documented tolerance — over representative **and** edge cases (empty, all-zeros, degenerate, unequal lengths). A candidate that fails the oracle is not a faster version; it's a bug. This is the one step the baseline agents did well — keep doing it.

2. **Parameterized benchmark + baseline number.** Use the **smallest input that is representative of the regime that matters**: big enough that the dominating cost dominates (not lost in call overhead or noise), small enough to run in ~seconds so you can iterate. Parameterize by the Phase-1 dimensions and **sweep the dominating one to confirm the scaling you designed for** — don't just assert "it's faster at real N." Control noise (warmup, multiple reps, report median/min + spread); prefer `criterion` (Rust) / `pytest-benchmark` or `timeit` (Python) over hand-rolled timing. **Record the baseline number now** — it's what every change is measured against.

Minimal Python harness embodying oracle + sweep + baseline:

```python
import timeit, numpy as np

def reference(*args): ...   # current/naive implementation = the oracle
def candidate(*args): ...   # optimized version under test

def make_inputs(n_samples, n_genes, n_blacklist, seed=0):
    rng = np.random.default_rng(seed)
    ...
    return counts, lengths, blacklist

# 1. Correctness: representative + degenerate cases must match the oracle.
for shape in [(4, 100, 5), (8, 4000, 0), (2, 10, 10)]:      # last = all-blacklisted
    a = make_inputs(*shape)
    assert np.allclose(candidate(*a), reference(*a), equal_nan=True), shape

# 2. Benchmark: sweep the DOMINATING dimension; report best-of-k to cut noise.
for n_genes in (2_000, 20_000, 200_000):
    a = make_inputs(32, n_genes, 500)
    t = min(timeit.repeat(lambda: candidate(*a), number=5, repeat=5)) / 5
    print(f"n_genes={n_genes:>7}: {t*1e3:8.3f} ms/call")   # confirm the scaling curve
```

### Phase 4 — Measure → optimize → repeat

Loop until diminishing returns:

1. **Profile to find the actual hot spot — don't guess it.** By Amdahl's law only the biggest slice is worth your time. Python: `pyinstrument` (default). Rust: `samply` / flamegraph. Full tool set and platform notes in `tools.md`.
2. Form **one** hypothesis, make **one** change, re-run the oracle **and** the benchmark. Keep it only if it wins *and* stays correct; revert otherwise.
3. **For compiled/Rust changes, verify the mechanism — don't assert it.** Use `cargo-show-asm` to confirm the compiler actually vectorized, inlined, or dropped bounds checks. "This should autovectorize" is a hypothesis until you've read the asm.
4. Re-profile — the hot spot moves — and repeat.

**Stop when** you've hit the Phase-0 target, **or** the next hot spot's share is too small to matter (Amdahl ceiling), **or** the remaining gain isn't worth the added complexity/maintenance. State which one stopped you.

## Red flags — you're guessing

| Sign | Fix |
|------|-----|
| Editing for speed before profiling | Profile first — you don't know the hot spot |
| No baseline number recorded | You can't claim a speedup you didn't measure |
| No correctness oracle | You may be shipping fast garbage |
| Benchmark size chosen by vibes | You're measuring overhead or noise, not the workload |
| "This should vectorize / be faster" with no asm and no benchmark | A hypothesis stated as a fact — confirm it |
| Optimizing code no profile says is hot | Premature; likely wasted effort |
| "Scales better at real N" without sweeping N | Unverified — sweep the dimension |
| Fabricated "realistic" input sizes | Derive from data / ask the user; the dominating dim decides everything |

## Quick reference

| Phase | Required artifact | Primary tools |
|-------|-------------------|---------------|
| 0 Warranted? | Target + bottleneck evidence | — |
| 1 Characterize | Dimensions table + bound | profiler on real inputs |
| 2 Design | Target complexity + lever | — |
| 3 Harness | Correctness oracle + swept benchmark + baseline | criterion / pytest-benchmark / timeit |
| 4 Optimize | Profile → change → re-measure loop | pyinstrument; samply, cargo-show-asm |

**Tooling, install commands, and the macOS-vs-Linux tool matrix (perf/callgrind are Linux-only):** see `tools.md`.
