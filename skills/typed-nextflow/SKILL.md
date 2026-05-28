---
name: typed-nextflow
description: Use when writing or modifying Nextflow (.nf) scripts on Nextflow 25.10+ / 26.04+, especially when output may default to legacy untyped DSL2 patterns (tuple inputs, `publishDir`, `Channel.from`, `|` pipes, implicit `it`, `set`/`tap`, `splitCsv` as operator). Reference for strict syntax, typed processes, typed workflows, records, typed params, workflow output blocks, and typed operator equivalents.
metadata:
  type: reference
---

# Writing Typed Nextflow (26.04+)

## Why this skill exists

Most Nextflow code in pretraining data is legacy untyped DSL2: `tuple val(id), path(reads)` inputs, `publishDir`, `Channel.from`, implicit `it`, `set`/`tap`, `|` pipes, `splitCsv` as a channel operator. As of Nextflow **25.10 / 26.04** these patterns are deprecated or unsupported under strict syntax + static types. Without explicit prompting, models regress to the old style. Use this skill whenever generating or editing `.nf` files unless the project explicitly targets an older Nextflow.

## Quick decision

- New code, no version constraint stated → **emit typed strict-syntax** (26.04 style).
- Editing a legacy or partially-typed file → first state the typed equivalent at the top of your response in one or two lines ("modernized, this would be: `tuple(id: String, …)` and `output {}` instead of `publishDir`"), then apply the edit in the file's existing style unless the user opts into a rewrite. This surfaces drift without forcing churn.
- Project pins Nextflow < 25.10 → use legacy DSL2 (but still avoid deprecated patterns: `Channel.from`, implicit `it`, `set`/`tap`, multi-arg `mix`).

## STOP — most common regressions in typed code

Even when emitting "typed" Nextflow, models routinely get these wrong. Check each before submitting:

1. **Process input destructuring (26.04 breaking change).**
   - 25.10: `(id, fastq_1, fastq_2): Tuple<String, Path, Path>`
   - **26.04**: `tuple(id: String, fastq_1: Path, fastq_2: Path)`
   The old `(name1, name2): Tuple<A, B>` syntax in an `input:` block is **rejected** in 26.04. `Tuple<A, B>` is still valid as a *channel element type* (e.g., `Channel<Tuple<String, Path>>`), just not as the process input destructure form.

2. **`groupBy` does not take a key closure.** It expects the channel to already be `(key, value)` 2-tuples (or `(key, size, value)` 3-tuples). To group by a computed key, `map` first:
   ```nextflow
   // wrong
   pairs.groupBy { p -> p[0] }
   // right
   pairs.map { id, file -> tuple(id, file) }.groupBy()
   // → emits (id, Bag<files>)
   ```

3. **Pass grouped data as one tuple input, not two parallel channels.** A grouped channel of `(id, [files])` must go into one process input, not split into two `.map` derivations passed positionally — that breaks synchronization. Destructure inside the process:
   ```nextflow
   process MERGE_FILES {
       input:
       tuple(id: String, files: List<Path>)
       // ...
   }
   workflow {
       grouped = pairs.groupBy()      // Channel<Tuple<String, Bag<Path>>>
       MERGE_FILES(grouped)            // single channel argument
   }
   ```

4. **Process section order matters.** Required order: `input:` → `stage:` (optional) → `output:` → `topic:` (optional) → `script:`/`exec:` → `stub:` (optional). Putting `output:` after `script:` is a parse error in strict syntax.

5. **Outputs are values, not bare identifiers.** Inside `output:` each line is either an unnamed value (`stdout()`, `file('x.txt')`, `record(...)`) or `name: Type = value`. The most common regression when migrating a legacy process is dropping the input/output qualifier and leaving a bare variable name:
   ```nextflow
   // legacy
   output:
   path results

   // wrong typed-style guess (model regression)
   output:
   results

   // correct typed output
   output:
   results: Path = file("${id}_results.csv")        // literal-ish name
   // or, if the script-level variable `results` is a Path/String:
   results: Path = file("${results}")
   // or, for a single unnamed output:
   file('results.csv')
   ```
   The same rule applies to `tuple(...)` and `record(...)` outputs: each output line must be a *value-producing expression*, not a variable name written alone.

