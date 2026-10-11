#!/usr/bin/env bash
# tests/test-ingest-guard.sh — D-04, D-03, INGEST-01, INGEST-04 and ROADMAP
# criterion 5: the command lines of skills/dossier-ingest/SKILL.md, read FROM
# that file (not copied here), go through the real Phase 3 guard
# (hooks/guard-sources.py) and the real scripts.
#
# The point: skill, guard and scripts cannot drift apart. A skill line the guard
# denies, a placeholder this test does not know, or a shortcut the guard stops
# catching turns this test red. Where the guard is blind (it never inspects
# python3, a script, or pdftotext writing to an existing .txt), the scripts must
# refuse on their own: that is asserted too.
#
# Order: every guard check runs on the pristine fixture first, then the real
# executions, then the pdftotext-hidden run (ROADMAP criterion 5).
set -u

# shellcheck source=./lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SKILL_MD="$REPO_ROOT/skills/dossier-ingest/SKILL.md"
SKILL_ABS="$REPO_ROOT/skills/dossier-ingest"
MAKE_PDF="$REPO_ROOT/tests/fixtures/make-pdf.py"
SPEC_SENTENCE='sources are immutable; file a correction in the dossier instead'

assert_file "$SKILL_MD"

# --- The lines: every non-comment, non-blank line of every ```bash block ---
BASH_LINES="$(awk '
  $0 == "```bash" { on = 1; next }
  $0 == "```" { on = 0; next }
  on && $0 != "" && $0 !~ /^#/ { print }
' "$SKILL_MD" 2>/dev/null)"
N_LINES=$(printf '%s\n' "$BASH_LINES" | grep -c . | tr -d ' ')
echo "read $N_LINES bash lines from skills/dossier-ingest/SKILL.md:"
printf '%s\n' "$BASH_LINES" | sed 's/^/  | /'
if [ "$N_LINES" -ge 11 ]; then TESTS_PASSED=$((TESTS_PASSED + 1)); else echo "FAIL: only $N_LINES bash lines in SKILL.md, expected at least 11" >&2; TESTS_FAILED=$((TESTS_FAILED + 1)); fi
has_line_with() { # FIXED_STRING LABEL
  if printf '%s\n' "$BASH_LINES" | grep -qF -- "$1"; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "FAIL: no bash line in SKILL.md contains: $2 ($1)" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}
has_line_with 'file_source.py fetch' 'the fetch line'
has_line_with 'file_source.py --kind' 'the filing line'
has_line_with "extract-text.sh '" 'the extraction line'
if printf '%s\n' "$BASH_LINES" | grep -qxF 'test -x ${CLAUDE_SKILL_DIR}/scripts/extract-text.sh'; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "FAIL: no bash line is: test -x \${CLAUDE_SKILL_DIR}/scripts/extract-text.sh" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi
assert_eq '0' "$(printf '%s\n' "$BASH_LINES" | grep -c '\\$' | tr -d ' ')" 'no bash line ends with a backslash (one command per line)'

LINE_FETCH="$(printf '%s\n' "$BASH_LINES" | grep -F 'file_source.py fetch' | head -1)"
LINE_FILE="$(printf '%s\n' "$BASH_LINES" | grep -F 'file_source.py --kind' | head -1)"
LINE_EXTRACT="$(printf '%s\n' "$BASH_LINES" | grep -F "extract-text.sh '" | head -1)"
LINE_CP="$(printf '%s\n' "$BASH_LINES" | grep -F 'cp -n' | head -1)"
LINE_PDFTOTEXT="$(printf '%s\n' "$BASH_LINES" | grep -F 'pdftotext -enc UTF-8' | head -1)"

