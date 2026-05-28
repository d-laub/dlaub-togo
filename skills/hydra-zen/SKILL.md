---
name: hydra-zen
description: Use when reading or editing config code that imports hydra_zen (builds, make_custom_builds_fn, store, just, MISSING, hydrated_dataclass, kwargs_of, make_config, ZenStore, BuildsFn), or when Hydra-style "${...}" interpolations, config groups, _target_ blocks, or `builds_bases` inheritance appear in a hydra-zen project. Covers the typing model, idiomatic patterns, type-refinement gotchas, and hacks for corner cases (partial-of-partial, per-variant overrides, project-wide builder defaults).
---

# hydra-zen Fluency

## Overview

**hydra-zen is not plain Hydra.** It's a thin layer on top of Hydra/OmegaConf whose job is to **eliminate hand-written YAML and `_target_` strings** by generating structured configs from real Python callables. The two things you trade for that:

1. **Type safety**: configs are dataclasses derived from the callable's signature; missing or misspelled fields fail at config-build time, not at runtime (`builds(Foo, momtum=0.9)` raises `TypeError` immediately if `Foo` has no `momtum` kwarg).
2. **Less boilerplate (DRY)**: no `conf/` YAML tree, no `_target_: pkg.mod.Class` strings — you pass the class/function itself to `builds(...)` and hydra-zen mirrors the signature for you. Refactor the target, the config follows automatically.

If you find yourself writing a Hydra-style string where hydra-zen would accept a callable or a builder, you're working around hydra-zen instead of using it.

## When to use

Use this skill when you see any of:

- Imports from `hydra_zen` (`builds`, `make_custom_builds_fn`, `store`, `just`, `MISSING`, `hydrated_dataclass`, `kwargs_of`, `make_config`, `instantiate`, `to_yaml`, `zen`, `ZenStore`, `BuildsFn`).
- A `hydra_defaults=[...]` list passed into a `store(...)` call instead of a `defaults:` YAML block.
- `_target_` strings, `${interpolations}`, or `MISSING` sentinels in a project that uses hydra-zen.
- `builds_bases=(Parent,)` for config inheritance, or `bases=(Cfg,)` on `make_config`.
- LLM-written config that looks like Hydra YAML translated into Python kwargs.
- A "partial of partial" pattern — `functools.partial(builds_fn, target, ...)` — usually a sign someone was fighting `populate_full_signature`.

Do **not** use this skill for:

- Pure Hydra/OmegaConf projects with no `hydra_zen` import — those follow different rules (YAML is the source of truth).
- Runtime/training logic. This skill is about **config construction**, not the code that consumes the instantiated objects.

## How it works (the typing POV)

```
Hydra:      YAML files  →  OmegaConf DictConfig  →  hydra.utils.instantiate
hydra-zen:  Python      →  dataclass (via builds) →  hydra_zen.instantiate
                                ↑
                       this is the part you write
```

`builds(Foo, **kwargs)` does roughly this at import time:

1. Calls `inspect.signature(Foo)` to read parameters, defaults, and annotations.
2. Validates each kwarg you passed against that signature — typos → `TypeError` now, not at runtime.
3. **Refines** each annotation to something Hydra/OmegaConf accepts (see "Type refinement" below).
4. Generates a `@dataclass` whose fields mirror the (refined) signature, with `_target_ = "pkg.mod.Foo"` baked in.
5. Returns that dataclass *type*. `instantiate(Cls(**overrides))` constructs `Foo(**overrides)`.

Static typing: builds' overloads are typed so the returned dataclass advertises `BuildsWithSig[type[Foo], P]` where `P` is `Foo`'s `ParamSpec`. Pyright/mypy can therefore check kwargs to the *config class* against `Foo`'s signature. With `@hydrated_dataclass`, the decorator uses [`dataclass_transform`](https://typing.readthedocs.io/en/latest/spec/dataclasses.html) so the resulting class behaves like a `@dataclass` to static checkers — attribute access, frozen-ness, and field types are all visible.

### Type refinement — the silent type-widening

