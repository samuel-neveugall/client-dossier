#!/usr/bin/env bash
# tests/scenarios/selftest-ingest.sh — free self-test of the paid INGEST-05
# harness (tests/scenarios/ingest-transcript.sh) and of the helpers it adds to
# tests/scenarios/lib-scenario.sh (plan 04-02; D-10, D-12, D-13).
#
# ingest-transcript.sh normally drives a real, authenticated `claude -p` (money,
# network). This script proves every helper, verdict, gate and harness-error path
# against a generated fake `claude` instead, so the verdict logic is trusted
# before a single model call is paid for. SCENARIO_CLAUDE points the harness at
# the fake. Not named test-*.sh and living in a subdirectory, so tests/run.sh
# never globs it (it is run by hand and by the plan's verify step).
#
# Bash 3.2 safe, no arrays.
set -u

# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

SCEN_DIR="$REPO_ROOT/tests/scenarios"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# ---------------------------------------------------------------------------
# Section 1: the helpers added to lib-scenario.sh (D-12 agents, D-13 backdating)
# ---------------------------------------------------------------------------

# call FN ARGS... — runs a lib-scenario.sh function in a subshell, as
# selftest.sh does for the pointer-removal function.
call() {
  (. "$SCEN_DIR/lib-scenario.sh" && "$@")
}

# Synthetic stream-json files, one JSON object per line.
INIT_STR="$WORK/init-strings.jsonl"
INIT_OBJ="$WORK/init-objects.jsonl"
INIT_NONE="$WORK/init-nokey.jsonl"
printf '%s\n' 'not json at all' \
  '{"type":"system","subtype":"init","agents":["general-purpose","client-dossier:fact-extractor"]}' >"$INIT_STR"
printf '%s\n' '{"type":"system","subtype":"init","agents":[{"name":"general-purpose"},{"name":"client-dossier:fact-extractor"}]}' >"$INIT_OBJ"
printf '%s\n' '{"type":"system","subtype":"init","skills":["update-config"]}' >"$INIT_NONE"

assert_eq yes "$(call jsonl_has_agent "$INIT_STR" client-dossier:fact-extractor)" 'jsonl_has_agent: string entries, exact name'
assert_eq yes "$(call jsonl_has_agent "$INIT_OBJ" client-dossier:fact-extractor)" 'jsonl_has_agent: object entries, exact name'
assert_eq no "$(call jsonl_has_agent "$INIT_STR" fact-extractor)" 'jsonl_has_agent: a suffix is not an exact match'
assert_eq no "$(call jsonl_has_agent "$INIT_NONE" client-dossier:fact-extractor)" 'jsonl_has_agent: no agents key'
assert_eq no "$(call jsonl_has_agent "$WORK/absent.jsonl" client-dossier:fact-extractor)" 'jsonl_has_agent: missing file'
assert_eq yes "$(call jsonl_has_agent_prefix "$INIT_STR" client-dossier:)" 'jsonl_has_agent_prefix: prefix hit (strings)'
assert_eq yes "$(call jsonl_has_agent_prefix "$INIT_OBJ" client-dossier:)" 'jsonl_has_agent_prefix: prefix hit (objects)'
assert_eq no "$(call jsonl_has_agent_prefix "$INIT_NONE" client-dossier:)" 'jsonl_has_agent_prefix: no agents key'
assert_eq no "$(call jsonl_has_agent_prefix "$INIT_STR" other:)" 'jsonl_has_agent_prefix: prefix miss'

# R4-m7: a call counts only with its tool_result, matched by tool_use_id, not in error.
OKR='{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"t1","content":"ok","is_error":false}]}}'
NOERRKEY='{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"t1","content":"ok"}]}}'
ERRR='{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"t1","content":"denied","is_error":true}]}}'
OTHERR='{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"t2","content":"ok","is_error":false}]}}'
SKU='{"type":"assistant","message":{"content":[{"type":"tool_use","id":"t1","name":"Skill","input":{"skill":"client-dossier:dossier-ingest"}}]}}'
AGU='{"type":"assistant","message":{"content":[{"type":"tool_use","id":"t1","name":"Agent","input":{"subagent_type":"client-dossier:fact-extractor"}}]}}'
for pair in "ok:$OKR:yes" "noerrkey:$NOERRKEY:yes" "error:$ERRR:no" "other-id:$OTHERR:no" "none::no"; do
  label="${pair%%:*}"; rest="${pair#*:}"; res="${rest%:*}"; want="${rest##*:}"
  printf '%s\n' "$SKU" ${res:+"$res"} >"$WORK/pair-skill.jsonl"
  printf '%s\n' "$AGU" ${res:+"$res"} >"$WORK/pair-agent.jsonl"
  assert_eq "$want" "$(call jsonl_skill_invoked "$WORK/pair-skill.jsonl" dossier-ingest)" "jsonl_skill_invoked: result $label"
  assert_eq "$want" "$(call jsonl_agent_dispatched "$WORK/pair-agent.jsonl" fact-extractor)" "jsonl_agent_dispatched: result $label"
