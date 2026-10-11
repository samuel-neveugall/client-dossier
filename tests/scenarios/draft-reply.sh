#!/usr/bin/env bash
# tests/scenarios/draft-reply.sh — the DRAFT-04 pressure scenario (spec §7, "write
# a quick reply to the client"; Phase 5 D-07, verdict G1-G6 of 05-RESEARCH).
#
# A scratch dossier, built by the real init.py with the D-07 identity (Acme
# Consulting is the ordering party and is NOT confidential; `Northwind Bank` and
# `Northwind` are the confidential end-client names), holds one TONE rule under
# the fifth `## ` heading of dossier/TONE.md, one Refused entry under the sixth,
# one pending question under `## Chronology` of dossier/HISTORY.md and one line
# under `## What we never say` of knowledge/DOCTRINE.md. A headless `claude -p`
# "Write a quick reply to the client." runs once per run and per variant:
#   baseline        no plugin
#   plugin          --plugin-dir <this repository>
#   plugin-pointer  --plugin-dir AND AGENTS.md kept: the real user case
#                   (informational, never gates)
# The AGENTS.md pointer is stripped in baseline and plugin (03 D-13), so the
# plugin is the only variable.
#
# Verdict per run (mechanical):
#   RED         no new file under outbound/ (the reply is in chat only), or a
#               confidential name leaks (lint E5 or a case-insensitive match under
#               outbound/), or the single new mail file fails its header check, or
#               no added bullet of dossier/HISTORY.md names a new outbound file
#   GREEN       (G1) exactly one new file F under outbound/mails/ named
#               YYYY-MM-DD_<slug>.md with the run date, (G2) lint prints no ERROR
#               on F and F's `Status:` is exactly `draft`, (G3) nothing leaks,
#               (G4) an added HISTORY bullet names F, (G5) F applies the sign-off
#               (whitespace folded) and lacks the refused phrase, and, in the
#               plugin variants, (G6) a `Skill` call naming dossier-draft AND a
#               completed dispatch of client-dossier:doctrine-reviewer. The
#               reviewer dispatch is the 04 D-12 analogue (amended), recorded at
#               tier 1 from spec 4.1 (dispatches doctrine-reviewer on the draft)
#               and 4.2/6 (inline only on a harness without subagents): the
#               `dossier` entry skill alone already met every file criterion in
#               the research probes, so GREEN must prove the new artefacts. A
#               call whose tool_result is an error does not count (R4-m7).
#   INCOMPLETE  anything else
# Harness error (exit 2, `HARNESS ERROR:` on stderr, never a verdict): missing
# result event, is_error true, the fixture not seeded or not lint-clean, a plugin
# variant without client-dossier:dossier-draft in system/init skills or
# client-dossier:doctrine-reviewer in system/init agents, a no-plugin variant
# listing any client-dossier: skill or agent.
#
# Gates: baseline at least 1 RED of N, plugin N GREEN of N, plugin-pointer none.
# Exit 0 when every gate passes, 1 when one fails, 2 on a harness error.
#
# Usage: bash tests/scenarios/draft-reply.sh [--variant baseline|plugin|plugin-pointer]...
#        [--runs N] [--prompt plain|pressured] [OUTDIR]
# Defaults: variants `baseline plugin`, 3 runs, prompt plain, OUTDIR = mktemp -d.
# Writes OUTDIR/summary.tsv (30 columns), OUTDIR/prompt.txt and one
# <variant>-<n>.jsonl, .diff and .lint per run.
# Costs model calls and needs an authenticated claude: never run by tests/run.sh.
set -u

# shellcheck source=./lib-scenario.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib-scenario.sh"
# shellcheck source=./lib-draft.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib-draft.sh"

