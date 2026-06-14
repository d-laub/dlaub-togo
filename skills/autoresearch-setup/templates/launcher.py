# Harness owns dispatch + keep/discard. Do not edit this to change what 'winning' means.
"""Generic, backend-pluggable autoresearch batch launcher.

Fans out N sibling variant scripts (``train_0.py .. train_{n-1}.py``) across a
compute backend, parses each variant's stdout summary, appends a row to
``results.tsv``, and commits the single best variant into the canonical
``train.py`` only if it beats the running best (keep/discard).

Variant-invocation convention
------------------------------
A variant ``train_{k}.py`` exposes ``build_spec()``. It is run as a subprocess
that imports that module, builds the spec, and hands it to the harness:

    python -m run_variant {k}

where ``run_variant.py`` is a tiny sibling shim (see RUN_VARIANT_CMD below).
Rather than depend on an extra file existing, this launcher invokes the shim
inline via ``python -c`` so the convention is self-contained and visible:

    python -c "<RUN_VARIANT_SRC>" {k}

The subprocess imports ``train_{k}``'s ``build_spec()``, calls
``harness.run_experiment(spec)``, then ``harness.emit_summary(...)``. The
summary block prints the primary metric first as ``^<primary_metric>:`` on
stdout, which this launcher greps. Captured stdout for variant k lands in
``<batch_dir>/v{k}/run.log``.

Only two things need editing by a copier (marked ``# TODO(autoresearch):``):
the primary metric name (``PRIMARY_METRIC``) and the sbatch resource lines.
Everything else is real, working code.
"""

from __future__ import annotations

import math
import os
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Protocol, runtime_checkable

# --- module constants ---------------------------------------------------------

HERE = Path(__file__).resolve().parent
CANONICAL_TRAIN = HERE / "train.py"
RESULTS_TSV = HERE / "results.tsv"
BATCH_LOGS_ROOT = HERE / "logs"

# TODO(autoresearch): set PRIMARY_METRIC to your harness's primary metric name
# (the FIRST line emitted by harness.emit_summary, grepped as ``^<name>:``).
PRIMARY_METRIC = "val_metric"

RESULTS_HEADER = "commit\tmetric\tstatus\tdescription\n"

# The variant subprocess: import train_{k}, build the spec, run it through the
# harness, and emit the summary block. Kept in one place so the invocation
# convention is documented and self-contained.
RUN_VARIANT_SRC = (
    "import os, sys, importlib, harness;"
    "k = sys.argv[1];"
    "mod = importlib.import_module('train_' + k);"
    "spec = mod.build_spec();"
    "budget = float(os.environ.get('AUTORES_BUDGET_MIN', harness.DEFAULT_BUDGET_MIN));"
    "metrics = harness.run_experiment(spec, budget_min=budget);"
    "harness.emit_summary(metrics)"
)


def _run_variant_cmd(variant_idx: int) -> list[str]:
    """The exact argv used to run one variant as a subprocess."""
    return [sys.executable, "-c", RUN_VARIANT_SRC, str(variant_idx)]


# --- backend protocol ---------------------------------------------------------


@runtime_checkable
class Backend(Protocol):
    """A compute backend that can launch variant subprocesses in parallel."""

    name: str

    def detect(self) -> bool:
        """True if this backend is usable in the current environment."""
        ...

    def default_n(self) -> int:
        """Default parallelism for this backend."""
        ...

    def dispatch(self, variant_idx: int, budget_min: float):
        """Launch one variant; return an opaque handle understood by wait()."""
        ...

    def wait(self, handles: list) -> None:
        """Block until all dispatched variants finish."""
        ...


def _variant_log_path(variant_idx: int) -> Path:
    workdir = BATCH_LOGS_ROOT / f"v{variant_idx}"
    workdir.mkdir(parents=True, exist_ok=True)
    return workdir / "run.log"


# --- LocalMultiGPU backend ----------------------------------------------------