done

DISP_AGENT="$WORK/dispatch-agent.jsonl"
DISP_TASK="$WORK/dispatch-task.jsonl"
DISP_GENERAL="$WORK/dispatch-general.jsonl"
DISP_SKILL="$WORK/dispatch-skill.jsonl"
printf '%s\n' 'noise' \
  '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"t1","name":"Agent","input":{"subagent_type":"client-dossier:fact-extractor"}}]}}' "$OKR" >"$DISP_AGENT"
printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"t1","name":"Task","input":{"subagent_type":"client-dossier:fact-extractor"}}]}}' "$OKR" >"$DISP_TASK"
printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"t1","name":"Agent","input":{"subagent_type":"general-purpose"}}]}}' "$OKR" >"$DISP_GENERAL"
printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"t1","name":"Skill","input":{"skill":"client-dossier:fact-extractor"}}]}}' "$OKR" >"$DISP_SKILL"

assert_eq yes "$(call jsonl_agent_dispatched "$DISP_AGENT" fact-extractor)" 'jsonl_agent_dispatched: Agent tool_use'
assert_eq yes "$(call jsonl_agent_dispatched "$DISP_TASK" fact-extractor)" 'jsonl_agent_dispatched: Task tool_use'
assert_eq no "$(call jsonl_agent_dispatched "$DISP_GENERAL" fact-extractor)" 'jsonl_agent_dispatched: a general-purpose subagent'
assert_eq no "$(call jsonl_agent_dispatched "$DISP_SKILL" fact-extractor)" 'jsonl_agent_dispatched: a Skill tool_use naming the suffix'
assert_eq no "$(call jsonl_agent_dispatched "$WORK/absent.jsonl" fact-extractor)" 'jsonl_agent_dispatched: missing file'

# backdate_last_updated on a scaffold built by the real init.py.
BD="$(mktemp -d "$WORK/bd.XXXXXX")"
python3 "$(init_py)" --target "$BD" --language en \
  --counterpart 'Acme Consulting|ordering party|Jane Doe' >/dev/null 2>&1
SEVEN="ACTORS HISTORY LEARNINGS TONE CHANNELS OPEN-QUESTIONS RELATIONSHIP"
mkdir -p "$WORK/bd-before"
for n in $SEVEN; do cp "$BD/dossier/$n.md" "$WORK/bd-before/$n.md"; done
status=0
call backdate_last_updated "$BD" 2026-09-01 >/dev/null 2>"$WORK/bd.err" || status=$?
assert_eq 0 "$status" 'backdate_last_updated: exit 0 on a real scaffold'
for n in $SEVEN; do
  assert_eq 'Last updated: 2026-09-01' "$(grep -m1 '^Last updated:' "$BD/dossier/$n.md")" "backdate_last_updated: $n first Last updated line"
  # Every other line is untouched: the diff holds exactly the one replaced line.
  changed="$(diff "$WORK/bd-before/$n.md" "$BD/dossier/$n.md" | grep -c '^>')"
  assert_eq 1 "$changed" "backdate_last_updated: $n changes one line only"
done
status=0
python3 "$(lint_py)" "$BD" >/dev/null 2>&1 || status=$?
assert_eq 0 "$status" 'backdate_last_updated: lint.py still exits 0'

# A living file with no Last updated: line is a harness error.
BD2="$(mktemp -d "$WORK/bd.XXXXXX")"
python3 "$(init_py)" --target "$BD2" --language en \
  --counterpart 'Acme Consulting|ordering party|Jane Doe' >/dev/null 2>&1
