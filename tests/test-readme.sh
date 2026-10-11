#!/usr/bin/env bash
# tests/test-readme.sh — the free README, LICENSE and CHANGELOG checks.
#
# Pins DIST-05 (the documented limits of the sources guard and of the
# confidential-name check), DIST-03 (what a bare-skills install loses), D-08
# (the README covers the four install targets), D-13 (Codex hook trust and the
# public plugin directory), D-16 (versioning, and the permanent coherence rule
# between CHANGELOG.md and the manifests), 03 D-04 / 03 D-17 (the guard's
# limits) and 05 D-09 (the confidential-name debt). Plan 07-06.
#
# Free: no network, no harness, no write outside mktemp. Bash 3.2.
set -u
# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

README="$REPO_ROOT/README.md"
LICENSE_FILE="$REPO_ROOT/LICENSE"
CHANGELOG="$REPO_ROOT/CHANGELOG.md"
MANIFEST="$REPO_ROOT/.claude-plugin/plugin.json"

# has_fixed STRING PATH LABEL — STRING occurs in PATH (grep -F: regex characters
# in STRING are literal). has_fixed_i is the case-insensitive form.
has_fixed() {
  if grep -qF -- "$1" "$2" 2>/dev/null; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "FAIL: $3 (missing: $1)" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}
has_fixed_i() {
  if grep -qiF -- "$1" "$2" 2>/dev/null; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "FAIL: $3 (missing, case-insensitive: $1)" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}
# has_heading LINE — LINE is a whole line of the README.
has_heading() {
  if grep -qxF -- "$1" "$README" 2>/dev/null; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "FAIL: README heading missing: $1" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

assert_file "$README"
assert_file "$LICENSE_FILE"
assert_file "$CHANGELOG"

# --- The headings of the outline, whole lines --------------------------------
has_heading '# client-dossier'
has_heading '## What it is'
has_heading '## The dossier layout'
has_heading '## Installation'
has_heading '### Claude Code'
has_heading '### Codex'
has_heading '### Agent Skills harnesses (Cursor, Copilot CLI, Gemini CLI, OpenCode)'
has_heading '### Without a plugin (AGENTS.md only)'

# --- The layout and the untranslated protocol keywords -----------------------
for kw in 'dossier.yaml' 'sources/' 'dossier/' 'knowledge/' 'outbound/' \
  'Last updated:' 'Status:' 'To:' 'Subject:' 'Deadline:' 'Written by:' 'Rules:' \
  '`draft`' '`reviewed by`' '`sent`'; do
  has_fixed "$kw" "$README" "README layout/keyword"
done

# --- Install strings ---------------------------------------------------------
for s in \
  '/plugin marketplace add samuel-neveugall/client-dossier' \
  '/plugin install client-dossier@client-dossier' \
  'claude plugin marketplace add samuel-neveugall/client-dossier' \
  'claude plugin install client-dossier@client-dossier' \
  '@v1.0.0' \
  'codex plugin marketplace add samuel-neveugall/client-dossier' \
  '--ref v1.0.0' \
  'codex plugin add client-dossier@client-dossier' \
  '/hooks' \
  'npx skills add samuel-neveugall/client-dossier' \
  'skills@1.7.0' \
  'AGENTS.md'; do
  has_fixed "$s" "$README" "README install string"
done
# The pin tested in plan 07-05 is 1.7.0; the untested 1.7.2 must not be named.
assert_not_grep 'skills@1\.7\.2' "$README"

# --- What the bare-skills install loses --------------------------------------
for s in 'What this install loses' 'scripts/lint.py' 'fact-extractor' \
  'doctrine-reviewer' 'hooks' 'CLAUDE_SKILL_DIR'; do
  has_fixed "$s" "$README" "README loses list"
done

# --- No home path and no e-mail address (T-07-21) ----------------------------
assert_not_grep '/Users/' "$README"
assert_not_grep '/home/' "$README"
readme_has_no_email() {
  if grep -Eq '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' "$README" 2>/dev/null; then
    echo "FAIL: README holds an e-mail address" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  else
    TESTS_PASSED=$((TESTS_PASSED + 1))
  fi
}
readme_has_no_email
# The command paragraph (### Commands) belongs to plan 07-08, not to this plan.
if grep -qi 'dossier-lint' "$README" 2>/dev/null; then
  echo "FAIL: README names dossier-lint (plan 07-08 owns the command paragraph)" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
else
  TESTS_PASSED=$((TESTS_PASSED + 1))
fi

# --- LICENSE -----------------------------------------------------------------
assert_eq 'MIT License' "$(head -n 1 "$LICENSE_FILE")" 'LICENSE first line'
has_fixed 'Copyright (c) 2026 Samuel Neveu' "$LICENSE_FILE" 'LICENSE copyright line'
has_fixed 'Permission is hereby granted, free of charge' "$LICENSE_FILE" 'LICENSE grant'

# --- CHANGELOG and the permanent version coherence rule ----------------------
assert_grep '^## \[Unreleased\]' "$CHANGELOG"
COHERENCE="$(python3 -I - "$MANIFEST" "$CHANGELOG" <<'PY'
import json
import re
import sys

manifest, changelog = sys.argv[1], sys.argv[2]
version = json.load(open(manifest, encoding="utf-8"))["version"]
heading = re.compile(r"^## \[(\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.+-]+)?)\] - \d{4}-\d{2}-\d{2}\s*$")
newest = None
with open(changelog, encoding="utf-8") as handle:
    for line in handle:
        found = heading.match(line)
        if found:
            newest = found.group(1)
            break
if newest is not None:
    print("ok" if newest == version else "bad: newest released heading %s, manifest %s" % (newest, version))
else:
    print("ok" if version == "0.1.0" else "bad: no released heading, manifest %s is not 0.1.0" % version)
PY
)"
assert_eq 'ok' "$COHERENCE" 'CHANGELOG newest released heading equals the manifest version (else 0.1.0)'

# PART2-CHECKS (limits, Codex directory, versioning, licence, privacy: task 2)

finish
