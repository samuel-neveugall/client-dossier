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

finish
