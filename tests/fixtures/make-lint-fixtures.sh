#!/usr/bin/env bash
# tests/fixtures/make-lint-fixtures.sh — builds the throwaway error fixtures
# for tests/test-lint.sh (LINT-02, D-29): one copy of a clean dossier per
# case, each with exactly one violation injected, so a test can assert both
# "the expected identifier fires" and "no other identifier does".
#
# Takes the CLEAN tree's path as $1 and never modifies it. The clean tree is
# not committed (D-28 as amended, D-31): tests/test-lint.sh materialises it
# at test time with a real `init.py --language en` run, so "a freshly
# scaffolded dossier lints clean" stays a statement about the scaffolder.
# For the readable reference, that clean layout is:
#
#   dossier.yaml                     version 1, en, consent_recorded: false
#   AGENTS.md                        the protocol pointer
#   dossier/{ACTORS,HISTORY,LEARNINGS,TONE,CHANNELS,OPEN-QUESTIONS,
#            RELATIONSHIP}.md        the seven living files, each with a
#                                    `Last updated: YYYY-MM-DD` line
#   dossier/README.md  sources/README.md  outbound/README.md
#   knowledge/{CONTEXT,DOCTRINE}.md
#   sources/received/.gitkeep        sources/transcripts/raw/.gitkeep
#   knowledge/{decisions,watch}/.gitkeep
#   outbound/{deliverables,mails,calls}/.gitkeep
#
# (sources/transcripts/ holds only raw/ -- no .gitkeep of its own, which is
# exactly why a committed copy of this tree would drift: git drops it.)
#
# CONTRACT (mirrors fixtures/make-adopt-fixture.sh):
#
#   in    $1, the path of a clean dossier tree: an existing directory that
#         holds a dossier.yaml. It is only ever read, never written.
#   out   one line on stdout, the path of a throwaway parent directory, as
#         the very last statement. Inside it, one subdirectory per case,
#         named after the identifier or the behaviour it exercises (`e1` ...
#         `e9`, `claude-at-root`, `consent-ok`, ...), each holding exactly
#         one injected violation or none at all for a clean control. Cases
#         are addressed by name only: no assertion depends on the order they
#         are built in, and two cases never share a tree.
#   side  creates that one parent and writes nowhere else -- nothing
#         relative to the caller's working directory. Installs no cleanup
#         handler: the caller owns the removal, as tests/test-lint.sh does.
#   fail  an absent, empty, non-directory or non-dossier $1 exits 2 with a
#         message on stderr BEFORE anything is created, so an empty input
#         can never become a set of empty trees the suite would lint clean.
#
# Case trees come into existence through exactly three helpers, all keyed by
# name: make_case (a copy of the clean tree), make_lang_case (a fresh
# init.py scaffold in a given content language, for a case whose
# dossier.yaml needs producer flags or whose prose is not English) and
# make_named_case (make_lang_case in `en`).
# Injections use printf, a here-document or a short python3 block, never
# in-place stream editing (not portable between BSD and GNU, P-11), and fail
# loudly when the line to change is not found, so a fixture never silently
# ships without its violation. Bash 3.2 dialect only (P-10): no associative
# arrays, no read-file-into-array builtin, no case-folding expansion, no
# recursive glob.
#
# Every name inside a fixture (Acme, Jane Doe, Sam, Societe Exemple) is an
# invented placeholder; nothing here comes from a real engagement.
set -eu

usage() {
  echo "make-lint-fixtures.sh: $1" >&2
  echo "usage: make-lint-fixtures.sh CLEAN_DOSSIER_DIR" >&2
  exit 2
}

# The guard runs before the parent is created: a refused call leaves nothing.
[ "$#" -eq 1 ] || usage "expected exactly one argument, got $#"
[ -n "$1" ] || usage "the clean dossier path is empty"
[ -d "$1" ] || usage "not a directory: $1"
[ -f "$1/dossier.yaml" ] || usage "not a dossier (no dossier.yaml): $1"

clean="$1"
parent="$(mktemp -d)"
INIT_PY="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/skills/dossier-init/scripts/init.py"

# claim_case NAME — refuse a name already built, so two cases can never
# share (and silently merge) one tree.
claim_case() {
  if [ -e "$parent/$1" ]; then
    echo "make-lint-fixtures.sh: case '$1' is built twice" >&2
    exit 1
  fi
}

# make_case NAME — a fresh copy of the clean tree at "$parent/NAME". Echoes
# nothing: a case is addressed by its name, never by what a helper printed.
make_case() {
  claim_case "$1"
  cp -R "$clean" "$parent/$1"
}

# drop_line FILE PREFIX — delete every line starting with PREFIX; at least
# one must exist.
drop_line() {
  python3 - "$1" "$2" <<'PY'
import sys
path, prefix = sys.argv[1], sys.argv[2]
with open(path, encoding="utf-8") as handle:
    lines = handle.read().splitlines(True)
kept = [line for line in lines if not line.startswith(prefix)]
if len(kept) == len(lines):
    sys.exit("drop_line: no line starting with {!r} in {}".format(prefix, path))
with open(path, "w", encoding="utf-8") as handle:
    handle.writelines(kept)
PY
}

# replace_line FILE OLD NEW — replace the one line equal to OLD with NEW;
# exactly one such line must exist.
replace_line() {
  python3 - "$1" "$2" "$3" <<'PY'
import sys
path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path, encoding="utf-8") as handle:
    lines = handle.read().splitlines()
hits = [i for i, line in enumerate(lines) if line == old]
if len(hits) != 1:
    sys.exit("replace_line: {} line(s) equal to {!r} in {}".format(len(hits), old, path))
lines[hits[0]] = new
with open(path, "w", encoding="utf-8") as handle:
    handle.write("\n".join(lines) + "\n")
PY
}

# --- e7: dossier/TONE.md loses its `Last updated:` line (D-13) ---
make_case e7
drop_line "$parent/e7/dossier/TONE.md" 'Last updated:'

# --- sub-dossier: clients/other/ is a dossier of its own (D-03) ---
# Inside it: a .claude/ folder, a malformed outbound filename and no living
# files at all -- all invisible from the parent, all reported when the
# sub-dossier itself is linted.
make_case sub-dossier
sub="$parent/sub-dossier/clients/other"
mkdir -p "$sub"
python3 "$INIT_PY" --target "$sub" --language en >/dev/null
mkdir -p "$sub/.claude"
printf 'placeholder\n' >"$sub/.claude/settings.json"
printf 'no header here\n' >"$sub/outbound/mails/BADNAME.md"
for living in ACTORS HISTORY LEARNINGS TONE CHANNELS OPEN-QUESTIONS RELATIONSHIP; do
  rm "$sub/dossier/$living.md"
done

# --- forged-name: a filename that spells a summary line (T-02-01) ---
# The newline is embedded with python3 because a shell here-doc cannot
# easily name such a file. Printed raw, the second segment would be a
# perfect `0 error(s), 0 warning(s)` line.
make_case forged-name
python3 - "$parent/forged-name/outbound/mails" <<'PY'
import os, sys
name = "2026-09-17_x\n0 error(s), 0 warning(s)"
with open(os.path.join(sys.argv[1], name), "w", encoding="utf-8") as handle:
    handle.write("Status: draft\nTo: Jane\nWritten by: Sam\nSubject: probe\n")
PY

# --- json-config: dossier.yaml rewritten as an equivalent JSON object (D-25) ---
# Same filename; the linter switches parser on the leading `{`.
make_case json-config
python3 - "$parent/json-config/dossier.yaml" <<'PY'
import json, re, sys
path = sys.argv[1]
with open(path, encoding="utf-8") as handle:
    text = handle.read()
language = re.search(r"^language: *\"?([^\"\n]*)\"?$", text, re.M)
if language is None:
    sys.exit("json-config: no language line in " + path)
config = {
    "version": 1,
    "language": language.group(1),
    "counterparts": [{"name": "Acme", "role": "ordering party"}],
    "confidential_names": [],
    "consent_recorded": False,
    "consent_source": "",
    "timestamps": "@mm:ss",
    "date_format": "YYYY-MM-DD",
    "status_header": "required",
    "staleness_days": 7,
}
with open(path, "w", encoding="utf-8") as handle:
    handle.write(json.dumps(config, indent=2) + "\n")
