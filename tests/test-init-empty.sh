#!/usr/bin/env bash
# tests/test-init-empty.sh — the tracer's acceptance test: scaffolding an
# empty git repository with `init.py --language en`. This is the
# specification of Task 2's output (SCAF-01, SCAF-02, SCAF-03 for one file,
# D-08 idempotence).
set -u

# shellcheck source=./lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

d=$(scratch_repo)

status=0
python3 "$(init_py)" \
  --target "$d" \
  --language en \
  --counterpart 'Acme Consulting|ordering party|Jane Doe' \
  --counterpart 'Big Telco|end client' \
  --confidential-name Acme \
  --confidential-name 'Big Telco' \
  >"$d.stdout1" 2>"$d.stderr1" || status=$?
assert_eq 0 "$status" 'init exits 0 on an empty repo'

# dossier.yaml — the ten spec §3.2 keys, in spec order.
assert_file "$d/dossier.yaml"
assert_grep '^version:' "$d/dossier.yaml"
assert_grep '^language:' "$d/dossier.yaml"
assert_grep '^counterparts:' "$d/dossier.yaml"
assert_grep '^confidential_names:' "$d/dossier.yaml"
assert_grep '^consent_recorded:' "$d/dossier.yaml"
assert_grep '^consent_source:' "$d/dossier.yaml"
assert_grep '^timestamps:' "$d/dossier.yaml"
assert_grep '^date_format:' "$d/dossier.yaml"
assert_grep '^status_header:' "$d/dossier.yaml"
assert_grep '^staleness_days:' "$d/dossier.yaml"
assert_grep '^language: en$' "$d/dossier.yaml"
assert_grep '^staleness_days: 7$' "$d/dossier.yaml"

# The twelve directories.
assert_dir "$d/sources"
assert_dir "$d/sources/received"
assert_dir "$d/sources/transcripts"
assert_dir "$d/sources/transcripts/raw"
assert_dir "$d/dossier"
assert_dir "$d/knowledge"
assert_dir "$d/knowledge/decisions"
assert_dir "$d/knowledge/watch"
assert_dir "$d/outbound"
assert_dir "$d/outbound/deliverables"
assert_dir "$d/outbound/mails"
assert_dir "$d/outbound/calls"

# The seven .gitkeep leaves named verbatim in spec §3.2.
assert_file "$d/sources/received/.gitkeep"
assert_file "$d/sources/transcripts/raw/.gitkeep"
assert_file "$d/knowledge/decisions/.gitkeep"
assert_file "$d/knowledge/watch/.gitkeep"
assert_file "$d/outbound/deliverables/.gitkeep"
assert_file "$d/outbound/mails/.gitkeep"
assert_file "$d/outbound/calls/.gitkeep"

# dossier/ACTORS.md rendered from the one bundled English template.
assert_file "$d/dossier/ACTORS.md"
assert_grep_e '^Last updated: [0-9]{4}-[0-9]{2}-[0-9]{2}$' "$d/dossier/ACTORS.md"
assert_grep 'Updated when' "$d/dossier/ACTORS.md"

# Idempotence (D-08, the phase's highest-impact control).
cp -R "$d" "$d.snap"
status2=0
python3 "$(init_py)" \
  --target "$d" \
  --language en \
  --counterpart 'Acme Consulting|ordering party|Jane Doe' \
  --counterpart 'Big Telco|end client' \
  --confidential-name Acme \
  --confidential-name 'Big Telco' \
  >"$d.stdout2" 2>"$d.stderr2" || status2=$?
assert_eq 0 "$status2" 'second run exits 0'
assert_grep '^kept: ' "$d.stdout2"
assert_eq '' "$(diff -r "$d.snap" "$d" 2>&1)" 'second run changes nothing on disk'

rm -rf "$d" "$d.snap" "$d.stdout1" "$d.stderr1" "$d.stdout2" "$d.stderr2"

