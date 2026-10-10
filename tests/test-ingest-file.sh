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

# run_fs DIR ARG... — runs the script from DIR. stderr goes through a mktemp
# file, never a file beside the dossier, so the tree under test stays clean.
run_fs() {
  local dir="$1" err_file
  shift
  err_file="$(mktemp)"
  FS_STATUS=0
  FS_OUT="$(cd "$dir" && python3 "$(fs_script)" "$@" 2>"$err_file")" || FS_STATUS=$?
  FS_ERR="$(cat "$err_file")"
  rm -f "$err_file"
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