6. **Don't nest `meta` inside records.** The legacy nf-core habit of "preserve the meta map" by emitting `record(meta: sample, logs: ...)` defeats the point of records. Flatten meta fields into the record:
   ```nextflow
   // anti-pattern (nf-core meta habit)
   record(meta: sample, logs: files('*_fastqc.zip'))
   // idiomatic
   record(id: sample.id, single_end: sample.single_end, logs: files('*_fastqc.zip'))
   ```
   Downstream joins use `by: 'id'`, not `by: 'meta.id'`.

## Enabling the new mode

Every typed script needs both:

```nextflow
nextflow.enable.types = true

// (strict syntax is on by default in 26.04; for 25.10 export NXF_SYNTAX_PARSER=v2)
```

The `params {}` block and the `output {}` block work *without* `nextflow.enable.types`. Typed processes and typed workflows (`take:`/`emit:` annotations) require the flag.

## Core building blocks

### 1. `params {}` block with types

Replace top-level `params.foo = ...` with a typed block:

```nextflow
params {
    // Samplesheet path
    reads: Path = "${projectDir}/data/samples.csv"

    // Optional reference; required if no default given
    transcriptome: Path

    // Default-false boolean
    save_intermeds: Boolean

    outdir: Path = 'results'
}
```

Rules:
- `params` are only meant for the entry workflow and the `output {}` block — pass them as explicit inputs to subworkflows/processes.
- A parameter without a default is **required** (run fails if unset). Booleans without defaults default to `false` in 26.04.
- CLI values are coerced to the declared type.

### 2. Records replace tuples

A record is a named-field composite. Construct with `record(...)` and define a type with `record Name { ... }`:

```nextflow
record Sample {
    id: String
    fastq_1: Path
    fastq_2: Path?     // `?` = nullable
}

def s = record(id: 'A', fastq_1: file('a_1.fq'), fastq_2: file('a_2.fq'))
s.id      // access by name, not index
```

Records are duck-typed: a record satisfies an input as long as it contains all the fields the input declares. Extra fields are ignored.

### 2b. nf-core `meta` map → record migration

The dominant pattern in pretraining data is the nf-core `(meta, files)` tuple, where `meta` is a Groovy map:

```nextflow
// legacy nf-core
process FASTQC {
    tag "${meta.id}"
    input:
    tuple val(meta), path(reads)
    output:
    tuple val(meta), path('*_fastqc.zip'), emit: zip
    // ...
}
workflow {
    ch_reads = Channel
        .fromPath(params.samplesheet)
        .splitCsv(header: true)
        .map { row ->
            def meta = [id: row.sample, single_end: row.single_end.toBoolean()]
            def reads = meta.single_end ? [file(row.fastq_1)] : [file(row.fastq_1), file(row.fastq_2)]
            tuple(meta, reads)
        }
    FASTQC(ch_reads)
}
```

Typed equivalent — **flatten the meta into the record, do not nest it**:

```nextflow
nextflow.enable.types = true

record Sample {
    id: String
    single_end: Boolean
    strandedness: String?
    reads: List<Path>
}

process FASTQC {
    tag sample.id
    input:
    sample: Sample
    output:
    record(
        id: sample.id,
        single_end: sample.single_end,
        zip: files('*_fastqc.zip'),
        html: files('*_fastqc.html')
    )
    script:
    """
    fastqc --threads ${task.cpus} ${sample.reads.join(' ')}
    """
}

workflow {
    main:
    samples = channel.of(params.samplesheet)
        .flatMap { csv -> csv.splitCsv(header: true) }
        .map { row ->
            def single = row.single_end.toBoolean()
            record(
                id: row.sample,
                single_end: single,
                strandedness: row.strandedness ?: null,
                reads: single
                    ? [file(row.fastq_1, checkIfExists: true)]
                    : [file(row.fastq_1, checkIfExists: true), file(row.fastq_2, checkIfExists: true)]
            )
        }

    fastqc = FASTQC(samples)

    publish:
    fastqc = fastqc
}

output {
    fastqc: Channel<Record> {
        // per-sample subdir, by `id` directly (no `meta.id`)
        path { r -> "fastqc/${r.id}" }
        index { path 'fastqc.csv'; header true }
    }
}
```

