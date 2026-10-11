#!/usr/bin/env bash
# tests/scenarios/deal-status.sh — the CALL-05 pressure scenario (spec §7,
# scenario 4, "where are we with this deal"; Phase 6 D-08, D-10, D-16).
#
# A scratch dossier, built by the real init.py with the Phase 6 identity (Acme
# Consulting is the ordering party and is NOT confidential; `Northwind Telecom`
# and `Northwind` are the confidential end-client names), holds the hardened
# D-16 fixture: about 15 sources, at least 30 Chronology lines and three
# independent seeds with distinctive tokens (an overdue Ours commitment, the
# `security questionnaire`; an overdue draft, the `steering` agenda, that no
# history line names; an unreflected source, the `brochure`), plus traps (a
# commitment citing a sent mail, a draft that is not due yet, a commitment closed
# with `done <date>`). The fixture is committed in dated stages, so the first
# commit time of every source is meaningful. A headless `claude -p` runs once per
# run and per variant, by default with the pressured prompt (D-16):
#   baseline        no plugin
#   plugin          --plugin-dir <this repository>
#   plugin-pointer  --plugin-dir AND AGENTS.md kept: the real user case
#                   (informational, never gates)
# The AGENTS.md pointer is stripped in baseline and plugin (03 D-13), so the
# plugin is the only variable.
#
# Verdict per run (mechanical):
#   RED         the final answer misses `security questionnaire`, `steering` or
#               `brochure` (case-insensitive, - and _ folded to a space)
#   GREEN       all three named, the dossier tree including .git byte-identical,
#               `git status --porcelain` empty and, in the plugin variants,
#               dossier-status invoked (Skill tool_use with a successful result)
#               and a Bash command that ran scripts/status.py (D-10)
#   INCOMPLETE  anything else
# Harness error (exit 2, `HARNESS ERROR:` on stderr, never a verdict): missing
# result event, is_error true, the fixture not seeded, not lint-clean or dirty
# before the run, a plugin variant without client-dossier:dossier-status in
# system/init skills, a no-plugin variant listing any client-dossier: skill or
# agent.
#
# Gates: baseline at least 1 RED of N, plugin N GREEN of N, plugin-pointer none.
# Exit 0 when every gate passes, 1 when one fails, 2 on a harness error. When the
# baseline records 0 RED the gate fails (exit 1): the D-16 fallback, "baseline
# recorded", is then applied by hand, never by relaxing a rule.
#
# Usage: bash tests/scenarios/deal-status.sh [--variant baseline|plugin|plugin-pointer]...
#        [--runs N] [--prompt plain|pressured] [OUTDIR]
# Defaults: variants `baseline plugin`, 3 runs, prompt pressured, OUTDIR = mktemp -d.
# Writes OUTDIR/summary.tsv (25 columns), OUTDIR/prompt.txt and one
# <variant>-<n>.jsonl, .diff, .lint and .treediff per run.
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
SEED_COMMITMENT="security questionnaire"
SEED_DRAFT="steering"
SEED_SOURCE="brochure"
TRAP_SENT="revised-quote"
TRAP_FUTURE="pilot-plan"
TRAP_DONE="signed NDA"
STALE_NAME="RELATIONSHIP"
PROMPT_PLAIN="Where are we with this deal?"
PROMPT_PRESSURED="Quick one, I'm about to jump on a call with Jane: where are we with this deal? Just the gist."

usage() {
  echo "usage: bash tests/scenarios/deal-status.sh [--variant baseline|plugin|plugin-pointer]... [--runs N] [--prompt plain|pressured] [OUTDIR]" >&2
  exit 2
}

VARIANTS=""
RUNS=3
PROMPT_KIND="pressured"
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

# 25 tab-separated columns, in this order (the scenario contract of plan 06-01).
ROW_FMT='%s'
col_i=2
while [ "$col_i" -le 25 ]; do
  ROW_FMT="$ROW_FMT\\t%s"
  col_i=$((col_i + 1))
done
ROW_FMT="$ROW_FMT\\n"
# shellcheck disable=SC2059
printf "$ROW_FMT" \
  variant run verdict prompt_kind agents_md commitment_reported draft_reported \
  source_reported tree_unchanged porcelain_empty status_skill status_script_run \
  trap_sent_named trap_future_named trap_done_named stale_named reads lint_called \
  changed_paths model claude_code_version cost_usd is_error dossier jsonl >"$SUMMARY"

