#!/usr/bin/env bash
# tests/test-draft-shapes.sh — DRAFT-01, DRAFT-02, D-02, D-04, D-06: the status block
# and the history lines of skills/dossier-draft/SKILL.md, read out of the file (never a
# copy), have their placeholders substituted and go through the REAL linter in a dossier
# scaffolded by the real init.py. The point: what the skill tells the agent to write is
# what lint.py accepts, and each way of getting it wrong is what lint.py reports.
# Bash 3.2, no arrays. The behavioural proof of the skill is plan 05-05's GREEN run.
set -u

# shellcheck source=./lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SKILL_MD="$REPO_ROOT/skills/dossier-draft/SKILL.md"
WORK="$(mktemp -d)"
TMPS="$WORK"
cleanup() { rm -rf $TMPS; }
trap cleanup EXIT

# --- The substitution map: the only place these values are defined ---
V_RECIPIENT='Ana Ruiz (Fabrikam)'
V_SUBJECT='Start date of the review'
V_DATE='2026-10-12'
V_BODY_1='Hello Ana,'
V_BODY_2='The review can start on 2026-11-09.'
V_KIND='mail'
V_SLUG='start-date-reply'
V_SENDER='Test Runner'
V_FOLDER='mails'
V_FILE='2026-10-12_start-date-reply.md'

assert_file "$SKILL_MD"

# --- Extraction from SKILL.md ---
awk '
  $0 == "```markdown" { on = 1; n = 0; next }
  on && $0 == "```" { on = 0; if (n > 0 && buf[1] == "<!--") { for (i = 1; i <= n; i++) print buf[i]; exit } next }
  on { n++; buf[n] = $0 }
' "$SKILL_MD" >"$WORK/block.tpl" 2>/dev/null
awk '
  $0 == "```text" { on = 1; n = 0; next }
  on && $0 == "```" { on = 0; if (n > 0 && index(buf[1], "- <YYYY-MM-DD>: draft ") == 1) { for (i = 1; i <= n; i++) print buf[i]; exit } next }
  on { n++; buf[n] = $0 }
' "$SKILL_MD" >"$WORK/hist.tpl" 2>/dev/null

if [ -s "$WORK/block.tpl" ] && [ -s "$WORK/hist.tpl" ]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "FAIL: could not extract the status block and the history lines from $SKILL_MD" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# render TEMPLATE_FILE [BODY_TEXT] — the template with every placeholder substituted, on stdout.
# A placeholder left behind is a failure (exit 3).
render() {
  python3 -I - "$1" "$V_RECIPIENT" "$V_SUBJECT" "$V_DATE" "$V_KIND" "$V_SLUG" "$V_SENDER" "$V_FOLDER" "$V_FILE" "${2-$V_BODY_1
$V_BODY_2}" <<'PY'
import re, sys
path, recipient, subject, date, kind, slug, sender, folder, file_, body = sys.argv[1:11]
text = open(path, encoding="utf-8").read()
for key, value in (("<recipient>", recipient), ("<subject>", subject), ("<YYYY-MM-DD>", date),
                   ("<kind>", kind), ("<slug>", slug), ("<sender>", sender),
                   ("<folder>", folder), ("<file>", file_)):
    text = text.replace(key, value)
if "<body>" in text:
    text = text.replace("<body>", "@@BODY@@")
left = re.findall(r"<(?:recipient|subject|YYYY-MM-DD|body|kind|slug|sender|folder|file|ext)>", text)
if left:
    sys.exit("placeholder left after substitution: %s" % left)
sys.stdout.write(text.replace("@@BODY@@", body))
PY
}

# new_dossier LANG — a scratch git repository scaffolded by the real init.py; sets DOSSIER.
new_dossier() {
  DOSSIER="$(scratch_repo)"
  TMPS="$TMPS $DOSSIER"
  python3 "$(init_py)" --target "$DOSSIER" --language "$1" \
    --counterpart 'Fabrikam|client|Ana Ruiz' --confidential-name Contoso >/dev/null 2>&1
  assert_eq '0' "$?" "init.py scaffolds a $1 dossier"
}

