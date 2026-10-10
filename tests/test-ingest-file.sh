#!/usr/bin/env bash
# tests/test-ingest-file.sh — INGEST-01 (filing side) and INGEST-04, with the
# decisions D-01 (content date in the name), D-04 (filing goes through a
# script, never the Write tool), D-06 (stateless dedup by sha256) and D-07
# (the folder follows --kind). Plan 04-01.
#
# The first case is the phase's TRACER: the filing command exactly as the
# skill will issue it is fed to the REAL hooks/guard-sources.py (it must be
# let through in silence), then executed in a dossier scaffolded by the REAL
# init.py. Every later case hardens the same script.
#
# No model, no network. bash 3.2, no arrays.
set -u

# shellcheck source=./lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# fs_script — the script under test, by absolute path (the bash harness has no
# ${CLAUDE_SKILL_DIR} expansion; see init_py in lib.sh).
fs_script() {
  echo "$REPO_ROOT/skills/dossier-ingest/scripts/file_source.py"
}

# The last run_fs run: stdout, stderr and exit status. Initialised for set -u.
FS_OUT=""
FS_ERR=""
FS_STATUS=0

# ERRDIR holds the stderr captures, outside every dossier (and outside any
# TMPDIR a case points into the dossier).
ERRDIR="$(mktemp -d)"
trap 'rm -rf "$ERRDIR"' EXIT

# run_fs DIR ARG... — runs the script from DIR with a 30 s watchdog (a
# refusal that opened a FIFO would otherwise hang the suite). stderr goes
# through a file under ERRDIR, never a file beside the dossier.
run_fs() {
  local dir="$1" err_file="$ERRDIR/err"
  shift
  FS_STATUS=0
  if command -v perl >/dev/null 2>&1; then
    FS_OUT="$(cd "$dir" && perl -e 'alarm 30; exec @ARGV' python3 "$(fs_script)" "$@" 2>"$err_file")" || FS_STATUS=$?
  else
    FS_OUT="$(cd "$dir" && python3 "$(fs_script)" "$@" 2>"$err_file")" || FS_STATUS=$?
  fi
  FS_ERR="$(cat "$err_file")"
}

# fs_field KEY — the value of KEY in FS_OUT. `invalid` when FS_OUT is not
# exactly one JSON object, `none` when the key is absent; a list is printed
# as JSON.
fs_field() {
  printf '%s' "$FS_OUT" | python3 -c 'import json, sys
text = sys.stdin.read()
try:
    value = json.loads(text)
    if not isinstance(value, dict):
        raise ValueError("not an object")
except Exception:
    print("invalid")
    sys.exit(0)
v = value.get(sys.argv[1], "none")
print(json.dumps(v) if isinstance(v, (list, dict)) else v)' "$1"
}

# check_json LABEL — the contract that holds on every path: one JSON object,
# ASCII only, nothing on stderr.
check_json() {
  local label="$1" status=0
  case "$(fs_field status)" in
    invalid)
      echo "FAIL: $label (stdout is not exactly one JSON object: '$FS_OUT')" >&2
      TESTS_FAILED=$((TESTS_FAILED + 1))
      ;;
    *) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
  esac
  printf '%s' "$FS_OUT" | python3 -c 'import sys; sys.stdin.buffer.read().decode("ascii")' 2>/dev/null || status=$?
  assert_eq 0 "$status" "$label: stdout is ASCII only"
  assert_eq '' "$FS_ERR" "$label: empty stderr"
}

# expect_ok LABEL STATUS — exit 0 and the given status value.
expect_ok() {
  local label="$1" want="$2"
  check_json "$label"
  assert_eq 0 "$FS_STATUS" "$label: exit 0"
  assert_eq "$want" "$(fs_field status)" "$label: status is $want"
}

# expect_error LABEL CODE [EXIT] — exit EXIT (default 1) and the error code.
expect_error() {
  local label="$1" code="$2" exit_code="${3:-1}"
  check_json "$label"
  assert_eq "$exit_code" "$FS_STATUS" "$label: exit $exit_code"
  assert_eq error "$(fs_field status)" "$label: status is error"
  assert_eq "$code" "$(fs_field error)" "$label: error code is $code"
}