# --- Plan 01-02: the full scaffold surface ---
# The tests below fail until the eleven remaining templates exist and every
# template is wired into TEMPLATE_MAP (Tasks 2 and 3). This is the RED gate
# for those tasks.

d4=$(scratch_repo)
status5=0
python3 "$(init_py)" \
  --target "$d4" \
  --language en \
  --counterpart 'Acme Consulting|ordering party|Jane Doe' \
  --counterpart 'Big Telco|end client' \
  --confidential-name Acme \
  --confidential-name 'Big Telco' \
  >"$d4.stdout" 2>"$d4.stderr" || status5=$?
assert_eq 0 "$status5" 'full-surface init exits 0 on an empty repo'

# Seven living files: each has a dated `Last updated:` line (a real ISO
# date, not the template token) and its own "Updated when" comment.
for f in ACTORS HISTORY LEARNINGS TONE CHANNELS OPEN-QUESTIONS RELATIONSHIP; do
  assert_file "$d4/dossier/$f.md"
  assert_grep_e '^Last updated: [0-9]{4}-[0-9]{2}-[0-9]{2}$' "$d4/dossier/$f.md"
  assert_grep 'Updated when' "$d4/dossier/$f.md"
done

# Five more targets: the two knowledge stubs and the three folder READMEs.
assert_file "$d4/knowledge/CONTEXT.md"
assert_file "$d4/knowledge/DOCTRINE.md"
assert_file "$d4/dossier/README.md"
assert_file "$d4/sources/README.md"
assert_file "$d4/outbound/README.md"

# knowledge/DOCTRINE.md carries its two lists and the vocabulary section.
assert_grep '^## What we say$' "$d4/knowledge/DOCTRINE.md"
assert_grep '^## What we never say$' "$d4/knowledge/DOCTRINE.md"
assert_grep '^## Vocabulary, one sentence each$' "$d4/knowledge/DOCTRINE.md"

# outbound/README.md restates the status header field by field, plus the
# naming rule and the three subfolders.
assert_grep '^Status:' "$d4/outbound/README.md"
assert_grep '^To:' "$d4/outbound/README.md"
assert_grep '^Subject:' "$d4/outbound/README.md"
assert_grep '^Deadline:' "$d4/outbound/README.md"
assert_grep '^Written by:' "$d4/outbound/README.md"
assert_grep '^Rules:' "$d4/outbound/README.md"
assert_grep 'YYYY-MM-DD_slug' "$d4/outbound/README.md"
assert_grep 'deliverables' "$d4/outbound/README.md"
assert_grep 'mails' "$d4/outbound/README.md"
assert_grep 'calls' "$d4/outbound/README.md"

# Confidentiality: no counterpart name, not even the spec's fictional one,
# reaches a file under outbound/, sources/ or dossier/ (spec §3.2; this is
# the scaffold-time face of Phase 2's LINT-01 check 3). Case-insensitive;
# assert_not_grep has no -i flag, so this is inlined rather than adding one
# to lib.sh (out of this task's declared file scope).
for target in "$d4/outbound/README.md" "$d4/sources/README.md" "$d4/dossier/README.md"; do
  if grep -qi -- 'acme' "$target" 2>/dev/null; then
    echo "FAIL: expected '$target' NOT to match /acme/i" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  else
    TESTS_PASSED=$((TESTS_PASSED + 1))
  fi
done

# The three READMEs carry no living-file update line. Anchored, so prose or
# an HTML comment mentioning the label elsewhere cannot satisfy it by
# accident.
assert_not_grep '^Last updated:' "$d4/outbound/README.md"
assert_not_grep '^Last updated:' "$d4/sources/README.md"
assert_not_grep '^Last updated:' "$d4/dossier/README.md"

rm -rf "$d4" "$d4.stdout" "$d4.stderr"

