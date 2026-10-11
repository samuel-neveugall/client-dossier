#!/usr/bin/env bash
# tests/scenarios/selftest-call.sh — free self-test of the paid CALL-04 and
# CALL-05 harnesses (tests/scenarios/call-prepare.sh, tests/scenarios/deal-status.sh),
# of the helpers of tests/scenarios/lib-call.sh and of commit_at / set_mtime in
# tests/scenarios/lib-scenario.sh (plan 06-01; D-08, D-10, D-11, D-16).
#
# The harnesses normally drive a real, authenticated `claude -p` (money,
# network). This script proves every helper, verdict, gate and harness-error path
# against a generated fake `claude` instead, so the verdict logic is trusted
# before a single model call is paid for. SCENARIO_CLAUDE points a harness at
# the fake. Not named test-*.sh and living in a subdirectory, so tests/run.sh
# never globs it (it is run by hand and by the plan's verify step).
#
# Bash 3.2 safe, no arrays.
set -u

# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

SCEN_DIR="$REPO_ROOT/tests/scenarios"
HARNESS="$SCEN_DIR/call-prepare.sh"
HARNESS_ST="$SCEN_DIR/deal-status.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# call FN ARGS... — runs a library function in a subshell, as the other
# self-tests do.
call() {
  (. "$SCEN_DIR/lib-scenario.sh" && . "$SCEN_DIR/lib-draft.sh" && . "$SCEN_DIR/lib-call.sh" && "$@")
}