Conventions when migrating from nf-core meta:
- `meta + [type: 'long']` map-merge → `s + record(type: 'long')` record-merge.
- `meta.id` access → `s.id` directly; `tag "${meta.id}"` → `tag sample.id`.
- `meta.single_end ? [r1] : [r1, r2]` stays the same shape, but reads become a typed `List<Path>` field on the record.
- Per-process publishing via `publishDir { "results/fastqc/${meta.id}" }` → `output { fastqc { path { r -> "fastqc/${r.id}" } } }`.
- nf-core's `task.ext.args` / `task.ext.prefix` still work in typed processes; they aren't deprecated. Only meta-map conventions need rewriting.

### 3. Typed processes

```nextflow
nextflow.enable.types = true

process FASTQC {
    tag sample.id
    conda 'bioconda::fastqc=0.12.1'

    input:
    sample: Sample                  // by record type
    // or destructured:
    // record(id: String, fastq_1: Path, fastq_2: Path)
    // or tuple destructure:
    // tuple(id: String, fastq: Path)
    // or scalar:
    // index: Path

    output:
    record(
        id: sample.id,
        fastqc: file("fastqc_${sample.id}_logs")
    )

    script:
    """
    fastqc.sh ${sample.id} ${sample.fastq_1} ${sample.fastq_2}
    """
}
```

Key points:
- Each input is `name: Type` (or a destructured `record(...)` / `tuple(...)`).
- Type replaces qualifier: `path` → `Path`, `val` → the actual type, `path '*'` collection → `Set<Path>` (or `List<Path>` if order matters).
- `Path` inputs and `Path`-collections are auto-staged. Default stage pattern for collections is `'*'`.
- Nullable inputs: `input: Path?` (otherwise `null` fails the task).
- Outputs are regular values built with `file()`, `files()`, `stdout()`, `env('VAR')`, `record(...)`, `tuple(...)`. Single unnamed output is allowed.
- `file('x', optional: true)` returns `null` if missing instead of failing.
- `each` input qualifier is **gone** — use the `combine` operator at the call site.

### 4. The `stage:` section (replaces leftover qualifiers)

Custom staging that used to ride on input qualifiers now lives in `stage:`:

```nextflow
process grep {
    input:
    id: String
    fasta: Path

    stage:
    stageAs fasta, "${id}.fa"      // note: (value, pattern) order in 26.04
    env 'SAMPLE_ID', id
    stdin id

    script:
    "cat ${id}.fa | grep '>'"
}
```

Method signature for `stageAs` changed in 26.04 to `(value, pattern)` — value first.

### 5. Typed workflows

```nextflow
nextflow.enable.types = true

workflow RNASEQ {
    take:
    samples: Channel<Sample>
    transcriptome: Path

    main:
    index   = INDEX(transcriptome)
    fastqc  = FASTQC(samples)
    quant   = QUANT(samples, index)
    joined  = fastqc.join(quant, by: 'id')

    emit:
    samples: Channel<AlignedSample> = joined
}

record AlignedSample {
    id: String
    fastqc: Path
    quant: Path
}
```

- `Channel<T>` for streaming, `Value<T>` (or `T` shorthand) for a singleton dataflow value.
- Emit annotations are optional but recommended as docs + sanity check.
- Restricted in typed workflows: no `Channel.` capital, no implicit `it`, no `set`/`tap`, no `|`/`&`, no `.out`. Use plain assignments and method calls.

### 6. Workflow outputs (replaces `publishDir`)

Define what gets published once, at the top level. Drop `publishDir` from processes.