class LocalMultiGPU:
    """One subprocess per variant, each pinned to a distinct GPU via
    ``CUDA_VISIBLE_DEVICES``. Imports torch lazily so this module loads
    without a GPU (or without torch installed)."""

    name = "local"

    def detect(self) -> bool:
        return self.default_n() > 0

    def default_n(self) -> int:
        try:
            import torch

            return int(torch.cuda.device_count())
        except Exception:  # noqa: BLE001
            return 0

    def dispatch(self, variant_idx: int, budget_min: float):
        log_path = _variant_log_path(variant_idx)
        env = {
            **os.environ,
            "AUTORES_BUDGET_MIN": str(budget_min),
            "AUTORES_VARIANT": str(variant_idx),
            "CUDA_VISIBLE_DEVICES": str(variant_idx),
        }
        log_fh = log_path.open("wb")
        proc = subprocess.Popen(
            _run_variant_cmd(variant_idx),
            cwd=HERE,
            stdout=log_fh,
            stderr=subprocess.STDOUT,
            env=env,
            start_new_session=True,
        )
        # Track the file handle so wait() can close it after the proc exits.
        return (proc, log_fh)

    def wait(self, handles: list) -> None:
        for proc, log_fh in handles:
            try:
                proc.wait()
            finally:
                log_fh.close()


# --- Sbatch backend -----------------------------------------------------------


class Sbatch:
    """One ``sbatch --wait`` job per variant. Each job writes a ``job.sh`` that
    runs the variant subprocess and tees stdout into the variant's run.log."""

    name = "sbatch"

    def detect(self) -> bool:
        return shutil.which("sbatch") is not None

    def default_n(self) -> int:
        return 4

    def _job_script(self, variant_idx: int, budget_min: float, log_path: Path) -> str:
        # The subprocess command, single-quoted-safe inside the heredoc.
        run_cmd = " ".join(_run_variant_cmd(variant_idx))
        timelimit_min = int(budget_min) + 15
        return f"""\
#!/bin/bash
# TODO(autoresearch): partition / account / GPU type
#SBATCH -p PARTITION
#SBATCH -A ACCOUNT
#SBATCH -G GPU_TYPE:1
#SBATCH -c 8
#SBATCH --mem 64g
#SBATCH -t 0:{timelimit_min:02d}:00
#SBATCH -o {log_path}
cd {HERE}
export AUTORES_BUDGET_MIN={budget_min}
export AUTORES_VARIANT={variant_idx}
exec {run_cmd}
"""

    def dispatch(self, variant_idx: int, budget_min: float):
        log_path = _variant_log_path(variant_idx)
        script = self._job_script(variant_idx, budget_min, log_path)
        script_path = log_path.parent / "job.sh"
        script_path.write_text(script)
        # ``--wait`` blocks until the job completes; we run the submit itself in
        # the background (Popen) so all N jobs are queued concurrently, then
        # join them in wait().
        proc = subprocess.Popen(
            ["sbatch", "--wait", str(script_path)],
            cwd=HERE,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.STDOUT,
        )
        return proc

    def wait(self, handles: list) -> None:
        for proc in handles:
            proc.wait()


# --- backend selection --------------------------------------------------------

_BACKENDS_BY_NAME = {
    "sbatch": Sbatch,
    "local": LocalMultiGPU,
}


def auto_backend() -> Backend:
    """Pick a backend automatically: sbatch if available, else local GPUs."""
    if shutil.which("sbatch") is not None:
        return Sbatch()
    return LocalMultiGPU()


def select_backend(name: str | None) -> Backend:
    """Resolve a backend by name (AUTORES_CLUSTER), falling back to auto."""
    if name:
        cls = _BACKENDS_BY_NAME.get(name)
        if cls is None:
            raise ValueError(
                f"Unknown backend {name!r}; choose from {sorted(_BACKENDS_BY_NAME)}."
            )
        return cls()
    return auto_backend()


# --- summary parsing + results.tsv (GENERIC, COMPLETE) ------------------------