# const NAME / const_status NAME — the value of a harness constant, read with sed
# (one NAME="value" per line), so the fake and the harness cannot disagree
# silently.
const() {
  sed -n 's/^'"$1"'="\(.*\)"$/\1/p' "$HARNESS"
}
const_status() {
  sed -n 's/^'"$1"'="\(.*\)"$/\1/p' "$HARNESS_ST"
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

# assert_ge MIN VALUE LABEL — VALUE is an integer at least MIN.
assert_ge() {
  case "$2" in
    '' | *[!0-9]*)
      echo "FAIL: $3 (not a number: '$2')" >&2
      TESTS_FAILED=$((TESTS_FAILED + 1))
      return 0
      ;;
  esac
  if [ "$2" -ge "$1" ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "FAIL: $3 ($2 < $1)" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

TODAY="$(date +%F)"
TOMORROW="$(call rel_date 1 "$TODAY")"
IDENT_ARGS="--language en --counterpart 'Acme Consulting|ordering party|Jane Doe' --counterpart 'Northwind Telecom|end client' --confidential-name 'Northwind Telecom' --confidential-name Northwind"

# new_dossier — a scratch dossier with the Phase 6 identity and no AGENTS.md.
new_dossier() {
  local d
  d="$(call build_dossier --language en --counterpart 'Acme Consulting|ordering party|Jane Doe' --counterpart 'Northwind Telecom|end client' --confidential-name 'Northwind Telecom' --confidential-name Northwind)"
  rm -f "$d/AGENTS.md"
  echo "$d"
}

# ---------------------------------------------------------------------------
# Section 1: commit_at, set_mtime, rel_date (lib-scenario.sh, lib-call.sh)
# ---------------------------------------------------------------------------

R1="$WORK/repo1"
git init -q "$R1"
git -C "$R1" config user.name "Scenario Runner"
git -C "$R1" config user.email "scenario@example.invalid"
git -C "$R1" config commit.gpgsign false
echo one >"$R1/a.txt"
HEAD1="$(call commit_at "$R1" 2026-09-01 'first')"
assert_eq "$(git -C "$R1" rev-parse HEAD)" "$HEAD1" 'commit_at echoes the new HEAD'
assert_eq '2026-09-01 2026-09-01' "$(git -C "$R1" log -1 --format='%ad %cd' --date=short)" 'commit_at: author and committer date'
echo two >"$R1/b.txt"
call commit_at "$R1" 2026-09-05 'second' >/dev/null
assert_eq '2026-09-05' "$(git -C "$R1" log -1 --format='%ad' --date=short)" 'commit_at: a second commit has its own date'
assert_eq 'second' "$(git -C "$R1" log -1 --format=%s)" 'commit_at: the message'
status=0
call commit_at "$R1" 2026-9-1 'bad' >/dev/null 2>"$WORK/ca.err" || status=$?
assert_eq 2 "$status" 'commit_at with a bad date: exit 2'
assert_grep '^HARNESS ERROR:' "$WORK/ca.err"
status=0
call commit_at "$R1" 2026-09-06 'nothing to commit' >/dev/null 2>"$WORK/ca2.err" || status=$?
assert_eq 2 "$status" 'commit_at with nothing to commit: exit 2'
echo x >"$R1/c.txt"
call set_mtime "$R1/c.txt" 2026-09-01
assert_eq '2026-09-01' "$(python3 -I -c 'import datetime, os, sys; print(datetime.date.fromtimestamp(os.path.getmtime(sys.argv[1])))' "$R1/c.txt")" 'set_mtime: the mtime date'
status=0
call set_mtime "$R1/c.txt" 2026-9-1 2>"$WORK/sm.err" || status=$?
assert_eq 2 "$status" 'set_mtime with a bad date: exit 2'
assert_grep '^HARNESS ERROR:' "$WORK/sm.err"
assert_eq 1 "$(grep -c '^# --- Phase 6 additions (plan 06-01) ---$' "$SCEN_DIR/lib-scenario.sh")" 'lib-scenario.sh holds the Phase 6 block once'
assert_eq 2026-10-08 "$(call rel_date -3 2026-10-11)" 'rel_date -3'
assert_eq 2027-01-01 "$(call rel_date 1 2026-12-31)" 'rel_date across a year end'
assert_eq 2026-10-11 "$(call rel_date 0 2026-10-11)" 'rel_date 0'
assert_eq "$TODAY" "$(call rel_date 0)" 'rel_date without a base is today'

# ---------------------------------------------------------------------------
# Section 2: the CALL-04 fixture
# ---------------------------------------------------------------------------

P1="$(new_dossier)"
call prep_fixture "$P1" 2026-10-11
status=0
call check_prep_fixture "$P1" 2026-10-11 || status=$?
assert_eq 0 "$status" 'check_prep_fixture passes on a seeded dossier'
LINT_P1="$(python3 "$(lint_py)" "$P1" 2>&1)"
status=0
python3 "$(lint_py)" "$P1" >/dev/null 2>&1 || status=$?
assert_eq 0 "$status" 'prep fixture: lint exits 0'
assert_has '0 error(s), 0 warning(s)' "$LINT_P1" 'prep fixture: lint is clean'
L_FT="$(grep -n 'field teams' "$P1/dossier/OPEN-QUESTIONS.md" | head -1 | cut -d: -f1)"
L_SI="$(grep -n 'Who signs the order' "$P1/dossier/OPEN-QUESTIONS.md" | head -1 | cut -d: -f1)"
L_GL="$(grep -n 'go-live' "$P1/dossier/OPEN-QUESTIONS.md" | head -1 | cut -d: -f1)"
if [ "$L_FT" -lt "$L_SI" ] && [ "$L_SI" -lt "$L_GL" ]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "FAIL: the open questions are not in the field teams, signs, go-live order ($L_FT $L_SI $L_GL)" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi
assert_eq '## Still open on the counterpart side' "$(awk '/^## / {c++} c==2 && /^## / {print; exit}' "$P1/dossier/OPEN-QUESTIONS.md")" 'the rows sit under the second ## heading'
assert_eq 7 "$(grep -c '^Last updated: '"$(call rel_date -10 2026-10-11)"'$' "$P1"/dossier/*.md | awk -F: '{s += $2} END {print s}')" 'every living file is backdated to D(-10)'
assert_file "$P1/outbound/calls/2026-10-01_kickoff.md"
assert_grep_e '^- We send the quote for the pilot to Jane Doe \(Acme Consulting\) by 2026-10-16 \(call 2026-10-01 @21:40\)\.$' "$P1/dossier/HISTORY.md"
assert_grep '^- A price before the pilot scope is signed' "$P1/knowledge/DOCTRINE.md"
assert_grep 'last 30 minutes' "$P1/dossier/CHANNELS.md"
assert_eq 0 "$(awk '/^## Upcoming/ {on=1; next} on && NF {c++} END {print c+0}' "$P1/dossier/HISTORY.md")" 'nothing under ## Upcoming'
assert_eq 6 "$(awk '/^## Chronology/ {on=1; next} /^## / {on=0} on && /^- / {c++} END {print c+0}' "$P1/dossier/HISTORY.md")" 'six Chronology bullets'
assert_eq 0 "$(call text_has_ci "$P1/none.jsonl" x | grep -c yes)" 'text_has_ci on a missing file is no'

# A copy with one row removed: check_prep_fixture exits 2 naming the row.
grep -v 'go-live' "$P1/dossier/OPEN-QUESTIONS.md" >"$WORK/oq.tmp" && cp "$WORK/oq.tmp" "$P1/dossier/OPEN-QUESTIONS.md"
status=0
call check_prep_fixture "$P1" 2026-10-11 2>"$WORK/cp.err" || status=$?
assert_eq 2 "$status" 'check_prep_fixture with a row removed: exit 2'
assert_grep '^HARNESS ERROR:.*open question 3' "$WORK/cp.err"
rm -rf "$P1"

# ---------------------------------------------------------------------------
# Section 3: lib-call.sh units on crafted files
# ---------------------------------------------------------------------------

U="$WORK/units"
mkdir -p "$U"
printf '%s\n' '# Call' '' '## Open questions' '' '- Who signs the order?' '- Is the go-live firm?' '- Do the field teams join?' >"$U/q-ok.md"
printf '%s\n' '# Call' '' '- Is the go-live firm?' '- Who signs the order?' '- Do the field teams join?' >"$U/q-bad.md"
printf '%s\n' '# Call' '' '- Who signs the order?' '- Is the go-live firm?' 'The field teams' >"$U/q-miss.md"
printf '%s\n' '# Call' 'signs go-live field teams, one line without a mark' '- Who SIGNS?' '- GO-LIVE?' '- Field Teams?' >"$U/q-ci.md"
assert_eq yes "$(call call_question_order "$U/q-ok.md" signs go-live 'field teams')" 'call_question_order: ascending'
assert_eq no "$(call call_question_order "$U/q-bad.md" signs go-live 'field teams')" 'call_question_order: all present, wrong order'
assert_eq missing "$(call call_question_order "$U/q-miss.md" signs go-live 'field teams')" 'call_question_order: a token without a question line'
assert_eq missing "$(call call_question_order "$U/nope.md" signs go-live 'field teams')" 'call_question_order: missing file'
assert_eq yes "$(call call_question_order "$U/q-ci.md" signs go-live 'field teams')" 'call_question_order: case-insensitive, the mark decides'

printf '%s\n' '# Call' '## What we do not do in this call' '- x' >"$U/h1.md"
printf '%s\n' '# Call' '## What we don'"'"'t do' >"$U/h2.md"
printf '%s\n' '# Call' 'What we do not do is not a heading' >"$U/h3.md"
assert_eq yes "$(call call_heading_present "$U/h1.md" 'what we (do not|don.t) do')" 'call_heading_present: do not'
assert_eq yes "$(call call_heading_present "$U/h2.md" 'what we (do not|don.t) do')" 'call_heading_present: dont'
assert_eq no "$(call call_heading_present "$U/h3.md" 'what we (do not|don.t) do')" 'call_heading_present: not a heading'
assert_eq no "$(call call_heading_present "$U/nope.md" 'x')" 'call_heading_present: missing file'

MIN='^#{1,6} +minutes'
printf '%s\n' '# Call' '## Agenda (30 minutes)' '- 0:00 Intro' '## Minutes' '' >"$U/m1.md"
printf '%s\n' '# Call' '## Minutes' '<!-- to fill after the call -->' '' '<!--' 'multi' 'line' '-->' >"$U/m2.md"
printf '%s\n' '# Call' '## Minutes' '' '- Jane agrees (call 2026-10-01 @12:34).' >"$U/m3.md"
printf '%s\n' '# Call' '## Agenda' '- x' >"$U/m4.md"
printf '%s\n' '# Call' '## Minutes' '' '## Next' '- later' >"$U/m5.md"
assert_eq yes "$(call call_minutes_empty "$U/m1.md" "$MIN")" 'call_minutes_empty: empty, with an earlier Agenda (30 minutes) heading'
assert_eq yes "$(call call_minutes_empty "$U/m2.md" "$MIN")" 'call_minutes_empty: only HTML comments'
assert_eq no "$(call call_minutes_empty "$U/m3.md" "$MIN")" 'call_minutes_empty: a filled line'
assert_eq none "$(call call_minutes_empty "$U/m4.md" "$MIN")" 'call_minutes_empty: no minutes heading'
assert_eq yes "$(call call_minutes_empty "$U/m5.md" "$MIN")" 'call_minutes_empty: stops at the next heading'
assert_eq none "$(call call_minutes_empty "$U/nope.md" "$MIN")" 'call_minutes_empty: missing file'

printf '%s\n' '- 0:00-0:05 Intro' '- 10 min: scope' '- 5min wrap' '- Jane agrees (call 2026-10-01 @12:34).' '- plain line' '12:30 Lunch' >"$U/t1.md"
assert_eq 4 "$(call call_timed_lines "$U/t1.md")" 'call_timed_lines: counts clock and minute lines, ignores @ locators'
assert_eq 0 "$(call call_timed_lines "$U/nope.md")" 'call_timed_lines: missing file'
printf '%s\n' '<!--' 'Status: draft' 'Deadline: 2026-10-12' '-->' 'body' >"$U/d1.md"
printf '%s\n' '<!--' 'Status: draft' '-->' 'body' >"$U/d2.md"
assert_eq yes "$(call call_line_present "$U/d1.md" 'Deadline:')" 'call_line_present: a deadline field line'
assert_eq no "$(call call_line_present "$U/d2.md" 'Deadline:')" 'call_line_present: none present'
assert_eq none "$(call call_line_present "$U/nope.md" 'Deadline:')" 'call_line_present: missing file'

printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"text","text":"Steering-Agenda mentioned here only"}]}}' '{"type":"result","is_error":false,"result":"first answer"}' '{"type":"result","is_error":false,"result":"The Steering-Agenda draft is overdue; revised_quote done"}' >"$U/r.jsonl"
assert_eq yes "$(call text_has_ci "$U/r.jsonl" 'steering agenda')" 'text_has_ci: folds - and _ and case'
assert_eq yes "$(call text_has_ci "$U/r.jsonl" 'revised-quote')" 'text_has_ci: folds _ against -'
assert_eq no "$(call text_has_ci "$U/r.jsonl" 'first answer')" 'text_has_ci: only the last result event counts'
assert_eq no "$(call text_has_ci "$U/nope.jsonl" 'x')" 'text_has_ci: missing file'
printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"a","name":"Read","input":{"file_path":"x"}},{"type":"tool_use","id":"b","name":"Bash","input":{"command":"cat dossier/HISTORY.md"}},{"type":"tool_use","id":"c","name":"Bash","input":{"command":"ls"}},{"type":"tool_use","id":"d","name":"Bash","input":{"command":"sed -n 1,5p x"}},{"type":"tool_use","id":"e","name":"Bash","input":{"command":"head -3 x"}}]}}' >"$U/reads.jsonl"
assert_eq 4 "$(call call_reads "$U/reads.jsonl")" 'call_reads: Read, cat, sed -n, head'
assert_eq 0 "$(call call_reads "$U/nope.jsonl")" 'call_reads: missing file'
printf '%s\n' '{"type":"user","message":{"content":[{"type":"text","text":"Stop hook feedback: the outbound changed but nothing under dossier/ did"}]}}' >"$U/stop.jsonl"
assert_eq yes "$(call stop_blocked "$U/stop.jsonl")" 'stop_blocked: the hook text'
assert_eq no "$(call stop_blocked "$U/r.jsonl")" 'stop_blocked: absent'
assert_eq no "$(call stop_blocked "$U/nope.jsonl")" 'stop_blocked: missing file'

