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
# or a dangling symlink, and the final write is atomic and never clobbers: the
# text goes to a temporary file in the PDF's own folder, then `ln` gives it its
# final name, which fails when that name exists (also as a dangling symlink),
# so a .txt that appears during the extraction is not overwritten either.
#
# Confinement (A4-F8): the PDF must lie under the sources/ folder of a dossier
# (a directory named sources whose parent holds dossier.yaml); anything else is
# a usage error, so the script never writes next to an arbitrary PDF. Every
# name printed has its control characters replaced by '?', because the output
# is read by an agent and a newline in a file name would inject lines.
#
# set -u but not -e: the exit codes are the contract. Bash 3.2 compatible.
set -u

# safe TEXT — TEXT with every control character replaced by '?'.
# (a bash substitution, not tr: this runs before the PATH is known to be sane)
safe() { printf '%s' "${1//[[:cntrl:]]/?}"; }

pdf="${1:-}"
case "$pdf" in
  *.pdf | *.PDF) ;;
  *) echo "usage: extract-text.sh FILE.pdf" >&2; exit 64 ;;
esac
[ -f "$pdf" ] || { echo "extract-text.sh: no such file: $(safe "$pdf")" >&2; exit 64; }
txt="${pdf%.*}.txt"
case "$pdf" in
  */*) dir="${pdf%/*}"; [ -n "$dir" ] || dir="/" ;;
  *) dir="." ;;
esac

# Confinement: some ancestor of the PDF's physical folder is a sources/ whose
# parent holds dossier.yaml.
phys="$(cd -- "$dir" 2>/dev/null && pwd -P)" || phys=""
confined=0
walk="$phys"
while [ -n "$walk" ] && [ "$walk" != "/" ]; do
  parent="${walk%/*}"
  [ -n "$parent" ] || parent="/"
  if [ "${walk##*/}" = "sources" ] && [ -f "${parent%/}/dossier.yaml" ]; then
    confined=1
    break
  fi
  walk="$parent"
done
if [ "$confined" -ne 1 ]; then
  echo "extract-text.sh: $(safe "$pdf") is not under the sources/ folder of a dossier; nothing written." >&2
  exit 64
fi

if [ -e "$txt" ] || [ -L "$txt" ]; then
  echo "exists: $(safe "$txt")"
  exit 0
fi

if ! command -v pdftotext >/dev/null 2>&1; then
  echo "extract-text.sh: pdftotext not found; the PDF stays filed, extraction skipped." >&2
  echo "Install poppler: macOS 'brew install poppler'; Debian/Ubuntu 'sudo apt-get install poppler-utils'." >&2
  exit 69
fi

tmp="$(mktemp "${TMPDIR:-/tmp}/extract-text.XXXXXX")" || exit 1
final=""
trap 'rm -f "$tmp" "$tmp.p" "$final"' EXIT

# Default reading order and form-feed page breaks: the awk pass below needs them.
pdftotext -enc UTF-8 -- "$pdf" "$tmp" || exit 1

# A scan gives only form feeds: no non-whitespace character at all.
if [ -z "$(tr -d ' \t\r\n\f' <"$tmp" | head -c 1)" ]; then
  echo "extract-text.sh: no text layer in $(safe "$pdf") (a scan?); nothing written." >&2
  exit 65
fi

awk 'BEGIN { RS = "\f"; n = 0 } { n++; if ($0 ~ /[^ \t\r\n]/) printf "--- page %d ---\n%s", n, $0 }' "$tmp" >"$tmp.p" || exit 1

# The only write into the dossier: a complete temporary file next to the PDF,
# then ln, which refuses an existing name and a dangling symlink, including
# one that appeared since the pre-check above. Nothing partial ever has the
# final name.
final="$(mktemp "$dir/.extract-text.XXXXXX")" || { echo "extract-text.sh: could not write next to $(safe "$pdf")" >&2; exit 1; }
cat "$tmp.p" >"$final" || { echo "extract-text.sh: could not write $(safe "$txt")" >&2; exit 1; }
chmod 644 "$final" 2>/dev/null
if ! ln -- "$final" "$txt" 2>/dev/null; then
  if [ -e "$txt" ] || [ -L "$txt" ]; then
    echo "exists: $(safe "$txt")"
    exit 0
  fi
  echo "extract-text.sh: could not write $(safe "$txt")" >&2
  exit 1
fi
echo "extracted: $(safe "$txt")"