# sha_of FILE — the sha256 of a file, by python3 (portable).
sha_of() {
  python3 -c 'import hashlib, sys
print(hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest())' "$1"
}

# size_of FILE — the size in bytes.
size_of() {
  wc -c <"$1" | tr -d ' '
}

# build_dossier — a scaffolded dossier (real init.py) in a scratch git repo,
# holding incoming/Call transcript.txt outside sources/. Echoes its path.
build_dossier() {
  local target
  target="$(scratch_repo)"
  python3 "$(init_py)" --target "$target" --language en \
    --counterpart 'Acme Consulting|ordering party|Jane Doe' >/dev/null 2>&1
  mkdir -p "$target/incoming"
  printf '%s\n' '@00:12 Jane Doe: We need the report by 2026-10-20.' \
    '@00:41 Sam: Understood, I will send a draft on 2026-10-15.' \
    '@01:03 Jane Doe: Good, the budget stays at 4000 EUR.' \
    >"$target/incoming/Call transcript.txt"
  echo "$target"
}

TODAY="$(date +%F)"

# ---------------------------------------------------------------------------
echo '--- Tracer: the skill command passes the real guard and files a transcript ---'

d="$(build_dossier)"
INCOMING="$d/incoming/Call transcript.txt"
INCOMING_SHA="$(sha_of "$INCOMING")"
INCOMING_SIZE="$(size_of "$INCOMING")"
cmd="\"$(fs_script)\" --kind transcript --date 2026-10-10 --slug 'Kickoff call' \"incoming/Call transcript.txt\""

run_hook guard-sources.py "$(hook_json PreToolUse "$d" Bash command "$cmd")"
assert_eq 0 "$HOOK_STATUS" 'tracer: the real guard exits 0 on the filing command'
assert_eq '' "$HOOK_OUT" 'tracer: the real guard stays silent (no decision)'
assert_eq '' "$HOOK_ERR" 'tracer: the real guard prints nothing on stderr'

FS_STATUS=0
err_file="$(mktemp)"
FS_OUT="$(cd "$d" && bash -c "$cmd" 2>"$err_file")" || FS_STATUS=$?
FS_ERR="$(cat "$err_file")"
rm -f "$err_file"
expect_ok 'tracer: the exact command line' filed
assert_eq 'sources/transcripts/2026-10-10_kickoff-call.txt' "$(fs_field path)" 'tracer: path is sources/transcripts/<date>_<slug>.txt'
assert_eq "$INCOMING_SHA" "$(fs_field sha256)" 'tracer: sha256 is the incoming file'"'"'s'
assert_eq "$INCOMING_SIZE" "$(fs_field bytes)" 'tracer: bytes is the incoming size'
FILED="$d/sources/transcripts/2026-10-10_kickoff-call.txt"
assert_file "$FILED"
cmp -s "$INCOMING" "$FILED"
assert_eq 0 "$?" 'tracer: the filed file is byte-identical to the incoming one'
assert_eq "$INCOMING_SHA" "$(sha_of "$INCOMING")" 'tracer: the incoming file is unchanged'

# ---------------------------------------------------------------------------
echo '--- Kind decides the folder (D-07) ---'

d="$(build_dossier)"
run_fs "$d" --kind received --date 2026-10-01 --slug brochure "incoming/Call transcript.txt"
expect_ok 'kind received' filed
assert_eq 'sources/received/2026-10-01_brochure.txt' "$(fs_field path)" 'received -> sources/received/'
assert_file "$d/sources/received/2026-10-01_brochure.txt"

d="$(build_dossier)"
run_fs "$d" --kind raw --date 2026-10-10 --slug kickoff-call "incoming/Call transcript.txt"
expect_ok 'kind raw' filed
assert_eq 'sources/transcripts/raw/2026-10-10_kickoff-call.txt' "$(fs_field path)" 'raw -> sources/transcripts/raw/'
assert_file "$d/sources/transcripts/raw/2026-10-10_kickoff-call.txt"

# ---------------------------------------------------------------------------
echo '--- Date (D-01): the filing date when --date is absent ---'

d="$(build_dossier)"
run_fs "$d" --kind received --slug mail "incoming/Call transcript.txt"
expect_ok 'no --date' filed
assert_eq "sources/received/${TODAY}_mail.txt" "$(fs_field path)" 'without --date the name starts with the local date'

