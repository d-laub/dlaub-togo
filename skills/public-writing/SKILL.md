---
name: public-writing
description: Use when writing David Laub's public-facing, non-manuscript prose. Covers the LinkedIn About section, technical blog posts announcing a tool or a result, project READMEs, and release notes. Sets the voice, the per-genre specs, and the mechanical guardrails against LLM writing tells.
metadata:
  type: technique
---

# Public writing

For prose that a stranger reads without being paid to. A LinkedIn About section,
a blog post announcing a tool, a README, a release note. Not for manuscripts,
which are covered by `scientific-writing-draft` and its `dlaub-style.md`.

Two reference files hold the evidence this guide is built from. Read the relevant
one before drafting, because the verbatim examples are more useful than the rules
abstracted from them.

- `references/bio-examples.md`, 25 sources, LinkedIn and personal site bios from
  computational biology, ML infrastructure and open source tool authors.
- `references/blog-examples.md`, 23 sources, posts announcing scientific software
  and ML models.

`scripts/check-prose.sh` greps a draft for the mechanical rules below. Run it
before showing a draft to anyone.

## Which rules win

Four rule sets apply, and they contradict each other. Precedence, highest first:

1. The fact and the number. No stylistic rule justifies dropping a figure, a
   dataset name, or a resource budget.
2. `plain-writing` for punctuation, sentence shape and vocabulary.
3. `dlaub-style` for claim-first structure and quantification discipline.
4. Genre convention from the two reference files.

Where two and three collide, the resolutions are fixed:

| Question | dlaub-style | plain-writing | Public writing uses |
|---|---|---|---|
| Dashes in ranges | En dash, "190–450x" | No dashes, "190 to 450 times" | "190 to 450 times faster" |
| Sentence length | Short, one idea each | Longer and explanatory | Explanatory in the blog, mixed in the bio, never staccato |
| Demonstrative openers | Not addressed | Never open with This, That, These, Those | Never |
| Contractions | Absent from manuscripts | Fine | Use them, sparingly |
| Bold figure callouts | Required, `(**Fig. 2C**)` | No decorative bold | No callouts. Caption states the conclusion |
| Citations | About one per factual claim | Not addressed | Link instead, one per claim about prior work |
| Paragraph shape | Claim first | Topic sentence, then support | Compatible. The claim is the topic sentence |

## Voice

Write as one person who built a thing and is describing it. First person
singular. Present tense for what the work does, past tense for what you did.

### Sentence rhythm, and the failure mode to watch for

Long, connected sentences. Join clauses with because, since, so, which, while,
although and rather than, and let a sentence carry two related ideas instead of
splitting them into two sentences. Target a mean sentence length near 25 to 30
words in the blog, and check it rather than trusting your ear:

```
python3 -c "import re,statistics,sys;
t=' '.join(l.strip() for l in open(sys.argv[1]) if l.strip() and l[0] not in '#!*-');
w=[len(x.split()) for x in re.split(r'(?<=[.!?]) +',t) if x.strip()];
print('mean',round(statistics.mean(w),1),'| under 8 words:',sum(1 for x in w if x<8))" FILE
```

The failure mode is a stack of short declaratives used for emphasis, where each
one lands like a drumbeat and the cumulative effect is that everything sounds
maximally important. It reads as salesmanship rather than as a scientist
describing a result, and it is the single most likely way this guide gets
violated in practice. Symptoms, all drawn from a draft that had to be rewritten:

- A short sentence that only restates the previous one louder. "People have
  tried." "The obvious fix was unaffordable." "Half is not most."
- Anaphora for rhythm. "The obvious fix is X. The obvious fix was Y."
- Imperative or slogan headings. "Do not write the genomes down" should be
  "Assembling personal genomes during training".
- Superlative framings of your own contribution. "One thing it does that nothing
  else does" and "Every other tool silently misaligns them" should be "a detail
  that other tools appear to miss".

Do not perform the humility, either. Announcing that you are being candid is
its own kind of puffery: it asks for credit for the disclosure instead of just
making it. The linter treats this as an error.

<!-- prose-check:off -->
- "the read penalty is a real regression and worth stating" is the disclosure
  plus a bid for credit. The disclosure alone is "short reads are slower".
- Also banned: worth noting, worth saying out loud, to be honest, the honest
  reading, I want to be careful, let me be clear, it bears repeating, for what
  it is worth.
- Same for narrating your own posture toward a claim. "The tentative conclusion
  I draw is that X" and "The narrower claim is that X" should both be X, with
  the hedge carried by a verb such as appears or suggests.
<!-- prose-check:on -->

Prefer the humbler verb throughout. The work performs comparably rather than
wins, appears to rather than proves, and the conclusion is tentative rather than
practical. Overclaiming is more damaging to a technical reader's trust than
underclaiming, and the numbers are already doing the persuading.

Note that this rule and the three-clause limit inherited from plain-writing pull
against each other. Long connected sentences win in the blog, so a handful of
`three or more clauses` warnings from the linter is the expected steady state
there; treat them as a prompt to reread, not as a defect to fix.

