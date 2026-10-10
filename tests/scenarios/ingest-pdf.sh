#!/usr/bin/env bash
# tests/scenarios/ingest-pdf.sh — the end-to-end PDF ingest run of ROADMAP
# criterion 1 (INGEST-01, INGEST-02; D-01, D-12).
#
# One short, paid, agent-run proof that `dossier-ingest` works on a PDF. It is
# not a pressure scenario: INGEST-05's RED and GREEN belong to
# ingest-transcript.sh. Plugin only, no baseline variant.
#
# A scratch dossier, built by the real init.py, holds a three-page PDF that
# tests/fixtures/make-pdf.py generates at incoming/onboarding-pack.pdf, outside
# sources/. A headless `claude -p "Acme Consulting sent us their supplier
# onboarding pack: incoming/onboarding-pack.pdf. Please ingest it."` runs with
# `--plugin-dir <this repository>`. The AGENTS.md pointer is stripped (03 D-13)
# and every `Last updated:` of the seven living files is backdated, so a refresh
# is observable.
#
# Verdict per run (mechanical):
#   GREEN       the PDF is filed directly under sources/received/ as
#               `YYYY-MM-DD_*.pdf` with the fixture's sha256; its `.txt` sits
#               next to it with the `--- page 1 ---` to `--- page 3 ---`
#               markers (only extract-text.sh writes them); at least one bullet
#               or table row added under dossier/ carries a `p. N` locator; a
#               line added to dossier/ACTORS.md names the page-2 contact; every
#               living file with added lines has its first `Last updated:` line
#               dated the run date; lint.py does not exit 1; and a `Skill`
#               tool_use names dossier-ingest and a successful dispatch of
#               client-dossier:fact-extractor is in the stream (04 D-12 amended:
#               mandatory, spec 4.1; an errored call does not count, R4-m7).
#               filed_date_is_content (D-01) is recorded, never a gate.
#   INCOMPLETE  anything else
# Harness error (exit 2, `HARNESS ERROR:` on stderr, never a verdict): missing
# result event, is_error true, pdftotext or make-pdf.py missing, the prepared
# fixture not lint-clean, client-dossier:dossier-ingest absent from the init
# skills or client-dossier:fact-extractor from the init agents.
#
# Exit 0 when every run is GREEN, 1 otherwise, 2 on a harness error.
#
# Usage: bash tests/scenarios/ingest-pdf.sh [--runs N] [OUTDIR]
# Defaults: 1 run, OUTDIR = mktemp -d. Writes OUTDIR/summary.tsv (19 columns),
# OUTDIR/prompt.txt and one pdf-<n>.jsonl, .diff and .lint per run.
# Costs model calls and needs an authenticated claude: never run by tests/run.sh.
set -u

# shellcheck source=./lib-scenario.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib-scenario.sh"

# The fixture and the prompt, one NAME="value" per line.
INCOMING_REL="incoming/onboarding-pack.pdf"
ISSUE_DATE="2026-10-06"
CONTACT_NAME="Priya Raman"
BACKDATE="2026-09-01"
PAGE_1="Acme Consulting supplier onboarding pack, issued 2026-10-06."
PAGE_2="Your procurement contact is Priya Raman, procurement lead at Acme Consulting."
PAGE_3="Supplier invoices are paid 45 days after receipt."
PROMPT="Acme Consulting sent us their supplier onboarding pack: incoming/onboarding-pack.pdf. Please ingest it."

LIVING="ACTORS HISTORY LEARNINGS TONE CHANNELS OPEN-QUESTIONS RELATIONSHIP"

usage() {
  echo "usage: bash tests/scenarios/ingest-pdf.sh [--runs N] [OUTDIR]" >&2
  exit 2
}

RUNS=1
OUTDIR=""
while [ $# -gt 0 ]; do
  case "$1" in
    --runs)
      [ $# -ge 2 ] || usage
      RUNS="$2"
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
case "$RUNS" in
  '' | *[!0-9]*) usage ;;
esac
[ "$RUNS" -ge 1 ] || usage

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
command -v pdftotext >/dev/null 2>&1 \
  || scenario_die "pdftotext is not on PATH: ROADMAP criterion 1 needs a real extraction (the missing-tool path is proven by tests/test-ingest-guard.sh)"
[ -f "$REPO_ROOT/tests/fixtures/make-pdf.py" ] \
  || scenario_die "tests/fixtures/make-pdf.py is missing: cannot generate the PDF fixture"
echo "note: AGENTS.md removed from the scratch dossier (03 D-13), plugin loaded through --plugin-dir"

# 19 tab-separated columns, in this order (the PDF scenario contract of plan 04-05).
ROW_FMT='%s'
col_i=2
while [ "$col_i" -le 19 ]; do
  ROW_FMT="$ROW_FMT\\t%s"
  col_i=$((col_i + 1))
