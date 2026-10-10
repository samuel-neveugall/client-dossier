#!/usr/bin/env bash
# tests/scenarios/ingest-transcript.sh — the INGEST-05 pressure scenario
# (spec §7 scenario 2, "given a transcript, what did we learn"; D-10, D-12, D-13).
#
# A scratch dossier, built by the real init.py, holds a call transcript at
# incoming/call-transcript.txt, OUTSIDE sources/ and without a date in its name.
# A headless `claude -p "Here is the transcript of today's call: ... What did we
# learn?"` runs once per run and per variant:
#   baseline        no plugin
#   plugin          --plugin-dir <this repository>
#   plugin-pointer  --plugin-dir AND AGENTS.md kept: the real user case
#                   (informational, never gates)
# The AGENTS.md pointer is stripped in baseline and plugin (03 D-13), so the
# plugin is the only variable. Before the baseline commit, every variant gets
# the same fixture (D-13): every `Last updated:` of the seven living files is
# backdated to 2026-09-01 and dossier/HISTORY.md carries a seeded line that the
# transcript contradicts (15,000 versus 18,000 euros).
#
# Verdict per run (D-10, mechanical):
#   RED         no line added under dossier/ (diffed against the baseline commit,
#               untracked files included) is a bullet or table row holding an
#               `@m:ss` or `@mm:ss` locator
#   GREEN       (a) a `YYYY-MM-DD_*` file under sources/transcripts/ has the
#               fixture's sha256, (b) at least one such timestamped line was
#               added, (c) every living file with added lines has its first
#               `Last updated:` line dated the run date, (d) lint.py does not
#               exit 1; in the plugin variants (D-12) also a `Skill` tool_use
#               naming dossier-ingest. The fact-extractor dispatch is recorded
#               (extractor_dispatched) but never gates.
#   INCOMPLETE  anything else
# Harness error (exit 2, `HARNESS ERROR:` on stderr, never a verdict): missing
# result event, is_error true, the fixture missing or not lint-clean before the
# run, a plugin variant without client-dossier:dossier-ingest in system/init
# skills or client-dossier:fact-extractor in system/init agents, a no-plugin
# variant listing any client-dossier: skill or agent.
#
# Gates: baseline at least 1 RED of N, plugin N GREEN of N, plugin-pointer none.
# Exit 0 when every gate passes, 1 when one fails, 2 on a harness error.
#
# Usage: bash tests/scenarios/ingest-transcript.sh [--variant baseline|plugin|plugin-pointer]...
#        [--runs N] [--prompt plain|pressured] [OUTDIR]
# Defaults: variants `baseline plugin`, 3 runs, prompt plain, OUTDIR = mktemp -d.
# Writes OUTDIR/summary.tsv (20 columns), OUTDIR/prompt.txt and one
# <variant>-<n>.jsonl, .diff and .lint per run.
# Costs model calls and needs an authenticated claude: never run by tests/run.sh.
set -u

# shellcheck source=./lib-scenario.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib-scenario.sh"

# The fixture and the prompts, named so the self-test can read them with sed
# (one NAME="value" per line).
INCOMING_REL="incoming/call-transcript.txt"
BACKDATE="2026-09-01"
SEEDED_LINE="- Jane Doe (Acme Consulting) set the phase one budget at 15,000 euros (mail 2026-10-01 from Jane Doe)."
OLD_AMOUNT="15,000"
NEW_AMOUNT="18,000"
NEW_PERSON="Tom Becker"
PROMPT_PLAIN="Here is the transcript of today's call: incoming/call-transcript.txt. What did we learn?"
PROMPT_PRESSURED="Here is the transcript of today's call: incoming/call-transcript.txt. What did we learn? Keep it short, I'm walking into my next meeting in two minutes."

LIVING="ACTORS HISTORY LEARNINGS TONE CHANNELS OPEN-QUESTIONS RELATIONSHIP"