Three habits carry over from the manuscript voice and matter more here, not
less.

**Name the specific thing.** A generic descriptor is a note to yourself to look
up its referent. "a reference-sequence baseline" becomes "Flashzoi". "cohort
scale" becomes "the 3,202 samples in 1000 Genomes". If you cannot name it, the
claim is not ready.

**Replace a magnitude word with the span.** A magnitude word is an instruction
to go find the number, and the checker warns on each one it knows.
<!-- prose-check:off -->
The list is "orders of magnitude", "much faster", "substantially", "widely",
"significantly", "dramatically" and their neighbours.
<!-- prose-check:on -->

**Pair every ratio with an absolute and a budget.** A ratio persuades and an
absolute makes it checkable. gnomAD writes "nearly 5x larger" and "807,162 total
individuals" in one sentence. Heng Li writes "Aligning 30X human reads in 50
minutes over 32 CPU threads". The budget is what separates a measurement from a
boast, and the checker warns when a ratio appears with no dataset and no
resources on the same line.

Two habits are new, because the audience is not a reviewer.

**Say where you lose.** Ray Data's post reports being 30% slower than PyTorch
DataLoader and explains why, then shows where it wins. MosaicML says its speedup
disappears for LLM training. Heng Li says his own new aligner is worse than his
old one for short reads. Every post in the reference set that reads as honest
does one of these, and every post that reads as marketing does not.

**Adoption over self-assessment.** "Many research labs use my single-cell data
browser Cell Guide" beats any adjective. Download counts, dependent packages and
citing papers are facts.
<!-- prose-check:off -->
"Powerful" and "robust" are not.
<!-- prose-check:on -->

## The LinkedIn About section

Target 110 to 150 words in four short paragraphs.

LinkedIn truncates at roughly 100 characters for a logged out reader and in
search results. The first sentence does most of the work. Write it to stand
alone.

**Sentence one.** First person, present tense, a verb about work being done, and
a named class of problem rather than a field. Under 100 characters. Compare "I
design new machine learning approaches for modeling biological systems" against
"AI Scientist with a PhD in Computational Biology". The first is a claim, the
second is a resume header true of a hundred people.

**Paragraph two, the artifacts.** Name each tool and gloss it in one clause, so a
reader can type the noun into GitHub. "ggrepel, an R package for annotating
figures" is the model. Describe a package by what it gives other people, not by
what it is technically. If there is adoption evidence, it goes here as a fact.

**Paragraph three, the credentials, compressed.** The PhD is a subordinate
clause, not a paragraph, and it comes after the work. Name advisors, labs and
institutions. Do not use prestige adjectives. Order the sentences so that
trimming from the end never removes anything load-bearing, which is Wes
McKinney's published rule for his own bio.

**Paragraph four, the close.** Optional. Several strong bios in the reference set
have none. If you write one, pick a form that does not read as an application.
Offer help rather than asking for it, or name the work you want to do rather than
the job, or scope the conversation to three specific topics with one of them off
topic. Put an email address in it, because recruiters without InMail have no
other way to reach you.

Hard rules for the bio:

- At least a dozen proper nouns. The single best discriminator between the real
  bios and the templates is proper nouns per sentence.
- At most two numbers, and each must be a fact rather than a result. "One of the
  first ten employees" and "over 20k citations" are facts. "Improved performance
  by 30%" against an unnamed baseline is filler, and every stock template has
  one.
- State a hobby if you want one, and never argue for its relevance. Arguing that
  mountain biking taught you to handle complex datasets is the tell.
- No trailing keyword list. LinkedIn has a Skills section.
- Translate once into plain English, early, in one sentence a non-specialist
  could repeat. "I teach people on the internet" is the sharpest example found.

## The blog post

Target 1,800 to 2,500 words with three to five figures.

A tool announcement has three readers at once, and naming them before drafting
settles most of the wording. There is a practitioner from the field the tool
serves, who knows the problem and not the method, and a practitioner from the
field the method comes from, who knows the method and not the problem. The third
is a hiring manager or a prospective collaborator skimming for whether the work
is real, and writing for the first two handles the third.

**Treat the word count as a ceiling.** Personal blog tool announcements in the
reference set run from 450 to 2,900 words, and the 450 word one does the whole
job. Announcing more than one tool in a single post is already ambitious, and
anything past 2,500 words loses the reader furthest from your field before the
section that carries the result.

**Opening.** Follow the DeepVariant pattern. Two or three paragraphs stating the
problem in numbers, then the announcement in the fourth. Never say the problem is
hard. Give the quantity that makes it hard and let the reader draw the
conclusion, the way a storage figure of 1.97 petabytes and a bill over $50,000 a
month settle the question without the word "expensive" appearing.

Openings to avoid, all drawn from real posts: a Human Genome Project preamble, a
definition both audiences already have,
<!-- prose-check:off -->
such as "DNA is the blueprint of life", and any first sentence containing "we are
proud to".
<!-- prose-check:on -->