Hydra only accepts a narrow subset of annotations: `Any`, primitives, `Enum`, nested structured configs, `List`/`Dict` of those, `Optional`, and nested containers (OmegaConf ≥ 2.2). Everything else (`Literal`, `Union[X, Y]` of non-primitives, custom protocols, `TypedDict`, `Annotated`, etc.) will explode at instantiate time in vanilla Hydra.

hydra-zen **automatically broadens** unsupported annotations:

- `Literal[1, 2]` → `Any`
- `List[Literal[1, 2]]` → `List[Any]` (preserves container, drops inner)
- `tuple[int, ...]` → kept as-is if OmegaConf supports it; else `Tuple[Any, ...]`.

Consequences:
- Your config will instantiate, but OmegaConf will *not* enforce `Literal` membership at runtime. If you need that, layer on `pydantic`/`beartype` via `zen_wrappers=` or by decorating the target with `@pydantic.dataclasses.dataclass`.
- Static checkers still see the *original* types because hydra-zen attaches them in metadata; you don't lose IDE support — you only lose Hydra-side runtime validation for refined fields.

## The builders

| Builder | Returns | Use for |
|---|---|---|
| `builds(Foo, **kwargs)` | Dataclass type; `instantiate` returns `Foo(**kwargs)` | Concrete configs |
| `builds(Foo, zen_partial=True, ...)` | Dataclass; `instantiate` returns `functools.partial(Foo, **kwargs)` | Optimizers, schedulers, loggers — anything a framework instantiates later |
| `builds(Foo, populate_full_signature=True)` | Dataclass mirroring **every** `__init__` parameter | When you want the user to be able to override any field on the CLI |
| `make_custom_builds_fn(**defaults)` | A `builds` with pre-applied defaults | Project-wide convention (e.g. always `populate_full_signature=True`) |
| `hydrated_dataclass(target=...)` | Decorator; class body defines fields | Static-typed configs (pyright sees field types and `frozen=True`) |
| `kwargs_of(fn, **overrides)` | Dataclass that instantiates to a **`dict`** matching `fn`'s signature | "Give me a dict that has exactly these keys"; great for passing through `**kwargs` to a non-target |
| `make_config(*fields, bases=(...))` | Untargeted dataclass with named fields | Top-level "task" configs or experiment overlays — see below |
| `just(value)` | Dataclass that resolves to `value` literally | Embed a list of already-built configs, a class object, or a `functools.partial(...)` instance |
| `MISSING` | OmegaConf sentinel | Required field; defaults list must supply the value, or CLI must |

`pbuilds` (as defined in this repo) is just `make_custom_builds_fn(populate_full_signature=True, zen_partial=True)` — read it as "partial builds with full signature".

## The signature-population trap

`populate_full_signature=True` re-derives **every** field from the target's `__init__` defaults. When combined with `builds_bases=(Parent,)`, any field that was set **only on the parent** is silently overwritten by the target's own `__init__` default.

```python
# Parent sets val_splits=["train-val"]
MMDataCfg = pbuilds(CisGeneRegData, val_splits=["train-val"], ..., builds_bases=(DataCfg,))

# WRONG: populate_full_signature on the child re-derives val_splits from
# CisGeneRegData.__init__, blanking what MMDataCfg set.
MMTuneDataCfg = pbuilds(CisGeneRegData, limit_regions=TUNING_CHROM,
                        builds_bases=(MMDataCfg,))

# RIGHT: restate inherited fields explicitly when you need full-signature population.
MMTuneDataCfg = pbuilds(CisGeneRegData, limit_regions=TUNING_CHROM,
                        val_splits=["train-val"], test_splits=["train-test"],
                        builds_bases=(MMDataCfg,))

# ALSO RIGHT (idiomatic — see "Hacking" section): drop full-signature on the child.
size_builds = make_custom_builds_fn(zen_partial=True)   # no populate_full_signature
MMTuneDataCfg = size_builds(CisGeneRegData, limit_regions=TUNING_CHROM,
                            builds_bases=(MMDataCfg,))
```