R2="$WORK/repo2"
git init -q "$R2"
git -C "$R2" config user.name "Scenario Runner"
git -C "$R2" config user.email "scenario@example.invalid"
echo a >"$R2/a.txt"
call commit_at "$R2" 2026-09-01 m >/dev/null
assert_eq yes "$(call porcelain_empty "$R2")" 'porcelain_empty: clean'
echo b >"$R2/b.txt"
assert_eq no "$(call porcelain_empty "$R2")" 'porcelain_empty: untracked file'
rm "$R2/b.txt"
call tree_manifest "$R2" >"$WORK/man1.txt"
assert_grep '  a.txt$' "$WORK/man1.txt"
assert_grep '  \.git/HEAD$' "$WORK/man1.txt"
call tree_manifest "$R2" >"$WORK/man1b.txt"
assert_eq "$(cat "$WORK/man1.txt")" "$(cat "$WORK/man1b.txt")" 'tree_manifest is stable'
echo c >"$R2/.git/extra"
call tree_manifest "$R2" >"$WORK/man2.txt"
assert_eq 1 "$(diff "$WORK/man1.txt" "$WORK/man2.txt" | grep -c '^>')" 'tree_manifest sees a new file under .git'

# ---------------------------------------------------------------------------
# Section 4: the harness constants and the fake claude
#
# The fake `claude` acts in its working directory according to FAKE_MODE:
#   CALL-04:  chat-only, prep-good, prep-tomorrow-word, prep-no-notdo,
#             prep-two-questions, prep-today-date, prep-misorder, prep-deadline,
#             prep-untimed, prep-minutes-filled, prep-leak
#   CALL-05:  status-all, status-miss-source, status-miss-draft,
#             status-miss-commitment, status-writes, status-git-only
#   both:     error (is_error true)
# plus the stream switches FAKE_NOSKILL, FAKE_LEAK, FAKE_LEAK_AGENT,
# FAKE_NOINVOKE, FAKE_NOSCRIPT, FAKE_NORESULT, FAKE_HELP_MISSING=<flag>,
# FAKE_DISPATCH and FAKE_TRAPS.
# ---------------------------------------------------------------------------

