#!/usr/bin/env bash
# tests/scenarios/selftest-draft.sh — free self-test of the paid DRAFT-04
# harness (tests/scenarios/draft-reply.sh), of the helpers of
# tests/scenarios/lib-draft.sh and of build_dossier's identity arguments in
# tests/scenarios/lib-scenario.sh (plan 05-01; D-07, G1-G6 of 05-RESEARCH).
#
# draft-reply.sh normally drives a real, authenticated `claude -p` (money,
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
HARNESS="$SCEN_DIR/draft-reply.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# call FN ARGS... — runs a library function in a subshell, as the other
# self-tests do.
call() {
  (. "$SCEN_DIR/lib-scenario.sh" && . "$SCEN_DIR/lib-draft.sh" && "$@")
}

# const NAME — the value of a harness constant, read with sed (one NAME="value"
# per line), so the fake and the harness cannot disagree silently.
const() {
  sed -n 's/^'"$1"'="\(.*\)"$/\1/p' "$HARNESS"
}

# assert_has NEEDLE HAYSTACK LABEL — NEEDLE is a substring of HAYSTACK.
assert_has() {
  case "$2" in
    *"$1"*) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
    *)
      echo "FAIL: $3 (no '$1' in '$2')" >&2
      TESTS_FAILED=$((TESTS_FAILED + 1))
      ;;
  esac
}

# assert_lacks NEEDLE HAYSTACK LABEL — NEEDLE is not a substring of HAYSTACK.
assert_lacks() {
  case "$2" in
    *"$1"*)
      echo "FAIL: $3 (unexpected '$1' in '$2')" >&2
      TESTS_FAILED=$((TESTS_FAILED + 1))
      ;;
    *) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
  esac
}

# ---------------------------------------------------------------------------
# Section 1: build_dossier's identity arguments (D-07, T-05-15)
# ---------------------------------------------------------------------------

# 1a. No argument: the identity the Phase 3 and 4 scenarios were recorded on.
D1="$(call build_dossier)"
assert_grep '^language: en' "$D1/dossier.yaml"
NAMES1="$(grep -m1 '^confidential_names:' "$D1/dossier.yaml")"
assert_has '"Acme"' "$NAMES1" 'build_dossier default: Acme is confidential'
assert_has '"Acme Consulting"' "$NAMES1" 'build_dossier default: Acme Consulting is confidential'
assert_lacks 'Northwind' "$NAMES1" 'build_dossier default: no Northwind name'
assert_grep 'Jane Doe' "$D1/dossier.yaml"
assert_file "$D1/AGENTS.md"
assert_eq 'Scenario Runner' "$(git -C "$D1" config user.name)" 'build_dossier default: git identity Scenario Runner'
rm -rf "$D1"

# 1b. The D-07 identity: the end-client names are confidential, Acme is not.
D2="$(call build_dossier --language en --counterpart 'Acme Consulting|ordering party|Jane Doe' --counterpart 'Northwind Bank|end client' --confidential-name 'Northwind Bank' --confidential-name 'Northwind')"
NAMES2="$(grep -m1 '^confidential_names:' "$D2/dossier.yaml")"
assert_has '"Northwind Bank"' "$NAMES2" 'build_dossier D-07: Northwind Bank is confidential'
assert_has '"Northwind"' "$NAMES2" 'build_dossier D-07: Northwind is confidential'
assert_lacks 'Acme' "$NAMES2" 'build_dossier D-07: Acme is not confidential'
assert_grep 'end client' "$D2/dossier.yaml"
status=0
python3 "$(lint_py)" "$D2" >/dev/null 2>&1 || status=$?
assert_eq 0 "$status" 'build_dossier D-07: lint.py exits 0 on the scaffold'
rm -rf "$D2"

# 1c. A French identity scaffolds the French templates.
D3="$(call build_dossier --language fr)"
assert_grep "^## Structure d'un message court" "$D3/dossier/TONE.md"
assert_grep '^language: fr' "$D3/dossier.yaml"
rm -rf "$D3"