# lines_for REL — how many lines of the last lint output start with REL.
lines_for() { printf '%s\n' "$LINT_OUT" | grep -c "^$1" | tr -d ' '; }

# put_draft REL — render the block (default body) into DOSSIER/REL.
put_draft() { render "$WORK/block.tpl" >"$DOSSIER/$1"; }

new_dossier en
assert_lint "$DOSSIER" 0 'the scaffolded en dossier is lint-clean before any draft'
EN="$DOSSIER"

# --- Positive: the block as a mail, with and without Deadline ---
REL="outbound/mails/$V_FILE"
put_draft "$REL"
assert_file "$DOSSIER/$REL"
assert_lint "$DOSSIER" 0 'the status block as a mail is lint-clean'
assert_eq '0' "$(lines_for "$REL")" 'no lint line names the mail'

render "$WORK/block.tpl" | grep -v '^Deadline:' >"$DOSSIER/$REL"
assert_eq '0' "$(grep -c '^Deadline:' "$DOSSIER/$REL")" 'the Deadline line is gone from the variant'
assert_lint "$DOSSIER" 0 'the block without its Deadline line is lint-clean'
assert_eq '0' "$(lines_for "$REL")" 'no lint line names the mail without a deadline'
rm -f "$DOSSIER/$REL"

# --- Positive: a deliverable has no Subject line, .md and .html ---
for ext in md html; do
  REL_D="outbound/deliverables/2026-10-12_scope-note.$ext"
  if [ "$ext" = "html" ]; then
    render "$WORK/block.tpl" "<p>$V_BODY_1</p>
<p>$V_BODY_2</p>" | grep -v '^Subject:' >"$DOSSIER/$REL_D"
  else
    render "$WORK/block.tpl" | grep -v '^Subject:' >"$DOSSIER/$REL_D"
  fi
  assert_eq '0' "$(grep -c '^Subject:' "$DOSSIER/$REL_D")" "the $ext deliverable has no Subject line"
  assert_lint "$DOSSIER" 0 "the block as a .$ext deliverable without Subject is lint-clean"
  assert_eq '0' "$(lines_for "$REL_D")" "no lint line names the .$ext deliverable"
  rm -f "$DOSSIER/$REL_D"
done

# --- Positive: the history lines under the first ### below the second ## of HISTORY.md ---
# insert_history DOSSIER_DIR LASTUPDATED LINE... — python3 -I on fixed strings: the lines go
# under the first ### heading below the second ## heading of dossier/HISTORY.md, the first
# Last updated: line is replaced by LASTUPDATED.
insert_history() {
  python3 -I - "$1/dossier/HISTORY.md" "$2" "${@:3}" <<'PY'
import sys
path, refresh = sys.argv[1:3]
new = sys.argv[3:]
lines = open(path, encoding="utf-8").read().split("\n")
seen_h2 = 0
at = None
for i, line in enumerate(lines):
    if line.startswith("## "):
        seen_h2 += 1
    elif seen_h2 >= 2 and line.startswith("### "):
        at = i
        break
if at is None:
    sys.exit("no ### heading below the second ## heading")
lines[at + 1:at + 1] = [""] + new
for i, line in enumerate(lines):
    if line.startswith("Last updated:"):
        lines[i] = refresh
        break
open(path, "w", encoding="utf-8").write("\n".join(lines))
PY
}
render "$WORK/hist.tpl" >"$WORK/hist.out"
H1="$(sed -n '1p' "$WORK/hist.out")"
H2="$(sed -n '2p' "$WORK/hist.out")"
HU="$(sed -n '3p' "$WORK/hist.out")"
case "$H1" in "- $V_DATE: draft $V_KIND '$V_SLUG' written, to be sent by $V_SENDER, deadline $V_DATE ("*) TESTS_PASSED=$((TESTS_PASSED + 1)) ;; *) echo "FAIL: history line 1 rendered unexpectedly: $H1" >&2; TESTS_FAILED=$((TESTS_FAILED + 1)) ;; esac
case "$HU" in "Last updated: $V_DATE, after the draft $V_KIND '$V_SLUG'") TESTS_PASSED=$((TESTS_PASSED + 1)) ;; *) echo "FAIL: refresh line rendered unexpectedly: $HU" >&2; TESTS_FAILED=$((TESTS_FAILED + 1)) ;; esac
put_draft "$REL"
insert_history "$DOSSIER" "$HU" "$H1" "$H2"
assert_eq '2' "$(grep -c "draft $V_KIND '$V_SLUG' written" "$DOSSIER/dossier/HISTORY.md")" 'both history lines are in HISTORY.md'
assert_lint "$DOSSIER" 0 'the draft plus both history lines is lint-clean'
case "$LINT_OUT" in
  *'0 error(s), 0 warning(s)'*) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
  *) echo "FAIL: lint did not print '0 error(s), 0 warning(s)'; got: $LINT_OUT" >&2; TESTS_FAILED=$((TESTS_FAILED + 1)) ;;