The strongest available motivation is often not yours to assert, because someone
with more standing has already written it down. When the dominant tool in a field
disclaims the problem your work takes on, quote the disclaimer rather than
asserting the gap yourself. AlphaGenome's limitations section saying "We haven't
designed or validated AlphaGenome for personal genome prediction, a known
challenge for AI models" is the pattern to look for.

**Section skeleton.** Practitioner voice, infrastructure evidence sections,
institutional limitations section. Roughly:

1. The problem, in numbers.
2. What I built, and the headline number in a practical unit.
3. How it works. One mechanism per tool, at the depth a reader needs to believe
   the number.
4. What it costs and what it buys, with the benchmark setup stated.
5. What the tool made possible, which is the measurement.
6. What it does not do.
7. Resources.

Name sections for what the reader gets, not for what you implemented. MosaicML's
`Property: Consequence` headings are the reusable form: "Correctness: no silent
pitfalls", "Efficiency: faster startup, lower costs". A section named for the
design decision most likely to be challenged is also good, in the shape of Simon
Willison's "Why an immutable API?".

**Defining terms.** Gloss inline in an aside, once, and never in a glossary box.
Evo 2 writes "over 9.3 trillion tokens, in this case nucleotides". Evo 1 writes
"Proteins, the tiny molecular machines that make cells function". Budget about
eight defined terms for the whole post. Past that, the post is a tutorial.

**Numbers and figures.** Numbers live in prose. Both Heng Li posts in the
reference set carry zero figures and are among the most persuasive. A figure
caption states the conclusion, not the axes. If a claim rests on a magnitude, the
magnitude goes in the sentence, and a figure is never the only place a headline
number appears.

One comparison table across competing tools is the single most useful artifact
for a reader deciding whether to switch.

**Limitations.** Mandatory, as its own section, and specific. A null result the
work was designed to test belongs here as the centrepiece rather than buried, and
it is reported with the effect size, the controls it ran under, and whether it
replicates out of sample. State the unexplained variance as a number, and bound
it with what is known about the terms the study did not measure.

**Close.** A named Resources list. Manuscript with DOI, code, docs, install line.
Do not close on a hiring pitch or a demo signup, which is the worst ending in the
reference set. If a third party has verified a number, say so in one sentence.

## Guardrails

Run `scripts/check-prose.sh draft.md`. Error rules fail the file, warn rules ask
a question. The reference files themselves fire many rules, because they quote
bad writing on purpose.

Every banned pattern below appears in the reference set only in the weaker
sources. Full lists live in the two reference files.

<!-- prose-check:off -->
**Punctuation.** No em dash or en dash anywhere, including ranges. No middle dot.
Straight quotes. At most one colon per sentence and only to introduce a list. A
semicolon joining clauses becomes two sentences.

**Marketing diction.** leverage, seamless, cutting-edge, best-in-class,
game-changer, revolutionize, battle-tested, world-class, unlock, empower,
paradigm, supercharge.

**AI tells.** delve, tapestry, realm, landscape of, testament to, boasts,
showcase, underscore, pivotal, meticulous, nuanced, intricate, myriad, plethora,
crucial, vital.

**Puffery.** "proud to share", "significant milestone", "redefines", "it is worth
noting", "truly". Also robust and powerful, which are warnings rather than
errors: say what it withstands, or how fast it is.

**Constructions.** No negative parallelism, so no "not just X, it is Y" and no
"not only X but Y". No throat-clearing opener. No idiom, so no "under the hood",
"out of the box", "heavy lifting", "deep dive", "blueprint of life". No sentence
or paragraph opening with a demonstrative pronoun. No stacked rhetorical
questions. No opening with a count of things.

**Structure.** Sentence case headings. No decorative bold. Three or more clauses
in a prose sentence becomes a First, Second, Third sequence or separate
sentences. Lists capped at four or five points, used sparingly in an essay.
<!-- prose-check:on -->

**Substituting popularity for evidence** is the same failure as puffery.
"Downloaded more than 700,000 times, with 120+ citations" as a stand-in for a
benchmark appears only in the weakest post in the reference set. Adoption is a
real fact about a tool, and it is not a performance result.

## Before sending

- Does the first sentence work alone, with nothing after it?
- Is every ratio paired with an absolute, a named dataset, and a resource budget?
- Is there a sentence saying where the work loses, or where the speedup stops
  mattering?
- Could a reader check a claim by typing a proper noun into GitHub or Google?
- Is every number a fact or a measurement rather than a round decile against an
  unnamed baseline?
- Any dash, curly quote, or clause-joining semicolon?
- Any word from the banned lists?
<!-- prose-check:off -->
- Does any sentence or paragraph open with This, That, These or Those?
<!-- prose-check:on -->
- Did `check-prose.sh` come back clean on the error rules?

## Where the facts live

Before drafting, collect every headline number into one file, each with its
dataset name and its resource budget attached, and check them once against the
analysis that produced them. Draft from that file rather than rederiving figures
mid-sentence, because a number that shifts during drafting is how a wrong figure
reaches a public post. Keep a pointer from each number back to its source, so a
claim that needs more than the headline can be followed up without a search.
