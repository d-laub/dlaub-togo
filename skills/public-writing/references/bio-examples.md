---
name: bio-examples
description: Verbatim evidence base of LinkedIn About sections and professional bios from computational biology, ML infrastructure, and open source tool authors. Source material for the public-writing style guide.
metadata:
  type: reference
---

# Bio examples, with verbatim excerpts

Gathered 2026-09-08. Every quote below is verbatim from the linked source.

## A caveat about the LinkedIn sources

LinkedIn truncates the About section at roughly 100 characters for a logged out
reader, and serves the rest only behind the login wall. The truncated string is
what appears in search snippets and in the `meta description` tag. Full About
text below comes either from a Wayback snapshot or from a section short enough
to fit under the cap. The openings in the second group are exactly what a logged
out reader sees.

The practical consequence: the first sentence does most of the work. Everything
after it is read only by someone who already decided to click.

## Length, measured

| Bio | Words |
|---|---|
| Ritchie Vink | 22 |
| Alex Wolf | 24 |
| Valentine Svensson, opening | 27 |
| Michael Hall | 41 |
| Kamil Slowikowski | 50 |
| Olga Botvinnik | 78 |
| Wes McKinney | 93 |
| PhD to industry template | 119 |
| Adam Gayoso | 123 |
| ResumeWorded data scientist template | 179 |
| Jacob Schreiber | 299 |
| Stas Bekman | 311 |

Two clusters. Twenty to fifty words for people whose name and projects already do
the work. Ninety to one hundred thirty words for someone who has to explain
themselves. Only the two longest run past 150, and both are personal site bios
rather than LinkedIn copy.

## Real LinkedIn openings, verbatim

These are the first hundred characters as LinkedIn serves them.

Avantika Lal, Principal Scientist at Genentech,
https://www.linkedin.com/in/avantikalal/

> "I'm a biologist and AI researcher working to decode the regulatory language of
> the human…"

Surag Nair, Genentech, https://www.linkedin.com/in/surag-nair-0b0597ab/

> "I work on machine learning for genomics and drug discovery, as well as
> evaluating and…"

Yusuf Roohani, Arc Institute, https://www.linkedin.com/in/yusuf-roohani-bb195231/

> "I design new machine learning approaches for modeling biological systems, with
> a…"

Stas Bekman, ML infrastructure at Snowflake, https://www.linkedin.com/in/stasbekman

> "Designing high scalability LLM training and inference systems.
>
> Training 175B+…"

Kabir Nagrecha, https://www.linkedin.com/in/kabir-nagrecha-952591152/

> "I'm the CEO and co-founder of Tessera Labs.
>
> I used to be a research scientist with…"

Six of nine sampled openings start with a first person verb phrase about work
being done, not a credential. The weaker two start with a noun phrase job label,
for example "AI Scientist with a PhD in Computational Biology and Medicine", and
read like a resume header.