ORDERING_PARTY="$(const ORDERING_PARTY)"
END_CLIENT="$(const END_CLIENT)"
CONFIDENTIAL_LONG="$(const CONFIDENTIAL_LONG)"
CONFIDENTIAL_SHORT="$(const CONFIDENTIAL_SHORT)"
TOKEN_FIRST="$(const TOKEN_FIRST)"
TOKEN_SECOND="$(const TOKEN_SECOND)"
TOKEN_THIRD="$(const TOKEN_THIRD)"
NOT_DO_ERE="$(const NOT_DO_ERE)"
MINUTES_ERE="$(const MINUTES_ERE)"
PROMPT_PLAIN="$(const PROMPT_PLAIN)"
PROMPT_PRESSURED="$(const PROMPT_PRESSURED)"
assert_eq 'Acme Consulting|ordering party|Jane Doe' "$ORDERING_PARTY" 'constant ORDERING_PARTY'
assert_eq 'Northwind Telecom|end client' "$END_CLIENT" 'constant END_CLIENT'
assert_eq 'Northwind Telecom' "$CONFIDENTIAL_LONG" 'constant CONFIDENTIAL_LONG'
assert_eq 'Northwind' "$CONFIDENTIAL_SHORT" 'constant CONFIDENTIAL_SHORT'
assert_eq 'signs' "$TOKEN_FIRST" 'constant TOKEN_FIRST'
assert_eq 'go-live' "$TOKEN_SECOND" 'constant TOKEN_SECOND'
assert_eq 'field teams' "$TOKEN_THIRD" 'constant TOKEN_THIRD'
assert_eq 'what we (do not|don.t) do' "$NOT_DO_ERE" 'constant NOT_DO_ERE'
assert_eq '^#{1,6} +minutes' "$MINUTES_ERE" 'constant MINUTES_ERE'
assert_eq "Prepare tomorrow's call with Jane." "$PROMPT_PLAIN" 'constant PROMPT_PLAIN'
assert_eq "Prepare tomorrow's call with Jane. Quick, I only have two minutes before my next meeting." "$PROMPT_PRESSURED" 'constant PROMPT_PRESSURED'
assert_eq 11 "$(grep -cE '^(ORDERING_PARTY|END_CLIENT|CONFIDENTIAL_LONG|CONFIDENTIAL_SHORT|TOKEN_FIRST|TOKEN_SECOND|TOKEN_THIRD|NOT_DO_ERE|MINUTES_ERE|PROMPT_PLAIN|PROMPT_PRESSURED)=' "$HARNESS")" 'eleven named constants in call-prepare.sh'
assert_eq 1 "$(grep -cx '  seed_fixture "\$dir"' "$HARNESS")" 'call-prepare: seed_fixture has one call site'
for name in ORDERING_PARTY END_CLIENT CONFIDENTIAL_LONG CONFIDENTIAL_SHORT TOKEN_FIRST TOKEN_SECOND TOKEN_THIRD NOT_DO_ERE MINUTES_ERE PROMPT_PLAIN PROMPT_PRESSURED; do
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
prompt=""
prev=""
for a in "$@"; do
  [ "$a" = "--plugin-dir" ] && has_plugin=yes
  [ "$prev" = "-p" ] && prompt="$a"
  prev="$a"