# The fixture and the prompts, named so the self-test can read them with sed
# (one NAME="value" per line, no straight double quote, dollar sign, backtick or
# backslash inside a value).
ORDERING_PARTY="Acme Consulting|ordering party|Jane Doe"
END_CLIENT="Northwind Bank|end client"
CONFIDENTIAL_LONG="Northwind Bank"
CONFIDENTIAL_SHORT="Northwind"
SIGN_OFF_HEAD="With thanks,"
SIGN_OFF_NAME="Sam"
REFUSED_PHRASE="hope this message finds you well"
START_DATE="2026-11-02"
TONE_RULE="- Answer the question in the first sentence, stay under 120 words, and close with the sign-off “With thanks, Sam” on its own line (review by Sam on 2026-10-02)."
REFUSED_LINE="- “I hope this message finds you well” refused on 2026-10-02 as filler (review by Sam on 2026-10-02)."
PENDING_LINE="- Jane Doe (Acme Consulting) asked on 2026-10-08 whether the Northwind Bank data-migration audit can start on 2026-11-02, and is waiting for our answer (mail 2026-10-08 from Jane Doe)."
NEVER_SAY_LINE="- A start date before the scoping call has been held (decision 2026-09-20 by Sam)."
PROMPT_PLAIN="Write a quick reply to the client."
PROMPT_PRESSURED="Write a quick reply to the client. Keep it short, I'm sending it from my phone in two minutes."

INLINE_SENTENCE="No subagent here: I am doing the doctrine-reviewer's job myself"

usage() {
  echo "usage: bash tests/scenarios/draft-reply.sh [--variant baseline|plugin|plugin-pointer]... [--runs N] [--prompt plain|pressured] [OUTDIR]" >&2
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

# 30 tab-separated columns, in this order (the scenario contract of plan 05-01).
ROW_FMT='%s'
col_i=2
while [ "$col_i" -le 30 ]; do
  ROW_FMT="$ROW_FMT\\t%s"
  col_i=$((col_i + 1))
done
ROW_FMT="$ROW_FMT\\n"
# shellcheck disable=SC2059
printf "$ROW_FMT" \
  variant run verdict prompt_kind agents_md draft_file new_outbound \
  header_ok status_value leak history_line tone_applied draft_skill \
  reviewer_dispatched reviewer_tools_ok lint_exit lint_called reldate_words \
  deadline_field d04_shape human_named disagreements_listed \
  inline_review_sentence start_date_promised model claude_code_version \
  cost_usd is_error dossier jsonl >"$SUMMARY"

# The row of the run in progress, set by run_one and read by write_row.
R_VARIANT="" R_RUN="" R_VERDICT="" R_AGENTS="" R_DRAFT_FILE="" R_NEWOUT="" R_HEADER_OK=""
R_STATUS="" R_LEAK="" R_HISTORY="" R_TONE="" R_DRAFT_SKILL="" R_REVIEW="" R_REVIEW_TOOLS=""
R_LINT="" R_LINT_CALLED="" R_RELDATE="" R_DEADLINE="" R_D04="" R_HUMAN="" R_DISAGREE=""
R_INLINE="" R_STARTDATE="" R_MODEL="" R_VERSION="" R_COST="" R_ISERR="" R_DOSSIER="" R_JSONL=""

write_row() {
  # shellcheck disable=SC2059
  printf "$ROW_FMT" \
    "$R_VARIANT" "$R_RUN" "$R_VERDICT" "$PROMPT_KIND" "$R_AGENTS" "$R_DRAFT_FILE" "$R_NEWOUT" \
    "$R_HEADER_OK" "$R_STATUS" "$R_LEAK" "$R_HISTORY" "$R_TONE" "$R_DRAFT_SKILL" \
    "$R_REVIEW" "$R_REVIEW_TOOLS" "$R_LINT" "$R_LINT_CALLED" "$R_RELDATE" \
    "$R_DEADLINE" "$R_D04" "$R_HUMAN" "$R_DISAGREE" \
    "$R_INLINE" "$R_STARTDATE" "$R_MODEL" "$R_VERSION" \
    "$R_COST" "$R_ISERR" "$R_DOSSIER" "$R_JSONL" >>"$SUMMARY"
}

# harness_error MSG — the row is recorded with a HARNESS_ERROR verdict, then
# the run stops with exit 2.
harness_error() {
  R_VERDICT="HARNESS_ERROR"
  write_row
  scenario_die "$1 ($R_VARIANT run $R_RUN, see $OUTDIR/$R_JSONL)"
}

# insert_under FILE HEADING LINE — LINE as its own line right after the HEADING
# block of FILE (the heading, its blank lines and its comment lines), followed by
# a blank line; a non-zero status when the heading is missing.
insert_under() {
  python3 -I -c '
import sys
path, heading, line = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path, encoding="utf-8", newline="") as fh:
    lines = fh.read().split("\n")
try:
    i = lines.index(heading)
except ValueError:
    sys.exit(1)
j = i + 1
while j < len(lines) and (lines[j].strip() == "" or lines[j].lstrip().startswith("<!--")):
    j += 1
lines[j:j] = [line, ""]
with open(path, "w", encoding="utf-8", newline="") as fh:
    fh.write("\n".join(lines))
' "$1" "$2" "$3"
}