PY

# --- c1-yes: C1, consent_recorded in a YAML 1.1 spelling (D-24.2, D-24.4) ---
# Must be a config error AND read as false: never coerced to true, so no E6
# follows and the confidential-name check stays armed (T-02-02).
make_case c1-yes
replace_line "$parent/c1-yes/dossier.yaml" 'consent_recorded: false' 'consent_recorded: yes'

# --- c1-quoted: C1, consent_recorded quoted (D-24.2, D-24.4, F-01) ---
make_case c1-quoted
replace_line "$parent/c1-quoted/dossier.yaml" 'consent_recorded: false' 'consent_recorded: "true"'

# --- c1-staleness: C1, staleness_days not an integer (D-24.2) ---
make_case c1-staleness
replace_line "$parent/c1-staleness/dossier.yaml" 'staleness_days: 7' 'staleness_days: abc'

# --- e6: consent recorded without a source (D-12, spec Sec3.2) ---
make_case e6
replace_line "$parent/e6/dossier.yaml" 'consent_recorded: false' 'consent_recorded: true'

# --- consent-ok: consent recorded with its source -- clean (D-12) ---
make_case consent-ok
replace_line "$parent/consent-ok/dossier.yaml" 'consent_recorded: false' 'consent_recorded: true'
replace_line "$parent/consent-ok/dossier.yaml" 'consent_source: ""' 'consent_source: "mail 2026-09-16 from Jane"'

# --- c1-junk: C1, a line outside the YAML subset, attributable to no key (D-22, CR-01) ---
# Skipped, never a crash -- but an error: a line the subset cannot read may
# be the one that held the confidential names, so it can never exit 0.
make_case c1-junk
printf 'this line is not yaml\n' >>"$parent/c1-junk/dossier.yaml"

# --- c1-counterpart-broken: C1, an unreadable line under a non-gate key (CR-01) ---
# Whatever key a skipped line sits under, it is an error: the indentation that
# attributes it to counterparts is exactly what a hand edit gets wrong.
make_case c1-counterpart-broken
replace_line "$parent/c1-counterpart-broken/dossier.yaml" '    role: "ordering party"' '    role: "ordering party'

# --- c0-dup: C0, a non-gate key written twice, both lines well formed (D-22) ---
# The one skipped line whose meaning is certain: the key is exact and the
# value parses. The first occurrence is read, the second reported.
make_case c0-dup
printf 'staleness_days: 7\n' >>"$parent/c0-dup/dossier.yaml"

# write_file PATH CONTENT -- create PATH (and its parent folders) holding
# CONTENT verbatim; printf '%s' so a `%` or a backslash in CONTENT is inert.
write_file() {
  mkdir -p "$(dirname "$1")"
  printf '%s' "$2" >"$1"
}

# A complete, well-formed mail header plus a body -- the baseline every
# outbound case below starts from and breaks in exactly one place.
GOOD_MAIL='Status: draft
To: Jane Doe
Subject: Follow-up on the audit
Written by: agent session, 2026-09-17

Hello Jane,

Here is the follow-up we discussed.
'

# --- E1: an outbound mail with a body and no status block at all (D-07) ---
make_case e1
write_file "$parent/e1/outbound/mails/2026-09-17_relance.md" 'Hello Jane,

Here is the follow-up we discussed, with no header above it.
'

# --- E2: a `sent` status with a date but no sender (D-08) ---
make_case e2
write_file "$parent/e2/outbound/mails/2026-09-17_relance.md" 'Status: sent 2026-09-17
To: Jane Doe
Subject: Follow-up on the audit
Written by: agent session, 2026-09-17

Body.
'

# --- e2-reviewed: E2, `reviewed by` with no name -- the same defect (D-08) ---
make_case e2-reviewed
write_file "$parent/e2-reviewed/outbound/mails/2026-09-17_relance.md" 'Status: reviewed by
To: Jane Doe
Subject: Follow-up on the audit
Written by: agent session, 2026-09-17

Body.
'

# --- E3: a relative Deadline (D-09) ---
make_case e3
write_file "$parent/e3/outbound/mails/2026-09-17_relance.md" 'Status: draft
To: Jane Doe
Subject: Follow-up on the audit
Deadline: next week
Written by: agent session, 2026-09-17

Body.
'

# --- e3-baddate: E3, a Deadline with the right shape and an impossible date ---
make_case e3-baddate
write_file "$parent/e3-baddate/outbound/mails/2026-09-17_relance.md" 'Status: draft
To: Jane Doe
Subject: Follow-up on the audit
Deadline: 2026-13-45
Written by: agent session, 2026-09-17

Body.
'

# --- mail-no-subject: E1, a mail header without Subject: (A-02) ---
# calls-no-subject is the same file under outbound/calls/, where Subject: is
# not required: it must lint clean.
NO_SUBJECT='Status: draft
To: Jane Doe
Written by: agent session, 2026-09-17

Body.
'
make_case mail-no-subject
write_file "$parent/mail-no-subject/outbound/mails/2026-09-17_relance.md" "$NO_SUBJECT"
make_case calls-no-subject
write_file "$parent/calls-no-subject/outbound/calls/2026-09-17_relance.md" "$NO_SUBJECT"

# --- header-ok: well-formed headers in the three comment syntaxes -- clean ---
# The Markdown mail also quotes an older header below line 10, which must be
# ignored (P-06); the HTML-comment and `#`-comment headers exercise the
# no-per-format-parser rule (D-07); the sent status carries date, time and
# sender (D-08) and the Deadline is a real date (D-09).
make_case header-ok
write_file "$parent/header-ok/outbound/mails/2026-09-17_relance.md" "${GOOD_MAIL}
Best regards.

> On 2026-09-10 you wrote:
> Status: sent yesterday
> Deadline: next week
"
write_file "$parent/header-ok/outbound/mails/2026-09-18_suite.md" '<!--
Status: sent 2026-09-18 14:30 by Jane Doe
To: Jane Doe
Subject: Next steps
Deadline: 2026-10-01
Written by: Sam
Rules: no confidential names; see knowledge/DOCTRINE.md
-->

Body.
'
write_file "$parent/header-ok/outbound/calls/2026-09-19_kickoff.txt" '# Status: reviewed by Sam
# To: Jane Doe
# Written by: agent session, 2026-09-19

Agenda.
'
write_file "$parent/header-ok/outbound/deliverables/2026-09-20_audit.html" '<!-- Status: draft -->
<!-- To: Jane Doe -->
<!-- Written by: Sam -->
<p>Audit.</p>
'

# Call minutes whose body, inside the 10-line window, repeats a Status: line
# (first occurrence wins, P-06) and mentions a Deadline: mid-sentence (only
# a line that *starts* with a field, after comment syntax, is a header line).
write_file "$parent/header-ok/outbound/calls/2026-09-21_debrief.md" 'Status: draft
To: Jane Doe
Written by: Sam

Minutes.
Jane read the old header aloud:
Status: sent last week
We said the Deadline: next week was fine.
'

# --- binary-ok: a rendered PDF beside its Markdown source -- clean (D-07) ---
# The .pdf carries no text header and is outside E1-E3; its .md sibling
# carries the header.
make_case binary-ok
: >"$parent/binary-ok/outbound/deliverables/2026-09-17_audit.pdf"
write_file "$parent/binary-ok/outbound/deliverables/2026-09-17_audit.md" "$GOOD_MAIL"

# make_lang_case NAME LANGUAGE [INIT_ARG...] -- a fresh init.py scaffold at
# "$parent/NAME" in LANGUAGE, with the extra flags given. Used when a case
# needs a confidential name, a consent or a content language other than the
# clean tree's `en`: the flags go through the producer, so dossier.yaml keeps
# init.py's exact bytes instead of a hand edit.
make_lang_case() {
  local name="$1" language="$2"
  shift 2
  claim_case "$name"
  mkdir -p "$parent/$name"
  python3 "$INIT_PY" --target "$parent/$name" --language "$language" "$@" >/dev/null
}

# make_named_case NAME [INIT_ARG...] -- make_lang_case in `en`.
make_named_case() {
  local name="$1"
  shift
  make_lang_case "$name" en "$@"
}

