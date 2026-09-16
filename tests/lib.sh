#!/usr/bin/env bash
# tests/lib.sh — shared assertion helpers, sourced by every test-*.sh file.
#
# set -u (catch unset-variable typos in test files) but NOT set -e: a failed
# assertion must be recorded and the test must keep running, not abort.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

TESTS_PASSED=0
TESTS_FAILED=0

# init_py — the absolute path to the script under test. Tests call
# `python3 "$(init_py)" ...` because the bash harness has no
# `${CLAUDE_SKILL_DIR}` expansion (that is a Claude Code harness-side
# substitution, not an environment variable — RESEARCH assumption A4).
init_py() {
  echo "$REPO_ROOT/skills/dossier-init/scripts/init.py"
}

# scratch_repo — a fresh throwaway git repository. Echoes its path.
scratch_repo() {
  local d
  d="$(mktemp -d)"
  git init -q "$d"
  git -C "$d" config user.email "test@example.invalid"
  git -C "$d" config user.name "Test Runner"
  echo "$d"
}

assert_file() {
  local path="$1"
  if [ -f "$path" ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "FAIL: expected file to exist: $path" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

assert_dir() {
  local path="$1"
  if [ -d "$path" ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "FAIL: expected directory to exist: $path" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

assert_exec() {
  local path="$1"
  if [ -x "$path" ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "FAIL: expected file to be executable: $path" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# assert_grep REGEX PATH — fixed-string-safe basic regex match (grep -q --).
# The `--` guards against a regex that starts with `-` being read as an option.
assert_grep() {
  local regex="$1" path="$2"
  if grep -q -- "$regex" "$path" 2>/dev/null; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "FAIL: expected '$path' to match /$regex/: $path" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# assert_grep_e REGEX PATH — same as assert_grep but extended regex (grep -Eq --).
assert_grep_e() {
  local regex="$1" path="$2"
  if grep -Eq -- "$regex" "$path" 2>/dev/null; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "FAIL: expected '$path' to match /$regex/ (extended): $path" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

assert_not_grep() {
  local regex="$1" path="$2"
  if grep -q -- "$regex" "$path" 2>/dev/null; then
    echo "FAIL: expected '$path' NOT to match /$regex/: $path" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  else
    TESTS_PASSED=$((TESTS_PASSED + 1))
  fi
}

assert_eq() {
  local expected="$1" actual="$2" label="$3"
  if [ "$expected" = "$actual" ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "FAIL: $label (expected '$expected', got '$actual')" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# finish — prints the summary line and exits 1 when any assertion failed.
finish() {
  echo "PASS $TESTS_PASSED FAIL $TESTS_FAILED"
  if [ "$TESTS_FAILED" -gt 0 ]; then
    exit 1
  fi
  exit 0
}
