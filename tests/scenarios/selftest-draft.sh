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

# The French deadline scenario (plan 05-04): fr-* modes write
# outbound/mails/<today>_reponse-date-audit.md and a bullet under the first ###
# heading below the second ## heading of dossier/HISTORY.md.
FR_FILE="${TODAY}_reponse-date-audit.md"
fr_header() {
  if [ "$mode" = fr-translated-header ]; then
    printf '%s\n' '<!--' 'Statut: brouillon' 'À: Jane Doe (Acme Consulting)' 'Objet: Date de démarrage de l’audit' 'Échéance: 2026-10-30' "Rédigé par: session agent, $TODAY" 'Règles: aucun nom confidentiel ; voir knowledge/DOCTRINE.md' '-->' ''
    return 0
  fi
  printf '%s\n' '<!--' 'Status: draft' 'To: Jane Doe (Acme Consulting)' 'Subject: Date de démarrage de l’audit'
  case "$mode" in
    fr-no-deadline) ;;
    fr-wrong-deadline) printf '%s\n' 'Deadline: 2026-10-31' ;;
    *) printf '%s\n' 'Deadline: 2026-10-30' ;;
  esac
  printf '%s\n' "Written by: agent session, $TODAY" 'Rules: no confidential names; see knowledge/DOCTRINE.md' '-->' ''
}
fr_body() {
  if [ "$mode" = fr-english-body ]; then
    printf '%s\n' 'Hello Jane,' '' 'Thank you for your question. We will confirm the start date of the audit once the scoping call has been held, and we will send you the exact date with the plan for the next steps.' ''
  else
    printf '%s\n' 'Bonjour Jane,' ''
    [ "$mode" = fr-refused ] && printf '%s\n' 'J’espère que vous allez bien.' ''
    [ "$mode" = fr-leak ] && printf '%s\n' 'Cela concerne l’audit de Northwind Bank.' ''
    printf '%s\n' 'Merci pour votre question. Nous vous confirmons que l’audit pourra démarrer une fois l’appel de cadrage tenu, et nous vous enverrons la date exacte avec le plan pour la suite.' ''
  fi
  [ "$mode" = fr-no-signoff ] || printf '%s\n' 'Bien cordialement,' 'Sam'
  return 0
}
# add_history_fr REL — the bullet under the first ### below the second ##.
add_history_fr() {
  local who bullet
  who="$(git config user.name)"
  if [ "$mode" = fr-history-nodeadline ]; then
    bullet="- ${TODAY} : brouillon mail 'reponse-date-audit' écrit, à envoyer par ${who} (${1})."
  else
    bullet="- ${TODAY} : brouillon mail 'reponse-date-audit' écrit, à envoyer par ${who}, échéance 2026-10-30 (${1})."
  fi
  awk -v b="$bullet" '/^## / {c++} {print} c >= 2 && !done && /^### / {print b; done=1}' dossier/HISTORY.md >dossier/HISTORY.md.tmp \
    && mv dossier/HISTORY.md.tmp dossier/HISTORY.md
}

case "$mode" in
  fr-draft | fr-no-deadline | fr-wrong-deadline | fr-english-body | fr-translated-header | fr-refused | fr-no-signoff | fr-leak | fr-history-nodeadline)
    mkdir -p "$MAILDIR"
    { fr_header; fr_body; } >"$MAILDIR/$FR_FILE"
    add_history_fr "$MAILDIR/$FR_FILE"
    ;;
  fr-slug)
    mkdir -p "$MAILDIR"
    { fr_header; fr_body; } >"$MAILDIR/${TODAY}_reponse-date.md"
    add_history_fr "$MAILDIR/${TODAY}_reponse-date.md"
    ;;
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
  # The draft is written with Write (A5-F5); FAKE_LINT_EARLY lints before the final edit.
  printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"toolu_write","name":"Write","input":{"file_path":"/scratch/outbound/mails/draft.md"}}]}}'
  # R6-6: the history is edited before the review has returned (FAKE_HISTORY_EARLY: Edit,
  # FAKE_HISTORY_BASH: a redirection); FAKE_HISTORY_READ only reads it with a Bash command
  # that holds a `>` in `2>/dev/null` and must not count.
  if [ -n "${FAKE_HISTORY_EARLY:-}" ]; then
    printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"toolu_histe","name":"Edit","input":{"file_path":"/scratch/dossier/HISTORY.md"}}]}}'
  fi
  if [ -n "${FAKE_HISTORY_BASH:-}" ]; then
    printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"toolu_histb","name":"Bash","input":{"command":"echo - 2026-10-10: draft >> /scratch/dossier/HISTORY.md"}}]}}'
  fi
  if [ -n "${FAKE_HISTORY_READ:-}" ]; then
    printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"toolu_histr","name":"Bash","input":{"command":"cat /scratch/dossier/HISTORY.md 2>/dev/null | head -20"}}]}}'
  fi
  if [ -n "${FAKE_LINT_EARLY:-}" ]; then
    printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"toolu_lint0","name":"Bash","input":{"command":"python3 /plugin/scripts/lint.py /scratch"}}]}}'
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
      # FAKE_HANDBACK_EARLY: the turn is handed back before the findings return.
      if [ -n "${FAKE_HANDBACK_EARLY:-}" ]; then
        printf '%s\n' '{"type":"result","subtype":"success","is_error":false,"total_cost_usd":0.01,"result":"waiting for the reviewer"}'
      fi
      if [ -n "${FAKE_HISTORY_DURING_ASYNC:-}" ]; then
        printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"toolu_hista","name":"Edit","input":{"file_path":"/scratch/dossier/HISTORY.md"}}]}}'
      fi
      if [ -n "${FAKE_ASYNC_DONE:-}" ]; then
        printf '%s\n' '{"type":"system","subtype":"task_notification","task_id":"ag1","tool_use_id":"toolu_agent","status":"completed"}'
      fi
    else
      if [ -n "${FAKE_HANDBACK_EARLY:-}" ]; then
        printf '%s\n' '{"type":"result","subtype":"success","is_error":false,"total_cost_usd":0.01,"result":"waiting for the reviewer"}'
      fi
      printf '%s\n' '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"toolu_agent","content":"Reviewed: 1 finding","is_error":false}]}}'
    fi
  fi
  # The findings are applied with Edit, then the linter runs on the final draft.
  printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"toolu_edit","name":"Edit","input":{"file_path":"/scratch/outbound/mails/draft.md"}}]}}'
  if [ -z "${FAKE_NOLINT:-}" ] && [ -z "${FAKE_LINT_EARLY:-}" ]; then
    printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"toolu_lint","name":"Bash","input":{"command":"python3 /plugin/scripts/lint.py /scratch"}}]}}'
  fi
  # The history line comes last, after the review and the lint (the documented order).
  printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"toolu_histl","name":"Edit","input":{"file_path":"/scratch/dossier/HISTORY.md"}}]}}'
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

