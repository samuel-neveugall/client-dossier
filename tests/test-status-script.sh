#!/usr/bin/env bash
# tests/test-status-script.sh — CALL-03 mechanics and PROTO-08's exit 2, with the
# decisions D-02 to D-05, D-12 and D-13 (plan 06-02): the read-only
# skills/dossier-status/scripts/status.py, on scratch git dossiers scaffolded by
# the REAL init.py, always with --today so no case depends on the calendar.
#
# The first case is the phase's TRACER: status.py from CLI to report on one
# dossier (root, today, one overdue commitment, the real linter found from the
# script's own location, JSON and text). Every later case hardens the same script.
#
# No model, no network. bash 3.2, no arrays.
set -u

# shellcheck source=./lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# The plugin-root variable is substituted in skill text but empty in the Bash
# tool (06-RESEARCH P1): no case may rely on it being set.
unset CLAUDE_PLUGIN_ROOT

# st_script — the script under test, by absolute path (the bash harness has no
# ${CLAUDE_SKILL_DIR} expansion; see init_py in lib.sh).
st_script() {
  echo "$REPO_ROOT/skills/dossier-status/scripts/status.py"
}

# The last run_st run: stdout, stderr and exit status. Initialised for set -u.
ST_OUT=""
ST_ERR=""
ST_STATUS=0

# WORK holds every scratch dossier (physical path: macOS /var is a symlink, and
# status.py reports the real path). ERRDIR holds the stderr captures, outside
# every dossier.
WORK="$(cd "$(mktemp -d)" && pwd -P)"
ERRDIR="$(mktemp -d)"
trap 'rm -rf "$WORK" "$ERRDIR"' EXIT

TODAY=2026-10-11

# run_st DIR ARG... — runs the script from DIR with a 30 s watchdog. stderr goes
# through a file under ERRDIR, never a file beside the dossier.
run_st() {
  local dir="$1" err_file="$ERRDIR/err"
  shift
  ST_STATUS=0
  if command -v perl >/dev/null 2>&1; then
    ST_OUT="$(cd "$dir" && perl -e 'alarm 30; exec @ARGV' python3 "$(st_script)" "$@" 2>"$err_file")" || ST_STATUS=$?
  else
    ST_OUT="$(cd "$dir" && python3 "$(st_script)" "$@" 2>"$err_file")" || ST_STATUS=$?
  fi
  ST_ERR="$(cat "$err_file")"
}

# st_json PYEXPR — the value of a Python expression evaluated on
# d = json.loads(ST_OUT). A list or dict is printed as JSON. `invalid` when
# ST_OUT is not exactly one JSON object.
st_json() {
  printf '%s' "$ST_OUT" | python3 -I -c 'import json, sys
try:
    d = json.loads(sys.stdin.read())
    if not isinstance(d, dict):
        raise ValueError("not an object")
except Exception:
    print("invalid")
    sys.exit(0)
v = eval(sys.argv[1])
print(json.dumps(v) if isinstance(v, (list, dict)) else v)' "$1"
}

# mk_dossier LANG — a git repository holding a dossier scaffolded by the real
# init.py, with an initial commit. Echoes its path.
mk_dossier() {
  local lang="$1" d
  d="$(mktemp -d "$WORK/d.XXXXXX")"
  git init -q "$d"
  git -C "$d" config user.email "test@example.invalid"
  git -C "$d" config user.name "Test Runner"
  python3 "$(init_py)" --target "$d" --language "$lang" >/dev/null 2>&1
  git -C "$d" add -A >/dev/null 2>&1
  git -C "$d" commit -q -m 'scaffold' >/dev/null 2>&1
  echo "$d"
}

# set_updated DIR DATE — every living file says `Last updated: DATE`.
set_updated() {
  python3 -I -c 'import glob, os, re, sys
d, date = sys.argv[1], sys.argv[2]
for p in glob.glob(os.path.join(d, "dossier", "*.md")):
    t = open(p, encoding="utf-8").read()
    t = re.sub(r"(?m)^Last updated:.*$", "Last updated: " + date, t, count=1)
    open(p, "w", encoding="utf-8").write(t)' "$1" "$2"
}

# write_history DIR OURS THEIRS UPCOMING [LANG] — rewrites dossier/HISTORY.md
# with the given bullet blocks under the three positional headings.
write_history() {
  local d="$1" ours="$2" theirs="$3" up="$4" lang="${5:-en}"
  local h1 h2 o t u c
  if [ "$lang" = fr ]; then
    h1='Historique'; c='Chronologie'; h2='Engagements en cours'; o='Les nôtres'; t='Les leurs'; u='À venir'
  else
    h1='History'; c='Chronology'; h2='Commitments in progress'; o='Ours'; t='Theirs'; u='Upcoming'
  fi
  printf '# %s\n\nLast updated: 2026-10-10\n\n## %s\n\n## %s\n\n### %s\n%s\n\n### %s\n%s\n\n## %s\n%s\n' \
    "$h1" "$c" "$h2" "$o" "$ours" "$t" "$theirs" "$u" "$up" >"$d/dossier/HISTORY.md"
}

# ---------------------------------------------------------------------------
echo '--- Tracer: one overdue commitment, the real linter, JSON and text ---'

D="$(mk_dossier en)"
write_history "$D" '- We send the quote to Jane Doe (Acme Consulting) by 2026-10-08 (call 2026-10-01 @12:34).' '' ''
LINE="$(grep -n 'We send the quote' "$D/dossier/HISTORY.md" | cut -d: -f1)"
set_updated "$D" 2026-10-10

run_st "$D" --json --today "$TODAY" "$D"
assert_eq 0 "$ST_STATUS" 'tracer: exit 0 after a report'
assert_eq '' "$ST_ERR" 'tracer: nothing on stderr'
assert_eq "$D" "$(st_json 'd["root"]')" 'tracer: root is the dossier'
assert_eq "$TODAY" "$(st_json 'd["today"]')" 'tracer: today echoes --today'
assert_eq 1 "$(st_json 'len(d["commitments"])')" 'tracer: exactly one commitment'
assert_eq 2026-10-08 "$(st_json 'd["commitments"][0]["date"]')" 'tracer: commitment date'
assert_eq overdue "$(st_json 'd["commitments"][0]["state"]')" 'tracer: commitment is overdue'
assert_eq ours "$(st_json 'd["commitments"][0]["side"]')" 'tracer: side ours'
assert_eq Ours "$(st_json 'd["commitments"][0]["heading"]')" 'tracer: heading text kept'
assert_eq dossier/HISTORY.md "$(st_json 'd["commitments"][0]["file"]')" 'tracer: source file'
assert_eq "$LINE" "$(st_json 'd["commitments"][0]["line"]')" 'tracer: source line number'
assert_eq True "$(st_json 'd["lint"]["available"]')" 'tracer: the linter is found from the script location, no argument'
assert_eq 0 "$(st_json 'd["lint"]["exit"]')" 'tracer: lint exit 0'
assert_eq 0 "$(st_json 'd["lint"]["errors"]')" 'tracer: lint reports 0 errors'
assert_eq '[]' "$(st_json 'd["upcoming"]')" 'tracer: no upcoming item'