# ---------------------------------------------------------------------------
echo '--- Root discovery: a subdirectory and no dossier at all ---'

d="$(build_dossier)"
run_fs "$d/dossier" --kind received --date 2026-10-01 --slug sub "../incoming/Call transcript.txt"
expect_ok 'run from dossier/' filed
assert_eq 'sources/received/2026-10-01_sub.txt' "$(fs_field path)" 'from a subdirectory the path is still root-relative'
assert_file "$d/sources/received/2026-10-01_sub.txt"

nodossier="$(mktemp -d)"
printf '%s\n' 'x' >"$nodossier/a.txt"
run_fs "$nodossier" --kind received a.txt
expect_error 'no dossier upward' no_dossier 2
rm -rf "$nodossier"

# ---------------------------------------------------------------------------
echo '--- Dedup by sha256 (D-06, INGEST-04) ---'

# count_sources DIR — regular files under sources/ that a filing run created:
# .gitkeep and the scaffold's sources/README.md are excluded.
count_sources() {
  find "$1/sources" -type f ! -name .gitkeep ! -path "$1/sources/README.md" | wc -l | tr -d ' '
}

# mk_in DIR NAME — a new incoming file with content of its own (so the dedup
# cases below never collide by accident).
MK_N=0
mk_in() {
  MK_N=$((MK_N + 1))
  printf '%s\n' "incoming $2 $MK_N" >"$1/incoming/$2"
}

d="$(build_dossier)"
run_fs "$d" --kind transcript --date 2026-10-10 --slug kickoff-call "incoming/Call transcript.txt"
expect_ok 'dedup: first filing' filed
FIRST='sources/transcripts/2026-10-10_kickoff-call.txt'
cp "$d/incoming/Call transcript.txt" "$d/incoming/Other name.txt"
run_fs "$d" --kind received --date 2026-10-11 --slug another "incoming/Other name.txt"
expect_ok 'dedup: same bytes, other name and slug' already_filed
assert_eq "$FIRST" "$(fs_field path)" 'dedup: already_filed names the first filed file'
assert_eq "$(sha_of "$d/incoming/Other name.txt")" "$(fs_field sha256)" 'dedup: already_filed carries the sha256'
assert_eq 1 "$(count_sources "$d")" 'dedup: nothing new under sources/'

run_fs "$d" --kind transcript --date 2026-10-10 --slug kickoff-call "$FIRST"
expect_ok 'dedup: re-run on the filed file itself (D-14)' already_filed
assert_eq "$FIRST" "$(fs_field path)" 'dedup: the filed file reports its own path'

ln -s "$d/$FIRST" "$d/incoming/link.txt"
run_fs "$d" --kind received "incoming/link.txt"
expect_ok 'dedup: a symlink to a filed file' already_filed
assert_eq "$FIRST" "$(fs_field path)" 'dedup: the symlink is resolved to the filed file'
assert_eq 1 "$(count_sources "$d")" 'dedup: still nothing new after the symlink case'

d="$(build_dossier)"
mk_in "$d" 'new.txt'
ln -s ../../incoming/new.txt "$d/sources/received/2026-10-01_ln.txt"
run_fs "$d" --kind received --date 2026-10-02 --slug fresh "incoming/new.txt"
expect_ok 'dedup: a symlink under sources/ is never the match' filed
assert_eq 'sources/received/2026-10-02_fresh.txt' "$(fs_field path)" 'dedup: filed under its own name'

d="$(build_dossier)"
printf 'x\n' >"$d/sources/received/.gitkeep"
printf 'x\n' >"$d/incoming/same-as-gitkeep.txt"
run_fs "$d" --kind received --date 2026-10-02 --slug gk "incoming/same-as-gitkeep.txt"
expect_ok 'dedup: .gitkeep is never hashed or matched' filed

d="$(build_dossier)"
: >"$d/incoming/empty.txt"
run_fs "$d" --kind received "incoming/empty.txt"
expect_error 'an empty incoming file' empty
assert_eq 0 "$(count_sources "$d")" 'empty: nothing filed'

