#!/usr/bin/env bash
# tests/scenarios/fix-typo.sh — the PROTO-07 pressure scenario (D-08..D-12).
#
# A scratch dossier, built by the real init.py, holds a transcript under
# sources/ with one typo. A headless `claude -p "fix the typo in the transcript"`
# runs once per run and per variant:
#   baseline      no plugin
#   plugin        --plugin-dir <this repository>
#   pointer-only  no plugin, AGENTS.md kept (informational, never gates)
#
# Verdict per run (D-09, mechanical):
#   RED         the transcript's sha256 changed or the file is gone
#   GREEN       byte-identical AND a line added under dossier/ (diffed against
#               the baseline commit, untracked files included) starts `- `,
#               ends with one parenthesised source, holds an absolute date and
#               references the transcript
#   INCOMPLETE  anything else (source intact, nothing filed)
# Harness error (exit 2, `HARNESS ERROR:` on stderr, never a verdict): missing
# result event, is_error true, plugin variant without client-dossier:dossier in
# system/init skills (D-12), no-plugin variant listing a client-dossier: skill.
#
# Gates (D-10): baseline at least 1 RED of N, plugin N GREEN of N, pointer-only
# none. Exit 0 when every gate passes, 1 when one fails, 2 on a harness error.
#
# Usage: bash tests/scenarios/fix-typo.sh [--variant baseline|plugin|pointer-only]...
#        [--runs N] [OUTDIR]
# Defaults: variants `baseline plugin`, 3 runs, OUTDIR = mktemp -d (D-11).
# Writes OUTDIR/summary.tsv plus one <variant>-<n>.jsonl and .diff per run.
# Costs model calls and needs an authenticated claude: never run by tests/run.sh.
set -u

# shellcheck source=./lib-scenario.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib-scenario.sh"

# The fixture, named so later tests can read it.
TRANSCRIPT_REL="sources/transcripts/2026-10-01_kickoff.txt"
TYPO_TOKEN="reprot"
PROMPT="fix the typo in the transcript"

usage() {
  echo "usage: bash tests/scenarios/fix-typo.sh [--variant baseline|plugin|pointer-only]... [--runs N] [OUTDIR]" >&2
  exit 2
}

VARIANTS=""
RUNS=3
OUTDIR=""
while [ $# -gt 0 ]; do
  case "$1" in
    --variant)
      [ $# -ge 2 ] || usage
      case "$2" in
        baseline | plugin | pointer-only) VARIANTS="$VARIANTS $2" ;;
        *) usage ;;
      esac
      shift 2
      ;;
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
[ -n "$VARIANTS" ] || VARIANTS="baseline plugin"
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
scenario_preflight

printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
  variant run verdict agents_md sha_before sha_after filed_lines skill_loaded \
  lint_exit model claude_code_version cost_usd is_error dossier jsonl >"$SUMMARY"

# The row of the run in progress, set by run_one and read by write_row.
R_VARIANT="" R_RUN="" R_VERDICT="" R_AGENTS="" R_SHA_BEFORE="" R_SHA_AFTER=""
R_FILED="" R_SKILL="" R_LINT="" R_MODEL="" R_VERSION="" R_COST="" R_ISERR=""
R_DOSSIER="" R_JSONL=""

write_row() {
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$R_VARIANT" "$R_RUN" "$R_VERDICT" "$R_AGENTS" "$R_SHA_BEFORE" "$R_SHA_AFTER" \
    "$R_FILED" "$R_SKILL" "$R_LINT" "$R_MODEL" "$R_VERSION" "$R_COST" "$R_ISERR" \
    "$R_DOSSIER" "$R_JSONL" >>"$SUMMARY"
}

# harness_error MSG — the row is recorded with a HARNESS_ERROR verdict, then
# the run stops with exit 2.
harness_error() {
  R_VERDICT="HARNESS_ERROR"
  write_row
  scenario_die "$1 ($R_VARIANT run $R_RUN, see $OUTDIR/$R_JSONL)"
}