run_st "$D" --today "$TODAY" "$D"
assert_eq 0 "$ST_STATUS" 'tracer text: exit 0'
printf '%s\n' "$ST_OUT" | grep -A1 '^Commitments overdue:' | grep -q '2026-10-08'
assert_eq 0 "$?" 'tracer text: Commitments overdue: is followed by the 2026-10-08 line'
case "$ST_OUT" in
  *'Lint: 0 error(s), 0 warning(s)'*) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
  *) echo 'FAIL: tracer text: lint summary line' >&2; TESTS_FAILED=$((TESTS_FAILED + 1)) ;;
esac

run_st "$D/dossier" --json --today "$TODAY"
assert_eq "$D" "$(st_json 'd["root"]')" 'subfolder: same root when run from dossier/'

mkdir -p "$D/deep/er"
run_st "$D/deep/er" --json --today "$TODAY"
assert_eq "$D" "$(st_json 'd["root"]')" 'subfolder: same root two folders down'
run_st "$D" --json --today "$TODAY" deep/er
assert_eq "$D" "$(st_json 'd["root"]')" 'subfolder: PATH argument inside the dossier'

mkdir -p "$D/outer/sub/inner"
printf 'version: 1\nlanguage: en\n' >"$D/outer/sub/inner/dossier.yaml"
run_st "$D/outer/sub/inner" --json --today "$TODAY"
assert_eq "$D/outer/sub/inner" "$(st_json 'd["root"]')" 'nested dossiers: the nearest one is the root'
rm -rf "$D/outer"

if [ -x /usr/bin/python3 ]; then
  ST_STATUS=0
  ST_OUT="$(cd "$D" && /usr/bin/python3 "$(st_script)" --json --today "$TODAY" "$D" 2>"$ERRDIR/err")" || ST_STATUS=$?
  assert_eq 0 "$ST_STATUS" "/usr/bin/python3 ($(/usr/bin/python3 --version 2>&1)): tracer exit 0"
  assert_eq 2026-10-08 "$(st_json 'd["commitments"][0]["date"]')" '/usr/bin/python3: same commitment as the tracer'
  assert_eq 0 "$(st_json 'd["lint"]["errors"]')" '/usr/bin/python3: the linter ran'
else
  skip '/usr/bin/python3 is absent: the older-interpreter rerun of the tracer did not run'
fi

# ---------------------------------------------------------------------------
echo '--- Exit codes ---'

NO="$WORK/nodossier"
mkdir -p "$NO"
run_st "$NO" --today "$TODAY"
assert_eq 2 "$ST_STATUS" 'no dossier.yaml upward: exit 2'
case "$ST_ERR" in
  'error: no dossier.yaml found from '*' upward') TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
  *) echo "FAIL: no-dossier message (got '$ST_ERR')" >&2; TESTS_FAILED=$((TESTS_FAILED + 1)) ;;
esac
assert_eq '' "$ST_OUT" 'no dossier.yaml upward: nothing on stdout'

run_st "$D" --today "$TODAY" "$D/missing-folder"
assert_eq 2 "$ST_STATUS" 'missing path: exit 2'
run_st "$D" --today 2026-02-30 "$D"
assert_eq 2 "$ST_STATUS" '--today 2026-02-30 (not a calendar date): exit 2'
run_st "$D" --today tomorrow "$D"
assert_eq 2 "$ST_STATUS" '--today tomorrow: exit 2'
run_st "$D" --today 2026-1-5 "$D"
assert_eq 2 "$ST_STATUS" '--today 2026-1-5 (not zero padded): exit 2'
run_st "$D" --bogus
assert_eq 2 "$ST_STATUS" 'unknown option: exit 2'

ST_STATUS=0
ST_ERR="$(python3 -I -B -c 'import importlib.util, sys
spec = importlib.util.spec_from_file_location("status_under_test", sys.argv[1])
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
def boom(args):
    raise RuntimeError("boom")
mod._run = boom
sys.exit(mod.main(["--json", sys.argv[2]]))' "$(st_script)" "$D" 2>&1 >/dev/null)" || ST_STATUS=$?
assert_eq 3 "$ST_STATUS" 'a failing _run: exit 3'
case "$ST_ERR" in
  'error: internal status failure'*) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
  *) echo "FAIL: exit 3 message (got '$ST_ERR')" >&2; TESTS_FAILED=$((TESTS_FAILED + 1)) ;;
esac

# ---------------------------------------------------------------------------
echo '--- Static: Python 3.8 grammar, standard library only, read-only, parity with lint.py ---'

script="$(st_script)"
STATUS=0
python3 -c 'import ast, sys; ast.parse(open(sys.argv[1]).read(), feature_version=(3, 8))' "$script" 2>/dev/null || STATUS=$?
assert_eq 0 "$STATUS" 'status.py parses with the Python 3.8 grammar'

STATUS=0
python3 - "$script" <<'PY' 2>/dev/null || STATUS=$?
import ast, sys
tree = ast.parse(open(sys.argv[1]).read())
allowed = {"argparse", "datetime", "json", "os", "re", "subprocess", "sys"}
bad = []
for node in ast.walk(tree):
    if isinstance(node, ast.Import):
        bad += [a.name for a in node.names if a.name not in allowed]
    elif isinstance(node, ast.ImportFrom):
        names = [a.name for a in node.names]
        if not (node.module == "pathlib" and names == ["Path"]):
            bad.append("from %s import %s" % (node.module, ",".join(names)))
if bad:
    print("disallowed imports:", bad)
    sys.exit(1)
PY
assert_eq 0 "$STATUS" 'status.py imports only the allowed standard library modules'

NEWER="$(grep -nE 'file_digest|removeprefix|removesuffix|is_relative_to|strict=|functools|@cache|\b(list|dict|tuple|set|frozenset)\[' "$script" || true)"
assert_eq '' "$NEWER" 'status.py uses none of the Python 3.9+ APIs'

STATUS=0
python3 - "$script" <<'PY' 2>/dev/null || STATUS=$?
import ast, sys
tree = ast.parse(open(sys.argv[1]).read())
writers = {"write_text", "write_bytes", "unlink", "rmdir", "mkdir", "makedirs",
           "rmtree", "touch"}
os_writers = {"remove", "rename", "replace", "chmod", "symlink", "link", "truncate"}
bad = []
for node in ast.walk(tree):
    if not isinstance(node, ast.Call):
        continue
    func = node.func
    if isinstance(func, ast.Name) and func.id == "open":
        mode = None
        if len(node.args) > 1 and isinstance(node.args[1], ast.Constant):
            mode = node.args[1].value
        for kw in node.keywords:
            if kw.arg == "mode" and isinstance(kw.value, ast.Constant):
                mode = kw.value.value
        if isinstance(mode, str) and any(c in mode for c in "wax+"):
            bad.append("open(..., %r)" % mode)
    elif isinstance(func, ast.Attribute) and func.attr in writers:
        bad.append("." + func.attr)
    elif (isinstance(func, ast.Attribute) and func.attr in os_writers
          and isinstance(func.value, ast.Name) and func.value.id == "os"):
        bad.append("os." + func.attr)
