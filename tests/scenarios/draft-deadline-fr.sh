#!/usr/bin/env bash
# tests/scenarios/draft-deadline-fr.sh — the French deadline draft run of
# ROADMAP Phase 5 criterion 1 (DRAFT-01, DRAFT-02; D-02, D-04).
#
# One short, paid, agent-run proof that `dossier-draft mail <slug>` works on a
# French dossier with a deadline. It is not a pressure scenario: DRAFT-04's RED
# and GREEN belong to draft-reply.sh. Plugin only, no baseline variant, never run
# by tests/run.sh (it costs model calls and needs an authenticated claude).
#
# A scratch dossier, built by the real init.py with `--language fr` and the D-07
# identity (Acme Consulting is the ordering party and is NOT confidential;
# `Northwind Bank` and `Northwind` are), holds four fixture lines seeded by
# heading POSITION, never by the French title: a sign-off rule under the fifth
# `## ` heading of dossier/TONE.md, a refused opening under the sixth, a pending
# question under the first `## ` of dossier/HISTORY.md and a never-say line under
# the second `## ` of knowledge/DOCTRINE.md. A headless `claude -p` with the
# plugin runs the French prompt, which names `dossier-draft mail
# reponse-date-audit` and the absolute send-by date 2026-10-30. The AGENTS.md
# pointer is stripped (03 D-13).
#
# Verdict per run (mechanical):
#   GREEN       exactly one new file under outbound/mails/ named
#               `<run date>_reponse-date-audit.md` (slug_kept), lint prints no
#               ERROR on it and its `Status:` is exactly `draft` (header_ok), its
#               status block holds `Deadline: 2026-10-30` with the English field
#               names (deadline_ok), its body is French (french_body), it applies
#               the sign-off `Bien cordialement,` then `Sam` without the refused
#               phrase (tone_applied), no confidential name leaks under outbound/,
#               an added HISTORY bullet names the file AND carries 2026-10-30
#               (history_line), and a `Skill` call naming dossier-draft and a
#               completed dispatch of client-dossier:doctrine-reviewer are in the
#               stream (an errored call does not count, R4-m7), with
#               handback_before_review 0 (no top-level result event before the review
#               has returned) and lint_after_last_draft_edit yes (the last linter run
#               comes after the last Write or Edit of the draft; Phase 5 review R5-M1)
#               and history_edit_before_review 0 (no edit of dossier/HISTORY.md by the
#               main agent before the review has returned; R6-6).
#   INCOMPLETE  anything else. reviewer_tools_ok and lint_exit never gate.
# Harness error (exit 2, `HARNESS ERROR:` on stderr, a HARNESS_ERROR row, never a
# verdict): preflight failure, missing result event, is_error true, the fixture
# not seeded or not lint-clean, client-dossier:dossier-draft absent from the
# system/init skills or client-dossier:doctrine-reviewer from the system/init
# agents.
#
# Exit 0 when every run is GREEN, 1 otherwise, 2 on a harness error. Last line
# `SCENARIO draft-deadline-fr: PASS|FAIL`.
#
# Usage: bash tests/scenarios/draft-deadline-fr.sh [--runs N] [OUTDIR]
# Defaults: 1 run, OUTDIR = mktemp -d. Writes OUTDIR/summary.tsv (25 columns),
# OUTDIR/prompt.txt and one fr-<n>.jsonl, .diff and .lint per run.
set -u

# shellcheck source=./lib-scenario.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib-scenario.sh"
# shellcheck source=./lib-draft.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib-draft.sh"