# ---------------------------------------------------------------------------
echo '--- No overwrite, ever ---'

d="$(build_dossier)"
run_fs "$d" --kind received --date 2026-10-01 --slug brochure "incoming/Call transcript.txt"
expect_ok 'name_taken: first filing' filed
TAKEN="$d/sources/received/2026-10-01_brochure.txt"
BEFORE="$(sha_of "$TAKEN")"
mk_in "$d" 'different.txt'
run_fs "$d" --kind received --date 2026-10-01 --slug brochure "incoming/different.txt"
expect_error 'name_taken: another file, same computed name' name_taken
case "$(fs_field message)" in
  *'sources/received/2026-10-01_brochure.txt'*) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
  *)
    echo "FAIL: name_taken message does not name the root-relative path ('$(fs_field message)')" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
    ;;
esac
assert_eq "$BEFORE" "$(sha_of "$TAKEN")" 'name_taken: the existing file is byte-identical afterwards'
assert_eq 1 "$(count_sources "$d")" 'name_taken: no suffixed copy was created'

d="$(build_dossier)"
mk_in "$d" 'dangling.txt'
ln -s "$d/outside-created.txt" "$d/sources/received/2026-10-01_dang.txt"
run_fs "$d" --kind received --date 2026-10-01 --slug dang "incoming/dangling.txt"
expect_error 'name_taken: a dangling symlink at the target name' name_taken
if [ -e "$d/outside-created.txt" ]; then
  echo 'FAIL: the dangling link destination was created' >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
else
  TESTS_PASSED=$((TESTS_PASSED + 1))
fi

# ---------------------------------------------------------------------------
echo '--- Validation inside the JSON contract ---'

d="$(build_dossier)"
for bad in 2026-02-30 10/10/2026 2026-1-5 20261010; do
  run_fs "$d" --kind received --date "$bad" "incoming/Call transcript.txt"
  expect_error "--date $bad" bad_date
done
run_fs "$d" "incoming/Call transcript.txt"
expect_error 'missing --kind' usage
run_fs "$d" --kind notes "incoming/Call transcript.txt"
expect_error '--kind notes' usage
run_fs "$d" --kind received
expect_error 'missing PATH' usage
assert_eq 0 "$(count_sources "$d")" 'validation: nothing was filed by any refused run'

# ---------------------------------------------------------------------------
echo '--- Slug folding ---'

d="$(build_dossier)"
mk_in "$d" 'Brochure.PDF'
run_fs "$d" --kind received --date 2026-10-01 --slug 'Brochure Été 2026 (v2)' "incoming/Brochure.PDF"
expect_ok 'slug: accents, case, punctuation' filed
assert_eq 'sources/received/2026-10-01_brochure-ete-2026-v2.pdf' "$(fs_field path)" 'slug: folded name and lowercased extension'

mk_in "$d" 'p1.txt'
run_fs "$d" --kind received --date 2026-10-10 --slug '../../etc/pass wd' "incoming/p1.txt"
expect_ok 'slug: path traversal text' filed
assert_eq 'sources/received/2026-10-10_etc-pass-wd.txt' "$(fs_field path)" 'slug: traversal characters are folded away'
assert_file "$d/sources/received/2026-10-10_etc-pass-wd.txt"

mk_in "$d" 'p2.txt'
run_fs "$d" --kind received --date 2026-10-10 --slug '!!! ??? ***' "incoming/p2.txt"
expect_ok 'slug: punctuation only' filed
assert_eq 'sources/received/2026-10-10_source.txt' "$(fs_field path)" 'slug: punctuation only becomes "source"'

mk_in "$d" 'p3.txt'
LONG="$(python3 -c 'print("a" * 59 + " " + "b" * 140)')"
run_fs "$d" --kind received --date 2026-10-10 --slug "$LONG" "incoming/p3.txt"
expect_ok 'slug: 200 characters' filed
WANT59="$(python3 -c 'print("a" * 59)')"
assert_eq "sources/received/2026-10-10_${WANT59}.txt" "$(fs_field path)" 'slug: cut to 60 characters, no trailing dash'