# subst [--abs] [name=value]... — stdin lines with every placeholder replaced. This map
# is the only place the placeholders are defined: an unknown placeholder survives and
# is caught by the leftover check below. --abs also replaces ${CLAUDE_SKILL_DIR} and
# ${CLAUDE_PLUGIN_ROOT} by the absolute skill folder and repository root.
subst() {
  python3 -c '
import os, shlex, sys
m = {
    "url": "http://127.0.0.1:9/brochure.pdf",
    "kind": "transcript",
    "YYYY-MM-DD": "2026-10-10",
    "slug": "kickoff-call",
    "path": "incoming/Call transcript.txt",
    "filed pdf": "sources/received/2026-10-02_price-list.pdf",
    "abs_path": os.environ.get("SUBST_ROOT", ".") + "/sources/received/2026-10-02_price-list.pdf",
    "root": os.environ.get("SUBST_ROOT", "."),
    "stage": "/tmp/client-dossier-fetch-x",
    "folder": "transcripts",
    "ext": ".txt",
    "txt": os.environ.get("SUBST_ROOT", ".") + "/sources/received/2026-10-02_price-list.txt",
}
absolute = False
for a in sys.argv[3:]:
    if a == "--abs":
        absolute = True
    else:
        k, v = a.split("=", 1)
        m[k] = v
for line in sys.stdin.read().split("\n"):
    for k, v in m.items():
        line = line.replace("<%s>" % k, v)
    if absolute:
        line = line.replace("${CLAUDE_SKILL_DIR}", shlex.quote(sys.argv[1]))
        line = line.replace("${CLAUDE_PLUGIN_ROOT}", shlex.quote(sys.argv[2]))
    print(line)
' "$SKILL_ABS" "$REPO_ROOT" "$@"
}

# No placeholder may survive the map: the skill and this test cannot drift.
LEFTOVER="$(printf '%s\n' "$BASH_LINES" | subst | grep -E '<[A-Za-z][^<>]*>' || true)"
assert_eq '' "$LEFTOVER" 'every placeholder of the skill is in the substitution map'

# --- Fixture: a dossier scaffolded by the real init.py -------------------------
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
d="$WORK/dossier"
export SUBST_ROOT="$d"
mkdir -p "$d"
git init -q "$d"
python3 "$(init_py)" --target "$d" --language en \
  --counterpart 'Acme Consulting|ordering party|Jane Doe' >/dev/null 2>&1
mkdir -p "$d/incoming" "$d/sources/received" "$d/sources/transcripts"
printf '%s\n' '@00:12 Jane Doe: We agree on the scope.' >"$d/incoming/Call transcript.txt"
python3 "$MAKE_PDF" "$d/sources/received/2026-10-01_brochure.pdf" 'Brochure text'
printf '%s\n' '--- page 1 ---' 'Brochure text' >"$d/sources/received/2026-10-01_brochure.txt"
python3 "$MAKE_PDF" "$d/sources/received/2026-10-02_price-list.pdf" 'Price list 1,250'
HAVE_PDFTOTEXT=0
command -v pdftotext >/dev/null 2>&1 && HAVE_PDFTOTEXT=1

sha() { shasum -a 256 "$1" 2>/dev/null | cut -d' ' -f1; }
BROCHURE_TXT_SHA="$(sha "$d/sources/received/2026-10-01_brochure.txt")"

# --- Guard helpers (the shapes of tests/test-hook-guard-sources.sh, copied) ----
check_common() { # LABEL — exit 0, empty stderr, never an allow decision
  local label="$1"
  assert_eq 0 "$HOOK_STATUS" "$label: exit status 0"
  assert_eq '' "$HOOK_ERR" "$label: empty stderr"
  case "$(hook_field hookSpecificOutput.permissionDecision)" in
    allow) echo "FAIL: $label (the hook printed an allow decision)" >&2; TESTS_FAILED=$((TESTS_FAILED + 1)) ;;
    *) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
  esac
}
guard_silent() { # LABEL CWD CMD — no output at all
  run_hook guard-sources.py "$(hook_json PreToolUse "$2" Bash command "$3")"
  check_common "$1"
  assert_eq '' "$HOOK_OUT" "$1: silent (no decision)"
}
guard_denies() { # LABEL JSON — a deny that starts with the spec sentence
  local reason
  run_hook guard-sources.py "$2"
  check_common "$1"
  assert_eq deny "$(hook_field hookSpecificOutput.permissionDecision)" "$1: decision is deny"
  reason="$(hook_field hookSpecificOutput.permissionDecisionReason)"
  case "$reason" in
    "$SPEC_SENTENCE: "*) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
    *) echo "FAIL: $1 (reason does not start with the spec sentence: '$reason')" >&2; TESTS_FAILED=$((TESTS_FAILED + 1)) ;;
  esac
}