usage() {
  echo "usage: bash tests/scenarios/ingest-transcript.sh [--variant baseline|plugin|plugin-pointer]... [--runs N] [--prompt plain|pressured] [OUTDIR]" >&2
  exit 2
}

VARIANTS=""
RUNS=3
PROMPT_KIND="plain"
OUTDIR=""
while [ $# -gt 0 ]; do
  case "$1" in
    --variant)
      [ $# -ge 2 ] || usage
      case "$2" in
        baseline | plugin | plugin-pointer) VARIANTS="$VARIANTS $2" ;;
        *) usage ;;
      esac
      shift 2
      ;;
    --runs)
      [ $# -ge 2 ] || usage
      RUNS="$2"
      shift 2
      ;;
    --prompt)
      [ $# -ge 2 ] || usage
      case "$2" in
        plain | pressured) PROMPT_KIND="$2" ;;
        *) usage ;;
      esac
      shift 2
      ;;
    -h | --help) usage ;;
    -*) usage ;;
    *)
      OUTDIR="$1"
      shift
      ;;
  esac
done
[ -n "$VARIANTS" ] || VARIANTS="baseline plugin"
case "$RUNS" in
  '' | *[!0-9]*) usage ;;
esac
[ "$RUNS" -ge 1 ] || usage
if [ "$PROMPT_KIND" = pressured ]; then PROMPT="$PROMPT_PRESSURED"; else PROMPT="$PROMPT_PLAIN"; fi

if [ -z "$OUTDIR" ]; then
  OUTDIR="$(mktemp -d)" || scenario_die "mktemp -d failed"
fi
mkdir -p "$OUTDIR" || scenario_die "cannot create $OUTDIR"
OUTDIR="$(cd "$OUTDIR" && pwd)"
SUMMARY="$OUTDIR/summary.tsv"

echo "outdir: $OUTDIR"
printf '%s\n' "$PROMPT" >"$OUTDIR/prompt.txt"
echo "prompt: $PROMPT"
scenario_preflight
case " $VARIANTS " in
  *" baseline "* | *" plugin "*)
    echo "note: AGENTS.md removed from the scratch dossier in the baseline and plugin variants (03 D-13); plugin-pointer keeps it and is informational"
    ;;
esac

# 20 tab-separated columns, in this order (the scenario contract of plan 04-02).
ROW_FMT='%s'
col_i=2
while [ "$col_i" -le 20 ]; do
  ROW_FMT="$ROW_FMT\\t%s"
  col_i=$((col_i + 1))
done
ROW_FMT="$ROW_FMT\\n"
# shellcheck disable=SC2059
printf "$ROW_FMT" \
  variant run verdict prompt_kind agents_md filed_name timestamped_lines refreshed \
  lint_exit warnings ingest_skill extractor_dispatched corrected filed_date_is_today \
  model claude_code_version cost_usd is_error dossier jsonl >"$SUMMARY"

# The row of the run in progress, set by run_one and read by write_row.
R_VARIANT="" R_RUN="" R_VERDICT="" R_AGENTS="" R_FILED_NAME="" R_TS="" R_REFRESHED=""
R_LINT="" R_WARN="" R_INGEST="" R_DISPATCH="" R_CORRECTED="" R_FILED_TODAY=""
R_MODEL="" R_VERSION="" R_COST="" R_ISERR="" R_DOSSIER="" R_JSONL=""

write_row() {
  # shellcheck disable=SC2059
  printf "$ROW_FMT" \
    "$R_VARIANT" "$R_RUN" "$R_VERDICT" "$PROMPT_KIND" "$R_AGENTS" "$R_FILED_NAME" "$R_TS" \
    "$R_REFRESHED" "$R_LINT" "$R_WARN" "$R_INGEST" "$R_DISPATCH" "$R_CORRECTED" \
    "$R_FILED_TODAY" "$R_MODEL" "$R_VERSION" "$R_COST" "$R_ISERR" "$R_DOSSIER" \
    "$R_JSONL" >>"$SUMMARY"
}