# --- E4: a valid header under a filename that is not YYYY-MM-DD_slug.ext (D-10) ---
make_case e4
write_file "$parent/e4/outbound/mails/Relance_Finale.md" "$GOOD_MAIL"

# --- e4-baddate: E4, the right shape with an impossible date (D-10, D-09) ---
make_case e4-baddate
write_file "$parent/e4-baddate/outbound/mails/2026-13-45_relance.md" "$GOOD_MAIL"

# --- E5: a confidential name in the body of a well-named mail (D-11) ---
make_named_case e5 --confidential-name Acme
write_file "$parent/e5/outbound/mails/2026-09-17_relance.md" "${GOOD_MAIL}
Nous travaillons avec Acme.
"

# --- e5-filename: E5, the name only in the filename (D-11, F-02) ---
# The name sits at the head of the slug, right after the `_`: the case the
# naive (?<!\w) boundary silently misses.
make_named_case e5-filename --confidential-name Acme
write_file "$parent/e5-filename/outbound/mails/2026-09-17_acme-offer.md" "$GOOD_MAIL"

# --- e5-boundary: the name inside longer words -- clean (D-11) ---
make_named_case e5-boundary --confidential-name Acme
write_file "$parent/e5-boundary/outbound/mails/2026-09-17_note.md" "${GOOD_MAIL}
Acmetal and AcmeCorp are unrelated.
"

# --- e5-nfd: E5, an accented name written decomposed, configured composed (P-05) ---
# dossier.yaml carries the NFC spelling (init.py writes what it is given);
# the body carries the NFD spelling a macOS editor may store.
make_named_case e5-nfd --confidential-name "$(printf 'Soci\303\251t\303\251 Exemple')"
python3 - "$parent/e5-nfd/outbound/mails/2026-09-17_relance.md" "$GOOD_MAIL" <<'PY2'
import sys, unicodedata
name = unicodedata.normalize("NFD", "Société Exemple")
assert name != unicodedata.normalize("NFC", name)
with open(sys.argv[1], "w", encoding="utf-8") as handle:
    handle.write(sys.argv[2] + "\nWe met " + name + " today.\n")
PY2

# --- e5-binary: E5, a binary that will not decode, with the name in its filename (P-07) ---
# The text half is skipped without a crash; the filename half still runs.
make_named_case e5-binary --confidential-name Acme
printf '\377\376\000binary\200' >"$parent/e5-binary/outbound/deliverables/2026-09-17_acme-scan.pdf"
# Its Markdown source sits beside it (so E9, plan 02-04, stays silent); the
# name in that sibling's filename is a second, equally legitimate E5.
write_file "$parent/e5-binary/outbound/deliverables/2026-09-17_acme-scan.md" "$GOOD_MAIL"

# --- e5-nonames: an empty confidential_names list, a counterpart in the body -- clean ---
make_case e5-nonames
write_file "$parent/e5-nonames/outbound/mails/2026-09-17_relance.md" "${GOOD_MAIL}
Nous travaillons avec Acme.
"

# --- c1-quoted-leak: a malformed consent flag plus a leak -> C1 AND E5 (T-02-02) ---
# consent_recorded: "true" (quoted) is a config error read as false, so the
# leak check stays armed even though a source is filled in.
make_named_case c1-quoted-leak --confidential-name Acme --consent-source 'mail 2026-09-16 from Jane'
replace_line "$parent/c1-quoted-leak/dossier.yaml" 'consent_recorded: false' 'consent_recorded: "true"'
write_file "$parent/c1-quoted-leak/outbound/mails/2026-09-17_relance.md" "${GOOD_MAIL}
Nous travaillons avec Acme.
"

# --- consent-ok-leak: consent recorded AND sourced suppresses E5 -- clean (spec Sec3.2) ---
make_named_case consent-ok-leak --confidential-name Acme --consent-recorded true \
  --consent-source 'mail 2026-09-16 from Jane'
write_file "$parent/consent-ok-leak/outbound/mails/2026-09-17_relance.md" "${GOOD_MAIL}
Nous travaillons avec Acme.
"

# --- consent-nosource-leak: consent recorded WITHOUT a source -> E6 AND E5 (D-12) ---
# "A consent without a source is an opinion": it does not buy the suppression.
make_named_case consent-nosource-leak --confidential-name Acme --consent-recorded true
write_file "$parent/consent-nosource-leak/outbound/mails/2026-09-17_relance.md" "${GOOD_MAIL}
Nous travaillons avec Acme.
"

# ---------------------------------------------------------------------------
# The confidentiality gate fails closed (CR-01, T-02-02). A line that carries
# confidential_names, consent_recorded or consent_source and that the subset
# parser cannot read must never turn E5 off quietly: it is a C1 error, never
# a C0 warning. Every case below leaks Acme in a well-formed mail.
# ---------------------------------------------------------------------------

LEAK_MAIL="${GOOD_MAIL}
Nous travaillons avec Acme.
"

# make_gate_case NAME NEW -- the clean tree, its `confidential_names: []`
# line replaced by NEW (which may span several lines), plus the leaking mail.
make_gate_case() {
  make_case "$1"
  replace_line "$parent/$1/dossier.yaml" 'confidential_names: []' "$2"
  write_file "$parent/$1/outbound/mails/2026-09-17_relance.md" "$LEAK_MAIL"
}

# --- gate-col0: a block sequence with its items at column 0 -- ordinary YAML, read ---
make_gate_case gate-col0 "$(printf 'confidential_names:\n- Acme')"
# --- gate-multiline: a flow sequence spread over three lines -- C1 ---
make_gate_case gate-multiline "$(printf 'confidential_names: [\n  Acme\n]')"
# --- gate-escape: a YAML escape the subset does not read -- C1 ---
# (The backslash comes from printf's octal \134, so this file holds no escape of its own.)
make_gate_case gate-escape "$(printf 'confidential_names: [ "Acme", "Zo\134x65" ]')"
# --- gate-typo: a stray token after a quoted name -- C1 ---
make_gate_case gate-typo 'confidential_names: [ "Acme" , "Beta" x ]'
# --- gate-quoted-key: the key itself quoted -- C1 ---
make_gate_case gate-quoted-key '"confidential_names": [ Acme ]'
# --- gate-nocolon: the colon forgotten -- C1 ---
make_gate_case gate-nocolon 'confidential_names [ Acme ]'
# --- gate-indent: the item indentation changes partway through -- C1 ---
make_gate_case gate-indent "$(printf 'confidential_names:\n  - Beta\n - Acme')"
# --- gate-dup: the key twice, the second one empty -- C1, first wins, E5 armed ---
make_gate_case gate-dup "$(printf 'confidential_names: [ Acme ]\nconfidential_names: []')"

# --- gate-consent-dup: consent_recorded twice, false then true, source filled -- C1 AND E5 ---
# A last-wins reader takes the true and suppresses E5 with exit 0.
make_named_case gate-consent-dup --confidential-name Acme --consent-source 'mail 2026-09-16 from Jane'
replace_line "$parent/gate-consent-dup/dossier.yaml" 'consent_recorded: false' \
  "$(printf 'consent_recorded: false\nconsent_recorded: true')"
write_file "$parent/gate-consent-dup/outbound/mails/2026-09-17_relance.md" "$LEAK_MAIL"

# --- gate-consent-dup-rev: the same, true then false -- C1 AND E5 ---
# First wins, so the flag reads true; a damaged gate still keeps E5 armed.
make_named_case gate-consent-dup-rev --confidential-name Acme --consent-source 'mail 2026-09-16 from Jane'
replace_line "$parent/gate-consent-dup-rev/dossier.yaml" 'consent_recorded: false' \
  "$(printf 'consent_recorded: true\nconsent_recorded: false')"
write_file "$parent/gate-consent-dup-rev/outbound/mails/2026-09-17_relance.md" "$LEAK_MAIL"

# --- gate-source-broken: consent recorded, its source line unreadable -- C1, E6 AND E5 ---
make_named_case gate-source-broken --confidential-name Acme --consent-recorded true \
  --consent-source 'mail 2026-09-16 from Jane'
replace_line "$parent/gate-source-broken/dossier.yaml" 'consent_source: "mail 2026-09-16 from Jane"' \
  'consent_source: "mail 2026-09-16 from Jane'
