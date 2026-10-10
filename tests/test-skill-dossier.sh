#!/usr/bin/env bash
# tests/test-skill-dossier.sh — mechanical checks on skills/dossier/SKILL.md
# (PROTO-01 triggering, PROTO-02 content, PROTO-03 language, the PROTO-08 rule,
# D-05 step-aside, D-06 one file, D-07 self-updating pointers). Reads the
# tracked file and greps it; the behavioural proof is tests/scenarios/ (03-06).
set -u

# shellcheck source=./lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SKILL_MD="$REPO_ROOT/skills/dossier/SKILL.md"
SKILL_DIR="$(dirname "$SKILL_MD")"

# has FIXED_STRING LABEL — the body contains the exact string.
has() {
  if grep -qF -- "$1" "$SKILL_MD" 2>/dev/null; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "FAIL: SKILL.md lacks: $2 ($1)" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}
# has_not FIXED_STRING LABEL — the body does not contain the string.
has_not() {
  if grep -qF -- "$1" "$SKILL_MD" 2>/dev/null; then
    echo "FAIL: SKILL.md must not contain: $2 ($1)" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  else
    TESTS_PASSED=$((TESTS_PASSED + 1))
  fi
}

assert_file "$SKILL_MD"

# --- Frontmatter (PROTO-01) and the one-file rule (D-06) ---
assert_grep_e '^name: dossier$' "$SKILL_MD"
assert_eq 'dossier' "$(basename "$SKILL_DIR")" 'the containing folder is named dossier'
assert_eq 'SKILL.md' "$(ls -A "$SKILL_DIR" 2>/dev/null)" 'skills/dossier holds SKILL.md only (D-06)'

DESC="$(sed -n 's/^description: //p' "$SKILL_MD" | head -1 | tr -d '\n')"
DESC_LEN=$(printf '%s' "$DESC" | wc -c | tr -d ' ')
if [ "$DESC_LEN" -gt 0 ] && [ "$DESC_LEN" -le 1024 ]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "FAIL: description: length $DESC_LEN is not in (0, 1024]" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi
case "$DESC" in
  "Use when"*) TESTS_PASSED=$((TESTS_PASSED + 1)) ;;
  *) echo "FAIL: description does not start with 'Use when'" >&2; TESTS_FAILED=$((TESTS_FAILED + 1)) ;;
esac
for word in dossier.yaml client counterpart prospect partner call message; do
  if printf '%s' "$DESC" | grep -qi -- "$word"; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "FAIL: description lacks the trigger word: $word" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
done

LINE_COUNT=$(wc -l < "$SKILL_MD" 2>/dev/null | tr -d ' ')
if [ "${LINE_COUNT:-9999}" -lt 500 ]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "FAIL: SKILL.md is ${LINE_COUNT:-missing} lines, expected under 500" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# --- Discovery, step-aside and language (PROTO-08, D-05, PROTO-03) ---
has 'the nearest `dossier.yaml`' 'nearest dossier.yaml'
has 'the nearest one wins' 'several dossiers rule'
has 'say so in one line' 'step-aside: one line'
has "then continue with the user's task" 'step-aside: never blocks'
has 'task skills stop' 'task skills stop without a dossier'
has 'Protocol keywords stay in English' 'language rule: keywords'
has '`language`' 'language key'