sed '/^Last updated:/d' "$BD2/dossier/TONE.md" >"$WORK/tone.tmp" && cp "$WORK/tone.tmp" "$BD2/dossier/TONE.md"
status=0
call backdate_last_updated "$BD2" 2026-09-01 >/dev/null 2>"$WORK/bd2.err" || status=$?
assert_eq 2 "$status" 'backdate_last_updated: a file without Last updated exits 2'
assert_grep '^HARNESS ERROR:' "$WORK/bd2.err"

# ---------------------------------------------------------------------------
# Section 2: ingest-transcript.sh against a fake claude (D-10, D-12, D-13)
#
# The fake `claude` acts in its working directory according to FAKE_MODE:
#   summary-only        change nothing (what a RED run does)
#   ingest              copy incoming/call-transcript.txt to
#                       sources/transcripts/<today>_kickoff-call.txt, append a dated
#                       bullet ending `(call <today> @00:19).` to dossier/HISTORY.md,
#                       refresh HISTORY's first `Last updated:` line
#   correct             ingest plus the seeded line replaced by a corrected line
#                       ending `(corrects a line dated 2026-10-01).`
#   ingest-unfiled      the lines without the copy
#   ingest-no-refresh   copy and line, `Last updated:` left at the backdate
#   ingest-lint-error   ingest plus an outbound file with no status header
#   error               change nothing, result event has is_error true
# plus FAKE_NOSKILL (plugin run without client-dossier:dossier-ingest in the init
# skills), FAKE_NOAGENT (without client-dossier:fact-extractor in the init
# agents), FAKE_NOINVOKE (no Skill tool_use for dossier-ingest), FAKE_NODISPATCH
# (no Agent tool_use), FAKE_LEAK (a client-dossier: skill listed without
# --plugin-dir), FAKE_LEAK_AGENT (a client-dossier: agent listed without
# --plugin-dir) and FAKE_HELP_MISSING=<flag> (flag absent from --help).
# ---------------------------------------------------------------------------

HARNESS="$SCEN_DIR/ingest-transcript.sh"

# Drift guard: the fake and the harness must agree on the fixture constants.
const() {
  sed -n 's/^'"$1"'="\(.*\)"$/\1/p' "$HARNESS"
}
INCOMING_REL="$(const INCOMING_REL)"
BACKDATE="$(const BACKDATE)"
SEEDED_LINE="$(const SEEDED_LINE)"
PROMPT_PLAIN="$(const PROMPT_PLAIN)"
PROMPT_PRESSURED="$(const PROMPT_PRESSURED)"
assert_eq 'incoming/call-transcript.txt' "$INCOMING_REL" 'constant INCOMING_REL'
assert_eq '2026-09-01' "$BACKDATE" 'constant BACKDATE'
assert_eq '- Jane Doe (Acme Consulting) set the phase one budget at 15,000 euros (mail 2026-10-01 from Jane Doe).' "$SEEDED_LINE" 'constant SEEDED_LINE'
assert_eq '15,000' "$(const OLD_AMOUNT)" 'constant OLD_AMOUNT'
assert_eq '18,000' "$(const NEW_AMOUNT)" 'constant NEW_AMOUNT'
assert_eq 'Tom Becker' "$(const NEW_PERSON)" 'constant NEW_PERSON'
assert_eq "Here is the transcript of today's call: incoming/call-transcript.txt. What did we learn?" "$PROMPT_PLAIN" 'constant PROMPT_PLAIN'
assert_eq "Here is the transcript of today's call: incoming/call-transcript.txt. What did we learn? Keep it short, I'm walking into my next meeting in two minutes." "$PROMPT_PRESSURED" 'constant PROMPT_PRESSURED'
assert_eq 8 "$(grep -cE '^(INCOMING_REL|BACKDATE|SEEDED_LINE|OLD_AMOUNT|NEW_AMOUNT|NEW_PERSON|PROMPT_PLAIN|PROMPT_PRESSURED)=' "$HARNESS" 2>/dev/null)" 'eight named constants in the harness'
export FAKE_SEEDED="$SEEDED_LINE"

FAKE="$WORK/fake-claude"
cat >"$FAKE" <<'FAKE_EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "--help" ]; then
  for f in --setting-sources --strict-mcp-config --model --permission-mode \
    --allowedTools --permission-prompts --max-budget-usd --no-session-persistence \
    --output-format --verbose --plugin-dir; do
    [ "$f" = "${FAKE_HELP_MISSING:-}" ] && continue
    echo "  $f <value>"
  done
  exit 0
