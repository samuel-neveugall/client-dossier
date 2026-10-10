#!/usr/bin/env bash
# extract-text.sh — write a PDF's text next to it (mechanics tier; the
# judgement lives in skills/dossier-ingest/SKILL.md).
#
#   extract-text.sh FILE.pdf
#
# Writes exactly one file, <stem>.txt next to the PDF (UTF-8, a "--- page N ---"
# marker before each non-empty page; empty pages are skipped but keep their
# number), and prints "extracted: <txt>". The PDF is never modified. pdftotext
# writes into a temporary file outside the dossier, removed on every path, so a
# crash never leaves a partial .txt under sources/.
#
# set -u but not -e: the exit codes are the contract.
set -u

pdf="${1:-}"
case "$pdf" in
  *.pdf | *.PDF) ;;
  *) echo "usage: extract-text.sh FILE.pdf" >&2; exit 64 ;;
esac
[ -f "$pdf" ] || { echo "extract-text.sh: no such file: $pdf" >&2; exit 64; }
txt="${pdf%.*}.txt"

tmp="$(mktemp "${TMPDIR:-/tmp}/extract-text.XXXXXX")" || exit 1
trap 'rm -f "$tmp" "$tmp.p"' EXIT

# Default reading order and form-feed page breaks: the awk pass below needs them.
pdftotext -enc UTF-8 -- "$pdf" "$tmp" || exit 1

awk 'BEGIN { RS = "\f"; n = 0 } { n++; if ($0 ~ /[^ \t\r\n]/) printf "--- page %d ---\n%s", n, $0 }' "$tmp" >"$tmp.p" || exit 1

cat "$tmp.p" >"$txt" || exit 1
echo "extracted: $txt"
