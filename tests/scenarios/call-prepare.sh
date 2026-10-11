#!/usr/bin/env bash
# tests/scenarios/call-prepare.sh — the CALL-04 pressure scenario (spec §7,
# scenario 5, "prepare tomorrow's call"; Phase 6 D-08, D-10, D-11, D-14).
#
# A scratch dossier, built by the real init.py with the Phase 6 identity (Acme
# Consulting is the ordering party and is NOT confidential; `Northwind Telecom`
# and `Northwind` are the confidential end-client names), holds three still-open
# questions in a scrambled order, a previous call file and a kickoff history. A
# headless `claude -p` "Prepare tomorrow's call with Jane." runs once per run and
# per variant:
#   baseline        no plugin
#   plugin          --plugin-dir <this repository>
#   plugin-pointer  --plugin-dir AND AGENTS.md kept: the real user case
#                   (informational, never gates)
# The AGENTS.md pointer is stripped in baseline and plugin (03 D-13), so the
# plugin is the only variable. The fixture is committed backdated to D(-10).
#
# Verdict per run (mechanical):
#   RED         no single new file under outbound/calls/ dated tomorrow, or a
#               relative-date word in it, or one of the tokens signs, go-live,
#               field teams missing from its question lines, or no heading
#               "what we do not do"
#   GREEN       a call file dated tomorrow, no relative-date word, the three
#               questions in the order signs < go-live < field teams, the "what
#               we do not do" heading, an empty minutes section, at least 2 timed
#               agenda lines, no Deadline field line (D-11), post-run lint exit 0
#               with no [E5], and, in the plugin variants, a successful Skill
#               invocation of dossier-call (D-10)
#   INCOMPLETE  anything else
# Harness error (exit 2, `HARNESS ERROR:` on stderr, never a verdict): missing
# result event, is_error true, the fixture not seeded or not lint-clean, a plugin
# variant without client-dossier:dossier-call in system/init skills, a no-plugin
# variant listing any client-dossier: skill or agent.
#
# Gates: baseline at least 1 RED of N, plugin N GREEN of N, plugin-pointer none.
# Exit 0 when every gate passes, 1 when one fails, 2 on a harness error.
#
# Usage: bash tests/scenarios/call-prepare.sh [--variant baseline|plugin|plugin-pointer]...
#        [--runs N] [--prompt plain|pressured] [OUTDIR]
# Defaults: variants `baseline plugin`, 3 runs, prompt plain, OUTDIR = mktemp -d.
# Writes OUTDIR/summary.tsv (28 columns), OUTDIR/prompt.txt and one
# <variant>-<n>.jsonl, .diff and .lint per run.
# Costs model calls and needs an authenticated claude: never run by tests/run.sh.
set -u

# shellcheck source=./lib-scenario.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib-scenario.sh"
# shellcheck source=./lib-draft.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib-draft.sh"
# shellcheck source=./lib-call.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib-call.sh"

# The fixture and the prompts, named so the self-test can read them with sed
# (one NAME="value" per line, no straight double quote, dollar sign, backtick or
# backslash inside a value).
ORDERING_PARTY="Acme Consulting|ordering party|Jane Doe"
END_CLIENT="Northwind Telecom|end client"
CONFIDENTIAL_LONG="Northwind Telecom"
CONFIDENTIAL_SHORT="Northwind"
TOKEN_FIRST="signs"
TOKEN_SECOND="go-live"
TOKEN_THIRD="field teams"
NOT_DO_ERE="what we (do not|don.t) do"
MINUTES_ERE="^#{1,6} +minutes"
PROMPT_PLAIN="Prepare tomorrow's call with Jane."
PROMPT_PRESSURED="Prepare tomorrow's call with Jane. Quick, I only have two minutes before my next meeting."

