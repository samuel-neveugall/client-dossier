#!/usr/bin/env bash
# tests/test-hook-session-start.sh — PROTO-04 and the PROTO-08 root rule for
# hooks: hooks/session-start.py is the SessionStart hook. When a dossier.yaml
# is found upward from the session cwd it prints one JSON object whose
# additionalContext says the repository is a client dossier, names the nearest
# root and tells the agent to load the `dossier` skill (client-dossier:dossier);
# without a dossier.yaml it prints nothing. It never reads dossier.yaml, so no
# confidential name can reach the model through it (T-03-15).
# The hook is fed stdin JSON the way Claude Code feeds it; no model involved.
#
# Contract asserted on every case: exit 0 and empty stderr.
set -u

# shellcheck source=./lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# realpath_of PATH — the symlink-resolved path, as the hook reports it.
realpath_of() {
  python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$1"
}

# build_dossier TARGET — a scaffolded dossier (real init.py) with a
# confidential name in dossier.yaml. Nothing is written inside it afterwards.
build_dossier() {
  python3 "$(init_py)" --target "$1" --language en \
    --counterpart 'Acme Consulting|ordering party|Jane Doe' \
    --confidential-name Acme >/dev/null 2>&1
}

# session_json CWD SOURCE — the SessionStart stdin: `cwd` only when CWD is
# non-empty, `source` only when SOURCE is non-empty. Built by python3.
session_json() {
  python3 -c 'import json, sys
cwd, source = sys.argv[1], sys.argv[2]
d = {"hook_event_name": "SessionStart", "session_id": "test", "transcript_path": "/dev/null"}
if cwd:
    d["cwd"] = cwd
if source:
    d["source"] = source
print(json.dumps(d))' "$1" "$2"
}

# check_common LABEL — every case: exit 0, empty stderr.
check_common() {
  local label="$1"
  assert_eq 0 "$HOOK_STATUS" "$label: exit status 0"
  assert_eq '' "$HOOK_ERR" "$label: empty stderr"
}

# expect_reminder LABEL JSON ROOT — the hook prints the reminder naming ROOT.
expect_reminder() {
  local label="$1" json="$2" root="$3" ctx
  run_hook session-start.py "$json"
  check_common "$label"
  assert_eq SessionStart "$(hook_field hookSpecificOutput.hookEventName)" "$label: hookEventName"
  ctx="$(hook_field hookSpecificOutput.additionalContext)"
  case "$ctx" in
    *"client dossier"*) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
    *)
      echo "FAIL: $label (no 'client dossier' in: '$ctx')" >&2
      TESTS_FAILED=$((TESTS_FAILED + 1))
      ;;
  esac
  case "$ctx" in
    *"client-dossier:dossier"*) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
    *)
      echo "FAIL: $label (no 'client-dossier:dossier' in: '$ctx')" >&2
      TESTS_FAILED=$((TESTS_FAILED + 1))
      ;;
  esac
  case "$ctx" in
    *'`dossier` skill'*) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
    *)
      echo "FAIL: $label (no 'dossier skill' in: '$ctx')" >&2
      TESTS_FAILED=$((TESTS_FAILED + 1))
      ;;
  esac
  case "$ctx" in
    *"dossier.yaml at $root)"*) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
    *)
      echo "FAIL: $label (no 'dossier.yaml at $root)' in: '$ctx')" >&2
      TESTS_FAILED=$((TESTS_FAILED + 1))
      ;;
  esac
  # Two lines at most, and never the confidential name from dossier.yaml.
  assert_eq 1 "$(printf '%s\n' "$ctx" | wc -l | tr -d ' ' | awk '{ print ($1 <= 2) ? 1 : 0 }')" "$label: at most two lines"
  case "$ctx" in
    *Acme*)
      echo "FAIL: $label (the confidential name leaked into the reminder)" >&2
      TESTS_FAILED=$((TESTS_FAILED + 1))
      ;;
    *) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
  esac
}

# expect_silent LABEL JSON — the hook prints nothing at all.
expect_silent() {
  local label="$1" json="$2"
  run_hook session-start.py "$json"
  check_common "$label"
  assert_eq '' "$HOOK_OUT" "$label: empty stdout"
}

D="$(scratch_repo)"
build_dossier "$D"
R="$(realpath_of "$D")"

echo '--- Case 1: cwd is the dossier root ---'
expect_reminder 'root' "$(session_json "$D" startup)" "$R"

echo '--- Case 2: cwd is a subfolder of the dossier ---'
mkdir -p "$D/outbound/mails"
expect_reminder 'subfolder' "$(session_json "$D/outbound/mails" startup)" "$R"
expect_reminder 'subfolder, given as the resolved path' "$(session_json "$R/outbound/mails" startup)" "$R"

echo '--- Case 3: nested dossier, the nearest wins ---'
mkdir -p "$D/clients/acme"
build_dossier "$D/clients/acme"
expect_reminder 'nested, at the inner root' "$(session_json "$D/clients/acme" startup)" "$R/clients/acme"
expect_reminder 'nested, in the inner dossier folder' "$(session_json "$D/clients/acme/dossier" startup)" "$R/clients/acme"
expect_reminder 'nested, outer cwd still names the outer root' "$(session_json "$D/knowledge" startup)" "$R"

echo '--- Case 4: no dossier.yaml upward, silent ---'
PLAIN="$(mktemp -d)"
expect_silent 'plain directory' "$(session_json "$PLAIN" startup)"
expect_silent 'plain directory, source resume' "$(session_json "$PLAIN" resume)"

echo '--- Case 5: malformed stdin and missing cwd ---'
expect_silent 'malformed stdin' 'not json'
expect_silent 'empty stdin' ''
expect_silent 'JSON that is not an object' '[1, 2, 3]'
# No `cwd` key: the hook falls back to the process cwd (R/knowledge). The
# subshell keeps the cd local; HOOK_* are set in the parent shell.
ERR_FILE="$(mktemp)"
HOOK_STATUS=0
HOOK_OUT="$(cd "$D/knowledge" && printf '%s' "$(session_json '' startup)" | python3 "$(hooks_dir)/session-start.py" 2>"$ERR_FILE")" || HOOK_STATUS=$?
HOOK_ERR="$(cat "$ERR_FILE")"
rm -f "$ERR_FILE"
check_common 'missing cwd'
case "$(hook_field hookSpecificOutput.additionalContext)" in
  *"dossier.yaml at $R)"*) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
  *)
    echo "FAIL: missing cwd (the process cwd fallback did not name $R)" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
    ;;
esac

echo '--- Case 6: every source value gets the reminder (no matcher) ---'
for source in startup resume clear compact fork; do
  expect_reminder "source $source" "$(session_json "$D" "$source")" "$R"
done
expect_reminder 'no source key' "$(session_json "$D" '')" "$R"

echo '--- Case 7: a dossier.yaml that cannot be read does not matter ---'
# The hook only tests that the file exists; it never opens it (T-03-15).
U="$(scratch_repo)"
build_dossier "$U"
chmod 000 "$U/dossier.yaml"
UR="$(realpath_of "$U")"
expect_reminder 'unreadable dossier.yaml' "$(session_json "$U" startup)" "$UR"
chmod 644 "$U/dossier.yaml"

rm -rf "$D" "$U" "$PLAIN"

finish
