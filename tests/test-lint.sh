#!/usr/bin/env bash
# tests/test-lint.sh — LINT-01 / LINT-02 / LINT-03: scripts/lint.py finds the
# nearest dossier.yaml (D-01/D-02), types it through the per-field schema
# (D-24, D-25), walks the tree once with sub-dossier pruning (D-03), and
# reports findings in the compiler shape with a stable identifier and a
# 0/1/2 exit code (D-04, D-05). Assertions are on exit code + identifier,
# never on message prose (D-30).
#
# The clean dossier is built here by the real init.py (D-31), never
# hand-written; the error fixtures are copied from it by
# fixtures/make-lint-fixtures.sh (D-29).
set -u

# shellcheck source=./lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

FIXTURE_SCRIPT="$(dirname "${BASH_SOURCE[0]}")/fixtures/make-lint-fixtures.sh"

CLEAN=""
FIXTURES=""
EMPTY=""
READONLY=""
trap 'rm -rf "$CLEAN" "$FIXTURES" "$EMPTY" "$READONLY"' EXIT

# Every identifier the linter can print. A case asserts its own identifier
# fires and every other one stays silent.
ALL_IDS="E1 E2 E3 E4 E5 E6 E7 E8 E9 C1 C0 W1 W2"

# assert_only IDENT LABEL — IDENT fires, no other identifier does.
assert_only() {
  local want="$1" label="$2" ident
  assert_finding "$want" "$label"
  for ident in $ALL_IDS; do
    [ "$ident" = "$want" ] && continue
    assert_no_finding "$ident" "$label"
  done
}

# assert_out_line REGEX LABEL — some line of LINT_OUT matches the ERE.
assert_out_line() {
  local regex="$1" label="$2"
  if printf '%s\n' "$LINT_OUT" | grep -Eq -- "$regex"; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "FAIL: $label (no output line matches /$regex/)" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# assert_last_line EXPECTED LABEL — the summary is the last line (D-04).
assert_last_line() {
  assert_eq "$1" "$(printf '%s\n' "$LINT_OUT" | tail -n 1)" "$2"
}

# --- The linter is an executable script ---
assert_exec "$(lint_py)"

help_status=0
help_out="$(python3 "$(lint_py)" --help 2>&1)" || help_status=$?
assert_eq 0 "$help_status" '--help exits 0'
case "$help_out" in
  *upward*) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
  *) echo "FAIL: --help does not mention the upward walk" >&2; TESTS_FAILED=$((TESTS_FAILED + 1)) ;;
esac

# --- Clean: a dossier freshly scaffolded by init.py lints clean (criterion 1) ---
CLEAN="$(scratch_repo)"
init_status=0
python3 "$(init_py)" --target "$CLEAN" --language en --counterpart 'Acme|ordering party' >/dev/null || init_status=$?
assert_eq 0 "$init_status" 'clean: init.py scaffolds the base dossier'

assert_lint "$CLEAN" 0 'clean: a fresh scaffold exits 0'
assert_last_line '0 error(s), 0 warning(s)' 'clean: summary is 0 error(s), 0 warning(s)'
for ident in $ALL_IDS; do
  assert_no_finding "$ident" 'clean: no finding at all'
done

# --- The fixture generator refuses to run without a clean tree ---
gen_status=0
bash "$FIXTURE_SCRIPT" >/dev/null 2>&1 || gen_status=$?
if [ "$gen_status" -ne 0 ]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "FAIL: make-lint-fixtures.sh with no argument exited 0" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

FIXTURES="$(bash "$FIXTURE_SCRIPT" "$CLEAN")"
assert_dir "$FIXTURES"

# --- E7: a living file lost its Last updated: line (D-13) ---
assert_lint "$FIXTURES/e7" 1 'e7: exits 1'
assert_only E7 'e7: only [E7] fires'
assert_out_line '^dossier/TONE\.md:[0-9]+: ERROR \[E7\] ' 'e7: located on dossier/TONE.md'
assert_last_line '1 error(s), 0 warning(s)' 'e7: exactly one error'