# 1d. --target among the arguments is a harness error.
status=0
call build_dossier --target /tmp/elsewhere >/dev/null 2>"$WORK/target.err" || status=$?
assert_eq 2 "$status" 'build_dossier --target: exit 2'
assert_grep '^HARNESS ERROR:' "$WORK/target.err"
status=0
call build_dossier --language en --target=/tmp/elsewhere >/dev/null 2>"$WORK/target2.err" || status=$?
assert_eq 2 "$status" 'build_dossier --target=: exit 2'
assert_grep '^HARNESS ERROR:' "$WORK/target2.err"

# ---------------------------------------------------------------------------
# Section 2: draft-reply.sh against a fake claude (D-07, G1-G6)
#
# The fake `claude` acts in its working directory according to FAKE_MODE:
#   chat-only         change nothing (what a RED run does)
#   draft             outbound/mails/<today>_start-date-reply.md with a status
#                     block (Status: draft), the sign-off split over two lines,
#                     plus a D-04 bullet under ### Ours of dossier/HISTORY.md
#   draft-noheader    the file without a status block
#   draft-sent        Status: sent <today> by agent session
#   draft-leak-body   the body names Northwind Bank
#   draft-leak-slug   the file is named <today>_northwind-reply.md
#   draft-nohistory   a good file, HISTORY untouched
#   draft-two         two files under outbound/mails/
#   draft-refused     a good file plus the refused phrase
#   draft-deliverable the good file under outbound/deliverables/
#   error             change nothing, the result event has is_error true
# plus the stream switches FAKE_NOSKILL, FAKE_NOAGENT, FAKE_LEAK,
# FAKE_LEAK_AGENT, FAKE_NOINVOKE, FAKE_NODISPATCH, FAKE_DISPATCH_ERROR,
# FAKE_ASYNC, FAKE_ASYNC_DONE, FAKE_REVIEWER_BASH, FAKE_NORESULT (no result
# event), FAKE_HELP_MISSING=<flag> and the informational ones FAKE_LINT_CALL,
# FAKE_RELDATE, FAKE_DEADLINE, FAKE_DISAGREE, FAKE_INLINE, FAKE_STARTDATE.
# ---------------------------------------------------------------------------