if bad:
    print("writes:", bad)
    sys.exit(1)
PY
assert_eq 0 "$STATUS" 'status.py opens no file for writing'

assert_eq 0 "$(grep -c 'environ' "$script")" 'status.py names no environment variable access'

STATUS=0
python3 - "$script" <<'PY' 2>/dev/null || STATUS=$?
import ast, sys
tree = ast.parse(open(sys.argv[1]).read())
bad = []
count = 0
for node in ast.walk(tree):
    if isinstance(node, ast.List) and node.elts:
        first = node.elts[0]
        if isinstance(first, ast.Constant) and first.value == "git":
            count += 1
            values = [e.value for e in node.elts if isinstance(e, ast.Constant)]
            if len(values) < 5 or values[1] != "--no-optional-locks" or "core.fsmonitor=false" not in values:
                bad.append(values)
if bad or count < 1:
    print("git literal problems:", count, bad)
    sys.exit(1)
PY
assert_eq 0 "$STATUS" 'every "git" list literal is followed by --no-optional-locks and carries core.fsmonitor=false'

assert_exec "$(st_script)"
assert_eq '#!/usr/bin/env python3' "$(head -1 "$(st_script)")" 'status.py starts with the python3 env shebang'
assert_grep 'parents\[3\]' "$(st_script)"

LINT_BLOCK="$(sed -n '/^def find_root/,/^    return None$/p' "$(lint_py)")"
assert_eq 14 "$(printf '%s\n' "$LINT_BLOCK" | wc -l | tr -d ' ')" 'lint.py find_root block is 14 lines'
ST_BLOCK="$(sed -n '/^def find_root/,/^    return None$/p' "$(st_script)")"
if [ -n "$ST_BLOCK" ]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo 'FAIL: status.py has no def find_root block' >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi
assert_eq "$LINT_BLOCK" "$ST_BLOCK" 'status.py find_root is byte-identical to scripts/lint.py'"'"'s'

STATUS=0
python3 - "$(lint_py)" "$script" <<'PY' 2>&1 || STATUS=$?
import ast, sys
NAMES = ["CONFIG_NAME", "LIVING_DIR", "LIVING_FILES", "OUTBOUND_DIR", "EXEMPT_PATHS",
         "OS_METADATA_NAMES", "GITKEEP", "BINARY_EXTS", "PROTOCOL_FIELDS",
         "STATUS_HEADER_WINDOW", "DEFAULT_STALENESS_DAYS", "_LAST_UPDATED_RE",
         "_DATE_PREFIX_RE", "_FIELD_RE"]
def values(path):
    out = {}
    for n in ast.parse(open(path).read()).body:
        if isinstance(n, ast.Assign) and len(n.targets) == 1 and isinstance(n.targets[0], ast.Name):
            out[n.targets[0].id] = ast.dump(n.value)
    return out
a, b = values(sys.argv[1]), values(sys.argv[2])
bad = [n for n in NAMES if n not in a or n not in b or a[n] != b[n]]
if bad:
    print("constants differing from lint.py:", bad)
    sys.exit(1)
PY
assert_eq 0 "$STATUS" 'the fourteen ported constants are AST-identical to lint.py'"'"'s'

# ---------------------------------------------------------------------------
# Task 2: commitments, upcoming items, overdue drafts, stale files, one-line status
# ---------------------------------------------------------------------------

# expect_commitments LABEL DIR EXPECTED — runs the report and compares
# "date:state:side" of every commitment, comma separated, to EXPECTED.
expect_commitments() {
  local label="$1" dir="$2" expected="$3"
  run_st "$dir" --json --today "$TODAY" "$dir"
  assert_eq 0 "$ST_STATUS" "$label: exit 0"
  assert_eq "$expected" "$(st_json '",".join(i["date"] + ":" + i["state"] + ":" + i["side"] for i in d["commitments"])')" "$label"
}

# reset_out DIR — an outbound/ folder holding only its README and .gitkeep files.
reset_out() {
  find "$1/outbound" -type f -o -type l | grep -v -e '/README.md$' -e '/\.gitkeep$' | while IFS= read -r f; do rm -f "$f"; done
}

# mk_out DIR REL STATUS DEADLINE — an outbound file with a status header; an
# empty DEADLINE writes no Deadline: line.
mk_out() {
  local d="$1" rel="$2" status="$3" deadline="$4"
  mkdir -p "$(dirname "$d/$rel")"
  {
    printf 'Status: %s\nTo: Jane Doe\nWritten by: Sam\n' "$status"
    if [ -n "$deadline" ]; then printf 'Deadline: %s\n' "$deadline"; fi
    printf '\nBody of the draft.\n'
  } >"$d/$rel"
}

echo '--- Commitments: the 7-day window and its edges ---'

D2="$(mk_dossier en)"
set_updated "$D2" 2026-10-10

write_history "$D2" '- Send the plan by 2026-10-11 (call @12:34).' '' ''
expect_commitments 'due today is due_soon, not overdue' "$D2" '2026-10-11:due_soon:ours'
write_history "$D2" '- Send the plan by 2026-10-18 (call @12:34).' '' ''
expect_commitments 'due in 7 days is due_soon' "$D2" '2026-10-18:due_soon:ours'
write_history "$D2" '- Send the plan by 2026-10-19 (call @12:34).' '' ''
expect_commitments 'due in 8 days is not reported' "$D2" ''
write_history "$D2" '- Send the plan by 2026-10-10 (call @12:34).' '' ''
expect_commitments 'due yesterday is overdue' "$D2" '2026-10-10:overdue:ours'
write_history "$D2" '- Send the plan (call 2026-10-01 @12:34).' '' ''
expect_commitments 'an undated line is not reported (the date inside its source does not count)' "$D2" ''
write_history "$D2" '' '- Jane sends the list by 2026-10-09 (mail 2026-10-01 from Jane).' ''
expect_commitments 'a line under the second ### is theirs' "$D2" '2026-10-09:overdue:theirs'
assert_eq Theirs "$(st_json 'd["commitments"][0]["heading"]')" 'theirs: the ### text is kept as the heading'
write_history "$D2" '* Send the plan by 2026-10-09 (call @12:34).' '' ''
expect_commitments 'a * bullet counts' "$D2" '2026-10-09:overdue:ours'
write_history "$D2" $'<!--\n- Send the plan by 2026-10-01 (call @12:34).\n-->' '' ''
expect_commitments 'a bullet inside a multi-line comment is ignored' "$D2" ''
write_history "$D2" $'```\n- Send the plan by 2026-10-01 (call @12:34).\n```' '' ''
expect_commitments 'a bullet inside a fenced block is ignored' "$D2" ''
write_history "$D2" '- On 2026-10-01 Jane promised the list by 2026-10-16 (mail 2026-10-01 from Jane).' '' ''
expect_commitments 'two dates: the LAST one outside the source is the due date' "$D2" '2026-10-16:due_soon:ours'
write_history "$D2" '- Send the plan by 2026-10-04, done 2026-10-05 (call @12:34).' '' ''
expect_commitments 'a line marked done <date> is skipped' "$D2" ''
write_history "$D2" '- Send the plan by 2026-10-04, Done 2026-10-05 (call @12:34).' '' ''
expect_commitments 'Done <date> is skipped too (case-insensitive)' "$D2" ''
write_history "$D2" '- Send the plan by 2026-10-04, done tomorrow (call @12:34).' '' ''
expect_commitments 'done without a real date does not skip the line' "$D2" '2026-10-04:overdue:ours'
write_history "$D2" $'- Send A by 2026-10-12 (call @1).\n- Send B by 2026-10-09 (call @2).' $'- Jane C by 2026-10-10 (mail 2026-10-01 from Jane).' ''
expect_commitments 'items are sorted by date' "$D2" '2026-10-09:overdue:ours,2026-10-10:overdue:theirs,2026-10-12:due_soon:ours'
assert_eq '[]' "$(st_json 'd["upcoming"]')" 'commitments never appear as upcoming items'