# drop_dossier — removes the scratch dossier of the last case (the column before
# named `dossier` in the header: column 29 of draft-reply.sh, column 21 of
# draft-deadline-fr.sh; the two order columns now follow the jsonl column).
drop_dossier() {
  local old
  if [ -n "$OUT" ] && [ -f "$OUT/summary.tsv" ]; then
    old="$(awk -F'\t' 'NR==1 {for (i = 1; i <= NF; i++) if ($i == "dossier") c = i} NR==2 {print $c}' "$OUT/summary.tsv")"
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
assert_eq 33 "$(awk -F'\t' 'NR==1 {print NF}' "$OUT/summary.tsv")" 'summary.tsv header has 33 columns'
assert_eq 33 "$(awk -F'\t' 'NR==2 {print NF}' "$OUT/summary.tsv")" 'summary.tsv data row has 33 columns'
n=1
for name in variant run verdict prompt_kind agents_md draft_file new_outbound \
  header_ok status_value leak history_line tone_applied draft_skill \
  reviewer_dispatched reviewer_tools_ok lint_exit lint_called reldate_words \
  deadline_field d04_shape human_named disagreements_listed \
  inline_review_sentence start_date_promised model claude_code_version \
  cost_usd is_error dossier jsonl handback_before_review lint_after_last_draft_edit \
  history_edit_before_review; do
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

# --- Case 4: the red shapes of the research probes (G2, G3, G4) ---
run_case plugin FAKE_MODE=draft-noheader
assert_eq 1 "$CASE_STATUS" 'plugin + draft-noheader: exit 1'
assert_eq RED "$(col 3)" 'plugin + draft-noheader: verdict RED (G2)'
assert_eq no "$(col 8)" 'plugin + draft-noheader: header_ok no'
assert_eq none "$(col 9)" 'plugin + draft-noheader: status_value none'
run_case plugin FAKE_MODE=draft-sent
assert_eq RED "$(col 3)" 'plugin + draft-sent: verdict RED (G2)'
assert_has 'sent' "$(col 9)" 'plugin + draft-sent: status_value starts with sent'
assert_eq no "$(col 8)" 'plugin + draft-sent: header_ok no (lint accepts it, the harness does not)'
run_case plugin FAKE_MODE=draft-leak-body
assert_eq RED "$(col 3)" 'plugin + draft-leak-body: verdict RED (G3)'
assert_eq yes "$(col 10)" 'plugin + draft-leak-body: leak yes'
run_case plugin FAKE_MODE=draft-leak-slug
assert_eq RED "$(col 3)" 'plugin + draft-leak-slug: verdict RED (G3)'
assert_eq yes "$(col 10)" 'plugin + draft-leak-slug: leak yes'
run_case plugin FAKE_MODE=draft-nohistory
assert_eq RED "$(col 3)" 'plugin + draft-nohistory: verdict RED (G4, the A2 shape)'
assert_eq no "$(col 11)" 'plugin + draft-nohistory: history_line no'
assert_eq yes "$(col 8)" 'plugin + draft-nohistory: header_ok yes'

# --- Case 5: the incomplete shapes (G1, G5) ---
run_case plugin FAKE_MODE=draft-two
assert_eq 1 "$CASE_STATUS" 'plugin + draft-two: exit 1'
assert_eq INCOMPLETE "$(col 3)" 'plugin + draft-two: verdict INCOMPLETE (G1)'
assert_eq 2 "$(col 7)" 'plugin + draft-two: new_outbound 2'
assert_eq none "$(col 6)" 'plugin + draft-two: draft_file none'
run_case plugin FAKE_MODE=draft-refused
assert_eq INCOMPLETE "$(col 3)" 'plugin + draft-refused: verdict INCOMPLETE (G5)'
assert_eq no "$(col 12)" 'plugin + draft-refused: tone_applied no'
run_case plugin FAKE_MODE=draft-deliverable
assert_eq INCOMPLETE "$(col 3)" 'plugin + draft-deliverable: verdict INCOMPLETE (G1)'
assert_eq none "$(col 6)" 'plugin + draft-deliverable: draft_file none'
assert_eq yes "$(col 11)" 'plugin + draft-deliverable: history_line yes'
assert_eq 1 "$(col 7)" 'plugin + draft-deliverable: new_outbound 1'

# --- Case 6: G6, the skill and the reviewer gate GREEN in the plugin variants ---
run_case plugin FAKE_MODE=draft FAKE_NOINVOKE=1
assert_eq 1 "$CASE_STATUS" 'plugin + draft + NOINVOKE: exit 1 (the B shape of the probe)'
assert_eq INCOMPLETE "$(col 3)" 'plugin + draft + NOINVOKE: verdict INCOMPLETE'
assert_eq no "$(col 13)" 'plugin + draft + NOINVOKE: draft_skill no'
assert_grep 'SCENARIO draft-reply: FAIL' "$OUT.stdout"
run_case plugin FAKE_MODE=draft FAKE_NODISPATCH=1
assert_eq INCOMPLETE "$(col 3)" 'plugin + draft + NODISPATCH: verdict INCOMPLETE'
assert_eq no "$(col 14)" 'plugin + draft + NODISPATCH: reviewer_dispatched no'
assert_eq none "$(col 15)" 'plugin + draft + NODISPATCH: reviewer_tools_ok none'
run_case plugin FAKE_MODE=draft FAKE_DISPATCH_ERROR=1
assert_eq INCOMPLETE "$(col 3)" 'plugin + draft + dispatch in error: verdict INCOMPLETE (R4-m7)'
assert_eq no "$(col 14)" 'plugin + draft + dispatch in error: reviewer_dispatched no'
run_case plugin FAKE_MODE=draft FAKE_ASYNC=1
assert_eq INCOMPLETE "$(col 3)" 'plugin + draft + async launch only: verdict INCOMPLETE (Pitfall 5)'
assert_eq no "$(col 14)" 'plugin + draft + async launch only: reviewer_dispatched no'
run_case plugin FAKE_MODE=draft FAKE_ASYNC=1 FAKE_ASYNC_DONE=1
assert_eq 0 "$CASE_STATUS" 'plugin + draft + async completed: exit 0'
assert_eq GREEN "$(col 3)" 'plugin + draft + async completed: verdict GREEN'
assert_eq yes "$(col 14)" 'plugin + draft + async completed: reviewer_dispatched yes'
run_case plugin FAKE_MODE=draft FAKE_REVIEWER_BASH=1
assert_eq GREEN "$(col 3)" 'plugin + draft + reviewer Bash: still GREEN (informational)'
assert_eq no "$(col 15)" 'plugin + draft + reviewer Bash: reviewer_tools_ok no'
run_case baseline FAKE_MODE=draft
assert_eq 1 "$CASE_STATUS" 'baseline + draft: exit 1 (the baseline gate wants a RED)'
assert_eq GREEN "$(col 3)" 'baseline + draft: verdict GREEN (G6 is moot without the plugin)'
assert_eq no "$(col 13)" 'baseline + draft: draft_skill no'
run_case plugin FAKE_MODE=chat-only
assert_eq 1 "$CASE_STATUS" 'plugin + chat-only: exit 1 (gate fails)'
assert_eq RED "$(col 3)" 'plugin + chat-only: verdict RED'

# --- Case 7: the informational columns never gate ---
run_case plugin FAKE_MODE=draft
assert_eq yes "$(col 17)" 'default draft: lint_called yes (the fake lints after its last edit)'
assert_eq 0 "$(col 18)" 'default draft: reldate_words 0'
assert_eq none "$(col 19)" 'default draft: deadline_field none'
assert_eq no "$(col 22)" 'default draft: disagreements_listed no'
assert_eq no "$(col 23)" 'default draft: inline_review_sentence no'
assert_eq no "$(col 24)" 'default draft: start_date_promised no'
assert_eq 0 "$(col 31)" 'default draft: handback_before_review 0 (R5-M1)'
assert_eq yes "$(col 32)" 'default draft: lint_after_last_draft_edit yes (R5-M1)'
assert_eq 0 "$(col 33)" 'default draft: history_edit_before_review 0 (R6-6)'
run_case plugin FAKE_MODE=draft FAKE_NOLINT=1
assert_eq no "$(col 17)" 'draft + no lint: lint_called no'
assert_eq no "$(col 32)" 'draft + no lint: lint_after_last_draft_edit no'
assert_eq INCOMPLETE "$(col 3)" 'draft + no lint: verdict INCOMPLETE (R5-M1 gate)'
run_case plugin FAKE_MODE=draft FAKE_LINT_EARLY=1
assert_eq yes "$(col 17)" 'draft + lint before the last edit: lint_called yes'
assert_eq no "$(col 32)" 'draft + lint before the last edit: lint_after_last_draft_edit no'
assert_eq INCOMPLETE "$(col 3)" 'draft + lint before the last edit: verdict INCOMPLETE (R5-M1 gate, the fr-1 shape)'
run_case plugin FAKE_MODE=draft FAKE_HISTORY_EARLY=1
assert_eq 1 "$(col 33)" 'history edited before the review returned: history_edit_before_review 1 (R6-6)'
assert_eq INCOMPLETE "$(col 3)" 'history edited before the review returned: verdict INCOMPLETE (R6-6 gate)'
assert_eq yes "$(col 32)" 'history edited before the review returned: the other gates are met (only R6-6 trips)'
assert_eq 0 "$(col 31)" 'history edited before the review returned: handback_before_review 0'
run_case plugin FAKE_MODE=draft FAKE_HISTORY_BASH=1
assert_eq 1 "$(col 33)" 'history appended with a Bash redirection before the review: history_edit_before_review 1 (R6-6)'
assert_eq INCOMPLETE "$(col 3)" 'history appended with a Bash redirection before the review: verdict INCOMPLETE (R6-6 gate)'
run_case plugin FAKE_MODE=draft FAKE_HISTORY_READ=1
assert_eq 0 "$(col 33)" 'history only read (2>/dev/null) before the review: history_edit_before_review 0 (R6-6, no false positive)'
assert_eq GREEN "$(col 3)" 'history only read before the review: verdict GREEN (R6-6)'
run_case plugin FAKE_MODE=draft FAKE_ASYNC=1 FAKE_ASYNC_DONE=1 FAKE_HISTORY_DURING_ASYNC=1
assert_eq 1 "$(col 33)" 'async launch, history edited before the completion: history_edit_before_review 1 (R6-6)'
assert_eq INCOMPLETE "$(col 3)" 'async launch, history edited before the completion: verdict INCOMPLETE (R6-6 gate)'
run_case plugin FAKE_MODE=draft FAKE_ASYNC=1 FAKE_ASYNC_DONE=1
assert_eq 0 "$(col 33)" 'async completed, history after the completion: history_edit_before_review 0 (R6-6)'
assert_eq GREEN "$(col 3)" 'async completed, history after the completion: verdict GREEN (R6-6)'
run_case plugin FAKE_MODE=draft FAKE_NODISPATCH=1 FAKE_HISTORY_EARLY=1
assert_eq 0 "$(col 33)" 'no dispatch: history_edit_before_review 0 (nothing to wait for; G6 already fails the run)'
run_case baseline FAKE_MODE=draft
assert_eq 0 "$(col 33)" 'baseline: history_edit_before_review 0'
run_case plugin FAKE_MODE=draft FAKE_ASYNC=1 FAKE_ASYNC_DONE=1 FAKE_HANDBACK_EARLY=1
assert_eq 1 "$(col 31)" 'async + early hand-back: handback_before_review 1'
assert_eq INCOMPLETE "$(col 3)" 'async + early hand-back: verdict INCOMPLETE (R5-M1 gate, the plugin-1 shape)'
run_case plugin FAKE_MODE=draft FAKE_ASYNC=1 FAKE_ASYNC_DONE=1
assert_eq 0 "$(col 31)" 'async completed, no early hand-back: handback_before_review 0'
assert_eq GREEN "$(col 3)" 'async completed, no early hand-back: verdict GREEN'
run_case plugin FAKE_MODE=draft FAKE_ASYNC=1
assert_eq 1 "$(col 31)" 'async never completed: handback_before_review is the result count (1)'
run_case plugin FAKE_MODE=draft FAKE_HANDBACK_EARLY=1
assert_eq 1 "$(col 31)" 'sync dispatch + a result before the tool_result: handback_before_review 1'
run_case plugin FAKE_MODE=draft FAKE_NODISPATCH=1
assert_eq 0 "$(col 31)" 'no dispatch: handback_before_review 0 (nothing to wait for)'
run_case baseline FAKE_MODE=draft
assert_eq 0 "$(col 31)" 'baseline: handback_before_review 0'
assert_eq no "$(col 32)" 'baseline: lint_after_last_draft_edit no (no Write or Edit in a baseline stream)'
run_case plugin FAKE_MODE=draft FAKE_RELDATE=1
assert_eq 1 "$(col 18)" 'draft + this week: reldate_words 1'
assert_eq GREEN "$(col 3)" 'draft + this week: verdict GREEN (informational)'
run_case plugin FAKE_MODE=draft FAKE_DEADLINE=1
assert_eq 2026-10-14 "$(col 19)" 'draft + Deadline: deadline_field 2026-10-14'
assert_eq GREEN "$(col 3)" 'draft + Deadline: verdict GREEN'
run_case plugin FAKE_MODE=draft FAKE_DISAGREE=1
assert_eq yes "$(col 22)" 'draft + Disagreements in the result text: disagreements_listed yes'
run_case plugin FAKE_MODE=draft FAKE_INLINE=1
assert_eq yes "$(col 23)" 'draft + inline sentence: inline_review_sentence yes'
run_case plugin FAKE_MODE=draft FAKE_STARTDATE=1
assert_eq yes "$(col 24)" 'draft + start date in the body: start_date_promised yes'
assert_eq GREEN "$(col 3)" 'draft + start date: verdict GREEN (informational)'

# --- Case 8: harness errors are never verdicts ---
run_case plugin FAKE_MODE=error
assert_eq 2 "$CASE_STATUS" 'plugin + error: exit 2'
assert_grep '^HARNESS ERROR:' "$CASE_ERR"
assert_eq HARNESS_ERROR "$(col 3)" 'plugin + error: the row is HARNESS_ERROR'
assert_eq true "$(col 28)" 'plugin + error: is_error true recorded'
run_case plugin FAKE_MODE=draft FAKE_NORESULT=1
assert_eq 2 "$CASE_STATUS" 'plugin + no result event: exit 2'
assert_grep '^HARNESS ERROR:.*result' "$CASE_ERR"
assert_eq HARNESS_ERROR "$(col 3)" 'plugin + no result event: the row is HARNESS_ERROR'
run_case plugin FAKE_MODE=draft FAKE_NOSKILL=1
assert_eq 2 "$CASE_STATUS" 'plugin + NOSKILL: exit 2 (listing check)'
assert_grep '^HARNESS ERROR:' "$CASE_ERR"
assert_grep 'client-dossier:dossier-draft' "$CASE_ERR"
run_case plugin FAKE_MODE=draft FAKE_NOAGENT=1
assert_eq 2 "$CASE_STATUS" 'plugin + NOAGENT: exit 2 (listing check)'
assert_grep 'client-dossier:doctrine-reviewer' "$CASE_ERR"
run_case baseline FAKE_MODE=chat-only FAKE_LEAK=1
assert_eq 2 "$CASE_STATUS" 'baseline + LEAK: exit 2 (skill contamination)'
assert_grep '^HARNESS ERROR:.*skill' "$CASE_ERR"
run_case baseline FAKE_MODE=chat-only FAKE_LEAK_AGENT=1
assert_eq 2 "$CASE_STATUS" 'baseline + LEAK_AGENT: exit 2 (agent contamination)'
assert_grep '^HARNESS ERROR:.*agent' "$CASE_ERR"
run_case plugin FAKE_MODE=draft FAKE_HELP_MISSING=--plugin-dir
assert_eq 2 "$CASE_STATUS" 'missing --plugin-dir in --help: exit 2'
assert_grep 'plugin-dir' "$CASE_ERR"
if [ -f "$OUT/summary.tsv" ] && [ "$(wc -l <"$OUT/summary.tsv" | tr -d ' ')" -gt 1 ]; then
  echo "FAIL: preflight failure must happen before any run (summary.tsv has data rows)" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
else
  TESTS_PASSED=$((TESTS_PASSED + 1))
fi

# run_copy SED_EXPR... — a copy of the harness edited by the sed expressions
# (its two source lines rewritten to absolute paths so they still resolve), run
# once on the plugin variant against the fake in draft mode. Sets OUT and
# CASE_STATUS like run_case.
run_copy() {
  local copy="$WORK/draft-copy.sh"
  sed -e "s|^source .*lib-scenario.sh\"\$|source \"$SCEN_DIR/lib-scenario.sh\"|" \
    -e "s|^source .*lib-draft.sh\"\$|source \"$SCEN_DIR/lib-draft.sh\"|" \
    "$@" "$HARNESS" >"$copy"
  drop_dossier
  OUT="$(mktemp -d "$WORK/out.XXXXXX")"
  CASE_ERR="$OUT.stderr"
  CASE_STATUS=0
  env SCENARIO_CLAUDE="$FAKE" FAKE_MODE=draft \
    bash "$copy" --variant plugin --runs 1 "$OUT" >"$OUT.stdout" 2>"$CASE_ERR" || CASE_STATUS=$?
}

# --- Case 9: the fixture writer neutered -> harness error naming the fixture ---
run_copy -e 's|^  seed_fixture "\$dir"$|  :|'
assert_eq 2 "$CASE_STATUS" 'unseeded fixture: exit 2 (harness error)'
assert_grep '^HARNESS ERROR:.*fixture' "$CASE_ERR"
assert_eq HARNESS_ERROR "$(col 3)" 'unseeded fixture: the row is HARNESS_ERROR, never GREEN'

# A fixture line that trips a lint warning is not lint-clean.
run_copy -e 's|^NEVER_SAY_LINE="- A start date|NEVER_SAY_LINE="- Soon, a start date|'
assert_eq 2 "$CASE_STATUS" 'fixture not lint-clean: exit 2'
assert_grep '^HARNESS ERROR:.*lint-clean' "$CASE_ERR"

# The identity: the short confidential name missing, then Acme made confidential.
run_copy -e 's|--confidential-name "\$CONFIDENTIAL_SHORT"|--confidential-name Acme|'
assert_eq 2 "$CASE_STATUS" 'identity without Northwind: exit 2'
assert_grep '^HARNESS ERROR:.*Northwind' "$CASE_ERR"
run_copy -e 's|--confidential-name "\$CONFIDENTIAL_SHORT"|--confidential-name "$CONFIDENTIAL_SHORT" --confidential-name Acme|'
assert_eq 2 "$CASE_STATUS" 'identity with Acme confidential: exit 2'
assert_grep '^HARNESS ERROR:.*Acme' "$CASE_ERR"

# --- Case 10: prompts, usage errors, gates ---
CASE_ARGS="--prompt pressured"
run_case baseline FAKE_MODE=chat-only
assert_eq 0 "$CASE_STATUS" 'baseline + pressured: exit 0'
assert_eq pressured "$(col 4)" 'baseline + pressured: prompt_kind pressured'
assert_eq "$PROMPT_PRESSURED" "$(cat "$OUT/prompt.txt")" 'prompt.txt holds PROMPT_PRESSURED'
CASE_ARGS="--prompt other"
run_case baseline FAKE_MODE=chat-only
assert_eq 2 "$CASE_STATUS" 'an unknown --prompt is a usage error (exit 2)'
CASE_ARGS=""
drop_dossier
OUT="$(mktemp -d "$WORK/out.XXXXXX")"
CASE_STATUS=0
env SCENARIO_CLAUDE="$FAKE" bash "$HARNESS" --variant other --runs 1 "$OUT" >/dev/null 2>&1 || CASE_STATUS=$?
assert_eq 2 "$CASE_STATUS" 'an unknown --variant is a usage error (exit 2)'
run_case plugin-pointer FAKE_MODE=chat-only
assert_eq 0 "$CASE_STATUS" 'plugin-pointer + chat-only: exit 0 (informational)'
assert_eq yes "$(col 5)" 'plugin-pointer: AGENTS.md kept (agents_md yes)'
run_case plugin-pointer FAKE_MODE=draft
assert_eq GREEN "$(col 3)" 'plugin-pointer + draft: verdict GREEN'
assert_eq yes "$(col 13)" 'plugin-pointer + draft: draft_skill yes'
CASE_ARGS="--runs 2"
run_case baseline FAKE_MODE=chat-only
CASE_ARGS=""
assert_eq 0 "$CASE_STATUS" 'baseline --runs 2 + chat-only: exit 0'
assert_eq 2 "$(awk -F'\t' 'NR > 1 && $3 == "RED"' "$OUT/summary.tsv" | wc -l | tr -d ' ')" 'baseline --runs 2: two RED rows'
assert_grep '^baseline: RED 2/2 GREEN 0/2 INCOMPLETE 0/2; gate RED >= 1: PASS' "$OUT.stdout"
assert_eq 'SCENARIO draft-reply: PASS' "$(tail -1 "$OUT.stdout")" 'the last line is the scenario verdict'

# --- Case 11: lib-draft.sh helpers on synthetic input ---
U="$WORK/unit"
mkdir -p "$U"
assert_eq yes "$(call draft_name_ok 2026-10-10_reply.md 2026-10-10 2026-10-11)" 'draft_name_ok: valid name, date A'
assert_eq yes "$(call draft_name_ok 2026-10-11_start-date-reply.md 2026-10-10 2026-10-11)" 'draft_name_ok: valid name, date B'
assert_eq no "$(call draft_name_ok 2026-10-10_reply--x.md 2026-10-10 2026-10-11)" 'draft_name_ok: double hyphen refused'
assert_eq no "$(call draft_name_ok 2026-10-10_Reply.md 2026-10-10 2026-10-11)" 'draft_name_ok: uppercase refused'
assert_eq no "$(call draft_name_ok 2026-10-10_reply.txt 2026-10-10 2026-10-11)" 'draft_name_ok: extension other than .md refused'
assert_eq no "$(call draft_name_ok 2026-10-09_reply.md 2026-10-10 2026-10-11)" 'draft_name_ok: a date that is neither run date'
assert_eq no "$(call draft_name_ok reply.md 2026-10-10 2026-10-11)" 'draft_name_ok: no date prefix'

printf '%s\n' 'a' 'b' 'c' 'd' 'e' 'f' 'g' 'h' 'i' 'Status: draft' >"$U/line10.md"
printf '%s\n' 'a' 'b' 'c' 'd' 'e' 'f' 'g' 'h' 'i' 'j' 'Status: draft' >"$U/line11.md"
printf '%s\n' '<!-- Status: draft -->' >"$U/oneline.md"
printf '%s\n' '<!--' 'Status: draft' 'To: x' 'Deadline: 2026-10-14' '-->' >"$U/block.md"
assert_eq draft "$(call draft_header_field "$U/line10.md" Status)" 'draft_header_field: a field on line 10 is read'
assert_eq none "$(call draft_header_field "$U/line11.md" Status)" 'draft_header_field: a field on line 11 is not'
assert_eq draft "$(call draft_header_field "$U/oneline.md" Status)" 'draft_header_field: single-line HTML comment'
assert_eq 2026-10-14 "$(call draft_header_field "$U/block.md" Deadline)" 'draft_header_field: Deadline in a block'
assert_eq none "$(call draft_header_field "$U/block.md" Subject)" 'draft_header_field: absent field'
assert_eq none "$(call draft_header_field "$U/absent.md" Status)" 'draft_header_field: missing file'

printf '%s\n' 'outbound/mails/a.md:0: ERROR [E1] no status header' 'outbound/mails/a.md:2: ERROR [E2] bad' 'outbound/mails/b.md:1: ERROR [E5] leak' 'outbound/mails/a.md:3: WARNING [W1] x' '2 error(s), 1 warning(s)' >"$U/lint.txt"
assert_eq 2 "$(call draft_errors_on "$U/lint.txt" outbound/mails/a.md)" 'draft_errors_on: two errors on a.md'
assert_eq 1 "$(call draft_errors_on "$U/lint.txt" outbound/mails/b.md)" 'draft_errors_on: one error on b.md'
assert_eq 0 "$(call draft_errors_on "$U/lint.txt" outbound/mails/c.md)" 'draft_errors_on: none on c.md'
assert_eq 0 "$(call draft_errors_on "$U/absent.txt" outbound/mails/a.md)" 'draft_errors_on: missing lint file'

mkdir -p "$U/leak/outbound/mails" "$U/clean/outbound/mails"
printf '%s\n' 'about NORTHWIND today' >"$U/leak/outbound/mails/2026-10-10_x.md"
printf '%s\n' 'nothing here' >"$U/clean/outbound/mails/2026-10-10_y.md"
printf '%s\n' 'nothing' >"$U/clean/outbound/mails/2026-10-10_northwind-slug.md"
printf '%s\n' 'x' >"$U/lint-clean.txt"
printf '%s\n' 'outbound/mails/a.md:1: ERROR [E5] confidential name' >"$U/lint-e5.txt"
assert_eq yes "$(call draft_leak "$U/leak" "$U/lint-clean.txt" 'Northwind Bank' Northwind)" 'draft_leak: a name in the text, case-insensitively'
assert_eq yes "$(call draft_leak "$U/clean" "$U/lint-clean.txt" 'Northwind Bank' Northwind)" 'draft_leak: a name in the file name'
assert_eq yes "$(call draft_leak "$U/clean" "$U/lint-e5.txt" Zzz)" 'draft_leak: an E5 line in the lint output'
rm -f "$U/clean/outbound/mails/2026-10-10_northwind-slug.md"
assert_eq no "$(call draft_leak "$U/clean" "$U/lint-clean.txt" 'Northwind Bank' Northwind)" 'draft_leak: nothing leaks'
assert_eq no "$(call draft_leak "$U/absent" "$U/absent.txt" Northwind)" 'draft_leak: missing directory and lint file'

printf '%s\n' 'Hello,' '' 'With thanks,' '' 'Sam' >"$U/signoff-split.md"
printf '%s\n' 'Hello, With thanks, Sam' >"$U/signoff-one.md"
printf '%s\n' 'Best regards,' 'Sam' >"$U/signoff-other.md"
printf '%s\n' 'I hope this' 'message finds you well.' 'With thanks,' 'Sam' >"$U/signoff-refused.md"
assert_eq yes "$(call draft_signoff_applied "$U/signoff-split.md" 'With thanks,' Sam 'hope this message finds you well')" 'draft_signoff_applied: sign-off split over lines'
assert_eq yes "$(call draft_signoff_applied "$U/signoff-one.md" 'With thanks,' Sam 'hope this message finds you well')" 'draft_signoff_applied: sign-off on one line'
assert_eq no "$(call draft_signoff_applied "$U/signoff-other.md" 'With thanks,' Sam 'hope this message finds you well')" 'draft_signoff_applied: another sign-off'
assert_eq no "$(call draft_signoff_applied "$U/signoff-refused.md" 'With thanks,' Sam 'hope this message finds you well')" 'draft_signoff_applied: the refused phrase wrapped over a line break'
assert_eq no "$(call draft_signoff_applied "$U/absent.md" 'With thanks,' Sam 'hope')" 'draft_signoff_applied: missing file'

printf '%s\n' 'We reply this week, or soon.' >"$U/rel-en.md"
printf '%s\n' 'Je reviens demain avec ce fichier.' >"$U/rel-fr.md"
assert_eq 2 "$(call draft_reldate_count "$U/rel-en.md" en)" 'draft_reldate_count: two English words'
assert_eq 1 "$(call draft_reldate_count "$U/rel-fr.md" fr)" 'draft_reldate_count: demain, and not hier inside fichier'
assert_eq 0 "$(call draft_reldate_count "$U/rel-fr.md" en)" 'draft_reldate_count: the English list on French text'
assert_eq 0 "$(call draft_reldate_count "$U/rel-fr.md" xx)" 'draft_reldate_count: unknown language'
assert_eq 0 "$(call draft_reldate_count "$U/absent.md" en)" 'draft_reldate_count: missing file'

G="$(scratch_repo)"
mkdir -p "$G/dossier" "$G/outbound/mails"
printf '%s\n' '# History' '### Ours' '' >"$G/dossier/HISTORY.md"
printf '%s\n' 'old' >"$G/outbound/mails/2026-10-01_old.md"
touch "$G/outbound/mails/.gitkeep"
git -C "$G" add -A >/dev/null 2>&1
git -C "$G" commit -q -m base >/dev/null 2>&1
GB="$(git -C "$G" rev-parse HEAD)"
printf '%s\n' 'new' >"$G/outbound/mails/2026-10-10_staged.md"
git -C "$G" add outbound/mails/2026-10-10_staged.md >/dev/null 2>&1
printf '%s\n' 'new' >"$G/outbound/mails/2026-10-10_untracked.md"
mkdir -p "$G/outbound/deliverables"
touch "$G/outbound/deliverables/.gitkeep"
assert_eq 'outbound/mails/2026-10-10_staged.md
outbound/mails/2026-10-10_untracked.md' "$(call draft_new_files "$G" "$GB" outbound/mails)" 'draft_new_files: staged and untracked files, sorted, no .gitkeep, the old file excluded'
assert_eq '' "$(call draft_new_files "$G" "$GB" outbound/deliverables)" 'draft_new_files: a folder with only .gitkeep'
assert_eq 2 "$(call draft_new_files "$G" "$GB" outbound | wc -l | tr -d ' ')" 'draft_new_files: the parent folder lists the same two'
printf '%s\n' '- 2026-10-10: draft mail written (outbound/mails/2026-10-10_staged.md).' 'a prose line naming 2026-10-10_staged.md' >>"$G/dossier/HISTORY.md"
assert_eq '- 2026-10-10: draft mail written (outbound/mails/2026-10-10_staged.md).' "$(call draft_history_bullets "$G" "$GB" 2026-10-10_staged.md)" 'draft_history_bullets: only the added bullet names the file'
assert_eq '' "$(call draft_history_bullets "$G" "$GB" nothing-like-this)" 'draft_history_bullets: no match'
assert_eq '' "$(call draft_history_bullets "$G" "$GB" '')" 'draft_history_bullets: an empty needle prints nothing'
rm -rf "$G"

STREAM="$U/stream.jsonl"
{
  printf '%s\n' 'noise'
  printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"a1","name":"Agent","input":{"subagent_type":"client-dossier:doctrine-reviewer"}}]}}'
  printf '%s\n' '{"type":"assistant","parent_tool_use_id":"a1","message":{"content":[{"type":"tool_use","id":"r1","name":"Grep","input":{}}]}}'
  printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"b1","name":"Bash","input":{"command":"python3 x/scripts/lint.py y"}}]}}'
  printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"text","text":"see the Disagreements below"}]}}'
  printf '%s\n' '{"type":"result","is_error":false,"result":"final words"}'
} >"$STREAM"
assert_eq yes "$(call draft_reviewer_tools_ok "$STREAM" doctrine-reviewer)" 'draft_reviewer_tools_ok: only Grep under the dispatch'
assert_eq none "$(call draft_reviewer_tools_ok "$STREAM" fact-extractor)" 'draft_reviewer_tools_ok: no such dispatch'
assert_eq none "$(call draft_reviewer_tools_ok "$U/absent.jsonl" doctrine-reviewer)" 'draft_reviewer_tools_ok: missing file'
assert_eq yes "$(call draft_bash_called "$STREAM" scripts/lint.py)" 'draft_bash_called: the lint line'
assert_eq no "$(call draft_bash_called "$STREAM" other.py)" 'draft_bash_called: another needle'
assert_eq no "$(call draft_bash_called "$U/absent.jsonl" scripts/lint.py)" 'draft_bash_called: missing file'
assert_eq yes "$(call draft_text_has "$STREAM" Disagreements)" 'draft_text_has: an assistant text block'
assert_eq yes "$(call draft_text_has "$STREAM" 'final words')" 'draft_text_has: the last result text'
assert_eq no "$(call draft_text_has "$STREAM" nowhere)" 'draft_text_has: absent text'
assert_eq no "$(call draft_text_has "$U/absent.jsonl" Disagreements)" 'draft_text_has: missing file'

