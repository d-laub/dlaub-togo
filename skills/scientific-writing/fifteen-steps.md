# The Fifteen Steps — method reference

Distillation of **Drake JM, Han BA. "How to write a scientific paper in fifteen
steps." PLOS Computational Biology, 2025.**
<https://pmc.ncbi.nlm.nih.gov/articles/PMC12459795/>

The paper's thesis: write by a **logic of discovery, not a logic of presentation**
— finish the *thinking* (thesis, arc, method/result/finding lists, structure)
before you do any *phrasing*. This is the intellectual backbone of the
`scientific-writing` pipeline. Each stage owns a contiguous block of steps:

| Steps | Stage skill | What the step block delivers |
|------|------|------|
| 1–2 | `scientific-writing-story` | main point + two-part narrative arc |
| 3–12 | `scientific-writing-outline` | method/result/finding lists → CARS intro, findings + problem/response discussion, closing thesis, per-paragraph purpose statements, figures |
| 13–15 | `scientific-writing-draft` | topic / supporting / concluding sentences |

Cross-cutting principles (below) apply to the whole flow.

---

## Stage 1 — Story (Steps 1–2)

**Step 1 — Establish the main point.** One *short declarative sentence* (subject +
verb) that scopes the phenomenon and provides focus. It anchors every paragraph:
all content must illuminate it. Don't start writing until you know it. It need not
become the final title. → this is `story.md`'s **Thesis**.

**Step 2 — Determine the narrative arc.** Sketch the arc as a flow chart. Answer:
*What did we want to learn? Why? What did we do? What do we know now?* Verify the
arc follows the key transitions (question→answer, theory→evidence,
data→interpretation). **Two-part structures are the most memorable and
publishable.** Common two-part schemes:
- Experiment 1 + Experiment 2
- Simple model + Complicated model
- Experiment + Model to explain the results
- Model + Experiment to test the hypothesis
- Observational pattern + Model to explain the pattern

→ this is `story.md`'s **Narrative arc**; prefer one of these schemes.

---

## Stage 2 — Outline (Steps 3–12)

The outline is built from **numbered lists first, prose never** (Steps 3–5), then
those lists are arranged into sections (Steps 6–12).

**Step 3 — List methods.** A numbered list, *one method per line*, mirroring your
actual code. e.g. "rarefaction was performed on all samples for which species had
been identified." No paragraphs yet.

**Step 4 — Rationale per method.** For each Step-3 item, state *why* with an
**infinitive (to-) clause**: "*To estimate species richness*, rarefaction was
performed…". Grouped method+rationale pairs become the Methods paragraphs.

**Step 5 — List results.** A numbered list, *one observation / measurement /
statistic per line*, clear and unembellished. **Every result has a corresponding
method; every method leads to a result.** Grouped results become the Results
paragraphs.

**Step 6 — Introduction via the CARS model** (Create A Research Space). Three
moves, in order — make the first three intro paragraphs these:
1. **Territory** — establish the general context: claim centrality, state broad
   accepted topic generalizations, review prior work.
2. **Niche** — locate your work in that space; show what existing knowledge lacks
   ("no one has looked at this"). Feel free to *throw some elbows* to make room.
3. **Occupy the niche** — a clear statement of objectives/hypotheses that links to
   the methods and results. Either "We collected…, we developed…" or "Here we
   show…".

**Step 7 — Draft findings.** Findings = *results placed in interpretive context*,
each pertaining to a problem raised in the Introduction. **Findings ≠ results.**
The mapping need not be 1:1 (several results can support one finding), but there
can be **no finding unsupported by a result and no result that leads to no
finding**. Grouped findings are the *first half* of the Discussion.
- **Connector test:** put the results list and the findings list side by side and
  draw a line from each result to the finding it supports. Any unconnected item →
  add the missing partner, connect it, or cut it.

**Step 8 — List problem items.** A numbered list of caveats, inconsistencies,
statistical-assumption limits, model limitations, and anticipated objections to
the findings/results/methods.