# --- Sub-dossier boundary: a nested dossier is invisible from its parent (D-03) ---
assert_lint "$FIXTURES/sub-dossier" 0 'sub-dossier: the parent exits 0'
assert_last_line '0 error(s), 0 warning(s)' 'sub-dossier: the parent sees none of the nested findings'
assert_lint "$FIXTURES/sub-dossier/clients/other" 1 'sub-dossier: linted directly, it exits 1'
assert_finding E7 'sub-dossier: linted directly, its missing living files fire [E7]'
assert_out_line '^dossier/ACTORS\.md:0: ERROR \[E7\] ' 'sub-dossier: paths are relative to the nearest root'

# --- Byte stability: two runs over one unchanged tree are identical (D-04) ---
for tree in "$CLEAN" "$FIXTURES/sub-dossier/clients/other"; do
  run_one="$(mktemp)"
  run_two="$(mktemp)"
  python3 "$(lint_py)" "$tree" >"$run_one" 2>&1
  python3 "$(lint_py)" "$tree" >"$run_two" 2>&1
  assert_eq '' "$(diff "$run_one" "$run_two" 2>&1)" "byte-stable: two runs identical over $tree"
  rm -f "$run_one" "$run_two"
done

# --- Read-only: a snapshot diffs clean against the tree after a run (T-02-07) ---
# The mechanical proof the linter writes nothing, hence that an interrupted
# run and two parallel runs over one tree are both safe. Built fresh and
# never linted before the snapshot, so even an idempotent write (a file the
# linter would recreate identically on every run) shows up in the diff; the
# mtime probe catches a rewrite with unchanged content.
READONLY="$(scratch_repo)"
python3 "$(init_py)" --target "$READONLY" --language en >/dev/null
mkdir -p "$READONLY/clients/other"
python3 "$(init_py)" --target "$READONLY/clients/other" --language en >/dev/null
snap="$(mktemp -d)"
cp -R "$READONLY" "$snap/tree"
marker="$snap/marker"
: >"$marker"
python3 "$(lint_py)" "$READONLY" >/dev/null 2>&1
python3 "$(lint_py)" "$READONLY/clients/other" >/dev/null 2>&1
assert_eq '' "$(diff -r "$snap/tree" "$READONLY" 2>&1)" 'read-only: the runs added, removed or changed nothing'
assert_eq '' "$(find "$READONLY" -newer "$marker" 2>&1)" 'read-only: the runs touched no mtime'
rm -rf "$snap" "$READONLY"

# --- The walk itself prunes the sub-dossier (D-03) ---
# Pinned directly: until a check reports arbitrary paths (E1/E4/E8, plans
# 02-02 and 02-04), no end-to-end finding can reveal a missed prune.
walk_out="$(python3 -B - "$(lint_py)" "$FIXTURES/sub-dossier" <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("lint", sys.argv[1])
lint = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lint)
tree = lint.walk_tree(sys.argv[2])
for path in tree.files + tree.dirs:
    print(path)
PY
)"
case "$walk_out" in
  *"dossier/TONE.md"*) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
  *) echo "FAIL: walk: the parent's own living files are missing from the walk" >&2; TESTS_FAILED=$((TESTS_FAILED + 1)) ;;
esac
case "$walk_out" in
  *"clients/other/"*|*".git/"*)
    echo "FAIL: walk: descended into the sub-dossier or .git" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
    ;;
  *) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
esac
case "$walk_out" in
  *".gitkeep"*) echo "FAIL: walk: .gitkeep was not dropped" >&2; TESTS_FAILED=$((TESTS_FAILED + 1)) ;;
  *) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
esac