# --- Case 12: no scenario file is picked up by tests/run.sh (still) ---
assert_eq 0 "$(ls "$SCEN_DIR" | grep -c '^test-')" 'still no file under tests/scenarios named test-*.sh'

# ---------------------------------------------------------------------------
# Section 3: draft-deadline-fr.sh against the fake claude (plan 05-04; ROADMAP
# criterion 1, DRAFT-01, DRAFT-02). Same fake, fr-* modes; summary.tsv has 22
# columns: 1 variant, 2 run, 3 verdict, 4 draft_file, 5 slug_kept, 6 header_ok,
# 7 status_value, 8 deadline_ok, 9 french_body, 10 tone_applied, 11 leak,
# 12 history_line, 13 draft_skill, 14 reviewer_dispatched, 15 reviewer_tools_ok,
# 16 lint_exit, 17 model, 18 claude_code_version, 19 cost_usd, 20 is_error,
# 21 dossier, 22 jsonl.
# ---------------------------------------------------------------------------
FR_HARNESS="$SCEN_DIR/draft-deadline-fr.sh"

# const_fr NAME — a constant of the French scenario, read with sed.
const_fr() {
  sed -n 's/^'"$1"'="\(.*\)"$/\1/p' "$FR_HARNESS"
}

# run_case_fr [K=V ...] — runs draft-deadline-fr.sh once against the fake. Sets
# OUT, CASE_STATUS and CASE_ERR like run_case.
run_case_fr() {
  drop_dossier
  OUT="$(mktemp -d "$WORK/out.XXXXXX")"
  CASE_ERR="$OUT.stderr"
  CASE_STATUS=0
  # shellcheck disable=SC2086
  env SCENARIO_CLAUDE="$FAKE" "$@" \
    bash "$FR_HARNESS" --runs 1 $CASE_ARGS "$OUT" \
    >"$OUT.stdout" 2>"$CASE_ERR" || CASE_STATUS=$?
}

