#!/usr/bin/env bash
# tests/test-init-fr.sh — the French template variant's acceptance test
# (SCAF-07, ROADMAP criterion 5): `--language fr` must produce French
# titles, headings, comments and example lines throughout `dossier/` and
# `knowledge/`, while every path and every protocol keyword — the
# `Last updated:` label and the outbound status-header field names/values —
# stay byte-identical to the English variant. This is the RED gate for
# Tasks 2 and 3: it fails now because `templates/fr/` does not exist yet and
# `resolve_template_dir` falls back to `templates/en/`.
set -u

# shellcheck source=./lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

d=$(scratch_repo)

status=0
python3 "$(init_py)" \
  --target "$d" \
  --language fr \
  --counterpart 'Acme Consulting|donneur d'\''ordre|Jane Doe' \
  --confidential-name Acme \
  >"$d.stdout" 2>"$d.stderr" || status=$?
assert_eq 0 "$status" 'init exits 0 with --language fr'

# The fr variant was actually used, not the en fallback.
assert_grep_e '^templates: fr' "$d.stdout"
assert_grep '^language: fr$' "$d/dossier.yaml"

# Nine anchored French heading assertions, one per file — the exact contract
# Task 2 and Task 3 must satisfy. Anchored at both ends so an English
# fallback heading, or a differently-worded French heading, cannot pass by
# accident.
assert_grep_e '^## Chronologie$' "$d/dossier/HISTORY.md"
assert_grep_e '^## Refusé$' "$d/dossier/TONE.md"
assert_grep_e '^## Pièges connus$' "$d/dossier/LEARNINGS.md"
assert_grep_e '^## Ce dépôt$' "$d/dossier/CHANNELS.md"
assert_grep_e '^## Points à garder en tête$' "$d/dossier/RELATIONSHIP.md"
assert_grep_e "^## Côté donneur d'ordre\$" "$d/dossier/ACTORS.md"
assert_grep_e '^## Ce qu'\''on poserait au client final$' "$d/dossier/OPEN-QUESTIONS.md"
assert_grep_e "^## Ce qu'on ne dit pas\$" "$d/knowledge/DOCTRINE.md"
assert_grep_e "^## L'objet\$" "$d/knowledge/CONTEXT.md"

# The half of criterion 5 that actually breaks a French dossier: the
# `Last updated:` label survives on all seven living files, dated with a
# real ISO date (not the template's YYYY-MM-DD token).
for f in ACTORS HISTORY LEARNINGS TONE CHANNELS OPEN-QUESTIONS RELATIONSHIP; do
  assert_grep_e '^Last updated: [0-9]{4}-[0-9]{2}-[0-9]{2}$' "$d/dossier/$f.md"
done

# outbound/README.md restates the status header verbatim: the six field
# names, anchored, plus the three status values.
assert_grep '^Status:' "$d/outbound/README.md"
assert_grep '^To:' "$d/outbound/README.md"
assert_grep '^Subject:' "$d/outbound/README.md"
assert_grep '^Deadline:' "$d/outbound/README.md"
assert_grep '^Written by:' "$d/outbound/README.md"
assert_grep '^Rules:' "$d/outbound/README.md"
assert_grep 'draft' "$d/outbound/README.md"
assert_grep 'reviewed by' "$d/outbound/README.md"
assert_grep 'sent' "$d/outbound/README.md"

# A French dossier still has English paths and English filenames
# (CLAUDE.md C-3).
assert_dir "$d/dossier"
assert_dir "$d/sources"
assert_dir "$d/knowledge"
assert_dir "$d/outbound"
assert_dir "$d/outbound/calls"
assert_dir "$d/outbound/deliverables"
assert_dir "$d/outbound/mails"
assert_file "$d/dossier/ACTORS.md"
assert_file "$d/dossier/OPEN-QUESTIONS.md"

# No counterpart name, not even the fictional one, leaked into outbound/.
# Case-insensitive: lib.sh's assert_not_grep has no -i flag (the same
# constraint tests/test-init-empty.sh already documents), so this is
# inlined rather than adding one to lib.sh just for this test.
if grep -qi -- 'acme' "$d/outbound/README.md" 2>/dev/null; then
  echo "FAIL: expected '$d/outbound/README.md' NOT to match /acme/i" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
else
  TESTS_PASSED=$((TESTS_PASSED + 1))
fi

# The two protocol field names that must never be translated. Anchored at
# line start, which is what keeps these safe: French prose elsewhere in the
# file that happens to contain those words does not begin a line with them.
assert_eq 0 "$(grep -c '^Statut:' "$d/outbound/README.md")" 'status field name not translated'
assert_eq 0 "$(grep -c '^Échéance:' "$d/outbound/README.md")" 'deadline field name not translated'

rm -rf "$d" "$d.stdout" "$d.stderr"

finish