done
case "$prompt" in
  *Prepare*) scen=prep ;;
  *) scen=status ;;
esac

TODAY="$(date +%F)"
TOMORROW="$(python3 -I -c 'import datetime; print(datetime.date.today() + datetime.timedelta(days=1))')"
mode="${FAKE_MODE:-chat-only}"

# --- CALL-04 ---------------------------------------------------------------
prep_write() {
  local fname="${TOMORROW}_jane-call.md" ctx notdo q1 q2 q3 minutes
  [ "$mode" = prep-today-date ] && fname="${TODAY}_jane-call.md"
  ctx="Preparation of the call with the ordering party's project lead."
  [ "$mode" = prep-tomorrow-word ] && ctx="Preparation of the call planned for tomorrow."
  [ "$mode" = prep-leak ] && ctx="This concerns the Northwind Telecom pilot."
  notdo="## What we do not do in this call"
  [ "$mode" = prep-no-notdo ] && notdo="## Cautions"
  q1="- Who signs the order on the ordering party's side?"
  q2="- Is the go-live date of the pilot firm?"
  q3="- Do the end client's field teams join the pilot?"
  mkdir -p outbound/calls
  {
    printf '%s\n' '<!--' 'Status: draft' "To: the ordering party's project lead"
    [ "$mode" = prep-deadline ] && printf '%s\n' "Deadline: $TOMORROW"
    printf '%s\n' "Written by: agent session, $TODAY" 'Rules: no confidential names; see knowledge/DOCTRINE.md' '-->' ''
    printf '%s\n' "# Call with the ordering party, $TOMORROW" '' '## Context' '' "$ctx" '' '## What we want to obtain' '' 'A firm go decision on the pilot scope.' '' '## Agenda' ''
    if [ "$mode" = prep-untimed ]; then
      printf '%s\n' '- Welcome' '- Pilot scope'
    else
      printf '%s\n' '- 0:00-0:05 Welcome' '- 0:05-0:20 Pilot scope'
    fi
    printf '%s\n' '' "$notdo" '' '- Quote a price before the pilot scope is signed.' '' '## Open questions' ''
    if [ "$mode" = prep-misorder ]; then
      printf '%s\n' "$q2" "$q1" "$q3"
    elif [ "$mode" = prep-two-questions ]; then
      printf '%s\n' "$q1" "$q2"
    else
      printf '%s\n' "$q1" "$q2" "$q3"
    fi
    printf '%s\n' '' '## Minutes' ''
    if [ "$mode" = prep-minutes-filled ]; then
      printf '%s\n' "- Jane Doe (Acme Consulting) agrees (call $TOMORROW @12:34)."
    fi
  } >"outbound/calls/$fname"
  awk -v b="- Call with the ordering party's project lead on $TOMORROW (outbound/calls/$fname)." \
    '{print} $0 == "## Upcoming" {print b}' dossier/HISTORY.md >dossier/HISTORY.md.tmp \
    && mv dossier/HISTORY.md.tmp dossier/HISTORY.md
}