# --- Forged name: a control character in a filename cannot forge a line (T-02-01) ---
# End to end, the real summary is the only summary-shaped line and it is
# last. E4 reports the crafted file, so the escaped `\x0a` is also asserted
# end to end in the E4 section below; the reporter itself is pinned
# directly just below.
assert_lint "$FIXTURES/forged-name" 1 'forged-name: exits 1'
summaries="$(printf '%s\n' "$LINT_OUT" | grep -cE '^[0-9]+ error\(s\), [0-9]+ warning\(s\)$')"
assert_eq 1 "$summaries" 'forged-name: exactly one summary-shaped line'
assert_out_line '^[0-9]+ error\(s\), [0-9]+ warning\(s\)$' 'forged-name: a real summary is printed'
assert_eq "$(printf '%s\n' "$LINT_OUT" | grep -nE '^[0-9]+ error\(s\), [0-9]+ warning\(s\)$' | cut -d: -f1)" \
  "$(printf '%s\n' "$LINT_OUT" | wc -l | tr -d ' ')" 'forged-name: the summary is the last line'

# The reporter, fed the crafted path directly: escaped, never raw. -B keeps
# the import from writing a __pycache__ into scripts/.
forged_out="$(python3 -B - "$(lint_py)" <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("lint", sys.argv[1])
lint = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lint)
lint.report([lint.Finding("outbound/mails/2026-09-17_x\n0 error(s), 0 warning(s)", 0, lint.ERROR, "E4", "probe")])
PY
)"
escaped="$(printf '%s\n' "$forged_out" | grep -c '\\x0a')"
if [ "$escaped" -ge 1 ]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "FAIL: forged-name: the reporter printed the newline raw instead of \\x0a" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi
assert_eq '1 error(s), 0 warning(s)' "$(printf '%s\n' "$forged_out" | tail -n 1)" 'forged-name: the real summary is still last'
assert_eq 2 "$(printf '%s\n' "$forged_out" | wc -l | tr -d ' ')" 'forged-name: one finding line plus the summary, nothing forged'

# --- JSON config: same filename, json branch, same schema (D-25) ---
assert_lint "$FIXTURES/json-config" 0 'json-config: a clean JSON config exits 0'
assert_last_line '0 error(s), 0 warning(s)' 'json-config: zero findings'

# --- Configuration gate (D-24.4): asserted on identifier AND field name ---
# Exit 1 alone cannot tell the correct behaviour (a C1 config error) from
# the bug (silent coercion to true, then an E6 for the empty source): both
# exit 1. So C1 must fire on a line naming the field, and E6 must not.

# count_out_lines ERE — how many LINT_OUT lines match.
count_out_lines() {
  printf '%s\n' "$LINT_OUT" | grep -cE -- "$1"
}

for case_name in c1-yes c1-quoted; do
  assert_lint "$FIXTURES/$case_name" 1 "$case_name: exits 1"
  assert_eq 1 "$(count_out_lines 'ERROR \[C1\] .*consent_recorded')" "$case_name: exactly one [C1] line naming consent_recorded"
  assert_out_line '^dossier\.yaml:[0-9]+: ERROR \[C1\] ' "$case_name: located in dossier.yaml"
  assert_only C1 "$case_name: fails closed -- read as false, so no [E6] follows"
done

assert_lint "$FIXTURES/c1-staleness" 1 'c1-staleness: exits 1'
assert_out_line 'ERROR \[C1\] .*staleness_days' 'c1-staleness: the [C1] line names staleness_days'
assert_only C1 'c1-staleness: only [C1] fires'

assert_lint "$FIXTURES/e6" 1 'e6: exits 1'
assert_out_line '^dossier\.yaml:[0-9]+: ERROR \[E6\] ' 'e6: located at dossier.yaml:<line>'
assert_only E6 'e6: only [E6] fires, no [C1]'

assert_lint "$FIXTURES/consent-ok" 0 'consent-ok: exits 0'
assert_last_line '0 error(s), 0 warning(s)' 'consent-ok: a recorded, sourced consent is clean'

junk_line="$(wc -l <"$FIXTURES/c0-junk/dossier.yaml" | tr -d ' ')"
assert_lint "$FIXTURES/c0-junk" 0 'c0-junk: an unparseable line is a warning, exit 0'
assert_out_line "^dossier\\.yaml:$junk_line: WARNING \\[C0\\] .*$junk_line" 'c0-junk: the [C0] warning names the line number'
assert_only C0 'c0-junk: only [C0] fires'
assert_last_line '0 error(s), 1 warning(s)' 'c0-junk: one warning, zero errors'

