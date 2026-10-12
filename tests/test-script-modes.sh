#!/usr/bin/env bash
# tests/test-script-modes.sh — every script a SKILL.md runs directly
# ("${CLAUDE_SKILL_DIR}/scripts/X" with no interpreter in front) keeps what a
# direct run needs: a shebang on line 1, the exec bit on disk, and mode 100755
# in the git index, so a clone or archive of the repository keeps it (v1
# milestone audit, W4). Scripts run through `python3 "..."` are not in scope.
# A negative control proves the extraction is not vacuous.
# No model, no network. bash 3.2, no arrays.
set -u

# shellcheck source=./lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# direct_scripts — "skill-folder<TAB>script-name" for each direct run, unique.
direct_scripts() {
  local f skill
  for f in "$REPO_ROOT"/skills/*/SKILL.md; do
    skill="$(basename "$(dirname "$f")")"
    grep -oE '^"\$\{CLAUDE_SKILL_DIR\}/scripts/[A-Za-z0-9_.-]+"' "$f" 2>/dev/null \
      | sed -E 's|^"\$\{CLAUDE_SKILL_DIR\}/scripts/||; s|"$||' \
      | while read -r name; do printf '%s\t%s\n' "$skill" "$name"; done
  done | sort -u
}

LIST="$(direct_scripts)"
COUNT="$(printf '%s\n' "$LIST" | grep -c .)"

# Negative control: init.py, file_source.py, extract-text.sh and status.py at least.
if [ "$COUNT" -ge 4 ]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "FAIL: expected at least 4 directly run skill scripts, found $COUNT" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

IN_GIT=0
if git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  IN_GIT=1
fi

while IFS="$(printf '\t')" read -r skill name; do
  [ -n "$skill" ] || continue
  path="$REPO_ROOT/skills/$skill/scripts/$name"
  assert_file "$path"
  assert_exec "$path"
  if head -n 1 "$path" 2>/dev/null | grep -q '^#!'; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "FAIL: $skill/scripts/$name has no shebang on line 1" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
  if [ "$IN_GIT" -eq 1 ]; then
    mode="$(git -C "$REPO_ROOT" ls-files -s -- "skills/$skill/scripts/$name" | cut -d' ' -f1)"
    assert_eq 100755 "$mode" "git index mode of skills/$skill/scripts/$name"
  else
    skip "not a git work tree: index mode of skills/$skill/scripts/$name"
  fi
done <<EOF
$LIST
EOF

finish