# --- CALL-05 ---------------------------------------------------------------
status_answer() {
  local out="Where we stand: on track for the pilot."
  [ "$mode" != status-miss-commitment ] && out="$out The security questionnaire answers are overdue."
  [ "$mode" != status-miss-draft ] && out="$out The steering agenda draft is overdue."
  [ "$mode" != status-miss-source ] && out="$out The pilot brochure was filed and not reflected."
  if [ -n "${FAKE_TRAPS:-}" ]; then
    out="$out The revised quote is sent, the pilot plan is not due, the signed NDA is done. RELATIONSHIP is stale."
  fi
  printf '%s' "$out"
}

case "$mode" in
  prep-good | prep-tomorrow-word | prep-no-notdo | prep-two-questions | prep-today-date | prep-misorder | prep-deadline | prep-untimed | prep-minutes-filled | prep-leak)
    prep_write
    ;;
  status-writes)
    printf '%s\n' '- 2026-10-01: a line the status run must not write.' >>dossier/HISTORY.md
    ;;
  status-git-only)
    printf 'x\n' >.git/fake-refresh
    ;;
esac

if [ "$scen" = prep ]; then main_skill="client-dossier:dossier-call"; else main_skill="client-dossier:dossier-status"; fi
skills='["update-config"]'
agents='["general-purpose"]'
if [ "$has_plugin" = yes ] && [ -z "${FAKE_NOSKILL:-}" ]; then
  skills='["update-config","client-dossier:dossier","'"$main_skill"'"]'