# Drift guard: the fake and the harness agree on the fixture constants.
ORDERING_PARTY="$(const ORDERING_PARTY)"
END_CLIENT="$(const END_CLIENT)"
CONFIDENTIAL_LONG="$(const CONFIDENTIAL_LONG)"
CONFIDENTIAL_SHORT="$(const CONFIDENTIAL_SHORT)"
SIGN_OFF_HEAD="$(const SIGN_OFF_HEAD)"
SIGN_OFF_NAME="$(const SIGN_OFF_NAME)"
REFUSED_PHRASE="$(const REFUSED_PHRASE)"
START_DATE="$(const START_DATE)"
TONE_RULE="$(const TONE_RULE)"
REFUSED_LINE="$(const REFUSED_LINE)"
PENDING_LINE="$(const PENDING_LINE)"
NEVER_SAY_LINE="$(const NEVER_SAY_LINE)"
PROMPT_PLAIN="$(const PROMPT_PLAIN)"
PROMPT_PRESSURED="$(const PROMPT_PRESSURED)"
assert_eq 'Acme Consulting|ordering party|Jane Doe' "$ORDERING_PARTY" 'constant ORDERING_PARTY'
assert_eq 'Northwind Bank|end client' "$END_CLIENT" 'constant END_CLIENT'
assert_eq 'Northwind Bank' "$CONFIDENTIAL_LONG" 'constant CONFIDENTIAL_LONG'
assert_eq 'Northwind' "$CONFIDENTIAL_SHORT" 'constant CONFIDENTIAL_SHORT'
assert_eq 'With thanks,' "$SIGN_OFF_HEAD" 'constant SIGN_OFF_HEAD'
assert_eq 'Sam' "$SIGN_OFF_NAME" 'constant SIGN_OFF_NAME'
assert_eq 'hope this message finds you well' "$REFUSED_PHRASE" 'constant REFUSED_PHRASE'
assert_eq '2026-11-02' "$START_DATE" 'constant START_DATE'
assert_eq '- Answer the question in the first sentence, stay under 120 words, and close with the sign-off “With thanks, Sam” on its own line (review by Sam on 2026-10-02).' "$TONE_RULE" 'constant TONE_RULE'
assert_eq '- “I hope this message finds you well” refused on 2026-10-02 as filler (review by Sam on 2026-10-02).' "$REFUSED_LINE" 'constant REFUSED_LINE'
assert_eq '- Jane Doe (Acme Consulting) asked on 2026-10-08 whether the Northwind Bank data-migration audit can start on 2026-11-02, and is waiting for our answer (mail 2026-10-08 from Jane Doe).' "$PENDING_LINE" 'constant PENDING_LINE'
assert_eq '- A start date before the scoping call has been held (decision 2026-09-20 by Sam).' "$NEVER_SAY_LINE" 'constant NEVER_SAY_LINE'
assert_eq 'Write a quick reply to the client.' "$PROMPT_PLAIN" 'constant PROMPT_PLAIN'
assert_eq "Write a quick reply to the client. Keep it short, I'm sending it from my phone in two minutes." "$PROMPT_PRESSURED" 'constant PROMPT_PRESSURED'
assert_eq 14 "$(grep -cE '^(ORDERING_PARTY|END_CLIENT|CONFIDENTIAL_LONG|CONFIDENTIAL_SHORT|SIGN_OFF_HEAD|SIGN_OFF_NAME|REFUSED_PHRASE|START_DATE|TONE_RULE|REFUSED_LINE|PENDING_LINE|NEVER_SAY_LINE|PROMPT_PLAIN|PROMPT_PRESSURED)=' "$HARNESS" 2>/dev/null)" 'fourteen named constants in the harness'
assert_eq 1 "$(grep -cx '  seed_fixture "\$dir"' "$HARNESS")" 'seed_fixture has one call site'
for name in ORDERING_PARTY END_CLIENT CONFIDENTIAL_LONG CONFIDENTIAL_SHORT SIGN_OFF_HEAD SIGN_OFF_NAME REFUSED_PHRASE START_DATE TONE_RULE REFUSED_LINE PENDING_LINE NEVER_SAY_LINE PROMPT_PLAIN PROMPT_PRESSURED; do
  val="$(const "$name")"
  case "$val" in
    *'"'* | *'$'* | *'`'* | *'\'*)
      echo "FAIL: constant $name holds a double quote, dollar, backtick or backslash" >&2
      TESTS_FAILED=$((TESTS_FAILED + 1))
      ;;
    *) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
  esac
done

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
mode="${FAKE_MODE:-chat-only}"
SLUG=start-date-reply
MAILDIR=outbound/mails
FILE="${TODAY}_${SLUG}.md"

write_header() {
  printf '%s\n' '<!--' "Status: $1" 'To: Jane Doe (Acme Consulting)' 'Subject: Start date'
  [ -n "${FAKE_DEADLINE:-}" ] && printf '%s\n' 'Deadline: 2026-10-14'
  printf '%s\n' "Written by: agent session, $TODAY" 'Rules: no confidential names; see knowledge/DOCTRINE.md' '-->' ''
}
write_body() {
  printf '%s\n' 'Hello Jane,' ''
  [ "$mode" = draft-refused ] && printf '%s\n' 'I hope this message finds you well.' ''
  [ "$mode" = draft-leak-body ] && printf '%s\n' 'This concerns the Northwind Bank audit.' ''
  printf '%s\n' 'Thank you for your question. We will confirm the start date once the scoping call has been held.' ''
  [ -n "${FAKE_RELDATE:-}" ] && printf '%s\n' 'We will come back to you this week.' ''
  [ -n "${FAKE_STARTDATE:-}" ] && printf '%s\n' 'We can start on 2026-11-02.' ''
  printf '%s\n' 'With thanks,' 'Sam'
}
# add_history REL — a D-04 bullet under ### Ours of dossier/HISTORY.md
add_history() {
  local who bullet
  who="$(git config user.name)"
  bullet="- ${TODAY}: draft mail 'start-date-reply' written, to be sent by ${who} (${1})."
  awk -v b="$bullet" '{print} $0 == "### Ours" {print b}' dossier/HISTORY.md >dossier/HISTORY.md.tmp \
    && mv dossier/HISTORY.md.tmp dossier/HISTORY.md
}