echo '--- Commitments citing an outbound draft (D-12) ---'

DRAFT_LINE="- 2026-10-01: draft mail 'x' written, to be sent by Sam, deadline 2026-10-20 (outbound/mails/2026-10-01_x.md)."
write_history "$D2" "$DRAFT_LINE" '' ''
reset_out "$D2"; mk_out "$D2" outbound/mails/2026-10-01_x.md draft 2026-10-09
expect_commitments 'a cited draft takes the file Deadline: (never the leading date)' "$D2" '2026-10-09:overdue:ours'
reset_out "$D2"; mk_out "$D2" outbound/mails/2026-10-01_x.md 'sent 2026-10-08 by Sam' 2026-10-09
expect_commitments 'a cited file that is sent gives nothing' "$D2" ''
reset_out "$D2"; mk_out "$D2" outbound/mails/2026-10-01_x.md 'reviewed by Sam' 2026-10-15
expect_commitments 'a cited reviewed-by draft with a deadline in 4 days is due_soon' "$D2" '2026-10-15:due_soon:ours'
reset_out "$D2"; mk_out "$D2" outbound/mails/2026-10-01_x.md draft ''
expect_commitments 'a cited draft without a deadline field gives nothing' "$D2" ''
reset_out "$D2"
expect_commitments 'a citation of a missing file falls back to the last date outside the source' "$D2" ''
assert_eq 1 "$(st_json 'len([n for n in d["notes"] if "outbound/mails/2026-10-01_x.md" in n])')" 'a missing cited file adds a note'
write_history "$D2" "- 2026-10-01: draft mail 'x' written, deadline 2026-10-09 (outbound/mails/2026-10-01_x.md)." '' ''
expect_commitments 'a missing cited file: the fallback date is overdue' "$D2" '2026-10-09:overdue:ours'
write_history "$D2" "- 2026-10-01: draft mail 'x' written, deadline 2026-10-09 (outbound/../dossier.yaml)." '' ''
expect_commitments 'outbound/../dossier.yaml is not read: fallback to the last date' "$D2" '2026-10-09:overdue:ours'
assert_eq 1 "$(st_json 'len([n for n in d["notes"] if "outbound/../dossier.yaml" in n])')" 'outbound/../ citation adds a note'
write_history "$D2" "- 2026-10-01: draft mail 'x' written, deadline 2026-10-09 (outbound/mails/2026-10-01_link.md)." '' ''
mkdir -p "$D2/outbound/mails"
printf 'Status: sent 2026-10-08 by Sam\nTo: x\nWritten by: Sam\nDeadline: 2026-10-30\n' >"$WORK/outside.md"
ln -s "$WORK/outside.md" "$D2/outbound/mails/2026-10-01_link.md"
expect_commitments 'a cited symlink is not read: fallback to the last date' "$D2" '2026-10-09:overdue:ours'
assert_eq 1 "$(st_json 'len([n for n in d["notes"] if "2026-10-01_link.md" in n])')" 'a cited symlink adds a note'
reset_out "$D2"

echo '--- Upcoming items ---'

write_history "$D2" '' '' $'- 2026-10-12: meeting with Jane (call @12:34).\n- 2026-10-01: old meeting (call @12:34).\n- 2026-10-19: far meeting (call @12:34).\n- 2026-10-11: kickoff (call @12:34).'
run_st "$D2" --json --today "$TODAY" "$D2"
assert_eq 0 "$ST_STATUS" 'upcoming: exit 0'
assert_eq '2026-10-11,2026-10-12' "$(st_json '",".join(i["date"] for i in d["upcoming"])')" 'upcoming: only 0..7 days, sorted'
assert_eq '[]' "$(st_json 'd["commitments"]')" 'upcoming: never in commitments, never overdue'
assert_eq dossier/HISTORY.md "$(st_json 'd["upcoming"][0]["file"]')" 'upcoming: file recorded'
mkdir -p "$D2/outbound/calls"
printf 'Status: draft\nTo: the counterpart\nWritten by: Sam\n\n# Call\n' >"$D2/outbound/calls/2026-10-12_pilot.md"
write_history "$D2" '' '' '- 2026-10-12: call with Jane (outbound/calls/2026-10-12_pilot.md).'
run_st "$D2" --json --today "$TODAY" "$D2"
assert_eq '2026-10-12' "$(st_json '",".join(i["date"] for i in d["upcoming"])')" 'upcoming: a cited call file without Deadline: falls back to the line date'
rm -rf "$D2/outbound/calls"

echo '--- A French dossier: same positions, no word list ---'

DF="$(mk_dossier fr)"
set_updated "$DF" 2026-10-10
write_history "$DF" '- Envoyer le devis avant le 2026-10-08 (appel @12:34).' '- Jane envoie la liste avant le 2026-10-15 (mail 2026-10-01 de Jane).' '- 2026-10-13 : réunion (appel @1).' fr
run_st "$DF" --json --today "$TODAY" "$DF"
assert_eq 0 "$ST_STATUS" 'fr: exit 0'
assert_eq '2026-10-08:overdue:ours,2026-10-15:due_soon:theirs' "$(st_json '",".join(i["date"] + ":" + i["state"] + ":" + i["side"] for i in d["commitments"])')" 'fr: ours and theirs by position'
assert_eq 'Les nôtres' "$(st_json 'd["commitments"][0]["heading"]')" 'fr: the ### text is the owner text (ours)'
assert_eq 'Les leurs' "$(st_json 'd["commitments"][1]["heading"]')" 'fr: the ### text is the owner text (theirs)'
assert_eq 1 "$(st_json 'len(d["upcoming"])')" 'fr: the third ## is the upcoming list'
printf '# Relation\n\nLast updated: 2026-10-10\n\n## État en une ligne\n\nSur les rails, livrable le 2026-10-20 (appel @12:34).\n\n## Chiffres\n' >"$DF/dossier/RELATIONSHIP.md"
run_st "$DF" --json --today "$TODAY" "$DF"
assert_eq 'Sur les rails, livrable le 2026-10-20 (appel @12:34).' "$(st_json 'd["status_line"]')" 'fr: the first ## of RELATIONSHIP.md gives the status line'