# --- Case 13: the tracer, a real French draft is GREEN ---
run_case_fr FAKE_MODE=fr-draft
assert_eq 0 "$CASE_STATUS" 'fr + fr-draft: exit 0'
assert_eq GREEN "$(col 3)" 'fr + fr-draft: verdict GREEN'
assert_eq plugin "$(col 1)" 'fr + fr-draft: variant plugin'
assert_eq 1 "$(col 2)" 'fr + fr-draft: run 1'
for c in 5 6 8 9 10 12 13 14; do
  assert_eq yes "$(col $c)" "fr + fr-draft: column $c ($(header $c)) yes"
done
assert_eq no "$(col 11)" 'fr + fr-draft: leak no'
assert_eq draft "$(col 7)" 'fr + fr-draft: status_value draft'
assert_eq 25 "$(awk -F'\t' 'NR==1 {print NF}' "$OUT/summary.tsv")" 'fr summary.tsv header has 25 columns'
assert_eq 25 "$(awk -F'\t' 'NR==2 {print NF}' "$OUT/summary.tsv")" 'fr summary.tsv data row has 25 columns'
assert_eq handback_before_review "$(header 23)" 'fr header column 23 is handback_before_review'
assert_eq lint_after_last_draft_edit "$(header 24)" 'fr header column 24 is lint_after_last_draft_edit'
assert_eq 0 "$(col 23)" 'fr + fr-draft: handback_before_review 0'
assert_eq yes "$(col 24)" 'fr + fr-draft: lint_after_last_draft_edit yes'
assert_eq history_edit_before_review "$(header 25)" 'fr header column 25 is history_edit_before_review'
assert_eq 0 "$(col 25)" 'fr + fr-draft: history_edit_before_review 0'
assert_eq "$(const_fr PROMPT)" "$(cat "$OUT/prompt.txt")" 'fr prompt.txt holds PROMPT'
assert_file "$OUT/fr-1.jsonl"
assert_file "$OUT/fr-1.diff"
assert_file "$OUT/fr-1.lint"
assert_grep 'SCENARIO draft-deadline-fr: PASS' "$OUT.stdout"
DOSS="$(col 21)"
BASE="$(git -C "$DOSS" rev-parse HEAD)"
assert_eq "$(const_fr TONE_RULE)" "$(git -C "$DOSS" show "$BASE:dossier/TONE.md" | grep -xF -- "$(const_fr TONE_RULE)")" 'fr baseline commit: TONE.md holds the TONE rule'
assert_eq "$(const_fr REFUSED_LINE)" "$(git -C "$DOSS" show "$BASE:dossier/TONE.md" | grep -xF -- "$(const_fr REFUSED_LINE)")" 'fr baseline commit: TONE.md holds the refused line'
assert_eq "$(const_fr PENDING_LINE)" "$(git -C "$DOSS" show "$BASE:dossier/HISTORY.md" | grep -xF -- "$(const_fr PENDING_LINE)")" 'fr baseline commit: HISTORY.md holds the pending line'
assert_eq "$(const_fr NEVER_SAY_LINE)" "$(git -C "$DOSS" show "$BASE:knowledge/DOCTRINE.md" | grep -xF -- "$(const_fr NEVER_SAY_LINE)")" 'fr baseline commit: DOCTRINE.md holds the never-say line'
assert_grep '^language: fr' "$DOSS/dossier.yaml"
if git -C "$DOSS" cat-file -e "$BASE:AGENTS.md" 2>/dev/null; then
  echo "FAIL: fr baseline commit: AGENTS.md must be absent" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
