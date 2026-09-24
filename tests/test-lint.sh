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
CLEAN_FR=""
FIXTURES=""
EMPTY=""
READONLY=""
GEN_TMP=""
# The one cleanup for everything this file creates, the generator's parent
# included: the generator installs no handler of its own, so a failed
# assertion anywhere below still leaks nothing.
trap 'rm -rf "$CLEAN" "$CLEAN_FR" "$FIXTURES" "$EMPTY" "$READONLY" "$GEN_TMP"' EXIT

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

# line_of FILE TEXT — the number of the first line of FILE containing the
# fixed string TEXT. Locations are derived from the fixture, never
# hard-coded, so a template gaining a line cannot silently shift them.
line_of() {
  grep -n -F -- "$2" "$1" | head -n 1 | cut -d: -f1
}

# assert_last_line EXPECTED LABEL — the summary is the last line (D-04).
assert_last_line() {
  assert_eq "$1" "$(printf '%s\n' "$LINT_OUT" | tail -n 1)" "$2"
}

# assert_clean LABEL — the last lint run raised none of the identifiers and
# its summary is exactly zero and zero.
assert_clean() {
  local label="$1" ident
  assert_last_line '0 error(s), 0 warning(s)' "$label: summary is 0 error(s), 0 warning(s)"
  for ident in $ALL_IDS; do
    assert_no_finding "$ident" "$label: no finding at all"
  done
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
assert_clean 'clean'

# --- The fixture generator's contract (LINT-02, D-29) ---
# An absent, empty, non-directory or non-dossier argument is refused with a
# message on stderr, and refused BEFORE anything is created. The generator's
# only way to create anything is its one `mktemp -d`, so every refused run
# below puts a logging mktemp shim first on PATH and the log must stay
# empty. (TMPDIR cannot be used for this: macOS mktemp -d ignores it.)
# Without the guard, an empty input would become a set of empty trees -- and
# an empty tree lints as "no dossier", never as the violation the case was
# meant to carry.
GEN_TMP="$(mktemp -d)"
mkdir "$GEN_TMP/bin"
printf '#!/bin/sh\necho "mktemp $*" >>"%s/mktemp.log"\nexit 1\n' "$GEN_TMP" >"$GEN_TMP/bin/mktemp"
chmod +x "$GEN_TMP/bin/mktemp"
: >"$GEN_TMP/mktemp.log"
not_a_file="$GEN_TMP/does-not-exist"
not_a_dossier="$GEN_TMP/not-a-dossier"
mkdir "$not_a_dossier"

# gen_refuses LABEL [ARG...] — the generator exits non-zero and says why.
gen_refuses() {
  local label="$1" status=0 err
  shift
  err="$(PATH="$GEN_TMP/bin:$PATH" bash "$FIXTURE_SCRIPT" "$@" 2>&1 >/dev/null)" || status=$?
  if [ "$status" -ne 0 ] && [ -n "$err" ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "FAIL: generator: $label (exit $status, stderr '$err')" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}
gen_refuses 'no argument is refused'
gen_refuses 'an empty argument is refused' ''
gen_refuses 'a path that does not exist is refused' "$not_a_file"
gen_refuses 'a directory with no dossier.yaml is refused' "$not_a_dossier"
gen_refuses 'two arguments are refused' "$CLEAN" "$CLEAN"
assert_eq '' "$(cat "$GEN_TMP/mktemp.log")" 'generator: a refused run never reached mktemp, so created nothing'
# The shim is live: the same PATH does reach it once the guard passes.
PATH="$GEN_TMP/bin:$PATH" bash "$FIXTURE_SCRIPT" "$CLEAN" >/dev/null 2>&1 || true
assert_grep '^mktemp -d' "$GEN_TMP/mktemp.log"

gen_out="$(bash "$FIXTURE_SCRIPT" "$CLEAN")"
assert_eq 1 "$(printf '%s\n' "$gen_out" | wc -l | tr -d ' ')" 'generator: a successful run prints exactly one line'
FIXTURES="$gen_out"
assert_dir "$FIXTURES"
# Addressed by name: each of the nine error classes has its own case tree.
for ident in e1 e2 e3 e4 e5 e6 e7 e8 e9; do
  assert_dir "$FIXTURES/$ident"
done

# --- The nine-class sweep: each error fixture fires its identifier and no other (criterion 2) ---
# Every one of these fixtures exits 1 for any error at all, so without the
# negative half a linter that reported one class on all nine trees would pass.
# Each pair is fixture:identifier, split by parameter expansion (bash 3.2 has
# no associative arrays). The exact summary also catches a second finding of
# the SAME class and a stray warning. Assertions are on exit code and
# identifier only, never on a golden output file (D-30).
SWEEP='e1:E1 e2:E2 e3:E3 e4:E4 e5:E5 e6:E6 e7:E7 e8:E8 e9:E9'
for pair in $SWEEP; do
  case_name="${pair%%:*}"
  want="${pair#*:}"
  assert_lint "$FIXTURES/$case_name" 1 "$case_name: exits 1"
  assert_finding "$want" "$case_name: [$want] fires"
  for ident in $ALL_IDS; do
    [ "$ident" = "$want" ] && continue
    assert_no_finding "$ident" "$case_name: [$ident] stays silent"
  done
  assert_last_line '1 error(s), 0 warning(s)' "$case_name: exactly one error, no warning"
  # What the sweep cannot express: where each finding is located.
  case "$case_name" in
    e1) assert_out_line '^outbound/mails/2026-09-17_relance\.md:0: ERROR \[E1\] ' 'e1: no status block (D-07), reported at line 0 of the mail' ;;
    e2) assert_out_line '^outbound/mails/2026-09-17_relance\.md:1: ERROR \[E2\] ' 'e2: sent without a sender (D-08), reported at the Status: line' ;;
    e3) assert_out_line '^outbound/mails/2026-09-17_relance\.md:4: ERROR \[E3\] ' 'e3: a relative Deadline (D-09), reported at the Deadline: line' ;;
    e4) assert_out_line '^outbound/mails/[^:]*:0: ERROR \[E4\] ' 'e4: a malformed filename (D-10), reported at line 0' ;;
    e5)
      assert_out_line '^outbound/mails/2026-09-17_relance\.md:[1-9][0-9]*: ERROR \[E5\] ' 'e5: a name in the body (D-11), reported at the matching line'
      assert_eq 0 "$(printf '%s\n' "$LINT_OUT" | grep -c 'travaillons')" 'e5: the message carries the needle, never the surrounding sentence (T-02-09)'
      ;;
    e6) assert_out_line '^dossier\.yaml:[0-9]+: ERROR \[E6\] ' 'e6: consent without a source (D-12), located in dossier.yaml' ;;
    e7) assert_out_line '^dossier/TONE\.md:[0-9]+: ERROR \[E7\] ' 'e7: a lost Last updated: line (D-13), on dossier/TONE.md' ;;
    e8) assert_out_line '^dossier/\.claude:0: ERROR \[E8\] ' 'e8: a nested .claude/ (D-14), reported at line 0 of the folder' ;;
    e9) assert_out_line '^outbound/deliverables/2026-09-17_audit\.pdf:0: ERROR \[E9\] ' 'e9: a render with no source (D-15), reported at line 0' ;;
  esac