# harness_error MSG — the row is recorded with a HARNESS_ERROR verdict, then
# the run stops with exit 2.
harness_error() {
  R_VERDICT="HARNESS_ERROR"
  write_row
  scenario_die "$1 ($R_VARIANT run $R_RUN, see $OUTDIR/$R_JSONL)"
}

# The call transcript: timestamped, no date in the file name, one line each.
write_transcript() {
  mkdir -p "$(dirname "$1")"
  printf '%s\n' \
    'Kickoff call, Acme Consulting' \
    '@00:04 Jane Doe: Thanks for joining. Tom Becker from our finance team is with me.' \
    '@00:19 Jane Doe: We confirmed the phase one budget at 18,000 euros.' \
    '@00:41 Tom Becker: Invoices go to accounts@acme.example, with the purchase order number on each one.' \
    '@01:05 Jane Doe: We need the first deliverable by 2026-11-14.' \
    '@01:32 Consultant: Understood, I will send the outline by 2026-10-24.' \
    '@02:10 Jane Doe: Maybe we extend to a phase two in January, nothing is decided.' >"$1"
}

# seed_contradicted_line DIR — D-13: SEEDED_LINE as its own line right after the
# `## Chronology` heading block of dossier/HISTORY.md (the heading, its blank
# lines and its comment), exact insertion; a harness error when the heading is
# missing.
seed_contradicted_line() {
  python3 -c '
import sys
path, line = sys.argv[1], sys.argv[2]
with open(path, encoding="utf-8", newline="") as fh:
    lines = fh.read().split("\n")
try:
    i = lines.index("## Chronology")
except ValueError:
    sys.exit(1)
j = i + 1
while j < len(lines) and (lines[j].strip() == "" or lines[j].lstrip().startswith("<!--")):
    j += 1
lines[j:j] = [line, ""]
with open(path, "w", encoding="utf-8", newline="") as fh:
    fh.write("\n".join(lines))
' "$1/dossier/HISTORY.md" "$SEEDED_LINE" \
    || scenario_die "the ## Chronology heading is missing from $1/dossier/HISTORY.md: cannot seed the contradicted line (D-13)"
}

# count_timestamped_lines — reads added lines on stdin, prints how many are a
# bullet or table row holding an @m:ss / @mm:ss locator (D-10).
count_timestamped_lines() {
  grep -E '^[[:space:]]*([-*] |\|)' | grep -cE '@[0-9]{1,2}:[0-9]{2}'
}

