"""Drop-in dynamics recorder + two-tier writer for an autoresearch harness.
Project-agnostic — copy as-is. Snapshot tier = the `# [stats]` header;
full-resolution tier = the wide CSV body + optional per-entity parquet.
"""

from __future__ import annotations

import math
import sys
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any


class Recorder:
    """Collects named time-series for a single autoresearch v2 run.

    Owned by run_experiment and handed to train_fn via
    TrainContext.recorder. log() is safe to call from anywhere train
    has the recorder handle. Values stay in memory until run_experiment
    flushes them at end-of-run.
    """

    def __init__(self) -> None:
        self._series: dict[str, list[tuple[int, float]]] = {}
        self._auto_step: dict[str, int] = {}

    def log(self, name: str, value: float, step: int | None = None) -> None:
        s = self._series.setdefault(name, [])
        if step is None:
            step = self._auto_step.get(name, 0)
        self._auto_step[name] = step + 1
        s.append((step, float(value)))

    def snapshot(self) -> dict[str, list[tuple[int, float]]]:
        # Deep-ish copy: the writer must not see mutation if log() is
        # called after snapshot (e.g. from a stray validation pass).
        return {k: list(v) for k, v in self._series.items()}

    def last_step(self) -> int:
        """Highest step index across all series (0 if nothing logged).

        Eval-time series (e.g. val_r) are logged at this step so they align
        in the same CSV row as the most recent per-step metrics, rather than
        getting their own independent 0-based auto-counter.
        """
        steps = [s for series in self._series.values() for s, _ in series]
        return max(steps) if steps else 0


def _fmt_num(x: float) -> str:
    if math.isnan(x):
        return "nan"
    if math.isinf(x):
        return "inf" if x > 0 else "-inf"
    # 3 sig figs. Use scientific for very small/large.
    if x == 0:
        return "0.00"
    mag = abs(x)
    if mag < 1e-2 or mag >= 1e4:
        return f"{x:.2e}"
    return f"{x:.3g}"


def per_entity_final_lines(last_vals: dict[str, Any]) -> list[str]:
    """`# [per-entity] final <split> mean=.. median=..` lines from last-epoch
    per-entity value vectors (numpy arrays). nan-safe.

    "entity" = gene/class/token/whatever the project's per-item axis is.
    """
    import numpy as np

    out: list[str] = []
    for split, r in last_vals.items():
        arr = np.asarray(r, dtype=float)
        finite = arr[~np.isnan(arr)]
        mean = float(np.mean(finite)) if finite.size else math.nan
        median = float(np.median(finite)) if finite.size else math.nan
        out.append(
            f"# [per-entity] final {split} "
            f"mean={_fmt_num(mean)} median={_fmt_num(median)}"
        )
    return out


# ---------------------------------------------------------------------------
# Full-resolution CSV API (v3)
# ---------------------------------------------------------------------------

DYNAMICS_FILENAME = "run_dynamics.csv"
_FORMAT_VERSION = "v3"

# Project sets these to its own series. Generic defaults below.
CANONICAL_ORDER: tuple[str, ...] = ("train_loss", "val_metric", "lr", "grad_norm")
LEGEND: dict[str, str] = {
    "train_loss": "per-step train loss",
    "lr": "per-step learning rate",
    "grad_norm": "per-step grad L2 (pre-clip)",
    "val_metric": "primary validation metric (higher = better) — PRIMARY",
}
_DEFAULT_LEGEND = "logged by train.py via ctx.recorder.log"


@dataclass(frozen=True)
class SeriesStat:
    name: str
    n: int
    first: float
    final: float
    min_v: float
    min_step: int
    max_v: float
    max_step: int


def series_stat(name: str, points: list[tuple[int, float]]) -> SeriesStat:
    """Cheap at-a-glance stats: first/final/nan-safe min@/max@."""
    if not points:
        return SeriesStat(name, 0, math.nan, math.nan, math.nan, 0, math.nan, 0)
    first = points[0][1]
    final = points[-1][1]
    finite = [(s, v) for s, v in points if not math.isnan(v)]
    if finite:
        min_v, min_s = min((v, s) for s, v in finite)
        max_v, max_s = max((v, s) for s, v in finite)
    else:
        min_v = max_v = math.nan
        min_s = max_s = points[0][0]
    return SeriesStat(name, len(points), first, final, min_v, min_s, max_v, max_s)


def _ordered_names(series: dict[str, list[tuple[int, float]]]) -> list[str]:
    """Canonical series first (when present), then user series first-logged."""
    out = [n for n in CANONICAL_ORDER if n in series]
    out += [n for n in series if n not in out]
    return out


def _csv_num(v: float) -> str:
    """Round-trippable float; non-finite -> '' (null in CSV)."""
    if math.isnan(v) or math.isinf(v):
        return ""
    return repr(float(v))