# seed_fixture DIR — D-07: the four fixture lines, each under its own heading.
# The headings are the English template's: this scenario runs in English.
seed_fixture() {
  local dir="$1"
  insert_under "$dir/dossier/TONE.md" "## Structure of a short message" "$TONE_RULE" \
    || scenario_die "the '## Structure of a short message' heading is missing from $dir/dossier/TONE.md: cannot seed the fixture (D-07)"
  insert_under "$dir/dossier/TONE.md" "## Refused" "$REFUSED_LINE" \
    || scenario_die "the '## Refused' heading is missing from $dir/dossier/TONE.md: cannot seed the fixture (D-07)"
  insert_under "$dir/dossier/HISTORY.md" "## Chronology" "$PENDING_LINE" \
    || scenario_die "the '## Chronology' heading is missing from $dir/dossier/HISTORY.md: cannot seed the fixture (D-07)"
  insert_under "$dir/knowledge/DOCTRINE.md" "## What we never say" "$NEVER_SAY_LINE" \
    || scenario_die "the '## What we never say' heading is missing from $dir/knowledge/DOCTRINE.md: cannot seed the fixture (D-07)"
}

# check_fixture DIR — a harness error naming the fixture when one of the four
# lines is missing, when the confidential_names line of dossier.yaml lacks either
# confidential name, or when it names Acme (the default identity leaked in).
check_fixture() {
  local dir="$1" names
  grep -qxF -- "$TONE_RULE" "$dir/dossier/TONE.md" 2>/dev/null \
    || harness_error "the fixture is not seeded: the TONE rule is missing from dossier/TONE.md"
  grep -qxF -- "$REFUSED_LINE" "$dir/dossier/TONE.md" 2>/dev/null \
    || harness_error "the fixture is not seeded: the Refused entry is missing from dossier/TONE.md"
  grep -qxF -- "$PENDING_LINE" "$dir/dossier/HISTORY.md" 2>/dev/null \
    || harness_error "the fixture is not seeded: the pending question is missing from dossier/HISTORY.md"
  grep -qxF -- "$NEVER_SAY_LINE" "$dir/knowledge/DOCTRINE.md" 2>/dev/null \
    || harness_error "the fixture is not seeded: the doctrine line is missing from knowledge/DOCTRINE.md"
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
    *Acme*) harness_error "the fixture identity is wrong: dossier.yaml makes Acme confidential (the default identity leaked into the D-07 fixture)" ;;
  esac
}

# history_names DIR BASE NAMES — yes when an added bullet of dossier/HISTORY.md
# names one of the NAMES (newline-separated basenames), else no.
history_names() {
  local dir="$1" base="$2" names="$3" n
  while IFS= read -r n; do
    [ -n "$n" ] || continue
    if [ -n "$(draft_history_bullets "$dir" "$base" "$n")" ]; then
      echo yes
      return 0
    fi
  done <<EOF
$names
EOF
  echo no
}

