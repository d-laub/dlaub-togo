#!/usr/bin/env bash
# check-prose.sh — mechanical guardrails for public-facing prose.
#
# Usage: check-prose.sh FILE [FILE...]
#
# Every rule here is one the writer can violate on purpose. The script reports,
# it does not rewrite. Exit status is 1 if any ERROR fired, 0 otherwise.
# WARN lines never affect exit status.
#
# Rules come from skills/public-writing/SKILL.md. Keep the two in sync.

set -uo pipefail

# Lines that are not the author's own prose: fenced code, inline code spans,
# blockquotes (verbatim quotations of other people), markdown table rows, and
# regions bracketed by <!-- prose-check:off --> / <!-- prose-check:on -->.
PRUNE='
  NR == 1 && /^---[[:space:]]*$/ { inmeta = 1; next }
  inmeta && /^---[[:space:]]*$/  { inmeta = 0; next }
  inmeta { next }
  /<!--[[:space:]]*prose-check:[[:space:]]*off[[:space:]]*-->/ { off = 1; next }
  /<!--[[:space:]]*prose-check:[[:space:]]*on[[:space:]]*-->/  { off = 0; next }
  off { next }
  /^[[:space:]]*```/ { infence = !infence; next }
  infence { next }
  /^[[:space:]]*>/ { next }
  /^[[:space:]]*\|/ { next }
'

errors=0
files=("$@")

if [ ${#files[@]} -eq 0 ]; then
  echo "usage: check-prose.sh FILE [FILE...]" >&2
  exit 2
fi

# report LEVEL LABEL PATTERN
# Skips fenced code blocks and inline code spans before matching.
report() {
  local level="$1" label="$2" pattern="$3" f="$4" case="${5:-ci}"
  local greparg="-Ei"
  [ "$case" = "cs" ] && greparg="-E"
  local hits
  # Content is emitted as "<lineno><TAB><text>", so a caller's leading "^" has to
  # be re-anchored past that prefix.
  case "$pattern" in
    ^*) pattern="^[0-9]+"$'\t'"[[:space:]]*${pattern#^}" ;;
  esac
  hits=$(awk "$PRUNE"'
    { gsub(/`[^`]*`/, ""); print NR "\t" $0 }
  ' "$f" | grep "$greparg" -- "$pattern" | head -12)
  if [ -n "$hits" ]; then
    echo "$level  $label"
    echo "$hits" | sed 's/^/        /'
    [ "$level" = "ERROR" ] && errors=$((errors + 1))
  fi
  return 0
}

