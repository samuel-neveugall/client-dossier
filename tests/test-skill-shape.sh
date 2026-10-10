#!/usr/bin/env bash
# tests/test-skill-shape.sh — mechanical checks on skills/dossier-init/SKILL.md
# (SCAF-06/SCAF-07, plan 01-06). No scratch repo needed: this test only reads
# the tracked SKILL.md and greps it. It proves two things a golden-file test
# on init.py's output cannot: that the judgement layer's prose is complete
# (every .gitkeep leaf and every dossier.yaml key named, so the D-07 inline
# fallback is not gestured at), and that the file stays inside this phase's
# authority (no mention of the Phase 2 linter, hooks, marketplace manifests
# or a commands/ folder).
set -u

# shellcheck source=./lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SKILL_MD="$REPO_ROOT/skills/dossier-init/SKILL.md"
SKILL_DIR_NAME="$(basename "$(dirname "$SKILL_MD")")"

assert_file "$SKILL_MD"

# --- Frontmatter shape ---
assert_grep_e '^name: dossier-init$' "$SKILL_MD"
assert_eq 'dossier-init' "$SKILL_DIR_NAME" 'the containing folder is named dossier-init, matching name:'

DESC_LEN=$(sed -n 's/^description: //p' "$SKILL_MD" | head -1 | tr -d '\n' | wc -c | tr -d ' ')
if [ "$DESC_LEN" -gt 0 ] && [ "$DESC_LEN" -le 1536 ]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "FAIL: description: length $DESC_LEN is not in (0, 1536]" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

LINE_COUNT=$(wc -l < "$SKILL_MD" | tr -d ' ')
if [ "$LINE_COUNT" -lt 500 ]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "FAIL: SKILL.md is $LINE_COUNT lines, expected under 500" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# --- R4-M4: no skill carries allowed-tools (a Skill call that needs approval never loads headless) ---
for skill_file in "$REPO_ROOT"/skills/*/SKILL.md; do
  if grep -qE '^allowed-tools:' "$skill_file"; then
    echo "FAIL: $(basename "$(dirname "$skill_file")") carries allowed-tools in its frontmatter (R4-M4)" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  else
    TESTS_PASSED=$((TESTS_PASSED + 1))
  fi
done

# --- Bundled-resource reference pattern (never a repository-relative path) ---
SKILL_DIR_COUNT=$(grep -c 'CLAUDE_SKILL_DIR' "$SKILL_MD")
if [ "$SKILL_DIR_COUNT" -ge 2 ]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "FAIL: expected \${CLAUDE_SKILL_DIR} at least twice, found $SKILL_DIR_COUNT" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

RELPATH_COUNT=$(grep -c -E '(\.\./|\./)?skills/dossier-init/scripts/init\.py' "$SKILL_MD")
assert_eq 0 "$RELPATH_COUNT" 'no line names the script by a repository-relative path'

# --- The D-07 inline fallback is complete: all seven .gitkeep leaves ---
for leaf in 'sources/received' 'sources/transcripts/raw' 'knowledge/decisions' \
  'knowledge/watch' 'outbound/deliverables' 'outbound/mails' 'outbound/calls'; do
  assert_grep "$leaf" "$SKILL_MD"
done

# --- ...and all ten dossier.yaml keys ---
for key in 'version' 'language' 'counterparts' 'confidential_names' 'consent_recorded' \
  'consent_source' 'timestamps' 'date_format' 'status_header' 'staleness_days'; do
  assert_grep "$key" "$SKILL_MD"
done

# --- The rename-execution surface: proposal flag and the git mv it drives ---
assert_grep '--propose-renames' "$SKILL_MD"
assert_grep 'git mv -- ' "$SKILL_MD"

# --- The never-commits rule and the human-confirmation rule ---
assert_eq 1 "$([ "$(grep -ci 'never commit' "$SKILL_MD")" -ge 1 ] && echo 1 || echo 0)" 'body states the never-commits rule'
assert_eq 1 "$([ "$(grep -ci 'confirmation' "$SKILL_MD")" -ge 1 ] && echo 1 || echo 0)" 'body states the human-confirmation rule'

# --- Out-of-scope negative greps: nothing outside this phase's authority ---
OUT_OF_SCOPE_COUNT=$(grep -ci -E 'stop hook|lint\.py|hooks\.json|marketplace\.json|commands/' "$SKILL_MD")
assert_eq 0 "$OUT_OF_SCOPE_COUNT" 'no mention of the Phase 2 linter, hooks.json, marketplace.json or a commands/ folder'

SESSION_AUTOMATION_COUNT=$(grep -ci -E 'sessionstart|pretooluse|session-event' "$SKILL_MD")
assert_eq 0 "$SESSION_AUTOMATION_COUNT" 'no mention of session-event automation'

finish