fi
if [ -n "${FAKE_LEAK:-}" ]; then
  skills='["update-config","client-dossier:dossier","'"$main_skill"'"]'
fi
if [ "$has_plugin" = yes ] || [ -n "${FAKE_LEAK_AGENT:-}" ]; then
  agents='["general-purpose","client-dossier:doctrine-reviewer"]'
fi
printf '%s\n' '{"type":"system","subtype":"init","model":"fake-model","claude_code_version":"0.0.0-fake","skills":'"$skills"',"agents":'"$agents"'}'

if [ "$has_plugin" = yes ] && [ -z "${FAKE_NOINVOKE:-}" ]; then
  printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"toolu_skill","name":"Skill","input":{"skill":"'"$main_skill"'"}}]}}'
  printf '%s\n' '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"toolu_skill","content":"Launching skill"}]}}'
fi
if [ "$scen" = status ]; then
  printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"toolu_read","name":"Read","input":{"file_path":"/scratch/dossier/RELATIONSHIP.md"}}]}}'
  printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"toolu_cat","name":"Bash","input":{"command":"cat dossier/HISTORY.md"}}]}}'
  if [ "$has_plugin" = yes ] && [ -z "${FAKE_NOSCRIPT:-}" ]; then
    printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"toolu_status","name":"Bash","input":{"command":"python3 /plugin/skills/dossier-status/scripts/status.py '"'"'/scratch'"'"'"}}]}}'
  fi
fi
if [ -n "${FAKE_DISPATCH:-}" ]; then
  printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"toolu_agent","name":"Agent","input":{"subagent_type":"client-dossier:doctrine-reviewer"}}]}}'
  printf '%s\n' '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"toolu_agent","content":"Reviewed","is_error":false}]}}'
fi

if [ "$scen" = status ]; then RESULT="$(status_answer)"; else RESULT="fake summary"; fi
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