def parse_metric(log_path: Path) -> tuple[float | None, str]:
    """Grep the variant's captured stdout for ``^<PRIMARY_METRIC>:`` and read
    field 2 as a float.

    Returns ``(metric, status)`` where status is one of:
      - "ok"          metric parsed cleanly to a finite/real number
      - "crash"       the harness printed its crash marker, or the log is missing
      - "parse_error" the log exists but the metric line is absent/unparseable,
                      or the metric parsed to NaN (which can never win and must
                      not be reported as "ok")
    """
    try:
        text = log_path.read_text()
    except (FileNotFoundError, OSError):
        return None, "crash"

    crashed = "[autores] crashed:" in text
    metric: float | None = None
    for line in text.splitlines():
        if line.startswith(f"{PRIMARY_METRIC}:"):
            fields = line.split()
            if len(fields) >= 2:
                try:
                    metric = float(fields[1])
                except ValueError:
                    metric = None
            break

    if crashed:
        return metric, "crash"
    if metric is None:
        return None, "parse_error"
    # A literal `nan` metric never wins (see the winner guard / load_running_best);
    # report it honestly rather than as "ok".
    if math.isnan(metric):
        return metric, "parse_error"
    return metric, "ok"


def variant_description(train_k_path: Path) -> str:
    """First line of the variant module's docstring (the results description).
    Falls back to ``variant {k}`` parsed from the filename."""
    import ast

    stem_k = train_k_path.stem.removeprefix("train_")
    fallback = f"variant {stem_k}" if stem_k else "variant ?"
    try:
        tree = ast.parse(train_k_path.read_text())
    except (FileNotFoundError, OSError, SyntaxError):
        return fallback
    doc = ast.get_docstring(tree)
    if not doc:
        return fallback
    for line in doc.splitlines():
        stripped = line.strip()
        if stripped:
            return stripped
    return fallback


def format_results_row(
    *, commit: str, metric: float | None, status: str, description: str
) -> str:
    """One tab-separated row of results.tsv (trailing newline included)."""
    safe_desc = description.replace("\t", " ").replace("\n", " ")
    metric_str = "nan" if metric is None or math.isnan(metric) else f"{metric:.6f}"
    return f"{commit}\t{metric_str}\t{status}\t{safe_desc}\n"


def _ensure_results_header() -> None:
    if not RESULTS_TSV.exists():
        RESULTS_TSV.write_text(RESULTS_HEADER)


def load_running_best() -> float:
    """Largest metric among rows with status=="keep" in results.tsv. NaN-safe.
    Returns -inf if there is no prior keep so the first ok variant can win."""
    best = -math.inf
    try:
        lines = RESULTS_TSV.read_text().splitlines()
    except (FileNotFoundError, OSError):
        return best
    for line in lines[1:]:  # skip header
        cols = line.split("\t")
        if len(cols) < 4 or cols[2] != "keep":
            continue
        try:
            v = float(cols[1])
        except ValueError:
            continue
        if math.isnan(v):
            continue
        if v > best:
            best = v
    return best


# --- git helpers --------------------------------------------------------------


def _git(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["git", *args], cwd=HERE, check=True, capture_output=True, text=True
    )


def _git_head_short() -> str:
    return _git("rev-parse", "--short=7", "HEAD").stdout.strip()


def _commit_winner(variant_idx: int, metric: float, description: str) -> str:
    """Copy the winning variant over train.py, then git add + commit it.
    Returns the new commit's short SHA."""
    shutil.copyfile(HERE / f"train_{variant_idx}.py", CANONICAL_TRAIN)
    _git("add", str(CANONICAL_TRAIN))
    msg = f"autores v{variant_idx}: {PRIMARY_METRIC}={metric:.6f} ({description})"
    _git("commit", "-m", msg)
    return _git_head_short()


# --- variant discovery + cleanup ----------------------------------------------