# --- 1. Allowed: each substituted line, literal and absolute, from the dossier root ---
echo '--- guard: every line of the skill is silent ---'
while IFS= read -r line; do
  [ -n "$line" ] || continue
  lit="$(printf '%s\n' "$line" | subst)"
  absl="$(printf '%s\n' "$line" | subst --abs)"
  guard_silent "literal: $lit" "$d" "$lit"
  guard_silent "absolute: $absl" "$d" "$absl"
done <<EOF
$BASH_LINES
EOF
# The extraction line also works from the folder of the PDF, with the file name only.
guard_silent 'extract from sources/received with the file name only' "$d/sources/received" \
  "$(printf '%s\n' "$LINE_EXTRACT" | subst --abs 'abs_path=2026-10-02_price-list.pdf')"

# --- 2. Denied (D-03, D-04): the shortcuts the guard exists for ----------------
echo '--- guard: the shortcuts stay denied ---'
guard_denies 'line cp -n onto the existing brochure .txt' \
  "$(hook_json PreToolUse "$d" Bash command "$(printf '%s\n' "$LINE_CP" | subst folder=received YYYY-MM-DD=2026-10-01 slug=brochure ext=.txt)")"
guard_denies 'line pdftotext redirected onto the existing brochure .txt' \
  "$(hook_json PreToolUse "$d" Bash command "$(printf '%s\n' "$LINE_PDFTOTEXT" | subst "txt=$d/sources/received/2026-10-01_brochure.txt" 'filed pdf=sources/received/2026-10-01_brochure.pdf')")"
guard_denies 'cp over the existing brochure PDF' \
  "$(hook_json PreToolUse "$d" Bash command 'cp "incoming/Call transcript.txt" sources/received/2026-10-01_brochure.pdf')"
guard_denies 'Write tool on a new .txt under sources/' \
  "$(hook_json PreToolUse "$d" Write file_path "$d/sources/received/2026-10-09_new.txt")"
guard_denies 'Edit tool on the existing brochure .txt' \
  "$(hook_json PreToolUse "$d" Edit file_path "$d/sources/received/2026-10-01_brochure.txt")"

# --- 3. Guard blind, the scripts refuse on their own ---------------------------
echo '--- real run: where the guard is blind, the scripts refuse ---'
RUN_OUT=""; RUN_ERR=""; RUN_STATUS=0
run_line() { # CWD LINE [PATH] — run the line under /bin/bash in CWD
  local cwd="$1" line="$2" errf
  errf="$(mktemp)"
  RUN_STATUS=0
  RUN_OUT="$(cd "$cwd" && PATH="${3:-$PATH}" /bin/bash -c "$line" 2>"$errf")" || RUN_STATUS=$?
  RUN_ERR="$(cat "$errf")"
  rm -f "$errf"
}
jget() { # KEY — the value of KEY in the JSON object RUN_OUT
  printf '%s' "$RUN_OUT" | python3 -c 'import json, sys
try:
    print(json.load(sys.stdin).get(sys.argv[1], ""))
except Exception:
    print("invalid-json")' "$1"
}

