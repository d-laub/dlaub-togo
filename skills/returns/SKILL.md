---
name: returns
description: Use when writing or modifying Python library code that imports `returns` (dry-python/returns) — Result/ResultE, Maybe, IO/IOResult, Future/FutureResult, @safe/@impure_safe/@future_safe, .bind/.map, do-notation, flow/pipe, pointfree. Also when a returns-using project is type-checked with pyrefly (no mypy plugin) and HKT types like KindN leak as false positives. Covers which container fits which failure, bind-vs-map, staying in the container, exposing containers in a public API, and pyrefly config.
---

# Using `returns` in downstream library code

Basic `returns` usage (Success/Failure, `.bind`, `@safe`) is covered by training
data. This skill targets the edges that get missed: picking the right container,
keeping the IO/async markers, not bailing out of the container early, designing a
public API around it, and the **pyrefly type-checker reality** (returns ships a
*mypy* plugin that no other checker can run).

## Pick the container by the *kind* of failure

The most common miss is collapsing distinct failure kinds onto `Result`. Match
the container to what can go wrong:

| Situation | Container | How to produce it |
|---|---|---|
| Value may be **absent** (missing key, `None`, empty) — not an error | `Maybe[A]` | `Maybe.from_optional(x)`, `@maybe` |
| Pure computation that may **fail with info** | `Result[A, E]` / `ResultE[A]` | `@safe`, `Success`/`Failure` |
| **Impure** action that never fails (random, clock, env, print) | `IO[A]` | `IO(...)`, `@impure` |
| **Impure** action that may fail (network, disk, DB) | `IOResult[A, E]` / `IOResultE[A]` | `@impure_safe` |
| **Async** action that may fail | `FutureResult[A, E]` / `FutureResultE[A]` | `@future_safe` |
| Pure logic needing **injected dependencies** | `RequiresContext[A, Deps]` (+ `...Result`, `...IOResult`, `...FutureResult`) | construct with a `lambda deps: ...` |

**Do not use `@safe` for impure work.** A network/disk/DB call that can fail is
`IOResultE`, not `ResultE` — use `@impure_safe`. `@safe` says "pure but fallible";
using it on IO silently drops the `IO` marker that the whole library exists to
preserve. `ResultE` is the alias for `Result[A, Exception]`; `IOResultE` for
`IOResult[A, Exception]`.

```python
from returns.io import impure_safe, IOResultE
from returns.result import safe, ResultE

@impure_safe                      # ✅ network call: impure AND fallible
def fetch(user_id: int) -> dict:
    resp = requests.get(f"/users/{user_id}"); resp.raise_for_status()
    return resp.json()
# fetch(1) -> IOResultE[dict]

@safe                             # ✅ pure parse that may raise
def parse_age(raw: str) -> int:
    return int(raw)
```

## `bind` vs `map` — the cardinal rule

- `.map(f)`   — `f: A -> B`            (plain function)
- `.bind(f)`  — `f: A -> Container[B]` (function that itself returns the *same* container)

Using `.map` with a container-returning function nests the container
(`Result[Result[B, E], E]`) and the type checker won't always catch it under
pyrefly (see below). Using `.bind` with a plain function fails outright.

```python
result.map(lambda x: x + 1)          # A -> B
result.bind(parse_age)               # A -> Result[B, E]   (parse_age is @safe)
```

**Crossing container types uses a typed `bind_*`, not `.bind`.** `.bind` only
accepts the *same* container. To run a `Result`-returning step inside an
`IOResult`/`FutureResult` chain, use the bridge methods:

| In this container | Run a step returning... | Use |
|---|---|---|
| `IOResult` | `Result` | `.bind_result(f)` |
| `IOResult` | `IO` | `.bind_io(f)` |
| `FutureResult` | `Result` | `.bind_result(f)` |
| `FutureResult` | `IOResult` | `.bind_ioresult(f)` |
| `FutureResult` | a coroutine | `.bind_async(f)` |
| `Maybe` | `Optional`-returning fn | `.bind_optional(f)` |

## Stay in the container — don't unwrap early

`.unwrap()` raises on the failure case, `.failure()` raises on success, and
`._inner_value` is private. Reaching for any of them (or wrapping a container in
`try/except`) throws away the safety the container provides. Keep transforming
*inside* the container and collapse to a plain value only at the program edge.