# A fresh scaffold raises neither configuration identifier.
assert_lint "$CLEAN" 0 'clean: still exits 0'
assert_no_finding C1 'clean: no [C1]'
assert_no_finding C0 'clean: no [C0]'

# --- E1: an outbound file with no status block in its first 10 lines (D-07) ---
assert_lint "$FIXTURES/e1" 1 'e1: exits 1'
assert_only E1 'e1: only [E1] fires'
assert_out_line '^outbound/mails/2026-09-17_relance\.md:0: ERROR \[E1\] ' 'e1: reported at line 0 of the mail'
assert_last_line '1 error(s), 0 warning(s)' 'e1: exactly one error'

# --- E2: an incomplete status value (D-08) ---
assert_lint "$FIXTURES/e2" 1 'e2: sent without a sender exits 1'
assert_only E2 'e2: only [E2] fires'
assert_out_line '^outbound/mails/2026-09-17_relance\.md:1: ERROR \[E2\] ' 'e2: reported at the Status: line'
assert_lint "$FIXTURES/e2-reviewed" 1 'e2-reviewed: reviewed by with no name exits 1'
assert_only E2 'e2-reviewed: only [E2] fires'

# --- E3: a Deadline that is not an absolute, real date (D-09) ---
assert_lint "$FIXTURES/e3" 1 'e3: a relative Deadline exits 1'
assert_only E3 'e3: only [E3] fires'
assert_out_line '^outbound/mails/2026-09-17_relance\.md:4: ERROR \[E3\] ' 'e3: reported at the Deadline: line'
assert_lint "$FIXTURES/e3-baddate" 1 'e3-baddate: Deadline 2026-13-45 exits 1'
assert_only E3 'e3-baddate: the calendar is validated, not just the shape'

# --- E1 on an incomplete header: Subject: is required under mails/ only (A-02) ---
assert_lint "$FIXTURES/mail-no-subject" 1 'mail-no-subject: exits 1'
assert_only E1 'mail-no-subject: only [E1] fires'
assert_out_line 'ERROR \[E1\] .*Subject:' 'mail-no-subject: the [E1] line names the missing Subject:'
assert_lint "$FIXTURES/calls-no-subject" 0 'calls-no-subject: the same file under calls/ exits 0'
assert_last_line '0 error(s), 0 warning(s)' 'calls-no-subject: zero findings'

# --- Negatives: well-formed headers, a binary deliverable, the shipped README ---
assert_lint "$FIXTURES/header-ok" 0 'header-ok: well-formed headers in three comment syntaxes exit 0'
assert_last_line '0 error(s), 0 warning(s)' 'header-ok: zero findings, the quoted header below line 10 ignored'
assert_lint "$FIXTURES/binary-ok" 0 'binary-ok: a .pdf beside its .md exits 0'
assert_last_line '0 error(s), 0 warning(s)' 'binary-ok: a binary raises none of E1-E3'
# The regression guard for the D-06 exemption: outbound/README.md quotes the
# status header verbatim, placeholders included (P-01).
assert_grep '^Deadline: YYYY-MM-DD' "$CLEAN/outbound/README.md"
assert_lint "$CLEAN" 0 'clean: outbound/README.md is exempt from E1-E3'
for ident in E1 E2 E3; do
  assert_no_finding "$ident" 'clean: the shipped outbound README raises no header finding'
done

# --- E4: the outbound filename convention (D-10, A-03) ---
assert_lint "$FIXTURES/e4" 1 'e4: a malformed filename exits 1'
assert_only E4 'e4: only [E4] fires'
assert_out_line '^outbound/mails/[^:]*:0: ERROR \[E4\] ' 'e4: reported at line 0 of the file'
assert_lint "$FIXTURES/e4-baddate" 1 'e4-baddate: 2026-13-45 in the filename exits 1'
assert_only E4 'e4-baddate: the filename date is calendar-validated'