# The extraction line on a PDF whose .txt exists: the guard cannot see it, the script says exists:.
run_line "$d" "$(printf '%s\n' "$LINE_EXTRACT" | subst --abs "abs_path=$d/sources/received/2026-10-01_brochure.pdf")"
assert_eq 0 "$RUN_STATUS" 'extract on a PDF whose .txt exists: exit 0'
case "$RUN_OUT" in
  exists:*) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
  *) echo "FAIL: extract on a PDF whose .txt exists prints exists: (got '$RUN_OUT')" >&2; TESTS_FAILED=$((TESTS_FAILED + 1)) ;;
esac
assert_eq "$BROCHURE_TXT_SHA" "$(sha "$d/sources/received/2026-10-01_brochure.txt")" 'extract on an existing .txt leaves it byte-identical'

# The filing line with a date and slug that name the existing brochure .txt (different bytes): name_taken.
run_line "$d" "$(printf '%s\n' "$LINE_FILE" | subst --abs kind=received YYYY-MM-DD=2026-10-01 slug=brochure)"
assert_eq 1 "$RUN_STATUS" 'filing onto an existing name: exit 1'
assert_eq 'name_taken' "$(jget error)" 'filing onto an existing name: name_taken'
assert_eq "$BROCHURE_TXT_SHA" "$(sha "$d/sources/received/2026-10-01_brochure.txt")" 'name_taken leaves the existing file byte-identical'

# --- 4. Real runs of the skill's own lines (INGEST-01, INGEST-04) --------------
echo '--- real run: the skill lines, from the dossier root ---'
run_line "$d" 'test -x '"$(printf '%s' '${CLAUDE_SKILL_DIR}' | python3 -c 'import shlex, sys; print(shlex.quote(sys.argv[1]))' "$SKILL_ABS")"'/scripts/file_source.py'
assert_eq 0 "$RUN_STATUS" 'line: test -x on file_source.py exits 0'
run_line "$d" "$(printf '%s\n' 'test -x ${CLAUDE_SKILL_DIR}/scripts/extract-text.sh' | subst --abs)"
assert_eq 0 "$RUN_STATUS" 'line: test -x on extract-text.sh exits 0'

FILE_ABS="$(printf '%s\n' "$LINE_FILE" | subst --abs)"
run_line "$d" "$FILE_ABS"
assert_eq 0 "$RUN_STATUS" 'filing line: exit 0'
assert_eq 'filed' "$(jget status)" 'filing line: status filed'
assert_eq 'sources/transcripts/2026-10-10_kickoff-call.txt' "$(jget path)" 'filing line: the dated name under sources/transcripts/'
assert_eq "$(sha "$d/incoming/Call transcript.txt")" "$(sha "$d/sources/transcripts/2026-10-10_kickoff-call.txt")" 'filing line: the filed bytes are the incoming bytes'
run_line "$d" "$FILE_ABS"
assert_eq 0 "$RUN_STATUS" 'filing line again: exit 0'
assert_eq 'already_filed' "$(jget status)" 'filing line again: already_filed (INGEST-04)'
assert_eq 'sources/transcripts/2026-10-10_kickoff-call.txt' "$(jget path)" 'filing line again: names the existing path'

if [ "$HAVE_PDFTOTEXT" = 1 ]; then
  run_line "$d" "$(printf '%s\n' "$LINE_EXTRACT" | subst --abs)"
  assert_eq 0 "$RUN_STATUS" 'extraction line: exit 0'
  case "$RUN_OUT" in
    extracted:*) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
    *) echo "FAIL: extraction line prints extracted: (got '$RUN_OUT')" >&2; TESTS_FAILED=$((TESTS_FAILED + 1)) ;;
  esac
  assert_eq 1 "$(grep -c -- '--- page 1 ---' "$d/sources/received/2026-10-02_price-list.txt" 2>/dev/null)" 'extraction line: the .txt holds the page marker'
else
  skip 'pdftotext is not on PATH: the extraction line was not run for real'
fi