done

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

# E6 itself is in the nine-class sweep. Its clean twin is swept against all
# thirteen identifiers: a recorded, sourced consent raises nothing at all.
assert_lint "$FIXTURES/consent-ok" 0 'consent-ok: exits 0'
assert_clean 'consent-ok'

junk_line="$(wc -l <"$FIXTURES/c0-junk/dossier.yaml" | tr -d ' ')"
assert_lint "$FIXTURES/c0-junk" 0 'c0-junk: an unparseable line is a warning, exit 0'
assert_out_line "^dossier\\.yaml:$junk_line: WARNING \\[C0\\] .*$junk_line" 'c0-junk: the [C0] warning names the line number'
assert_only C0 'c0-junk: only [C0] fires'
assert_last_line '0 error(s), 1 warning(s)' 'c0-junk: one warning, zero errors'

# A fresh scaffold raises neither configuration identifier.
assert_lint "$CLEAN" 0 'clean: still exits 0'
assert_no_finding C1 'clean: no [C1]'
assert_no_finding C0 'clean: no [C0]'

# --- E2 and E3 variants beyond the sweep's one fixture per class (D-08, D-09) ---
assert_lint "$FIXTURES/e2-reviewed" 1 'e2-reviewed: reviewed by with no name exits 1'
assert_only E2 'e2-reviewed: only [E2] fires'
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

