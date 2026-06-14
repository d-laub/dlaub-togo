"""<one-line variant description — becomes the results.tsv description column>

EDIT FREELY. You own the model, optimizer, scheduler, loss, training loop.
Only the harness.py contract constrains you (build_spec / eval_forward / train_fn).
"""

from __future__ import annotations

import itertools
import time
from typing import Any

import torch
from torch import nn
from torch.optim import AdamW

from harness import PRIMARY_VAL_KIND, ExperimentSpec, TrainContext, TrainResult


def build_spec() -> ExperimentSpec:
    """Construct the experiment: config dict + model + the two callables the
    harness drives (train_fn, eval_forward)."""
    # Free-form project config the harness threads into the data builders and
    # that train_fn can read back. Put feature flags / architecture knobs here.
    cfg: dict[str, Any] = {
        # TODO(autoresearch): your config knobs (window size, encoding, etc.)
        "d_model": 128,
    }
    max_items = 2**13  # TODO(autoresearch): the fixed per-batch item budget

    # TODO(autoresearch): your nn.Module. The stub below is a single Linear so
    # this file compiles and the build_spec/eval_forward/train_fn pattern is
    # visible — the copier replaces it with the real model.
    model: nn.Module = nn.Linear(cfg["d_model"], 1)

    return ExperimentSpec(
        cfg=cfg,
        max_items=max_items,
        model=model,
        train_fn=_train_fn,
        eval_forward=_eval_forward,
    )


def _eval_forward(model: nn.Module, batch: dict[str, Any]) -> torch.Tensor:
    # TODO(autoresearch): return preds matching the harness metric's expected shape.
    # The harness scorer reads the target from `batch` and reduces preds+target
    # to the scalar metric, so the shape here must line up with that reduction.
    return model(batch["x"])  # TODO(autoresearch): your forward / input key


def _train_fn(ctx: TrainContext) -> TrainResult:
    """Canonical plain-torch + Fabric training loop.

    This is the teaching centerpiece: a fixed-wall-clock-budget loop with
    AdamW, fabric.backward, gradient clipping, recorder logging, and periodic
    validation. Copy this structure; swap in your model and loss.
    """
    model = ctx.model
    fabric = ctx.fabric

    # NO torch.compile — under a short fixed budget, trace + autotune burns the
    # whole budget every run. Use pre-tuned kernels from kernels.py instead.

    peak_lr = 5e-4
    optimizer = AdamW(
        model.parameters(),
        lr=peak_lr,
        betas=(0.9, 0.95),
        eps=1e-7,
        weight_decay=0.06,
    )
    optimizer = fabric.setup_optimizers(optimizer)
    grad_clip_val = 1.0

    # If the project uses variable batch sizes (a packing sampler), a step-based
    # scheduler is wrong — schedule in item-units instead. See program.md
    # ("LR scheduling + packing sampler") for the item-unit cosine-LR pattern.

    num_steps = 0
    val_every = 50  # TODO(autoresearch): periodic-validation cadence in steps
    t0 = time.monotonic()
    stop = False

    for _epoch in itertools.count():
        if stop:
            break
        model.train()
        for batch in ctx.train_loader:
            preds = _eval_forward(model, batch)

            # TODO(autoresearch): your loss. The MSE placeholder below compiles
            # and shows where the loss goes; replace with your real objective
            # (and read the target from `batch` however your data provides it).
            target = batch["y"]
            loss = nn.functional.mse_loss(preds, target)

            fabric.backward(loss)
            grad_norm = fabric.clip_gradients(model, optimizer, max_norm=grad_clip_val)
            optimizer.step()
            optimizer.zero_grad(set_to_none=True)

            ctx.recorder.log("train_loss", float(loss.detach()))
            ctx.recorder.log("lr", optimizer.param_groups[0]["lr"])
            if grad_norm is not None:
                ctx.recorder.log("grad_norm", float(grad_norm))

            num_steps += 1

            # Periodic validation: score the primary val kind. The harness
            # scorer (_Score) restores train mode on the way out, so no
            # ctx.model.train() is needed here.
            if num_steps % val_every == 0:
                ctx.score(PRIMARY_VAL_KIND, ctx.model)

            # Wall-clock budget check — stop as soon as the budget is exhausted.
            if time.monotonic() - t0 >= ctx.budget_sec:
                stop = True
                break

        # End-of-epoch scoring so the running best is up to date — but skip it
        # when we're stopping due to an exhausted budget (a final score runs
        # once after the loop, so the harness still gets a fresh best).
        if not stop:
            ctx.score(PRIMARY_VAL_KIND, ctx.model)

    # Final score exactly once, so the harness has a fresh running best.
    ctx.score(PRIMARY_VAL_KIND, ctx.model)

    training_seconds = time.monotonic() - t0
    return TrainResult(num_steps=num_steps, training_seconds=training_seconds)