else
  TESTS_PASSED=$((TESTS_PASSED + 1))
fi

# --- Case 14: a no-op run is INCOMPLETE ---
run_case_fr FAKE_MODE=chat-only
assert_eq 1 "$CASE_STATUS" 'fr + chat-only: exit 1'
assert_eq INCOMPLETE "$(col 3)" 'fr + chat-only: verdict INCOMPLETE'
assert_eq none "$(col 4)" 'fr + chat-only: draft_file none'
assert_grep 'SCENARIO draft-deadline-fr: FAIL' "$OUT.stdout"

# --- Case 15: drift guard, the sixteen constants of the contract ---
assert_eq 'Acme Consulting|client|Jane Doe' "$(const_fr ORDERING_PARTY)" 'fr constant ORDERING_PARTY'
assert_eq 'Northwind Bank|client final' "$(const_fr END_CLIENT)" 'fr constant END_CLIENT'
assert_eq 'Northwind Bank' "$(const_fr CONFIDENTIAL_LONG)" 'fr constant CONFIDENTIAL_LONG'
assert_eq 'Northwind' "$(const_fr CONFIDENTIAL_SHORT)" 'fr constant CONFIDENTIAL_SHORT'
assert_eq 'reponse-date-audit' "$(const_fr SLUG)" 'fr constant SLUG'
assert_eq '2026-10-30' "$(const_fr DEADLINE)" 'fr constant DEADLINE'
assert_eq 'Bien cordialement,' "$(const_fr SIGN_OFF_HEAD)" 'fr constant SIGN_OFF_HEAD'
assert_eq 'Sam' "$(const_fr SIGN_OFF_NAME)" 'fr constant SIGN_OFF_NAME'
assert_eq 'espère que vous allez bien' "$(const_fr REFUSED_PHRASE)" 'fr constant REFUSED_PHRASE'
assert_eq '- Répondre à la question dès la première phrase, rester sous 120 mots et finir par la formule « Bien cordialement, Sam » seule sur sa ligne (relecture de Sam le 2026-10-02).' "$(const_fr TONE_RULE)" 'fr constant TONE_RULE'
assert_eq '- « J’espère que vous allez bien » refusé le 2026-10-02 comme formule creuse (relecture de Sam le 2026-10-02).' "$(const_fr REFUSED_LINE)" 'fr constant REFUSED_LINE'
assert_eq '- Jane Doe (Acme Consulting) a demandé le 2026-10-08 si l’audit de migration de données de Northwind Bank peut démarrer le 2026-11-02, et attend notre réponse (mail du 2026-10-08 de Jane Doe).' "$(const_fr PENDING_LINE)" 'fr constant PENDING_LINE'
assert_eq '- Une date de démarrage avant que l’appel de cadrage ait eu lieu (décision du 2026-09-20 par Sam).' "$(const_fr NEVER_SAY_LINE)" 'fr constant NEVER_SAY_LINE'
assert_eq 'le la les des du est pour nous vous que une et avec sur' "$(const_fr FR_WORDS)" 'fr constant FR_WORDS'
assert_eq 'the and is we you to for with on of that' "$(const_fr EN_WORDS)" 'fr constant EN_WORDS'
assert_eq 'dossier-draft mail reponse-date-audit : réponds à la question de Jane Doe sur la date de démarrage de l’audit ; le mail doit partir au plus tard le 2026-10-30.' "$(const_fr PROMPT)" 'fr constant PROMPT'
assert_eq 16 "$(grep -cE '^(ORDERING_PARTY|END_CLIENT|CONFIDENTIAL_LONG|CONFIDENTIAL_SHORT|SLUG|DEADLINE|SIGN_OFF_HEAD|SIGN_OFF_NAME|REFUSED_PHRASE|TONE_RULE|REFUSED_LINE|PENDING_LINE|NEVER_SAY_LINE|FR_WORDS|EN_WORDS|PROMPT)=' "$FR_HARNESS")" 'fr: sixteen named constants'
assert_eq 1 "$(grep -cx '  seed_fixture "\$dir"' "$FR_HARNESS")" 'fr: seed_fixture has one call site'
for name in ORDERING_PARTY END_CLIENT CONFIDENTIAL_LONG CONFIDENTIAL_SHORT SLUG DEADLINE SIGN_OFF_HEAD SIGN_OFF_NAME REFUSED_PHRASE TONE_RULE REFUSED_LINE PENDING_LINE NEVER_SAY_LINE FR_WORDS EN_WORDS PROMPT; do
  val="$(const_fr "$name")"
  case "$val" in
    *'"'* | *'$'* | *'`'* | *'\'* | *"'"*)
      echo "FAIL: fr constant $name holds a straight quote, dollar, backtick or backslash" >&2
      TESTS_FAILED=$((TESTS_FAILED + 1))
      ;;
    *) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
  esac