# --- E4 variant: the filename date is calendar-validated (D-10, A-03) ---
assert_lint "$FIXTURES/e4-baddate" 1 'e4-baddate: 2026-13-45 in the filename exits 1'
assert_only E4 'e4-baddate: the filename date is calendar-validated'

# --- E5 variants: the filename, word boundaries, NFD, binaries, no names (D-11) ---
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

# --- The confidentiality gate fails closed on an unreadable line (CR-01, T-02-02) ---
# A gate line the subset cannot read is a [C1] error, never a [C0] warning:
# a warning exits 0, and E5 would be silently off with the name list lost.
for case_name in gate-multiline gate-escape gate-typo gate-quoted-key gate-nocolon gate-indent; do
  assert_lint "$FIXTURES/$case_name" 1 "$case_name: an unreadable confidential_names line exits 1"
  assert_out_line '^dossier\.yaml:[1-9][0-9]*: ERROR \[C1\] .*confidential_names' "$case_name: [C1] names the gate key"
  assert_no_finding C0 "$case_name: never a mere [C0] warning"
done
assert_lint "$FIXTURES/gate-col0" 1 'gate-col0: column-0 block items are read, the leak exits 1'
assert_only E5 'gate-col0: only [E5] fires -- ordinary YAML, no config finding'
for case_name in gate-dup gate-consent-dup gate-consent-dup-rev gate-json-dup gate-source-broken; do
  assert_lint "$FIXTURES/$case_name" 1 "$case_name: exits 1"
  assert_finding C1 "$case_name: the duplicated or broken gate key is a [C1]"
  assert_finding E5 "$case_name: and the leak check stays armed"
  assert_no_finding C0 "$case_name: never a mere [C0] warning"
done
assert_lint "$FIXTURES/gate-consent-dup-rev" 1 'gate-consent-dup-rev: exits 1'
assert_out_line '^dossier\.yaml:[1-9][0-9]*: ERROR \[C1\] .*consent_recorded' 'gate-consent-dup-rev: the [C1] names consent_recorded'
# --- Unicode line breaks inside a name drop no name (CR-02) ---
# The producer strips them; the consumer splits lines on \n and \r only.
for sep in '\342\200\250' '\342\200\251' '\302\205'; do
  assert_eq 0 "$(grep -c -F -- "$(printf "$sep")" "$FIXTURES/linebreak-name/dossier.yaml")" \
    "linebreak-name: init.py writes no raw Unicode line break into dossier.yaml ($sep)"
done
assert_lint "$FIXTURES/linebreak-name" 1 'linebreak-name: init.py -> lint.py round trip, the leak of Beta exits 1'
assert_only E5 'linebreak-name: only [E5] fires, the names line was read whole'
assert_lint "$FIXTURES/linebreak-yaml" 1 'linebreak-yaml: a U+2028 inside a quoted name still reads the line'
assert_only E5 'linebreak-yaml: only [E5] fires, no [C0] or [C1] for a split line'
# --- E5 on multi-word names: slugs and whitespace variants (CR-03) ---
assert_lint "$FIXTURES/e5-slug" 1 'e5-slug: big-telco in a conforming filename exits 1'
assert_only E5 'e5-slug: only [E5] fires'
assert_out_line '^outbound/mails/2026-09-17_big-telco-offer\.md:0: ERROR \[E5\] ' 'e5-slug: reported at line 0 of the file'
assert_lint "$FIXTURES/e5-slug-joined" 1 'e5-slug-joined: bigtelco in a filename exits 1'
assert_only E5 'e5-slug-joined: only [E5] fires'
assert_lint "$FIXTURES/e5-slug-accent" 1 'e5-slug-accent: an accented name folded into an ASCII slug exits 1'
assert_only E5 'e5-slug-accent: only [E5] fires'
assert_lint "$FIXTURES/e5-slug-boundary" 0 'e5-slug-boundary: bigtelcom, Bigger Telco and Big Telcom exit 0'
assert_last_line '0 error(s), 0 warning(s)' 'e5-slug-boundary: a longer word is still not the name'
ew="$FIXTURES/e5-wrapped/outbound/mails/2026-09-17_relance.md"
assert_lint "$FIXTURES/e5-wrapped" 1 'e5-wrapped: a name split across two lines exits 1'
assert_only E5 'e5-wrapped: only [E5] fires'
assert_out_line "^outbound/mails/2026-09-17_relance\\.md:$(line_of "$ew" 'people at Big'): ERROR \\[E5\\] " \
  'e5-wrapped: reported at the line the name starts on'