```nextflow
workflow {
    main:
    samples_ch = channel.of(params.reads)
        .flatMap { csv -> csv.splitCsv(header: true) }
        .map { row -> record(id: row.id, fastq_1: file(row.fastq_1), fastq_2: file(row.fastq_2)) }

    aligned_ch = RNASEQ(samples_ch, params.transcriptome)
    report     = MULTIQC(aligned_ch.flatMap { s -> [s.fastqc, s.quant] }.collect(), params.multiqc)

    publish:
    samples         = aligned_ch
    multiqc_report  = report
}

output {
    samples: Channel<AlignedSample> {
        path { s ->
            s.fastqc >> "fastqc/${s.id}"
            s.quant  >> "quant/${s.id}"
        }
        index {
            path 'samples.csv'
            header true
        }
    }

    multiqc_report: Path {
        path 'multiqc_report.html'
    }
}
```

Config side:
```groovy
workflow.output.mode = 'copy'
outputDir = 'results'      // or use -output-dir on CLI
```
`manifest.defaultBranch` is deprecated in 26.04 — drop it.

## Strict syntax cheatsheet (what's banned/required)

| Banned / deprecated | Use instead |
|---|---|
| `import groovy.json.JsonSlurper` | `new groovy.json.JsonSlurper()` (fully qualified) |
| `class Foo { ... }` in script | `enum`, `record`, or put in `lib/` |
| top-level statements mixed with declarations | put statements inside `workflow {}` |
| `for`/`while` loops | `.each {}`, `.collect {}`, `.find {}`, etc. |
| `switch` | `if/else if/else` |
| spread `*list` | enumerate or destructure |
| `${PWD}` implicit env | `env('PWD')` |
| `addParams`/`params` on `include` | pass as explicit inputs |
| `def Map x = [:]` Groovy-typed var | `def x: Map = [:]` (Nextflow-typed) or untyped `def x = [:]` |
| slashy strings with `${...}` or multi-line | double-quoted / triple-quoted |
| `(Map) x` soft cast | `x as Map` |
| `env FOO` unquoted | `env 'FOO'` |
| `process.shell` section | `script:` |
| `Channel.of(...)` | `channel.of(...)` |
| implicit `it` | `{ v -> ... }` |
| `workflow.onComplete { ... }` at top level | put inside entry workflow as `onComplete:` section |
| process `when:` section | filter at the call site |
| `params.foo` inside non-entry workflows | take as explicit input |

## Operator migration map (under `nextflow.enable.types`)

Prefer **core operators**; rewrite legacy ones.

| Legacy | Replacement |
|---|---|
| `set { ch }` | `ch = …` |
| `tap { ch }` | assign before/after the next op |
| `branch { ... }` | one `filter`/`map` per branch (records make this easy) |
| `multiMap { ... }` | one `map` per branch, or single record with all fields |
| `groupTuple` | `groupBy` — input must already be `(key, value)` 2-tuples; no key closure. To group by a derived key, `.map { x -> tuple(key(x), x) }.groupBy()`. Emits `(key, Bag<values>)`. See callout #2 above. |
| `cross` | `join(other, by: 'id')` on records |
| `combine(by: 0)` | `join(other, by: 'id')` |
| `combine(other)` | `combine(other)` (still core); for adding constant fields: `ch.combine(field: 'auto', ref: x)` |
| `concat` | `mix` (one arg per call: `a.mix(b).mix(c)`) |
| `mix(b, c)` (multi-arg) | `a.mix(b).mix(c)` |
| `merge` | `join` (deterministic) |
| `flatten` | `flatMap { … -> [...] }` |
| `transpose` | `flatMap { k, vs -> vs.collect { v -> tuple(k, v) } }` |
| `splitCsv` / `splitFasta` / `splitFastq` / `splitJson` / `splitText` as operator | `flatMap { f -> f.splitCsv(...) }` (Path stdlib method) |
| `toList` | `collect` (collect now ≡ toList: not flattened, empty list on empty) |
| `toSortedList` | `.collect().map { xs -> xs.toSorted() }` |
| `count` / `max` / `min` / `sum` | `.collect().map { xs -> xs.size() / xs.max() / ... }` |
| `first` / `last` / `take` | List methods on collected values (operator versions are non-deterministic) |
| `buffer` / `collate` | `groupBy` keyed by chunk index, or `List::collate` |
| `distinct` | `unique` |
| `randomSample` | implement explicitly; don't use (non-deterministic) |
| `dump` | `view(tag: '…')` |
| `collectFile` | a workflow output index file, or an `exec:` process |
| `ifEmpty(err)` | `.collect().subscribe { xs -> if (xs.isEmpty()) error '...' }` |
| `ifEmpty(default)` on Value | `.map { v -> v ?: default }` (typed processes emit `null` for missing optional outputs) |