def render_dynamics_csv(
    series: dict[str, list[tuple[int, float]]],
    *,
    meta: dict[str, str],
    extra_header: list[str] | tuple[str, ...] = (),
) -> str:
    """Render the full run_dynamics.csv body: comment header + wide CSV.

    One row per step (sorted union of all series' steps); one column per
    series in canonical-then-first-logged order; empty cell where a series
    wasn't logged at that step (or logged a non-finite value).
    """
    names = _ordered_names(series)
    ts = datetime.now().isoformat(timespec="seconds")
    lines: list[str] = [f"# dynamics {_FORMAT_VERSION} — autores run {ts}"]
    if meta:
        meta_kv = " ".join(f"{k}={v}" for k, v in meta.items())
        lines.append(f"# [meta] {meta_kv}")
    # [stats] is a cheap-glance human summary (3 sig figs via _fmt_num);
    # exact full-precision values live in the CSV body below.
    for name in names:
        st = series_stat(name, series[name])
        lines.append(
            f"# [stats] {name} n={st.n} first={_fmt_num(st.first)} "
            f"final={_fmt_num(st.final)} "
            f"min={_fmt_num(st.min_v)}@{st.min_step} "
            f"max={_fmt_num(st.max_v)}@{st.max_step}"
        )
    for name in names:
        lines.append(f"# [legend] {name} = {LEGEND.get(name, _DEFAULT_LEGEND)}")
    lines.extend(str(h) for h in extra_header)

    maps = {n: dict(series[n]) for n in names}
    steps = sorted({s for n in names for s, _ in series[n]})
    lines.append(",".join(["step", *names]))
    for s in steps:
        row = [str(s)]
        for n in names:
            v = maps[n].get(s)
            row.append("" if v is None else _csv_num(v))
        lines.append(",".join(row))
    return "\n".join(lines) + "\n"


def write_dynamics_csv(
    path: Path | str,
    *,
    series: dict[str, list[tuple[int, float]]],
    meta: dict[str, str],
    extra_header: list[str] | tuple[str, ...] = (),
) -> None:
    """Write run_dynamics.csv. MUST NOT raise — errors get a stderr
    breadcrumb so the stdout summary-block grep contract is preserved."""
    try:
        body = render_dynamics_csv(series, meta=meta, extra_header=extra_header)
        Path(path).write_text(body)
    except Exception as exc:  # noqa: BLE001
        print(
            f"[autores] dynamics writer failed: {type(exc).__name__}: {exc}",
            file=sys.stderr,
        )


@dataclass(frozen=True)
class RunDynamics:
    meta: dict[str, str]
    legend: dict[str, str]
    stats: Any  # pl.DataFrame
    series: Any  # pl.DataFrame
    per_entity_header: list[str]
    path: Path

    def per_entity(self) -> Any | None:
        import polars as pl

        p = self.path.parent / "dynamics_per_entity.parquet"
        return pl.read_parquet(p) if p.exists() else None


def _parse_float(tok: str) -> float:
    try:
        return float(tok)
    except ValueError:
        return math.nan


def load_run_dynamics(path: Path | str) -> RunDynamics:
    """Parse a run_dynamics.csv into meta/legend/stats/series for analysis."""
    import re

    import polars as pl

    path = Path(path)
    text = path.read_text()
    meta: dict[str, str] = {}
    legend: dict[str, str] = {}
    stats_rows: list[dict[str, Any]] = []
    per_entity_header: list[str] = []
    kv = re.compile(r"([\w./-]+)=(\S+)")

    for line in text.splitlines():
        if line.startswith("# [meta]"):
            for k, v in kv.findall(line[len("# [meta]") :]):
                meta[k] = v
        elif line.startswith("# [legend]"):
            body = line[len("# [legend]") :].strip()
            if " = " in body:
                name, desc = body.split(" = ", 1)
                legend[name.strip()] = desc.strip()
        elif line.startswith("# [stats]"):
            toks = line[len("# [stats]") :].split()
            if not toks:
                continue
            name = toks[0]
            fields = dict(t.split("=", 1) for t in toks[1:] if "=" in t)
            min_v, _, min_s = fields.get("min", "nan@0").partition("@")
            max_v, _, max_s = fields.get("max", "nan@0").partition("@")
            stats_rows.append(
                {
                    "name": name,
                    "n": int(fields.get("n", "0")),
                    "first": _parse_float(fields.get("first", "nan")),
                    "final": _parse_float(fields.get("final", "nan")),
                    "min": _parse_float(min_v),
                    "min_step": int(min_s or 0),
                    "max": _parse_float(max_v),
                    "max_step": int(max_s or 0),
                }
            )
        elif line.startswith("# [per-entity]"):
            per_entity_header.append(line)

    stats = pl.DataFrame(
        stats_rows,
        schema={
            "name": pl.String,
            "n": pl.Int64,
            "first": pl.Float64,
            "final": pl.Float64,
            "min": pl.Float64,
            "min_step": pl.Int64,
            "max": pl.Float64,
            "max_step": pl.Int64,
        },
    )
    series = pl.read_csv(path, comment_prefix="#")
    series = series.with_columns(
        pl.col(c).cast(pl.Float64) for c in series.columns if c != "step"
    )
    return RunDynamics(
        meta=meta,
        legend=legend,
        stats=stats,
        series=series,
        per_entity_header=per_entity_header,
        path=path,
    )