esac

# --- Negative controls: each fresh copy of the substituted mail block gives the finding on its path ---
# SEEN_CODES collects the E-codes the controls produced, so the fallback tie below is computed.
SEEN_CODES=""
# finding_on REL CODE — a lint line starting with REL carries [CODE]; the code is recorded.
finding_on() {
  printf '%s\n' "$LINT_OUT" | grep "^$1" | grep -q "\[$2\]"
}
# neg_case LABEL REL CODE — the draft at DOSSIER/REL was just written by the caller: lint must
# exit 1 with [CODE] on REL; the draft is removed afterwards.
neg_case() {
  assert_lint "$DOSSIER" 1 "$1: lint exits 1"
  finding_on "$2" "$3"
  ok_neg=$?
  if [ "$ok_neg" -eq 0 ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    SEEN_CODES="$SEEN_CODES $3"
  else
    echo "FAIL: $1: no [$3] on $2 in: $LINT_OUT" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
  rm -f "$DOSSIER/$2"
}

DOSSIER="$EN"
R_MAIL="outbound/mails/$V_FILE"

render "$WORK/block.tpl" | grep -v '^Subject:' >"$DOSSIER/$R_MAIL"
neg_case 'a mail without its Subject line gives [E1]' "$R_MAIL" E1

{ i=1; while [ "$i" -le 9 ]; do echo "Preface line $i."; i=$((i + 1)); done; render "$WORK/block.tpl"; } >"$DOSSIER/$R_MAIL"
neg_case 'a status block past line 10 gives [E1]' "$R_MAIL" E1

render "$WORK/block.tpl" | sed 's/^Status: draft$/Status: Draft/' >"$DOSSIER/$R_MAIL"
neg_case 'a capitalised Status: Draft gives [E2]' "$R_MAIL" E2

render "$WORK/block.tpl" | sed 's/^Deadline: .*$/Deadline:/' >"$DOSSIER/$R_MAIL"
neg_case 'an empty Deadline: gives [E3]' "$R_MAIL" E3

render "$WORK/block.tpl" | sed 's/^Deadline: .*$/Deadline: next Friday/' >"$DOSSIER/$R_MAIL"
neg_case 'Deadline: next Friday gives [E3]' "$R_MAIL" E3

R_DOUBLE='outbound/mails/2026-10-12_start--date.md'
render "$WORK/block.tpl" >"$DOSSIER/$R_DOUBLE"
neg_case 'a double hyphen in the file name gives [E4]' "$R_DOUBLE" E4

R_NAME='outbound/mails/2026-10-12_contoso-reply.md'
render "$WORK/block.tpl" >"$DOSSIER/$R_NAME"
neg_case 'a confidential name in the file name gives [E5]' "$R_NAME" E5

render "$WORK/block.tpl" "Hello Ana,
We also work with Contoso." >"$DOSSIER/$R_MAIL"
neg_case 'a confidential name in the body gives [E5]' "$R_MAIL" E5

# --- Documented gap (Pitfall 3): lint accepts a sent status, so the skill sentence is the only guard ---
render "$WORK/block.tpl" | sed 's/^Status: draft$/Status: sent 2026-10-12 by agent session/' >"$DOSSIER/$R_MAIL"
assert_lint "$DOSSIER" 0 'GAP: lint accepts "Status: sent <date> by agent session"; the skill rule is the only guard'
assert_eq '0' "$(lines_for "$R_MAIL")" 'GAP: no lint line names a draft the agent marked as sent (the never-sent sentence of SKILL.md is load-bearing)'
rm -f "$DOSSIER/$R_MAIL"
if tr '\n' ' ' <"$SKILL_MD" | tr -s ' ' | grep -qF 'A new draft is `Status: draft`. Never write `sent` or `reviewed by`: a human sends the message and edits that line.'; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "FAIL: SKILL.md lost the never-sent sentence, the only guard against a draft marked sent" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# --- History control: a relative-date word in the history line is checked (W1) ---
new_dossier en
put_draft "$REL"
H2_SOON="$(printf '%s' "$H2" | sed 's/ (outbound/ soon (outbound/')"
case "$H2_SOON" in *' soon (outbound'*) TESTS_PASSED=$((TESTS_PASSED + 1)) ;; *) echo "FAIL: could not insert the relative-date word into the history line" >&2; TESTS_FAILED=$((TESTS_FAILED + 1)) ;; esac
insert_history "$DOSSIER" "$HU" "$H1" "$H2_SOON"
assert_lint "$DOSSIER" 0 'a relative-date word in a history line is a warning, not an error'
if printf '%s\n' "$LINT_OUT" | grep '^dossier/HISTORY.md' | grep -q 'WARNING \[W1\]'; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "FAIL: no WARNING [W1] on dossier/HISTORY.md for the word 'soon': $LINT_OUT" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# --- French dossier: English keywords, French content ---
new_dossier fr
FR_REL='outbound/mails/2026-10-12_date-demarrage.md'
SAVE_SUBJECT="$V_SUBJECT"
V_SUBJECT='Date de démarrage de la revue'
render "$WORK/block.tpl" "Bonjour Ana,
La revue peut démarrer le 2026-11-09." >"$DOSSIER/$FR_REL"
V_SUBJECT="$SAVE_SUBJECT"
assert_eq '1' "$(grep -c '^Status: draft$' "$DOSSIER/$FR_REL")" 'the French draft keeps the English field name and status value'
assert_eq '1' "$(grep -c '^Subject: Date de démarrage de la revue$' "$DOSSIER/$FR_REL")" 'the French subject is in French'
assert_lint "$DOSSIER" 0 'the French mail is lint-clean'
assert_eq '0' "$(lines_for "$FR_REL")" 'no lint line names the French mail'
FR_H3="$(awk '/^## / { n++; next } n >= 2 && /^### / { print; exit }' "$DOSSIER/dossier/HISTORY.md")"
assert_eq '### Les nôtres' "$FR_H3" 'the first ### below the second ## of the French HISTORY.md is "Les nôtres"'
insert_history "$DOSSIER" "Last updated: 2026-10-12, après le brouillon mail 'date-demarrage'" \
  "- 2026-10-12 : brouillon mail 'date-demarrage' écrit, à envoyer par Test Runner (outbound/mails/2026-10-12_date-demarrage.md)."
assert_eq '1' "$(grep -c "brouillon mail 'date-demarrage' écrit" "$DOSSIER/dossier/HISTORY.md")" 'the French history line is in HISTORY.md'
assert_lint "$DOSSIER" 0 'the French draft plus its French history line is lint-clean'
case "$LINT_OUT" in
  *'0 error(s), 0 warning(s)'*) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
  *) echo "FAIL: the French dossier did not lint at '0 error(s), 0 warning(s)'; got: $LINT_OUT" >&2; TESTS_FAILED=$((TESTS_FAILED + 1)) ;;
esac

# --- Fallback tie: each E-code the skill's fallback names is what a control really produced ---
NOLINT="$(awk '$0 == "## Without the linter" { on = 1; next } on && /^## / { exit } on { print }' "$SKILL_MD")"
for e in E1 E2 E3 E4 E5; do
  assert_eq '1' "$(printf '%s\n' "$NOLINT" | grep -c "^- $e:" | tr -d ' ')" "the fallback section of SKILL.md names $e"
  case " $SEEN_CODES " in
    *" $e "*) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
    *) echo "FAIL: no negative control produced $e (seen:$SEEN_CODES)" >&2; TESTS_FAILED=$((TESTS_FAILED + 1)) ;;
  esac
done

finish
