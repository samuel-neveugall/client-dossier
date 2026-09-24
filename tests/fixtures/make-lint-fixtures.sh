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

# --- c0-junk: C0, one line outside the YAML subset is skipped (D-22) ---
make_case c0-junk
printf 'this line is not yaml\n' >>"$parent/c0-junk/dossier.yaml"

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
make_case linebreak-yaml
replace_line "$parent/linebreak-yaml/dossier.yaml" 'confidential_names: []' \
  "confidential_names: [ \"Acme${LS}Corp\", \"Sam${NEL}Co\", \"Beta\" ]"
write_file "$parent/linebreak-yaml/outbound/mails/2026-09-17_relance.md" "${GOOD_MAIL}
Beta asked for the audit.
"
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
# The boundary still holds in both halves: longer words are not the name.
make_named_case e5-slug-boundary --confidential-name 'Big Telco'
write_file "$parent/e5-slug-boundary/outbound/mails/2026-09-17_bigtelcom-offer.md" "${GOOD_MAIL}
Bigger Telco and Big Telcom are unrelated.
"
# The name hard-wrapped across two lines of a mail body.
make_named_case e5-wrapped --confidential-name 'Big Telco'
write_file "$parent/e5-wrapped/outbound/mails/2026-09-17_relance.md" "${GOOD_MAIL}
We met the people at Big
Telco last week.
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
# comment block and one right after it closes. None carries a relative-date
# word, so W1 stays silent and every warning here is a W2.
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