write_file "$parent/gate-source-broken/outbound/mails/2026-09-17_relance.md" "$LEAK_MAIL"

# --- gate-json-dup: a JSON config naming the key twice, the second empty -- C1 AND E5 ---
# json.loads alone keeps the last value, which would disable E5 with exit 0.
make_case gate-json-dup
write_file "$parent/gate-json-dup/dossier.yaml" '{
  "version": 1,
  "language": "en",
  "confidential_names": ["Acme"],
  "confidential_names": []
}
'
write_file "$parent/gate-json-dup/outbound/mails/2026-09-17_relance.md" "$LEAK_MAIL"
# --- gate-json-consent-dup: a JSON config with consent_recorded true, then false (WR-04) ---
# keep_first() reads the true; with a filled source, only the damaged-gate
# flag keeps E5 armed.
make_case gate-json-consent-dup
write_file "$parent/gate-json-consent-dup/dossier.yaml" '{
  "version": 1,
  "language": "en",
  "confidential_names": ["Acme"],
  "consent_recorded": true,
  "consent_recorded": false,
  "consent_source": "mail 2026-09-16 from Jane"
}
'
write_file "$parent/gate-json-consent-dup/outbound/mails/2026-09-17_relance.md" "$LEAK_MAIL"
# --- gate-misindent-block / gate-misindent-scalar: the names line indented by mistake (CR-01) ---
# Appended after the counterparts block, or after a scalar, one level too
# deep: a conforming YAML parser rejects both files. The line carries the
# gate key itself, whatever block its indentation puts it in.
make_gate_case gate-misindent-block '  confidential_names: [ Acme ]'
make_case gate-misindent-scalar
drop_line "$parent/gate-misindent-scalar/dossier.yaml" 'confidential_names: []'
replace_line "$parent/gate-misindent-scalar/dossier.yaml" 'status_header: required' \
  "$(printf 'status_header: required\n  confidential_names: [ Acme ]')"
write_file "$parent/gate-misindent-scalar/outbound/mails/2026-09-17_relance.md" "$LEAK_MAIL"
# --- gate-key-*: a misspelt gate key, which D-22 would otherwise ignore (WR-01) ---
# A hyphen, a capital, a dropped letter, a space: each is the names line
# with a key the schema does not know, so E5 would be off with nothing said.
make_gate_case gate-key-dash 'confidential-names: [ Acme ]'
make_gate_case gate-key-case 'Confidential_names: [ Acme ]'
make_gate_case gate-key-typo 'confidental_names: [ Acme ]'
make_gate_case gate-key-space 'confidential names: [ Acme ]'
# --- gate-nested-seq: a nested sequence inside the names list (WR-01) ---
# YAML reads a list inside the list; the subset must not read `- Acme` as a name.
make_gate_case gate-nested-seq "$(printf 'confidential_names:\n  - - Acme')"
# --- gate-in-counterpart: the names line indented to a counterpart item's column (WR-01) ---
# YAML reads it as counterparts[0].confidential_names, and the top-level key is absent.
make_gate_case gate-in-counterpart '    confidential_names: [ Acme ]'
# --- gate-joined: the names line joined onto the line above it (WR-01) ---
# `: ` inside a plain scalar is not YAML; the subset must not read the
# names as part of status_header's value.
make_case gate-joined
drop_line "$parent/gate-joined/dossier.yaml" 'confidential_names: []'
replace_line "$parent/gate-joined/dossier.yaml" 'status_header: required' \
  'status_header: required confidential_names: [ Acme ]'
write_file "$parent/gate-joined/outbound/mails/2026-09-17_relance.md" "$LEAK_MAIL"
# --- gate-key-consent: a misspelt consent_recorded beside a sourced consent (WR-01) ---
make_named_case gate-key-consent --confidential-name Acme --consent-recorded true \
  --consent-source 'mail 2026-09-16 from Jane'
replace_line "$parent/gate-key-consent/dossier.yaml" 'consent_recorded: true' 'consent-recorded: true'
write_file "$parent/gate-key-consent/outbound/mails/2026-09-17_relance.md" "$LEAK_MAIL"
# --- gate-key-beside-consent: a certain misspelling of consent_recorded beside a recorded,
# sourced consent still keeps E5 armed (iteration-3 review WR-02; kills mutation M1, which
# forces the near-miss scan's contribution to gate_damaged to False) ---
make_named_case gate-key-beside-consent --confidential-name Acme --consent-recorded true \
  --consent-source 'mail 2026-09-16 from Jane'
printf 'Consent_recorded: false\n' >>"$parent/gate-key-beside-consent/dossier.yaml"
write_file "$parent/gate-key-beside-consent/outbound/mails/2026-09-17_relance.md" "$LEAK_MAIL"
# --- gate-json-key-case / gate-json-nested: the same two mistakes in a JSON config (WR-01) ---
make_case gate-json-key-case
write_file "$parent/gate-json-key-case/dossier.yaml" '{
  "version": 1,
  "language": "en",
  "Confidential_Names": ["Acme"]
}
'
write_file "$parent/gate-json-key-case/outbound/mails/2026-09-17_relance.md" "$LEAK_MAIL"
make_case gate-json-nested
write_file "$parent/gate-json-nested/dossier.yaml" '{
  "version": 1,
  "language": "en",
  "counterparts": [{"name": "Jane", "confidential_names": ["Acme"]}]
}
'
write_file "$parent/gate-json-nested/outbound/mails/2026-09-17_relance.md" "$LEAK_MAIL"
# --- gate-json-deep: a gate key two levels below the top, a depth the YAML subset cannot
# express (iteration-3 review WR-02; kills mutation M2, which drops visit()'s recursion below
# the first nesting level) ---
make_case gate-json-deep
write_file "$parent/gate-json-deep/dossier.yaml" '{
  "version": 1,
  "language": "en",
  "counterparts": [{"name": "Jane", "meta": {"confidential_names": ["Acme"]}}]
}
'
write_file "$parent/gate-json-deep/outbound/mails/2026-09-17_relance.md" "$LEAK_MAIL"
# --- gate-key-extras / gate-key-extras-leak: legitimate extension keys beside the exact
# gate keys are ignored, not reported (D-22, 2026-09-25 UAT test 2, G-02-2) ---
# consent_scope, confidential_notes and the rest of WR-01's measured mappings sit right next
# to confidential_names, consent_recorded and consent_source -- at top level and nested under
# a counterpart. The exact gate key is present each time, so a near-miss beside it is a
# different, legitimate key, not a misspelling.
build_gate_key_extras() {
  make_named_case "$1" --confidential-name Acme --counterpart 'Acme|ordering party'
  printf 'consent_scope: "mails only"\nconsent_sources: "see HISTORY"\nconsent_required: true\nconsent_revoked: false\nconsent_recorded_at: "2026-09-16"\nconfidential: "internal"\nconfidential_notes: "ask Jane first"\nnon_confidential_names: [ Beta ]\n' \
    >>"$parent/$1/dossier.yaml"
  replace_line "$parent/$1/dossier.yaml" '    role: "ordering party"' \
    "$(printf '    role: "ordering party"\n    confidential_notes: "ask Jane first"')"
}
build_gate_key_extras gate-key-extras
build_gate_key_extras gate-key-extras-leak
write_file "$parent/gate-key-extras-leak/outbound/mails/2026-09-17_relance.md" "$LEAK_MAIL"
# --- gate-nested-typo: a JSON nested near-miss stays C1 while the exact gate key it
# resembles is absent from the top level (D-22, D-GAP-1, G-02-2) ---
make_case gate-nested-typo
write_file "$parent/gate-nested-typo/dossier.yaml" '{
  "version": 1,
  "language": "en",
  "counterparts": [{"name": "Jane", "confidental_names": ["Acme"]}]
}
'
write_file "$parent/gate-nested-typo/outbound/mails/2026-09-17_relance.md" "$LEAK_MAIL"
# --- gate-skip-armed: consent recorded and sourced, plus one unreadable line (CR-01) ---
# Any skipped line may have been the gate, so the leak check stays armed.
make_named_case gate-skip-armed --confidential-name Acme --consent-recorded true \
  --consent-source 'mail 2026-09-16 from Jane'