Worth knowing as a counterexample: Ziga Avsec, who built Kipoi, Basenji, Enformer
and AlphaGenome, has a nine word About section that reads in full, "Passionate
about machine learning and its real-world applications."
(https://www.linkedin.com/in/avsec). An empty or generic About is common in this
field, which makes a good one differentiating rather than expected.

## Full bios from the closest peer group

### Jacob Schreiber, https://jmschrei.github.io/

The closest single analogue. Genomics deep learning plus heavy open source
tooling. 299 words.

> "I am an Assistant Professor in the Genomics and Computational Biology
> Department at UMass Chan Medical School in Worcester, MA. In previous lives, I
> was a visiting scientist at the Institute of Molecular Pathology (IMP) in
> Vienna, a postdoctoral researcher at Stanford University with Dr. Anshul
> Kundaje, and a graduate student at the University of Washington with Dr.
> William Noble.
>
> My goal is to understand the regulatory role of each nucleotide in the genome
> and how this role changes across all cells in our body. This could be done
> simply via experimental means if we had infinite money and time but, until
> then, my group will develop computational methods that work toward this goal.
> To this end, I have developed Ledidi, a method for editing biosequences to
> exhibit desired characteristics, Avocado, a deep tensor factorization approach
> for jointly modeling thousands of genome-wide regulatory experiments and
> imputing those that have not yet been performed, and a method that uses
> submodular optimization to guide future experimental efforts. These projects
> sometimes involve machine learning methods that are not mainstream, and so I
> routinely contribute to the Python open source community in the form of
> packages that implement general purpose versions of the algorithms that I apply
> to genomics. As such, I am the core developer of pomegranate, a package for
> flexible probabilistic modeling, apricot, a package for submodular
> optimization, and in the past was a core developer for scikit-learn.
>
> In addition to my research activities, I am also an editor at the Stanford AI
> Lab Blog, an editor at the Journal of Open Source Software, on the editorial
> board of reviewers for the Journal of Machine Learning Research, and
> occasionally co-host podcasts on The Bioinformatics Chat. When I don't get much
> done in a week, I pretend these are the reasons why."

The mission sentence is the hinge, and it explicitly justifies why the software
exists. The bridge sentence doing that work is worth copying in shape: "These
projects sometimes involve machine learning methods that are not mainstream, and
so I routinely contribute to the Python open source community." The close is a
joke at his own expense. There are no metrics anywhere, and roughly 20 proper
nouns.

### Adam Gayoso, https://adamgayoso.github.io/

scvi-tools co-creator, Berkeley PhD to Google DeepMind. 123 words, strict reverse
chronology.

> "I am a Senior Research Scientist at Google DeepMind working on genomics. My
> projects at GDM include AlphaGenome.
>
> Previously, I completed my PhD in the Center for Computational Biology at UC
> Berkeley co-advised by Aaron Streets and Nir Yosef. During my PhD, I developed
> deep generative models for single-cell omics data that facilitate common
> analysis tasks. I am also the co-creator of scvi-tools, which is a Python
> package that provides: (1) accessible implementations of state-of-the-art
> single-cell probabilistic models and (2) the building blocks to rapidly develop
> new models.
>
> Before my PhD, I received my BS in Operations Research: Engineering Management
> Systems and MS in Computer Science from Columbia University, where I developed
> computational models for single-cell RNA-sequencing data with the Dana Pe'er
> Lab."

The package is described by what it gives other people, in two numbered parts,
rather than by what it is technically.

### Kamil Slowikowski, https://slowkow.com/

Author of ggrepel. 50 words.

> "I'm Kamil, a computational biologist at Mass General Brigham, where I work on
> genomics projects to study human immunology.
>
> Many research labs use my single-cell data browser Cell Guide and you can see
> published datasets at Immunogenomics.io and Villani Lab.
>
> I also made ggrepel, an R package for annotating figures."

Adoption evidence rather than self assessment: "Many research labs use my", not
"I am skilled at building". He also demonstrates the plain English restatement
device further down the same page:

> "My research is in the fields of human genetics, functional genomics,
> immunology, statistics, and software development.
>
> In other words, I study data that tells us what cells are doing in our bodies.
> And I compare the cells from different people to find out what happens in
> diseases like rheumatoid arthritis, immunotherapy-related colitis, and
> COVID-19."

### Alex Wolf, https://falexwolf.me/

Scanpy creator, now co-founder and CEO of Lamin. 24 words.

> "I work on open data infra for bio/AI at Lamin.
>
> Previously, I created Scanpy and led the build-up of Cellarity's compute
> platform."

His company team page compresses further, and the shape is `scope of ownership.
Previously: credential, credential, credential.` (https://lamin.ai/about):

> "Alex Wolf, Co-Founder & CEO. Created Scanpy & led the build-up of Cellarity's
> compute platform. Two decades of building R&D software across domains and >20k
> citations on Google Scholar."

### Wes McKinney, https://wesmckinney.com/about/

93 words, third person, six named projects, no call to action.

> "Wes McKinney is an open source software developer focusing on analytical
> computing. He created the Python pandas project and is a co-creator of Apache
> Arrow, a project that remains central to his open source work. He authored
> three editions of the reference book, Python for Data Analysis. Wes is a member
> of The Apache Software Foundation and also a PMC member for Apache Parquet. He
> is the Founder at Kenn Software and also serves as a Principal Architect at
> Posit, where he contributes to Python and AI strategy. He previously co-founded
> Voltron Data."

He publishes his own trimming rule alongside it, which tells you the sentences
are ordered by descending importance:

> "If you don't have enough space for the whole biography you can trim sentences
> from the end until it is short enough."

### Ritchie Vink, https://www.ritchievink.com/about/

22 words, two facts, and a typo left in place.

> "Ritchie Vink is the orignal author of the Polars Query Engine for DataFrames.
> He is the co-founder and CEO of Polars BV."

### Olga Botvinnik, https://olgabotvinnik.com/

78 words.

> "I'm Olga Botvinnik (she/her), a peppy computational biologist. I'm currently
> building Seanome, where we build open genomics tools to unlock breakthroughs
> from ocean biodiversity.
>
> My passions include open source software, open science, tea, and Beyonce.
>
> Molecular sequence data is my happy place: I love looking at ACGTs of DNA, the
> 20+ amino acids of proteins, and thinking about what they do.
>
> My goals in life are to understand how a cell works, and make science better
> for everyone."

The "ACGTs of DNA, the 20+ amino acids" line shows specificity standing in for
metrics. The hobby line states the hobbies and does not argue for their
relevance.

### Charles Frye, https://charlesfrye.github.io/about/

The sharpest identity line in the whole sample:

> "My name is Charles Frye and I teach people on the internet."

### Rob Patro, https://github.com/rob-p

Names the class of problem rather than the field, then repeats it verbatim in the
collaboration line.

> "We (the COMBINE-lab) work mostly on algorithms and data structures for
> efficient processing, indexing, querying, and inference in high-throughput
> sequencing data."

> "I'm looking to collaborate on interesting projects related to processing,
> indexing, querying, and inference in high-throughput sequencing data (after
> all, it's what we do!)."

### Valentine Svensson, https://www.nxn.se/about

27 word opening with the email in it, then headed sections in reverse
chronology.

> "I am Valentine Svensson, a principal scientist at Tahoe Therapeutics bridging
> computational biology and machine learning for drug discovery. You can reach me
> through valentine (at) nxn.se."

His one quantitative detail is a fact rather than a result:

> "I worked at the biotechnology startup Vesalius Therapeutics, starting as one
> of the first ten employees, on analysis and statistical methods for complex in
> vitro models."

### Stas Bekman, archived at
http://web.archive.org/web/20210614205433/http://www.linkedin.com/in/stasbekman/

Two moves worth taking, and one to avoid. The contact instruction names the
friction and sits near the top rather than at the end:

> "Please don't hesitate to contact me if you need help with your ML/NLP projects
> - but I don't visit linkedin often, so it's best to email me directly at
> stas@stason.org."

The move to avoid is the trailing keyword dump, which reads as an artifact of an
older LinkedIn and dilutes the positioning:

> "Specialties: machine learning, deep learning, python, entrepreneurship, angel
> investing, SEO, monetizing websites, consulting, anti-SPAM, anti-phishing,
> Apache, mod_perl, email, Perl, C, book and articles authoring, software design,
> presenting, teaching, Reiki healing, Reflexology"

## Generic filler, quoted so it can be recognized

From https://www.seadigitalis.com/en/biotechnologist-linkedin-summary-examples/

> "As a bioinformatics biotechnologist, I bridge the gap between biology and
> computer science to analyze and interpret complex biological data. I use
> computational tools to identify patterns, predict outcomes, and develop new
> therapeutic targets."

> "I am passionate about leveraging data to drive advancements in personalized
> medicine and am eager to connect with fellow professionals in the field to
> explore collaborative opportunities."

From https://resumeworded.com/linkedin-samples/data-scientist-linkedin-summary-examples

> "When I'm not crunching numbers, I'm an avid mountain biker. I've found that the
> drive and determination needed to tackle rough trails translates well into my
> professional life. It's allowed me to better understand how to handle complex
> data sets, and ultimately, how to turn raw data into actionable insights."

> "If you're looking for someone who can make sense of big data and drive results
> for your company, I'd love to chat."

The stock templates have every structural move right. They have an origin
anecdote, a percentage, a hobby, and a call to action, and they are still inert.
Three reasons, each checkable.

First, the metrics are unanchored. "20% reduction in customer churn", "improving
its performance by 30%", "cut production costs by a whopping 40%". Every number
is a round decile against an unnamed baseline on a metric the writer never
defined. Real technical bios either give no numbers at all, or give a number that
is a fact rather than a result: "one of the first ten employees", ">20k
citations", "Training 175B+".

Second, the hobby is instrumentalized. Arguing that mountain biking taught you to
handle complex data sets is the giveaway. Authentic hobby mentions do not argue
for their own relevance. Olga Botvinnik writes "tea, and Beyonce". Charles Frye
writes that he runs tabletop roleplaying games. Neither explains why.

Third, nothing is falsifiable. The real bios are full of claims a reader could
check: a package name, a lab, an advisor, an institute, an email address.
Schreiber names two advisors, Gayoso names two, Svensson names four institutions
and a collaborator. The filler bios name no one.

## Phrases to treat as automatic rewrites

<!-- prose-check:off -->
"bridge the gap between biology and computer science", "leverage data to drive
advancements", "I am passionate about", "turn raw data into actionable insights",
"actionable insights", "I consider myself a problem solver", "I'm a believer in
the power of collaboration", "cross-functional, multidisciplinary", "thrive in
agile environments", "Passionate software developer with X years of experience",
"eager to connect with fellow professionals in the field to explore collaborative
opportunities", "seeking new opportunities", "open to opportunities", "If you're
looking for someone who can [three abstract nouns], I'd love to chat".
<!-- prose-check:on -->

## Saying what you want without sounding like an applicant

Four observed strategies, best first.

Offer help rather than asking for it. Stas Bekman writes "Please don't hesitate
to contact me if you need help with your ML/NLP projects." He is the resource,
not the applicant. Available to anyone with shipped, adopted software.

Describe the work rather than the job. Rob Patro's "I'm looking to collaborate on
interesting projects related to processing, indexing, querying, and inference in
high-throughput sequencing data." States availability without stating need.

Scope the conversation with three named topics, one of them off topic. Gijo,
quoted in LinkedIn's own editorial roundup: "Reach out if you want to talk about
emerging tech, creating software products, or baseball."

State it as a specification, in one sentence, with a role name, a geography, and
a team shape. From the PhD to industry template at
https://academiatoindustry.com/blog/linkedin-profile-tips-phd.html: "I am
currently looking for Data Scientist or NLP Engineer roles in Germany, ideally in
a product-focused team working on applied ML." It works because it is the third
of four paragraphs, so the reader already has a reason to care.

## The MIT rubric

From https://mitcommlab.mit.edu/be/commkit/professional-bio/, verbatim criteria:

> "Begins with a one-sentence main message: a memorable statement of your
> professional identity and goals"
> "Describes your experiences and qualifications that support the main message
> and match the interests of your targeted audience"
> "Concludes with a 'call to action' that encourages readers to further connect
> with you or your work"

Their sample main message:

> "Through engineering principles, I rationally design materials to enable
> on-demand delivery of therapeutics"

Their style axes are stated as tensions: impressive against credible, accomplished
against arrogant, professionalism against personality. On the second, their rule
is to emphasize concrete contributions and role rather than prestigious
affiliations.

## Conventions for an academic moving toward industry

Lead with the work, not the degree. Gayoso, Schreiber, Svensson and Wolf all
state current work first and give the PhD a subordinate clause later. The advice
sources agree, and the most repeated warning in the genre is that a PhD's About
section is either empty or reads like a dissertation abstract.

Convert software from research output to product with users. Schreiber narrates
the conversion explicitly. Gayoso describes his package by what it gives other
people. Slowikowski leads with adoption.

Translate once into plain English, early. Slowikowski's "In other words, I study
data that tells us what cells are doing in our bodies." Frye's "I teach people on
the internet." A single non-specialist sentence signals that the writer can talk
to a hiring manager or an investor.

Put keywords in prose, not in a trailing list. LinkedIn has a Skills section for
that.

<!-- prose-check:off -->
Name advisors, labs and institutions. Do not use prestige adjectives. Naming
Kundaje, Noble, Streets, Yosef or Pe'er is concrete. Calling an initiative
"world-class" is not.
<!-- prose-check:on -->

Use one transition word to do the work of a career history paragraph. "In
previous lives", "Past lives:", "Previously, I created Scanpy".

Put the email in the About section. Recruiters without InMail cannot otherwise
reach you.

## Full source list

- https://www.linkedin.com/in/avantikalal/
- https://www.linkedin.com/in/surag-nair-0b0597ab/
- https://www.linkedin.com/in/stevexniu/
- https://www.linkedin.com/in/yusuf-roohani-bb195231/
- https://www.linkedin.com/in/stasbekman and its 2021 Wayback snapshot
- https://www.linkedin.com/in/kabir-nagrecha-952591152/
- https://www.linkedin.com/in/aopisco/
- https://www.linkedin.com/in/avsec
- https://jmschrei.github.io/
- https://adamgayoso.github.io/
- https://olgabotvinnik.com/
- https://slowkow.com/
- https://falexwolf.me/ and https://lamin.ai/about
- https://www.ritchievink.com/about/
- https://wesmckinney.com/about/
- https://www.nxn.se/about
- https://mbhall88.github.io/
- https://github.com/rob-p
- https://charlesfrye.github.io/about/
- https://mitcommlab.mit.edu/be/commkit/professional-bio/
- https://academiatoindustry.com/blog/linkedin-profile-tips-phd.html
- https://www.linkedin.com/business/talent/blog/product-tips/linkedin-profile-summaries-that-we-love-and-how-to-boost-your-own
- https://resumeworded.com/linkedin-samples/data-scientist-linkedin-summary-examples
- https://www.seadigitalis.com/en/biotechnologist-linkedin-summary-examples/
- https://www.northwestern.edu/phd-postdoc-careers/your-job-search/networking-search/build-your-profile.html