```python
# ❌ defeats the purpose
user = fetch(1).unwrap()           # raises — back to exceptions
try:
    user = fetch(1).unwrap()
except Exception: ...

# ✅ stay in the container, collapse once at the boundary
message = (
    enrich_user(1)
    .map(lambda email: f"Email: {email}")
    .value_or("no email found")    # total: provides the failure branch
)
```

At the boundary use, in order of preference:
- `.value_or(default)` — one default for the failure branch.
- `.lash(handler)` — failure-side `bind` (recover into another container).
- `match` / `is_successful(x)` — when both branches need real handling.
- `.unwrap()` — only in tests, or right after you've already folded every
  failure into the success branch.

## Bridging between containers — use the converters, don't hand-roll

A frequent miss is reinventing `Maybe -> Result` as
`m.map(Success).value_or(Failure(err))`. The library ships the conversions:

```python
from returns.converters import maybe_to_result, result_to_maybe, flatten

maybe_to_result(maybe_email, ValueError("no email"))  # Maybe[A] -> Result[A, E]
result_to_maybe(some_result)                          # Result[A, E] -> Maybe[A]
flatten(Success(Success(1)))                           # Container[Container[A]] -> Container[A]
```

`is_successful(container)` is the boolean predicate; `partition(containers)` (from
`returns.methods`) splits an iterable of containers into `([successes], [failures])`.

## Composition: do-notation first, then flow/pointfree

For multi-step pipelines, prefer **do-notation** — it reads like imperative code
and avoids lambda soup. Each container type has its own `.do`:

```python
from returns.result import Result, Success, Failure

final: Result[int, str] = Result.do(
    x + y
    for x in parse("1")          # each `for` binds a Result; first Failure short-circuits
    for y in parse("2")
)
```

`flow(value, f1, f2, ...)` threads a value left-to-right; `pipe(f1, f2, ...)`
builds the function without a seed. With containers, the steps are **pointfree**
helpers from `returns.pointfree` (`bind`, `map_`, `bind_result`, `bind_io`,
`bind_async`, `lash`, `alt`, ...), because `flow` can't call `.bind` for you:

```python
from returns.pipeline import flow
from returns.pointfree import bind, map_

flow(user_id, fetch, bind(parse), map_(format_name))
```

Note: `map_` has a trailing underscore (avoids shadowing builtin `map`). Bare
`bind`/`map_` from pointfree act on the *first* container slot generically — see
the HKT note below for the pyrefly caveat.

## Async with Future / FutureResult

`@future_safe` turns an `async def` into a `FutureResultE`. Compose entirely
inside `FutureResult` (it stays lazy and short-circuits on first failure), then
cross the async boundary exactly once:

```python
from returns.future import future_safe, FutureResultE
from returns.io import IOResult
from returns.unsafe import unsafe_perform_io
import anyio

@future_safe
async def fetch_record(rid: int) -> dict:
    async with httpx.AsyncClient() as c:
        r = await c.get(f"/records/{rid}"); r.raise_for_status()
        return r.json()

def process(rid: int) -> FutureResultE[str]:
    return fetch_record(rid).bind_result(extract_field)   # Result step lifted in

def run(rid: int):
    # awaiting a FutureResult yields an IOResult, not a bare value.
    io_result: IOResult = anyio.run(process(rid).awaitable)
    return unsafe_perform_io(io_result)        # peel IO only at the true edge
```

Key facts agents miss: **awaiting a `FutureResult` gives an `IOResult`** (the
async IO happened, so the marker is preserved); `unsafe_perform_io` is the
*only* sanctioned way to strip `IO`, and only at the program edge. Don't
`asyncio.run` a raw `Future` and expect a plain value.

## Public API design: return the container, don't leak it

For a library's public surface:
- **Return `Result`/`Maybe`/`IOResult`** so callers see the failure mode in the
  type and compose with their own pipelines. Don't `.unwrap()` internally and
  re-raise — that erases the contract.
- **Use `ResultE`/`IOResultE` aliases** in signatures; they're shorter and signal
  "errors are exceptions" clearly.
- **Keep the IO marker in the type.** If the function does impure work, its
  public return type must be `IO*`/`Future*`. Hiding it behind `Result` lies to
  callers about purity.
- **Pick a deliberate error type.** `@safe`/`@impure_safe` capture *any*
  exception by default; narrow with `@safe(exceptions=(ValueError, KeyError))`
  when the contract should be specific.