printf 'this line is not yaml\n' >>"$parent/gate-skip-armed/dossier.yaml"
write_file "$parent/gate-skip-armed/outbound/mails/2026-09-17_relance.md" "$LEAK_MAIL"
# --- gate-sq-names / gate-sq-source: `''` inside a single-quoted scalar (WR-01) ---
# Valid YAML: the doubled quote is an escaped apostrophe, so the `,` and
# the `#` after it are still inside the scalar.
make_gate_case gate-sq-names "confidential_names: [ 'O''Brien, Jr', Acme ]"
make_named_case gate-sq-source --confidential-name Acme --consent-recorded true --consent-source 'placeholder'
replace_line "$parent/gate-sq-source/dossier.yaml" 'consent_source: "placeholder"' \
  "consent_source: 'mail 2026-09-16 from Jane: it''s # ok'"
write_file "$parent/gate-sq-source/outbound/mails/2026-09-17_relance.md" "$LEAK_MAIL"
# --- source-null / source-tilde / source-punct: a consent_source that is no source (WR-02) ---
# YAML reads an unquoted null or ~ as "no value", and a value with no letter
# or digit names nobody: each is the "true without a source" of spec Sec3.2,
# so E6 fires and the leak check stays armed.
for pair in 'source-null:null' 'source-tilde:~' 'source-punct:"-"'; do
  case_name="${pair%%:*}"
  make_named_case "$case_name" --confidential-name Acme --consent-recorded true --consent-source 'placeholder'
  replace_line "$parent/$case_name/dossier.yaml" 'consent_source: "placeholder"' "consent_source: ${pair#*:}"
  write_file "$parent/$case_name/outbound/mails/2026-09-17_relance.md" "$LEAK_MAIL"
done
# --- stray-config / stray-config-knowledge: a dossier.yaml inside the fixed layout (WR-03) ---
# A nested dossier cannot legitimately live in sources/, dossier/, outbound/
# or knowledge/, so a stray dossier.yaml there is never a sub-dossier
# boundary: pruning on it would hide the whole folder from every check.
make_gate_case stray-config 'confidential_names: [ Acme ]'
: >"$parent/stray-config/outbound/mails/dossier.yaml"
make_named_case stray-config-knowledge
: >"$parent/stray-config-knowledge/knowledge/dossier.yaml"
printf '%s\n' 'The budget is decided tomorrow.' >>"$parent/stray-config-knowledge/knowledge/CONTEXT.md"
# --- readme-nested: a README.md below outbound/'s root is an outbound file (WR-04, D-06) ---
# D-06 exempts outbound/README.md only; a draft saved as README.md in a
# subfolder must still carry its status header (D-10 still spares it E4).
make_case readme-nested
write_file "$parent/readme-nested/outbound/mails/README.md" 'Hello Jane,

A draft saved under the wrong name, with no header.
'
# --- os-junk / os-junk-leak: files the OS drops into a folder it shows (WR-05) ---
# Finder writes .DS_Store, Explorer Thumbs.db and desktop.ini: none is an
# outbound document, so none needs a header or a dated name -- but E5
# still reads them.
make_case os-junk
printf '\000\000\000\001Bud1\000\020\000' >"$parent/os-junk/outbound/mails/.DS_Store"
printf '\320\317\021\340\241\261\032\341' >"$parent/os-junk/outbound/deliverables/Thumbs.db"
printf '[.ShellClassInfo]\r\nIconResource=C:\\Windows\\system32\\imageres.dll,-3\r\n' \
  >"$parent/os-junk/outbound/calls/desktop.ini"
make_gate_case os-junk-leak 'confidential_names: [ Acme ]'
rm "$parent/os-junk-leak/outbound/mails/2026-09-17_relance.md"
printf '[.ShellClassInfo]\r\nInfoTip=Acme files\r\n' >"$parent/os-junk-leak/outbound/calls/desktop.ini"
# --- symlink-outbound / symlink-outbound-sub / symlink-knowledge: a symlinked folder (WR-02) ---
# The walk never follows a directory symlink (T-02-03), so the folder's
# files meet no check. Under outbound/ that is every leak check gone: the
# symlink itself must be reported. The real folder sits inside the case
# tree, outside the layout, where no outbound check looks.
make_gate_case symlink-outbound 'confidential_names: [ Acme ]'
write_file "$parent/symlink-outbound/outbound/mails/2026-09-17_nohead.md" 'Hello Jane, Acme here.
'
mkdir -p "$parent/symlink-outbound/elsewhere"
mv "$parent/symlink-outbound/outbound" "$parent/symlink-outbound/elsewhere/outbound-real"
ln -s elsewhere/outbound-real "$parent/symlink-outbound/outbound"
make_gate_case symlink-outbound-sub 'confidential_names: [ Acme ]'
mkdir -p "$parent/symlink-outbound-sub/elsewhere"
mv "$parent/symlink-outbound-sub/outbound/mails" "$parent/symlink-outbound-sub/elsewhere/mails-real"
ln -s ../elsewhere/mails-real "$parent/symlink-outbound-sub/outbound/mails"
make_named_case symlink-knowledge
printf '%s\n' 'The budget is decided tomorrow.' >>"$parent/symlink-knowledge/knowledge/CONTEXT.md"
mkdir -p "$parent/symlink-knowledge/elsewhere"
mv "$parent/symlink-knowledge/knowledge" "$parent/symlink-knowledge/elsewhere/knowledge-real"
ln -s elsewhere/knowledge-real "$parent/symlink-knowledge/knowledge"
# ---------------------------------------------------------------------------
# case-outbound / case-outbound-sub / case-knowledge / case-lookalike: a case
# variant of a fixed layout name fails closed (G-02-4a, CR-01 of the
# iteration-3 review). An adopted repository on a case-insensitive
# filesystem (the macOS default) may keep `Outbound/`; init.py's
# `makedirs(exist_ok=True)` keeps it too. Until the rename is applied, the
# linter must not exit 0 while a leak sits under it. Every rename below goes
# through a temporary name in two `mv` steps: a one-step case-only rename is
# a no-op on a case-insensitive filesystem, so these fixtures mean the same
# thing there and on a case-sensitive one.
# ---------------------------------------------------------------------------

# --- case-outbound: outbound/ itself renamed to Outbound/ (top-level LAYOUT_DIRS) ---
# outbound/mails/acme.md is headerless and outbound/mails/2026-09-17_relance.md
# is a well-formed leak: once the folder is Outbound/, neither is selected by
# the exact `outbound/` prefix any outbound check uses, so only the folder's
# own case-variant finding fires.
make_named_case case-outbound --confidential-name Acme
write_file "$parent/case-outbound/outbound/mails/acme.md" 'We met Acme.
'
write_file "$parent/case-outbound/outbound/mails/2026-09-17_relance.md" "$LEAK_MAIL"
mv "$parent/case-outbound/outbound" "$parent/case-outbound/outbound-tmp-rename"
mv "$parent/case-outbound/outbound-tmp-rename" "$parent/case-outbound/Outbound"

# --- case-outbound-config: Outbound/ additionally holds its own dossier.yaml
# (CR-01 of the iteration-4 review). walk_tree used to test layout
# membership case-sensitively, so this variant was pruned as a D-03
# sub-dossier boundary before the case-variant E1 loop above ever saw it --
# its leak never surfaced. Layout membership is now case-folded, so Outbound/
# is walked like any other case variant and its own E1 still fires.
make_named_case case-outbound-config --confidential-name Acme
write_file "$parent/case-outbound-config/outbound/mails/2026-09-17_relance.md" "$LEAK_MAIL"
cp "$parent/case-outbound-config/dossier.yaml" "$parent/case-outbound-config/outbound/dossier.yaml"
mv "$parent/case-outbound-config/outbound" "$parent/case-outbound-config/outbound-tmp-rename"
mv "$parent/case-outbound-config/outbound-tmp-rename" "$parent/case-outbound-config/Outbound"

