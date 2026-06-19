---
name: ultraplot
description: Use when writing or modifying Python plotting code that imports `ultraplot` (a matplotlib wrapper / maintained proplot fork) — building figures with `uplt.subplots`, styling via the `.format()` method, SubplotGrid indexing, colorbars/legends with location shortcuts, the `Colormap`/`Cycle`/`Norm`/`Locator`/`Formatter` constructors, axis sharing/spanning, panels/insets, geo/polar axes, or `uplt.rc` config. Skip for plain matplotlib that doesn't import ultraplot.
---

# UltraPlot

UltraPlot is an **object-oriented superset of matplotlib** (a maintained fork of
proplot supporting mpl 3.9+). Every matplotlib axes method still works; UltraPlot
adds a unified `.format()` styling method, smarter `subplots()`, location-shortcut
colorbars/legends, constructor functions, and auto-layout.

Most of UltraPlot is close enough to matplotlib that you can guess it. This skill
documents the conventions and edges that are easy to get **subtly wrong** — all
verified against ultraplot 2.3.

## Core conventions (get these right first)

- **Import as `uplt`**, not `plt` and not `pplt`: `import ultraplot as uplt`.
  (`pplt` is the old proplot alias; docs/old code may use it but `uplt` is current.)
- **Don't use the pyplot interface.** There is no `uplt.plot()` / `uplt.gca()` /
  `uplt.show()`-driven state machine. Always go through explicit figure/axes objects.
- **Style with `.format()`, not `set_*` calls.** One `ax.format(...)` /
  `fig.format(...)` call replaces dozens of `set_xlabel`/`set_title`/`set_xlim`/
  tick calls. `set_*` methods still work, but `.format()` is the idiom.

```python
import numpy as np
import ultraplot as uplt

fig, axs = uplt.subplots(nrows=2, ncols=2, share=True, refwidth=2.0)
fig.format(suptitle="Title", xlabel="x", ylabel="y", abc="a)", abcloc="ul")
axs[0].plot(np.random.rand(20, 3), cycle="538", labels=["a", "b", "c"], legend="ll")
m = axs[3].pcolormesh(np.random.rand(20, 20), cmap="magma")
fig.colorbar(m, loc="r", label="value")
fig.save("out.png", dpi=200)
```

## Figure creation

| Call | Returns |
|------|---------|
| `uplt.subplots(nrows=, ncols=, ...)` | `(Figure, SubplotGrid)` |
| `uplt.subplots(array=[[1,1],[2,3]])` | `(Figure, SubplotGrid)` — mosaic layout |
| `uplt.subplot(...)` (singular) | `(Figure, CartesianAxes)` — one bare axes |
| `uplt.figure(...)` then `fig.add_subplots(...)` / `fig.add_subplot(...)` | `Figure`, then grid / axes |

- **`subplots()` ALWAYS returns a `SubplotGrid`, even for one subplot.** So
  `fig, axs = uplt.subplots(ncols=1)` makes `axs` a grid — index it as `axs[0]`
  to get the axes. Use the singular `uplt.subplot()` when you want one bare axes.
- **Sizing is automatic.** Prefer `refwidth`/`refheight` (per-subplot reference
  size) + `refaspect`; the figure size and inter-subplot spacing are computed by
  auto-layout. Use `figwidth`/`figheight` only to force the overall size.
- **Units are flexible** on every size arg: numbers in `subplots`/format default to
  inches for figure dims and font-relative `em` for subplot/spacing dims; strings
  accept `'cm'`, `'mm'`, `'in'`, `'pt'`, `'em'` (e.g. `refwidth='4cm'`, `wspace='1em'`).

## SubplotGrid indexing (common trap)

`SubplotGrid` is a list-like container. Indexing is **not** numpy-like:

| Index | Result |
|-------|--------|
| `axs[i]` (1D int) | a **bare axes** (`CartesianAxes`) |
| `axs[i, j]` (2D int) | a **1-element `SubplotGrid`**, NOT a bare axes |
| `axs[r, :]`, `axs[:, c]`, `axs[a:b]` | a `SubplotGrid` |