assert_lint "$FIXTURES/e5-spacing" 1 'e5-spacing: whitespace variants exit 1'
assert_only E5 'e5-spacing: only [E5] fires'
assert_last_line '3 error(s), 0 warning(s)' 'e5-spacing: two spaces, a no-break space and a tab all match'
# --- `''` inside a single-quoted scalar is an escape, not a closing quote (WR-01) ---
assert_lint "$FIXTURES/gate-sq-names" 1 "gate-sq-names: [ 'O''Brien, Jr', Acme ] is read, the leak exits 1"
assert_only E5 'gate-sq-names: only [E5] fires, the names line is not skipped'
assert_lint "$FIXTURES/gate-sq-source" 0 "gate-sq-source: a sourced consent written 'it''s # ok' exits 0"
assert_clean 'gate-sq-source: the source is read whole, the leak check suppressed'
# --- A null, ~ or letterless consent_source is no source (WR-02, spec Sec3.2) ---
for case_name in source-null source-tilde source-punct; do
  assert_lint "$FIXTURES/$case_name" 1 "$case_name: exits 1"
  assert_finding E6 "$case_name: consent recorded without a real source is [E6]"
  assert_finding E5 "$case_name: and it does not suppress the leak check"
  for ident in E1 E2 E3 E4 E7 E8 E9 C1 C0 W1 W2; do
    assert_no_finding "$ident" "$case_name: nothing but [E6] and [E5]"
  done
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

# --- E8's negative controls (D-14) ---
# E8 itself is in the nine-class sweep. The negative controls that keep E8 from being vacuous: the root's own
# agent folder, and a sub-dossier's own one seen from either side.
assert_lint "$FIXTURES/claude-at-root" 0 'claude-at-root: <root>/.claude exits 0'
assert_last_line '0 error(s), 0 warning(s)' 'claude-at-root: the root agent folder raises nothing'
assert_lint "$FIXTURES/sub-dossier" 0 'sub-dossier: the nested .claude/ is pruned with its dossier'
assert_no_finding E8 'sub-dossier: no [E8] from the parent'
assert_lint "$FIXTURES/sub-dossier/clients/other" 1 'sub-dossier: linted directly, still exits 1 (E4, E7)'
assert_no_finding E8 'sub-dossier: linted directly, its own root .claude/ is permitted'

# --- E9's variant and negative controls (D-15) ---
# E9 itself is in the nine-class sweep.
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

# --- W1: relative-date words, in dossier/ and knowledge/ only, word-bounded (D-16, D-17) ---
# A warning never changes the exit code, so every case below exits 0 and the
# error identifiers stay silent.
ERROR_IDS="E1 E2 E3 E4 E5 E6 E7 E8 E9 C1"

# assert_no_error LABEL — none of the error identifiers fired.
assert_no_error() {
  local label="$1" ident
  for ident in $ERROR_IDS; do
    assert_no_finding "$ident" "$label"
  done
}

# Criterion 1 in the second shipped language: a French scaffold is as clean
# as an English one, which a boundary-less `hier` would break three times
# over (`fichier(s)` in the shipped French templates, P-04).
CLEAN_FR="$(scratch_repo)"
python3 "$(init_py)" --target "$CLEAN_FR" --language fr >/dev/null
assert_lint "$CLEAN_FR" 0 'clean-fr: a fresh French scaffold exits 0'
assert_clean 'clean-fr'

