#!/usr/bin/env bash
# tests/test-init-adopt.sh — SCAF-06 / D-14/D-15/D-17: `--propose-renames`
# detects an existing repository's folders and files that already play a
# dossier role under other names, and prints an ordered, confirmable
# `git mv` proposal to the fixed English names — writing nothing.
#
# Fails now: `--propose-renames` does not exist yet (RED gate for Task 2).
set -u

# shellcheck source=./lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

FIXTURE_SCRIPT="$(dirname "${BASH_SOURCE[0]}")/fixtures/make-adopt-fixture.sh"
GOLDEN="$REPO_ROOT/tests/golden/adopt-proposal.txt"

# --- Case A: the origin-shaped repository ---
fx="$(bash "$FIXTURE_SCRIPT")"
cp -R "$fx" "$fx.snap"

statusA=0
python3 "$(init_py)" --target "$fx" --propose-renames >"$fx.out" 2>"$fx.err" || statusA=$?
assert_eq 0 "$statusA" 'Case A: --propose-renames exits 0 on the origin-shaped fixture'
assert_eq '' "$(diff "$fx.out" "$GOLDEN" 2>&1)" 'Case A: the proposal matches the golden byte for byte'
assert_eq '' "$(diff -r "$fx.snap" "$fx" 2>&1)" 'Case A: --propose-renames wrote nothing to the fixture'

if [ -e "$fx/dossier.yaml" ]; then
  echo "FAIL: expected --propose-renames NOT to write dossier.yaml" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
else
  TESTS_PASSED=$((TESTS_PASSED + 1))
fi

rm -rf "$fx" "$fx.snap" "$fx.out" "$fx.err"

# --- Case B: a content hint with no name-table match ---
dB="$(scratch_repo)"
mkdir -p "$dB/archives-client"
printf 'placeholder\n' >"$dB/archives-client/TON.md"
printf 'placeholder\n' >"$dB/archives-client/HISTORIQUE.md"
git -C "$dB" add -A
git -C "$dB" commit -q -m "fixture: content-hint-only folder"

statusB=0
python3 "$(init_py)" --target "$dB" --propose-renames >"$dB.out" 2>"$dB.err" || statusB=$?
assert_eq 0 "$statusB" 'Case B: --propose-renames exits 0'
assert_grep_e '^candidate: archives-client -> dossier' "$dB.out"

rm -rf "$dB" "$dB.out" "$dB.err"

# --- Case C: a symlink escaping the repository ---
dC="$(scratch_repo)"
outside="$(mktemp -d)"
ln -s "$outside" "$dC/client"

statusC=0
python3 "$(init_py)" --target "$dC" --propose-renames >"$dC.out" 2>"$dC.err" || statusC=$?
assert_eq 0 "$statusC" 'Case C: --propose-renames exits 0 with a symlink escaping the repo'
assert_grep_e '^unsafe: client' "$dC.out"

if grep -q '^rename: client' "$dC.out" 2>/dev/null; then
  echo "FAIL: expected no 'rename: client' line for a symlink escaping the repo" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
else
  TESTS_PASSED=$((TESTS_PASSED + 1))
fi

rm -rf "$dC" "$outside" "$dC.out" "$dC.err"

# --- Case D: an already-adopted repository ---
dD="$(scratch_repo)"
statusD1=0
python3 "$(init_py)" \
  --target "$dD" \
  --language en \
  --counterpart 'Acme Consulting|ordering party|Jane Doe' \
  >"$dD.init-out" 2>"$dD.init-err" || statusD1=$?
assert_eq 0 "$statusD1" 'Case D: normal init exits 0'

statusD2=0
outD=$(python3 "$(init_py)" --target "$dD" --propose-renames 2>"$dD.err") || statusD2=$?
assert_eq 0 "$statusD2" 'Case D: --propose-renames exits 0 on an already-adopted repo'
assert_eq 'propose-renames: 0 proposed, 0 untracked, 0 unsafe, 0 ignored' "$outD" \
  'Case D: a correctly named dossier has nothing to rename or ignore'

rm -rf "$dD" "$dD.init-out" "$dD.init-err" "$dD.err"

finish
