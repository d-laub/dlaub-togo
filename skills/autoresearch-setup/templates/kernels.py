"""Optional pre-tuned compute kernels for the training loop.

RULES (fixed-budget autoresearch):
- Pre-tuned & pre-configured ONLY. NO runtime autotuning — it blows the budget.
- For Helion/Triton: ship a saved Config and load it; never call .autotune() at
  run time. See the `helion-jagged-and-autotuning` skill.
- Import is optional: train.py should fall back to an eager path if unavailable.
"""
# TODO(autoresearch): add pre-tuned kernels as experiments mature. Empty is fine.
