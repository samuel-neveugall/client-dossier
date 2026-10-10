#!/usr/bin/env bash
# tests/lib.sh — shared assertion helpers, sourced by every test-*.sh file.
#
# set -u (catch unset-variable typos in test files) but NOT set -e: a failed
# assertion must be recorded and the test must keep running, not abort.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# skip LABEL — a coverage gap tests/run.sh must not report as green in
# silence (WR-02 of the iteration-4 review): the caller's environment made
# a check impossible to run (e.g. chmod 000 has no effect as root), never a
# pass or a fail. Printed to stdout, not stderr, so it survives
# tests/run.sh's `bash "$f" >file 2>&1` capture and its own summary line
# whether the run as a whole passes or fails, and counted separately so
# `finish` can name how many happened without ever touching TESTS_PASSED or
# TESTS_FAILED -- tests/run.sh's pass/fail decision stays exactly what it
# was.
skip() {
  TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
  echo "SKIP: $1"
}

# The last lint run's stdout and stderr, set by assert_lint(). Initialised
# here because set -u aborts on a read before the first assert_lint.
LINT_OUT=""
LINT_ERR=""

# The last hook run's stdout, stderr and exit status, set by run_hook().
# Initialised here for the same reason as LINT_OUT: set -u aborts on a read
# before the first run_hook.
HOOK_OUT=""
HOOK_ERR=""
HOOK_STATUS=0

# init_py — the absolute path to the script under test. Tests call
# `python3 "$(init_py)" ...` because the bash harness has no
# `${CLAUDE_SKILL_DIR}` expansion (that is a Claude Code harness-side
# substitution, not an environment variable — RESEARCH assumption A4).
init_py() {
  echo "$REPO_ROOT/skills/dossier-init/scripts/init.py"
}

# lint_py — the absolute path to the linter under test. Mirrors init_py():
# the bash harness has no ${CLAUDE_PLUGIN_ROOT} expansion, and a hardcoded
# path breaks the moment the repository is checked out elsewhere.
lint_py() {
  echo "$REPO_ROOT/scripts/lint.py"
}

# hooks_dir — the absolute path to the hook scripts under test. Mirrors
# lint_py(): the bash harness has no ${CLAUDE_PLUGIN_ROOT} expansion.
hooks_dir() {
  echo "$REPO_ROOT/hooks"
}

# hook_json EVENT CWD TOOL_NAME INPUT_KEY INPUT_VALUE — one JSON object, the
# stdin a Claude Code hook receives. Built by python3 from argv, never by
# printf, so a path holding a space, a quote or a backslash stays valid JSON.
# `cwd` is present only when CWD is non-empty; `tool_name` and `tool_input`
# ({INPUT_KEY: INPUT_VALUE}) only when TOOL_NAME is non-empty.
hook_json() {
  python3 -c 'import json, sys
a = sys.argv[1:] + [""] * 5
event, cwd, tool, key, value = a[:5]
d = {"hook_event_name": event, "session_id": "test", "transcript_path": "/dev/null"}
if cwd:
    d["cwd"] = cwd
if tool:
    d["tool_name"] = tool
    d["tool_input"] = {key: value}
print(json.dumps(d))' "$@"
}

# run_hook NAME JSON — pipes JSON into `python3 hooks/NAME`, stores stdout in
# HOOK_OUT, stderr in HOOK_ERR and the exit status in HOOK_STATUS for the
# assertions that follow. stderr goes through a mktemp file, never a file
# beside the dossier, so the tree under test is left untouched.
run_hook() {
  local name="$1" json="$2" err_file
  err_file="$(mktemp)"
  HOOK_STATUS=0
  HOOK_OUT="$(printf '%s' "$json" | python3 "$(hooks_dir)/$name" 2>"$err_file")" || HOOK_STATUS=$?
  HOOK_ERR="$(cat "$err_file")"
  rm -f "$err_file"
}

# hook_field DOTTED.PATH — the value at that path in HOOK_OUT. Prints `none`
# when HOOK_OUT is empty or only whitespace (the hook stayed silent), and
# `invalid` when HOOK_OUT is not a single JSON object.
hook_field() {
  printf '%s' "$HOOK_OUT" | python3 -c 'import json, sys
text = sys.stdin.read()
if not text.strip():
    print("none")
    sys.exit(0)
try:
    value = json.loads(text)
    if not isinstance(value, dict):
        raise ValueError("not an object")
    for part in sys.argv[1].split("."):
        value = value[part]
except Exception:
    print("invalid")
    sys.exit(0)
print(value)' "$1"
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

# assert_lint DOSSIER EXPECTED_EXIT LABEL — runs the linter once on DOSSIER,
# stores stdout in LINT_OUT and stderr in LINT_ERR for the assertions that
# follow, and asserts the exit code. stderr goes through a mktemp file, never
# a file beside the dossier, so the tree under test is left untouched.
assert_lint() {
  local dossier="$1" expected="$2" label="$3" status=0 err_file
  err_file="$(mktemp)"
  LINT_OUT="$(python3 "$(lint_py)" "$dossier" 2>"$err_file")" || status=$?
  LINT_ERR="$(cat "$err_file")"
  rm -f "$err_file"
  assert_eq "$expected" "$status" "$label"
}

# assert_finding ID LABEL — the identifier `[ID]` appears in LINT_OUT.
# assert_no_finding ID LABEL — it does not (D-29 isolation). `case` glob
# matching keeps both bash-3.2-safe with no subprocess per assertion.
assert_finding() {
  local ident="$1" label="$2"
  case "$LINT_OUT" in
    *"[$ident]"*) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
    *)
      echo "FAIL: $label (no [$ident] in lint output)" >&2
      TESTS_FAILED=$((TESTS_FAILED + 1))
      ;;
  esac
}

assert_no_finding() {
  local ident="$1" label="$2"
  case "$LINT_OUT" in
    *"[$ident]"*)
      echo "FAIL: $label (unexpected [$ident] in lint output)" >&2
      TESTS_FAILED=$((TESTS_FAILED + 1))
      ;;
    *) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
  esac
}

# finish — prints the summary line and exits 1 when any assertion failed.
# The skip count is informational only: it never turns a pass into a fail,
# and it is silent when zero so today's output is unchanged everywhere
# skip() is not yet called (WR-02).
finish() {
  if [ "$TESTS_SKIPPED" -gt 0 ]; then
    echo "PASS $TESTS_PASSED FAIL $TESTS_FAILED SKIP $TESTS_SKIPPED"
  else
    echo "PASS $TESTS_PASSED FAIL $TESTS_FAILED"
  fi
  if [ "$TESTS_FAILED" -gt 0 ]; then
    exit 1
  fi
  exit 0
}
