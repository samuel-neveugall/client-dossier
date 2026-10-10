#!/usr/bin/env bash
# tests/scenarios/selftest.sh — free self-test of the paid scenario harness
# (PROTO-07, D-08..D-12, plan 03-02).
#
# fix-typo.sh normally drives a real, authenticated `claude -p` (money, network).
# This script proves every verdict, gate and harness-error path of that harness
# against a generated fake `claude` instead, so the verdict logic is trusted
# before a single model call is paid for. SCENARIO_CLAUDE points the harness at
# the fake. Not named test-*.sh and living in a subdirectory, so tests/run.sh
# never globs it (it is run by hand and by the plan's verify step).
#
# The fake `claude` acts in its working directory according to FAKE_MODE:
#   edit            replace the typo in the transcript (what a RED run does)
#   file            append a dated, sourced correction line to dossier/HISTORY.md
#   file-unsourced  append a line with no source and no date
#   refuse          change nothing
#   error           change nothing, result event has is_error true
# plus FAKE_NOSKILL=1 (plugin run without the skill listed), FAKE_LEAK=1 (skill
# listed without --plugin-dir) and FAKE_HELP_MISSING=<flag> (flag absent from
# --help). Bash 3.2 safe, no arrays.
set -u

# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

SCEN_DIR="$REPO_ROOT/tests/scenarios"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

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

case "${FAKE_MODE:-refuse}" in
  edit)
    python3 - <<'PY'
p = "sources/transcripts/2026-10-01_kickoff.txt"
s = open(p, encoding="utf-8").read()
open(p, "w", encoding="utf-8").write(s.replace("reprot", "report"))
PY
    ;;
  file)
    printf '%s\n' '- Jane Doe (Acme Consulting) asked on 2026-10-01 for the report by 2026-10-20; the transcript reads "reprot" (call 2026-10-01 @00:12).' >>dossier/HISTORY.md
    ;;
  file-unsourced)
    printf '%s\n' '- The transcript has a typo.' >>dossier/HISTORY.md
    ;;
esac

listed=no
if [ "$has_plugin" = yes ] && [ -z "${FAKE_NOSKILL:-}" ]; then listed=yes; fi
if [ -n "${FAKE_LEAK:-}" ]; then listed=yes; fi

if [ "$listed" = yes ]; then
  skills='["update-config","client-dossier:dossier"]'
else
  skills='["update-config"]'
fi
printf '%s\n' '{"type":"system","subtype":"init","model":"fake-model","claude_code_version":"0.0.0-fake","skills":'"$skills"'}'
if [ "$listed" = yes ]; then
  printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"client-dossier:dossier"}}]}}'
fi
if [ "${FAKE_MODE:-refuse}" = error ]; then
  iserr=true
else
  iserr=false
fi
printf '%s\n' '{"type":"result","subtype":"success","is_error":'"$iserr"',"total_cost_usd":0,"result":"fake"}'
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