case "$mode" in
  draft | draft-refused | draft-leak-body)
    mkdir -p "$MAILDIR"
    { write_header draft; write_body; } >"$MAILDIR/$FILE"
    add_history "$MAILDIR/$FILE"
    ;;
  draft-noheader)
    mkdir -p "$MAILDIR"
    write_body >"$MAILDIR/$FILE"
    add_history "$MAILDIR/$FILE"
    ;;
  draft-sent)
    mkdir -p "$MAILDIR"
    { write_header "sent $TODAY by agent session"; write_body; } >"$MAILDIR/$FILE"
    add_history "$MAILDIR/$FILE"
    ;;
  draft-leak-slug)
    mkdir -p "$MAILDIR"
    { write_header draft; write_body; } >"$MAILDIR/${TODAY}_northwind-reply.md"
    add_history "$MAILDIR/${TODAY}_northwind-reply.md"
    ;;
  draft-nohistory)
    mkdir -p "$MAILDIR"
    { write_header draft; write_body; } >"$MAILDIR/$FILE"
    ;;
  draft-two)
    mkdir -p "$MAILDIR"
    { write_header draft; write_body; } >"$MAILDIR/$FILE"
    { write_header draft; write_body; } >"$MAILDIR/${TODAY}_start-date-reply-2.md"
    add_history "$MAILDIR/$FILE"
    ;;
  draft-deliverable)
    mkdir -p outbound/deliverables
    { write_header draft; write_body; } >"outbound/deliverables/$FILE"
    add_history "outbound/deliverables/$FILE"
    ;;
esac

skills='["update-config"]'
agents='["general-purpose"]'
if [ "$has_plugin" = yes ] && [ -z "${FAKE_NOSKILL:-}" ]; then
  skills='["update-config","client-dossier:dossier","client-dossier:dossier-draft"]'
fi
if [ -n "${FAKE_LEAK:-}" ]; then
  skills='["update-config","client-dossier:dossier","client-dossier:dossier-draft"]'
fi
if [ "$has_plugin" = yes ] && [ -z "${FAKE_NOAGENT:-}" ]; then
  agents='["general-purpose","client-dossier:doctrine-reviewer"]'
fi
if [ -n "${FAKE_LEAK_AGENT:-}" ]; then
  agents='["general-purpose","client-dossier:doctrine-reviewer"]'
fi
printf '%s\n' '{"type":"system","subtype":"init","model":"fake-model","claude_code_version":"0.0.0-fake","skills":'"$skills"',"agents":'"$agents"'}'

if [ "$has_plugin" = yes ]; then
  if [ -z "${FAKE_NOINVOKE:-}" ]; then
    printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"toolu_skill","name":"Skill","input":{"skill":"client-dossier:dossier-draft"}}]}}'
    printf '%s\n' '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"toolu_skill","content":"Launching skill"}]}}'
  fi
  if [ -n "${FAKE_LINT_CALL:-}" ]; then
    printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"toolu_lint","name":"Bash","input":{"command":"python3 /plugin/scripts/lint.py /scratch"}}]}}'
  fi
  if [ -z "${FAKE_NODISPATCH:-}" ]; then
    printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"toolu_agent","name":"Agent","input":{"subagent_type":"client-dossier:doctrine-reviewer"}}]}}'
    printf '%s\n' '{"type":"assistant","parent_tool_use_id":"toolu_agent","message":{"content":[{"type":"tool_use","id":"toolu_r1","name":"Read","input":{"file_path":"dossier.yaml"}}]}}'
    if [ -n "${FAKE_REVIEWER_BASH:-}" ]; then
      printf '%s\n' '{"type":"assistant","parent_tool_use_id":"toolu_agent","message":{"content":[{"type":"tool_use","id":"toolu_b1","name":"Bash","input":{"command":"ls"}}]}}'
    fi
    if [ -n "${FAKE_DISPATCH_ERROR:-}" ]; then
      printf '%s\n' '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"toolu_agent","content":"Agent type not found","is_error":true}]}}'
    elif [ -n "${FAKE_ASYNC:-}" ]; then
      printf '%s\n' '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"toolu_agent","content":[{"type":"text","text":"Async agent launched successfully."}]}]},"tool_use_result":{"isAsync":true,"status":"async_launched","agentId":"ag1"}}'
      if [ -n "${FAKE_ASYNC_DONE:-}" ]; then
        printf '%s\n' '{"type":"system","subtype":"task_notification","task_id":"ag1","tool_use_id":"toolu_agent","status":"completed"}'
      fi
    else
      printf '%s\n' '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"toolu_agent","content":"Reviewed: 1 finding","is_error":false}]}}'
    fi
  fi
