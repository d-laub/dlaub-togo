# Profiling & benchmarking tools (Python + Rust)

Reference for `performant-py-rust`. Nothing here is assumed installed — install commands are given. Prefer `uv run --with <pkg>` for throwaway Python harnesses so you don't mutate a project env.

## Contents

- [Pick a tool by goal](#pick-a-tool-by-goal)
- [Python: profilers](#python-profilers)
- [Python: benchmarking](#python-benchmarking)
- [Python: the speed ladder](#python-the-speed-ladder)
- [Rust: benchmarking](#rust-benchmarking)
- [Rust: profilers](#rust-profilers)
- [Rust: verify the mechanism (asm)](#rust-verify-the-mechanism-asm)
- [Rust: parallelism & concurrency](#rust-parallelism--concurrency)
- [Crossing the Python↔Rust boundary (PyO3)](#crossing-the-pythonrust-boundary-pyo3)
- [Platform matrix (macOS vs Linux)](#platform-matrix-macos-vs-linux)
- [Noise control checklist](#noise-control-checklist)

## Pick a tool by goal

| Goal | Python | Rust |
|------|--------|------|
| Find the hot spot (call tree) | `pyinstrument` | `samply`, `cargo flamegraph` |
| Line-level cost | `line_profiler` | `samply` (source view) |
| CPU **and** memory | `scalene` | heaptrack (Linux), Instruments (macOS) |
| Profile a live/prod process | `py-spy` | `samply --pid` |
| Trustworthy timing numbers | `pytest-benchmark`, `timeit` | `criterion`, `divan` |
| Deterministic instruction counts (CI-stable) | — | `valgrind --tool=callgrind`, `iai-callgrind` *(Linux)* |
| Did it vectorize / inline? | — | `cargo-show-asm` |
| Whole-binary / CLI timing | `hyperfine` | `hyperfine` |

## Python: profilers

**pyinstrument** — default. Statistical (low overhead), shows a wall-clock call tree that hides its own frames.
```bash
uv run --with pyinstrument pyinstrument script.py        # whole script
```
```python
from pyinstrument import Profiler
with Profiler() as p: hot_function()
p.print()                                                # or p.open_in_browser()
```

**line_profiler** — line-by-line time inside a chosen function. Decorate with `@profile`, then:
```bash
uv run --with line_profiler kernprof -l -v script.py
```

**scalene** — CPU + memory (+ copy volume) together; good for finding hidden allocations/copies.
```bash
uv run --with scalene scalene script.py
```

**py-spy** — samples an already-running process by PID, no code change, safe in production.
```bash
uv run --with py-spy py-spy record -o out.svg --pid <PID>   # flamegraph
uv run --with py-spy py-spy top --pid <PID>                 # live top-like view
```

`cProfile` (stdlib) is deterministic but has high overhead that distorts many-small-call code; prefer `pyinstrument`.

## Python: benchmarking

**timeit** (stdlib) — fine for micro-benchmarks; take the min of `repeat` to cut noise:
```python
import timeit
best = min(timeit.repeat(lambda: f(x), number=100, repeat=7)) / 100
```

**pytest-benchmark** — statistics, comparison, regression tracking:
```python
def test_speed(benchmark):
    result = benchmark(f, x)      # runs warmup + many reps, reports mean/median/stddev
```
```bash
uv run --with pytest-benchmark pytest --benchmark-only
```

## Python: the speed ladder

Climb only as far as the Phase-0 target needs; stop at the first rung that hits it.

1. **Vectorize** — replace Python loops over arrays/rows with NumPy broadcasting or Polars expressions. Usually the biggest single win; multiply-by-reciprocal beats repeated divides; operate in-place to avoid extra full-size allocations. Choose whichever of NumPy (dense numeric) or Polars (tabular/columnar) fits the data.
2. **Numba** — `@njit(cache=True)` for numeric kernels that don't vectorize cleanly; `parallel=True` + `prange` for multicore. Adds a compile/warmup cost — worth it only when vectorization can't express the kernel. Verify the mechanism like you would Rust asm: `func.parallel_diagnostics(level=4)` shows whether `prange` actually parallelized and which loops fused; `func.inspect_types()` shows lowering. Time only the *second* call — the first pays JIT compilation.
3. **Rust/PyO3** — for hot paths that are neither vectorizable nor Numba-friendly, or that need real threading. See the PyO3 boundary section below.

## Rust: benchmarking

Always benchmark a `--release` build. Never trust debug-build numbers.

**criterion** — statistical benchmarking with warmup, outlier detection, and regression comparison across runs.
```toml
# Cargo.toml
[dev-dependencies]
criterion = { version = "0.5", features = ["html_reports"] }
[[bench]]
name = "hamming"
harness = false
```
```rust
// benches/hamming.rs
use criterion::{criterion_group, criterion_main, Criterion, black_box};
fn bench(c: &mut Criterion) {
    let (q, db) = make_inputs(/* sweep the dominating dim here */);
    c.bench_function("count_neighbors/len100", |b| {
        b.iter(|| count_neighbors(black_box(&q), black_box(&db), 3))
    });
}
criterion_group!(benches, bench);
criterion_main!(benches);
```
```bash
cargo bench                      # re-run after a change; criterion reports % change
```
`black_box` stops the optimizer from deleting the work under test. **divan** is a lighter modern alternative. **hyperfine** (`brew install hyperfine`) times whole binaries/CLIs.

## Rust: profilers

**samply** — cross-platform sampler (macOS + Linux); records a release binary and opens the Firefox Profiler UI. The go-to on macOS.
```bash
cargo install samply
samply record ./target/release/mybench        # or: samply record --pid <PID>
```

**cargo-flamegraph** — one-shot flamegraph. Uses `perf` on Linux, `dtrace` on macOS (needs sudo).
```bash
cargo install flamegraph
cargo flamegraph --bench hamming
```

**perf** *(Linux only)* — the standard sampling profiler + counters:
```bash
perf record -g ./target/release/mybench && perf report
perf stat ./target/release/mybench            # cycles, cache-misses, IPC
```

**valgrind callgrind / cachegrind** *(Linux only; effectively unavailable on Apple Silicon macOS)* — deterministic instruction and cache-miss counts, immune to machine noise, so ideal for **CI regression gates** and tiny reproducible cases. The **iai-callgrind** crate wraps this into stable per-benchmark counts.
```bash
valgrind --tool=callgrind ./target/release/mybench   # instructions per call site
valgrind --tool=cachegrind ./target/release/mybench  # cache misses
```
On macOS, when you need deterministic counts, run these in a Linux container or in CI. Otherwise use `samply` for sampling and Instruments (`xcrun xctrace record --template "Time Profiler" --launch ./bin`) for native detail.

## Rust: verify the mechanism (asm)

Don't assert "it autovectorized / inlined / dropped bounds checks" — read it.

**cargo-show-asm** (cross-platform):
```bash
cargo install cargo-show-asm
cargo asm --rust mycrate::within_hamming     # asm interleaved with source
cargo asm --llvm mycrate::within_hamming     # LLVM IR
```
Look for SIMD instructions (NEON `*.16b` on aarch64; `xmm`/`ymm` on x86-64), absence of `panic`/bounds-check branches, and that small helpers were inlined. [Compiler Explorer](https://godbolt.org) is handy for quick isolated checks.

Release-build knobs that change what you'll see (`Cargo.toml`):
```toml
[profile.release]
lto = "fat"            # cross-crate inlining
codegen-units = 1      # better optimization, slower compile
```
`RUSTFLAGS="-C target-cpu=native"` unlocks the host's widest SIMD — but the binary stops being portable, so gate it to local/known-hardware runs. Avoid bounds checks idiomatically: prefer `iter().zip()`, `chunks_exact()`, and slicing once over indexing `a[i]` in loops.

## Rust: parallelism & concurrency

- **rayon** (`rayon = "1"`) — data parallelism for CPU-bound work: swap `.iter()` for `.par_iter()`. Apply only after single-thread is tuned; measure — it isn't free at small N.
- **std::thread / crossbeam** — manual threading, scoped threads.
- **tokio** (`async`) — concurrency for IO/latency-bound work (many network/disk waits overlapped). Not a speedup for CPU-bound code.

## Crossing the Python↔Rust boundary (PyO3)

- Build with **maturin** (`maturin develop --release` for an editable fast build). Debug builds are slow — always `--release` when measuring.
- **FFI calls have per-call overhead.** Cross the boundary in **batches** (pass whole arrays, not element-by-element). Accept NumPy arrays via `numpy`/`rust-numpy` and operate on slices.
- **Release the GIL** with `py.allow_threads(|| ...)` around heavy Rust so it can run in parallel with Python threads (and internally use rayon).
- **Profile both sides:** confirm with `pyinstrument` that the Rust call is actually the cost on the Python side, then profile the Rust kernel separately with `samply` on a standalone `--release` harness. A slow PyO3 path is often boundary overhead or a debug build, not the algorithm.

## Platform matrix (macOS vs Linux)

| Tool | macOS (darwin) | Linux |
|------|----------------|-------|
| pyinstrument, py-spy, scalene, line_profiler | ✓ | ✓ |
| pytest-benchmark, timeit | ✓ | ✓ |
| criterion, divan, hyperfine | ✓ | ✓ |
| cargo-show-asm | ✓ | ✓ |
| samply | ✓ | ✓ |
| cargo flamegraph | ✓ (dtrace, sudo) | ✓ (perf) |
| Instruments / xctrace | ✓ (Xcode) | — |
| perf | — | ✓ |
| valgrind callgrind/cachegrind, iai-callgrind | ✗ (Apple Silicon) | ✓ |

On macOS default to **samply + cargo-show-asm + criterion**; reach for a Linux container or CI when you specifically need `perf` counters or deterministic `callgrind` instruction counts.

## Noise control checklist

- Build/measure in **release** (Rust `--release`); never benchmark debug builds.
- **Warm up**, then take **min or median** of many reps (criterion/pytest-benchmark do this for you).
- Quiet the machine: close background load, keep laptops plugged in, watch for **thermal throttling** on long runs.
- For stable counters on Linux: performance CPU governor, disable turbo, pin to a core (`taskset`). On macOS you can't pin easily — prefer deterministic counts (callgrind in a container) when noise dominates.
- Report the number **with units and the input size** it was measured at, alongside the baseline.