Rule of thumb: **`populate_full_signature=True` + `builds_bases` does not compose** the way you'd hope. Either restate fields, or use a builder without full-signature population for child variants.

## Interpolations vs. builders vs. defaults-list relocation

`"${name}"` is an **OmegaConf interpolation** resolved against the composed config tree at instantiate time. It is a `str` sitting in a field whose annotation is something else, so it punches a hole in the type system that hydra-zen's refinement can't see through. There are two legitimate uses; for everything else there's a better tool.

### Legitimate use 1: lazy/derived values

There is no type-safe alternative for these. Interpolations are the right tool.

```python
run_dir   = "${data.dir}/${run.name}"     # compose from other tree paths
git_sha   = "${oc.env:GIT_SHA}"           # resolve env at runtime
timestamp = "${now:%Y-%m-%d}"             # built-in resolvers
```

### Legitimate use 2: wiring a group selection into a nested field (but prefer `group@pkg`)

You'll see this written with `"${...}"`:

```python
# Works, but not the most idiomatic — loss_fn is annotated nn.Module and
# gets a "${loss}" str at config-build time. Wiring is scattered across nested
# builders instead of collocated.
ModelCfg = pbuilds(CisGeneReg, loss_fn="${loss}", scheduler="${scheduler}", flags="${flags}", ...)

store(name="train", loss=MISSING, scheduler=MISSING, flags=MISSING, model=ModelCfg, ...,
      hydra_defaults=["_self_",
                      {"loss": "pairwise_mse"},
                      {"scheduler": "cosine"},
                      {"flags": "multi_baseline"}])(train)
```

**Prefer the defaults-list package relocation `group@dest.path`:** the chosen group config is installed *directly* at the destination, with no interpolation string in the typed field and all wiring collocated in one place.

```python
# Idiomatic — no "${...}" in any nested builder; ModelCfg has no top-level
# `loss` / `scheduler` / `flags` mirror fields at all.
ModelCfg = pbuilds(CisGeneReg, optimizer=OptimCfg, ...)   # no loss_fn= line

store(name="train", model=ModelCfg, ...,
      hydra_defaults=["_self_",
                      {"loss@model.loss_fn":   "pairwise_mse"},
                      {"scheduler@model.scheduler": "cosine"},
                      {"flags@model.flags":    "multi_baseline"}])(train)
# CLI: python train.py loss@model.loss_fn=gar
```

Trade-offs:
- The interpolation form requires top-level mirror fields (`loss=MISSING`, etc.) so that `${loss}` has something to resolve. The relocation form doesn't — there is no top-level `loss` field at all.
- The interpolation form means **one** group choice can broadcast to multiple destinations (`${loss}` in many places). The relocation form needs one defaults-list entry per destination. Pick interpolation for fan-out, relocation for clean wiring.
- CLI override grammar differs: `loss=pairwise_mse` (interpolation form) vs `loss@model.loss_fn=pairwise_mse` (relocation form). The latter is more verbose but more explicit.

### Wrong uses of `"${...}"` (common LLM mistakes)

| Symptom | What the LLM meant | What to write |
|---|---|---|
| `optimizer="${optimizer}"` and no `optimizer` group exists | "Pass the optimizer in" | Inline the builder: `optimizer=OptimCfg` |
| `lr="${lr}"` with a flat top-level `lr` | Parameterize a scalar | `lr=1e-4`; override on CLI: `model.lr=3e-4` |
| `_target_: "pkg.Foo"` as a string field | Specify a class | `builds(Foo, ...)` — never hand-write `_target_` |
| `"${some_group}"` for group wiring | "Resolve the group choice into this field" | Prefer `{"some_group@dest.path": "default"}` in `hydra_defaults` |

Heuristic: **if there is no matching top-level field bound to a Hydra group, `"${...}"` is wrong.** Interpolations are not generic variables — they reference paths in the composed config. And even when a matching field exists, ask whether `group@pkg` would be cleaner.

## `MISSING` + defaults list — the explicit-choice pattern

