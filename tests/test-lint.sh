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
trap 'rm -rf "$CLEAN" "$FIXTURES" "$EMPTY"' EXIT

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