# The fixture and the prompt, one NAME="value" per line (no straight double
# quote, dollar sign, backtick, backslash or straight single quote inside).
ORDERING_PARTY="Acme Consulting|client|Jane Doe"
END_CLIENT="Northwind Bank|client final"
CONFIDENTIAL_LONG="Northwind Bank"
CONFIDENTIAL_SHORT="Northwind"
SLUG="reponse-date-audit"
DEADLINE="2026-10-30"
SIGN_OFF_HEAD="Bien cordialement,"
SIGN_OFF_NAME="Sam"
REFUSED_PHRASE="espère que vous allez bien"
TONE_RULE="- Répondre à la question dès la première phrase, rester sous 120 mots et finir par la formule « Bien cordialement, Sam » seule sur sa ligne (relecture de Sam le 2026-10-02)."
REFUSED_LINE="- « J’espère que vous allez bien » refusé le 2026-10-02 comme formule creuse (relecture de Sam le 2026-10-02)."
PENDING_LINE="- Jane Doe (Acme Consulting) a demandé le 2026-10-08 si l’audit de migration de données de Northwind Bank peut démarrer le 2026-11-02, et attend notre réponse (mail du 2026-10-08 de Jane Doe)."
NEVER_SAY_LINE="- Une date de démarrage avant que l’appel de cadrage ait eu lieu (décision du 2026-09-20 par Sam)."
FR_WORDS="le la les des du est pour nous vous que une et avec sur"
EN_WORDS="the and is we you to for with on of that"
PROMPT="dossier-draft mail reponse-date-audit : réponds à la question de Jane Doe sur la date de démarrage de l’audit ; le mail doit partir au plus tard le 2026-10-30."

