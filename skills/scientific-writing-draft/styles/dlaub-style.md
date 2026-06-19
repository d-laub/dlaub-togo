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
- **Claim-first.** Lead each paragraph and most sentences with the finding, then give the evidence. Write "Z (we did Y to test X)" in place of "To test X, we did Y, and saw Z".
- **Declarative, active, low-hedging.** "We developed", "GVL achieves", "we benchmarked". Reserve hedges ("should", "may", "can be pursued") for genuinely forward-looking or speculative claims only.
- **Compact.** No throat-clearing ("It is important to note", "In order to"). Cut filler.

## Punctuation and anti-LLM-isms
Write scientific prose, not chatbot prose. These patterns read as machine-generated and do not belong in a manuscript.
- **No em-dashes (—).** Split the sentence in two, or use a comma. En-dashes in numeric ranges ("190–450x", "2–16 kbp") are correct typography and encouraged.
- **No antithesis tic.** Avoid "not X, but Y", "it's not X, it's Y", and "rather than just X, Y". State the claim directly and let the contrast stand on its own.
- **No corporate or marketing diction.** Avoid leverage, robust, seamless, powerful, cutting-edge, delve, showcase, underscore, and "highlight" or "enable" as vague verbs of emphasis. Name the actual mechanism.
- **No colloquialisms or idioms.** "apples-to-apples", "under the hood", "out of the box", "heavy lifting", "game-changer", "best of both worlds" have no place in a manuscript. Use literal technical phrasing, for example "matched comparison" or a plain description of the controls.
- **One idea per sentence, plain punctuation.** Do not chain clauses with semicolons or stack multiple colons. Prefer short declarative sentences ended by periods. Use at most one colon per sentence, and only to introduce a list or a definition.

## Quantification (the signature tell)
- Report headline results as a **range with "up to N×"**: "up to 1,000 times faster", "300–1,000x speed-up", "190–450x", "over 2,000-fold reduction".
- **Pair every headline number with (a) the named dataset and (b) the resource budget.** e.g. "Using up to 64 CPUs and 16 GB of total RAM … on the TCGA dataset".
- Use concrete cost/scale framing where it lands: "1.97 petabytes", "$50,000 per month".

## Figure discipline (Results)
- **One bold callout per figure block, on the first sentence about that panel**: `(**Fig. 2C**)`, `(**Fig. 2A**)`, `(**Supp. Fig. 1A**)`. When a run of consecutive sentences all concern the same panel, cite it once in the first of them. Do not repeat the callout on every sentence in the block.
- Open a new callout when the panel changes, or after an intervening sentence about a different figure.
- One figure block → one figure panel. If a block of Results prose maps to no figure, it is probably not a Results claim.

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
- [ ] Does each run of same-panel Results sentences carry exactly one bold callout, on its first sentence (not repeated)?
- [ ] Any hedging that isn't forward-looking? Cut it.
- [ ] First use of each abbreviation defined?
- [ ] Any em-dashes? Replace with a period or comma.
- [ ] Any "not X, but Y" antithesis, corporate diction, or colloquialism? Rewrite literally.
- [ ] Any semicolon or second colon joining clauses? Split into separate sentences.