run_line "$d" "$(printf '%s\n' "$LINE_FETCH" | subst --abs)"
assert_eq 1 "$RUN_STATUS" 'fetch line on a loopback URL: exit 1'
assert_eq 'not_public' "$(jget error)" 'fetch line on a loopback URL: not_public (no network reached)'

# --- 4b. A4-F1: a hostile value is data inside single quotes, never executed ---
echo '--- real run: $(...) in a URL, a path or a slug does not run ---'
MARK="$WORK/MARK"
run_line "$d" "$(printf '%s\n' "$LINE_FETCH" | subst --abs "url=http://127.0.0.1:9/\$(touch $MARK-url)")"
assert_eq 1 "$RUN_STATUS" 'hostile URL: refused, not run'
assert_file_absent() { if [ -e "$1" ]; then echo "FAIL: $2 ($1 exists)" >&2; TESTS_FAILED=$((TESTS_FAILED + 1)); else TESTS_PASSED=$((TESTS_PASSED + 1)); fi; }
assert_file_absent "$MARK-url" 'hostile URL: the command substitution did not run'
run_line "$d" "$(printf '%s\n' "$LINE_FILE" | subst --abs "path=incoming/\$(touch $MARK-path).txt")"
assert_file_absent "$MARK-path" 'hostile path: the command substitution did not run'
run_line "$d" "$(printf '%s\n' "$LINE_FILE" | subst --abs "slug=\`touch $MARK-slug\`")"
assert_file_absent "$MARK-slug" 'hostile slug: the backticks did not run'
assert_eq 0 "$(printf '%s\n' "$BASH_LINES" | sed 's/"${CLAUDE_PLUGIN_ROOT}[^"]*"//g' | grep -c '"[^"]*<[A-Za-z]' | tr -d ' ')" 'no bash line of the skill double-quotes a placeholder (A5-F1: the plugin-root path is the one quoted value)'

# --- 5. pdftotext hidden from PATH (ROADMAP criterion 5) -----------------------
echo '--- real run: pdftotext hidden from PATH ---'
SHIM="$WORK/shim"
mkdir -p "$SHIM"
for tool in bash python3 env; do
  src="$(command -v "$tool" 2>/dev/null)"
  [ -n "$src" ] && ln -s "$src" "$SHIM/$tool"
done
python3 "$MAKE_PDF" "$d/incoming/Offer.pdf" 'Offer text'
run_line "$d" "$(printf '%s\n' "$LINE_FILE" | subst --abs kind=received slug=offer 'path=incoming/Offer.pdf')" "$SHIM"
assert_eq 0 "$RUN_STATUS" 'pdftotext hidden: filing a new PDF exits 0'
assert_eq 'filed' "$(jget status)" 'pdftotext hidden: the PDF is filed'
FILED_OFFER="$(jget path)"
assert_eq 'sources/received/2026-10-10_offer.pdf' "$FILED_OFFER" 'pdftotext hidden: filed under sources/received/'
OFFER_SHA="$(sha "$d/$FILED_OFFER")"
run_line "$d" "$(printf '%s\n' "$LINE_EXTRACT" | subst --abs "abs_path=$d/$FILED_OFFER")" "$SHIM"
assert_eq 69 "$RUN_STATUS" 'pdftotext hidden: the extraction line exits 69'
case "$RUN_ERR" in
  *'brew install poppler'*) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
  *) echo "FAIL: pdftotext hidden: stderr names the poppler install (got '$RUN_ERR')" >&2; TESTS_FAILED=$((TESTS_FAILED + 1)) ;;
esac
assert_file "$d/$FILED_OFFER"
assert_eq "$OFFER_SHA" "$(sha "$d/$FILED_OFFER")" 'pdftotext hidden: the filed PDF is unchanged'
assert_eq 0 "$(ls "$d/sources/received" | grep -c '2026-10-10_offer\.txt')" 'pdftotext hidden: no .txt was written'

finish