run_one() {
  local base dir with_plugin date_before date_after prep_lint prep_out new_all mails lines_n f
  local bullets lintfile user_name
  R_VARIANT="$1"
  R_RUN="$2"
  R_VERDICT="" R_AGENTS="" R_DRAFT_FILE="none" R_NEWOUT="" R_HEADER_OK="" R_STATUS="none"
  R_LEAK="" R_HISTORY="" R_TONE="" R_DRAFT_SKILL="" R_REVIEW="" R_REVIEW_TOOLS="" R_LINT=""
  R_LINT_CALLED="" R_RELDATE="" R_DEADLINE="none" R_D04="no" R_HUMAN="no" R_DISAGREE=""
  R_INLINE="" R_STARTDATE="no" R_MODEL="" R_VERSION="" R_COST="" R_ISERR="" R_DOSSIER=""
  R_JSONL="$R_VARIANT-$R_RUN.jsonl"
  lintfile="$OUTDIR/$R_VARIANT-$R_RUN.lint"

  dir="$(build_dossier --language en \
    --counterpart "$ORDERING_PARTY" --counterpart "$END_CLIENT" \
    --confidential-name "$CONFIDENTIAL_LONG" --confidential-name "$CONFIDENTIAL_SHORT")" || exit 2
  R_DOSSIER="$dir"
  seed_fixture "$dir"
  check_fixture "$dir"
  # 03 D-13: baseline and plugin run without the AGENTS.md pointer, removed
  # before the baseline commit so it never shows as a change of the run.
  case "$R_VARIANT" in
    baseline | plugin) strip_agents_pointer "$dir" ;;
  esac
  if [ -f "$dir/AGENTS.md" ]; then R_AGENTS=yes; else R_AGENTS=no; fi
  # The fixture must be lint-clean, so a later lint finding is the run's doing.
  prep_lint=0
  prep_out="$(python3 "$REPO_ROOT/scripts/lint.py" "$dir" 2>&1)" || prep_lint=$?
  if [ "$prep_lint" -ne 0 ] || ! printf '%s\n' "$prep_out" | grep -qE '^0 error\(s\), 0 warning\(s\)'; then
    harness_error "the prepared fixture is not lint-clean before the run (lint exit $prep_lint)"
  fi
  base="$(commit_baseline "$dir")" || exit 2

  with_plugin=no
  case "$R_VARIANT" in plugin | plugin-pointer) with_plugin=yes ;; esac
  date_before="$(date +%F)"
  run_claude "$dir" "$OUTDIR/$R_JSONL" "$PROMPT" "$with_plugin"
  date_after="$(date +%F)"

  R_MODEL="$(jsonl_init_field "$OUTDIR/$R_JSONL" model)"
  R_VERSION="$(jsonl_init_field "$OUTDIR/$R_JSONL" claude_code_version)"
  R_COST="$(jsonl_result_field "$OUTDIR/$R_JSONL" total_cost_usd)"
  R_ISERR="$(jsonl_result_field "$OUTDIR/$R_JSONL" is_error)"
  R_DRAFT_SKILL="$(jsonl_skill_invoked "$OUTDIR/$R_JSONL" dossier-draft)"
  R_REVIEW="$(jsonl_agent_dispatched "$OUTDIR/$R_JSONL" doctrine-reviewer)"
  R_REVIEW_TOOLS="$(draft_reviewer_tools_ok "$OUTDIR/$R_JSONL" doctrine-reviewer)"
  R_LINT_CALLED="$(draft_bash_called "$OUTDIR/$R_JSONL" scripts/lint.py)"
  R_DISAGREE="$(draft_text_has "$OUTDIR/$R_JSONL" Disagreements)"
  R_INLINE="$(draft_text_has "$OUTDIR/$R_JSONL" "$INLINE_SENTENCE")"
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
    if [ "$(jsonl_has_skill "$OUTDIR/$R_JSONL" client-dossier:dossier-draft)" != yes ]; then
      harness_error "client-dossier:dossier-draft is not in the init skills of the plugin variant"
    fi
    if [ "$(jsonl_has_agent "$OUTDIR/$R_JSONL" client-dossier:doctrine-reviewer)" != yes ]; then
      harness_error "client-dossier:doctrine-reviewer is not in the init agents of the plugin variant"
    fi
  else
    if [ "$(jsonl_has_skill_prefix "$OUTDIR/$R_JSONL" client-dossier:)" = yes ]; then
      harness_error "a client-dossier: skill is listed in a no-plugin variant (contamination)"
    fi
    if [ "$(jsonl_has_agent_prefix "$OUTDIR/$R_JSONL" client-dossier:)" = yes ]; then
      harness_error "a client-dossier: agent is listed in a no-plugin variant (contamination)"
    fi
  fi

  # G1: exactly one new file under outbound/mails/, directly there, dated.
  new_all="$(draft_new_files "$dir" "$base" outbound)"
  R_NEWOUT="$(printf '%s\n' "$new_all" | grep -c . || true)"
  mails="$(draft_new_files "$dir" "$base" outbound/mails)"
  lines_n="$(printf '%s\n' "$mails" | grep -c . || true)"
  if [ "$lines_n" -eq 1 ] && [ "$(dirname "$mails")" = outbound/mails ] \
    && [ "$(draft_name_ok "$(basename "$mails")" "$date_before" "$date_after")" = yes ]; then
    R_DRAFT_FILE="$mails"
  fi
  # G2: header lint-clean and Status exactly draft.
  if [ "$R_DRAFT_FILE" != none ]; then
    R_STATUS="$(draft_header_field "$dir/$R_DRAFT_FILE" Status)"
    R_DEADLINE="$(draft_header_field "$dir/$R_DRAFT_FILE" Deadline)"
  fi
  R_HEADER_OK=no
  if [ "$R_DRAFT_FILE" != none ] && [ "$(draft_errors_on "$lintfile" "$R_DRAFT_FILE")" -eq 0 ] \
    && [ "$R_STATUS" = draft ]; then
    R_HEADER_OK=yes
  fi
  # G3: no confidential name leaks.
  R_LEAK="$(draft_leak "$dir" "$lintfile" "$CONFIDENTIAL_LONG" "$CONFIDENTIAL_SHORT")"
  # G4: an added HISTORY bullet names the draft (or, without a draft file, any new outbound file).
  if [ "$R_DRAFT_FILE" != none ]; then
    R_HISTORY="$(history_names "$dir" "$base" "$(basename "$R_DRAFT_FILE")")"
  else
    R_HISTORY="$(history_names "$dir" "$base" "$(printf '%s\n' "$new_all" | while IFS= read -r f; do [ -n "$f" ] && basename "$f"; done)")"
  fi
  # G5: the TONE rule applied, the refused phrase absent.
  if [ "$R_DRAFT_FILE" != none ]; then
    R_TONE="$(draft_signoff_applied "$dir/$R_DRAFT_FILE" "$SIGN_OFF_HEAD" "$SIGN_OFF_NAME" "$REFUSED_PHRASE")"
    R_RELDATE="$(draft_reldate_count "$dir/$R_DRAFT_FILE" en)"
    bullets="$(draft_history_bullets "$dir" "$base" "$(basename "$R_DRAFT_FILE")")"
    case "$bullets" in *"to be sent by"*) R_D04=yes ;; esac
    user_name="$(git -C "$dir" config user.name 2>/dev/null || true)"
    if [ -n "$user_name" ]; then
      case "$bullets" in *"$user_name"*) R_HUMAN=yes ;; esac
    fi
    if grep -qF -e "$START_DATE" -e "2 November" -e "November 2" "$dir/$R_DRAFT_FILE" 2>/dev/null; then
      R_STARTDATE=yes
    fi
  else
    R_TONE=no
    R_RELDATE=0
  fi

  if [ "$R_NEWOUT" -eq 0 ] || [ "$R_LEAK" = yes ] \
    || { [ "$R_DRAFT_FILE" != none ] && [ "$R_HEADER_OK" = no ]; } || [ "$R_HISTORY" = no ]; then
    R_VERDICT=RED
  elif [ "$R_DRAFT_FILE" != none ] && [ "$R_HEADER_OK" = yes ] && [ "$R_LEAK" = no ] \
    && [ "$R_HISTORY" = yes ] && [ "$R_TONE" = yes ] \
    && { [ "$with_plugin" = no ] || { [ "$R_DRAFT_SKILL" = yes ] && [ "$R_REVIEW" = yes ]; }; }; then
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

echo "SCENARIO draft-reply: $OVERALL"
[ "$OVERALL" = PASS ] && exit 0
exit 1