w1="$FIXTURES/w1-fr"
assert_lint "$w1" 0 'w1-fr: four relative-date words still exit 0'
assert_no_error 'w1-fr: no error identifier'
assert_no_finding W2 'w1-fr: no bullet, so no [W2]'
assert_out_line "^dossier/HISTORY\\.md:$(line_of "$w1/dossier/HISTORY.md" 'rappelle demain'): WARNING \\[W1\\] .*'demain'" \
  'w1-fr: demain in dossier/HISTORY.md, at its line'
assert_out_line "^knowledge/CONTEXT\\.md:$(line_of "$w1/knowledge/CONTEXT.md" 'bougé récemment'): WARNING \\[W1\\] .*'récemment'" \
  'w1-fr: récemment in knowledge/CONTEXT.md -- knowledge/ is in scope too'
assert_out_line "^dossier/OPEN-QUESTIONS\\.md:$(line_of "$w1/dossier/OPEN-QUESTIONS.md" 'part la semaine'): WARNING \\[W1\\] .*'la semaine prochaine'" \
  'w1-fr: a multi-word entry matches as a phrase'
assert_out_line "^dossier/TONE\\.md:$(line_of "$w1/dossier/TONE.md" 'confirmé aujourd'): WARNING \\[W1\\] .*'aujourd'hui'" \
  'w1-fr: a typographic apostrophe matches the ASCII entry (P-05)'
assert_eq 1 "$(grep -c "$(printf '\342\200\231')" "$w1/dossier/TONE.md")" 'w1-fr: the bait really carries U+2019'
assert_last_line '0 error(s), 4 warning(s)' 'w1-fr: four warnings, zero errors'
assert_eq 0 "$(printf '%s\n' "$LINT_OUT" | grep -c 'périmètre')" 'w1-fr: the message names the entry, never the line (T-02-17)'

assert_lint "$FIXTURES/w1-en" 0 'w1-en: two relative-date words still exit 0'
assert_no_error 'w1-en: no error identifier'
assert_out_line "^dossier/HISTORY\\.md:$(line_of "$FIXTURES/w1-en/dossier/HISTORY.md" 'back tomorrow'): WARNING \\[W1\\] .*'tomorrow'" \
  'w1-en: tomorrow in dossier/HISTORY.md'
assert_out_line "^knowledge/CONTEXT\\.md:$(line_of "$FIXTURES/w1-en/knowledge/CONTEXT.md" 'decided next week'): WARNING \\[W1\\] .*'next week'" \
  'w1-en: next week in knowledge/CONTEXT.md'
assert_last_line '0 error(s), 2 warning(s)' 'w1-en: two warnings, zero errors'

assert_grep 'fichiers de la hiérarchie' "$FIXTURES/w1-boundary/dossier/CHANNELS.md"
assert_lint "$FIXTURES/w1-boundary" 0 'w1-boundary: exits 0'
assert_clean 'w1-boundary: hier inside fichiers and hiérarchie is no match (P-04)'

assert_grep 'demain' "$FIXTURES/w1-outbound/outbound/mails/2026-09-17_relance.md"
assert_lint "$FIXTURES/w1-outbound" 0 'w1-outbound: exits 0'
assert_clean 'w1-outbound: outbound/ is outside the relative-date check'

assert_lint "$FIXTURES/w1-nolist" 0 'w1-nolist: a language with no word list exits 0'
assert_eq 1 "$(count_out_lines '^info: ')" 'w1-nolist: exactly one informational line'
assert_out_line "^info: .*'de'" 'w1-nolist: the informational line names the language'
assert_no_finding W1 'w1-nolist: [W1] skipped'
assert_no_finding W2 'w1-nolist: [W2] skipped'
assert_last_line '0 error(s), 0 warning(s)' 'w1-nolist: never an error, never a crash (D-20)'
case "$(printf '%s\n' "$LINT_OUT" | head -n 1)" in
  info:*) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
  *) echo "FAIL: w1-nolist: the informational line is not printed first" >&2; TESTS_FAILED=$((TESTS_FAILED + 1)) ;;
esac
assert_lint "$CLEAN" 0 'clean: still exits 0'
assert_eq 0 "$(count_out_lines '^info: ')" 'clean: a shipped language prints no informational line'