usage() {
  echo "usage: bash tests/scenarios/draft-deadline-fr.sh [--runs N] [OUTDIR]" >&2
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
echo "note: AGENTS.md removed from the scratch dossier (03 D-13); plugin only"

# 25 tab-separated columns, in this order (the French scenario contract, plus the order
# columns of the Phase 5 review fixes, appended last so no earlier column moves).
ROW_FMT='%s'
col_i=2
while [ "$col_i" -le 25 ]; do
  ROW_FMT="$ROW_FMT\\t%s"
  col_i=$((col_i + 1))
done
ROW_FMT="$ROW_FMT\\n"
# shellcheck disable=SC2059
printf "$ROW_FMT" \
  variant run verdict draft_file slug_kept header_ok status_value deadline_ok \
  french_body tone_applied leak history_line draft_skill reviewer_dispatched \
  reviewer_tools_ok lint_exit model claude_code_version cost_usd is_error \
  dossier jsonl handback_before_review lint_after_last_draft_edit \
  history_edit_before_review >"$SUMMARY"

# The row of the run in progress, set by run_one and read by write_row.
R_RUN="" R_VERDICT="" R_DRAFT_FILE="" R_SLUG_KEPT="" R_HEADER_OK="" R_STATUS="" R_DEADLINE_OK=""
R_FRENCH="" R_TONE="" R_LEAK="" R_HISTORY="" R_DRAFT_SKILL="" R_REVIEW="" R_REVIEW_TOOLS=""
R_LINT="" R_MODEL="" R_VERSION="" R_COST="" R_ISERR="" R_DOSSIER="" R_JSONL=""
R_HANDBACK="" R_LINT_LAST="" R_HIST_EARLY=""

write_row() {
  # shellcheck disable=SC2059
  printf "$ROW_FMT" \
    plugin "$R_RUN" "$R_VERDICT" "$R_DRAFT_FILE" "$R_SLUG_KEPT" "$R_HEADER_OK" "$R_STATUS" \
    "$R_DEADLINE_OK" "$R_FRENCH" "$R_TONE" "$R_LEAK" "$R_HISTORY" "$R_DRAFT_SKILL" \
    "$R_REVIEW" "$R_REVIEW_TOOLS" "$R_LINT" "$R_MODEL" "$R_VERSION" "$R_COST" "$R_ISERR" \
    "$R_DOSSIER" "$R_JSONL" "$R_HANDBACK" "$R_LINT_LAST" "$R_HIST_EARLY" >>"$SUMMARY"
}

# harness_error MSG — the row is recorded with a HARNESS_ERROR verdict, then the
# run stops with exit 2.
harness_error() {
  R_VERDICT="HARNESS_ERROR"
  write_row
  scenario_die "$1 (run $R_RUN, see $OUTDIR/$R_JSONL)"
}

# insert_nth FILE N LINE — LINE as its own line right after the block (blank and
# comment lines) that follows the Nth `## ` heading of FILE, then a blank line.
# The heading is counted by position, never by its title, so the fixture does not
# depend on the dossier's language. A non-zero status when FILE has fewer than N
# `## ` headings.
insert_nth() {
  python3 -I -c '
import sys
path, n, line = sys.argv[1], int(sys.argv[2]), sys.argv[3]
with open(path, encoding="utf-8", newline="") as fh:
    lines = fh.read().split("\n")
count = 0
idx = None
for i, text in enumerate(lines):
    if text.startswith("## "):
        count += 1
        if count == n:
            idx = i
            break
if idx is None:
    sys.exit(1)
j = idx + 1
while j < len(lines) and (lines[j].strip() == "" or lines[j].lstrip().startswith("<!--")):
    j += 1
lines[j:j] = [line, ""]
with open(path, "w", encoding="utf-8", newline="") as fh:
    fh.write("\n".join(lines))
' "$1" "$2" "$3"
}

# seed_fixture DIR — the four fixture lines, each under its Nth `## ` heading.
seed_fixture() {
  local dir="$1"
  insert_nth "$dir/dossier/TONE.md" 5 "$TONE_RULE" \
    || scenario_die "dossier/TONE.md of $dir has fewer than 5 '## ' headings: cannot seed the fixture"
  insert_nth "$dir/dossier/TONE.md" 6 "$REFUSED_LINE" \
    || scenario_die "dossier/TONE.md of $dir has fewer than 6 '## ' headings: cannot seed the fixture"
  insert_nth "$dir/dossier/HISTORY.md" 1 "$PENDING_LINE" \
    || scenario_die "dossier/HISTORY.md of $dir has no '## ' heading: cannot seed the fixture"
  insert_nth "$dir/knowledge/DOCTRINE.md" 2 "$NEVER_SAY_LINE" \
    || scenario_die "knowledge/DOCTRINE.md of $dir has fewer than 2 '## ' headings: cannot seed the fixture"
}

# check_fixture DIR — a harness error naming the fixture when one of the four
# lines is missing, when dossier.yaml does not read `language: fr`, or when its
# confidential_names line lacks a confidential name or names Acme.
check_fixture() {
  local dir="$1" names
  grep -qxF -- "$TONE_RULE" "$dir/dossier/TONE.md" 2>/dev/null \
    || harness_error "the fixture is not seeded: the TONE rule is missing from dossier/TONE.md"
  grep -qxF -- "$REFUSED_LINE" "$dir/dossier/TONE.md" 2>/dev/null \
    || harness_error "the fixture is not seeded: the refused line is missing from dossier/TONE.md"
  grep -qxF -- "$PENDING_LINE" "$dir/dossier/HISTORY.md" 2>/dev/null \
    || harness_error "the fixture is not seeded: the pending question is missing from dossier/HISTORY.md"
  grep -qxF -- "$NEVER_SAY_LINE" "$dir/knowledge/DOCTRINE.md" 2>/dev/null \
    || harness_error "the fixture is not seeded: the doctrine line is missing from knowledge/DOCTRINE.md"
  grep -q '^language: fr' "$dir/dossier.yaml" 2>/dev/null \
    || harness_error "the fixture identity is wrong: dossier.yaml does not read language: fr"
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
    *Acme*) harness_error "the fixture identity is wrong: dossier.yaml makes Acme confidential (the default identity leaked into the fixture)" ;;
  esac
}

