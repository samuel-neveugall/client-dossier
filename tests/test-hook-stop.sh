#!/usr/bin/env bash
# tests/test-hook-stop.sh — PROTO-06 as settled by D-01 and D-02, and the
# PROTO-08 root rule for hooks: hooks/stop-check.py is the Stop hook. When
# `git status` of the nearest dossier shows uncommitted changes under outbound/
# or sources/ and none under dossier/, it blocks the stop ONCE with a reason
# addressed to the agent; with stop_hook_active true it stays silent, so it can
# never loop (D-01). The trigger is stateless: not a git repository, git
# missing, no dossier.yaml, a fresh uncommitted scaffold, a sibling dossier's
# changes and changes that include dossier/ all leave it silent (D-02).
# The hook is fed stdin JSON the way Claude Code feeds it; no model involved.
#
# Contract asserted on every case: exit 0 and empty stderr.
set -u

# shellcheck source=./lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# No case may depend on the caller's environment (P-02 reads this variable).
unset CLAUDE_PLUGIN_ROOT

# stop_json CWD ACTIVE — the Stop stdin: ACTIVE is the word true or false.
stop_json() {
  python3 -c 'import json, sys
d = {"hook_event_name": "Stop", "cwd": sys.argv[1],
     "stop_hook_active": sys.argv[2] == "true",
     "session_id": "test", "transcript_path": "/dev/null"}
print(json.dumps(d))' "$1" "$2"
}

# scaffold TARGET — a dossier made by the real init.py (no git involved).
scaffold() {
  mkdir -p "$1"
  python3 "$(init_py)" --target "$1" --language en \
    --counterpart 'Acme Consulting|ordering party|Jane Doe' >/dev/null 2>&1
}

# commit_all REPO LABEL — stage everything and commit it, quietly.
commit_all() {
  git -C "$1" add -A >/dev/null 2>&1
  git -C "$1" commit -qm "$2" >/dev/null 2>&1
}

# committed_dossier — a git repository holding one committed, clean scaffold.
# Echoes its path. Outputs are never written inside it.
committed_dossier() {
  local d
  d="$(scratch_repo)"
  scaffold "$d"
  commit_all "$d" scaffold
  echo "$d"
}

# new_file PATH — create an untracked file (and its folder) with one line.
new_file() {
  mkdir -p "$(dirname "$1")"
  printf '%s\n' 'Reply draft, written 2026-10-10.' >"$1"
}

# check_common LABEL — every case: exit 0, empty stderr.
check_common() {
  local label="$1"
  assert_eq 0 "$HOOK_STATUS" "$label: exit status 0"
  assert_eq '' "$HOOK_ERR" "$label: empty stderr"
}

# expect_silent LABEL JSON — the hook prints nothing at all.
expect_silent() {
  local label="$1" json="$2"
  run_hook stop-check.py "$json"
  check_common "$label"
  assert_eq '' "$HOOK_OUT" "$label: empty stdout"
}

# expect_block LABEL JSON TOUCHED — the hook blocks, with a reason naming
# TOUCHED ("outbound/", "sources/" or "outbound/ and sources/"), saying
# nothing under dossier/ changed and asking for the living files to be updated.
expect_block() {
  local label="$1" json="$2" touched="$3" reason
  run_hook stop-check.py "$json"
  check_common "$label"
  assert_eq block "$(hook_field decision)" "$label: decision is block"
  reason="$(hook_field reason)"
  case "$reason" in
    "$touched changed in this dossier"*) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
    *)
      echo "FAIL: $label (reason does not start with '$touched changed in this dossier': '$reason')" >&2
      TESTS_FAILED=$((TESTS_FAILED + 1))
      ;;
  esac
  case "$reason" in
    *"nothing under dossier/"*) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
    *)
      echo "FAIL: $label (no 'nothing under dossier/' in: '$reason')" >&2
      TESTS_FAILED=$((TESTS_FAILED + 1))
      ;;
  esac
  case "$reason" in
    *"update the living files"*) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
    *)
      echo "FAIL: $label (no 'update the living files' in: '$reason')" >&2
      TESTS_FAILED=$((TESTS_FAILED + 1))
      ;;
  esac
}

echo '--- Case 1: outbound changed, dossier not: block, naming outbound/ ---'
D="$(committed_dossier)"
new_file "$D/outbound/mails/2026-10-10_reply.md"
expect_block 'outbound only' "$(stop_json "$D" false)" 'outbound/'
case "$(hook_field reason)" in
  *"sources/"*)
    echo 'FAIL: outbound only (the reason names sources/ although it did not change)' >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
    ;;
  *) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