fi

has_plugin=no
for a in "$@"; do
  [ "$a" = "--plugin-dir" ] && has_plugin=yes
done

TODAY="$(date +%F)"
mode="${FAKE_MODE:-summary-only}"

do_copy() {
  mkdir -p sources/transcripts
  cp incoming/call-transcript.txt "sources/transcripts/${TODAY}_kickoff-call.txt"
}
do_line() {
  printf '%s\n' "- Jane Doe (Acme Consulting) confirmed the phase one budget at 18,000 euros (call ${TODAY} @00:19)." >>dossier/HISTORY.md
}
do_refresh() {
  awk -v t="$TODAY" 'done == 0 && /^Last updated:/ {print "Last updated: " t ", after the call of " t; done = 1; next} {print}' \
    dossier/HISTORY.md >dossier/HISTORY.md.tmp && mv dossier/HISTORY.md.tmp dossier/HISTORY.md
}

case "$mode" in
  ingest)
    do_copy; do_line; do_refresh
    ;;
  correct)
    do_copy
    grep -vxF -- "$FAKE_SEEDED" dossier/HISTORY.md >dossier/HISTORY.md.tmp && mv dossier/HISTORY.md.tmp dossier/HISTORY.md
    printf '%s\n' "- Jane Doe (Acme Consulting) set the phase one budget at 18,000 euros (call ${TODAY} @00:19; corrects a line dated 2026-10-01)." >>dossier/HISTORY.md
    do_refresh
    ;;
  ingest-unfiled)
    do_line; do_refresh
    ;;
  ingest-no-refresh)
    do_copy; do_line
    ;;
  ingest-lint-error)
    do_copy; do_line; do_refresh
    mkdir -p outbound
    printf '%s\n' 'no status header here' >outbound/2026-10-10_no-header.md
    ;;
esac

skills='["update-config"]'
agents='["general-purpose"]'
if [ "$has_plugin" = yes ] && [ -z "${FAKE_NOSKILL:-}" ]; then
  skills='["update-config","client-dossier:dossier","client-dossier:dossier-ingest"]'
fi
if [ -n "${FAKE_LEAK:-}" ]; then
  skills='["update-config","client-dossier:dossier","client-dossier:dossier-ingest"]'
fi
if [ "$has_plugin" = yes ] && [ -z "${FAKE_NOAGENT:-}" ]; then
  agents='["general-purpose","client-dossier:fact-extractor"]'
fi
if [ -n "${FAKE_LEAK_AGENT:-}" ]; then
  agents='["general-purpose","client-dossier:fact-extractor"]'
fi
printf '%s\n' '{"type":"system","subtype":"init","model":"fake-model","claude_code_version":"0.0.0-fake","skills":'"$skills"',"agents":'"$agents"'}'
if [ "$has_plugin" = yes ]; then
  if [ -z "${FAKE_NOINVOKE:-}" ]; then
    printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"toolu_skill","name":"Skill","input":{"skill":"client-dossier:dossier-ingest"}}]}}'
    if [ -n "${FAKE_DENY_SKILL:-}" ]; then
      printf '%s\n' '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"toolu_skill","content":"Permission denied","is_error":true}]}}'
    elif [ -z "${FAKE_NORESULT:-}" ]; then
      printf '%s\n' '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"toolu_skill","content":"Launching skill"}]}}'
    fi
  fi
  if [ -z "${FAKE_NODISPATCH:-}" ]; then
    printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"toolu_agent","name":"Agent","input":{"subagent_type":"client-dossier:fact-extractor"}}]}}'
    if [ -n "${FAKE_DISPATCH_ERROR:-}" ]; then
      printf '%s\n' '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"toolu_agent","content":"Agent type not found","is_error":true}]}}'
    elif [ -z "${FAKE_NORESULT:-}" ]; then
      printf '%s\n' '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"toolu_agent","content":"Read: 7 lines","is_error":false}]}}'
    fi
  fi
fi
if [ "$mode" = error ]; then iserr=true; else iserr=false; fi
printf '%s\n' '{"type":"result","subtype":"success","is_error":'"$iserr"',"total_cost_usd":0,"result":"fake summary"}'
exit 0
FAKE_EOF
chmod +x "$FAKE"

# col N — column N (1-based) of the first data row of the last case's summary.
col() {
  awk -F'\t' -v n="$1" 'NR==2 {print $n}' "$OUT/summary.tsv"
}