# --- W2: unsourced bullets in the seven living files only (D-16, D-18) ---
w2="$FIXTURES/w2-fr"
w2h="$w2/dossier/HISTORY.md"
assert_lint "$w2" 0 'w2-fr: four unsourced bullets still exit 0'
assert_no_error 'w2-fr: no error identifier'
assert_no_finding W1 'w2-fr: no relative-date word, so no [W1]'
assert_last_line '0 error(s), 4 warning(s)' 'w2-fr: exactly the four expected bullets fire'
# w2_at TEXT LABEL / no_w2_at TEXT LABEL — W2 does / does not fire at the
# HISTORY.md line holding TEXT.
w2_at() {
  assert_out_line "^dossier/HISTORY\\.md:$(line_of "$w2h" "$1"): WARNING \\[W2\\] " "$2"
}
no_w2_at() {
  assert_eq 0 "$(count_out_lines "^dossier/HISTORY\\.md:$(line_of "$w2h" "$1"): WARNING \\[W2\\] ")" "$2"
}
no_w2_at 'rappelle le 2026-10-01 (appel' 'w2-fr: a bullet ending with a parenthetical source is silent'
w2_at 'attendu le 2026-10-01.' 'w2-fr: an unsourced bullet fires at its exact line'
w2_at '* Une autre ligne' 'w2-fr: the `* ` marker is a bullet too'
no_w2_at 'Probablement un budget' 'w2-fr: an opinion marker makes an unsourced bullet legitimate'
w2_at 'reconstruite' 'w2-fr: an inflected near-marker is not a marker (boundary)'
no_w2_at 'Une piste non vérifiée' 'w2-fr: a bullet inside a multi-line comment block is silent'
w2_at 'après le commentaire' 'w2-fr: the tracker closes -- the bullet after the block fires'
no_w2_at '## Chronologie' 'w2-fr: a heading is never a bullet'
assert_eq 0 "$(count_out_lines '^dossier/README\.md:')" 'w2-fr: dossier/README.md is not a living file (P-02)'
assert_eq 0 "$(count_out_lines '^knowledge/')" 'w2-fr: knowledge/ is outside W2'
assert_eq 0 "$(count_out_lines '^outbound/')" 'w2-fr: outbound/ is outside W2'
assert_eq 0 "$(printf '%s\n' "$LINT_OUT" | grep -c 'livrable')" 'w2-fr: the message carries no content from the line (T-02-17)'

w2e="$FIXTURES/w2-en/dossier/HISTORY.md"
assert_lint "$FIXTURES/w2-en" 0 'w2-en: exits 0'
assert_no_error 'w2-en: no error identifier'
assert_out_line "^dossier/HISTORY\\.md:$(line_of "$w2e" 'budget was cut'): WARNING \\[W2\\] " 'w2-en: the unsourced bullet fires'
assert_last_line '0 error(s), 1 warning(s)' 'w2-en: the sourced and the Probably bullets are silent'

assert_lint "$FIXTURES/w2-many" 0 'w2-many: twenty warnings never change the exit code (D-16)'
assert_last_line '0 error(s), 20 warning(s)' 'w2-many: twenty warnings, zero errors'
assert_eq 20 "$(count_out_lines ' WARNING \[W2\] ')" 'w2-many: every one of the twenty is a [W2]'

# --- ROADMAP criterion 3: the committed French fixture (D-28 as amended) ---
# The one committed lint fixture, asserted where it lives rather than on a
# generated copy. Locations, not counts: "seven warnings" would pass with one
# class firing seven times and the other never.
FR="$REPO_ROOT/tests/fixtures/lint/fr"
frh="$FR/dossier/HISTORY.md"
assert_grep '^language: fr$' "$FR/dossier.yaml"
# The English protocol label, exactly once per living file, never translated.
for living in ACTORS HISTORY LEARNINGS TONE CHANNELS OPEN-QUESTIONS RELATIONSHIP; do
  assert_eq 1 "$(grep -cE '^Last updated: [0-9]{4}-[0-9]{2}-[0-9]{2}$' "$FR/dossier/$living.md")" \
    "fr: dossier/$living.md carries one English Last updated: line"
  assert_not_grep 'Dernière mise à jour' "$FR/dossier/$living.md"
