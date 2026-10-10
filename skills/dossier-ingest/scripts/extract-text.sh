#!/usr/bin/env bash
# extract-text.sh — write a PDF's text next to it (mechanics tier; the
# judgement lives in skills/dossier-ingest/SKILL.md).
#
#   extract-text.sh FILE.pdf        (also FILE.PDF)
#
# Writes exactly one file, <stem>.txt next to the PDF (UTF-8, a "--- page N ---"
# marker before each non-empty page; empty pages are skipped but keep their
# number), and prints "extracted: <txt>". The PDF is never modified. pdftotext
# writes into a temporary file outside the dossier, removed on every path, so a
# crash never leaves a partial .txt under sources/.
#
# Exit codes (the skill reports from them):
#   0   stdout "extracted: <txt>"  a new .txt written next to the PDF
#   0   stdout "exists: <txt>"     already there (file or symlink), untouched
#   64  usage: no argument, not a .pdf, or no such file
#   65  no text layer (a scan): nothing written
#   69  pdftotext not on PATH: install hint on stderr, nothing written (D-15)
#   1   pdftotext failed (its own message passed through), nothing written
#
# This script refuses to overwrite by itself: the Phase 3 sources guard cannot
# see pdftotext, or a script, writing. The pre-check reports an existing .txt
# or a dangling symlink, and the final write runs under `set -C` so a .txt that
# appears during the extraction is not clobbered either.
#
# set -u but not -e: the exit codes are the contract. Bash 3.2 compatible.
set -u

pdf="${1:-}"
case "$pdf" in
  *.pdf | *.PDF) ;;
  *) echo "usage: extract-text.sh FILE.pdf" >&2; exit 64 ;;
esac
[ -f "$pdf" ] || { echo "extract-text.sh: no such file: $pdf" >&2; exit 64; }
txt="${pdf%.*}.txt"

if [ -e "$txt" ] || [ -L "$txt" ]; then
  echo "exists: $txt"
  exit 0
fi

if ! command -v pdftotext >/dev/null 2>&1; then
  echo "extract-text.sh: pdftotext not found; the PDF stays filed, extraction skipped." >&2
  echo "Install poppler: macOS 'brew install poppler'; Debian/Ubuntu 'sudo apt-get install poppler-utils'." >&2
  exit 69
fi

tmp="$(mktemp "${TMPDIR:-/tmp}/extract-text.XXXXXX")" || exit 1
trap 'rm -f "$tmp" "$tmp.p"' EXIT

# Default reading order and form-feed page breaks: the awk pass below needs them.
pdftotext -enc UTF-8 -- "$pdf" "$tmp" || exit 1

# A scan gives only form feeds: no non-whitespace character at all.
if [ -z "$(tr -d ' \t\r\n\f' <"$tmp" | head -c 1)" ]; then
  echo "extract-text.sh: no text layer in $pdf (a scan?); nothing written." >&2
  exit 65
fi

awk 'BEGIN { RS = "\f"; n = 0 } { n++; if ($0 ~ /[^ \t\r\n]/) printf "--- page %d ---\n%s", n, $0 }' "$tmp" >"$tmp.p" || exit 1

# The only write into the dossier: noclobber refuses an existing file and a
# dangling symlink, including one that appeared since the pre-check above.
if ! ( set -C; cat "$tmp.p" >"$txt" ) 2>/dev/null; then
  if [ -e "$txt" ] || [ -L "$txt" ]; then
    echo "exists: $txt"
    exit 0
  fi
  echo "extract-text.sh: could not write $txt" >&2
  exit 1
fi
echo "extracted: $txt"