# --- E5: a confidential name under outbound/, in the text or the filename (D-11) ---
assert_lint "$FIXTURES/e5" 1 'e5: a name in the body exits 1'
assert_only E5 'e5: only [E5] fires'
assert_out_line '^outbound/mails/2026-09-17_relance\.md:[1-9][0-9]*: ERROR \[E5\] ' 'e5: reported at the matching, non-zero line'
assert_eq 0 "$(printf '%s\n' "$LINT_OUT" | grep -c 'travaillons')" 'e5: the message carries the needle, never the surrounding sentence (T-02-09)'

assert_lint "$FIXTURES/e5-filename" 1 'e5-filename: a name only in the filename exits 1'
assert_only E5 'e5-filename: only [E5] fires'
assert_out_line '^outbound/mails/2026-09-17_acme-offer\.md:0: ERROR \[E5\] ' 'e5-filename: reported at line 0'

assert_lint "$FIXTURES/e5-boundary" 0 'e5-boundary: Acmetal and AcmeCorp exit 0'
assert_last_line '0 error(s), 0 warning(s)' 'e5-boundary: a name inside a longer word is not a match'

assert_lint "$FIXTURES/e5-nfd" 1 'e5-nfd: a decomposed accented name exits 1'
assert_only E5 'e5-nfd: only [E5] fires -- both sides NFC-normalised'

assert_lint "$FIXTURES/e5-binary" 1 'e5-binary: an undecodable binary does not crash and exits 1'
assert_only E5 'e5-binary: only [E5] fires'
assert_out_line '^outbound/deliverables/2026-09-17_acme-scan\.pdf:0: ERROR \[E5\] ' 'e5-binary: the filename half still runs'

assert_lint "$FIXTURES/e5-nonames" 0 'e5-nonames: an empty confidential_names list exits 0'
assert_no_finding E5 'e5-nonames: [E5] never fires without a configured name'

# --- The consent gate fails closed: a malformed flag leaves E5 armed (T-02-02) ---
assert_lint "$FIXTURES/c1-quoted-leak" 1 'c1-quoted-leak: exits 1'
assert_finding C1 'c1-quoted-leak: the malformed flag is reported'
assert_finding E5 'c1-quoted-leak: and the leak is still reported'
for ident in E1 E2 E3 E4 E6 E7 E8 E9 C0 W1 W2; do
  assert_no_finding "$ident" 'c1-quoted-leak: nothing but [C1] and [E5]'
done

# --- Forged name, end to end: the crafted filename is now reported by E4 (T-02-01) ---
assert_lint "$FIXTURES/forged-name" 1 'forged-name: the crafted filename fails E4, exit 1'
assert_only E4 'forged-name: only [E4] fires'
assert_eq 1 "$(printf '%s\n' "$LINT_OUT" | grep -c '\\x0a')" 'forged-name: the newline in the name is printed as \x0a'
assert_eq 1 "$(printf '%s\n' "$LINT_OUT" | grep -cE '^[0-9]+ error\(s\), [0-9]+ warning\(s\)$')" 'forged-name: still exactly one summary-shaped line'
assert_last_line '1 error(s), 0 warning(s)' 'forged-name: the real summary is last'

# --- The consent gate, three ways (spec Sec3.2, D-12, T-02-02) ---
# Suppressed only by a consent that is recorded AND sourced; c1-quoted-leak
# above is the malformed-flag case.
assert_lint "$FIXTURES/consent-ok-leak" 0 'consent-ok-leak: a recorded, sourced consent exits 0'
assert_last_line '0 error(s), 0 warning(s)' 'consent-ok-leak: the leak check is suppressed'

assert_lint "$FIXTURES/consent-nosource-leak" 1 'consent-nosource-leak: exits 1'
assert_finding E6 'consent-nosource-leak: the sourceless consent is reported'
assert_finding E5 'consent-nosource-leak: and it does not suppress the leak check'
for ident in E1 E2 E3 E4 E7 E8 E9 C1 C0 W1 W2; do
  assert_no_finding "$ident" 'consent-nosource-leak: nothing but [E6] and [E5]'
done