# The row of the run in progress, set by run_one and read by write_row.
R_VARIANT="" R_RUN="" R_VERDICT="" R_AGENTS="" R_COMMIT="" R_DRAFT="" R_SOURCE="" R_TREE=""
R_PORCELAIN="" R_SKILL="" R_SCRIPT="" R_TSENT="" R_TFUTURE="" R_TDONE="" R_STALE="" R_READS=""
R_LINT_CALLED="" R_CHANGED="" R_MODEL="" R_VERSION="" R_COST="" R_ISERR="" R_DOSSIER="" R_JSONL=""

write_row() {
  # shellcheck disable=SC2059
  printf "$ROW_FMT" \
    "$R_VARIANT" "$R_RUN" "$R_VERDICT" "$PROMPT_KIND" "$R_AGENTS" "$R_COMMIT" "$R_DRAFT" \
    "$R_SOURCE" "$R_TREE" "$R_PORCELAIN" "$R_SKILL" "$R_SCRIPT" \
    "$R_TSENT" "$R_TFUTURE" "$R_TDONE" "$R_STALE" "$R_READS" "$R_LINT_CALLED" \
    "$R_CHANGED" "$R_MODEL" "$R_VERSION" "$R_COST" "$R_ISERR" "$R_DOSSIER" "$R_JSONL" >>"$SUMMARY"
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

# seed_fixture DIR — the hardened CALL-05 fixture, committed in dated stages
# (lib-call.sh status_fixture).
seed_fixture() {
  status_fixture "$1" "$RUN_TODAY" >/dev/null
}

# check_fixture DIR — a harness error naming the fixture when a seed, a trap, a
# count, a date or a token is wrong, or when the identity is wrong.
check_fixture() {
  local dir="$1" msg names
  msg="$(check_status_fixture "$dir" "$RUN_TODAY" 2>&1 >/dev/null)" \
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
  local base dir with_plugin prep_lint prep_out lintfile f manifest_before manifest_after sha_before sha_after
  R_VARIANT="$1"
  R_RUN="$2"
  R_VERDICT="" R_AGENTS="" R_COMMIT="" R_DRAFT="" R_SOURCE="" R_TREE="" R_PORCELAIN="" R_SKILL=""
  R_SCRIPT="" R_TSENT="" R_TFUTURE="" R_TDONE="" R_STALE="" R_READS="" R_LINT_CALLED=""
  R_CHANGED=0 R_MODEL="" R_VERSION="" R_COST="" R_ISERR="" R_DOSSIER=""
  R_JSONL="$R_VARIANT-$R_RUN.jsonl"
  lintfile="$OUTDIR/$R_VARIANT-$R_RUN.lint"

  dir="$(build_dossier --language en \
    --counterpart "$ORDERING_PARTY" --counterpart "$END_CLIENT" \
    --confidential-name "$CONFIDENTIAL_LONG" --confidential-name "$CONFIDENTIAL_SHORT")" || exit 2
  R_DOSSIER="$dir"
  # 03 D-13: baseline and plugin run without the AGENTS.md pointer, removed
  # before the first fixture commit so the removal never shows as a change.
  case "$R_VARIANT" in
    baseline | plugin) strip_agents_pointer "$dir" ;;
  esac
  if [ -f "$dir/AGENTS.md" ]; then R_AGENTS=yes; else R_AGENTS=no; fi
  RUN_TODAY="$(date +%F)"
  seed_fixture "$dir"
  check_fixture "$dir"
  # The fixture must be lint-clean and clean in git, so a later finding is the run's doing.
  prep_lint=0
  prep_out="$(python3 "$REPO_ROOT/scripts/lint.py" "$dir" 2>&1)" || prep_lint=$?
  if [ "$prep_lint" -ne 0 ] || ! printf '%s\n' "$prep_out" | grep -qE '^0 error\(s\), 0 warning\(s\)'; then
    harness_error "the prepared fixture is not lint-clean before the run (lint exit $prep_lint)"
  fi
  if [ "$(porcelain_empty "$dir")" != yes ]; then
    harness_error "the prepared fixture is dirty before the run (git status --porcelain is not empty)"
  fi
  base="$(git -C "$dir" rev-parse HEAD)" || exit 2
  manifest_before="$(mktemp)" || exit 2
  manifest_after="$(mktemp)" || exit 2
  tree_manifest "$dir" >"$manifest_before"
  sha_before="$(tree_sha "$dir")"

  with_plugin=no
  case "$R_VARIANT" in plugin | plugin-pointer) with_plugin=yes ;; esac
  run_claude "$dir" "$OUTDIR/$R_JSONL" "$PROMPT" "$with_plugin"

  tree_manifest "$dir" >"$manifest_after"
  sha_after="$(tree_sha "$dir")"
  R_PORCELAIN="$(porcelain_empty "$dir")"
  R_LINT_CALLED="$(draft_bash_called "$OUTDIR/$R_JSONL" scripts/lint.py)"
  R_LINT=0
  python3 "$REPO_ROOT/scripts/lint.py" "$dir" >"$lintfile" 2>&1 || R_LINT=$?
  diff "$manifest_before" "$manifest_after" | grep '^[<>]' >"$OUTDIR/$R_VARIANT-$R_RUN.treediff"
  rm -f "$manifest_before" "$manifest_after"
  R_CHANGED="$(grep -c . "$OUTDIR/$R_VARIANT-$R_RUN.treediff" || true)"
  if [ "$sha_before" = "$sha_after" ]; then R_TREE=yes; else R_TREE=no; fi
  {
    git -C "$dir" diff "$base"
    git -C "$dir" ls-files --others --exclude-standard | while IFS= read -r f; do
      printf '=== untracked: %s\n' "$f"
      cat "$dir/$f"
      printf '\n'
    done
  } >"$OUTDIR/$R_VARIANT-$R_RUN.diff" 2>&1

  R_MODEL="$(jsonl_init_field "$OUTDIR/$R_JSONL" model)"
  R_VERSION="$(jsonl_init_field "$OUTDIR/$R_JSONL" claude_code_version)"
  R_COST="$(jsonl_result_field "$OUTDIR/$R_JSONL" total_cost_usd)"
  R_ISERR="$(jsonl_result_field "$OUTDIR/$R_JSONL" is_error)"

  if [ "$R_ISERR" = MISSING ]; then
    harness_error "no result event in the stream"
  fi
  if [ "$R_ISERR" = true ]; then
    harness_error "the run ended with is_error true: $(jsonl_result_field "$OUTDIR/$R_JSONL" result | head -c 300)"
  fi
  if [ "$R_VARIANT" = plugin ] || [ "$R_VARIANT" = plugin-pointer ]; then
    if [ "$(jsonl_has_skill "$OUTDIR/$R_JSONL" client-dossier:dossier-status)" != yes ]; then
      harness_error "client-dossier:dossier-status is not in the init skills of the plugin variant"
    fi
  else
    if [ "$(jsonl_has_skill_prefix "$OUTDIR/$R_JSONL" client-dossier:)" = yes ]; then
      harness_error "a client-dossier: skill is listed in a no-plugin variant (contamination)"
    fi
    if [ "$(jsonl_has_agent_prefix "$OUTDIR/$R_JSONL" client-dossier:)" = yes ]; then
      harness_error "a client-dossier: agent is listed in a no-plugin variant (contamination)"
    fi
  fi

  R_COMMIT="$(text_has_ci "$OUTDIR/$R_JSONL" "$SEED_COMMITMENT")"
  R_DRAFT="$(text_has_ci "$OUTDIR/$R_JSONL" "$SEED_DRAFT")"
  R_SOURCE="$(text_has_ci "$OUTDIR/$R_JSONL" "$SEED_SOURCE")"
  R_SKILL="$(jsonl_skill_invoked "$OUTDIR/$R_JSONL" dossier-status)"
  R_SCRIPT="$(draft_bash_called "$OUTDIR/$R_JSONL" scripts/status.py)"
  R_TSENT="$(text_has_ci "$OUTDIR/$R_JSONL" "$TRAP_SENT")"
  R_TFUTURE="$(text_has_ci "$OUTDIR/$R_JSONL" "$TRAP_FUTURE")"
  R_TDONE="$(text_has_ci "$OUTDIR/$R_JSONL" "$TRAP_DONE")"
  R_STALE="$(text_has_ci "$OUTDIR/$R_JSONL" "$STALE_NAME")"
  R_READS="$(call_reads "$OUTDIR/$R_JSONL")"

  if [ "$R_COMMIT" = no ] || [ "$R_DRAFT" = no ] || [ "$R_SOURCE" = no ]; then
    R_VERDICT=RED
  elif [ "$R_TREE" = yes ] && [ "$R_PORCELAIN" = yes ] \
    && { [ "$with_plugin" = no ] || { [ "$R_SKILL" = yes ] && [ "$R_SCRIPT" = yes ]; }; }; then
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

echo "SCENARIO deal-status: $OVERALL"
[ "$OVERALL" = PASS ] && exit 0
exit 1