# Variant fallback (SCAF-07 / D-09): a language with no hand-maintained
# variant scaffolds from templates/en/ and the report says so — the
# mechanical handoff to the skill's translation step.
d5=$(scratch_repo)
status6=0
python3 "$(init_py)" \
  --target "$d5" \
  --language es \
  --counterpart 'Acme Consulting|ordering party|Jane Doe' \
  >"$d5.stdout" 2>"$d5.stderr" || status6=$?
assert_eq 0 "$status6" 'init exits 0 with an unlisted --language'
assert_grep_e '^templates: en' "$d5.stdout"
assert_grep '^language: es$' "$d5/dossier.yaml"
rm -rf "$d5" "$d5.stdout" "$d5.stderr"

# Variant hit: an explicit --template-variant matching --language uses that
# variant and reports it the same way.
d6=$(scratch_repo)
status7=0
python3 "$(init_py)" \
  --target "$d6" \
  --language en \
  --template-variant en \
  --counterpart 'Acme Consulting|ordering party|Jane Doe' \
  >"$d6.stdout" 2>"$d6.stderr" || status7=$?
assert_eq 0 "$status7" 'init exits 0 with a matching --template-variant'
assert_grep_e '^templates: en' "$d6.stdout"
rm -rf "$d6" "$d6.stdout" "$d6.stderr"

# Regression: a counterpart role containing a colon (a plain, common value —
# e.g. French "Responsable : achats") must not corrupt dossier.yaml. Before
# the fix, `role` was emitted unquoted while every other field went through
# yaml_quote(), so a colon inside it broke the YAML mapping.
d7=$(scratch_repo)
status8=0
python3 "$(init_py)" \
  --target "$d7" \
  --language en \
  --counterpart 'Jane Doe|primary contact: EMEA|jane@acme.test' \
  >"$d7.stdout" 2>"$d7.stderr" || status8=$?
assert_eq 0 "$status8" 'init exits 0 with a colon in --counterpart role'
if python3 -c "
import sys, yaml
with open(sys.argv[1]) as f:
    data = yaml.safe_load(f)
assert data['counterparts'][0]['role'] == 'primary contact: EMEA', data
" "$d7/dossier.yaml" 2>"$d7.yamlerr"; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "FAIL: expected '$d7/dossier.yaml' to be re-parsable with role containing ':'" >&2
  cat "$d7.yamlerr" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi
rm -rf "$d7" "$d7.stdout" "$d7.stderr" "$d7.yamlerr"

# Regression: a field combining a double quote and a backslash must survive
# yaml_quote()'s strip -> backslash-escape -> quote-escape order without the
# backslash it inserts being re-escaped by the following quote pass. The
# verification script is written to a file, not inlined, so bash's own
# quote-escaping cannot interfere with the exact bytes being asserted on.
d8=$(scratch_repo)
status9=0
python3 "$(init_py)" \
  --target "$d8" \
  --language en \
  --counterpart 'Jane "The Fixer" Doe|VP "Ops" \ Sales|jane@acme.test' \
  >"$d8.stdout" 2>"$d8.stderr" || status9=$?
assert_eq 0 "$status9" 'init exits 0 with a quote+backslash in --counterpart fields'

d8_check=$(mktemp)
cat >"$d8_check" <<'PYEOF'
import sys
import yaml

with open(sys.argv[1]) as f:
    data = yaml.safe_load(f)
c = data["counterparts"][0]
assert c["name"] == 'Jane "The Fixer" Doe', c
assert c["role"] == 'VP "Ops" \\ Sales', c
PYEOF
if python3 "$d8_check" "$d8/dossier.yaml" 2>"$d8.yamlerr"; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "FAIL: expected '$d8/dossier.yaml' to be re-parsable with quote+backslash fields" >&2
  cat "$d8.yamlerr" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi
rm -rf "$d8" "$d8.stdout" "$d8.stderr" "$d8.yamlerr" "$d8_check"

finish
