#!/usr/bin/env bash
# tests/run.sh — dispatcher. Runs every tests/test-*.sh file with bash and
# reports a summary. Adding a test file never requires editing this script.
set -u

DIR="$(dirname "$0")"

files=0
failed=0

for f in "$DIR"/test-*.sh; do
  # Glob did not match anything: skip the literal pattern string.
  [ -e "$f" ] || continue
  files=$((files + 1))
  if bash "$f" >/tmp/gsd-test-output.$$ 2>&1; then
    echo "ok $f"
  else
    echo "FAIL $f"
    sed 's/^/    /' /tmp/gsd-test-output.$$
    failed=$((failed + 1))
  fi
  rm -f /tmp/gsd-test-output.$$
done

echo "TOTAL: $files files, $failed failed"

if [ "$files" -eq 0 ] || [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
