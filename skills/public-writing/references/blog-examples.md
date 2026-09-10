---
name: blog-examples
description: Verbatim evidence base of technical blog posts that announce scientific software or ML models. Source material for the public-writing style guide.
metadata:
  type: reference
---

# Blog post examples, with verbatim excerpts

Gathered 2026-09-08 by fetching each post. Grouped by genre. Every quote below is
verbatim from the linked source.

## The four templates found in the wild

**Template 1, institutional model announcement.** 1,200 to 2,200 words.
Problem in the world, then "Today we introduce X", then how it works, then two to
four named feature sections, then benchmarks, then what you can do with it, then
current limitations, then how to get it.
Used by AlphaGenome, AlphaMissense, Evo, Nucleotide Transformer.

**Template 2, infrastructure and performance post.** 1,300 to 4,800 words.
What is the problem, told through a specific war story, then "your code does not
change", then sections named `Property: Consequence`, then benchmarks with the
methodology stated, then where the tool is still behind, then a getting-started
command.
Used by MosaicML StreamingDataset, Hugging Face streaming, Ray Data, DuckDB.

**Template 3, practitioner tool announcement.** 450 to 2,900 words.
Why the existing tool stopped working, with the specific triggering event, then
what I built, then the headline number in a practical unit, then how it works,
then what it is still worse at, then what is next, then a link to the repo.
Used by minimap2, minibwa, Datasette, Polars.

**Template 4, layered explainer.** 4,000 to 7,000 words.
An audience contract in the second paragraph, then the high-level picture, then
the same thing in detail, then the same thing in equations or code, then when to
use it and when not to.
Used by The Illustrated Transformer, Attention? Attention!, What Is Zarr?

## The three best openings

### DeepVariant, Google Research, 2017-12-04
https://research.google/blog/deepvariant-highly-accurate-genomes-with-deep-neural-networks/

Teaches the biology problem to an ML reader across three paragraphs, then
announces in the fourth. It never says the problem is hard. It states the numbers
and lets the reader feel it.

> "One of the most transformative new technologies in genomics was
> high-throughput sequencing (HTS), which first became commercially available in
> the early 2000s. HTS allowed scientists and clinicians to produce sequencing
> data quickly, cheaply, and at scale. However, the output of HTS instruments is
> not the genome sequence for the individual being analyzed. For humans this is 3
> billion paired bases (guanine, cytosine, adenine and thymine) organized into 23
> pairs of chromosomes. Instead, these instruments generate ~1 billion short
> sequences, known as reads. Each read represents just 100 of the 3 billion
> bases, and per-base error rates range from 0.1-10%."

The reframing sentence that lets an ML reader import all their intuition at once:

> "DeepVariant transforms the task of variant calling, as this reconstruction
> problem is known in genomics, into an image classification problem well-suited
> to Google's existing technology and expertise."

### minimap2, Heng Li, 2018-04-02
https://lh3.github.io/2018/04/02/minimap2-and-the-future-of-bwa

The motivation is a dated event, not a trend, and the failure being described is
his own prior tool.

> "In early 2017, Nick Loman et al invented a new protocol to sequence nanopore
> reads of 100kb in length. Bwa-mem failed miserably on such ultra-long reads, it
> was not "fine" at all. In addition, not long after I published minimap, Suzuki
> and Kasahara released minialign. It implements a banded base-level alignment
> algorithm that is practical for long-read alignment and much faster than the
> alternatives. These events finally motivated me to develop minimap2."

He also shows the reasoning rather than asserting a need:

> "I didn't expand minimap to a full-pledge aligner because (1) I knew base-level
> alignment was going to be very slow and (2) bwa-mem still worked fine. However,
> both reasons became invalid in the coming years."

### Hugging Face streaming datasets, 2025-10-27
https://huggingface.co/blog/streaming-datasets

A specific, embarrassing, quantified personal failure.