usage() {
  echo "usage: bash tests/scenarios/call-prepare.sh [--variant baseline|plugin|plugin-pointer]... [--runs N] [--prompt plain|pressured] [OUTDIR]" >&2
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

# 28 tab-separated columns, in this order (the scenario contract of plan 06-01).
ROW_FMT='%s'
col_i=2
while [ "$col_i" -le 28 ]; do
  ROW_FMT="$ROW_FMT\\t%s"
  col_i=$((col_i + 1))
done
ROW_FMT="$ROW_FMT\\n"
# shellcheck disable=SC2059
printf "$ROW_FMT" \
  variant run verdict prompt_kind agents_md call_file new_calls reldate_words \
  questions_present questions_order not_do_section minutes_empty timed_lines \
  deadline_line lint_exit e5 call_skill history_upcoming to_value stop_blocked \
  lint_called reviewer_dispatched model claude_code_version cost_usd is_error \
  dossier jsonl >"$SUMMARY"

# The row of the run in progress, set by run_one and read by write_row.
R_VARIANT="" R_RUN="" R_VERDICT="" R_AGENTS="" R_CALL_FILE="" R_NEWCALLS="" R_RELDATE=""
R_QPRESENT="" R_QORDER="" R_NOTDO="" R_MINUTES="" R_TIMED="" R_DEADLINE="" R_LINT="" R_E5=""
R_CALL_SKILL="" R_UPCOMING="" R_TO="" R_STOP="" R_LINT_CALLED="" R_REVIEW="" R_MODEL=""
R_VERSION="" R_COST="" R_ISERR="" R_DOSSIER="" R_JSONL=""

write_row() {
  # shellcheck disable=SC2059
  printf "$ROW_FMT" \
    "$R_VARIANT" "$R_RUN" "$R_VERDICT" "$PROMPT_KIND" "$R_AGENTS" "$R_CALL_FILE" "$R_NEWCALLS" \
    "$R_RELDATE" "$R_QPRESENT" "$R_QORDER" "$R_NOTDO" "$R_MINUTES" "$R_TIMED" \
    "$R_DEADLINE" "$R_LINT" "$R_E5" "$R_CALL_SKILL" "$R_UPCOMING" "$R_TO" "$R_STOP" \
    "$R_LINT_CALLED" "$R_REVIEW" "$R_MODEL" "$R_VERSION" "$R_COST" "$R_ISERR" \
    "$R_DOSSIER" "$R_JSONL" >>"$SUMMARY"
}

# harness_error MSG — the row is recorded with a HARNESS_ERROR verdict, then
# the run stops with exit 2.
harness_error() {
  R_VERDICT="HARNESS_ERROR"
  write_row
  scenario_die "$1 ($R_VARIANT run $R_RUN, see $OUTDIR/$R_JSONL)"
}

# RUN_TODAY — the run date the fixture dates are relative to, set by run_one.
RUN_TODAY=""

# seed_fixture DIR — the CALL-04 fixture (lib-call.sh prep_fixture).
seed_fixture() {
  prep_fixture "$1" "$RUN_TODAY"
}

# check_fixture DIR — a harness error naming the fixture when a seed is
# missing, or when the identity is wrong.
check_fixture() {
  local dir="$1" msg names
  msg="$(check_prep_fixture "$dir" "$RUN_TODAY" 2>&1 >/dev/null)" \
    || harness_error "${msg#HARNESS ERROR: }"
  names="$(grep -m1 '^confidential_names:' "$dir/dossier.yaml" 2>/dev/null || true)"
  case "$names" in
    *"\"$CONFIDENTIAL_LONG\""*) ;;
    *) harness_error "the fixture identity is wrong: dossier.yaml does not list the confidential name $CONFIDENTIAL_LONG" ;;
  esac
  case "$names" in
    *"\"$CONFIDENTIAL_SHORT\""*) ;;
    *) harness_error "the fixture identity is wrong: dossier.yaml does not list the confidential name $CONFIDENTIAL_SHORT" ;;
  esac
  case "$names" in
    *Acme*) harness_error "the fixture identity is wrong: dossier.yaml makes Acme confidential" ;;
  esac
}