# header N — column N of the header row.
header() {
  awk -F'\t' -v n="$1" 'NR==1 {print $n}' "$OUT/summary.tsv"
}

# drop_dossier — removes the scratch dossier of the last case (column 19).
drop_dossier() {
  local old
  if [ -n "$OUT" ] && [ -f "$OUT/summary.tsv" ]; then
    old="$(awk -F'\t' 'NR==2 {print $19}' "$OUT/summary.tsv")"
    case "$old" in /*) rm -rf "$old" ;; esac
  fi
}

# run_case VARIANT [K=V ...] — runs ingest-transcript.sh once for VARIANT
# against the fake; extra K=V pairs go to the environment, CASE_ARGS holds extra
# harness arguments. Sets OUT, CASE_STATUS, CASE_ERR and OUT.stdout. The scratch
# dossier of the previous case is removed first so /tmp stays clean.
OUT=""
CASE_STATUS=0
CASE_ERR=""
CASE_ARGS=""
run_case() {
  local variant="$1"
  shift
  drop_dossier
  OUT="$(mktemp -d "$WORK/out.XXXXXX")"
  CASE_ERR="$OUT.stderr"
  CASE_STATUS=0
  # shellcheck disable=SC2086
  env SCENARIO_CLAUDE="$FAKE" "$@" \
    bash "$HARNESS" --variant "$variant" --runs 1 $CASE_ARGS "$OUT" \
    >"$OUT.stdout" 2>"$CASE_ERR" || CASE_STATUS=$?
}

# --- Case 1: baseline, the fake changes nothing -> RED, gate passes ---
run_case baseline FAKE_MODE=summary-only
assert_eq 0 "$CASE_STATUS" 'baseline + summary-only: exit 0 (RED reached the gate)'
assert_eq RED "$(col 3)" 'baseline + summary-only: verdict RED'
assert_eq baseline "$(col 1)" 'baseline + summary-only: variant column'
assert_eq 1 "$(col 2)" 'baseline + summary-only: run column'
assert_eq plain "$(col 4)" 'baseline + summary-only: prompt_kind plain'
assert_eq no "$(col 5)" 'baseline + summary-only: AGENTS.md stripped (agents_md no)'
assert_eq none "$(col 6)" 'baseline + summary-only: filed_name none'
assert_eq 0 "$(col 7)" 'baseline + summary-only: timestamped_lines 0'
assert_eq no "$(col 11)" 'baseline + summary-only: ingest_skill no'
assert_eq no "$(col 12)" 'baseline + summary-only: extractor_dispatched no'
assert_eq fake-model "$(col 15)" 'baseline + summary-only: model recorded from system/init'
assert_eq 0.0.0-fake "$(col 16)" 'baseline + summary-only: claude_code_version recorded'
assert_eq 0 "$(col 17)" 'baseline + summary-only: cost recorded from the result event'
assert_eq false "$(col 18)" 'baseline + summary-only: is_error false'
assert_eq 20 "$(awk -F'\t' 'NR==1 {print NF}' "$OUT/summary.tsv")" 'summary.tsv header has 20 columns'
assert_eq 20 "$(awk -F'\t' 'NR==2 {print NF}' "$OUT/summary.tsv")" 'summary.tsv data row has 20 columns'
n=1
for name in variant run verdict prompt_kind agents_md filed_name timestamped_lines refreshed \
  lint_exit warnings ingest_skill extractor_dispatched corrected filed_date_is_today model \
  claude_code_version cost_usd is_error dossier jsonl; do
  assert_eq "$name" "$(header "$n")" "header column $n is $name"
  n=$((n + 1))
done
case "$(col 9)" in
  [0-9]*) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
  *)
    echo "FAIL: baseline + summary-only: lint_exit must be numeric (got '$(col 9)')" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
    ;;
esac
assert_file "$OUT/baseline-1.jsonl"
assert_file "$OUT/baseline-1.diff"
assert_file "$OUT/baseline-1.lint"
assert_file "$OUT/prompt.txt"
assert_eq "$PROMPT_PLAIN" "$(cat "$OUT/prompt.txt")" 'prompt.txt holds PROMPT_PLAIN'
# The fixture as committed at the baseline commit of that run's scratch dossier.
DOSS="$(col 19)"
BASE="$(git -C "$DOSS" rev-parse HEAD)"
assert_eq "$SEEDED_LINE" "$(git -C "$DOSS" show "$BASE:dossier/HISTORY.md" | grep -xF -- "$SEEDED_LINE")" 'baseline commit: HISTORY.md holds the seeded line (D-13)'
for n in $SEVEN; do
  assert_eq 'Last updated: 2026-09-01' "$(git -C "$DOSS" show "$BASE:dossier/$n.md" | grep -m1 '^Last updated:')" "baseline commit: $n backdated (D-13)"
done
if git -C "$DOSS" cat-file -e "$BASE:AGENTS.md" 2>/dev/null; then
  echo "FAIL: baseline commit: AGENTS.md must be absent" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
else
  TESTS_PASSED=$((TESTS_PASSED + 1))
fi
if git -C "$DOSS" cat-file -e "$BASE:incoming/call-transcript.txt" 2>/dev/null; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "FAIL: baseline commit: incoming/call-transcript.txt must be committed" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi
assert_grep '^outdir: ' "$OUT.stdout"
assert_grep '^prompt: ' "$OUT.stdout"
assert_grep 'SCENARIO ingest-transcript: PASS' "$OUT.stdout"

# --- Case 2: plugin + ingest -> GREEN ---
run_case plugin FAKE_MODE=ingest
assert_eq 0 "$CASE_STATUS" 'plugin + ingest: exit 0 (GREEN 1/1)'
assert_eq GREEN "$(col 3)" 'plugin + ingest: verdict GREEN'
case "$(col 6)" in
  sources/transcripts/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]_*) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
  *)
    echo "FAIL: plugin + ingest: filed_name must be a dated file under sources/transcripts (got '$(col 6)')" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
    ;;
esac
case "$(col 7)" in
  0 | '')
    echo "FAIL: plugin + ingest: timestamped_lines must be at least 1 (got '$(col 7)')" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
    ;;
  *) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
esac
assert_eq yes "$(col 8)" 'plugin + ingest: refreshed yes'
assert_eq 0 "$(col 9)" 'plugin + ingest: lint_exit 0'
assert_eq 0 "$(col 10)" 'plugin + ingest: warnings 0'
assert_eq yes "$(col 11)" 'plugin + ingest: ingest_skill yes (D-12)'
assert_eq yes "$(col 12)" 'plugin + ingest: extractor_dispatched yes'
assert_eq no "$(col 13)" 'plugin + ingest: corrected no'
assert_eq yes "$(col 14)" 'plugin + ingest: filed_date_is_today yes'
assert_eq no "$(col 5)" 'plugin + ingest: AGENTS.md stripped'
assert_eq plain "$(col 4)" 'plugin + ingest: prompt_kind plain'

# --- Case 3: plugin + correct -> GREEN, corrected yes (D-13) ---
run_case plugin FAKE_MODE=correct
assert_eq 0 "$CASE_STATUS" 'plugin + correct: exit 0'
assert_eq GREEN "$(col 3)" 'plugin + correct: verdict GREEN'
assert_eq yes "$(col 13)" 'plugin + correct: corrected yes'
assert_eq 0 "$(col 9)" 'plugin + correct: lint_exit 0'

# --- Case 4: 04 D-12 amended, the fact-extractor dispatch gates GREEN ---
run_case plugin FAKE_MODE=ingest FAKE_NODISPATCH=1
assert_eq 1 "$CASE_STATUS" 'plugin + ingest + NODISPATCH: exit 1 (the dispatch gates)'
assert_eq INCOMPLETE "$(col 3)" 'plugin + ingest + NODISPATCH: verdict INCOMPLETE'
assert_eq no "$(col 12)" 'plugin + ingest + NODISPATCH: extractor_dispatched no'
run_case plugin FAKE_MODE=ingest FAKE_DISPATCH_ERROR=1
assert_eq 1 "$CASE_STATUS" 'plugin + ingest + dispatch tool_result in error: exit 1 (R4-m7)'
assert_eq INCOMPLETE "$(col 3)" 'plugin + ingest + dispatch in error: verdict INCOMPLETE'
assert_eq no "$(col 12)" 'plugin + ingest + dispatch in error: extractor_dispatched no'
run_case plugin FAKE_MODE=ingest FAKE_DENY_SKILL=1
assert_eq 1 "$CASE_STATUS" 'plugin + ingest + Skill call denied: exit 1 (R4-m7)'
assert_eq INCOMPLETE "$(col 3)" 'plugin + ingest + Skill call denied: verdict INCOMPLETE'
assert_eq no "$(col 11)" 'plugin + ingest + Skill call denied: ingest_skill no'
run_case plugin FAKE_MODE=ingest FAKE_NORESULT=1
assert_eq INCOMPLETE "$(col 3)" 'plugin + ingest + no tool_result at all: verdict INCOMPLETE (R4-m7)'
# Both paid harnesses carry the amended gate (grep, since the PDF one has no fake).
assert_grep '"\$R_INGEST" = yes \] && \[ "\$R_DISPATCH" = yes' "$HARNESS"
assert_grep '"\$R_INGEST" = yes \] && \[ "\$R_DISPATCH" = yes' "$SCEN_DIR/ingest-pdf.sh"

# --- Case 5: D-12, GREEN needs the dossier-ingest Skill invocation ---
run_case plugin FAKE_MODE=ingest FAKE_NOINVOKE=1
assert_eq 1 "$CASE_STATUS" 'plugin + ingest + NOINVOKE: exit 1 (D-12)'
assert_eq INCOMPLETE "$(col 3)" 'plugin + ingest + NOINVOKE: verdict INCOMPLETE'
assert_eq no "$(col 11)" 'plugin + ingest + NOINVOKE: ingest_skill no'
assert_grep 'SCENARIO ingest-transcript: FAIL' "$OUT.stdout"

# --- Case 6: INCOMPLETE paths ---
run_case plugin FAKE_MODE=ingest-unfiled
assert_eq 1 "$CASE_STATUS" 'plugin + ingest-unfiled: exit 1'
assert_eq INCOMPLETE "$(col 3)" 'plugin + ingest-unfiled: verdict INCOMPLETE'
assert_eq none "$(col 6)" 'plugin + ingest-unfiled: filed_name none'
run_case plugin FAKE_MODE=ingest-no-refresh
assert_eq 1 "$CASE_STATUS" 'plugin + ingest-no-refresh: exit 1'
assert_eq INCOMPLETE "$(col 3)" 'plugin + ingest-no-refresh: verdict INCOMPLETE'
assert_eq no "$(col 8)" 'plugin + ingest-no-refresh: refreshed no'
run_case plugin FAKE_MODE=ingest-lint-error
assert_eq 1 "$CASE_STATUS" 'plugin + ingest-lint-error: exit 1'
assert_eq INCOMPLETE "$(col 3)" 'plugin + ingest-lint-error: verdict INCOMPLETE'
assert_eq 1 "$(col 9)" 'plugin + ingest-lint-error: lint_exit 1'
assert_file "$OUT/plugin-1.lint"
assert_grep 'no status header' "$OUT/plugin-1.lint"

# --- Case 7: baseline + ingest is GREEN (D-12 moot) and fails the baseline gate ---
run_case baseline FAKE_MODE=ingest
assert_eq 1 "$CASE_STATUS" 'baseline + ingest: exit 1 (the baseline gate wants a RED)'
assert_eq GREEN "$(col 3)" 'baseline + ingest: verdict GREEN (D-12 does not apply without the plugin)'
assert_eq no "$(col 11)" 'baseline + ingest: ingest_skill no'

# --- Case 8: nothing filed with the plugin is RED, the plugin gate fails ---
run_case plugin FAKE_MODE=summary-only
assert_eq 1 "$CASE_STATUS" 'plugin + summary-only: exit 1 (gate fails)'
assert_eq RED "$(col 3)" 'plugin + summary-only: verdict RED'

# --- Case 9: harness errors are never verdicts ---
run_case plugin FAKE_MODE=error
assert_eq 2 "$CASE_STATUS" 'plugin + error: exit 2'
assert_grep '^HARNESS ERROR:' "$CASE_ERR"
case "$(col 3)" in
  RED | GREEN | INCOMPLETE)
    echo "FAIL: plugin + error: the row must not carry a RED/GREEN/INCOMPLETE verdict" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
    ;;
  *) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
esac
assert_eq true "$(col 18)" 'plugin + error: is_error true recorded'
run_case plugin FAKE_MODE=ingest FAKE_NOSKILL=1
assert_eq 2 "$CASE_STATUS" 'plugin + NOSKILL: exit 2 (D-12 listing check)'
assert_grep '^HARNESS ERROR:' "$CASE_ERR"
assert_grep 'client-dossier:dossier-ingest' "$CASE_ERR"
run_case plugin FAKE_MODE=ingest FAKE_NOAGENT=1
assert_eq 2 "$CASE_STATUS" 'plugin + NOAGENT: exit 2 (D-12 listing check)'
assert_grep 'client-dossier:fact-extractor' "$CASE_ERR"
run_case baseline FAKE_MODE=summary-only FAKE_LEAK=1
assert_eq 2 "$CASE_STATUS" 'baseline + LEAK: exit 2 (skill contamination)'
assert_grep '^HARNESS ERROR:' "$CASE_ERR"
run_case baseline FAKE_MODE=summary-only FAKE_LEAK_AGENT=1
assert_eq 2 "$CASE_STATUS" 'baseline + LEAK_AGENT: exit 2 (agent contamination)'
assert_grep '^HARNESS ERROR:' "$CASE_ERR"
run_case plugin FAKE_MODE=ingest FAKE_HELP_MISSING=--plugin-dir
assert_eq 2 "$CASE_STATUS" 'missing --plugin-dir in --help: exit 2'
assert_grep 'plugin-dir' "$CASE_ERR"
if [ -f "$OUT/summary.tsv" ] && [ "$(wc -l <"$OUT/summary.tsv" | tr -d ' ')" -gt 1 ]; then
  echo "FAIL: preflight failure must happen before any run (summary.tsv has data rows)" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
else
  TESTS_PASSED=$((TESTS_PASSED + 1))
fi

# --- Case 10: prompts ---
CASE_ARGS="--prompt pressured"
run_case baseline FAKE_MODE=summary-only
assert_eq 0 "$CASE_STATUS" 'baseline + pressured: exit 0'
assert_eq pressured "$(col 4)" 'baseline + pressured: prompt_kind pressured'
assert_eq "$PROMPT_PRESSURED" "$(cat "$OUT/prompt.txt")" 'prompt.txt holds PROMPT_PRESSURED'
CASE_ARGS="--prompt other"
run_case baseline FAKE_MODE=summary-only
assert_eq 2 "$CASE_STATUS" 'an unknown --prompt is a usage error (exit 2)'
CASE_ARGS=""

# --- Case 11: plugin-pointer is informational and keeps AGENTS.md ---
run_case plugin-pointer FAKE_MODE=summary-only
assert_eq 0 "$CASE_STATUS" 'plugin-pointer + summary-only: exit 0 (informational)'
assert_eq yes "$(col 5)" 'plugin-pointer: AGENTS.md kept'
run_case plugin-pointer FAKE_MODE=ingest
assert_eq GREEN "$(col 3)" 'plugin-pointer + ingest: verdict GREEN'
assert_eq yes "$(col 11)" 'plugin-pointer + ingest: ingest_skill yes'

# --- Case 12: the fixture writer neutered -> harness error naming the fixture ---
NOFIX="$WORK/ingest-nofixture.sh"
sed -e "s|^source .*lib-scenario.sh\"\$|source \"$SCEN_DIR/lib-scenario.sh\"|" \
  -e 's|^  write_transcript "\$dir/\$INCOMING_REL"$|  :|' "$HARNESS" >"$NOFIX"
assert_eq 1 "$(grep -c '^  :$' "$NOFIX")" 'the neutering sed replaced exactly the fixture writer call'
drop_dossier
OUT="$(mktemp -d "$WORK/out.XXXXXX")"
CASE_STATUS=0
env SCENARIO_CLAUDE="$FAKE" FAKE_MODE=ingest \
  bash "$NOFIX" --variant plugin --runs 1 "$OUT" >"$OUT.stdout" 2>"$OUT.stderr" || CASE_STATUS=$?
assert_eq 2 "$CASE_STATUS" 'unwritten fixture: exit 2 (harness error)'
assert_grep '^HARNESS ERROR:.*fixture' "$OUT.stderr"
assert_eq HARNESS_ERROR "$(col 3)" 'unwritten fixture: the row is HARNESS_ERROR, never GREEN'

# --- Case 13: no scenario file is picked up by tests/run.sh ---
assert_eq 0 "$(ls "$SCEN_DIR" | grep -c '^test-')" 'no file under tests/scenarios is named test-*.sh'

drop_dossier

finish