esac
case "$(hook_field reason)" in
  *dossier-status*)
    echo 'FAIL: outbound only (the reason names dossier-status with CLAUDE_PLUGIN_ROOT unset)' >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
    ;;
  *) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
esac

echo '--- Case 2: cwd in a subfolder gives the same block ---'
expect_block 'cwd in outbound/mails' "$(stop_json "$D/outbound/mails" false)" 'outbound/'

echo '--- Case 3: block once (D-01): stop_hook_active true is silent ---'
expect_silent 'stop_hook_active true' "$(stop_json "$D" true)"

echo '--- Case 4: a change under dossier/ satisfies the check ---'
printf '%s\n' '2026-10-10: reply drafted (mail 2026-10-10 from Jane).' >>"$D/dossier/HISTORY.md"
expect_silent 'outbound change plus a dossier/ change' "$(stop_json "$D" false)"
git -C "$D" checkout -q -- dossier/HISTORY.md
expect_block 'dossier/ change reverted: blocks again' "$(stop_json "$D" false)" 'outbound/'
rm -rf "$D"

echo '--- Case 5: sources only; and both sides ---'
D="$(committed_dossier)"
new_file "$D/sources/received/2026-10-10_brochure.txt"
expect_block 'sources only' "$(stop_json "$D" false)" 'sources/'
case "$(hook_field reason)" in
  *"outbound/"*)
    echo 'FAIL: sources only (the reason names outbound/ although it did not change)' >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
    ;;
  *) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
esac
new_file "$D/outbound/mails/2026-10-10_reply.md"
expect_block 'outbound and sources' "$(stop_json "$D" false)" 'outbound/ and sources/'
rm -rf "$D"

echo '--- Case 6: knowledge/ alone does not trigger ---'
D="$(committed_dossier)"
new_file "$D/knowledge/CONTEXT.md"
expect_silent 'knowledge/CONTEXT.md change alone' "$(stop_json "$D" false)"
rm -rf "$D"

echo '--- Case 7: renames count on both sides ---'
D="$(committed_dossier)"
git -C "$D" mv sources/README.md sources/README2.md >/dev/null 2>&1
expect_block 'staged rename inside sources/' "$(stop_json "$D" false)" 'sources/'
git -C "$D" reset -q >/dev/null 2>&1
git -C "$D" checkout -q -- . >/dev/null 2>&1
rm -f "$D/sources/README2.md"
# A rename from dossier/ out to outbound/ touches dossier/ on its old side.
git -C "$D" mv dossier/TONE.md outbound/TONE.md >/dev/null 2>&1
expect_silent 'rename from dossier/ to outbound/' "$(stop_json "$D" false)"
git -C "$D" reset -q >/dev/null 2>&1
git -C "$D" checkout -q -- . >/dev/null 2>&1
rm -f "$D/outbound/TONE.md"
# A rename from outbound/ into sources/ touches only the guarded folders.
new_file "$D/outbound/mails/draft.md"
commit_all "$D" 'a draft'
git -C "$D" mv outbound/mails/draft.md sources/received/draft.md >/dev/null 2>&1
expect_block 'rename from outbound/ to sources/' "$(stop_json "$D" false)" 'outbound/ and sources/'
rm -rf "$D"

echo '--- Case 8: a fresh, never committed scaffold is silent ---'
D="$(scratch_repo)"
scaffold "$D"
expect_silent 'fresh scaffold, nothing committed' "$(stop_json "$D" false)"
# Even with a new outbound file in it: the whole folder is untracked.
new_file "$D/outbound/mails/2026-10-10_reply.md"
expect_silent 'fresh scaffold plus an outbound file' "$(stop_json "$D" false)"
rm -rf "$D"

echo '--- Case 9: a dossier in a subfolder of a larger repository ---'
D="$(scratch_repo)"
printf '%s\n' 'Top-level readme.' >"$D/README.md"
scaffold "$D/clients/acme"
scaffold "$D/clients/beta"
commit_all "$D" 'two dossiers'
new_file "$D/clients/acme/outbound/mails/2026-10-10_reply.md"
expect_block 'subfolder dossier, own change (prefix stripped)' "$(stop_json "$D/clients/acme" false)" 'outbound/'
expect_block 'subfolder dossier, cwd below its root' "$(stop_json "$D/clients/acme/outbound/mails" false)" 'outbound/'
expect_silent 'sibling dossier has no change of its own' "$(stop_json "$D/clients/beta" false)"
rm -f "$D/clients/acme/outbound/mails/2026-10-10_reply.md"
new_file "$D/clients/beta/outbound/mails/2026-10-10_other.md"
expect_block 'sibling dossier, its own change' "$(stop_json "$D/clients/beta" false)" 'outbound/'
expect_silent 'cwd acme, only the sibling changed' "$(stop_json "$D/clients/acme" false)"
scaffold "$D/clients/gamma"
expect_silent 'wholly untracked sibling dossier' "$(stop_json "$D/clients/gamma" false)"
rm -rf "$D"