echo '--- Overdue drafts ---'

write_history "$D2" '' '' ''
expect_drafts() {
  local label="$1" expected="$2"
  run_st "$D2" --json --today "${3:-$TODAY}" "$D2"
  assert_eq 0 "$ST_STATUS" "$label: exit 0"
  assert_eq "$expected" "$(st_json '",".join(i["path"] for i in d["overdue_drafts"])')" "$label"
}
reset_out "$D2"
expect_drafts 'a fresh scaffold has no overdue draft' ''
mk_out "$D2" outbound/mails/2026-10-01_a.md draft 2026-10-10
expect_drafts 'draft with a past deadline is reported' 'outbound/mails/2026-10-01_a.md'
assert_eq draft "$(st_json 'd["overdue_drafts"][0]["status"]')" 'overdue draft: status kept'
assert_eq 2026-10-10 "$(st_json 'd["overdue_drafts"][0]["deadline"]')" 'overdue draft: deadline kept'
reset_out "$D2"; mk_out "$D2" outbound/mails/2026-10-01_a.md 'reviewed by Sam' 2026-10-10
expect_drafts 'reviewed by with a past deadline is reported' 'outbound/mails/2026-10-01_a.md'
reset_out "$D2"; mk_out "$D2" outbound/mails/2026-10-01_a.md 'sent 2026-10-09 by Sam' 2026-10-05
expect_drafts 'a sent file is not reported' ''
reset_out "$D2"; mk_out "$D2" outbound/mails/2026-10-01_a.md draft ''
expect_drafts 'no deadline field is not reported' ''
reset_out "$D2"; mk_out "$D2" outbound/mails/2026-10-01_a.md draft 2026-10-11
expect_drafts 'a deadline of today is not reported' ''
reset_out "$D2"
printf 'Status: draft\nTo: Jane\nWritten by: Sam\nl4\nl5\nl6\nl7\nl8\nl9\nl10\nDeadline: 2026-10-01\n' >"$D2/outbound/mails/2026-10-01_a.md"
expect_drafts 'a Deadline: on line 11 is outside the header window' ''
reset_out "$D2"; mk_out "$D2" outbound/mails/2026-10-01_a.md draft 2026-10-01
printf 'Status: draft\nDeadline: 2026-10-01\n' >"$D2/outbound/README.md"
printf 'x' >"$D2/outbound/mails/2026-10-01_b.pdf"
expect_drafts 'outbound/README.md and a .pdf are skipped' 'outbound/mails/2026-10-01_a.md'
git -C "$D2" checkout -q -- outbound/README.md 2>/dev/null
ln -s "$D2/outbound/mails/2026-10-01_a.md" "$D2/outbound/mails/2026-10-01_c.md"
expect_drafts 'a symlinked outbound file is not followed' 'outbound/mails/2026-10-01_a.md'
reset_out "$D2"; mk_out "$D2" outbound/calls/2026-10-01_x.md 'sent 2026-10-02 by Sam' ''
printf 'Status: draft\nTo: Jane\nWritten by: Sam\n\nCall prep.\n' >"$D2/outbound/calls/2026-10-01_y.md"
expect_drafts 'a call file without a deadline is never reported (even in 2027)' '' 2027-01-01
reset_out "$D2"; mk_out "$D2" outbound/mails/2026-10-02_z.md draft 2026-10-09; mk_out "$D2" outbound/deliverables/2026-10-01_a.md draft 2026-10-05
expect_drafts 'drafts are sorted by deadline then path' 'outbound/deliverables/2026-10-01_a.md,outbound/mails/2026-10-02_z.md'
reset_out "$D2"

echo '--- Stale living files and staleness_days ---'

# set_one DIR FILE DATE — one living file says `Last updated: DATE`.
set_one() {
  python3 -I -c 'import os, re, sys
p = os.path.join(sys.argv[1], "dossier", sys.argv[2])
t = open(p, encoding="utf-8").read()
open(p, "w", encoding="utf-8").write(re.sub(r"(?m)^Last updated:.*$", "Last updated: " + sys.argv[3], t, count=1))' "$1" "$2" "$3"
}
# set_cfg DIR LINE — the staleness_days line of dossier.yaml becomes LINE.
set_cfg() {
  python3 -I -c 'import os, re, sys
p = os.path.join(sys.argv[1], "dossier.yaml")
t = open(p, encoding="utf-8").read()
open(p, "w", encoding="utf-8").write(re.sub(r"(?m)^staleness_days:.*$", lambda m: sys.argv[2], t))' "$1" "$2"
}
expect_stale() {
  local label="$1" expected="$2"
  run_st "$D2" --json --today "$TODAY" "$D2"
  assert_eq 0 "$ST_STATUS" "$label: exit 0"
  assert_eq "$expected" "$(st_json '",".join(i["path"] + ":" + str(i["days"]) for i in d["stale_files"])')" "$label"
}
set_updated "$D2" 2026-10-10
expect_stale 'files updated yesterday are not stale' ''
assert_eq 7 "$(st_json 'd["staleness_days"]')" 'default staleness_days is 7'
set_one "$D2" ACTORS.md 2026-10-03
expect_stale '8 days old is stale (default 7)' 'dossier/ACTORS.md:8'
assert_eq 2026-10-03 "$(st_json 'd["stale_files"][0]["last_updated"]')" 'stale: last_updated kept'
set_one "$D2" ACTORS.md 2026-10-04
expect_stale '7 days old is not stale' ''
set_updated "$D2" 2026-10-07
set_cfg "$D2" 'staleness_days: 3'
expect_stale 'staleness_days: 3 makes 4-day-old files stale' 'dossier/ACTORS.md:4,dossier/CHANNELS.md:4,dossier/HISTORY.md:4,dossier/LEARNINGS.md:4,dossier/OPEN-QUESTIONS.md:4,dossier/RELATIONSHIP.md:4,dossier/TONE.md:4'
assert_eq 3 "$(st_json 'd["staleness_days"]')" 'staleness_days: 3 is reported'
set_cfg "$D2" 'staleness_days: "3"'
assert_eq 3 "$(run_st "$D2" --json --today "$TODAY" "$D2"; st_json 'd["staleness_days"]')" 'a quoted staleness_days works'
set_cfg "$D2" 'staleness_days: 3   # three days'
assert_eq 3 "$(run_st "$D2" --json --today "$TODAY" "$D2"; st_json 'd["staleness_days"]')" 'a trailing comment after staleness_days is ignored'
set_cfg "$D2" 'staleness_days: x'
run_st "$D2" --json --today "$TODAY" "$D2"
assert_eq 7 "$(st_json 'd["staleness_days"]')" 'staleness_days: x gives 7'
assert_eq 1 "$(st_json 'len([n for n in d["notes"] if "staleness_days" in n])')" 'staleness_days: x adds a note'
set_cfg "$D2" 'staleness_days: 0'
run_st "$D2" --json --today "$TODAY" "$D2"
assert_eq 7 "$(st_json 'd["staleness_days"]')" 'staleness_days: 0 gives 7'
assert_eq 1 "$(st_json 'len([n for n in d["notes"] if "staleness_days" in n])')" 'staleness_days: 0 adds a note'
printf '{"version": 1, "language": "en", "staleness_days": 3}\n' >"$D2/dossier.yaml"
run_st "$D2" --json --today "$TODAY" "$D2"
assert_eq 3 "$(st_json 'd["staleness_days"]')" 'a JSON dossier.yaml works'
git -C "$D2" checkout -q -- dossier.yaml
printf 'version: 1\nlanguage: en\n' >"$D2/dossier.yaml"
run_st "$D2" --json --today "$TODAY" "$D2"
assert_eq 7 "$(st_json 'd["staleness_days"]')" 'a missing staleness_days gives 7'
assert_eq 1 "$(st_json 'len([n for n in d["notes"] if "staleness_days" in n])')" 'a missing staleness_days adds a note'
git -C "$D2" checkout -q -- dossier.yaml
set_updated "$D2" 2026-10-10
set_one "$D2" TONE.md 2026-10-20
expect_stale 'a future Last updated: is not stale' ''
assert_eq 1 "$(st_json 'len([n for n in d["notes"] if "future" in n])')" 'a future Last updated: adds a note'
set_updated "$D2" 2026-10-10
rm -f "$D2/dossier/CHANNELS.md"
expect_stale 'a missing living file is not stale' ''
assert_eq 1 "$(st_json 'len([n for n in d["notes"] if "CHANNELS.md" in n])')" 'a missing living file adds a note'
git -C "$D2" checkout -q -- dossier/CHANNELS.md