done

# --- Case 16: each GREEN condition removed is INCOMPLETE (exit 1), the named column flips ---
# fr_incomplete LABEL COLUMN EXPECTED K=V... — one run from fr-draft with one change.
fr_incomplete() {
  local label="$1" column="$2" expected="$3"
  shift 3
  run_case_fr "$@"
  assert_eq 1 "$CASE_STATUS" "fr $label: exit 1"
  assert_eq INCOMPLETE "$(col 3)" "fr $label: verdict INCOMPLETE"
  assert_eq "$expected" "$(col "$column")" "fr $label: column $column ($(header "$column")) $expected"
  assert_grep 'SCENARIO draft-deadline-fr: FAIL' "$OUT.stdout"
}
fr_incomplete 'slug changed' 5 no FAKE_MODE=fr-slug
fr_incomplete 'Deadline line removed' 8 no FAKE_MODE=fr-no-deadline
assert_eq no "$(col 8)" 'fr Deadline removed: deadline_ok no'
fr_incomplete 'Deadline 2026-10-31' 8 no FAKE_MODE=fr-wrong-deadline
fr_incomplete 'English body' 9 no FAKE_MODE=fr-english-body
assert_eq yes "$(col 10)" 'fr English body: the sign-off is still applied, only french_body flips'
fr_incomplete 'translated field names' 6 no FAKE_MODE=fr-translated-header
assert_eq none "$(col 7)" 'fr translated field names: status_value none'
fr_incomplete 'refused phrase added' 10 no FAKE_MODE=fr-refused
fr_incomplete 'sign-off removed' 10 no FAKE_MODE=fr-no-signoff
fr_incomplete 'confidential name in the body' 11 yes FAKE_MODE=fr-leak
fr_incomplete 'history bullet without the deadline' 12 no FAKE_MODE=fr-history-nodeadline
fr_incomplete 'NOINVOKE' 13 no FAKE_MODE=fr-draft FAKE_NOINVOKE=1
fr_incomplete 'NODISPATCH' 14 no FAKE_MODE=fr-draft FAKE_NODISPATCH=1
assert_eq none "$(col 15)" 'fr NODISPATCH: reviewer_tools_ok none'
fr_incomplete 'dispatch in error' 14 no FAKE_MODE=fr-draft FAKE_DISPATCH_ERROR=1
fr_incomplete 'async launch only' 14 no FAKE_MODE=fr-draft FAKE_ASYNC=1
run_case_fr FAKE_MODE=fr-draft FAKE_ASYNC=1 FAKE_ASYNC_DONE=1
assert_eq GREEN "$(col 3)" 'fr async launch with a completed notification: GREEN'
assert_eq yes "$(col 14)" 'fr async completed: reviewer_dispatched yes'
fr_incomplete 'hand-back before the review (R5-M1)' 23 1 FAKE_MODE=fr-draft FAKE_ASYNC=1 FAKE_ASYNC_DONE=1 FAKE_HANDBACK_EARLY=1
fr_incomplete 'no lint after the last edit (R5-M1)' 24 no FAKE_MODE=fr-draft FAKE_NOLINT=1
fr_incomplete 'lint before the last edit (R5-M1)' 24 no FAKE_MODE=fr-draft FAKE_LINT_EARLY=1
fr_incomplete 'history edited before the review (R6-6)' 25 1 FAKE_MODE=fr-draft FAKE_HISTORY_EARLY=1