# run_case VARIANT [K=V ...] — runs fix-typo.sh once for VARIANT against the
# fake, extra K=V pairs go to the environment. Sets OUT (output directory),
# CASE_STATUS, CASE_STDOUT and CASE_STDERR (files). The scratch dossier of the
# previous case is removed first so /tmp stays clean.
OUT=""
CASE_STATUS=0
CASE_ERR=""
run_case() {
  local variant="$1"
  shift
  if [ -n "$OUT" ] && [ -f "$OUT/summary.tsv" ]; then
    local old
    old="$(awk -F'\t' 'NR==2 {print $14}' "$OUT/summary.tsv")"
    case "$old" in /*) rm -rf "$old" ;; esac
  fi
  OUT="$(mktemp -d "$WORK/out.XXXXXX")"
  CASE_ERR="$OUT.stderr"
  CASE_STATUS=0
  env SCENARIO_CLAUDE="$FAKE" "$@" \
    bash "$SCEN_DIR/fix-typo.sh" --variant "$variant" --runs 1 "$OUT" \
    >"$OUT.stdout" 2>"$CASE_ERR" || CASE_STATUS=$?
}

# --- Case 1: baseline, the fake edits the source -> RED, gate passes ---
run_case baseline FAKE_MODE=edit
assert_eq 0 "$CASE_STATUS" 'baseline + edit: exit 0 (RED reached the gate)'
assert_eq RED "$(col 3)" 'baseline + edit: verdict RED'
assert_eq baseline "$(col 1)" 'baseline + edit: variant column'
assert_eq 1 "$(col 2)" 'baseline + edit: run column'
assert_eq 'fake-model' "$(col 10)" 'baseline + edit: model recorded from system/init'
assert_eq '0.0.0-fake' "$(col 11)" 'baseline + edit: claude_code_version recorded'
assert_eq no "$(col 8)" 'baseline + edit: no skill loaded'
assert_eq 0 "$(col 12)" 'baseline + edit: cost recorded from the result event'
assert_eq false "$(col 13)" 'baseline + edit: is_error false'
if [ "$(col 5)" != "$(col 6)" ] && [ -n "$(col 5)" ] && [ -n "$(col 6)" ]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "FAIL: baseline + edit: sha_before must differ from sha_after for a RED row" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi
case "$(col 9)" in
  [0-9]*) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
  *)
    echo "FAIL: baseline + edit: lint_exit must be numeric (got '$(col 9)')" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
    ;;
esac
assert_eq 15 "$(awk -F'\t' 'NR==1 {print NF}' "$OUT/summary.tsv")" 'summary.tsv header has 15 columns'
assert_eq 15 "$(awk -F'\t' 'NR==2 {print NF}' "$OUT/summary.tsv")" 'summary.tsv data row has 15 columns'
assert_eq variant "$(header 1)" 'header column 1 is variant'
assert_eq jsonl "$(header 15)" 'header column 15 is jsonl'
assert_file "$OUT/baseline-1.jsonl"
assert_file "$OUT/baseline-1.diff"

# --- Case 2: plugin, the fake files a dated sourced line -> GREEN ---
run_case plugin FAKE_MODE=file
assert_eq 0 "$CASE_STATUS" 'plugin + file: exit 0 (GREEN 1/1)'
assert_eq GREEN "$(col 3)" 'plugin + file: verdict GREEN'
assert_eq yes "$(col 8)" 'plugin + file: skill_loaded yes'
assert_eq 1 "$(col 7)" 'plugin + file: filed_lines 1'
assert_eq "$(col 5)" "$(col 6)" 'plugin + file: transcript sha unchanged'

# --- Case 3: plugin, the fake refuses and files nothing -> INCOMPLETE ---
run_case plugin FAKE_MODE=refuse
assert_eq 1 "$CASE_STATUS" 'plugin + refuse: exit 1 (gate fails)'
assert_eq INCOMPLETE "$(col 3)" 'plugin + refuse: verdict INCOMPLETE'
assert_eq "$(col 5)" "$(col 6)" 'plugin + refuse: transcript sha unchanged'

# --- Case 4: baseline, the fake refuses -> no RED, gate fails ---
run_case baseline FAKE_MODE=refuse
assert_eq 1 "$CASE_STATUS" 'baseline + refuse: exit 1 (no RED)'
assert_eq INCOMPLETE "$(col 3)" 'baseline + refuse: verdict INCOMPLETE'

# --- Case 5: plugin, an unsourced undated line -> INCOMPLETE ---
run_case plugin FAKE_MODE=file-unsourced
assert_eq 1 "$CASE_STATUS" 'plugin + file-unsourced: exit 1'
assert_eq INCOMPLETE "$(col 3)" 'plugin + file-unsourced: verdict INCOMPLETE'
assert_eq 0 "$(col 7)" 'plugin + file-unsourced: filed_lines 0'

# --- Case 6: result is_error true -> harness error, never a verdict ---
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
assert_eq true "$(col 13)" 'plugin + error: is_error true recorded'

# --- Case 7: D-12, plugin variant without the skill in init -> exit 2 ---
run_case plugin FAKE_MODE=file FAKE_NOSKILL=1
assert_eq 2 "$CASE_STATUS" 'plugin + NOSKILL: exit 2 (D-12)'
assert_grep '^HARNESS ERROR:' "$CASE_ERR"

# --- Case 8: contamination guard, no-plugin variant listing the skill ---
run_case baseline FAKE_MODE=edit FAKE_LEAK=1
assert_eq 2 "$CASE_STATUS" 'baseline + LEAK: exit 2 (contamination guard)'
assert_grep '^HARNESS ERROR:' "$CASE_ERR"

# --- Case 9: pointer-only is informational, never gates ---
run_case pointer-only FAKE_MODE=refuse
assert_eq 0 "$CASE_STATUS" 'pointer-only + refuse: exit 0 (informational)'
assert_eq INCOMPLETE "$(col 3)" 'pointer-only + refuse: verdict INCOMPLETE'

# --- Case 10: a flag missing from --help is caught by the preflight ---
run_case plugin FAKE_MODE=file FAKE_HELP_MISSING=--permission-prompts
assert_eq 2 "$CASE_STATUS" 'missing --permission-prompts in --help: exit 2'
assert_grep '^HARNESS ERROR:' "$CASE_ERR"
assert_grep 'permission-prompts' "$CASE_ERR"
if [ -f "$OUT/summary.tsv" ] && [ "$(wc -l <"$OUT/summary.tsv" | tr -d ' ')" -gt 1 ]; then
  echo "FAIL: preflight failure must happen before any run (summary.tsv has data rows)" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
else
  TESTS_PASSED=$((TESTS_PASSED + 1))
fi

# --- Case 11: tests/run.sh never globs the scenarios ---
assert_eq 0 "$(ls "$SCEN_DIR" | grep -c '^test-')" 'no file under tests/scenarios is named test-*.sh'

# cleanup of the last scratch dossier
if [ -n "$OUT" ] && [ -f "$OUT/summary.tsv" ]; then
  old="$(awk -F'\t' 'NR==2 {print $14}' "$OUT/summary.tsv")"
  case "$old" in /*) rm -rf "$old" ;; esac
fi

finish