echo '--- The one-line status ---'

DS="$(mk_dossier en)"
run_st "$DS" --json --today "$TODAY" "$DS"
assert_eq None "$(st_json 'd["status_line"]')" 'the init.py template (example in a comment) gives null'
run_st "$DS" --today "$TODAY" "$DS"
case "$ST_OUT" in
  *'One-line status: none recorded'*) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
  *) echo 'FAIL: text mode: One-line status: none recorded' >&2; TESTS_FAILED=$((TESTS_FAILED + 1)) ;;
esac
python3 -I -c 'import re, sys
p = sys.argv[1]
t = open(p, encoding="utf-8").read()
t = t.replace("## Status in one line\n", "## Status in one line\n\nOn track, deliverable due 2026-10-20, no blockers (call @12:34).\n", 1)
open(p, "w", encoding="utf-8").write(t)' "$DS/dossier/RELATIONSHIP.md"
run_st "$DS" --json --today "$TODAY" "$DS"
assert_eq 'On track, deliverable due 2026-10-20, no blockers (call @12:34).' "$(st_json 'd["status_line"]')" 'a line under ## Status in one line is returned verbatim'
run_st "$DS" --today "$TODAY" "$DS"
case "$ST_OUT" in
  *'One-line status: On track, deliverable due 2026-10-20'*) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
  *) echo 'FAIL: text mode: the status line is printed' >&2; TESTS_FAILED=$((TESTS_FAILED + 1)) ;;
esac

# ---------------------------------------------------------------------------
# Task 3: unreflected sources from git and mtimes, lint variants, read-only, escaping
# ---------------------------------------------------------------------------

# commit_at DIR DATE MSG — stage everything and commit with author and committer
# dates DATE at noon local time.
commit_at() {
  GIT_AUTHOR_DATE="$2T12:00:00" GIT_COMMITTER_DATE="$2T12:00:00" git -C "$1" add -A >/dev/null 2>&1
  GIT_AUTHOR_DATE="$2T12:00:00" GIT_COMMITTER_DATE="$2T12:00:00" git -C "$1" commit -q -m "$3" >/dev/null 2>&1
}

# mtime_at FILE YYYYMMDD — the file's modification time becomes that day, noon.
mtime_at() {
  touch -t "${2}1200" "$1"
}

# mk_src DIR REL YYYYMMDD — a source file with that mtime.
mk_src() {
  mkdir -p "$(dirname "$1/$2")"
  printf 'content of %s\n' "$2" >"$1/$2"
  mtime_at "$1/$2" "$3"
}

# expect_sources LABEL DIR EXPECTED — "path:filed:how" of every unreflected source.
expect_sources() {
  local label="$1" dir="$2" expected="$3"
  run_st "$dir" --json --today "$TODAY" "$dir"
  assert_eq 0 "$ST_STATUS" "$label: exit 0"
  assert_eq "$expected" "$(st_json '",".join(i["path"] + ":" + i["filed"] + ":" + i["how"] for i in d["unreflected_sources"])')" "$label"
}

echo '--- Unreflected sources (D-04) ---'

DG="$(mk_dossier en)"
set_updated "$DG" 2026-10-05
commit_at "$DG" 2026-10-04 'living files updated'
expect_sources 'a clean scaffold has no unreflected source' "$DG" ''
assert_eq 2026-10-05 "$(st_json 'd["last_reflected"]')" 'last_reflected is the newest Last updated: date'

mk_src "$DG" sources/received/2026-10-06_a.txt 20261006
commit_at "$DG" 2026-10-06 'file a'
expect_sources 'a source committed after the last update is reported (how git)' "$DG" 'sources/received/2026-10-06_a.txt:2026-10-06:git'

DG="$(mk_dossier en)"
set_updated "$DG" 2026-10-05
mk_src "$DG" sources/received/2026-10-05_b.txt 20261005
commit_at "$DG" 2026-10-05 'file b'
expect_sources 'a source filed the same day as the last update is not reported (strictly later only)' "$DG" ''

DG="$(mk_dossier en)"
set_updated "$DG" 2026-10-05
mk_src "$DG" sources/received/2026-10-04_c.txt 20261004
commit_at "$DG" 2026-10-06 'file c, committed late'
expect_sources 'commit lag: mtime 2026-10-04, committed 2026-10-06, is not a false positive (min of both)' "$DG" ''

DG="$(mk_dossier en)"
set_updated "$DG" 2026-10-05
mk_src "$DG" sources/received/2026-10-01_d.txt 20261001
commit_at "$DG" 2026-10-01 'file d'
git -C "$DG" mv sources/received/2026-10-01_d.txt sources/received/2026-10-07_e.txt
mtime_at "$DG/sources/received/2026-10-07_e.txt" 20261007
commit_at "$DG" 2026-10-07 'rename d to e'
expect_sources 'a renamed source counts as an add at the rename commit' "$DG" 'sources/received/2026-10-07_e.txt:2026-10-07:git'

DG="$(mk_dossier en)"
set_updated "$DG" 2026-10-05
commit_at "$DG" 2026-10-05 'living files'
mk_src "$DG" sources/received/2026-10-09_f.txt 20261001
expect_sources 'an untracked source is filed today (how untracked), whatever its mtime' "$DG" "sources/received/2026-10-09_f.txt:$TODAY:untracked"
git -C "$DG" add sources/received/2026-10-09_f.txt
expect_sources 'a staged but never committed source is filed today too' "$DG" "sources/received/2026-10-09_f.txt:$TODAY:untracked"