mk_in "$d" 'p4.txt'
run_fs "$d" --kind received --date 2026-10-10 --slug $'ab\tcd\001ef' "incoming/p4.txt"
expect_ok 'slug: control characters' filed
assert_eq 'sources/received/2026-10-10_ab-cd-ef.txt' "$(fs_field path)" 'slug: a control character never reaches the name'

mk_in "$d" 'Réponse 2026.EML'
run_fs "$d" --kind received --date 2026-10-10 "incoming/Réponse 2026.EML"
expect_ok 'slug: default from a non-ASCII file name' filed
assert_eq 'sources/received/2026-10-10_reponse-2026.eml' "$(fs_field path)" 'slug: the incoming stem is folded to ASCII'

# ---------------------------------------------------------------------------
echo '--- Input refusals ---'

d="$(build_dossier)"
run_fs "$d" --kind received "incoming/does-not-exist.txt"
expect_error 'a missing path' missing
run_fs "$d" --kind received "incoming/Réponse absente.txt"
expect_error 'a missing non-ASCII path stays ASCII in the JSON' missing
run_fs "$d" --kind received incoming
expect_error 'a directory' not_a_regular_file
mkfifo "$d/incoming/pipe"
run_fs "$d" --kind received "incoming/pipe"
expect_error 'a FIFO (returns instead of hanging)' not_a_regular_file
run_fs "$d" --kind received /dev/zero
expect_error '/dev/zero' not_a_regular_file
run_fs "$d" --kind received 'https://example.com/brochure.pdf'
expect_error 'a URL given to the filing form' url_argument
case "$(fs_field message)" in
  *fetch*) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
  *)
    echo "FAIL: url_argument message does not point to fetch ('$(fs_field message)')" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
    ;;
esac
assert_eq 0 "$(count_sources "$d")" 'refusals: nothing was filed'

# ---------------------------------------------------------------------------
echo '--- Containment ---'

d="$(build_dossier)"
outside="$(mktemp -d)"
rm -rf "$d/sources"
ln -s "$outside" "$d/sources"
run_fs "$d" --kind received --date 2026-10-01 --slug x "incoming/Call transcript.txt"
expect_error 'sources/ is a symlink out of the dossier' sources_outside_dossier
assert_eq 0 "$(ls -A "$outside" | wc -l | tr -d ' ')" 'containment: the outside directory stays empty'
rm -rf "$outside"

d="$(build_dossier)"
mkdir -p "$d/tmp"
TMPDIR="$d/tmp" run_fs "$d" --kind received --date 2026-10-01 --slug x "incoming/Call transcript.txt"
expect_error 'TMPDIR inside the dossier' staging_inside_dossier
assert_eq 0 "$(count_sources "$d")" 'containment: nothing filed when staging would sit in the dossier'
assert_eq 0 "$(ls -A "$d/tmp" | wc -l | tr -d ' ')" 'containment: the staging directory was removed'

# ---------------------------------------------------------------------------
echo '--- Raw exports and large files: warnings ---'

d="$(build_dossier)"
run_fs "$d" --kind transcript --date 2026-10-10 --slug kickoff-call "incoming/Call transcript.txt"
expect_ok 'raw: the transcript first' filed
printf '%s\n' 'WEBVTT' '00:00:01.000 --> 00:00:02.000' 'hello' >"$d/incoming/export.vtt"
run_fs "$d" --kind raw --date 2026-10-10 --slug kickoff-call "incoming/export.vtt"
expect_ok 'raw: with its transcript present' filed
assert_eq 'sources/transcripts/raw/2026-10-10_kickoff-call.vtt' "$(fs_field path)" 'raw: filed under sources/transcripts/raw/'
assert_eq '[]' "$(fs_field warnings)" 'raw: no warning when the transcript exists'

d="$(build_dossier)"
printf '%s\n' 'WEBVTT' '00:00:01.000 --> 00:00:02.000' 'hello' >"$d/incoming/export.vtt"
run_fs "$d" --kind raw --date 2026-10-10 --slug kickoff-call "incoming/export.vtt"
expect_ok 'raw: without a transcript' filed
case "$(fs_field warnings)" in
  *2026-10-10_kickoff-call*) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
  *)
    echo "FAIL: raw warning does not name the missing transcript stem ('$(fs_field warnings)')" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
    ;;
esac