# --- case-outbound-sub: outbound/mails/ renamed to outbound/Mails/ (OUTBOUND_SUBS) ---
# outbound/ itself keeps its correct spelling, so the leak is still under the
# exact `outbound/` prefix: E1-E3 and E5 still read it, only E4 (which needs
# the exact sub name) stays silent.
make_named_case case-outbound-sub --confidential-name Acme
write_file "$parent/case-outbound-sub/outbound/mails/2026-09-17_relance.md" "$LEAK_MAIL"
mv "$parent/case-outbound-sub/outbound/mails" "$parent/case-outbound-sub/outbound/mails-tmp-rename"
mv "$parent/case-outbound-sub/outbound/mails-tmp-rename" "$parent/case-outbound-sub/outbound/Mails"

# --- case-knowledge: knowledge/ renamed to Knowledge/ (top-level LAYOUT_DIRS) ---
make_case case-knowledge
mv "$parent/case-knowledge/knowledge" "$parent/case-knowledge/knowledge-tmp-rename"
mv "$parent/case-knowledge/knowledge-tmp-rename" "$parent/case-knowledge/Knowledge"

# --- case-lookalike: folder names that only start with a layout name -- clean ---
# The rule is an exact case-insensitive match, never a prefix or substring
# match: neither name here is a case variant of outbound/.
make_case case-lookalike
write_file "$parent/case-lookalike/outbound-old/notes.md" 'Not a layout folder.
'
write_file "$parent/case-lookalike/Outbounds/notes.md" 'Not a layout folder either.
'
# ---------------------------------------------------------------------------
# unreadable-outbound / unreadable-knowledge / git-outbound / git-knowledge:
# a folder the walk cannot list, or a .git folder, inside the fixed layout
# is reported rather than skipped in silence (G-02-4e, WR-03 of the
# iteration-3 review). The chmod that makes a folder unreadable is the
# test's job, never the generator's (a mode-000 folder would make this very
# tree undeletable by anyone who forgets to restore it) -- the two
# unreadable cases only lay out the leak; tests/test-lint.sh does the
# locking.
# ---------------------------------------------------------------------------

# --- unreadable-outbound: tests/test-lint.sh chmod 000s outbound/mails ---
make_named_case unreadable-outbound --confidential-name Acme
write_file "$parent/unreadable-outbound/outbound/mails/2026-09-17_relance.md" "$LEAK_MAIL"

# --- unreadable-knowledge: tests/test-lint.sh chmod 000s knowledge/watch ---
make_case unreadable-knowledge

# --- git-outbound: a .git folder under outbound/, never walked but reported ---
make_named_case git-outbound --confidential-name Acme
write_file "$parent/git-outbound/outbound/mails/.git/2026-09-17_relance.md" "$LEAK_MAIL"

# --- git-knowledge: same, elsewhere in the layout -- an info line, not E1 ---
make_case git-knowledge
write_file "$parent/git-knowledge/knowledge/.git/HEAD" 'ref: refs/heads/main
'
# --- enc-leak: a finding that a non-UTF-8 stdout cannot encode (WR-06) ---
# The name is L-with-stroke + ukasz, outside latin-1, so a strict encoder
# raises on the E5 line itself.
make_named_case enc-leak --confidential-name "$(printf '\305\201ukasz')"
write_file "$parent/enc-leak/outbound/mails/2026-09-17_relance.md" "${GOOD_MAIL}
We met $(printf '\305\201ukasz') today.
"
# --- gate-block / gate-json-*: the gate's parser branches init.py never writes (WR-09) ---
# init.py always writes a one-line flow list of double-quoted names, so the
# block-sequence and JSON branches of the gate need fixtures of their own.
make_gate_case gate-block "$(printf 'confidential_names:\n  - Beta\n  - "Acme"\n  - '"'"'Sam'"'"'')"

# write_json_gate NAME CONSENT_RECORDED CONSENT_SOURCE -- a JSON config
# naming Acme, the two consent values given as raw JSON, plus the leak.
write_json_gate() {
  make_case "$1"
  write_file "$parent/$1/dossier.yaml" "{
  \"version\": 1,
  \"language\": \"en\",
  \"confidential_names\": [\"Acme\"],
  \"consent_recorded\": $2,
  \"consent_source\": $3
}
"
  write_file "$parent/$1/outbound/mails/2026-09-17_relance.md" "$LEAK_MAIL"
}
write_json_gate gate-json-quoted '"true"' '"mail 2026-09-16 from Jane"'
write_json_gate gate-json-nullsource 'true' 'null'
write_json_gate gate-json-ok 'true' '"mail 2026-09-16 from Jane"'
write_json_gate gate-json-armed 'false' '""'
# --- linebreak-name / linebreak-yaml: Unicode line breaks inside a name (CR-02) ---
# str.splitlines() treats U+2028, U+2029 and U+0085 as line breaks; YAML 1.2
# and the producer do not. A name holding one must neither reach
# dossier.yaml raw (producer side) nor split the names line in two, dropping
# every name on it (consumer side). Built from bytes: bash 3.2 has no \u.
LS="$(printf '\342\200\250')"
PS="$(printf '\342\200\251')"
NEL="$(printf '\302\205')"
make_named_case linebreak-name --confidential-name "Acme${LS}Corp" \
  --confidential-name "Big${PS}Telco" --confidential-name "Sam${NEL}Co" --confidential-name Beta
write_file "$parent/linebreak-name/outbound/mails/2026-09-17_relance.md" "${GOOD_MAIL}
Beta asked for the audit.
"
# --- linebreak-words: a break or a control between two words separates them (CR-02) ---
# A Word manual line break, a tab from a spreadsheet cell, a newline, NEL,
# and a run of them: init.py writes each as one space, never deleting it
# (which would fuse `Acme Corp` into `AcmeCorp`, a needle nothing matches).
# The leak is both in a body and in a conforming slug, per name.
make_named_case linebreak-words --confidential-name "Acme${LS}Corp" \
  --confidential-name "Big$(printf '\t')Telco" --confidential-name "$(printf 'Sam\nCo')" \
  --confidential-name "Nord${NEL}Star" --confidential-name "$(printf 'Red\t\r\nFox')"
write_file "$parent/linebreak-words/outbound/mails/2026-09-17_relance.md" "${GOOD_MAIL}
We met Acme Corp, Big Telco, Sam Co, Nord Star and Red Fox today.
"
for slug in acme-corp big-telco sam-co nord-star red-fox; do
  write_file "$parent/linebreak-words/outbound/mails/2026-09-17_${slug}.md" "$GOOD_MAIL"
done
make_case linebreak-yaml
replace_line "$parent/linebreak-yaml/dossier.yaml" 'confidential_names: []' \
  "confidential_names: [ \"Acme${LS}Corp\", \"Sam${NEL}Co\", \"Beta\" ]"
write_file "$parent/linebreak-yaml/outbound/mails/2026-09-17_relance.md" "${GOOD_MAIL}
Beta asked for the audit.
"
# --- format-name-yaml / format-name-init / format-body: a Unicode format character (category
# Cf) inside a configured name, an outbound body, or a path below outbound/ never hides the
# name, on either side, and init.py never writes one raw (D-GAP-6, G-02-4b, CR-02 of the
# iteration-3 review and D-FIX-12 of its fix round, which already does this for line breaks).
# Built from bytes: bash 3.2 has no \u. ZWSP U+200B, BOM U+FEFF, SHY (soft hyphen) U+00AD,
# ZWNJ U+200C, WJ (word joiner) U+2060.
ZWSP="$(printf '\342\200\213')"
BOM="$(printf '\357\273\277')"
SHY="$(printf '\302\255')"
ZWNJ="$(printf '\342\200\214')"
WJ="$(printf '\342\201\240')"

# format-name-yaml (consumer side, hand-written): five names, each carrying a format character
# either inside a word (the deletion reading is what matches) or between two words (the space
# reading is what matches); the message names the space reading (D-GAP-6).
make_case format-name-yaml
replace_line "$parent/format-name-yaml/dossier.yaml" 'confidential_names: []' \
  "confidential_names: [ \"Acme${ZWSP}Corp\", \"Big Telco${BOM}\", \"${WJ}Nord Star\", \"Red${ZWNJ}Fox\", \"Glo${SHY}bex\" ]"
write_file "$parent/format-name-yaml/outbound/mails/2026-09-17_relance.md" "${GOOD_MAIL}
We met Acme Corp today.
Then Big Telco called.
Nord Star joined the call.
Red Fox signed.
Finally Globex agreed.
"