DG="$(mk_dossier en)"
set_updated "$DG" 2026-10-05
mk_src "$DG" sources/received/2026-10-08_g.txt 20261008
mk_src "$DG" sources/README.md 20261008
mk_src "$DG" sources/received/.gitkeep 20261008
mk_src "$DG" sources/received/.DS_Store 20261008
commit_at "$DG" 2026-10-08 'noise after the max date'
expect_sources 'sources/README.md, .gitkeep and .DS_Store are never reported' "$DG" 'sources/received/2026-10-08_g.txt:2026-10-08:git'

DG="$(mk_dossier en)"
set_updated "$DG" 2026-10-05
printf 'sources/received/ignored.txt\n' >"$DG/.gitignore"
commit_at "$DG" 2026-10-05 'gitignore'
mk_src "$DG" sources/received/ignored.txt 20261008
expect_sources 'a git-ignored source uses its mtime date (how mtime)' "$DG" 'sources/received/ignored.txt:2026-10-08:mtime'

DN="$WORK/notgit"
mkdir -p "$DN"
python3 "$(init_py)" --target "$DN" --language en >/dev/null 2>&1
set_updated "$DN" 2026-10-05
mk_src "$DN" sources/received/2026-10-09_h.txt 20261009
mk_src "$DN" sources/received/2026-10-02_old.txt 20261002
expect_sources 'outside a git repository every source uses its mtime date' "$DN" 'sources/received/2026-10-09_h.txt:2026-10-09:mtime'
assert_eq 1 "$(st_json 'len([n for n in d["notes"] if "git" in n])')" 'outside a git repository a note says git was not available'

DR="$WORK/bigrepo"
mkdir -p "$DR/clients/acme"
git init -q "$DR"
git -C "$DR" config user.email "test@example.invalid"
git -C "$DR" config user.name "Test Runner"
printf 'other project\n' >"$DR/README.md"
python3 "$(init_py)" --target "$DR/clients/acme" --language en >/dev/null 2>&1
set_updated "$DR/clients/acme" 2026-10-05
commit_at "$DR" 2026-10-04 'repo with a nested dossier'
mk_src "$DR/clients/acme" sources/received/2026-10-06_n.txt 20261006
commit_at "$DR" 2026-10-06 'nested source'
expect_sources 'a dossier nested in a larger repository reports root-relative paths with git dates' "$DR/clients/acme" 'sources/received/2026-10-06_n.txt:2026-10-06:git'
assert_eq "$DR/clients/acme" "$(st_json 'd["root"]')" 'nested dossier: the root is the folder holding dossier.yaml'

DG="$(mk_dossier en)"
python3 -I -c 'import glob, re, sys
for p in glob.glob(sys.argv[1] + "/dossier/*.md"):
    t = open(p, encoding="utf-8").read()
    open(p, "w", encoding="utf-8").write(re.sub(r"(?m)^Last updated:.*$", "Last updated: soon", t, count=1))' "$DG"
commit_at "$DG" 2026-10-04 'no valid dates'
mk_src "$DG" sources/received/2026-10-02_i.txt 20261002
commit_at "$DG" 2026-10-02 'file i'
expect_sources 'no valid Last updated: date anywhere: every source is reported' "$DG" 'sources/received/2026-10-02_i.txt:2026-10-02:git'
assert_eq None "$(st_json 'd["last_reflected"]')" 'no valid Last updated: date: last_reflected is null'
assert_eq 1 "$(st_json 'len([n for n in d["notes"] if "Last updated" in n and "every source" in n])')" 'no valid Last updated: date: a note says why'

echo '--- The linter variants (D-02, D-12) ---'

DL="$(mk_dossier en)"
set_updated "$DL" 2026-10-10
run_st "$DL" --json --today "$TODAY" --lint /nonexistent/lint.py "$DL"
assert_eq 0 "$ST_STATUS" '--lint of an absent file: exit 0'
assert_eq False "$(st_json 'd["lint"]["available"]')" '--lint of an absent file: available false'
assert_eq None "$(st_json 'd["lint"]["exit"]')" '--lint of an absent file: exit null'
run_st "$DL" --today "$TODAY" --lint /nonexistent/lint.py "$DL"
case "$ST_OUT" in
  *'Lint: unavailable'*) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
  *) echo 'FAIL: text mode: Lint: unavailable' >&2; TESTS_FAILED=$((TESTS_FAILED + 1)) ;;
esac

BARE="$WORK/bare"
mkdir -p "$BARE/skills/dossier-status/scripts"
cp "$(st_script)" "$BARE/skills/dossier-status/scripts/status.py"
ST_STATUS=0
ST_OUT="$(cd "$DL" && CLAUDE_PLUGIN_ROOT="$REPO_ROOT" python3 "$BARE/skills/dossier-status/scripts/status.py" --json --today "$TODAY" "$DL" 2>"$ERRDIR/err")" || ST_STATUS=$?
assert_eq 0 "$ST_STATUS" 'bare-skills layout: exit 0'
assert_eq False "$(st_json 'd["lint"]["available"]')" 'bare-skills layout: no scripts/lint.py beside the skills, so lint is unavailable'
assert_eq False "$(st_json 'd["lint"]["available"]')" 'bare-skills layout: the exported plugin-root variable is never read'

mk_out "$DL" outbound/mails/2026-10-01_nohdr.md draft ''
printf 'Hello, no status block here.\n' >"$DL/outbound/mails/2026-10-01_nohdr.md"
run_st "$DL" --json --today "$TODAY" "$DL"
assert_eq True "$(st_json 'd["lint"]["errors"] >= 1')" 'lint: an outbound mail without a status block gives at least one error'
assert_eq True "$(st_json 'any(f["id"].startswith("E") and f["path"].startswith("outbound/") for f in d["lint"]["findings"])')" 'lint: a finding with an E identifier under outbound/ is parsed'
assert_eq 1 "$(st_json 'd["lint"]["exit"]')" 'lint: exit 1 when there is an error'
rm -f "$DL/outbound/mails/2026-10-01_nohdr.md"

STUB="$WORK/stub-lint.py"
printf 'import sys\nsys.exit(3)\n' >"$STUB"
run_st "$DL" --json --today "$TODAY" --lint "$STUB" "$DL"
assert_eq 0 "$ST_STATUS" 'a stub linter exiting 3: status still exits 0'
assert_eq True "$(st_json 'd["lint"]["available"]')" 'a stub linter exiting 3: available true'
assert_eq 3 "$(st_json 'd["lint"]["exit"]')" 'a stub linter exiting 3: exit 3 recorded'
assert_eq None "$(st_json 'd["lint"]["errors"]')" 'a stub linter exiting 3: counts null'
assert_eq 1 "$(st_json 'len([n for n in d["notes"] if "lint could not run" in n])')" 'a stub linter exiting 3: a note'
run_st "$DL" --today "$TODAY" --lint "$STUB" "$DL"
case "$ST_OUT" in
  *'Lint: did not run'*) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
  *) echo 'FAIL: text mode: Lint: did not run' >&2; TESTS_FAILED=$((TESTS_FAILED + 1)) ;;