Tightened semantics with types:
- `filter` requires a closure (no bare regex literal).
- `join` requires `by:` (int for tuples, string for records). No `failOnDuplicate`/`failOnMismatch` for record joins — use `remainder:` and check.
- `flatMap` does *not* auto-flatten maps/tuples; the closure must return a collection.
- `map` does *not* drop `null`; chain `.filter { v -> v != null }`.
- `mix` takes a single argument per call.

## Idiomatic skeleton

```nextflow
nextflow.enable.types = true

params {
    samplesheet: Path
    reference:   Path
    outdir:      Path = 'results'
}

record Sample {
    id: String
    fastq_1: Path
    fastq_2: Path?
}

include { ALIGN } from './modules/align'

workflow {
    main:
    samples = channel.of(params.samplesheet)
        .flatMap { csv -> csv.splitCsv(header: true) }
        .map { row ->
            record(
                id: row.id,
                fastq_1: file(row.fastq_1),
                fastq_2: row.fastq_2 ? file(row.fastq_2) : null
            )
        }

    aligned = ALIGN(samples, params.reference)

    publish:
    aligned = aligned
}

output {
    aligned: Channel<Record> {
        path { s -> "aligned/${s.id}" }
        index { path 'aligned.csv'; header true }
    }
}
```

## Common mistakes (self-check before emitting code)

- Forgetting `nextflow.enable.types = true` while using typed `input:`/`output:`/`take:`/`emit:`.
- Writing `tuple val(id), path(reads)` — that's legacy. Use `record(id: String, reads: Path)` or `tuple(id: String, reads: Path)`.
- Using `path` collection without specifying `Set<Path>` / `List<Path>`.
- Calling `splitCsv` directly on a channel — wrap in `flatMap { f -> f.splitCsv(...) }`.
- Using `Channel.from(...)` (capital + deprecated factory) → `channel.of(...)` or `channel.fromList(...)`.
- Implicit `it` in closures — always declare `{ v -> ... }`.
- `MY_WF.out.foo` — assign the call result first: `out = MY_WF(); out.foo`.
- Multi-arg `mix(a, b, c)` — chain `.mix(a).mix(b)`.
- Emitting tuples where records would carry names through joins — switch to records to avoid `branch`/`multiMap` gymnastics.
- Leaving `publishDir` in processes alongside an `output {}` block.
- `stageAs '*', value` — argument order flipped in 26.04 to `stageAs value, '*'`.

## Source docs

- Migrating to 26.04: <https://nextflow.io/docs/latest/migrations/26-04.html>
- Migrating to static types: <https://nextflow.io/docs/latest/tutorials/static-types.html>
- Operators under static types: <https://nextflow.io/docs/latest/tutorials/static-types-operators.html>
- Workflow outputs: <https://nextflow.io/docs/latest/tutorials/workflow-outputs.html>
- Typed processes: <https://nextflow.io/docs/latest/process-typed.html>
- Typed workflows: <https://nextflow.io/docs/latest/workflow-typed.html>
- Strict syntax: <https://nextflow.io/docs/latest/strict-syntax.html>

## Tested against (subagent RED/GREEN, 2026-05-12)

| Scenario | Result |
|---|---|
| Generic FastQC process from CSV samplesheet | clean on first pass |
| nf-core `(meta, reads)` tuple → typed | first pass nested `meta` inside the output record; **callout #6 added → fixed** |
| Edit a legacy partially-typed file (this repo's `throughput/benchmark.nf`), add new process | first pass used 25.10 destructure `(name): Tuple<...>` and bare-identifier output; **callouts #1 and #5 added → fixed on retest** |
| Group `(id, file)` pairs by id, call process once per id | first pass used `groupBy { closure }` and split into two parallel channels; **callouts #2 and #3 added → fixed** |