# format-name-init (producer side, round trip): the same five names through init.py.
# dossier.yaml must hold the space reading of each, never the raw format character
# (D-FIX-12 extended).
make_named_case format-name-init --confidential-name "Acme${ZWSP}Corp" --confidential-name "Big Telco${BOM}" \
  --confidential-name "${WJ}Nord Star" --confidential-name "Red${ZWNJ}Fox" --confidential-name "Glo${SHY}bex"
write_file "$parent/format-name-init/outbound/mails/2026-09-17_relance.md" "${GOOD_MAIL}
We met Acme Corp, Big Telco, Nord Star, Red Fox and Globex today.
"
for slug in acme-corp big-telco nord-star red-fox globex; do
  write_file "$parent/format-name-init/outbound/mails/2026-09-17_${slug}.md" "$GOOD_MAIL"
done

# format-body (haystack side): eight lines each hide a plain "Acme" or "Big Telco" behind a
# format character read one of the two ways the readings cover -- embedded inside a word
# (deletion), or between two words (space) -- plus a boundary that was already open before this
# fix (L7: a format character already counts as non-word for boundary_pattern(), which a
# deletion-only fix would break, D-GAP-6), an &shy; HTML reference that needs Task 2's decode
# and this task's readings together (L8), and the name surviving only in a path below E4's
# scope.
make_named_case format-body --confidential-name Acme --confidential-name 'Big Telco'
write_file "$parent/format-body/outbound/mails/2026-09-17_relance.md" "${GOOD_MAIL}
L1: Ac${SHY}me signed.
L2: Ac${ZWSP}me signed.
L3: Ac${WJ}me signed.
L4: Ac${ZWNJ}me signed.
L5: Ac${BOM}me signed.
L6: Big${ZWSP}Telco called.
L7: Contact${ZWSP}Acme today.
L8: Ac&shy;me in a pasted snippet.
"
write_file "$parent/format-body/outbound/mails/archive/2026-09-17_ac${SHY}me.md" "$GOOD_MAIL"
# --- Multi-word names: filename slugs and whitespace variants (CR-03) ---
# E4 only accepts a lowercase ASCII slug joined by hyphens, so the only
# conforming spelling of a multi-word name in a filename is `big-telco`;
# in text, a mail body is hard-wrapped and spaced by hand.
make_named_case e5-slug --confidential-name 'Big Telco'
write_file "$parent/e5-slug/outbound/mails/2026-09-17_big-telco-offer.md" "$GOOD_MAIL"
# The slug with no separator at all, and an accented name folded to ASCII.
make_named_case e5-slug-joined --confidential-name 'Big Telco'
write_file "$parent/e5-slug-joined/outbound/mails/2026-09-17_bigtelco-offer.md" "$GOOD_MAIL"
make_named_case e5-slug-accent --confidential-name "$(printf 'Soci\303\251t\303\251 Exemple')"
write_file "$parent/e5-slug-accent/outbound/mails/2026-09-17_societe-exemple-offer.md" "$GOOD_MAIL"
# Letters NFKD does not decompose (CR-03): a stroke, a slash, a ligature, an
# eth, a thorn, a dotless i. Each name is leaked through its only conforming
# slug; Đ has two customary transliterations, d and dj, and both are slugs.
TRANSLIT_PAIRS='Łukasz Nowak:lukasz-nowak
Michał Zieliński:michal-zielinski
Øresund Bank:oresund-bank
Søren Holm:soren-holm
Æther Labs:aether-labs
Encyclopædia Nordica:encyclopaedia-nordica
Œuvre SA:oeuvre-sa
Cœur Studio:coeur-studio
Đorđe Petrović:djordje-petrovic
Đorđe Petrović:dorde-petrovic
Straße AG:strasse-ag
Þór Holdings:thor-holdings
Borgarþing:borgarthing
Aðalsteinn Ltd:adalsteinn-ltd
Kırmızı Tekstil:kirmizi-tekstil
Ħamrun Spartans:hamrun-spartans'
set --
previous=''
while IFS= read -r pair; do
  # Đorđe Petrović has two slugs but is configured once.
  [ "${pair%%:*}" = "$previous" ] || set -- "$@" --confidential-name "${pair%%:*}"
  previous="${pair%%:*}"
done <<EOF
$TRANSLIT_PAIRS
EOF
make_named_case e5-slug-translit "$@"
set --
while IFS= read -r pair; do
  write_file "$parent/e5-slug-translit/outbound/mails/2026-09-17_${pair#*:}.md" "$GOOD_MAIL"
done <<EOF
$TRANSLIT_PAIRS
EOF
# --- e5-text-fold / e5-text-fold-boundary: the text half spells a name as the slug does (WR-03) ---
# A body typed without accents, a name hyphenated or run together in prose,
# a letter NFKD leaves whole: each is the name. Each sits on its own line,
# after a line whose folding changes its length (Æ -> ae, ﬁ -> fi), so a
# line number taken from the wrong string would show.
make_named_case e5-text-fold --confidential-name "$(printf 'Soci\303\251t\303\251 Exemple')" \
  --confidential-name 'Big Telco' --confidential-name 'Łukasz Nowak' --confidential-name "O'Brien" \
  --confidential-name 'Đorđe Petrović'
write_file "$parent/e5-text-fold/outbound/mails/2026-09-17_relance.md" "${GOOD_MAIL}
Æsthetics of the ﬁnal draft.
We met Societe Exemple today.
Æ ﬁ Æ ﬁ.
Then Big-Telco called, then BigTelco wrote.
Lukasz Nowak signed. So did OBrien.
Djordje Petrovic did not.
"
# The folded half must not match more than a spelling of the name: not
# across a comma, and never for a name whose punctuation carries meaning
# (`C++` folds to the single letter c, which is everywhere in prose).
make_named_case e5-text-fold-boundary --confidential-name 'Big Telco' --confidential-name 'C++'
write_file "$parent/e5-text-fold-boundary/outbound/mails/2026-09-17_relance.md" "${GOOD_MAIL}
We asked Big, Telco answered. See section c of the plan, c'est clair.
"
# --- e5-html-entities: HTML character references never hide a name (D-GAP-5, G-02-4c, CR-03
# of the iteration-3 review) --- .html is a sanctioned outbound format, and standard
# serialisation escapes `&` and often `'` and accented letters as named or numeric references;
# a decoded haystack must catch them, in an .html deliverable and in a Markdown mail pasted
# from a web page alike.
make_named_case e5-html-entities --confidential-name 'Johnson & Johnson' --confidential-name 'AT&T' \
  --confidential-name "$(printf 'Soci\303\251t\303\251 Exemple')" --confidential-name "O'Brien"
write_file "$parent/e5-html-entities/outbound/deliverables/2026-09-17_proposal.html" '<!-- Status: draft -->
<!-- To: Jane Doe -->
<!-- Written by: Sam -->
<p>Prepared for Johnson &amp; Johnson and AT&amp;T.</p>
<p>Soci&eacute;t&eacute; Exemple, Soci&#233;t&#233; Exemple</p>
<p>Dear Mr O&#39;Brien, Mr O&rsquo;Brien</p>
'
write_file "$parent/e5-html-entities/outbound/mails/2026-09-17_relance.md" "${GOOD_MAIL}
Pasted from the portal: AT&amp;T
"
# The boundary still holds in both halves: longer words are not the name.
make_named_case e5-slug-boundary --confidential-name 'Big Telco'
write_file "$parent/e5-slug-boundary/outbound/mails/2026-09-17_bigtelcom-offer.md" "${GOOD_MAIL}
Bigger Telco and Big Telcom are unrelated.
"
# The name hard-wrapped across two lines of a mail body, then wrapped again
# inside three styles of quoted reply -- a single '> ', a nested '> > ', and
# a bare '>' with no space -- none of which may stop the match either
# (D-GAP-4, G-02-4f, WR-04 of the iteration-3 review).
make_named_case e5-wrapped --confidential-name 'Big Telco'
write_file "$parent/e5-wrapped/outbound/mails/2026-09-17_relance.md" "${GOOD_MAIL}
We met the people at Big
Telco last week.

