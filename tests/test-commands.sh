#!/usr/bin/env bash
# tests/test-commands.sh — the Claude Code command set, DIST-04 as amended by
# D-18 (07-CONTEXT.md, settled by Samuel on 2026-10-12, amending D-06), plan
# 07-08.
#
# One command ships: commands/dossier-lint.md. The five task skills are
# themselves the slash commands (/client-dossier:dossier-<name>). A plugin
# command named like a plugin skill shadows the skill for the user and for the
# model (07-RESEARCH probes K1-K3), so the collision loop below fails the day
# any commands/*.md stem equals a skills/ folder name. Every check that
# depends on the command set lives in this one file: a later change of the set
# is the EXPECTED_COMMANDS line plus the body and document checks here.
#
# Free: reads tracked files only, writes nothing. Bash 3.2, no arrays.
set -u
# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

EXPECTED_COMMANDS='dossier-lint'

CMD_DIR="$REPO_ROOT/commands"
LINT_CMD="$CMD_DIR/dossier-lint.md"

# has_fixed STRING PATH LABEL — STRING occurs in PATH (grep -F: literal).
has_fixed() {
  if grep -qF -- "$1" "$2" 2>/dev/null; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "FAIL: $3 (missing: $1)" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# --- The command set is exactly the expected one ---
ACTUAL_COMMANDS=""
if [ -d "$CMD_DIR" ]; then
  ACTUAL_COMMANDS="$(find "$CMD_DIR" -maxdepth 1 -type f -name '*.md' -exec basename {} .md \; | sort | tr '\n' ' ' | sed 's/ $//')"
fi
assert_eq "$EXPECTED_COMMANDS" "$ACTUAL_COMMANDS" 'commands/ holds exactly the expected command files (D-18)'

# --- Collision: no command stem equals a skills/ folder name (Pitfall 1, T-07-28) ---
for cmd_file in "$CMD_DIR"/*.md; do
  [ -f "$cmd_file" ] || continue
  stem="$(basename "$cmd_file" .md)"
  if [ -d "$REPO_ROOT/skills/$stem" ]; then
    echo "FAIL: commands/$stem.md shares its name with skills/$stem/ and would shadow the skill (D-18)" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  else
    TESTS_PASSED=$((TESTS_PASSED + 1))
  fi
done

# --- Frontmatter of every command: description + argument-hint only, no tool grant (T-07-27, R4-M4) ---
for cmd_file in "$CMD_DIR"/*.md; do
  [ -f "$cmd_file" ] || continue
  name="commands/$(basename "$cmd_file")"
  first="$(sed -n '1p' "$cmd_file")"
  assert_eq '---' "$first" "$name opens with a frontmatter fence"
  FM="$(awk 'NR==1 && $0=="---" {infm=1; next} infm && $0=="---" {exit} infm {print}' "$cmd_file")"
  KEYS="$(printf '%s\n' "$FM" | sed -n 's/^\([A-Za-z_-][A-Za-z0-9_-]*\):.*/\1/p' | sort | tr '\n' ' ' | sed 's/ $//')"
  assert_eq 'argument-hint description' "$KEYS" "$name frontmatter keys are exactly description and argument-hint"
  DESC="$(printf '%s\n' "$FM" | sed -n 's/^description:[[:space:]]*//p')"
  if [ -n "$DESC" ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "FAIL: $name has an empty description" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
  if grep -qE '^allowed-tools:' "$cmd_file"; then
    echo "FAIL: $name carries allowed-tools in its frontmatter (R4-M4)" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  else
    TESTS_PASSED=$((TESTS_PASSED + 1))
  fi
done

# --- commands/dossier-lint.md body: quoting, refusal, read-only, exit codes ---
assert_file "$LINT_CMD"
has_fixed 'python3 "${CLAUDE_PLUGIN_ROOT}/scripts/lint.py" '"'<path>'" "$LINT_CMD" 'the exact lint line, path single-quoted (A4-F1)'

# Every ${CLAUDE_PLUGIN_ROOT} is preceded by a double quote.
TOTAL_ROOT="$(grep -o '\${CLAUDE_PLUGIN_ROOT}' "$LINT_CMD" 2>/dev/null | wc -l | tr -d ' ')"
QUOTED_ROOT="$(grep -o '"\${CLAUDE_PLUGIN_ROOT}' "$LINT_CMD" 2>/dev/null | wc -l | tr -d ' ')"
if [ "$TOTAL_ROOT" -ge 1 ] && [ "$TOTAL_ROOT" = "$QUOTED_ROOT" ]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "FAIL: every \${CLAUDE_PLUGIN_ROOT} in $LINT_CMD must follow a double quote (found $TOTAL_ROOT, quoted $QUOTED_ROOT)" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

has_fixed 'single quote' "$LINT_CMD" 'the refusal names the single quote'
has_fixed 'line break' "$LINT_CMD" 'the refusal names the line break'
has_fixed '$ARGUMENTS' "$LINT_CMD" 'the body passes the arguments through'
has_fixed 'Fix nothing' "$LINT_CMD" 'the command is read-only'
has_fixed '0 no error (warnings allowed)' "$LINT_CMD" 'exit code 0 meaning'
has_fixed '1 at least one error' "$LINT_CMD" 'exit code 1 meaning'
has_fixed '2 no `dossier.yaml` found upward or unreadable' "$LINT_CMD" 'exit code 2 meaning'
has_fixed '3 internal error' "$LINT_CMD" 'exit code 3 meaning'

finish