`MISSING` is only needed when a field exists in the config and must be filled by something other than its dataclass default. With **interpolation-style** group wiring you need both `MISSING` and a defaults entry; with **`group@pkg` relocation** you usually need neither, because the destination field is installed by the defaults list itself.

```python
# Interpolation form: requires the MISSING field + defaults entry pair.
store(name="train",
      loss=MISSING,                                       # required field
      scheduler=MISSING,                                  # required field
      hydra_defaults=["_self_",
                      {"loss": "pairwise_mse"},
                      {"scheduler": "cosine"}])(train)

# Relocation form: no top-level loss/scheduler fields at all; the defaults
# list installs the chosen configs directly at model.loss_fn / model.scheduler.
store(name="train",
      hydra_defaults=["_self_",
                      {"loss@model.loss_fn":      "pairwise_mse"},
                      {"scheduler@model.scheduler": "cosine"}])(train)
```

Why `MISSING` matters in the interpolation form: it says "this field must be set". Drop the defaults-list entry and the CLI must pass `loss=...` every run; drop `MISSING` and a typo silently leaves the field at its dataclass default.

## ZenStore — groups, packages, and the "no Python `None`" rule

`store(group="scheduler")(SomeCfg, name="cosine")` registers `SomeCfg` under group `scheduler`. CLI: `scheduler=cosine`.

Useful patterns from the docs:

```python
# Pre-curry a group for repeated entries
db_store = store(group="db")
db_store(Database(name="mysql"))
db_store(Database(name="sqlite"))

# Auto-name from a config attribute (lambda receives the cfg)
auto_name = store(name=lambda cfg: cfg.name)
auto_name(group="server")(Server(name="apache", port=80))

# Push everything into Hydra's global store at app startup
if __name__ == "__main__":
    store.add_to_hydra_store()
    zen(task).hydra_main(config_path=None, config_name="train", version_base="1.2")
```

**You cannot register raw `None` as a group option:**

```python
# WRONG — hydra-zen rejects None as a config:
scheduler_store(None, name="none")
# Also wrong on CLI: `scheduler=null`. Hydra parses YAML null as Python None
# *before* the group lookup, raising ValueError.

# RIGHT: wrap None in a builds() of a sentinel function.
def _null_scheduler(*a, **kw): return None
scheduler_store(builds(_null_scheduler), name="none")    # CLI: scheduler=none
```

### Experiment overlays via `make_config` + `_global_` package

The idiomatic way to express "experiment X = base config + a few overrides":

```python
from hydra_zen import make_config

experiment_store = store(group="experiment", package="_global_")
experiment_store(
    make_config(
        hydra_defaults=["_self_", {"override /db": "sqlite"}],
        server=dict(port=8080),
        bases=(Config,),            # inherit from the top-level config
    ),
    name="aplite",
)
# CLI: python app.py +experiment=aplite
```

`package="_global_"` means the experiment config *replaces* the top-level config rather than nesting under it; `bases=(Config,)` means "inherit all fields then override these"; `"override /db"` (absolute path) is required because we're not using Hydra's YAML search path.

## `just()` — embed Python objects literally

`just(x)` produces a config whose `instantiate(...)` returns `x` unchanged. Use it for things that aren't directly callable-as-target but need to live inside another `builds(...)`:

```python
# A list of already-built callback configs, embedded into the Trainer config.
TrainerCfg = pbuilds(L.Trainer,
                     callbacks=just([builds(RichProgressBar)]),
                     ...)

# Embedding a functools.partial as an alternative to zen_partial=True:
LogConf = just(functools.partial(logger, format_spec='{0:>8s}'))
```

Without `just`, hydra-zen tries to interpret the value as a target and fails.

## `hydrated_dataclass` — when you want static typing

`builds(...)` returns a class, but pyright/mypy can't see field names without overload tricks. `@hydrated_dataclass` flips it around — you write a dataclass body and the decorator wires in `_target_`, `_partial_`, validation, and type-refinement:

```python
from hydra_zen import hydrated_dataclass
from torch.optim import Adam

@hydrated_dataclass(target=Adam, zen_partial=True, frozen=True)
class BuildsAdam:
    lr: float = 0.01
    momentum: float = 0.9

# pyright now flags both of these:
BuildsAdam(lr="a string")   # bad type
conf = BuildsAdam(); conf.lr = 10.0   # frozen
```

Misspelled field names raise `TypeError` at decoration time, just like `builds()`. Use this when you care about IDE attribute completion or `frozen=True` static checks.

## `kwargs_of` — "give me a dict matching this signature"

When you need a config that instantiates to a **`dict`** (not the target itself) whose keys/defaults mirror some function:

```python
from hydra_zen import kwargs_of

DataLoaderKwargs = kwargs_of(DataLoader, zen_exclude=("dataset",), batch_size=32)
# instantiate(DataLoaderKwargs(num_workers=4))
# → {"batch_size": 32, "num_workers": 4, ...}
```

Useful for passing a `**kwargs` blob through to a constructor you don't own, or for configs that feed `dataclasses.replace`-style overlays.

## `BuildsFn` subclass — project-wide builder defaults

If you need stronger conventions than `make_custom_builds_fn` (e.g. always attach a beartype wrapper, always set `hydra_convert="object"`, always reject unknown kwargs), subclass `BuildsFn`:

```python
from hydra_zen import BuildsFn

class MyBuilds(BuildsFn):
    _default_dataclass_options_for_builds = {"frozen": True}
    # ... override class methods to inject zen_wrappers, etc.

builds = MyBuilds.builds
pbuilds = MyBuilds.builds  # with zen_partial=True via your own wrapper
```

Reserve this for genuinely project-wide policy. For most projects, `make_custom_builds_fn` is sufficient.

## Hacking corner cases

### The "partial-of-partial" pattern (and why it's usually wrong)

Code that looks like this is a smell:

```python
# This repo's cfg.py:
PartialModelCfg = partial(
    pbuilds,
    CisGeneReg,
    loss_fn="${loss}", optimizer=OptimCfg, scheduler="${scheduler}",
    grad_clip_val=1.0, flags="${flags}", device="cuda", compile_arch=True,
    builds_bases=(ModelCfg,),
)
model_store(PartialModelCfg(d_model=32, nhead=2, n_layers=2), name="tiny")
model_store(PartialModelCfg(d_model=64, nhead=4, n_layers=4), name="small")
```

What's actually happening: the author wants four small per-size variants. They wrap `pbuilds` in `functools.partial` so each call only needs `d_model`/`nhead`/`n_layers`. They also set `builds_bases=(ModelCfg,)` *and* restate all the shared kwargs — which is redundant if `builds_bases` works, but is needed here because `pbuilds` has `populate_full_signature=True` and that blanks parent-only fields (see "signature-population trap" above).

**Idiomatic refactor** — use a *second* builder without full-signature population for variants:

```python
builds_kw = make_custom_builds_fn()                                 # for required configs
pbuilds   = make_custom_builds_fn(populate_full_signature=True,
                                  zen_partial=True)                  # full sig + partial
variant   = make_custom_builds_fn(zen_partial=True)                  # partial, no full sig

# Base carries every shared kwarg (and full signature → CLI overrideable):
ModelCfg = pbuilds(
    CisGeneReg,
    loss_fn="${loss}", optimizer=OptimCfg, scheduler="${scheduler}",
    grad_clip_val=1.0, flags="${flags}", device="cuda", compile_arch=True,
)

# Variants inherit cleanly; only the differing kwargs are listed.
model_store(variant(CisGeneReg, d_model=32, nhead=2, n_layers=2,  builds_bases=(ModelCfg,)), name="tiny")
model_store(variant(CisGeneReg, d_model=64, nhead=4, n_layers=4,  builds_bases=(ModelCfg,)), name="small")
```

