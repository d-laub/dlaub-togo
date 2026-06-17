---
name: dlaub-style
description: David Laub's scientific-manuscript voice for bioinformatics software/methods papers. Loaded by scientific-writing-draft when drafting prose.
metadata:
  type: reference
---

# dlaub-style — Scientific Manuscript Voice

Distilled from `manuscript.md` (published GenVarLoader paper) + `supplement.md` Methods.
Apply when drafting Background/Results/Conclusions prose and Methods.

## Core voice
- **Claim-first.** Lead each paragraph and most sentences with the finding or point; follow with evidence. Not "To test X, we did Y, and saw Z" — instead "Z (we did Y to test X)".
- **Declarative, active, low-hedging.** "We developed", "GVL achieves", "we benchmarked". Reserve hedges ("should", "may", "can be pursued") for genuinely forward-looking/speculative claims only.
- **Compact.** No throat-clearing ("It is important to note", "In order to"). Cut filler.

## Quantification (the signature tell)
- Report headline results as a **range with "up to N×"**: "up to 1,000 times faster", "300–1,000x speed-up", "190–450x", "over 2,000-fold reduction".
- **Pair every headline number with (a) the named dataset and (b) the resource budget.** e.g. "Using up to 64 CPUs and 16 GB of total RAM … on the TCGA dataset".
- Use concrete cost/scale framing where it lands: "1.97 petabytes", "$50,000 per month".

## Figure discipline (Results)
- **Every result claim ends in a bold figure callout**: `(**Fig. 2C**)`, `(**Fig. 2A**)`, `(**Supp. Fig. 1A**)`.
- One claim → one figure panel. If a claim has no figure, it is probably not a Results claim.

## Background
- Citation-dense: ≈one citation per factual claim.
- Arc: prior work/motivation → the gap/limitation → "Here, we introduce **<Tool>** (<TLA>), which …".

## Abbreviations
- Define once at first use in parentheses: "GenVarLoader (GVL)", "Sparse Variant (SVAR) format", "whole genome sequencing (WGS)". Reuse the short form thereafter.

## Methods register (from supplement)
- Step-ordered and reproducible; name tools **with versions/flags**; imperative/past-tense procedure ("We converted VCFs to SVAR using …").

## Quick checklist before finishing a paragraph
- [ ] Does it lead with the claim?
- [ ] Is every headline number a range tied to a dataset + resource budget?
- [ ] Does every Results sentence end in a bold figure callout?
- [ ] Any hedging that isn't forward-looking? Cut it.
- [ ] First use of each abbreviation defined?
