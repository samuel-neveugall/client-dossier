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
# Dependency-free check (CLAUDE.md forbids a PyYAML dependency in tests):
# assert the exact byte-for-byte line yaml_quote() must produce. Before the
# fix, `role` was emitted unquoted (`role: primary contact: EMEA`), a
# different and broken literal -- so this line is red without the fix and
# green with it.
assert_grep '    role: "primary contact: EMEA"' "$d7/dossier.yaml"
rm -rf "$d7" "$d7.stdout" "$d7.stderr"

# Regression: a field combining a colon-space, a double quote, and a
# backslash must survive yaml_quote()'s strip -> backslash-escape ->
# quote-escape order without the backslash it inserts being re-escaped by
# the following quote pass. The role below is deliberately *not* just
# quote+backslash (the tour-1 version of this test): a plain YAML scalar
# containing only `"` and `\` happens to re-parse to the same string
# whether or not it was quoted, so that version stayed green even with the
# quoting fix reverted -- it asserted re-parsed equality, not that quoting
# had actually run. Adding a colon-space makes the unquoted form genuinely
# different (and broken -- a second unquoted ':' inside the value), so this
# byte-exact literal is red without the fix and green with it.
d8=$(scratch_repo)
status9=0
python3 "$(init_py)" \
  --target "$d8" \
  --language en \
  --counterpart 'Jane "The Fixer" Doe|VP: "Ops" \ Sales|jane@acme.test' \
  >"$d8.stdout" 2>"$d8.stderr" || status9=$?
assert_eq 0 "$status9" 'init exits 0 with a colon+quote+backslash in --counterpart fields'
# grep -F (fixed string), not assert_grep's BRE: the expected bytes contain
# literal backslashes, whose meaning in a basic regular expression is
# unreliable across grep implementations. Fixed-string matching is the only
# byte-exact, dependency-free option here.
if grep -qF -- '  - name: "Jane \"The Fixer\" Doe"' "$d8/dossier.yaml" \
  && grep -qF -- '    role: "VP: \"Ops\" \\ Sales"' "$d8/dossier.yaml"; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "FAIL: expected '$d8/dossier.yaml' to quote+escape name/role containing a colon, quote and backslash" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi
rm -rf "$d8" "$d8.stdout" "$d8.stderr"

# Regression (correctif 4, tour 2): yaml_quote() strips control characters
# below 0x20, including newline, before quoting -- untested until now (a
# mutation deleting that filter survived every prior test in this suite). A
# newline embedded in a counterpart name must not survive into the file: it
# must not split the quoted scalar across lines, and it must not let text
# after the newline be read as a new top-level YAML key.
d9=$(scratch_repo)
status10=0
python3 "$(init_py)" \
  --target "$d9" \
  --language en \
  --counterpart "$(printf 'Jane\ninjected: pwned')|contact" \
  >"$d9.stdout" 2>"$d9.stderr" || status10=$?
assert_eq 0 "$status10" 'init exits 0 with a newline in --counterpart name'
# The newline becomes a space, never deleted (CR-02 of phase 02): deleting it
# would fuse two words of a name.
assert_grep '  - name: "Jane injected: pwned"' "$d9/dossier.yaml"
assert_not_grep '^injected:' "$d9/dossier.yaml"
rm -rf "$d9" "$d9.stdout" "$d9.stderr"

# Regression (correctif 1, tour 2 -- the CAUSE): `language` and
# `status_header` are CLI-fed free text that bypassed yaml_quote() entirely
# (T-01-01). `language` had no argparse `choices=` (it cannot: language
# codes are open-ended), so emit_scalar()'s allowlist is the only guard --
# assert it actually quotes a colon and strips an embedded newline instead
# of injecting a key.
d10=$(scratch_repo)
status11=0
python3 "$(init_py)" \
  --target "$d10" \
  --language 'en: draft' \
  >"$d10.stdout" 2>"$d10.stderr" || status11=$?