for f in "${files[@]}"; do
  echo "=== $f ==="

  # --- Punctuation -----------------------------------------------------------
  report ERROR "em dash or en dash (write two sentences, or 'to' for a range)" \
    $'—|–' "$f"
  report ERROR "middle dot as separator (use a comma or a new line)" \
    $'·' "$f"
  report ERROR "curly quote or curly apostrophe (use straight quotes)" \
    $'‘|’|“|”' "$f"
  report WARN "semicolon joining clauses (split into two sentences)" \
    ';' "$f"
  report WARN "emoji or symbol decoration" \
    $'[\U0001F300-\U0001FAFF☀-➿]' "$f"

  # --- Marketing and filler vocabulary ---------------------------------------
  report ERROR "marketing diction (name the mechanism instead)" \
    '\b(leverag(e|es|ed|ing)|seamless(ly)?|cutting.edge|state.of.the.art|best.in.class|game.chang(er|ing)|revolutioni[sz](e|es|ed|ing)|battle.tested|world.class|next.generation|paradigm|synerg(y|ies)|unlock(s|ed|ing)?|empower(s|ed|ing)?|supercharge)' "$f"
  report ERROR "AI-tell vocabulary" \
    '\b(delve|tapestry|realm|landscape of|testament to|boasts|showcas(e|es|ed|ing)|underscor(e|es|ed|ing)|pivotal|renowned|meticulous(ly)?|profound(ly)?|nuanced|intricate|myriad|plethora|crucial(ly)?|vital(ly)?)\b' "$f"
  report ERROR "puffery with no information" \
    '\b(proud to (share|announce)|significant milestone|redefin(e|es|ing)|truly|really quite|it is worth noting|worth noting|matters a (great deal|lot)|carries weight)\b' "$f"
  report ERROR "performed candor (be honest, do not announce that you are)" \
    '\b(worth (stating|saying|noting|mentioning|having|repeating|adding|flagging)|say(ing)? (it|so|that) out loud|said out loud|to be (honest|clear|frank|fair)|in all honesty|if I am honest|the honest (reading|answer|truth|version)|I (want|need) to be careful|worth being careful|let me be (clear|honest|careful)|it (must|should|has to) be said|it bears (repeating|saying)|for what it is worth|I will say so|full disclosure)\b' "$f"
  report ERROR "mannered self-narration (state the claim, not your posture toward it)" \
    '\b((tentative|careful|honest|modest) (conclusion|claim|reading|assessment) (I|we) (draw|make|take)|the (narrow|narrower|honest|modest) (claim|version) (is|here)|I would (go so far as|hesitate to)|(I|we) should probably (say|note|admit)|to (my|our) mind|as (I|we) see it)\b' "$f"
  report WARN "'robust' or 'powerful' (say what it withstands, or how fast)" \
    '\b(robust(ly|ness)?|powerful(ly)?)\b' "$f"

  # --- Constructions ---------------------------------------------------------
  report ERROR "negative parallelism (state what the thing is)" \
    "((it|that|this|which) (is|was)|are|is|was) not (just|only|merely|simply)|not only .* but( also)?|rather than just|isn't just|aren't just" "$f"
  report ERROR "throat-clearing opener" \
    '^[[:space:]]*(It is important to|It'"'"'s important to|In order to|At its core|At the heart of|Simply put|Put simply|In today'"'"'s|As we all know|Let'"'"'s (dive|take a look|explore))' "$f"
  report ERROR "idiom or figurative phrase (say the literal thing)" \
    '\b(under the hood|out of the box|heavy lifting|apples.to.apples|circle back|the ball rolling|move the needle|low.hanging fruit|deep dive|at the end of the day|a far cry|bread and butter|silver bullet|holy grail|north star|blueprint of life)\b' "$f"
  report ERROR "sentence or paragraph opening with a demonstrative pronoun" \
    '(^|\. )(This|That|These|Those)[[:space:]]+(is|are|was|were|means|gives|makes|lets|allows|shows|matters|works|way|approach|change|result|number|problem)' "$f"
  report WARN "vague magnitude word (look up the span and write it down)" \
    '\b(orders of magnitude|substantially|significantly|dramatically|vastly|considerably|much (faster|larger|smaller|better)|widely|greatly|massively|enormous(ly)?)\b' "$f"
  report WARN "hedge (keep only if the uncertainty is real)" \
    '\b(perhaps|arguably|somewhat|fairly|quite possibly|might possibly|could potentially|in some sense|to some extent)\b' "$f"
  report WARN "fake agency for a system (name the person or process)" \
    '\b(becomes? (a |an |the )?(record|source of truth)|transforms itself|decides to|wants to|knows how to|learns to (understand|appreciate))\b' "$f"

  # --- Structure -------------------------------------------------------------
  report WARN "opening with a count of things" \
    '^[[:space:]]*(Two|Three|Four|Five|Several|A few|A number of) (things|points|reasons|cautions|takeaways|lessons|caveats)\b' "$f"
  report WARN "Title Case heading (use sentence case)" \
    '^#{1,6} +([A-Z][A-Za-z]* ){3,}[A-Z][a-z]+' "$f" cs
  report WARN "rhetorical question" \
    '^[A-Z][^-*.!#]*\?[[:space:]]*$' "$f" cs

  # --- Numbers ---------------------------------------------------------------
  # A bare speed or size ratio with no dataset and no resource budget nearby is
  # the most common way a true claim reads as a boast.
  awk "$PRUNE"'
    /[0-9]+(\.[0-9]+)?[[:space:]]*(x|times|-fold|fold)[[:space:]]*(faster|smaller|less|fewer|larger|more|reduction|speed)/ {
      if ($0 !~ /GPU|CPU|thread|RAM|GB|GiB|TB|PB|core|sample|genome|cohort|on (the|a) [A-Z]/) {
        print NR "\t" $0
      }
    }
  ' "$f" | head -12 | { hits=$(cat); if [ -n "$hits" ]; then
      echo "WARN   ratio with no named dataset and no resource budget on the same line"
      echo "$hits" | sed 's/^/        /'
    fi; }

  # --- Sentence length -------------------------------------------------------
  # Three or more clauses in one prose sentence. Approximated by comma count.
  awk "$PRUNE"'
    /^[[:space:]]*[-*0-9]/ { next }          # skip list items
    /^[[:space:]]*#/ { next }                # skip headings
    {
      line = $0
      n = gsub(/,/, ",", line)
      if (n >= 3) print NR "\t" $0
    }
  ' "$f" | head -12 | { hits=$(cat); if [ -n "$hits" ]; then
      echo "WARN   three or more clauses in one sentence (split it, or use First/Second/Third)"
      echo "$hits" | sed 's/^/        /'
    fi; }

  echo
done

if [ "$errors" -gt 0 ]; then
  echo "$errors error rule(s) fired."
  exit 1
fi
echo "No error rules fired."
exit 0
