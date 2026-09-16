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

finish