> "Loading data, especially at the terabyte scale, is a major pain in any machine
> learning workflow. We suffered this while training SmolLM3, at one point we had
> to wait 3 hours before each run to download enough data."

> "Soon we found a big issue: our test run generated over 100,000 requests in
> under a minute, which got our IP blocked by the Hub! This happened because every
> DataLoader worker was initializing the dataset independently."

## Openings that work less well

Enformer opens with four sentences of Human Genome Project textbook before
anything is at stake. Nucleotide Transformer opens with "DNA is the blueprint of
life", a definition both audiences already have.

## The five honesty techniques

### 1. Report where you lose

Ray Data, https://www.anyscale.com/blog/fast-flexible-scalable-data-loading-for-ml-training-with-ray-data

> "Ray Data is within ~30% of PyTorch DataLoader's throughput. This performance
> gap comes from Ray Data doing extra data conversions compared to PyTorch
> DataLoader."

> "tf.data is fastest at loading images alone. However, this performance edge will
> be limited to TensorFlow models."

Contrast with TileDB,
https://tiledb.com/blog/population-genomics-is-a-data-management-problem/

> "It couldn't be easier to get up and running."

### 2. Say when the speedup does not matter

MosaicML, https://www.databricks.com/blog/mosaicml-streamingdataset

> "For larger model training like LLMs and Stable Diffusion, this effect
> disappears as the models are not dataloader bottlenecked."

Heng Li, minibwa, https://lh3.github.io/2026/07/04/minibwa-is-the-new-bwa

> "minibwa is currently fast enough that further performance optimizations would
> yield diminishing returns for overall pipelines."

### 3. Undercut the headline in the same paragraph

gnomAD v4, https://gnomad.broadinstitute.org/news/2023-11-gnomad-v4-0/

> "The gnomAD v4 release adds additional global diversity and includes ~138,000
> individuals of non-European genetic ancestry. However, the new inclusion of
> cohorts such as the UK Biobank means that the proportion of samples with
> European ancestry is higher than in previous releases."

### 4. State the scope you did not validate

AlphaGenome, https://deepmind.google/discover/blog/alphagenome-ai-for-better-understanding-the-genome/

> "We haven't designed or validated AlphaGenome for personal genome prediction, a
> known challenge for AI models. Instead, we focused more on characterising the
> performance on individual genetic variants."

A flagship model disclaiming the exact problem a smaller tool takes on is the
strongest motivation that tool can cite. Quote the disclaimer rather than
asserting the gap.

AlphaGenome's full limitations section is the best honest-caveat writing found in
any corporate post:

> "Like other sequence-based models, accurately capturing the influence of very
> distant regulatory elements, like those over 100,000 DNA letters away, is still
> an ongoing challenge. Another priority for future work is further increasing
> the model's ability to capture cell- and tissue-specific patterns."

Heng Li on his own new tool, against his own old tool:

> "minimap2 is not ready to replace bwa-mem all around"
> "minimap2 is not as consistent as bwa-mem for short reads of varying quality"
> "bwa-mem is still better for production uses, at least before I find a way to
> improve minimap2"

### 5. Attach every number to a setup or a practical unit

gnomAD:

> "only uses 18TB in storage (vs 897TB for a traditional project VCF)"
> "cuKING was able to compute relatedness across the v4 exomes and genomes in
> approximately 1.5 hours at a cost of $243"

FFCV, https://ffcv.io/ :

> "train an ImageNet model on one GPU in 35 minutes (98 cents per model on AWS)"

Heng Li, minibwa:

> "Aligning 30X human reads in 50 minutes over 32 CPU threads, it might outpace
> other upstream/downstream tools if you are not careful."

MosaicML figure caption, which states the conclusion rather than the axes:

> "StreamingDataset is faster than alternative solutions. Results shown are from
> ImageNet + ResNet-50 training, collected over 5 repetitions after data shards
> are cached after epoch 1."

