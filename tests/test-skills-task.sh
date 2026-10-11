#!/usr/bin/env bash
# tests/test-skills-task.sh — PROTO-02 and PROTO-08 completed over every skill
# (D-09, D-15; plan 06-04). Now that all six skills exist:
#   - PROTO-02: `## Other skills` of skills/dossier/SKILL.md names exactly dossier-init,
#     dossier-ingest, dossier-draft, dossier-call and dossier-status;
#   - PROTO-08: every task skill (all but dossier and dossier-init) stops outside a dossier,
#     looks for the nearest dossier.yaml and quotes its command values; status.py exits 2
#     outside a dossier.
# A negative control proves the stop-sentence loop is not vacuous.
# No model, no network. bash 3.2, no arrays.
set -u

# shellcheck source=./lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

DOSSIER_MD="$REPO_ROOT/skills/dossier/SKILL.md"
STATUS_PY="$REPO_ROOT/skills/dossier-status/scripts/status.py"

# has_flat_in FILE NEEDLE LABEL — the needle once FILE's line breaks are folded.
has_flat_in() {
  if tr '\n' ' ' <"$1" 2>/dev/null | tr -s ' ' | grep -qF -- "$2"; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "FAIL: $3: $(basename "$(dirname "$1")") lacks (line breaks folded): $2" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}
# stop_sentence_in FILE — 0 when FILE holds the three pinned task-skill sentences.
stop_sentence_in() {
  local f="$1" flat
  flat="$(tr '\n' ' ' <"$f" 2>/dev/null | tr -s ' ')"
  case "$flat" in *'If there is none, say so and stop: this is a task skill, it does nothing outside a dossier.'*) ;; *) return 1 ;; esac
  case "$flat" in *'the nearest one wins'*) ;; *) return 1 ;; esac
  case "$flat" in *'Suggest `dossier-init` if the user wants to start one.'*) ;; *) return 1 ;; esac
  return 0
}

# --- PROTO-02: the pointers, exactly five names ---
assert_file "$DOSSIER_MD"
OTHER="$(awk '$0 == "## Other skills" { on = 1; next } on { print }' "$DOSSIER_MD" 2>/dev/null)"
NAMES="$(printf '%s\n' "$OTHER" | grep -oE 'dossier-[a-z]+' | sort -u | tr '\n' ' ')"
assert_eq 'dossier-call dossier-draft dossier-ingest dossier-init dossier-status ' "$NAMES" 'PROTO-02: "Other skills" names exactly the five other skills'
for n in dossier-init dossier-ingest dossier-draft dossier-call dossier-status; do
  if printf '%s\n' "$OTHER" | grep -qE "(^|[.;] +|^)\`$n\`"; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "FAIL: PROTO-02: \`$n\` does not start a line or a sentence under '## Other skills'" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
  assert_file "$REPO_ROOT/skills/$n/SKILL.md"
done
assert_eq 6 "$(ls "$REPO_ROOT"/skills/*/SKILL.md 2>/dev/null | wc -l | tr -d ' ')" 'PROTO-02: six skills/*/SKILL.md'
assert_eq 1 "$(printf '%s\n' "$OTHER" | grep -cE '^`dossier-call` prepares' | tr -d ' ')" 'PROTO-02: the dossier-call sentence is there once'

# --- PROTO-08: every task skill ---
VISITED=0
for f in "$REPO_ROOT"/skills/*/SKILL.md; do
  name="$(basename "$(dirname "$f")")"
  [ "$name" = "dossier" ] && continue
  [ "$name" = "dossier-init" ] && continue
  VISITED=$((VISITED + 1))
  if stop_sentence_in "$f"; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "FAIL: PROTO-08: $name lacks the stop sentence, the nearest-dossier rule or the dossier-init suggestion" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
  has_flat_in "$f" 'If there is none, say so and stop: this is a task skill, it does nothing outside a dossier.' 'PROTO-08 stop'
  has_flat_in "$f" 'the nearest one wins' 'PROTO-08 nearest dossier'
  has_flat_in "$f" 'Suggest `dossier-init` if the user wants to start one.' 'PROTO-08 suggestion'
  if tr '\n' ' ' <"$f" | tr -s ' ' | grep -qiE 'goes? between single quotes'; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "FAIL: PROTO-08: $name lacks its single-quote rule" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
done
assert_eq 4 "$VISITED" 'PROTO-08: the loop visits exactly four task skills today'

# --- PROTO-08: status.py outside a dossier exits 2, says so on stderr, prints nothing ---
WORK="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/empty/sub"
for args in "" "--json"; do
  OUT="$(cd "$WORK/empty/sub" && python3 "$STATUS_PY" $args 2>"$WORK/err")"
  RC=$?
  assert_eq 2 "$RC" "PROTO-08: status.py $args outside a dossier exits 2"
  assert_eq '' "$OUT" "PROTO-08: status.py $args outside a dossier prints nothing on stdout"
  if grep -qF 'no dossier.yaml found' "$WORK/err"; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "FAIL: PROTO-08: status.py $args stderr lacks 'no dossier.yaml found': $(cat "$WORK/err")" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
done

# --- Negative control: the stop-sentence check fails on a copy with the sentence removed ---
mkdir -p "$WORK/ctl/dossier-draft"
sed 's/If there is none, say so and stop: this is a task skill, it does nothing outside a dossier\.//' \
  "$REPO_ROOT/skills/dossier-draft/SKILL.md" >"$WORK/ctl/dossier-draft/SKILL.md"
if stop_sentence_in "$WORK/ctl/dossier-draft/SKILL.md"; then
  echo "FAIL: control: the stop-sentence check passed on a copy without the sentence (the loop is vacuous)" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
else
  TESTS_PASSED=$((TESTS_PASSED + 1))
fi
if stop_sentence_in "$REPO_ROOT/skills/dossier-draft/SKILL.md"; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "FAIL: control: the stop-sentence check fails on the real dossier-draft skill" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi
# The same check on a copy that lost the nearest-dossier rule.
sed 's/the nearest one wins/the first one wins/' "$REPO_ROOT/skills/dossier-draft/SKILL.md" >"$WORK/ctl/dossier-draft/SKILL.md"
if stop_sentence_in "$WORK/ctl/dossier-draft/SKILL.md"; then
  echo "FAIL: control: the check passed on a copy without the nearest-dossier rule" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
else
  TESTS_PASSED=$((TESTS_PASSED + 1))
fi

finish