def _variant_paths(n: int) -> list[Path]:
    paths = []
    for k in range(n):
        p = HERE / f"train_{k}.py"
        if not p.exists():
            raise FileNotFoundError(
                f"Missing variant file {p.name}; expected train_0.py..train_{n - 1}.py."
            )
        paths.append(p)
    # Guard against stale variants from a prior, larger batch: any
    # train_<int>.py with index >= n would otherwise sit unused on disk and
    # confuse the run. Refuse to proceed until they're cleaned up.
    extras = sorted(
        p.name
        for p in HERE.glob("train_*.py")
        if (idx := p.stem.removeprefix("train_")).isdigit() and int(idx) >= n
    )
    if extras:
        raise RuntimeError(
            f"Found stale variant files beyond train_{n - 1}.py: {extras}. "
            "Remove them (e.g. via _cleanup_variants) before launching a batch of n="
            f"{n}."
        )
    return paths


def _cleanup_variants() -> None:
    for p in HERE.glob("train_*.py"):
        if p.stem.removeprefix("train_").isdigit():
            p.unlink(missing_ok=True)


# --- core: fan out, parse, keep/discard ---------------------------------------


def run_batch(n: int, budget_min: float) -> int:
    """Run one batch of n variants. Returns 0 on success.

    This is the generic, complete core: it does NOT need editing to change what
    winning means — winning is strictly "ok and beats the running best metric".
    """
    backend = select_backend(os.environ.get("AUTORES_CLUSTER"))
    print(
        f"[autores] backend={backend.name} N={n} budget_min={budget_min}", flush=True
    )

    variant_paths = _variant_paths(n)
    _ensure_results_header()
    BATCH_LOGS_ROOT.mkdir(parents=True, exist_ok=True)

    # 1. fan out all variants, then block until all finish.
    handles = [backend.dispatch(k, budget_min) for k in range(n)]
    backend.wait(handles)

    # 2. parse each variant's summary sequentially.
    parsed: list[tuple[float | None, str]] = []
    for k in range(n):
        metric, status = parse_metric(_variant_log_path(k))
        parsed.append((metric, status))
        print(f"[autores] v{k}: metric={metric} status={status}", flush=True)

    # 3. linear keep/discard. A crashed / parse_error variant can never win, and
    #    NaN never beats a real number.
    running_best = load_running_best()
    print(f"[autores] starting running_best={running_best}", flush=True)

    for k in range(n):
        metric, status = parsed[k]
        description = variant_description(variant_paths[k])

        winner = (
            status == "ok"
            and metric is not None
            and not math.isnan(metric)
            and metric > running_best
        )

        if winner:
            assert metric is not None  # for type-checkers; guarded above
            commit = _commit_winner(k, metric, description)
            running_best = metric
            row_status = "keep"
        else:
            commit = _git_head_short()  # row references current tip
            row_status = status

        with RESULTS_TSV.open("a") as f:
            f.write(
                format_results_row(
                    commit=commit,
                    metric=metric,
                    status=row_status,
                    description=description,
                )
            )
        print(
            f"[autores] v{k} -> {row_status} (running_best={running_best})", flush=True
        )

    # 4. delete the numbered variant files.
    _cleanup_variants()
    print(f"[autores] batch complete; final running_best={running_best}", flush=True)
    return 0


if __name__ == "__main__":
    backend_for_default = select_backend(os.environ.get("AUTORES_CLUSTER"))
    n_env = os.environ.get("AUTORES_N")
    n = int(n_env) if n_env else backend_for_default.default_n()
    if n <= 0:
        raise SystemExit(
            "No parallelism available (AUTORES_N unset and backend default_n()==0). "
            "Set AUTORES_N or run where GPUs/sbatch are available."
        )

    budget_min = float(os.environ.get("AUTORES_BUDGET_MIN", "5"))

    # AUTORES_SEED, if set, is consumed by each variant's harness subprocess via
    # inherited os.environ (Popen passes the parent env), so no action is needed
    # here.

    sys.exit(run_batch(n, budget_min))