# filed_transcript DIR — the root-relative path of a regular file directly under
# sources/transcripts/ whose name starts with YYYY-MM-DD_ and whose sha256
# equals the incoming file's, else none.
filed_transcript() {
  local dir="$1" f want
  want="$(file_sha "$dir/$INCOMING_REL")"
  for f in "$dir"/sources/transcripts/*; do
    [ -f "$f" ] || continue
    case "$(basename "$f")" in
      [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]_*) ;;
      *) continue ;;
    esac
    if [ "$(file_sha "$f")" = "$want" ]; then
      echo "${f#"$dir"/}"
      return 0
    fi
  done
  echo none
}

# refreshed DIR BASE D1 D2 — none when no living file gained a line, yes when
# every living file with an added line has its first `Last updated:` line
# starting with D1 or D2 (the run date before and after the run), else no.
refreshed() {
  local dir="$1" base="$2" d1="$3" d2="$4" n added first any=0
  for n in $LIVING; do
    added="$(added_lines "$dir" "$base" "dossier/$n.md")"
    [ -n "$(printf '%s' "$added" | tr -d '[:space:]')" ] || continue
    any=1
    first="$(grep -m1 '^Last updated:' "$dir/dossier/$n.md" 2>/dev/null || true)"
    case "$first" in
      "Last updated: $d1"* | "Last updated: $d2"*) ;;
      *)
        echo no
        return 0
        ;;
    esac
  done
  if [ "$any" -eq 0 ]; then echo none; else echo yes; fi
}

run_one() {
  local base dir with_plugin lines date_before date_after prep_lint sum_line
  R_VARIANT="$1"
  R_RUN="$2"
  R_VERDICT="" R_AGENTS="" R_FILED_NAME="" R_TS="" R_REFRESHED="" R_LINT="" R_WARN=""
  R_INGEST="" R_DISPATCH="" R_CORRECTED="" R_FILED_TODAY="" R_MODEL="" R_VERSION=""
  R_COST="" R_ISERR="" R_DOSSIER=""
  R_JSONL="$R_VARIANT-$R_RUN.jsonl"

  dir="$(build_dossier)" || exit 2
  R_DOSSIER="$dir"
  write_transcript "$dir/$INCOMING_REL"
  # 03 D-13: baseline and plugin run without the AGENTS.md pointer, removed
  # before the baseline commit so it never shows as a change of the run.
  case "$R_VARIANT" in
    baseline | plugin) strip_agents_pointer "$dir" ;;
  esac
  if [ -f "$dir/AGENTS.md" ]; then R_AGENTS=yes; else R_AGENTS=no; fi
  # D-13: a refresh and a correction must be observable.
  backdate_last_updated "$dir" "$BACKDATE"
  seed_contradicted_line "$dir"
  # The fixture must be lint-clean, so a later lint exit 1 is the run's doing.
  prep_lint=0
  python3 "$REPO_ROOT/scripts/lint.py" "$dir" >/dev/null 2>&1 || prep_lint=$?
  if [ "$prep_lint" -ne 0 ]; then
    harness_error "the prepared fixture is not lint-clean before the run (lint exit $prep_lint)"
  fi
  base="$(commit_baseline "$dir")" || exit 2
  # A fixture that was not written is a broken harness, never a verdict.
  if [ "$(file_sha "$dir/$INCOMING_REL")" = MISSING ]; then
    harness_error "the fixture transcript is missing before the run"
  fi

  with_plugin=no
  case "$R_VARIANT" in plugin | plugin-pointer) with_plugin=yes ;; esac
  date_before="$(date +%F)"
  run_claude "$dir" "$OUTDIR/$R_JSONL" "$PROMPT" "$with_plugin"
  date_after="$(date +%F)"

  R_MODEL="$(jsonl_init_field "$OUTDIR/$R_JSONL" model)"
  R_VERSION="$(jsonl_init_field "$OUTDIR/$R_JSONL" claude_code_version)"
  R_COST="$(jsonl_result_field "$OUTDIR/$R_JSONL" total_cost_usd)"
  R_ISERR="$(jsonl_result_field "$OUTDIR/$R_JSONL" is_error)"
  R_INGEST="$(jsonl_skill_invoked "$OUTDIR/$R_JSONL" dossier-ingest)"
  R_DISPATCH="$(jsonl_agent_dispatched "$OUTDIR/$R_JSONL" fact-extractor)"
  python3 "$REPO_ROOT/scripts/lint.py" "$dir" >"$OUTDIR/$R_VARIANT-$R_RUN.lint" 2>&1
  R_LINT=$?
  sum_line="$(grep -E '^[0-9]+ error\(s\), [0-9]+ warning\(s\)' "$OUTDIR/$R_VARIANT-$R_RUN.lint" | tail -1)"
  R_WARN="$(printf '%s\n' "$sum_line" | sed -n 's/^[0-9]* error(s), \([0-9]*\) warning(s).*/\1/p')"
  [ -n "$R_WARN" ] || R_WARN="MISSING"
  {
    git -C "$dir" diff "$base"
    echo "# untracked files:"
    git -C "$dir" ls-files --others --exclude-standard
  } >"$OUTDIR/$R_VARIANT-$R_RUN.diff" 2>&1

  if [ "$R_ISERR" = MISSING ]; then
    harness_error "no result event in the stream"
  fi
  if [ "$R_ISERR" = true ]; then
    harness_error "the run ended with is_error true: $(jsonl_result_field "$OUTDIR/$R_JSONL" result | head -c 300)"
  fi
  if [ "$R_VARIANT" = plugin ] || [ "$R_VARIANT" = plugin-pointer ]; then
    if [ "$(jsonl_has_skill "$OUTDIR/$R_JSONL" client-dossier:dossier-ingest)" != yes ]; then
      harness_error "client-dossier:dossier-ingest is not in the init skills of the plugin variant (D-12)"
    fi
    if [ "$(jsonl_has_agent "$OUTDIR/$R_JSONL" client-dossier:fact-extractor)" != yes ]; then
      harness_error "client-dossier:fact-extractor is not in the init agents of the plugin variant (D-12)"
    fi
  else
    if [ "$(jsonl_has_skill_prefix "$OUTDIR/$R_JSONL" client-dossier:)" = yes ]; then
      harness_error "a client-dossier: skill is listed in a no-plugin variant (contamination)"
    fi
    if [ "$(jsonl_has_agent_prefix "$OUTDIR/$R_JSONL" client-dossier:)" = yes ]; then
      harness_error "a client-dossier: agent is listed in a no-plugin variant (contamination)"
    fi
  fi

  lines="$(added_lines "$dir" "$base" dossier)"
  R_TS="$(printf '%s\n' "$lines" | count_timestamped_lines)"
  R_FILED_NAME="$(filed_transcript "$dir")"
  case "$R_FILED_NAME" in
    none) R_FILED_TODAY=no ;;
    *)
      case "$(basename "$R_FILED_NAME")" in
        "$date_before"_* | "$date_after"_*) R_FILED_TODAY=yes ;;
        *) R_FILED_TODAY=no ;;
      esac
      ;;
  esac
  R_REFRESHED="$(refreshed "$dir" "$base" "$date_before" "$date_after")"
  R_CORRECTED=no
  if ! grep -qxF -- "$SEEDED_LINE" "$dir/dossier/HISTORY.md" 2>/dev/null \
    && printf '%s\n' "$lines" | grep -qF 'corrects a line dated'; then
    R_CORRECTED=yes
  fi

  if [ "$R_TS" -eq 0 ]; then
    R_VERDICT=RED
  elif [ "$R_FILED_NAME" != none ] && [ "$R_REFRESHED" = yes ] && [ "$R_LINT" -ne 1 ] \
    && { [ "$with_plugin" = no ] || [ "$R_INGEST" = yes ]; }; then
    R_VERDICT=GREEN
  else
    R_VERDICT=INCOMPLETE
  fi
  write_row
  echo "$R_VARIANT $R_RUN: $R_VERDICT"
}