# --- Pointers are self-updating (D-07) ---
for f in "$REPO_ROOT"/skills/*/SKILL.md; do
  name="$(basename "$(dirname "$f")")"
  [ "$name" = "dossier" ] && continue
  has "$name" "pointer to the existing skill $name"
done
for name in dossier-ingest dossier-draft dossier-call dossier-status; do
  if [ ! -f "$REPO_ROOT/skills/$name/SKILL.md" ]; then
    has_not "$name" "pointer to $name, which does not exist yet"
  fi
done

# --- Layout (PROTO-02) ---
for s in 'sources/' 'received/' 'transcripts/' 'raw/' 'dossier/' 'knowledge/' 'CONTEXT.md' \
  'DOCTRINE.md' 'decisions/' 'watch/' 'outbound/' 'deliverables/' 'mails/' 'calls/' \
  'YYYY-MM-DD_slug' 'ACTORS.md' 'HISTORY.md' 'LEARNINGS.md' 'TONE.md' 'CHANNELS.md' \
  'OPEN-QUESTIONS.md' 'RELATIONSHIP.md'; do
  has "$s" "layout name $s"
done

# --- Read before acting, update before handing back ---
for row in 'Any session' 'Write a message or a document' 'Prepare a call' 'Debrief a call' \
  'Check a fact' 'Ingest a source'; do
  assert_grep_e "^\\| *$row" "$SKILL_MD"
done
has 'before its final message' 'handing back means before the final message'
has 'knowledge/CONTEXT.md' 'context one-pager is read first'
has 'why none needed it' 'update-or-say-why rule (D-01)'

# --- Fact line ---
has '- <fact, one sentence, absolute dates> (<source>, <locator>).' 'fact-line format'
has 'call @12:34' 'source example: call'
has 'mail 2026-09-16 from Jane' 'source example: mail'
has 'brochure p. 4' 'source example: brochure'
has 'reconstructed' 'reconstructed marker'
has '(corrects a line dated' 'correction trace'
has 'Name (Organisation)' 'Name (Organisation) rule'

# --- A wrong source: every route, heuristic, worked example (D-04, D-09) ---
assert_grep_e '^- .*transcript reads .*\(call [0-9]{4}-[0-9]{2}-[0-9]{2} @[0-9]{2}:[0-9]{2}\)\.$' "$SKILL_MD"
has 'every route' 'the rule covers every route'
has 'heuristic' 'the Bash guard is a heuristic'
# Drift guard: the scenario fixture constants this check is copied from.
FIXTURE="$REPO_ROOT/tests/scenarios/fix-typo.sh"
TYPO_TOKEN="$(sed -n 's/^TYPO_TOKEN="\(.*\)"$/\1/p' "$FIXTURE" | head -1)"
TRANSCRIPT_REL="$(sed -n 's/^TRANSCRIPT_REL="\(.*\)"$/\1/p' "$FIXTURE" | head -1)"
assert_eq 'reprot' "$TYPO_TOKEN" 'fix-typo.sh still defines the typo token'
assert_eq 'sources/transcripts/2026-10-01_kickoff.txt' "$TRANSCRIPT_REL" 'fix-typo.sh still defines the transcript path'
if [ -n "$TYPO_TOKEN" ]; then has_not "$TYPO_TOKEN" 'the scenario fixture typo token'; fi
if [ -n "$TRANSCRIPT_REL" ]; then has_not "$(basename "$TRANSCRIPT_REL")" 'the scenario fixture transcript name'; fi

# --- Status header and the never-list ---
for s in 'Status:' 'To:' 'Subject:' 'Deadline:' 'Written by:' 'Rules:' 'draft' 'reviewed by' 'sent'; do
  has "$s" "status header keyword $s"
done
assert_grep_e '[Nn]ever mark' "$SKILL_MD"
assert_grep_e '^## .*[Nn]ever' "$SKILL_MD"
for s in 'consent_recorded: true' 'consent_source' 'doctrine' '.claude/'; do
  has "$s" "never-list token $s"
done

# --- Linter pointer: through the plugin root, with the bare-skills fallback ---
has '${CLAUDE_PLUGIN_ROOT}/scripts/lint.py' 'linter via the plugin root'
assert_eq "$(grep -c 'scripts/lint.py' "$SKILL_MD")" "$(grep 'scripts/lint.py' "$SKILL_MD" | grep -c '${CLAUDE_PLUGIN_ROOT}/')" 'every lint.py mention uses the plugin root'
assert_grep_e '[Nn]ot available' "$SKILL_MD"

finish
