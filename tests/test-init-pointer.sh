#!/usr/bin/env bash
# tests/test-init-pointer.sh — SCAF-05 / D-16: the protocol-pointer section
# `init.py` upserts into AGENTS.md (always) and CLAUDE.md (only when it
# already exists), marker-delimited so a re-run replaces the span in place
# instead of duplicating it. This is RESEARCH Pitfall 7, the one documented
# exception to D-08's skip-if-the-file-exists rule: the file may exist
# without the section, so "skip because it exists" would silently do
# nothing.
#
# Fails now: `init.py` writes no pointer yet (RED gate for Task 3).
set -u

# shellcheck source=./lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

START_MARKER='^<!-- client-dossier:start -->$'
END_MARKER='^<!-- client-dossier:end -->$'

# --- Case A: neither instructions file exists ---
dA=$(scratch_repo)
statusA=0
python3 "$(init_py)" \
  --target "$dA" \
  --language en \
  --counterpart 'Acme Consulting|ordering party|Jane Doe' \
  >"$dA.stdout" 2>"$dA.stderr" || statusA=$?
assert_eq 0 "$statusA" 'Case A: init exits 0 on a repo with no instructions files'

assert_file "$dA/AGENTS.md"
assert_eq 1 "$(grep -c "$START_MARKER" "$dA/AGENTS.md" 2>/dev/null)" 'Case A: exactly one start marker in AGENTS.md'
assert_eq 1 "$(grep -c "$END_MARKER" "$dA/AGENTS.md" 2>/dev/null)" 'Case A: exactly one end marker in AGENTS.md'
assert_grep 'sources' "$dA/AGENTS.md"
assert_grep 'dossier' "$dA/AGENTS.md"
assert_grep 'knowledge' "$dA/AGENTS.md"
assert_grep 'outbound' "$dA/AGENTS.md"
assert_grep_e '^pointer: ' "$dA.stdout"

if [ -e "$dA/CLAUDE.md" ]; then
  echo "FAIL: expected CLAUDE.md NOT to be created on a repo where it did not exist" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
else
  TESTS_PASSED=$((TESTS_PASSED + 1))
fi

# Case F (English variant): scope — the pointer says nothing about the
# Phase 2 linter or the Phase 3 Stop-hook decision, which is Samuel's to
# take (CLAUDE.md C-12).
assert_eq 0 "$(grep -ci 'stop hook' "$dA/AGENTS.md" 2>/dev/null)" 'Case F (en): AGENTS.md does not mention a Stop hook'
assert_eq 0 "$(grep -c 'lint.py' "$dA/AGENTS.md" 2>/dev/null)" 'Case F (en): AGENTS.md does not mention lint.py'

rm -rf "$dA" "$dA.stdout" "$dA.stderr"

# --- Case B: CLAUDE.md exists, AGENTS.md does not ---
dB=$(scratch_repo)
printf 'SENTINEL-EXISTING-INSTRUCTIONS\n' >"$dB/CLAUDE.md"
statusB=0
python3 "$(init_py)" \
  --target "$dB" \
  --language en \
  --counterpart 'Acme Consulting|ordering party|Jane Doe' \
  >"$dB.stdout1" 2>"$dB.stderr1" || statusB=$?
assert_eq 0 "$statusB" 'Case B: init exits 0 with a pre-existing CLAUDE.md'

assert_file "$dB/AGENTS.md"
assert_eq 1 "$(grep -c "$START_MARKER" "$dB/AGENTS.md" 2>/dev/null)" 'Case B: exactly one start marker in AGENTS.md'
assert_eq 1 "$(grep -c "$END_MARKER" "$dB/AGENTS.md" 2>/dev/null)" 'Case B: exactly one end marker in AGENTS.md'

assert_grep 'SENTINEL-EXISTING-INSTRUCTIONS' "$dB/CLAUDE.md"
assert_eq 1 "$(grep -c "$START_MARKER" "$dB/CLAUDE.md" 2>/dev/null)" 'Case B: exactly one start marker appended to CLAUDE.md'
assert_eq 1 "$(grep -c "$END_MARKER" "$dB/CLAUDE.md" 2>/dev/null)" 'Case B: exactly one end marker appended to CLAUDE.md'

