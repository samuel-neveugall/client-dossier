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
# insert_history DOSSIER_DIR LINE1 LINE2 LASTUPDATED — python3 -I on fixed strings.
insert_history() {
  python3 -I - "$1/dossier/HISTORY.md" "$2" "$3" "$4" <<'PY'
import sys
path, l1, l2, refresh = sys.argv[1:5]
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
lines[at + 1:at + 1] = ["", l1, l2]
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
insert_history "$DOSSIER" "$H1" "$H2" "$HU"
assert_eq '2' "$(grep -c "draft $V_KIND '$V_SLUG' written" "$DOSSIER/dossier/HISTORY.md")" 'both history lines are in HISTORY.md'
assert_lint "$DOSSIER" 0 'the draft plus both history lines is lint-clean'
case "$LINT_OUT" in
  *'0 error(s), 0 warning(s)'*) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
  *) echo "FAIL: lint did not print '0 error(s), 0 warning(s)'; got: $LINT_OUT" >&2; TESTS_FAILED=$((TESTS_FAILED + 1)) ;;
esac

finish