**To get a single axes object, use flat 1D integer indexing `axs[i]`.** 2D and slice
indexing return grids. Methods broadcast over a grid (`axs.format(...)`,
`axs[0, :].plot(...)` all work), so `axs[i, j].plot()` works — but `axs[i, j]` is a
grid, so anything expecting a single Artist/Axes back will misbehave.

## The `.format()` method

Works on axes, figures, and grids. Common keywords (all optional):

```python
ax.format(
    title="t", ltitle=..., rtitle=..., ultitle=..., urtitle=...,  # corner titles
    xlabel="x", ylabel="y", xlim=(0, 10), ylim=..., xscale="log",
    xlocator="maxn", xformatter="sci",        # string shortcuts -> constructors
    xticks=[0, 5, 10], xticklabels=[...], xtickdir="inout", xticklen=5,
    xreverse=False, xmargin=0.05,
    grid=True, gridminor=True,
    abc="a)", abcloc="ul",                    # auto subplot labels: a) b) c) ...
)
fig.format(
    suptitle="figure title",
    leftlabels=["row1", "row2"], toplabels=["col1", "col2"],  # edge super-labels
    # ...also accepts every axes-format kwarg, applied to all subplots
)
axs.format(xlabel="shared", abc="A.")         # broadcasts to all axes in the grid
```

- `abc=True` (or a template like `'a)'`, `'A.'`, `'(a)'`) turns on automatic subplot
  labels; `abcloc` placement uses corner codes `'ul' 'uc' 'ur' 'll' 'lc' 'lr'`.
- `xlocator`/`xformatter`/`xscale` accept the same strings/tuples as the
  constructor functions below (e.g. `xlocator=('maxn', 5)`).

## Colorbars & legends (location shortcuts)

`ax.colorbar(...)`, `fig.colorbar(...)`, `ax.legend(...)`, `fig.legend(...)` all take
a `loc` of single-letter / corner codes — **not** matplotlib's `'upper right'` style
(though those still work for legends):

| Code | Meaning |
|------|---------|
| `'l' 'r' 't' 'b'` | outer left / right / top / bottom |
| `'ul' 'ur' 'll' 'lr'` | inset corners |
| `'c'` / `'best'` | centered / auto inset |

```python
m = ax.pcolormesh(z, cmap="viridis")
ax.colorbar(m, loc="r", label="v", length=0.8, width="1.5em")
fig.colorbar(m, loc="r", label="v")                 # figure-spanning colorbar

ax.legend(loc="ll", ncols=1)                        # from labeled artists
fig.legend(loc="b", ncols=3)
```

**Easiest path:** pass `colorbar=`/`legend=` (a loc code) straight to the plotting
command and skip the separate call:

```python
ax.pcolormesh(z, cmap="magma", colorbar="r")
ax.plot(y, labels=["a", "b", "c"], legend="ul")
```

## Constructor functions

These turn strings/tuples/lists into matplotlib objects; the same inputs are
accepted inline by plotting commands and `.format()`.

```python
uplt.Colormap("viridis", left=0.1, right=0.9, reverse=True)  # truncate/reverse/edit
uplt.Colormap(["red", "blue"])                               # build from colors
uplt.Cycle("538"); uplt.Cycle("viridis", 5); uplt.Cycle(["r","g","b"])
uplt.Norm("diverging", vcenter=0); uplt.Norm(("power", 2)); uplt.Norm("log")
uplt.Locator(("maxn", 5)); uplt.Locator("log")
uplt.Formatter("sci"); uplt.Formatter("frac"); uplt.Formatter("percent")
uplt.Scale(("power", 2)); uplt.Proj("ortho", central_latitude=45)
```

## Colormaps, cycles, colors

Registered on import (case-insensitive; append `_r` to reverse). Verified names:

- **Perceptually-uniform sequential:** `viridis`, `magma`, `plasma`, `inferno`, `cividis`.
- **Diverging:** `rdbu`, `coolwarm`, `piyg`, `brbg`, `spectral`.
- **Color cycles** (pass to `cycle=`): `default`, `colorblind`, `colorblind10`,
  `538`, `ggplot`, `seaborn`, `bmh`, `tab10`, `tab20`, `Set1`, `Qual1`, `Qual2`.

List what's available at runtime: `uplt.show_cmaps()`, `uplt.show_cycles()`,
`uplt.show_colors()`, `uplt.show_fonts()`. Programmatic registry: `uplt.colormaps`.

## Plotting commands (PlotAxes enhancements)

Standard matplotlib commands (`plot`, `scatter`, `pcolormesh`, `contourf`, ...) plus
extras like `ax.heatmap(...)`. Enhancements:

- Pass `cmap=`, `cycle=`, `norm=`, `levels=`, `colorbar=`, `legend=`, `labels=`
  directly to the plot call.
- Multi-column `y` → one line per column (with `labels=[...]` per column).
- pandas/xarray inputs auto-label axes/legend from names/coords.

## Axis sharing & spanning, panels, insets

```python
uplt.subplots(nrows=2, ncols=2,
    share=True,    # share=sharex=sharey level: 0/False .. 3/True, 4/'all', 'auto'
    span=True,     # single centered label spanning a row/column (spanx/spany)
    align=True)    # align labels across subplots (alignx/aligny)

ax.panel("r", width="3em")          # attached panel: 'l'/'r'/'t'/'b' (alias panel_axes)
ax.inset([0.5, 0.5, 0.4, 0.4])      # inset in axes-fraction coords (alias inset_axes)
```

Share levels: `0/False` none · `1/'labels'` labels only · `2/'limits'` limits+ticks ·
`3/True` + hide inner ticklabels · `4/'all'` across all rows/cols · `'auto'`.

## Geographic & polar axes

```python
fig, ax = uplt.subplots(proj="ortho", proj_kw=dict(central_latitude=45))  # needs cartopy
ax.format(land=True, coast=True, borders=True,
          lonlim=(-60, 60), latlim=(-30, 30), lonlocator=20, latlocator=20,
          longrid=True, latgrid=True)

fig, ax = uplt.subplots(proj="polar")   # PolarAxes, no cartopy needed
ax.format(thetalim=(0, 360), rlim=(0, 1), thetalocator=30, rlabelpos=45)
```

Geo projections (`'ortho'`, `'merc'`, `'moll'`, `'robin'`, ...) require **cartopy**;
without it `subplots(proj=...)` raises. `proj="polar"` always works.

## rc configuration

```python
uplt.rc["font.size"] = 11           # dict access (dotted keys)
uplt.rc.update({"axes.grid": True, "grid.alpha": 0.4})
with uplt.rc.context(fontsize=12, linewidth=1.5):  # underscore aliases; auto-reverts
    fig, ax = uplt.subplots()
uplt.rc.reset()
```

Loads defaults → `~/.config/ultraplotrc` → `./.ultraplotrc` (later overrides earlier).

## Saving

`fig.save("out.pdf", dpi=300)` or `fig.savefig(...)` (alias). Default format `pdf`,
default dpi 1000.

## Common mistakes

| Mistake | Fix |
|---------|-----|
| `import ultraplot as plt` / `as pplt` | `import ultraplot as uplt` |
| `uplt.plot(...)` / pyplot state machine | explicit `fig, ax = uplt.subplots(); ax.plot(...)` |
| Treating `axs[i, j]` as a single axes | it's a 1-element grid; use flat `axs[i]` for one axes |
| Assuming `subplots(ncols=1)` gives a bare axes | it gives a `SubplotGrid`; use `axs[0]` or `uplt.subplot()` |
| `ax.colorbar(m, "r")` positionally | `ax.colorbar(m, loc="r")` |
| Many `ax.set_xlabel/set_title/set_xlim` calls | one `ax.format(xlabel=, title=, xlim=)` |
| Manual "a) b) c)" text | `fig.format(abc="a)", abcloc="ul")` |
| `proj="ortho"` errors | install cartopy (or use `proj="polar"` which needs none) |