echo '--- Case 10: nested dossiers, the nearest wins ---'
D="$(scratch_repo)"
scaffold "$D"
scaffold "$D/clients/acme"
commit_all "$D" 'outer and inner dossiers'
new_file "$D/outbound/mails/2026-10-10_outer.md"
expect_silent 'inner cwd, change in the outer dossier only' "$(stop_json "$D/clients/acme" false)"
expect_block 'outer cwd, change in the outer dossier' "$(stop_json "$D" false)" 'outbound/'
rm -rf "$D"

echo '--- Case 11: not a git repository, git missing, no dossier, malformed stdin ---'
P="$(mktemp -d)"
scaffold "$P"
new_file "$P/outbound/mails/2026-10-10_reply.md"
expect_silent 'not a git repository' "$(stop_json "$P" false)"
rm -rf "$P"

D="$(committed_dossier)"
new_file "$D/outbound/mails/2026-10-10_reply.md"
PY="$(command -v python3)"
ERR_FILE="$(mktemp)"
HOOK_STATUS=0
HOOK_OUT="$(printf '%s' "$(stop_json "$D" false)" | PATH=/nonexistent "$PY" "$(hooks_dir)/stop-check.py" 2>"$ERR_FILE")" || HOOK_STATUS=$?
HOOK_ERR="$(cat "$ERR_FILE")"
rm -f "$ERR_FILE"
check_common 'git missing from PATH'
assert_eq '' "$HOOK_OUT" 'git missing from PATH: empty stdout'
rm -rf "$D"

N="$(mktemp -d)"
expect_silent 'no dossier.yaml upward' "$(stop_json "$N" false)"
expect_silent 'malformed stdin' 'not json'
expect_silent 'empty stdin' ''
expect_silent 'JSON that is not an object' '[1, 2, 3]'
rm -rf "$N"

# --- P-02 (PROVISIONAL): dossier-status sentence ---
# P-02 (03-CONTEXT.md, awaiting Samuel): the Stop reason names dossier-status
# only once ${CLAUDE_PLUGIN_ROOT}/skills/dossier-status/SKILL.md exists (D-07:
# never point at a missing skill). Exactly two cases pin it; if Samuel picks
# "always name it" or "never name it", these two assertions change with
# status_sentence() in hooks/stop-check.py and nothing else does.
D="$(committed_dossier)"
new_file "$D/outbound/mails/2026-10-10_reply.md"
STATUS_JSON="$(stop_json "$D" false)"

WITH_STATUS="$(mktemp -d)"
mkdir -p "$WITH_STATUS/skills/dossier-status"
printf '%s\n' '---' 'name: dossier-status' '---' >"$WITH_STATUS/skills/dossier-status/SKILL.md"
CLAUDE_PLUGIN_ROOT="$WITH_STATUS" run_hook stop-check.py "$STATUS_JSON"
check_common 'P-02, skill present'
assert_eq block "$(hook_field decision)" 'P-02, skill present: decision is block'
case "$(hook_field reason)" in
  *dossier-status*) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
  *)
    echo "FAIL: P-02, skill present (the reason does not name dossier-status: '$(hook_field reason)')" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
    ;;
esac

WITHOUT_STATUS="$(mktemp -d)"
CLAUDE_PLUGIN_ROOT="$WITHOUT_STATUS" run_hook stop-check.py "$STATUS_JSON"
check_common 'P-02, skill absent'
assert_eq block "$(hook_field decision)" 'P-02, skill absent: decision is block'
case "$(hook_field reason)" in
  *dossier-status*)
    echo "FAIL: P-02, skill absent (the reason names dossier-status: '$(hook_field reason)')" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
    ;;
  *) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
esac

# 03 D-14: with the real plugin root (this repository, which now holds
# skills/dossier-status/SKILL.md) the sentence appears on its own.
CLAUDE_PLUGIN_ROOT="$REPO_ROOT" run_hook stop-check.py "$STATUS_JSON"
check_common 'D-14, real plugin root'
assert_eq block "$(hook_field decision)" 'D-14, real plugin root: decision is block'
case "$(hook_field reason)" in
  *dossier-status*) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
  *)
    echo "FAIL: D-14, real plugin root (the reason does not name dossier-status: '$(hook_field reason)')" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
    ;;
esac
rm -rf "$D" "$WITH_STATUS" "$WITHOUT_STATUS"
# --- end P-02 (PROVISIONAL) ---

finish