esac
printf 'import sys\nsys.exit(2)\n' >"$STUB"
run_st "$DL" --json --today "$TODAY" --lint "$STUB" "$DL"
assert_eq 2 "$(st_json 'd["lint"]["exit"]')" 'a stub linter exiting 2: exit 2 recorded'
assert_eq 1 "$(st_json 'len([n for n in d["notes"] if "lint could not run" in n])')" 'a stub linter exiting 2: a note'
printf 'print("info: something to know")\nprint("outbound/mails/x.md:3: ERROR [E2] a: b")\nprint("dossier/A.md:0: WARNING [W2] c")\nprint("1 error(s), 1 warning(s)")\nimport sys\nsys.exit(1)\n' >"$STUB"
run_st "$DL" --json --today "$TODAY" --lint "$STUB" "$DL"
assert_eq '1,1,2' "$(st_json '",".join(str(x) for x in (d["lint"]["errors"], d["lint"]["warnings"], len(d["lint"]["findings"])))')" 'a stub report: summary and findings are parsed'
assert_eq 'outbound/mails/x.md:3:ERROR:E2:a: b' "$(st_json 'd["lint"]["findings"][0]["path"] + ":" + str(d["lint"]["findings"][0]["line"]) + ":" + d["lint"]["findings"][0]["severity"] + ":" + d["lint"]["findings"][0]["id"] + ":" + d["lint"]["findings"][0]["message"]')" 'a stub report: a finding is split into path, line, severity, id, message'
assert_eq '["something to know"]' "$(st_json 'd["lint"]["info"]')" 'a stub report: info lines are kept'
run_st "$DL" --today "$TODAY" --lint "$STUB" "$DL"
case "$ST_OUT" in
  *'Lint: 1 error(s), 1 warning(s)'*'outbound/mails/x.md:3: ERROR [E2] a: b'*) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
  *) echo 'FAIL: text mode: the lint summary then its findings' >&2; TESTS_FAILED=$((TESTS_FAILED + 1)) ;;
esac

echo '--- Read-only: the dossier and its .git are byte-identical after a run ---'

# tree_sha DIR — one sha256 over every regular file under DIR, .git included
# (relative path and content, sorted); logic copied from lib-scenario.sh.
tree_sha() {
  python3 -I -c '
import hashlib, os, sys
root = sys.argv[1]
digest = hashlib.sha256()
for base, dirs, files in os.walk(root):
    dirs.sort()
    for name in sorted(files):
        path = os.path.join(base, name)
        digest.update(os.path.relpath(path, root).encode("utf-8", "surrogateescape") + b"\0")
        try:
            with open(path, "rb") as fh:
                digest.update(hashlib.sha256(fh.read()).hexdigest().encode())
        except OSError:
            digest.update(b"UNREADABLE")
        digest.update(b"\n")
print(digest.hexdigest())
' "$1"
}

DX="$(mk_dossier en)"
set_updated "$DX" 2026-10-05
mk_src "$DX" sources/received/2026-10-03_old.txt 20261003
mk_out "$DX" outbound/mails/2026-10-01_a.md draft 2026-10-02
write_history "$DX" '- Send the plan by 2026-10-04 (call @12:34).' '' ''
commit_at "$DX" 2026-10-06 'backdated commit'
mtime_at "$DX/dossier/HISTORY.md" 20260901
mk_src "$DX" sources/received/2026-10-10_new.txt 20261010
git -C "$DX" status --short >/dev/null 2>&1
BEFORE="$(tree_sha "$DX")"
run_st "$DX" --json --today "$TODAY" "$DX"
assert_eq 0 "$ST_STATUS" 'read-only: JSON run exit 0'
assert_eq "$BEFORE" "$(tree_sha "$DX")" 'read-only: tree (with .git) identical after --json'
run_st "$DX" --today "$TODAY" "$DX"
assert_eq 0 "$ST_STATUS" 'read-only: text run exit 0'
assert_eq "$BEFORE" "$(tree_sha "$DX")" 'read-only: tree (with .git) identical after text mode'
assert_eq 1 "$(printf '%s\n' "$ST_OUT" | grep -c 'sources/received/2026-10-10_new.txt')" 'read-only: the untracked source was reported in that run'
assert_eq 0 "$(find "$(dirname "$(st_script)")" -name '__pycache__' | wc -l | tr -d ' ')" 'no __pycache__ folder appeared beside the script'

echo '--- Escaping: no raw control character reaches stdout ---'

DE="$(mk_dossier en)"
set_updated "$DE" 2026-10-05
commit_at "$DE" 2026-10-05 'living files'
BELL="$(printf '2026-10-09_bell\007x.txt')"
mk_src "$DE" "sources/received/$BELL" 20261009
ESC="$(printf '\033')"
write_history "$DE" "- Send the plan by 2026-10-09 ${ESC}[31mred (call @12:34)." '' ''
run_st "$DE" --today "$TODAY" "$DE"
assert_eq 0 "$ST_STATUS" 'escaping: text run exit 0'
assert_eq 0 "$(printf '%s' "$ST_OUT" | python3 -I -c 'import sys
d = sys.stdin.buffer.read()
print(sum(1 for b in d if b < 0x20 and b != 10))')" 'escaping: no byte below 0x20 other than the newline in text mode'
case "$ST_OUT" in
  *'\x07'*) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
  *) echo 'FAIL: escaping: the bell is printed as \x07' >&2; TESTS_FAILED=$((TESTS_FAILED + 1)) ;;
esac
case "$ST_OUT" in
  *'\x1b[31mred'*) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
  *) echo 'FAIL: escaping: the ESC of a commitment line is printed as \x1b' >&2; TESTS_FAILED=$((TESTS_FAILED + 1)) ;;
esac
run_st "$DE" --json --today "$TODAY" "$DE"
assert_eq 0 "$ST_STATUS" 'escaping: JSON run exit 0'
assert_eq 0 "$(printf '%s' "$ST_OUT" | python3 -I -c 'import sys
d = sys.stdin.buffer.read()
print(sum(1 for b in d if (b < 0x20 or b > 0x7e) and b != 10))')" 'escaping: the JSON is pure printable ASCII'
assert_eq 1 "$(st_json 'len([i for i in d["unreflected_sources"] if "bell" in i["path"]])')" 'escaping: the bell-named source is still reported (and parsed back from the JSON)'

echo '--- Static: bounded, prefixed, scoped subprocesses ---'

assert_grep '--no-renames' "$(st_script)"
assert_grep 'core.fsmonitor=false' "$(st_script)"
assert_grep_e 'README_NAME' "$(st_script)"
assert_eq 1 "$([ "$(grep -c 'timeout' "$(st_script)")" -ge 2 ] && echo 1 || echo 0)" 'status.py names a timeout for git and for lint'

finish