assert_eq 0 "$status11" 'init exits 0 with a colon in --language'
assert_grep '^language: "en: draft"$' "$d10/dossier.yaml"
rm -rf "$d10" "$d10.stdout" "$d10.stderr"

d11=$(scratch_repo)
status12=0
python3 "$(init_py)" \
  --target "$d11" \
  --language "$(printf 'en\ninjected: pwned')" \
  >"$d11.stdout" 2>"$d11.stderr" || status12=$?
assert_eq 0 "$status12" 'init exits 0 with a newline in --language'
assert_grep '^language: "en injected: pwned"$' "$d11/dossier.yaml"
assert_not_grep '^injected:' "$d11/dossier.yaml"
rm -rf "$d11" "$d11.stdout" "$d11.stderr"

# `status_header` has a small, fixed, spec-documented value set (spec
# Sec3.2: only "required" is ever shown), so it additionally gets an
# argparse `choices=` allowlist -- structurally impossible to feed it
# anything else, colon-injection or key-forging payload included.
d12=$(scratch_repo)
status13=0
python3 "$(init_py)" \
  --target "$d12" \
  --status-header 'yes: no' \
  >"$d12.stdout" 2>"$d12.stderr" || status13=$?
assert_eq 2 "$status13" 'init rejects an unknown --status-header value'
if [ -e "$d12/dossier.yaml" ]; then
  echo "FAIL: expected no dossier.yaml written when --status-header is rejected" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
else
  TESTS_PASSED=$((TESTS_PASSED + 1))
fi
rm -rf "$d12" "$d12.stdout" "$d12.stderr"

d13=$(scratch_repo)
status14=0
python3 "$(init_py)" \
  --target "$d13" \
  --status-header "$(printf 'required\nconsent_recorded: true')" \
  >"$d13.stdout" 2>"$d13.stderr" || status14=$?
assert_eq 2 "$status14" 'init rejects a --status-header value forging a second consent_recorded key'
rm -rf "$d13" "$d13.stdout" "$d13.stderr"

# Regression (Phase 1 debt (a), D-24.3): `no` is the ISO 639-1 code for
# Norwegian and also a YAML 1.1 reserved spelling -- emitted bare, a strict
# parser reads `language: no` back as boolean false. Red without the fix:
# the allowlist alone let every reserved spelling through unquoted, so the
# file carried `language: no`.
d14=$(scratch_repo)
status15=0
python3 "$(init_py)" \
  --target "$d14" \
  --language no \
  >"$d14.stdout" 2>"$d14.stderr" || status15=$?
assert_eq 0 "$status15" 'init exits 0 with --language no'
assert_grep '^language: "no"$' "$d14/dossier.yaml"
assert_not_grep '^language: no$' "$d14/dossier.yaml"
rm -rf "$d14" "$d14.stdout" "$d14.stderr"

# Regression (Phase 1 debt (b), D-24.3): the allowlist was anchored only at
# the start (`re.match` with `$`, and `$` also matches just before a final
# newline), so `en` followed by a newline passed it and was written bare,
# leaving a blank line between `language:` and `counterparts:`. Red without
# the fix: the line after `language: en` was empty. Command substitution
# strips trailing newlines, so the payload carries a sentinel `x` that is
# removed afterwards -- otherwise the case would silently test plain `en`.
d15=$(scratch_repo)
status16=0
lang15="$(printf 'en\nx')"
lang15="${lang15%x}"
python3 "$(init_py)" \
  --target "$d15" \
  --language "$lang15" \
  >"$d15.stdout" 2>"$d15.stderr" || status16=$?
assert_eq 0 "$status16" 'init exits 0 with a trailing newline in --language'
assert_grep '^language: "en"$' "$d15/dossier.yaml"
assert_eq "$(printf 'language: "en"\ncounterparts:')" \
  "$(grep -A1 -- '^language:' "$d15/dossier.yaml")" \
  'no blank line between language and counterparts after a trailing newline'
rm -rf "$d15" "$d15.stdout" "$d15.stderr"

finish
