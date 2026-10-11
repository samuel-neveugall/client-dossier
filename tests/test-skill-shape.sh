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

# --- DIST-03 (plan 07-03): script references are quoted, guarded and have a fallback ---
# A bare-skills install copies whole skill folders and nothing else, so every
# skill that names a script must (a) quote the plugin variable, (b) guard a
# bundled script with `test -x` and ship it executable inside its own folder,
# and (c) state what it does when the script is not available. The checker
# prints one line per violation; it is run on the real skills (zero expected)
# and on a mutated copy (exactly two expected, the negative control).
DIST03_CHECK='
import os, re, sys
root = sys.argv[1]
ref = re.compile(r"\$\{CLAUDE_(SKILL_DIR|PLUGIN_ROOT)\}/scripts/")
bundled = re.compile(r"\$\{CLAUDE_SKILL_DIR\}/scripts/([A-Za-z0-9._-]+)")
for skill in sorted(os.listdir(root)):
    path = os.path.join(root, skill, "SKILL.md")
    if not os.path.isfile(path):
        continue
    text = open(path, encoding="utf-8").read()
    for m in ref.finditer(text):
        if m.start() == 0 or text[m.start() - 1] != chr(34):
            line = text.count(chr(10), 0, m.start()) + 1
            print("%s: line %d: %s is not preceded by a double quote" % (skill, line, m.group(0)))
    for name in sorted(set(bundled.findall(text))):
        script = os.path.join(root, skill, "scripts", name)
        if not (os.path.isfile(script) and os.access(script, os.X_OK)):
            print("%s: scripts/%s is missing or not executable inside the skill folder" % (skill, name))
        guard = "test -x " + chr(34) + "${CLAUDE_SKILL_DIR}/scripts/" + name + chr(34)
        if guard not in text:
            print("%s: no `%s` guard line for %s" % (skill, guard, name))
    if ref.search(text) and "not available" not in text:
        print("%s: references a script but states no `not available` fallback" % skill)
'
DIST03_MUTATE='
import os, sys
root = sys.argv[1]
status = os.path.join(root, "dossier-status", "SKILL.md")
lines = open(status, encoding="utf-8").read().split(chr(10))
hit = [i for i, l in enumerate(lines) if l.startswith(chr(34) + "${CLAUDE_SKILL_DIR}/scripts/status.py" + chr(34) + " ")]
assert len(hit) == 1, hit
lines[hit[0]] = lines[hit[0]][1:]
open(status, "w", encoding="utf-8").write(chr(10).join(lines))
ingest = os.path.join(root, "dossier-ingest", "SKILL.md")
lines = open(ingest, encoding="utf-8").read().split(chr(10))
guard = "test -x " + chr(34) + "${CLAUDE_SKILL_DIR}/scripts/extract-text.sh" + chr(34)
keep = [l for l in lines if l.strip() != guard]
assert len(keep) == len(lines) - 1
open(ingest, "w", encoding="utf-8").write(chr(10).join(keep))
'
DIST03_REAL="$(python3 -c "$DIST03_CHECK" "$REPO_ROOT/skills")"
assert_eq '' "$DIST03_REAL" 'DIST-03: every skill quotes, guards and states a fallback for its script references'

DIST03_TMP="$(mktemp -d)"
cp -R "$REPO_ROOT/skills" "$DIST03_TMP/skills"
python3 -c "$DIST03_MUTATE" "$DIST03_TMP/skills"
DIST03_MUT="$(python3 -c "$DIST03_CHECK" "$DIST03_TMP/skills")"
rm -rf "$DIST03_TMP"
assert_eq 2 "$(printf '%s\n' "$DIST03_MUT" | grep -c .)" 'DIST-03 negative control: the mutated copy reports exactly 2 violations'
assert_eq 1 "$(printf '%s\n' "$DIST03_MUT" | grep -c '^dossier-status: .*not preceded by a double quote')" 'DIST-03 negative control: the unquoted status.py call is named'
assert_eq 1 "$(printf '%s\n' "$DIST03_MUT" | grep -c '^dossier-ingest: no .*extract-text.sh')" 'DIST-03 negative control: the missing extract-text.sh guard is named'

finish