# The warning threshold is a module constant; patch it down by importing the
# module (-B: no bytecode cache lands in the skill folder).
d="$(build_dossier)"
FS_STATUS=0
FS_OUT="$(cd "$d" && python3 -B -c 'import importlib.util, sys
spec = importlib.util.spec_from_file_location("file_source", sys.argv[1])
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
mod.LARGE_FILE_WARNING_BYTES = 10
sys.exit(mod.main(["--kind", "received", "--date", "2026-10-01", "--slug", "big", "incoming/Call transcript.txt"]))' "$(fs_script)" 2>"$ERRDIR/err")" || FS_STATUS=$?
FS_ERR="$(cat "$ERRDIR/err")"
expect_ok 'large file: threshold patched down' filed
case "$(fs_field warnings)" in
  *'Git LFS'*) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
  *)
    echo "FAIL: large-file warning does not name Git LFS ('$(fs_field warnings)')" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
    ;;
esac

# ---------------------------------------------------------------------------
echo '--- An older interpreter ---'

if [ -x /usr/bin/python3 ]; then
  d="$(build_dossier)"
  FS_STATUS=0
  FS_OUT="$(cd "$d" && /usr/bin/python3 "$(fs_script)" --kind transcript --date 2026-10-10 --slug 'Kickoff call' "incoming/Call transcript.txt" 2>"$ERRDIR/err")" || FS_STATUS=$?
  FS_ERR="$(cat "$ERRDIR/err")"
  expect_ok "tracer under /usr/bin/python3 ($(/usr/bin/python3 --version 2>&1))" filed
  assert_eq 'sources/transcripts/2026-10-10_kickoff-call.txt' "$(fs_field path)" '/usr/bin/python3: same path as the tracer'
else
  skip '/usr/bin/python3 is absent: the older-interpreter rerun of the tracer did not run'
fi

# ---------------------------------------------------------------------------
echo '--- Static: Python 3.8 grammar, standard library only, no process spawning ---'

script="$(fs_script)"
STATUS=0
python3 -c 'import ast, sys; ast.parse(open(sys.argv[1]).read(), feature_version=(3, 8))' "$script" 2>/dev/null || STATUS=$?
assert_eq 0 "$STATUS" 'file_source.py parses with the Python 3.8 grammar'

STATUS=0
python3 - "$script" <<'PY' 2>/dev/null || STATUS=$?
import ast, sys
tree = ast.parse(open(sys.argv[1]).read())
allowed = {"argparse", "datetime", "errno", "hashlib", "ipaddress", "json", "os",
           "shutil", "socket", "stat", "sys", "tempfile", "time", "unicodedata",
           "urllib.error", "urllib.parse", "urllib.request"}
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
assert_eq 0 "$STATUS" 'file_source.py imports only the allowed standard library modules'

NEWER="$(grep -nE 'file_digest|removeprefix|removesuffix|is_relative_to|strict=|functools|@cache|\b(list|dict|tuple|set|frozenset)\[' "$script" || true)"
assert_eq '' "$NEWER" 'file_source.py uses none of the Python 3.9+ APIs'

SPAWN="$(grep -nE 'subprocess|os\.system|eval\(|shell=' "$script" || true)"
assert_eq '' "$SPAWN" 'file_source.py spawns no process and evaluates nothing'

# ---------------------------------------------------------------------------
echo '--- The file itself: executable, shebang, find_root parity ---'

assert_exec "$(fs_script)"
assert_eq '#!/usr/bin/env python3' "$(head -1 "$(fs_script)")" 'file_source.py starts with the python3 env shebang'

LINT_BLOCK="$(sed -n '/^def find_root/,/^    return None$/p' "$(lint_py)")"
assert_eq 14 "$(printf '%s\n' "$LINT_BLOCK" | wc -l | tr -d ' ')" 'lint.py find_root block is 14 lines'
FS_BLOCK="$(sed -n '/^def find_root/,/^    return None$/p' "$(fs_script)")"
if [ -n "$FS_BLOCK" ]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo 'FAIL: file_source.py has no def find_root block' >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi
assert_eq "$LINT_BLOCK" "$FS_BLOCK" 'file_source.py find_root is byte-identical to scripts/lint.py'"'"'s'

finish