done
assert_lint "$FR" 0 'fr: the committed French fixture exits 0'
assert_no_error 'fr: no error identifier at all'
assert_no_finding E7 'fr: the English Last updated: label is found inside French content'
assert_eq 0 "$(count_out_lines ' ERROR ')" 'fr: no ERROR line'
assert_finding W1 'fr: [W1] is raised'
assert_finding W2 'fr: [W2] is raised'
assert_last_line '0 error(s), 7 warning(s)' 'fr: seven warnings, zero errors'

# fr_at FILE TEXT IDENT LABEL / fr_none FILE TEXT LABEL — IDENT fires / nothing
# fires at the line of dossier-relative FILE holding TEXT.
fr_at() {
  local n
  n="$(line_of "$FR/$1" "$2")"
  assert_out_line "^$(printf '%s' "$1" | sed 's/\./\\./g'):$n: WARNING \\[$3\\] " "$4"
}
fr_none() {
  local n
  n="$(line_of "$FR/$1" "$2")"
  [ -n "$n" ] || n='missing'
  assert_eq 0 "$(count_out_lines "^$(printf '%s' "$1" | sed 's/\./\\./g'):$n: ")" "$3"
}
fr_at dossier/HISTORY.md 'rappelle demain' W1 'fr: demain raises [W1]'
fr_at dossier/HISTORY.md 'rappelle demain' W2 'fr: ... and [W2] on the same unsourced line'
fr_at dossier/HISTORY.md 'la semaine prochaine (appel' W1 'fr: a sourced phrase raises [W1]'
assert_eq 0 "$(count_out_lines "^dossier/HISTORY\\.md:$(line_of "$frh" 'la semaine prochaine (appel'): WARNING \\[W2\\] ")" \
  'fr: ... and no [W2], it is sourced'
fr_none dossier/HISTORY.md 'Probablement un budget' 'fr: an opinion marker raises nothing'
fr_at dossier/HISTORY.md 'reconstruite' W2 'fr: an inflected near-marker raises [W2]'
fr_at dossier/HISTORY.md 'confirmé le cadrage' W1 'fr: a typographic apostrophe raises [W1]'
assert_eq 1 "$(grep -c "$(printf '\342\200\231')" "$frh")" 'fr: the apostrophe bait really is U+2019'
fr_none dossier/HISTORY.md 'gelé jusqu' 'fr: a bullet inside the multi-line comment raises nothing'
fr_at dossier/HISTORY.md 'proposition chiffrée' W2 'fr: the bullet after the comment block raises [W2]'
fr_at knowledge/CONTEXT.md 'bougé récemment' W1 'fr: knowledge/ is in [W1] scope'
# The P-04 bait: sourced, only substrings of `hier`, so nothing at all.
assert_eq 1 "$(grep -rn 'fichier' "$FR/dossier/" | grep -c 'hiérarchie')" 'fr: the fichiers/hiérarchie bait line is present'
fr_none dossier/CHANNELS.md 'fichiers de la hiérarchie' 'fr: the fichiers/hiérarchie bait line raises nothing (P-04)'
# A genuine multi-line comment: the opener and the closer on different lines.
assert_eq 1 "$(grep -cx -- '<!--' "$frh")" 'fr: HISTORY.md holds a bare <!-- opener line'
assert_eq 1 "$(grep -cx -- '-->' "$frh")" 'fr: ... and a bare --> closer line'

# Committed means tracked: an ignored file vanishes on a fresh clone and
# takes criterion 3 with it.
fr_tracked="$(git -C "$REPO_ROOT" ls-files tests/fixtures/lint/fr/)"
fr_count="$(printf '%s\n' "$fr_tracked" | grep -c 'fixtures/lint/fr/')"
if [ "$fr_count" -ge 20 ]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "FAIL: fr: only $fr_count fixture files are tracked by git (want >= 20)" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi
# No committed tests/fixtures/lint/clean/ (D-28 as amended): the clean tree is generated.
assert_eq '' "$(git -C "$REPO_ROOT" ls-files tests/fixtures/lint/clean/)" 'no committed clean fixture (D-28 as amended)'