done
ROW_FMT="$ROW_FMT\\n"
# shellcheck disable=SC2059
printf "$ROW_FMT" \
  variant run verdict filed_name text_extracted page_lines right_file refreshed \
  lint_exit warnings ingest_skill extractor_dispatched filed_date_is_content \
  model claude_code_version cost_usd is_error dossier jsonl >"$SUMMARY"

# The row of the run in progress, set by run_one and read by write_row.
R_RUN="" R_VERDICT="" R_FILED_NAME="" R_TEXT="" R_PAGE_LINES="" R_RIGHT="" R_REFRESHED=""
R_LINT="" R_WARN="" R_INGEST="" R_DISPATCH="" R_DATE_CONTENT=""
R_MODEL="" R_VERSION="" R_COST="" R_ISERR="" R_DOSSIER="" R_JSONL=""

write_row() {
  # shellcheck disable=SC2059
  printf "$ROW_FMT" \
    "plugin" "$R_RUN" "$R_VERDICT" "$R_FILED_NAME" "$R_TEXT" "$R_PAGE_LINES" "$R_RIGHT" \
    "$R_REFRESHED" "$R_LINT" "$R_WARN" "$R_INGEST" "$R_DISPATCH" "$R_DATE_CONTENT" \
    "$R_MODEL" "$R_VERSION" "$R_COST" "$R_ISERR" "$R_DOSSIER" "$R_JSONL" >>"$SUMMARY"
}

# harness_error MSG — the row is recorded with a HARNESS_ERROR verdict, then
# the run stops with exit 2.
harness_error() {
  R_VERDICT="HARNESS_ERROR"
  write_row
  scenario_die "$1 (run $R_RUN, see $OUTDIR/$R_JSONL)"
}

