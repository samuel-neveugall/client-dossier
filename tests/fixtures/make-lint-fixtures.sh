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
# Creates one throwaway parent under `mktemp -d`, writes one subdirectory per
# case named after what it triggers, and echoes the parent's path. Installs
# no trap: the caller cleans up. Injections use python3, never in-place
# stream editing (not portable between BSD and GNU, P-11), and fail loudly
# when the line to change is not found, so a fixture never silently ships
# without its violation.
set -eu

if [ "$#" -ne 1 ] || [ ! -d "$1" ] || [ ! -f "$1/dossier.yaml" ]; then
  echo "usage: make-lint-fixtures.sh CLEAN_DOSSIER_DIR" >&2
  exit 2
fi

clean="$1"
parent="$(mktemp -d)"

# make_case NAME — a fresh copy of the clean tree at "$parent/NAME".
make_case() {
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

# --- e7: dossier/TONE.md loses its `Last updated:` line (D-13) ---
make_case e7
drop_line "$parent/e7/dossier/TONE.md" 'Last updated:'

echo "$parent"
