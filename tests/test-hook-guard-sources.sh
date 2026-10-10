#!/usr/bin/env bash
# tests/test-hook-guard-sources.sh — PROTO-05 as amended by D-03 and D-04, and
# the PROTO-08 root rule for hooks: hooks/guard-sources.py is a PreToolUse
# guard that denies every write under the nearest dossier's sources/ (new
# files included, D-03) through the Write family of tools, and heuristically
# denies the Bash commands that visibly modify an existing file there (D-04).
# The hook is fed stdin JSON the way Claude Code feeds it; no model involved.
#
# Contract asserted on every case: exit 0, empty stderr, and the hook never
# prints an allow decision (a hook `allow` would bypass the user's own
# permission rules). A silent run is "no decision", so Claude Code's normal
# permission flow applies.
set -u

# shellcheck source=./lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SPEC_SENTENCE='sources are immutable; file a correction in the dossier instead'
TRANSCRIPT_REL='sources/transcripts/2026-10-01_kickoff.txt'

# build_dossier — a scaffolded dossier (real init.py) holding one transcript
# with a typo. Echoes its path. Outputs are never written inside it.
build_dossier() {
  local target="$1"
  python3 "$(init_py)" --target "$target" --language en \
    --counterpart 'Acme Consulting|ordering party|Jane Doe' >/dev/null 2>&1
  mkdir -p "$target/sources/transcripts" "$target/sources/received"
  printf '%s\n' '@00:12 Jane Doe: We need the reprot by 2026-10-20.' \
    >"$target/$TRANSCRIPT_REL"
}

# check_common LABEL — every case: exit 0, empty stderr, never `allow`.
check_common() {
  local label="$1"
  assert_eq 0 "$HOOK_STATUS" "$label: exit status 0"
  assert_eq '' "$HOOK_ERR" "$label: empty stderr"
  case "$(hook_field hookSpecificOutput.permissionDecision)" in
    allow)
      echo "FAIL: $label (the hook printed an allow decision)" >&2
      TESTS_FAILED=$((TESTS_FAILED + 1))
      ;;
    *) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
  esac
}

# expect_deny LABEL JSON REL — the hook denies, with the spec sentence first
# and REL (the path relative to the dossier root) right after it. REL is a
# glob pattern (unquoted in the `case`), so the case-variant test can accept
# whichever spelling of the first component the filesystem reports.
expect_deny() {
  local label="$1" json="$2" rel="$3" reason
  run_hook guard-sources.py "$json"
  check_common "$label"
  assert_eq deny "$(hook_field hookSpecificOutput.permissionDecision)" "$label: decision is deny"
  assert_eq PreToolUse "$(hook_field hookSpecificOutput.hookEventName)" "$label: hookEventName"
  reason="$(hook_field hookSpecificOutput.permissionDecisionReason)"
  case "$reason" in
    "$SPEC_SENTENCE: "$rel*) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
    *)
      echo "FAIL: $label (reason does not start with '$SPEC_SENTENCE: $rel': '$reason')" >&2
      TESTS_FAILED=$((TESTS_FAILED + 1))
      ;;
  esac
}

# expect_silent LABEL JSON — no output at all (no decision).
expect_silent() {
  local label="$1" json="$2"
  run_hook guard-sources.py "$json"
  check_common "$label"
  assert_eq none "$(hook_field hookSpecificOutput.permissionDecision)" "$label: no decision"
  assert_eq '' "$HOOK_OUT" "$label: empty stdout"
}

d=$(scratch_repo)
build_dossier "$d"

# --- Case 1: the Write family under sources/ is denied (D-03) ---
echo '--- Edit, absolute path, existing file ---'
expect_deny 'Edit absolute' \
  "$(hook_json PreToolUse "$d" Edit file_path "$d/$TRANSCRIPT_REL")" "$TRANSCRIPT_REL"

echo '--- Write of a NEW file under sources/ (D-03) ---'
expect_deny 'Write new file' \
  "$(hook_json PreToolUse "$d" Write file_path "$d/sources/received/2026-10-10_new.txt")" \
  'sources/received/2026-10-10_new.txt'