for variant in $VARIANTS; do
  n=1
  while [ "$n" -le "$RUNS" ]; do
    run_one "$variant" "$n"
    n=$((n + 1))
  done
done

# tally VARIANT VERDICT — rows of summary.tsv with that variant and verdict.
tally() {
  awk -F'\t' -v v="$1" -v d="$2" 'NR > 1 && $1 == v && $3 == d {c++} END {print c + 0}' "$SUMMARY"
}

OVERALL=PASS
for variant in $VARIANTS; do
  red="$(tally "$variant" RED)"
  green="$(tally "$variant" GREEN)"
  incomplete="$(tally "$variant" INCOMPLETE)"
  case "$variant" in
    baseline)
      rule="RED >= 1"
      if [ "$red" -ge 1 ]; then gate=PASS; else gate=FAIL; fi
      ;;
    plugin)
      rule="GREEN $RUNS/$RUNS"
      if [ "$green" -eq "$RUNS" ]; then gate=PASS; else gate=FAIL; fi
      ;;
    *)
      rule="none"
      gate=informational
      ;;
  esac
  echo "$variant: RED $red/$RUNS GREEN $green/$RUNS INCOMPLETE $incomplete/$RUNS; gate $rule: $gate"
  [ "$gate" = FAIL ] && OVERALL=FAIL
done

echo "SCENARIO ingest-transcript: $OVERALL"
[ "$OVERALL" = PASS ] && exit 0
exit 1