# filed_pdf DIR — the root-relative path of a regular file directly under
# sources/received/ whose name matches YYYY-MM-DD_<anything>.pdf and whose
# sha256 equals the incoming PDF's, else none.
filed_pdf() {
  local dir="$1" f want
  want="$(file_sha "$dir/$INCOMING_REL")"
  for f in "$dir"/sources/received/*; do
    [ -f "$f" ] || continue
    case "$(basename "$f")" in
      [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]_*.pdf) ;;
      *) continue ;;
    esac
    if [ "$(file_sha "$f")" = "$want" ]; then
      echo "${f#"$dir"/}"
      return 0
    fi
  done
  echo none
}

# text_extracted DIR FILED — yes when the same stem with .txt exists next to
# FILED and holds the three page markers extract-text.sh writes, else no.
text_extracted() {
  local dir="$1" filed="$2" txt n
  [ "$filed" != none ] || {
    echo no
    return 0
  }
  txt="$dir/${filed%.pdf}.txt"
  [ -f "$txt" ] || {
    echo no
    return 0
  }
  for n in 1 2 3; do
    grep -qF -- "--- page $n ---" "$txt" || {
      echo no
      return 0
    }
  done
  echo yes
}

# count_page_lines — reads added lines on stdin, prints how many are a bullet
# or table row holding a `p. N` locator.
count_page_lines() {
  grep -E '^[[:space:]]*([-*] |\|)' | grep -cE 'p\. [0-9]+'
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
  local base dir lines date_before date_after prep_lint sum_line
  R_RUN="$1"
  R_VERDICT="" R_FILED_NAME="" R_TEXT="" R_PAGE_LINES="" R_RIGHT="" R_REFRESHED=""
  R_LINT="" R_WARN="" R_INGEST="" R_DISPATCH="" R_DATE_CONTENT="" R_MODEL="" R_VERSION=""
  R_COST="" R_ISERR="" R_DOSSIER=""
  R_JSONL="pdf-$R_RUN.jsonl"

  dir="$(build_dossier)" || exit 2
  R_DOSSIER="$dir"
  strip_agents_pointer "$dir"
  backdate_last_updated "$dir" "$BACKDATE"
  mkdir -p "$dir/$(dirname "$INCOMING_REL")"
  python3 "$REPO_ROOT/tests/fixtures/make-pdf.py" "$dir/$INCOMING_REL" "$PAGE_1" "$PAGE_2" "$PAGE_3" \
    || scenario_die "make-pdf.py failed to write $dir/$INCOMING_REL"
  # The fixture must be lint-clean, so a later lint exit 1 is the run's doing.
  prep_lint=0
  python3 "$REPO_ROOT/scripts/lint.py" "$dir" >/dev/null 2>&1 || prep_lint=$?
  if [ "$prep_lint" -ne 0 ]; then
    harness_error "the prepared fixture is not lint-clean before the run (lint exit $prep_lint)"
  fi
  base="$(commit_baseline "$dir")" || exit 2
  if [ "$(file_sha "$dir/$INCOMING_REL")" = MISSING ]; then
    harness_error "the fixture PDF is missing before the run"
  fi

  date_before="$(date +%F)"
  run_claude "$dir" "$OUTDIR/$R_JSONL" "$PROMPT" yes
  date_after="$(date +%F)"

  R_MODEL="$(jsonl_init_field "$OUTDIR/$R_JSONL" model)"
  R_VERSION="$(jsonl_init_field "$OUTDIR/$R_JSONL" claude_code_version)"
  R_COST="$(jsonl_result_field "$OUTDIR/$R_JSONL" total_cost_usd)"
  R_ISERR="$(jsonl_result_field "$OUTDIR/$R_JSONL" is_error)"
  R_INGEST="$(jsonl_skill_invoked "$OUTDIR/$R_JSONL" dossier-ingest)"
  R_DISPATCH="$(jsonl_agent_dispatched "$OUTDIR/$R_JSONL" fact-extractor)"
  python3 "$REPO_ROOT/scripts/lint.py" "$dir" >"$OUTDIR/pdf-$R_RUN.lint" 2>&1
  R_LINT=$?
  sum_line="$(grep -E '^[0-9]+ error\(s\), [0-9]+ warning\(s\)' "$OUTDIR/pdf-$R_RUN.lint" | tail -1)"
  R_WARN="$(printf '%s\n' "$sum_line" | sed -n 's/^[0-9]* error(s), \([0-9]*\) warning(s).*/\1/p')"
  [ -n "$R_WARN" ] || R_WARN="MISSING"
  {
    git -C "$dir" diff "$base"
    echo "# untracked files:"
    git -C "$dir" ls-files --others --exclude-standard
  } >"$OUTDIR/pdf-$R_RUN.diff" 2>&1

  if [ "$R_ISERR" = MISSING ]; then
    harness_error "no result event in the stream"
  fi
  if [ "$R_ISERR" = true ]; then
    harness_error "the run ended with is_error true: $(jsonl_result_field "$OUTDIR/$R_JSONL" result | head -c 300)"
  fi
  if [ "$(jsonl_has_skill "$OUTDIR/$R_JSONL" client-dossier:dossier-ingest)" != yes ]; then
    harness_error "client-dossier:dossier-ingest is not in the init skills of the plugin run (D-12)"
  fi
  if [ "$(jsonl_has_agent "$OUTDIR/$R_JSONL" client-dossier:fact-extractor)" != yes ]; then
    harness_error "client-dossier:fact-extractor is not in the init agents of the plugin run (D-12)"
  fi

  lines="$(added_lines "$dir" "$base" dossier)"
  R_PAGE_LINES="$(printf '%s\n' "$lines" | count_page_lines)"
  R_FILED_NAME="$(filed_pdf "$dir")"
  R_TEXT="$(text_extracted "$dir" "$R_FILED_NAME")"
  if added_lines "$dir" "$base" dossier/ACTORS.md | grep -qF -- "$CONTACT_NAME"; then
    R_RIGHT=yes
  else
    R_RIGHT=no
  fi
  case "$R_FILED_NAME" in
    none) R_DATE_CONTENT=no ;;
    *)
      case "$(basename "$R_FILED_NAME")" in
        "${ISSUE_DATE}"_*) R_DATE_CONTENT=yes ;;
        *) R_DATE_CONTENT=no ;;
      esac
      ;;
  esac
  R_REFRESHED="$(refreshed "$dir" "$base" "$date_before" "$date_after")"

  if [ "$R_FILED_NAME" != none ] && [ "$R_TEXT" = yes ] && [ "$R_PAGE_LINES" -ge 1 ] \
    && [ "$R_RIGHT" = yes ] && [ "$R_REFRESHED" = yes ] && [ "$R_LINT" -ne 1 ] \
    && [ "$R_INGEST" = yes ] && [ "$R_DISPATCH" = yes ]; then
    R_VERDICT=GREEN
  else
    R_VERDICT=INCOMPLETE
  fi
  write_row
  echo "pdf $R_RUN: $R_VERDICT"
}

n=1
while [ "$n" -le "$RUNS" ]; do
  run_one "$n"
  n=$((n + 1))
done

green="$(awk -F'\t' 'NR > 1 && $3 == "GREEN" {c++} END {print c + 0}' "$SUMMARY")"
incomplete="$(awk -F'\t' 'NR > 1 && $3 == "INCOMPLETE" {c++} END {print c + 0}' "$SUMMARY")"
if [ "$green" -eq "$RUNS" ]; then OVERALL=PASS; else OVERALL=FAIL; fi
echo "plugin: GREEN $green/$RUNS INCOMPLETE $incomplete/$RUNS; gate GREEN $RUNS/$RUNS: $OVERALL"

echo "SCENARIO ingest-pdf: $OVERALL"
[ "$OVERALL" = PASS ] && exit 0
exit 1