Contrast, TileDB, the same claim shape with no number:

> "We have battle-tested our solution on datasets in the order of hundreds of TBs
> with our customers."

## Making a number mean something

AlphaMissense, https://deepmind.google/discover/blog/a-catalogue-of-genetic-mutations-to-help-pinpoint-the-cause-of-diseases/

> "The average person is carrying more than 9,000 missense variants."

> "Of more than 4 million missense variants that have been seen already in humans,
> only 2% have been annotated as pathogenic or benign by experts, roughly 0.1% of
> all 71 million possible missense variants."

Evo, https://arcinstitute.org/news/evo

> "For comparison, a gene essentiality experiment in the laboratory could require
> 6 months to a year of experimental effort."

Heng Li making a maintainability argument with a number:

> "bwa-mem2 doubles the lines of code of bwa-mem; bwa-meme further doubles
> bwa-mem2."

Pattern to copy: pair a big ratio with an absolute. The ratio persuades, the
absolute makes it checkable. gnomAD gives "nearly 5x larger" and "807,162 total
individuals" in the same sentence.

## Phrases that read as marketing

Every one of these appears only in the weaker posts.

<!-- prose-check:off -->
"we are proud to share", "marks a significant milestone", "redefines our
approach", "a giant corpus", "the power of X's universality", "revolutionizing",
"battle-tested", "It couldn't be easier", "providing a powerful foundation for".
<!-- prose-check:on -->

Substituting popularity for evidence is the same failure. Nucleotide Transformer:

> "downloaded more than 700,000 times, with 120+ citations"

Closings that read worst are demo signups. MosaicML:

> "We'll get you training high-quality, multibillion-parameter models in hours
> instead of months. We handle the heavy lifting and orchestration, so you can
> focus on your model training. If this sounds good, sign up for a demo today!"

## Section heading conventions

MosaicML names sections as `Property: Consequence`, which organizes the post
around what the reader gets rather than what the author implemented.

> What's the Problem? / Correctness: No Silent Pitfalls / Efficiency: Faster
> Startup, Lower Costs / Works at Scale / Ease of Use: The StreamingDataset /
> Getting Started / What's Next?

Earthmover's Zarr post uses "Use Zarr if" and "Zarr might not be ideal if" as
literal headings, which is the cleanest scoping device found. It adapts to any
tool by substituting the name.

Simon Willison names a section for the design decision most likely to be
challenged, "Why an immutable API?".

Jay Alammar escalates resolution and announces it in the headings, so a
mixed-audience reader can stop at any level: A High-Level Look, then
Self-Attention at a High Level, then Self-Attention in Detail, then Matrix
Calculation of Self-Attention.

## Defining a term without a glossary

Evo 2 glosses inline, twice, in an aside:

> "over 9.3 trillion tokens, in this case nucleotides"
> "9.3 trillion nucleotides, the building blocks that make up DNA or RNA"

Evo 1 glosses for ML readers:

> "Proteins, the tiny molecular machines that make cells function"
> "RNA, which helps DNA transmit information and often helps proteins accomplish
> their functions."

## Linking conventions

A named Resources block at the end, as a list, is the dominant convention. Evo's
is the best: manuscript with DOI, playground, code, Hugging Face checkpoint, pip
install line, lab pages.

Inline links on first mention for the paper and the repo, repeated in the end
block. Nobody hides the code link.

Put something runnable in the post. Hugging Face shows the same four-line snippet
at the top, to prove nothing changed, and at the bottom, to start the reader off.

Cite third parties who verified you. Heng Li:

> "Andrew Carroll has kindly confirmed the performance of minibwa independently on
> multiple non-human datasets."

Polars links the external h2oai benchmark rather than a self-run one, and dates
corrections in place rather than editing silently:

> "update 2021-03-14: Benchmarks age poorly, Polars now has the fastest join
> algorithm in the benchmark."