# drop_dossier — removes the scratch dossier of the last case (the column named
# `dossier` in the header).
drop_dossier() {
  local old
  if [ -n "${OUT:-}" ] && [ -f "$OUT/summary.tsv" ]; then
    old="$(awk -F'\t' 'NR==1 {for (i = 1; i <= NF; i++) if ($i == "dossier") c = i} NR==2 {print $c}' "$OUT/summary.tsv")"
    case "$old" in /*) rm -rf "$old" ;; esac
  fi
}

# run_case VARIANT [K=V ...] — runs the harness H once for VARIANT against the
# fake; extra K=V pairs go to the environment, CASE_ARGS holds extra harness
# arguments. Sets OUT, CASE_STATUS, CASE_ERR and OUT.stdout. The scratch dossier
# of the previous case is removed first so /tmp stays clean.
H="$HARNESS"
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
    bash "$H" --variant "$variant" --runs 1 $CASE_ARGS "$OUT" \
    >"$OUT.stdout" 2>"$CASE_ERR" || CASE_STATUS=$?
}

# --- Case 1: baseline, the fake changes nothing -> RED, gate passes ---
H="$HARNESS"
run_case baseline FAKE_MODE=chat-only
assert_eq 0 "$CASE_STATUS" 'prep baseline + chat-only: exit 0 (RED reached the gate)'
assert_eq RED "$(col 3)" 'prep baseline + chat-only: verdict RED'
assert_eq baseline "$(col 1)" 'prep baseline + chat-only: variant column'
assert_eq 1 "$(col 2)" 'prep baseline + chat-only: run column'
assert_eq plain "$(col 4)" 'prep baseline + chat-only: prompt_kind plain'
assert_eq no "$(col 5)" 'prep baseline + chat-only: AGENTS.md stripped (agents_md no)'
assert_eq none "$(col 6)" 'prep baseline + chat-only: call_file none'
assert_eq 0 "$(col 7)" 'prep baseline + chat-only: new_calls 0'
assert_eq fake-model "$(col 23)" 'prep baseline + chat-only: model recorded from system/init'
assert_eq 0.0.0-fake "$(col 24)" 'prep baseline + chat-only: claude_code_version recorded'
assert_eq 0.01 "$(col 25)" 'prep baseline + chat-only: cost recorded from the result event'
assert_eq false "$(col 26)" 'prep baseline + chat-only: is_error false'
assert_eq 28 "$(awk -F'\t' 'NR==1 {print NF}' "$OUT/summary.tsv")" 'prep summary.tsv header has 28 columns'
assert_eq 28 "$(awk -F'\t' 'NR==2 {print NF}' "$OUT/summary.tsv")" 'prep summary.tsv data row has 28 columns'
n=1
for name in variant run verdict prompt_kind agents_md call_file new_calls reldate_words \
  questions_present questions_order not_do_section minutes_empty timed_lines \
  deadline_line lint_exit e5 call_skill history_upcoming to_value stop_blocked \
  lint_called reviewer_dispatched model claude_code_version cost_usd is_error \
  dossier jsonl; do
  assert_eq "$name" "$(header "$n")" "prep header column $n is $name"
  n=$((n + 1))
done
assert_file "$OUT/baseline-1.jsonl"
assert_file "$OUT/baseline-1.diff"
assert_file "$OUT/baseline-1.lint"
assert_file "$OUT/prompt.txt"
assert_eq "$PROMPT_PLAIN" "$(cat "$OUT/prompt.txt")" 'prep prompt.txt holds PROMPT_PLAIN'
DOSS="$(col 27)"
BASE="$(git -C "$DOSS" rev-parse HEAD)"
assert_eq "$(call rel_date -10 "$TODAY")" "$(git -C "$DOSS" log -1 --format=%ad --date=short)" 'prep baseline commit is dated D(-10)'
if git -C "$DOSS" cat-file -e "$BASE:AGENTS.md" 2>/dev/null; then
  echo "FAIL: prep baseline commit: AGENTS.md must be absent" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
else
  TESTS_PASSED=$((TESTS_PASSED + 1))
fi
assert_grep '^outdir: ' "$OUT.stdout"
assert_grep '^prompt: ' "$OUT.stdout"
assert_eq 'SCENARIO call-prepare: PASS' "$(tail -1 "$OUT.stdout")" 'prep: the last line is the scenario verdict (PASS)'

# --- Case 2: plugin + prep-good -> GREEN ---
run_case plugin FAKE_MODE=prep-good
assert_eq 0 "$CASE_STATUS" 'prep plugin + prep-good: exit 0 (GREEN 1/1)'
assert_eq GREEN "$(col 3)" 'prep plugin + prep-good: verdict GREEN'
assert_eq "outbound/calls/${TOMORROW}_jane-call.md" "$(col 6)" 'prep plugin + prep-good: call_file'
assert_eq 1 "$(col 7)" 'prep plugin + prep-good: new_calls 1'
assert_eq 0 "$(col 8)" 'prep plugin + prep-good: reldate_words 0'
assert_eq 3 "$(col 9)" 'prep plugin + prep-good: questions_present 3'
assert_eq yes "$(col 10)" 'prep plugin + prep-good: questions_order yes'
assert_eq yes "$(col 11)" 'prep plugin + prep-good: not_do_section yes'
assert_eq yes "$(col 12)" 'prep plugin + prep-good: minutes_empty yes'
assert_ge 2 "$(col 13)" 'prep plugin + prep-good: timed_lines at least 2'
assert_eq no "$(col 14)" 'prep plugin + prep-good: deadline_line no'
assert_eq 0 "$(col 15)" 'prep plugin + prep-good: lint_exit 0'
assert_eq no "$(col 16)" 'prep plugin + prep-good: e5 no'
assert_eq yes "$(col 17)" 'prep plugin + prep-good: call_skill yes'
assert_eq yes "$(col 18)" 'prep plugin + prep-good: history_upcoming yes'
assert_eq "the ordering party's project lead" "$(col 19)" 'prep plugin + prep-good: to_value'
assert_eq no "$(col 20)" 'prep plugin + prep-good: stop_blocked no'
assert_eq no "$(col 22)" 'prep plugin + prep-good: reviewer_dispatched no'
assert_eq no "$(col 5)" 'prep plugin + prep-good: AGENTS.md stripped'
assert_eq 'SCENARIO call-prepare: PASS' "$(tail -1 "$OUT.stdout")" 'prep plugin + prep-good: PASS'

# --- Case 3: no scenario file is picked up by tests/run.sh ---
assert_eq 0 "$(ls "$SCEN_DIR" | grep -c '^test-')" 'no file under tests/scenarios is named test-*.sh'

drop_dossier

finish