# --- ROADMAP criterion 1, exhaustively: what init.py scaffolds lints with zero findings ---
# Every other check in this suite has a fixture that turns red. "The linter
# accepts what the scaffolder produces" only turns red if somebody runs it,
# so it is asserted here, not observed in a summary. The two exemptions that
# make it true -- dossier/README.md is not a living file (D-06) and a
# commented example line is not a fact line (D-18) -- are exactly the kind of
# detail a later simplification removes without noticing. Each case asserts
# three things, because each alone can be fooled: the exit code, the summary
# as the last line, and the absence of every one of the thirteen identifiers.

# scaffold_lints_clean LABEL [INIT_ARG...] — scaffold a scratch repository
# with the given init.py flags, lint it, assert zero findings, tear it down.
scaffold_lints_clean() {
  local label="$1" d status=0
  shift
  d="$(scratch_repo)"
  python3 "$(init_py)" --target "$d" "$@" >/dev/null || status=$?
  assert_eq 0 "$status" "$label: init.py scaffolds"
  assert_lint "$d" 0 "$label: exits 0"
  assert_clean "$label"
  assert_eq 0 "$(count_out_lines '\[(E[1-9]|W[12]|C[01])\]')" "$label: no identifier on any line"
  rm -rf "$d"
}

scaffold_lints_clean 'scaffold-en: a default English scaffold' --language en
# The French one is the case that catches a missing word boundary: the French
# dossier README says `fichier` three times, and `fichier` holds `hier` (P-04).
scaffold_lints_clean 'scaffold-fr: a default French scaffold' --language fr
# Every optional flag, each with a valid value: a fully populated config is
# as clean as a default one, and the schema's optional fields are exercised.
scaffold_lints_clean 'scaffold-full: every optional flag supplied' \
  --language fr \
  --counterpart 'Acme Consulting|donneur ordre|Jane Doe;jane@acme.example' \
  --counterpart 'Big Telco|client final' \
  --confidential-name Acme \
  --consent-recorded true \
  --consent-source 'mail 2026-09-16 from Jane' \
  --timestamps '@hh:mm:ss' \
  --staleness-days 14

# --- The producer/consumer round trip on a YAML reserved spelling (D-24.4, Phase 1 debt a) ---
# `no` is a language code and a YAML 1.1 spelling of false. init.py must
# write it quoted and lint.py must read it back as the two-letter string.
# The exit code alone cannot see a coercion: a consumer that read a boolean
# would print one in the informational line, or crash looking a boolean up in
# LANGUAGE_WORDS -- so the assertion is on the line's content.
rt="$(scratch_repo)"
rt_status=0
python3 "$(init_py)" --target "$rt" --language no >/dev/null || rt_status=$?
assert_eq 0 "$rt_status" 'round-trip: init.py scaffolds --language no'
assert_grep '^language: "no"$' "$rt/dossier.yaml"
assert_lint "$rt" 0 'round-trip: the dossier lints with exit 0'
assert_eq 1 "$(count_out_lines "^info: language 'no' ")" "round-trip: the info line names the string 'no'"
assert_eq 0 "$(printf '%s\n' "$LINT_OUT" | grep '^info:' | grep -cE 'False|True|false|true')" \
  'round-trip: the info line names no boolean'
assert_clean 'round-trip: the reserved-spelling dossier'
rm -rf "$rt"

# The complementary negative: an unknown code that is NOT reserved takes the
# same informational path, so the case above tests the reserved spelling and
# not merely the unknown-language path.
rt="$(scratch_repo)"
rt_status=0
python3 "$(init_py)" --target "$rt" --language it >/dev/null || rt_status=$?
assert_eq 0 "$rt_status" 'round-trip: init.py scaffolds --language it'
assert_grep '^language: it$' "$rt/dossier.yaml"
assert_lint "$rt" 0 'round-trip: the unreserved unknown language exits 0'
assert_eq 1 "$(count_out_lines "^info: language 'it' ")" "round-trip: the info line names 'it'"
assert_clean 'round-trip: the unreserved unknown-language dossier'
rm -rf "$rt"

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