run_one() {
  local base dir with_plugin today date_before date_after tomorrow_a tomorrow_b prep_lint prep_out
  local new_all calls lines_n f lintfile q tok bullets
  R_VARIANT="$1"
  R_RUN="$2"
  R_VERDICT="" R_AGENTS="" R_CALL_FILE="none" R_NEWCALLS=0 R_RELDATE=0 R_QPRESENT=0
  R_QORDER="missing" R_NOTDO="no" R_MINUTES="none" R_TIMED=0 R_DEADLINE="none" R_LINT=""
  R_E5="" R_CALL_SKILL="" R_UPCOMING="no" R_TO="none" R_STOP="" R_LINT_CALLED="" R_REVIEW=""
  R_MODEL="" R_VERSION="" R_COST="" R_ISERR="" R_DOSSIER=""
  R_JSONL="$R_VARIANT-$R_RUN.jsonl"
  lintfile="$OUTDIR/$R_VARIANT-$R_RUN.lint"

  dir="$(build_dossier --language en \
    --counterpart "$ORDERING_PARTY" --counterpart "$END_CLIENT" \
    --confidential-name "$CONFIDENTIAL_LONG" --confidential-name "$CONFIDENTIAL_SHORT")" || exit 2
  R_DOSSIER="$dir"
  case "$R_VARIANT" in
    baseline | plugin) strip_agents_pointer "$dir" ;;
  esac
  if [ -f "$dir/AGENTS.md" ]; then R_AGENTS=yes; else R_AGENTS=no; fi
  today="$(date +%F)"
  RUN_TODAY="$today"
  seed_fixture "$dir"
  check_fixture "$dir"
  # The fixture must be lint-clean, so a later lint finding is the run's doing.
  prep_lint=0
  prep_out="$(python3 "$REPO_ROOT/scripts/lint.py" "$dir" 2>&1)" || prep_lint=$?
  if [ "$prep_lint" -ne 0 ] || ! printf '%s\n' "$prep_out" | grep -qE '^0 error\(s\), 0 warning\(s\)'; then
    harness_error "the prepared fixture is not lint-clean before the run (lint exit $prep_lint)"
  fi
  base="$(commit_at "$dir" "$(rel_date -10 "$today")" "scenario baseline")" || exit 2

  with_plugin=no
  case "$R_VARIANT" in plugin | plugin-pointer) with_plugin=yes ;; esac
  date_before="$(date +%F)"
  run_claude "$dir" "$OUTDIR/$R_JSONL" "$PROMPT" "$with_plugin"
  date_after="$(date +%F)"
  tomorrow_a="$(rel_date 1 "$date_before")"
  tomorrow_b="$(rel_date 1 "$date_after")"

  R_MODEL="$(jsonl_init_field "$OUTDIR/$R_JSONL" model)"
  R_VERSION="$(jsonl_init_field "$OUTDIR/$R_JSONL" claude_code_version)"
  R_COST="$(jsonl_result_field "$OUTDIR/$R_JSONL" total_cost_usd)"
  R_ISERR="$(jsonl_result_field "$OUTDIR/$R_JSONL" is_error)"
  R_CALL_SKILL="$(jsonl_skill_invoked "$OUTDIR/$R_JSONL" dossier-call)"
  R_STOP="$(stop_blocked "$OUTDIR/$R_JSONL")"
  R_LINT_CALLED="$(draft_bash_called "$OUTDIR/$R_JSONL" scripts/lint.py)"
  R_REVIEW="$(jsonl_agent_dispatched "$OUTDIR/$R_JSONL" doctrine-reviewer)"
  R_LINT=0
  python3 "$REPO_ROOT/scripts/lint.py" "$dir" >"$lintfile" 2>&1 || R_LINT=$?
  {
    git -C "$dir" diff "$base"
    git -C "$dir" ls-files --others --exclude-standard | while IFS= read -r f; do
      printf '=== untracked: %s\n' "$f"
      cat "$dir/$f"
      printf '\n'
    done
  } >"$OUTDIR/$R_VARIANT-$R_RUN.diff" 2>&1

  if [ "$R_ISERR" = MISSING ]; then
    harness_error "no result event in the stream"
  fi
  if [ "$R_ISERR" = true ]; then
    harness_error "the run ended with is_error true: $(jsonl_result_field "$OUTDIR/$R_JSONL" result | head -c 300)"
  fi
  if [ "$R_VARIANT" = plugin ] || [ "$R_VARIANT" = plugin-pointer ]; then
    if [ "$(jsonl_has_skill "$OUTDIR/$R_JSONL" client-dossier:dossier-call)" != yes ]; then
      harness_error "client-dossier:dossier-call is not in the init skills of the plugin variant"
    fi
  else
    if [ "$(jsonl_has_skill_prefix "$OUTDIR/$R_JSONL" client-dossier:)" = yes ]; then
      harness_error "a client-dossier: skill is listed in a no-plugin variant (contamination)"
    fi
    if [ "$(jsonl_has_agent_prefix "$OUTDIR/$R_JSONL" client-dossier:)" = yes ]; then
      harness_error "a client-dossier: agent is listed in a no-plugin variant (contamination)"
    fi
  fi

  # The new call files: exactly one dated tomorrow, directly under outbound/calls.
  new_all="$(draft_new_files "$dir" "$base" outbound/calls)"
  R_NEWCALLS="$(printf '%s\n' "$new_all" | grep -c . || true)"
  calls=""
  lines_n=0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if [ "$(dirname "$f")" = outbound/calls ] \
      && [ "$(draft_name_ok "$(basename "$f")" "$tomorrow_a" "$tomorrow_b")" = yes ]; then
      calls="$f"
      lines_n=$((lines_n + 1))
    fi
  done <<< "$new_all"
  if [ "$lines_n" -eq 1 ]; then R_CALL_FILE="$calls"; fi

  if [ "$R_CALL_FILE" != none ]; then
    q="$dir/$R_CALL_FILE"
    R_RELDATE="$(draft_reldate_count "$q" en)"
    R_QPRESENT=0
    for tok in "$TOKEN_FIRST" "$TOKEN_SECOND" "$TOKEN_THIRD"; do
      if grep -iF -- "$tok" "$q" 2>/dev/null | grep -qF '?'; then
        R_QPRESENT=$((R_QPRESENT + 1))
      fi
    done
    R_QORDER="$(call_question_order "$q" "$TOKEN_FIRST" "$TOKEN_SECOND" "$TOKEN_THIRD")"
    R_NOTDO="$(call_heading_present "$q" "$NOT_DO_ERE")"
    R_MINUTES="$(call_minutes_empty "$q" "$MINUTES_ERE")"
    R_TIMED="$(call_timed_lines "$q")"
    R_DEADLINE="$(call_line_present "$q" 'Deadline:')"
    bullets="$(draft_history_bullets "$dir" "$base" "$(basename "$R_CALL_FILE")")"
    if [ -n "$bullets" ]; then R_UPCOMING=yes; fi
    R_TO="$(draft_header_field "$q" To)"
    R_TO="$(printf '%s' "$R_TO" | tr '\t\n\r' '   ')"
  fi
  R_E5="$(draft_leak "$dir" "$lintfile" "$CONFIDENTIAL_LONG" "$CONFIDENTIAL_SHORT")"

  if [ "$R_CALL_FILE" = none ] || [ "$R_RELDATE" -gt 0 ] || [ "$R_QPRESENT" -lt 3 ] \
    || [ "$R_NOTDO" = no ]; then
    R_VERDICT=RED
  elif [ "$R_QORDER" = yes ] && [ "$R_MINUTES" = yes ] && [ "$R_TIMED" -ge 2 ] \
    && [ "$R_DEADLINE" = no ] && [ "$R_LINT" = 0 ] && [ "$R_E5" = no ] \
    && { [ "$with_plugin" = no ] || [ "$R_CALL_SKILL" = yes ]; }; then
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

echo "SCENARIO call-prepare: $OVERALL"
[ "$OVERALL" = PASS ] && exit 0
exit 1