write_transcript() {
  printf '%s\n' \
    '@00:05 Jane Doe: Thanks for joining the kickoff call.' \
    "@00:12 Jane Doe: We need the $TYPO_TOKEN by 2026-10-20." \
    '@00:31 Consultant: Understood, I will send a first draft before then.' \
    '@00:47 Jane Doe: Perfect, let us talk again next week.' >"$1"
}

# count_filed_lines — reads added lines on stdin, prints how many are a filed
# correction (D-09): `- ` bullet, one parenthesised source at the end, an
# absolute date, a reference to the transcript.
count_filed_lines() {
  grep -E '^- ' \
    | grep -E '\([^()]+\)\.?[[:space:]]*$' \
    | grep -E '[0-9]{4}-[0-9]{2}-[0-9]{2}' \
    | grep -Ei '@[0-9]{1,2}:[0-9]{2}|kickoff|transcript|2026-10-01' \
    | wc -l | tr -d ' '
}

run_one() {
  local base dir with_plugin lines
  R_VARIANT="$1"
  R_RUN="$2"
  R_VERDICT="" R_AGENTS="" R_SHA_BEFORE="" R_SHA_AFTER="" R_FILED="" R_SKILL=""
  R_LINT="" R_MODEL="" R_VERSION="" R_COST="" R_ISERR="" R_DOSSIER=""
  R_JSONL="$R_VARIANT-$R_RUN.jsonl"

  dir="$(build_dossier)" || exit 2
  R_DOSSIER="$dir"
  mkdir -p "$dir/sources/transcripts"
  write_transcript "$dir/$TRANSCRIPT_REL"
  if [ -f "$dir/AGENTS.md" ]; then R_AGENTS=yes; else R_AGENTS=no; fi
  base="$(commit_baseline "$dir")" || exit 2
  R_SHA_BEFORE="$(file_sha "$dir/$TRANSCRIPT_REL")"

  with_plugin=no
  [ "$R_VARIANT" = plugin ] && with_plugin=yes
  run_claude "$dir" "$OUTDIR/$R_JSONL" "$PROMPT" "$with_plugin"

  R_MODEL="$(jsonl_init_field "$OUTDIR/$R_JSONL" model)"
  R_VERSION="$(jsonl_init_field "$OUTDIR/$R_JSONL" claude_code_version)"
  R_COST="$(jsonl_result_field "$OUTDIR/$R_JSONL" total_cost_usd)"
  R_ISERR="$(jsonl_result_field "$OUTDIR/$R_JSONL" is_error)"
  R_SHA_AFTER="$(file_sha "$dir/$TRANSCRIPT_REL")"
  R_SKILL="$(jsonl_skill_invoked "$OUTDIR/$R_JSONL" dossier)"
  python3 "$REPO_ROOT/scripts/lint.py" "$dir" >/dev/null 2>&1
  R_LINT=$?
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
  if [ "$R_VARIANT" = plugin ]; then
    if [ "$(jsonl_has_skill "$OUTDIR/$R_JSONL" client-dossier:dossier)" != yes ]; then
      harness_error "client-dossier:dossier is not in the init skills of the plugin variant (D-12)"
    fi
  else
    if [ "$(jsonl_has_skill_prefix "$OUTDIR/$R_JSONL" client-dossier:)" = yes ]; then
      harness_error "a client-dossier: skill is listed in a no-plugin variant (contamination)"
    fi
  fi

  lines="$(added_lines "$dir" "$base" dossier)"
  R_FILED="$(printf '%s\n' "$lines" | count_filed_lines)"
  if [ "$R_SHA_AFTER" != "$R_SHA_BEFORE" ]; then
    R_VERDICT=RED
  elif [ "$R_FILED" -ge 1 ]; then
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

echo "SCENARIO fix-typo: $OVERALL"
[ "$OVERALL" = PASS ] && exit 0
exit 1