## Figure counts

Model announcements carry one to five figures, and the numbers live in prose.
Infrastructure posts carry tables and charts, with captions that state the
conclusion. Personal-blog tool posts often carry zero figures. Both Heng Li posts
have none, and the numbers sit in the sentences.

Ray Data includes one feature comparison table across every competing tool, which
is the single most useful artifact for a reader deciding whether to switch.

## The empty niche

No well-known blog post announces a genomics data loader for deep learning.
gReLU, tiledb-vcf, and cellxgene-census all shipped with papers and READMEs and
no narrative post. The nearest neighbours are all outside genomics: MosaicML,
Hugging Face, Ray Data, FFCV.

Hail's "An Origin Story for Scalable Genomics Analysis"
(https://blog.hail.is/introtohail/) is the closest post in spirit, and its
framing is a ready-made way to explain why a special purpose loader exists.
Genomic data does not fit the dataframe abstraction, because rows are sites,
columns are samples, and genotypes add a third dimension. The site was returning
503 during collection, so retrieve it by hand before relying on it.

## Full source list

- https://deepmind.google/discover/blog/predicting-gene-expression-with-ai/ (Enformer, 2021-10-04, ~1,200 words)
- https://deepmind.google/discover/blog/alphagenome-ai-for-better-understanding-the-genome/ (2025-06-25, ~2,200 words)
- https://deepmind.google/discover/blog/a-catalogue-of-genetic-mutations-to-help-pinpoint-the-cause-of-diseases/ (AlphaMissense, 2023-09-19, ~2,200 words)
- https://arcinstitute.org/news/blog/evo2 (2025-02-19, ~1,850 words)
- https://arcinstitute.org/news/evo and https://www.together.ai/blog/evo (2024-02-27, ~2,100 words)
- https://research.google/blog/deepvariant-highly-accurate-genomes-with-deep-neural-networks/ (2017-12-04, ~1,400 words)
- https://instadeep.com/2024/12/decoding-our-genome-with-nucleotide-transformers/ (2024-12-05, ~1,100 words)
- https://gnomad.broadinstitute.org/news/2023-11-gnomad-v4-0/ (2023-11-01, ~4,900 words)
- https://www.databricks.com/blog/mosaicml-streamingdataset (2023-02-09, ~2,800 words)
- https://huggingface.co/blog/streaming-datasets (2025-10-27, ~1,300 words)
- https://www.anyscale.com/blog/fast-flexible-scalable-data-loading-for-ml-training-with-ray-data (2023-09-15, ~4,800 words)
- https://www.ritchievink.com/blog/2021/02/28/i-wrote-one-of-the-fastest-dataframe-libraries/ (2021-02-28, ~2,900 words)
- https://duckdb.org/2021/05/14/sql-on-pandas.html (2021-05-14, ~4,500 words)
- https://ffcv.io/
- https://tiledb.com/blog/population-genomics-is-a-data-management-problem/ (2021-11-16, ~2,850 words)
- https://lh3.github.io/2018/04/02/minimap2-and-the-future-of-bwa (2018-04-02, ~1,100 words)
- https://lh3.github.io/2026/07/04/minibwa-is-the-new-bwa (2026-07-04, ~450 words)
- https://simonwillison.net/2017/Nov/13/datasette/ (2017-11-13, ~2,800 words)
- https://liorpachter.wordpress.com/2026/02/19/the-quickening/ (2026-02-19, ~3,100 words)
- https://vickiboykis.com/2024/01/05/retro-on-viberary/ (2024-01-05, ~11,500 words)
- https://jalammar.github.io/illustrated-transformer/ (2018-06-27, ~5,200 words)
- https://lilianweng.github.io/posts/2018-06-24-attention/ (2018-06-24, ~6,800 words)
- https://www.earthmover.io/blog/what-is-zarr/ (2025-05-20, ~4,200 words)