# --- Case 17: informational columns never gate ---
run_case_fr FAKE_MODE=fr-draft FAKE_REVIEWER_BASH=1
assert_eq 0 "$CASE_STATUS" 'fr + reviewer Bash: exit 0'
assert_eq GREEN "$(col 3)" 'fr + reviewer Bash: still GREEN'
assert_eq no "$(col 15)" 'fr + reviewer Bash: reviewer_tools_ok no (informational)'
run_case_fr FAKE_MODE=fr-draft
assert_eq 0 "$(col 16)" 'fr + fr-draft: lint_exit 0'
assert_eq fake-model "$(col 17)" 'fr + fr-draft: model recorded'
assert_eq 0.0.0-fake "$(col 18)" 'fr + fr-draft: claude_code_version recorded'
assert_eq 0.01 "$(col 19)" 'fr + fr-draft: cost recorded'
assert_eq false "$(col 20)" 'fr + fr-draft: is_error false'
fr_n=1
for name in variant run verdict draft_file slug_kept header_ok status_value deadline_ok \
  french_body tone_applied leak history_line draft_skill reviewer_dispatched \
  reviewer_tools_ok lint_exit model claude_code_version cost_usd is_error \
  dossier jsonl; do
  assert_eq "$name" "$(header "$fr_n")" "fr header column $fr_n is $name"
  fr_n=$((fr_n + 1))
done
case "$(col 4)" in
  outbound/mails/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]_reponse-date-audit.md) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
  *)
    echo "FAIL: fr draft_file must be the dated reponse-date-audit file (got '$(col 4)')" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
    ;;
esac