## pyrefly + returns: the mypy plugin does NOT apply

This is the highest-value, least-obvious part. `returns` ships a **mypy plugin**
(`returns.contrib.mypy.returns_plugin`) precisely because its emulated
Higher-Kinded-Types encoding (`KindN`/`Kind1`/`Kind2`/`Kind3`, `@kinded`,
`dekind`) cannot be resolved by a structural type checker alone. **pyrefly has no
plugin system** (it hardcodes support for a fixed set like Pydantic/Django), so
under pyrefly that machinery runs unassisted.

What this means concretely (verified against pyrefly 1.0):

| Construct | Under pyrefly (no plugin) |
|---|---|
| `r.map(f)`, `r.bind(f)` on a **concrete** container (`Result`, `IOResult`, `Maybe`) | ✅ Correct — these declare concrete return types directly |
| `flow(...)` / `pipe(...)` | ⚠️ Degrades to `Unknown` — pipeline inference is plugin-only (no error, lost precision) |
| `Container.do(...)` | ⚠️ Value type kept, **error type lost** (`Result[int, Unknown]`) |
| **pointfree** `bind(f)`, `map_(f)` | ❌ Leaks `KindN[...]` — assigning the result to `Result[...]` raises `bad-assignment`; calling `.map` on it raises `not-callable` |
| your own `@kinded` / `KindN`-generic helpers | ❌ Same `KindN` leakage and false errors |

**Practical guidance for pyrefly projects:**
1. Prefer **method chaining on concrete containers** (`x.bind(f).map(g)`) and
   **do-notation** over pointfree `flow`/`bind`/`map_`. The concrete methods type
   cleanly; pointfree is where the false positives live.
2. In your own public signatures, **annotate with concrete container types**
   (`Result[int, str]`, `IOResultE[dict]`) rather than `KindN`/`@kinded` generics
   unless you genuinely need HKT polymorphism — pyrefly can't check the latter.
3. Suppress the residual false positives **surgically**, not globally:
   ```python
   applied: Result[int, str] = bind(parse)(r)  # pyrefly: ignore[bad-assignment]
   ```
   `pyrefly suppress` can auto-insert these.
4. Recommended `pyproject.toml` baseline:
   ```toml
   [tool.pyrefly]
   # don't type-check inside returns' own HKT machinery
   project-excludes = ["**/site-packages/returns/**"]
   ```
   Only if pointfree/HKT usage is pervasive and inline ignores become noisy, add:
   ```toml
   [tool.pyrefly.errors]
   bad-assignment = false   # broad — also silences real assignment errors
   not-callable   = false
   ```
   Last resort (gives up all checking of returns, including the parts that work):
   ```toml
   [tool.pyrefly]
   replace-imports-with-any = ["returns.*"]
   ```

There is **no** pyrefly config that restores HKT inference — only the mypy plugin
does that. If full HKT type-safety matters, run mypy (with the plugin) alongside
pyrefly, or stay on mypy for that codebase.

## Common mistakes

| Mistake | Fix |
|---|---|
| `@safe` on a network/disk/DB call | Use `@impure_safe` → `IOResultE`; impure work keeps the IO marker |
| `.map(f)` where `f` returns a container | Use `.bind(f)` (or `.bind_result`/`bind_io`/... to cross types) |
| `.bind(f)` where `f` returns a plain value | Use `.map(f)` |
| `.unwrap()` / `._inner_value` / `try/except` to get the value | Stay in the container; `.value_or` / `.lash` / `match` at the edge only |
| Hand-rolling `m.map(Success).value_or(Failure(e))` | `maybe_to_result(m, e)` from `returns.converters` |
| `.bind` to go `IOResult` → `Result` step | `.bind_result(f)` (the typed bridge) |
| `asyncio.run(some_future)` expecting a value | `await` a `FutureResult` → `IOResult`; `unsafe_perform_io` at the edge |
| Library internally unwraps then re-raises | Return the `Result`/`IOResult`; let callers compose |
| Pyrefly errors on pointfree `bind`/`map_` ("not callable", "bad assignment") | Expected — no mypy plugin under pyrefly; use concrete-method chaining or `# pyrefly: ignore[...]` |
| Annotating helpers with `KindN`/`@kinded` in a pyrefly project | Use concrete container types unless HKT polymorphism is truly required |