# --- The README exemption boundary: E1-E4 skip it, E5 does not (D-06, Q-5) ---
assert_lint "$FIXTURES/e5-readme" 1 'e5-readme: a name in outbound/README.md exits 1'
assert_only E5 'e5-readme: only [E5] fires -- none of E1-E4 on the README'
assert_out_line '^outbound/README\.md:[1-9][0-9]*: ERROR \[E5\] ' 'e5-readme: reported on outbound/README.md'
assert_lint "$FIXTURES/e5-readme-nonames" 0 'e5-readme-nonames: the same README with no configured name exits 0'
assert_last_line '0 error(s), 0 warning(s)' 'e5-readme-nonames: zero findings'
assert_lint "$CLEAN" 0 'clean: still exits 0'
assert_eq 0 "$(printf '%s\n' "$LINT_OUT" | grep -c '^outbound/README\.md:')" 'clean: no finding of any class on outbound/README.md'

# --- E8: a .claude/ folder below the dossier root (D-14) ---
assert_lint "$FIXTURES/e8" 1 'e8: dossier/.claude/ exits 1'
assert_only E8 'e8: only [E8] fires'
assert_out_line '^dossier/\.claude:0: ERROR \[E8\] ' 'e8: reported at line 0 of dossier/.claude'
assert_last_line '1 error(s), 0 warning(s)' 'e8: exactly one error'
# The negative controls that keep E8 from being vacuous: the root's own
# agent folder, and a sub-dossier's own one seen from either side.
assert_lint "$FIXTURES/claude-at-root" 0 'claude-at-root: <root>/.claude exits 0'
assert_last_line '0 error(s), 0 warning(s)' 'claude-at-root: the root agent folder raises nothing'
assert_lint "$FIXTURES/sub-dossier" 0 'sub-dossier: the nested .claude/ is pruned with its dossier'
assert_no_finding E8 'sub-dossier: no [E8] from the parent'
assert_lint "$FIXTURES/sub-dossier/clients/other" 1 'sub-dossier: linted directly, still exits 1 (E4, E7)'
assert_no_finding E8 'sub-dossier: linted directly, its own root .claude/ is permitted'

# --- E9: a rendered deliverable with no .md/.html source beside it (D-15) ---
assert_lint "$FIXTURES/e9" 1 'e9: a lone .pdf under deliverables/ exits 1'
assert_only E9 'e9: only [E9] fires'
assert_out_line '^outbound/deliverables/2026-09-17_audit\.pdf:0: ERROR \[E9\] ' 'e9: reported at line 0 of the render'
assert_last_line '1 error(s), 0 warning(s)' 'e9: exactly one error'
assert_lint "$FIXTURES/e9-docx" 1 'e9-docx: a lone .docx under deliverables/ exits 1'
assert_only E9 'e9-docx: only [E9] fires'
assert_lint "$FIXTURES/e9-source-only" 0 'e9-source-only: a source with no render exits 0'
assert_last_line '0 error(s), 0 warning(s)' 'e9-source-only: the reverse direction is silent'
assert_lint "$FIXTURES/render-html-ok" 0 'render-html-ok: a .pdf beside its .html exits 0'
assert_last_line '0 error(s), 0 warning(s)' 'render-html-ok: an .html source satisfies E9'
assert_lint "$FIXTURES/binary-ok" 0 'binary-ok: a .pdf beside its .md exits 0'
assert_no_finding E9 'binary-ok: an .md source satisfies E9'
assert_lint "$FIXTURES/e9-outside-deliverables" 0 'e9-outside-deliverables: a lone .pdf under mails/ exits 0'
assert_no_finding E9 'e9-outside-deliverables: E9 is scoped to outbound/deliverables/'

# --- No dossier: exit 2, the stderr message, nothing on stdout (D-02, P-13) ---
EMPTY="$(mktemp -d)"
assert_lint "$EMPTY" 2 'no dossier: exits 2'
assert_eq '' "$LINT_OUT" 'no dossier: nothing on stdout'
case "$LINT_ERR" in
  *"no dossier.yaml found from "*" upward"*) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
  *) echo "FAIL: no dossier: stderr lacks 'no dossier.yaml found from <path> upward' (got '$LINT_ERR')" >&2
     TESTS_FAILED=$((TESTS_FAILED + 1)) ;;
esac

finish