What changed: `variant` omits `populate_full_signature=True`, so `builds_bases=(ModelCfg,)` cleanly composes — parent fields are preserved, child only adds the size triple. No `functools.partial` indirection. (Trade-off: variants' configs no longer expose every `CisGeneReg.__init__` field on the CLI; the *base* still does because `pbuilds` is full-signature, and CLI overrides propagate through inheritance.)

### Alternative: `make_config` overlays

If the variant is purely a CLI overlay rather than a separate target config, `make_config(..., bases=(ModelCfg,))` works (see "Experiment overlays" above). Use this for compositional experiments; use `builds(... builds_bases=...)` for typed variants of a single target.

### Embedding a `functools.partial` directly

When you have an *instance* of `functools.partial` and want to register it as a config (e.g. a third-party factory you can't decorate), wrap it in `just`:

```python
LogConf = just(functools.partial(logger, format_spec='{0:>8s}'))
```

Equivalent to `builds(logger, format_spec='{0:>8s}', zen_partial=True)` but lets you build the `partial` outside hydra-zen.

### Adding runtime type validation

`zen_wrappers=(validates_with_beartype,)` or `(validates_with_pydantic,)` re-asserts the unrefined types at instantiate time:

```python
from hydra_zen.third_party.beartype import validates_with_beartype

ModelCfg = pbuilds(CisGeneReg, ..., zen_wrappers=validates_with_beartype)
```

Now `Literal[...]`, custom protocols, and union types are enforced when `instantiate` runs, despite hydra-zen having broadened them for Hydra.

### `zen_meta` — fields that live in the config but not in the target

For tracking metadata (experiment tags, git SHA) that should appear in the dumped config but **not** be passed to the target's `__init__`:

```python
ModelCfg = pbuilds(CisGeneReg, ..., zen_meta={"git_sha": "${oc.env:GIT_SHA}"})
```

`git_sha` shows up in `to_yaml(ModelCfg)` but is stripped before `CisGeneReg(**kwargs)` is called.

### `zen_exclude` — drop signature parameters

For `populate_full_signature=True` builds where some kwargs shouldn't be configurable:

```python
builds(DataLoader, populate_full_signature=True, zen_exclude=("dataset", "collate_fn"))
```

Useful when a parameter is set at runtime (`dataset` is passed by the trainer), but you still want full sig for the others.

## Quick reference

| Need | Pattern |
|---|---|
| Concrete config of a class | `builds(Cls, **kwargs)` |
| Factory / partial | `builds(Cls, zen_partial=True, ...)` |
| Project-wide builder defaults | `make_custom_builds_fn(populate_full_signature=True, ...)` |
| Static-typed config (pyright) | `@hydrated_dataclass(target=Cls)` class body |
| Untargeted top-level / experiment | `make_config(*fields, bases=(...))` |
| Dict matching a signature | `kwargs_of(fn, **overrides)` |
| Required field, default from group | `field=MISSING` + `hydra_defaults=[{"group": "name"}, ...]` |
| Wire group choice into nested field (idiomatic) | `hydra_defaults=[{"group@dest.path": "default_name"}, ...]` — installs the chosen config directly at `dest.path` |
| Wire group choice into nested field (fan-out) | `nested_field="${group_name}"` + top-level `group_name=MISSING` + defaults entry; use when one group choice must broadcast to multiple destinations |
| Lazy / derived / env-resolved value | `field="${other.path}"`, `"${oc.env:VAR}"`, `"${now:...}"` — no type-safe alternative |
| Register group option | `store(group="g")(SomeCfg, name="opt")` |
| Group option that resolves to `None` | `builds(_null_fn)` registered under the group |
| Experiment overlay | `make_config(hydra_defaults=[...], bases=(Config,))` registered with `package="_global_"` |
| Embed Python literal / `functools.partial` | `just(value)` |
| Inherit + override | `builds(Cls, **overrides, builds_bases=(ParentCfg,))` — restate parent-only fields if `populate_full_signature=True` |
| Variants of a base | Use a no-full-sig builder so `builds_bases` composes cleanly |
| Drop fields from full-sig | `zen_exclude=("name1", "name2")` |
| Add runtime type checking | `zen_wrappers=validates_with_beartype` |
| Config-only metadata | `zen_meta={"key": value}` |

## Red flags — STOP and reconsider

- `_target_` appears as a string anywhere in a hydra-zen file → use `builds(...)`.
- `"${something}"` where `something` is not a top-level field of the same store → either inline the builder, add the missing group/field, or (preferred) replace with a `{"something@dest.path": "..."}` entry in `hydra_defaults`.
- `"${group_name}"` *with* a matching `group_name=MISSING` mirror field → works, but consider whether `group@dest.path` relocation would be cleaner. Use interpolation only when you genuinely need the same choice in multiple destinations.
- A child `builds_bases=(Parent,)` config "mysteriously" loses a parent's field → it's the `populate_full_signature` re-derivation; restate the field or use a no-full-sig builder.
- `functools.partial(some_builds_fn, target, ...)` wrapping a hydra-zen builder → almost always working around (2); refactor with `builds_bases` + a no-full-sig variant.
- `store(group="g")(None, name="off")` or CLI `g=null` failing → wrap `None` in a sentinel `builds()`.
- New YAML file appearing in a hydra-zen project → almost always wrong; the dataclasses are the source of truth.
- `instantiate(cfg)` returning a `functools.partial` you didn't expect → the builder was `zen_partial=True`; either call it, or rebuild without `zen_partial`.
- Runtime `ValidationError` on a `Literal`/`Union` field → hydra-zen refined it to `Any`; if you need enforcement, add `zen_wrappers=validates_with_beartype` or decorate the target with `@pydantic.dataclasses.dataclass`.

## Common LLM mistakes (and the corrections)

| Mistake | Why it's wrong | Fix |
|---|---|---|
| Replacing `OptimCfg` with `optimizer="${optimizer}"` | No `optimizer` group is registered; interpolation resolves to nothing | Pass the builder: `optimizer=OptimCfg` |
| Writing `_target_="pkg.Foo"` kwargs into `builds` | hydra-zen sets `_target_` from the first positional argument | `builds(Foo, ...)` |
| Setting `scheduler=None` to "disable" | hydra-zen and Hydra null parsing both reject it as a group option | Wrap in `builds(_null_scheduler)`, register as `"none"` |
| `populate_full_signature=True` + `builds_bases` and expecting deep merge | Child re-derives every field from `__init__`, blanking parent-only fields | Restate inherited fields, or use a no-full-sig builder for the child |
| Wrapping `pbuilds` in `functools.partial` to share kwargs across variants | `builds_bases` already does this — the wrapper exists to defeat full-sig blanking | Use a second `make_custom_builds_fn` without `populate_full_signature` for variants |
| Writing a `defaults:` YAML block | hydra-zen uses `hydra_defaults=[...]` kwarg on `store(...)` | Move the list into the store call |
| `${oc.env:VAR}` to parameterize a Python constant | hydra-zen lets you write a real Python default | Use a normal kwarg / factory parameter |
| Assuming `Literal[...]` is enforced at runtime | Type refinement broadens it to `Any` for Hydra compatibility | Add `zen_wrappers=validates_with_beartype` or use a pydantic dataclass target |

## See also

- hydra-zen docs: https://mit-ll-responsible-ai.github.io/hydra-zen/
- DRY rationale: `docs/source/explanation/dont_repeat_yourself.rst` in the upstream repo
- Type refinement: `docs/source/explanation/type_refinement.rst`
- Static-typed configs: `docs/source/explanation/hydrated_dataclass.rst`
- Experiment overlays: `docs/source/how_to/configuring_experiments.rst`
- Partial configs: `docs/source/how_to/partial_config.rst`
- Pydantic / beartype runtime checking: `docs/source/how_to/pydantic_guide.rst`, `beartype.rst`
- Hydra defaults-list semantics still apply: https://hydra.cc/docs/advanced/defaults_list/
- In this repo, `src/gvf_germ_som/train/multigene/cfg.py` is the canonical local example; the comments there encode several of the gotchas above.