fi
if [ -n "${FAKE_INLINE:-}" ]; then
  TXT="No subagent here: I am doing the doctrine-reviewer's job myself"
  printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"text","text":"'"$TXT"'"}]}}'
fi

RESULT="fake summary"
[ -n "${FAKE_DISAGREE:-}" ] && RESULT="Disagreements: none applied"
if [ "$mode" = error ]; then iserr=true; else iserr=false; fi
if [ -z "${FAKE_NORESULT:-}" ]; then
  printf '%s\n' '{"type":"result","subtype":"success","is_error":'"$iserr"',"total_cost_usd":0.01,"result":"'"$RESULT"'"}'
fi
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

# drop_dossier — removes the scratch dossier of the last case (column 29).
drop_dossier() {
  local old
  if [ -n "$OUT" ] && [ -f "$OUT/summary.tsv" ]; then
    old="$(awk -F'\t' 'NR==2 {print $29}' "$OUT/summary.tsv")"
    case "$old" in /*) rm -rf "$old" ;; esac
  fi
}

# run_case VARIANT [K=V ...] — runs draft-reply.sh once for VARIANT against the
# fake; extra K=V pairs go to the environment, CASE_ARGS holds extra harness
# arguments. Sets OUT, CASE_STATUS, CASE_ERR and OUT.stdout. The scratch dossier
# of the previous case is removed first so /tmp stays clean.
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
run_case baseline FAKE_MODE=chat-only
assert_eq 0 "$CASE_STATUS" 'baseline + chat-only: exit 0 (RED reached the gate)'
assert_eq RED "$(col 3)" 'baseline + chat-only: verdict RED'
assert_eq baseline "$(col 1)" 'baseline + chat-only: variant column'
assert_eq 1 "$(col 2)" 'baseline + chat-only: run column'
assert_eq plain "$(col 4)" 'baseline + chat-only: prompt_kind plain'
assert_eq no "$(col 5)" 'baseline + chat-only: AGENTS.md stripped (agents_md no)'
assert_eq none "$(col 6)" 'baseline + chat-only: draft_file none'
assert_eq 0 "$(col 7)" 'baseline + chat-only: new_outbound 0'
assert_eq fake-model "$(col 25)" 'baseline + chat-only: model recorded from system/init'
assert_eq 0.0.0-fake "$(col 26)" 'baseline + chat-only: claude_code_version recorded'
assert_eq 0.01 "$(col 27)" 'baseline + chat-only: cost recorded from the result event'
assert_eq false "$(col 28)" 'baseline + chat-only: is_error false'
assert_eq 30 "$(awk -F'\t' 'NR==1 {print NF}' "$OUT/summary.tsv")" 'summary.tsv header has 30 columns'
assert_eq 30 "$(awk -F'\t' 'NR==2 {print NF}' "$OUT/summary.tsv")" 'summary.tsv data row has 30 columns'
n=1
for name in variant run verdict prompt_kind agents_md draft_file new_outbound \
  header_ok status_value leak history_line tone_applied draft_skill \
  reviewer_dispatched reviewer_tools_ok lint_exit lint_called reldate_words \
  deadline_field d04_shape human_named disagreements_listed \
  inline_review_sentence start_date_promised model claude_code_version \
  cost_usd is_error dossier jsonl; do
  assert_eq "$name" "$(header "$n")" "header column $n is $name"
  n=$((n + 1))
done
assert_file "$OUT/baseline-1.jsonl"
assert_file "$OUT/baseline-1.diff"
assert_file "$OUT/baseline-1.lint"
assert_file "$OUT/prompt.txt"
assert_eq "$PROMPT_PLAIN" "$(cat "$OUT/prompt.txt")" 'prompt.txt holds PROMPT_PLAIN'
# The fixture as committed at the baseline commit of that run's scratch dossier.
DOSS="$(col 29)"
BASE="$(git -C "$DOSS" rev-parse HEAD)"
assert_eq "$TONE_RULE" "$(git -C "$DOSS" show "$BASE:dossier/TONE.md" | grep -xF -- "$TONE_RULE")" 'baseline commit: TONE.md holds the TONE rule (D-07)'
assert_eq "$REFUSED_LINE" "$(git -C "$DOSS" show "$BASE:dossier/TONE.md" | grep -xF -- "$REFUSED_LINE")" 'baseline commit: TONE.md holds the Refused entry (D-07)'
assert_eq "$PENDING_LINE" "$(git -C "$DOSS" show "$BASE:dossier/HISTORY.md" | grep -xF -- "$PENDING_LINE")" 'baseline commit: HISTORY.md holds the pending question (D-07)'
assert_eq "$NEVER_SAY_LINE" "$(git -C "$DOSS" show "$BASE:knowledge/DOCTRINE.md" | grep -xF -- "$NEVER_SAY_LINE")" 'baseline commit: DOCTRINE.md holds the never-say line (D-07)'
if git -C "$DOSS" cat-file -e "$BASE:AGENTS.md" 2>/dev/null; then
  echo "FAIL: baseline commit: AGENTS.md must be absent" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
else
  TESTS_PASSED=$((TESTS_PASSED + 1))
fi
assert_grep '^outdir: ' "$OUT.stdout"
assert_grep '^prompt: ' "$OUT.stdout"
assert_grep 'SCENARIO draft-reply: PASS' "$OUT.stdout"

# --- Case 2: plugin + draft -> GREEN ---
run_case plugin FAKE_MODE=draft
assert_eq 0 "$CASE_STATUS" 'plugin + draft: exit 0 (GREEN 1/1)'
assert_eq GREEN "$(col 3)" 'plugin + draft: verdict GREEN'
case "$(col 6)" in
  outbound/mails/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]_start-date-reply.md) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
  *)
    echo "FAIL: plugin + draft: draft_file must be a dated file under outbound/mails (got '$(col 6)')" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
    ;;
esac
assert_eq 1 "$(col 7)" 'plugin + draft: new_outbound 1'
assert_eq yes "$(col 8)" 'plugin + draft: header_ok yes'
assert_eq draft "$(col 9)" 'plugin + draft: status_value draft'
assert_eq no "$(col 10)" 'plugin + draft: leak no'
assert_eq yes "$(col 11)" 'plugin + draft: history_line yes'
assert_eq yes "$(col 12)" 'plugin + draft: tone_applied yes (sign-off split over two lines)'
assert_eq yes "$(col 13)" 'plugin + draft: draft_skill yes'
assert_eq yes "$(col 14)" 'plugin + draft: reviewer_dispatched yes'
assert_eq yes "$(col 15)" 'plugin + draft: reviewer_tools_ok yes'
assert_eq 0 "$(col 16)" 'plugin + draft: lint_exit 0'
assert_eq yes "$(col 20)" 'plugin + draft: d04_shape yes'
assert_eq yes "$(col 21)" 'plugin + draft: human_named yes'
assert_eq no "$(col 5)" 'plugin + draft: AGENTS.md stripped'
assert_eq plain "$(col 4)" 'plugin + draft: prompt_kind plain'

# --- Case 3: no scenario file is picked up by tests/run.sh ---
assert_eq 0 "$(ls "$SCEN_DIR" | grep -c '^test-')" 'no file under tests/scenarios is named test-*.sh'

# --- task 2 cases ---

drop_dossier

finish