# french_body FILE — yes when the text of FILE after its first line holding
# `-->` (the whole text when there is none), lowercased and split into letter
# runs, holds at least 5 tokens of FR_WORDS and more than it holds of EN_WORDS;
# else no. Local to this scenario.
french_body() {
  python3 -I -c '
import re, sys
path, fr_words, en_words = sys.argv[1], sys.argv[2].split(), sys.argv[3].split()
try:
    with open(path, encoding="utf-8", errors="replace") as fh:
        lines = fh.read().split("\n")
except OSError:
    print("no")
    sys.exit(0)
body = lines
for i, text in enumerate(lines):
    if "-->" in text:
        body = lines[i + 1:]
        break
tokens = re.findall(r"[^\W\d_]+", "\n".join(body).lower())
fr = sum(1 for t in tokens if t in fr_words)
en = sum(1 for t in tokens if t in en_words)
print("yes" if fr >= 5 and fr > en else "no")
' "$1" "$FR_WORDS" "$EN_WORDS"
}

run_one() {
  local base dir date_before date_after prep_lint prep_out new_all mails lines_n lintfile name
  R_RUN="$1"
  R_VERDICT="" R_DRAFT_FILE="none" R_SLUG_KEPT="no" R_HEADER_OK="no" R_STATUS="none"
  R_DEADLINE_OK="no" R_FRENCH="no" R_TONE="no" R_LEAK="" R_HISTORY="no" R_DRAFT_SKILL=""
  R_REVIEW="" R_REVIEW_TOOLS="" R_LINT="" R_MODEL="" R_VERSION="" R_COST="" R_ISERR=""
  R_DOSSIER="" R_JSONL="fr-$R_RUN.jsonl"
  lintfile="$OUTDIR/fr-$R_RUN.lint"

  dir="$(build_dossier --language fr \
    --counterpart "$ORDERING_PARTY" --counterpart "$END_CLIENT" \
    --confidential-name "$CONFIDENTIAL_LONG" --confidential-name "$CONFIDENTIAL_SHORT")" || exit 2
  R_DOSSIER="$dir"
  seed_fixture "$dir"
  check_fixture "$dir"
  # 03 D-13: no AGENTS.md pointer, removed before the baseline commit so it never
  # shows as a change of the run.
  strip_agents_pointer "$dir"
  # The fixture must be lint-clean, so a later lint finding is the run's doing.
  prep_lint=0
  prep_out="$(python3 "$REPO_ROOT/scripts/lint.py" "$dir" 2>&1)" || prep_lint=$?
  if [ "$prep_lint" -ne 0 ] || ! printf '%s\n' "$prep_out" | grep -qE '^0 error\(s\), 0 warning\(s\)'; then
    harness_error "the prepared fixture is not lint-clean before the run (lint exit $prep_lint)"
  fi
  base="$(commit_baseline "$dir")" || exit 2

  date_before="$(date +%F)"
  run_claude "$dir" "$OUTDIR/$R_JSONL" "$PROMPT" yes
  date_after="$(date +%F)"

  R_MODEL="$(jsonl_init_field "$OUTDIR/$R_JSONL" model)"
  R_VERSION="$(jsonl_init_field "$OUTDIR/$R_JSONL" claude_code_version)"
  R_COST="$(jsonl_result_field "$OUTDIR/$R_JSONL" total_cost_usd)"
  R_ISERR="$(jsonl_result_field "$OUTDIR/$R_JSONL" is_error)"
  R_DRAFT_SKILL="$(jsonl_skill_invoked "$OUTDIR/$R_JSONL" dossier-draft)"
  R_REVIEW="$(jsonl_agent_dispatched "$OUTDIR/$R_JSONL" doctrine-reviewer)"
  R_REVIEW_TOOLS="$(draft_reviewer_tools_ok "$OUTDIR/$R_JSONL" doctrine-reviewer)"
  R_HANDBACK="$(draft_handback_before_review "$OUTDIR/$R_JSONL")"
  R_LINT_LAST="$(draft_lint_after_last_draft_edit "$OUTDIR/$R_JSONL")"
  R_HIST_EARLY="$(draft_history_edit_before_review "$OUTDIR/$R_JSONL")"
  R_LINT=0
  python3 "$REPO_ROOT/scripts/lint.py" "$dir" >"$lintfile" 2>&1 || R_LINT=$?
  {
    git -C "$dir" diff "$base"
    git -C "$dir" ls-files --others --exclude-standard | while IFS= read -r name; do
      printf '=== untracked: %s\n' "$name"
      cat "$dir/$name"
      printf '\n'
    done
  } >"$OUTDIR/fr-$R_RUN.diff" 2>&1

  if [ "$R_ISERR" = MISSING ]; then
    harness_error "no result event in the stream"
  fi
  if [ "$R_ISERR" = true ]; then
    harness_error "the run ended with is_error true: $(jsonl_result_field "$OUTDIR/$R_JSONL" result | head -c 300)"
  fi
  if [ "$(jsonl_has_skill "$OUTDIR/$R_JSONL" client-dossier:dossier-draft)" != yes ]; then
    harness_error "client-dossier:dossier-draft is not in the init skills of the run"
  fi
  if [ "$(jsonl_has_agent "$OUTDIR/$R_JSONL" client-dossier:doctrine-reviewer)" != yes ]; then
    harness_error "client-dossier:doctrine-reviewer is not in the init agents of the run"
  fi

  # Exactly one new file under outbound/mails/, directly there, dated.
  new_all="$(draft_new_files "$dir" "$base" outbound)"
  mails="$(draft_new_files "$dir" "$base" outbound/mails)"
  lines_n="$(printf '%s\n' "$mails" | grep -c . || true)"
  if [ "$lines_n" -eq 1 ] && [ "$(dirname "$mails")" = outbound/mails ] \
    && [ "$(draft_name_ok "$(basename "$mails")" "$date_before" "$date_after")" = yes ]; then
    R_DRAFT_FILE="$mails"
  fi
  R_LEAK="$(draft_leak "$dir" "$lintfile" "$CONFIDENTIAL_LONG" "$CONFIDENTIAL_SHORT")"

  if [ "$R_DRAFT_FILE" != none ]; then
    name="$(basename "$R_DRAFT_FILE")"
    if [ "$name" = "${date_before}_${SLUG}.md" ] || [ "$name" = "${date_after}_${SLUG}.md" ]; then
      R_SLUG_KEPT=yes
    fi
    R_STATUS="$(draft_header_field "$dir/$R_DRAFT_FILE" Status)"
    if [ "$(draft_errors_on "$lintfile" "$R_DRAFT_FILE")" -eq 0 ] && [ "$R_STATUS" = draft ]; then
      R_HEADER_OK=yes
    fi
    if [ "$(draft_header_field "$dir/$R_DRAFT_FILE" Deadline)" = "$DEADLINE" ]; then
      R_DEADLINE_OK=yes
    fi
    R_FRENCH="$(french_body "$dir/$R_DRAFT_FILE")"
    R_TONE="$(draft_signoff_applied "$dir/$R_DRAFT_FILE" "$SIGN_OFF_HEAD" "$SIGN_OFF_NAME" "$REFUSED_PHRASE")"
    if draft_history_bullets "$dir" "$base" "$name" | grep -qF -- "$DEADLINE"; then
      R_HISTORY=yes
    fi
  fi

  if [ "$R_DRAFT_FILE" != none ] && [ "$R_SLUG_KEPT" = yes ] && [ "$R_HEADER_OK" = yes ] \
    && [ "$R_DEADLINE_OK" = yes ] && [ "$R_FRENCH" = yes ] && [ "$R_TONE" = yes ] \
    && [ "$R_HISTORY" = yes ] && [ "$R_DRAFT_SKILL" = yes ] && [ "$R_REVIEW" = yes ] \
    && [ "$R_LEAK" = no ] && [ "$R_HANDBACK" = 0 ] && [ "$R_LINT_LAST" = yes ] \
    && [ "$R_HIST_EARLY" = 0 ]; then
    R_VERDICT=GREEN
  else
    R_VERDICT=INCOMPLETE
  fi
  write_row
  echo "plugin $R_RUN: $R_VERDICT"
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
echo "SCENARIO draft-deadline-fr: $OVERALL"
[ "$OVERALL" = PASS ] && exit 0
exit 1