> On Monday you wrote: we should meet Big
> Telco next week.
> > Earlier still: the Big
> > Telco board met.
>Tightly quoted: Big
>Telco again.
"
# Two spaces, a no-break space, a tab: one finding each.
make_named_case e5-spacing --confidential-name 'Big Telco'
write_file "$parent/e5-spacing/outbound/mails/2026-09-17_relance.md" "${GOOD_MAIL}
Two spaces: Big  Telco.
No-break space: Big$(printf '\302\240')Telco.
Tab: Big$(printf '\t')Telco.
"
# --- e5-readme: E5, a confidential name in the exempt outbound/README.md (Q-5) ---
# README.md is exempt from E1-E4 only: a leaked name is a leak wherever it sits.
# e5-readme-nonames is the same edit with no configured name -- clean, which
# proves the README content alone raises nothing.
make_named_case e5-readme --confidential-name Acme
printf '\nOur reference client is Acme.\n' >>"$parent/e5-readme/outbound/README.md"
make_case e5-readme-nonames
printf '\nOur reference client is Acme.\n' >>"$parent/e5-readme-nonames/outbound/README.md"


# --- e8: E8, a .claude/ folder below the dossier root (D-14, spec Sec4.4 check 7) ---
# This case is exactly why the fixtures are generated rather than committed
# (D-29): the repository's .gitignore ignores `.claude/` at any depth, so a
# committed copy of this tree would silently lose its one violation.
make_case e8
mkdir -p "$parent/e8/dossier/.claude"
printf 'placeholder\n' >"$parent/e8/dossier/.claude/settings.json"

# --- claude-at-root: the root's own .claude/ -- clean (D-14) ---
# Exactly `<root>/.claude` is the agent folder D-14 permits.
make_case claude-at-root
mkdir -p "$parent/claude-at-root/.claude"
printf 'placeholder\n' >"$parent/claude-at-root/.claude/settings.json"

# --- e9: E9, a rendered deliverable with no source beside it (D-15, spec Sec4.4 check 8) ---
make_case e9
: >"$parent/e9/outbound/deliverables/2026-09-17_audit.pdf"

# --- e9-docx: E9, the same rule for the other rendered extension (D-15) ---
make_case e9-docx
: >"$parent/e9-docx/outbound/deliverables/2026-09-17_audit.docx"

# --- e9-source-only: a source with no render -- clean (D-15: the reverse is silent) ---
make_case e9-source-only
write_file "$parent/e9-source-only/outbound/deliverables/2026-09-17_audit.md" "$GOOD_MAIL"

# --- render-html-ok: a .pdf beside an .html source -- clean (D-15) ---
make_case render-html-ok
: >"$parent/render-html-ok/outbound/deliverables/2026-09-17_audit.pdf"
write_file "$parent/render-html-ok/outbound/deliverables/2026-09-17_audit.html" '<!-- Status: draft -->
<!-- To: Jane Doe -->
<!-- Written by: Sam -->
<p>Audit.</p>
'

# --- e9-outside-deliverables: a lone .pdf under outbound/mails/ -- clean (D-15 scope) ---
# E9 is scoped to outbound/deliverables/; a binary elsewhere is outside E1-E3
# too, and its well-formed name keeps E4 quiet.
make_case e9-outside-deliverables
: >"$parent/e9-outside-deliverables/outbound/mails/2026-09-17_audit.pdf"

# ---------------------------------------------------------------------------
# W1 -- relative-date words (D-16, D-17). Warnings only: every case exits 0.
# ---------------------------------------------------------------------------

# The typographic apostrophe (U+2019) a smart-quotes editor writes, as bytes
# so the dialect stays bash 3.2 and the character stays visible here (P-05).
RSQUO="$(printf '\342\200\231')"

# --- w1-fr: one bait per scope and spelling, none of them a bullet ---
# dossier/ and knowledge/ are both in scope; a multi-word entry matches as a
# phrase; the typographic apostrophe matches the list's ASCII entry.
make_lang_case w1-fr fr
printf '%s\n' 'Elle rappelle demain pour valider le périmètre.' >>"$parent/w1-fr/dossier/HISTORY.md"
printf '%s\n' 'Le marché a bougé récemment.' >>"$parent/w1-fr/knowledge/CONTEXT.md"
printf '%s\n' 'Le devis part la semaine prochaine.' >>"$parent/w1-fr/dossier/OPEN-QUESTIONS.md"
printf 'Le cadrage a été confirmé aujourd%shui.\n' "$RSQUO" >>"$parent/w1-fr/dossier/TONE.md"

# --- w1-en: the English list, a word and a phrase ---
make_named_case w1-en
printf '%s\n' 'Jane calls back tomorrow.' >>"$parent/w1-en/dossier/HISTORY.md"
printf '%s\n' 'The budget is decided next week.' >>"$parent/w1-en/knowledge/CONTEXT.md"

# --- w1-boundary: `hier` inside `fichiers` and `hiérarchie` -- clean (P-04) ---
# Sourced, so W2 stays quiet too: the only way this case raises anything is
# a word match without boundaries.
make_lang_case w1-boundary fr
printf '%s\n' '- Les fichiers de la hiérarchie sont classés par canal (mail 2026-09-16 de Jane).' \
  >>"$parent/w1-boundary/dossier/CHANNELS.md"

# --- w1-outbound: a relative-date word under outbound/ -- clean (spec Sec4.4 check 5 scope) ---
make_lang_case w1-outbound fr
write_file "$parent/w1-outbound/outbound/mails/2026-09-17_relance.md" "${GOOD_MAIL}Je vous rappelle demain.
"

# --- w1-nolist: a language with no word list -- W1 and W2 skipped, one info line (D-20) ---
make_lang_case w1-nolist de
printf '%s\n' 'Jane calls back tomorrow.' '- An unsourced bullet line' >>"$parent/w1-nolist/dossier/HISTORY.md"

# ---------------------------------------------------------------------------
# W2 -- bullet lines with no parenthetical source (D-16, D-18). Warnings only.
# ---------------------------------------------------------------------------

# --- w2-fr: every W2 branch in one living file, plus three out-of-scope files ---
# Each HISTORY.md line exists to fail one specific way: a sourced bullet, an
# unsourced one, the `*` marker, an opinion marker, an inflected near-marker
# (`reconstruite` is not `reconstruit`), a bullet inside a genuine multi-line
# comment block, one right after it closes and a heading whose text starts
# with a bullet marker. None carries a relative-date word, so W1 stays
# silent and every warning here is a W2.
make_lang_case w2-fr fr
cat >>"$parent/w2-fr/dossier/HISTORY.md" <<'MD'
- Jane Doe (Acme) rappelle le 2026-10-01 (appel @12:34).
- Le livrable est attendu le 2026-10-01.
* Une autre ligne sans source
- Probablement un budget revu à la hausse.
- Leur priorité est reconstruite à partir de leurs questions.
<!--
- Une piste non vérifiée sur le budget
-->
- Une ligne après le commentaire
## - Une rubrique en forme de puce
MD
# dossier/README.md is not a living file (P-02): seven unsourced bullets
# there must stay silent, which is what iterating LIVING_FILES buys.
i=1
while [ "$i" -le 7 ]; do
  printf -- '- Puce de README sans source %s\n' "$i" >>"$parent/w2-fr/dossier/README.md"
  i=$((i + 1))
done
printf '%s\n' '- Une puce de contexte sans source' >>"$parent/w2-fr/knowledge/CONTEXT.md"
write_file "$parent/w2-fr/outbound/mails/2026-09-17_relance.md" "${GOOD_MAIL}- Une puce de mail sans source
"

# --- w2-en: the English opinion markers ---
make_named_case w2-en
printf '%s\n' '- Jane asked for the audit (call @12:34).' '- The budget was cut.' \
  '- Probably a revised budget.' >>"$parent/w2-en/dossier/HISTORY.md"

# --- w2-many: twenty unsourced bullets still exit 0 (D-16, T-02-16) ---
make_lang_case w2-many fr
i=1
while [ "$i" -le 20 ]; do
  printf -- '- Une ligne sans source numero %s\n' "$i" >>"$parent/w2-many/dossier/HISTORY.md"
  i=$((i + 1))
done

echo "$parent"