# --- Case C: re-run idempotence (Pitfall 7) ---
cp -R "$dB" "$dB.snap"
statusC=0
python3 "$(init_py)" \
  --target "$dB" \
  --language en \
  --counterpart 'Acme Consulting|ordering party|Jane Doe' \
  >"$dB.stdout2" 2>"$dB.stderr2" || statusC=$?
assert_eq 0 "$statusC" 'Case C: second identical run exits 0'
assert_eq 1 "$(grep -c "$START_MARKER" "$dB/AGENTS.md" 2>/dev/null)" 'Case C: still exactly one start marker in AGENTS.md'
assert_eq 1 "$(grep -c "$END_MARKER" "$dB/AGENTS.md" 2>/dev/null)" 'Case C: still exactly one end marker in AGENTS.md'
assert_eq 1 "$(grep -c "$START_MARKER" "$dB/CLAUDE.md" 2>/dev/null)" 'Case C: still exactly one start marker in CLAUDE.md'
assert_eq 1 "$(grep -c "$END_MARKER" "$dB/CLAUDE.md" 2>/dev/null)" 'Case C: still exactly one end marker in CLAUDE.md'
assert_eq '' "$(diff -r "$dB.snap" "$dB" 2>&1)" 'Case C: second run changes nothing on disk'

# --- Case D: in-place update of a hand-edited body ---
# Replace the line inside AGENTS.md's markers with a stale sentinel, then
# run init a third time. This is the case that distinguishes
# replace-the-span from skip-because-the-file-exists.
python3 -c "
import re

path = '$dB/AGENTS.md'
with open(path, encoding='utf-8') as handle:
    text = handle.read()
text = re.sub(
    r'(?s)(<!-- client-dossier:start -->\n).*(\n<!-- client-dossier:end -->)',
    lambda m: m.group(1) + 'SENTINEL-STALE-BODY' + m.group(2),
    text,
    count=1,
)
with open(path, 'w', encoding='utf-8') as handle:
    handle.write(text)
"
assert_grep 'SENTINEL-STALE-BODY' "$dB/AGENTS.md"

statusD=0
python3 "$(init_py)" \
  --target "$dB" \
  --language en \
  --counterpart 'Acme Consulting|ordering party|Jane Doe' \
  >"$dB.stdout3" 2>"$dB.stderr3" || statusD=$?
assert_eq 0 "$statusD" 'Case D: third run (after a hand-edited body) exits 0'
assert_eq 1 "$(grep -c "$START_MARKER" "$dB/AGENTS.md" 2>/dev/null)" 'Case D: still exactly one start marker in AGENTS.md'
assert_eq 1 "$(grep -c "$END_MARKER" "$dB/AGENTS.md" 2>/dev/null)" 'Case D: still exactly one end marker in AGENTS.md'
assert_not_grep 'SENTINEL-STALE-BODY' "$dB/AGENTS.md"
assert_grep 'SENTINEL-EXISTING-INSTRUCTIONS' "$dB/CLAUDE.md"

rm -rf "$dB" "$dB.snap" "$dB.stdout1" "$dB.stderr1" "$dB.stdout2" "$dB.stderr2" "$dB.stdout3" "$dB.stderr3"

# --- Case E: language (SCAF-07) — a French dossier gets a French pointer;
# the folder paths and protocol keywords stay English.
dE=$(scratch_repo)
statusE=0
python3 "$(init_py)" \
  --target "$dE" \
  --language fr \
  --counterpart 'Acme Consulting|ordering party|Jane Doe' \
  >"$dE.stdout" 2>"$dE.stderr" || statusE=$?
assert_eq 0 "$statusE" 'Case E: init exits 0 with --language fr'
assert_file "$dE/AGENTS.md"
assert_grep 'dossier client' "$dE/AGENTS.md"
assert_grep 'dossier/' "$dE/AGENTS.md"
assert_grep 'outbound/' "$dE/AGENTS.md"

# Case F (French variant): the same out-of-scope check as Case A, in the
# other language.
assert_eq 0 "$(grep -ci 'stop hook' "$dE/AGENTS.md" 2>/dev/null)" 'Case F (fr): AGENTS.md does not mention a Stop hook'
assert_eq 0 "$(grep -c 'lint.py' "$dE/AGENTS.md" 2>/dev/null)" 'Case F (fr): AGENTS.md does not mention lint.py'

rm -rf "$dE" "$dE.stdout" "$dE.stderr"

finish