echo '--- MultiEdit and NotebookEdit ---'
expect_deny 'MultiEdit' \
  "$(hook_json PreToolUse "$d" MultiEdit file_path "$d/$TRANSCRIPT_REL")" "$TRANSCRIPT_REL"
expect_deny 'NotebookEdit' \
  "$(hook_json PreToolUse "$d" NotebookEdit notebook_path "$d/sources/received/analysis.ipynb")" \
  'sources/received/analysis.ipynb'

echo '--- Relative paths resolve against the stdin cwd ---'
expect_deny 'Edit relative, cwd = root' \
  "$(hook_json PreToolUse "$d" Edit file_path "$TRANSCRIPT_REL")" "$TRANSCRIPT_REL"
expect_deny 'Edit ../sources, cwd = dossier/' \
  "$(hook_json PreToolUse "$d/dossier" Edit file_path "../$TRANSCRIPT_REL")" "$TRANSCRIPT_REL"

echo '--- Path tricks: .., case variant, symlink ---'
expect_deny 'Edit dossier/../sources' \
  "$(hook_json PreToolUse "$d" Edit file_path "$d/dossier/../$TRANSCRIPT_REL")" "$TRANSCRIPT_REL"
expect_deny 'Write Sources/ case variant' \
  "$(hook_json PreToolUse "$d" Write file_path "$d/Sources/transcripts/x.txt")" '?ources/transcripts/x.txt'
ln -s sources "$d/notes"
expect_deny 'Edit through a symlink to sources' \
  "$(hook_json PreToolUse "$d" Edit file_path "$d/notes/transcripts/2026-10-01_kickoff.txt")" "$TRANSCRIPT_REL"

# --- Case 2: everything else is silent so the normal permission flow applies ---
echo '--- Writes elsewhere in the dossier are not touched ---'
expect_silent 'Edit dossier/HISTORY.md' \
  "$(hook_json PreToolUse "$d" Edit file_path "$d/dossier/HISTORY.md")"
expect_silent 'Write outbound/mails' \
  "$(hook_json PreToolUse "$d" Write file_path "$d/outbound/mails/2026-10-10_x.md")"
expect_silent 'Write knowledge/CONTEXT.md' \
  "$(hook_json PreToolUse "$d" Write file_path "$d/knowledge/CONTEXT.md")"
expect_silent 'Edit a file named like sources but under dossier/' \
  "$(hook_json PreToolUse "$d" Edit file_path "$d/dossier/sources.md")"

echo '--- Outside any dossier ---'
plain=$(mktemp -d)
mkdir -p "$plain/sources"
expect_silent 'Edit under a sources/ folder without dossier.yaml' \
  "$(hook_json PreToolUse "$plain" Edit file_path "$plain/sources/x.txt")"

# --- Case 3: nested dossiers, the nearest one wins (PROTO-08) ---
echo '--- Nested dossier ---'
mkdir -p "$d/clients/acme"
python3 "$(init_py)" --target "$d/clients/acme" --language en \
  --counterpart 'Acme Consulting|ordering party|Jane Doe' >/dev/null 2>&1
expect_deny 'Edit in the inner dossier sources/ (session cwd = outer root)' \
  "$(hook_json PreToolUse "$d" Edit file_path "$d/clients/acme/sources/x.txt")" 'sources/x.txt'
expect_silent 'Edit in the inner dossier dossier/' \
  "$(hook_json PreToolUse "$d" Edit file_path "$d/clients/acme/dossier/HISTORY.md")"

# --- Case 4: fail open ---
echo '--- Fail open ---'
expect_silent 'stdin is not JSON' 'not json'
expect_silent 'stdin is an empty object' '{}'
expect_silent 'Edit without file_path' \
  "$(hook_json PreToolUse "$d" Edit old_string x)"
expect_silent 'read-only Bash call' \
  "$(hook_json PreToolUse "$d" Bash command 'ls sources')"
expect_silent 'unknown tool' \
  "$(hook_json PreToolUse "$d" Read file_path "$d/$TRANSCRIPT_REL")"

rm -rf "$d" "$plain"

finish