**Step 9 — Response per problem item.** For each Step-8 item, **one** paired
response (a qualification, answer, or synthesis) that satisfies the concern or at
least states the conditions under which the work applies. **1:1 pairing.** Grouped
problem+response pairs are the *second half* of the Discussion.

**Step 10 — Closing-paragraph thesis.** The final paragraph gets *its own* thesis,
which may branch from the main thesis but must connect to it explicitly. Rules:
- **End on a positive note.**
- **Do not end with a caveat or a "need for further research."**
- A strong ending is one of: (i) a declaration of the main finding, (ii) a new
  question, or (iii) a concrete application.

**Step 11 — Purpose statement per paragraph.** Give *every* planned paragraph a
one-sentence **purpose statement** naming its role in advancing the thesis, e.g.
"This paragraph explains why we used Cormack–Jolly–Seber models rather than band
recovery models." The first three come from the CARS moves; the rest from grouped
methods, grouped results, findings, problem/response pairs, and the closing
paragraph. These are the bones of the arc. (Carry them into the draft as boldface
labels; delete before the final manuscript.)

**Step 12 — Integrate figures.** Figures exist *before* writing (from the research
phase). Most belong in Results; a conceptual figure may aid the Intro, a study
diagram the Methods. Order figures by the narrative arc; cut any figure that
doesn't illuminate the thesis.
- **Caption rule:** the caption's topic sentence must be a *complete sentence*
  (subject + verb) readable as the figure's title — not a label. Include all
  technical detail (units, error bars, parameter values, tests). The *sequence* of
  caption topic sentences should read as an abbreviation of the whole narrative,
  understandable without the main text.

---

## Stage 3 — Draft (Steps 13–15)

Each planned paragraph (its Step-11 purpose statement) becomes one paragraph of
three parts:

**Step 13 — Topic sentence.** Often the Step-11 purpose statement itself.
Alternatives: a **question** ("Why is silica limiting to *Cyclotella*?"), a
**turning point** ("Having established X, we turn to Y"), a **complication**
("This argument suggests… but it fails to account for…"), or a **development**
("This idea can be made concrete with a model"). Verify the paragraph supports the
paper's main point; if not, rewrite or delete it.

**Step 14 — Concluding sentence.** Closes the theme the topic sentence opened: if
the topic sentence declares, the concluding sentence develops/clarifies/summarizes
the support; if it asks, the concluding sentence answers it (or says why it can't
be answered). It should also **initiate the segue to the next paragraph**, in logic
if not in syntax. If topic and concluding sentences are disconnected, rewrite both.

**Step 15 — Supporting sentences.** Typically **3–6 per paragraph**. For Methods,
Results, and Conclusions, many can be **lifted directly from the numbered lists**
in Steps 4, 5, and 9. Equations, algorithms, and code snippets count as supporting
sentences. **Strike any sentence that does not advance the paragraph's purpose.**

---

## Cross-cutting principles

- **Write after the research is done.** The manuscript is retrospective, not
  prospective. Keep lab notes/protocols during the work, but begin the manuscript
  with a clean slate — starting too early reinforces preliminary interpretations
  and creates cognitive inertia.
- **Thinking before phrasing.** Steps 1–12 are the intellectual work; Steps 13–15
  are the phrasing. Don't phrase what you haven't yet thought through.
- **Generative AI is a Steps-13–15 tool, not a Steps-1–12 tool.** It helps clarify
  language, suggest alternative phrasings, and flag unsupported claims *after* the
  ideas are shaped. Do not let fluency substitute for clear thinking: complete the
  intellectual work of shaping ideas before relying on it.

## Quick verification heuristics

| Test | Question |
|------|----------|
| Connector test (Step 7) | Draw lines results↔findings — any unconnected item? |
| Paragraph purpose (Step 11) | Does this paragraph advance the main thesis? If no, cut/rewrite. |
| Problem/response (Steps 8–9) | Does each response satisfy its concern or state applicability conditions? |
| Topic↔concluding (Steps 13–14) | Does the concluding sentence close the theme the topic sentence opened? |
| Closing paragraph (Step 10) | Positive note, no "further research," ends on finding/question/application? |