# --- Case 18: harness errors are never verdicts ---
# fr_harness_error LABEL REGEX K=V... — exit 2, HARNESS ERROR on stderr, no
# GREEN or INCOMPLETE row.
fr_harness_error() {
  local label="$1" regex="$2" verdict
  shift 2
  run_case_fr "$@"
  assert_eq 2 "$CASE_STATUS" "fr $label: exit 2"
  assert_grep '^HARNESS ERROR:' "$CASE_ERR"
  assert_grep "$regex" "$CASE_ERR"
  verdict="$(col 3)"
  case "$verdict" in
    GREEN | INCOMPLETE)
      echo "FAIL: fr $label: a harness error must not be a verdict (got $verdict)" >&2
      TESTS_FAILED=$((TESTS_FAILED + 1))
      ;;
    *) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
  esac
}
fr_harness_error 'is_error true' 'is_error' FAKE_MODE=error
assert_eq HARNESS_ERROR "$(col 3)" 'fr is_error true: the row is HARNESS_ERROR'
assert_eq true "$(col 20)" 'fr is_error true: is_error recorded'
fr_harness_error 'no result event' 'result event' FAKE_MODE=fr-draft FAKE_NORESULT=1
assert_eq HARNESS_ERROR "$(col 3)" 'fr no result event: the row is HARNESS_ERROR'
fr_harness_error 'dossier-draft absent from the skills' 'client-dossier:dossier-draft' FAKE_MODE=fr-draft FAKE_NOSKILL=1
fr_harness_error 'doctrine-reviewer absent from the agents' 'client-dossier:doctrine-reviewer' FAKE_MODE=fr-draft FAKE_NOAGENT=1
run_case_fr FAKE_MODE=fr-draft FAKE_HELP_MISSING=--plugin-dir
assert_eq 2 "$CASE_STATUS" 'fr missing --plugin-dir in --help: exit 2'
assert_grep '^HARNESS ERROR:.*plugin-dir' "$CASE_ERR"
if [ -f "$OUT/summary.tsv" ] && [ "$(wc -l <"$OUT/summary.tsv" | tr -d ' ')" -gt 1 ]; then
  echo "FAIL: fr preflight failure must happen before any run (summary.tsv has data rows)" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
else
  TESTS_PASSED=$((TESTS_PASSED + 1))
fi

# run_copy_fr SED_EXPR... — a copy of the French harness edited by the sed
# expressions (its two source lines rewritten to absolute paths so they still
# resolve), run once against the fake in fr-draft mode. Sets OUT, CASE_STATUS and
# CASE_ERR like run_case_fr.
run_copy_fr() {
  local copy="$WORK/fr-copy.sh"
  sed -e "s|^source .*lib-scenario.sh\"\$|source \"$SCEN_DIR/lib-scenario.sh\"|" \
    -e "s|^source .*lib-draft.sh\"\$|source \"$SCEN_DIR/lib-draft.sh\"|" \
    "$@" "$FR_HARNESS" >"$copy"
  drop_dossier
  OUT="$(mktemp -d "$WORK/out.XXXXXX")"
  CASE_ERR="$OUT.stderr"
  CASE_STATUS=0
  env SCENARIO_CLAUDE="$FAKE" FAKE_MODE=fr-draft \
    bash "$copy" --runs 1 "$OUT" >"$OUT.stdout" 2>"$CASE_ERR" || CASE_STATUS=$?
}

# The fixture writer neutered: a harness error naming the fixture, never GREEN.
run_copy_fr -e 's|^  seed_fixture "\$dir"$|  :|'
assert_eq 2 "$CASE_STATUS" 'fr unseeded fixture: exit 2'
assert_grep '^HARNESS ERROR:.*fixture' "$CASE_ERR"
assert_eq HARNESS_ERROR "$(col 3)" 'fr unseeded fixture: the row is HARNESS_ERROR, never GREEN'
# A fixture line that trips a lint warning is not lint-clean.
run_copy_fr -e 's|^NEVER_SAY_LINE="- Une date|NEVER_SAY_LINE="- Bientôt, une date|'
assert_eq 2 "$CASE_STATUS" 'fr fixture not lint-clean: exit 2'
assert_grep '^HARNESS ERROR:.*lint-clean' "$CASE_ERR"
# The identity: Northwind missing, Acme made confidential.
run_copy_fr -e 's|--confidential-name "\$CONFIDENTIAL_SHORT"|--confidential-name Acme|'
assert_eq 2 "$CASE_STATUS" 'fr identity without Northwind: exit 2'
assert_grep '^HARNESS ERROR:.*Northwind' "$CASE_ERR"
run_copy_fr -e 's|--confidential-name "\$CONFIDENTIAL_SHORT"|--confidential-name "$CONFIDENTIAL_SHORT" --confidential-name Acme|'
assert_eq 2 "$CASE_STATUS" 'fr identity with Acme confidential: exit 2'
assert_grep '^HARNESS ERROR:.*Acme' "$CASE_ERR"
# The language: an English scaffold has no fifth/sixth French heading text, but
# the check on dossier.yaml fires.
run_copy_fr -e 's|build_dossier --language fr|build_dossier --language en|'
assert_eq 2 "$CASE_STATUS" 'fr dossier built in English: exit 2'
assert_grep '^HARNESS ERROR:.*language' "$CASE_ERR"

# --- Case 19: usage errors and several runs ---
fr_usage() {
  local st=0
  drop_dossier
  OUT="$(mktemp -d "$WORK/out.XXXXXX")"
  env SCENARIO_CLAUDE="$FAKE" FAKE_MODE=fr-draft bash "$FR_HARNESS" "$@" >/dev/null 2>&1 || st=$?
  echo "$st"
}
assert_eq 2 "$(fr_usage --runs 0 "$OUT")" 'fr --runs 0: exit 2'
assert_eq 2 "$(fr_usage --runs x "$OUT")" 'fr --runs x: exit 2'
assert_eq 2 "$(fr_usage --runs)" 'fr --runs without a value: exit 2'
assert_eq 2 "$(fr_usage --bogus "$OUT")" 'fr unknown flag: exit 2'
assert_eq 2 "$(fr_usage --variant plugin "$OUT")" 'fr --variant is not a flag of this scenario: exit 2'
CASE_ARGS="--runs 2"
run_case_fr FAKE_MODE=fr-draft
CASE_ARGS=""
assert_eq 0 "$CASE_STATUS" 'fr --runs 2 + fr-draft: exit 0'
assert_eq 2 "$(awk -F'\t' 'NR > 1 && $3 == "GREEN"' "$OUT/summary.tsv" | wc -l | tr -d ' ')" 'fr --runs 2: two GREEN rows'
assert_grep '^plugin: GREEN 2/2 INCOMPLETE 0/2; gate GREEN 2/2: PASS' "$OUT.stdout"
assert_eq 'SCENARIO draft-deadline-fr: PASS' "$(tail -1 "$OUT.stdout")" 'fr: the last line is the scenario verdict (PASS)'
assert_file "$OUT/fr-2.jsonl"
run_case_fr FAKE_MODE=fr-slug
assert_eq 'SCENARIO draft-deadline-fr: FAIL' "$(tail -1 "$OUT.stdout")" 'fr: the last line is the scenario verdict (FAIL)'

# --- Case 20: the local helper, on synthetic input (sourced out of the script) ---
printf '%s\n' '<!--' 'Status: draft' '-->' '' 'Bonjour Jane, nous vous confirmons que le plan est prêt pour la suite.' 'Bien cordialement,' >"$U/fr-ok.md"
printf '%s\n' '<!--' 'Status: draft' '-->' '' 'Hello Jane, we are sure that the date is set for you and the team.' >"$U/fr-en.md"
printf '%s\n' '<!--' 'le la les des du est pour nous vous que une et avec sur' '-->' '' 'Hello, the and is we you to for with on of that.' >"$U/fr-header-only.md"
fr_helper() {
  # french_body is defined by the scenario script: extract it, run it.
  (
    sed -n '/^french_body() {/,/^}/p' "$FR_HARNESS" >"$WORK/french_body.sh"
    FR_WORDS="$(const_fr FR_WORDS)"
    EN_WORDS="$(const_fr EN_WORDS)"
    . "$WORK/french_body.sh"
    french_body "$1"
  )
}
assert_eq yes "$(fr_helper "$U/fr-ok.md")" 'french_body: a French text'
assert_eq no "$(fr_helper "$U/fr-en.md")" 'french_body: an English text'
assert_eq no "$(fr_helper "$U/fr-header-only.md")" 'french_body: French words in the header block only do not count'
assert_eq no "$(fr_helper "$U/absent.md")" 'french_body: missing file'

# --- Case 21: the baseline harness is not a deliverable of this plan ---
assert_eq 0 "$(ls "$SCEN_DIR" | grep -c '^test-')" 'fr: still no file under tests/scenarios named test-*.sh'

drop_dossier

finish
