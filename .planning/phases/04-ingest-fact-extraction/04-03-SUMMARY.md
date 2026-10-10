---
phase: 04-ingest-fact-extraction
plan: 03
subsystem: ingest
tags: [pdftotext, bash-3.2, extraction, test-fixtures]
requires:
  - phase: 03-protocol-skill-hooks
    provides: "hooks/guard-sources.py, which cannot see pdftotext or a script writing (hence the script's own no-overwrite)"
provides:
  - "skills/dossier-ingest/scripts/extract-text.sh: pdftotext wrapper with page markers and the 0/64/65/69/1 exit contract"
  - "tests/fixtures/make-pdf.py: stdlib PDF generator (text, @empty, @scan pages)"
  - "tests/test-ingest-extract.sh: every exit path under /bin/bash 3.2"
affects: [04-04 dossier-ingest SKILL.md and fact-extractor, 04-05 spec/CLAUDE.md amendments]
tech-stack:
  added: []
  patterns:
    - "private skill script reported from by exit code (sysexits 64/65/69)"
    - "no-overwrite enforced by the script itself: pre-check plus final write under set -C"
key-files:
  created:
    - skills/dossier-ingest/scripts/extract-text.sh
    - tests/fixtures/make-pdf.py
    - tests/test-ingest-extract.sh
  modified: []
key-decisions:
  - "A failed noclobber write is reported as exists: only when the target really exists (file or symlink); any other write failure is exit 1 with a message, so a read-only folder is not mistaken for a race."
  - "Task 1 shipped the happy path only; the exists pre-check, set -C write, scan (65) and missing-tool (69) branches were added in task 2 after the tests for them failed (RED 16 failures)."
patterns-established:
  - "Fake pdftotext first on PATH (EX_PATH) to exercise a race deterministically"
  - "Dedicated TMPDIR per case, asserted empty afterwards, to prove the EXIT trap"
requirements-completed: [INGEST-01]
status: complete
commits: 2
plan_head_before: e0b59cf
plan_head_after: 088cb79
actuals:
  tokens: 4530
  tasks: 2
  commits: 2
duration: 20min
completed: 2026-10-10
---

# Phase 4 Plan 03: PDF text extraction script Summary

`extract-text.sh` writes a PDF's UTF-8 text next to it with `--- page N ---` markers, never overwrites (even in a race), and reports a scan, a corrupt PDF and a missing pdftotext through distinct exit codes, tested under the system bash 3.2 from generated PDFs.

## Tasks

| Task | Commit | Result |
|---|---|---|
| 1. Fixture generator and happy path | 50ab4b7 | RED 3 pass / 21 fail, GREEN 24 pass / 0 fail |
| 2. Every other exit path | 088cb79 | RED 57 pass / 16 fail, GREEN 73 pass / 0 fail |

`extract-text.sh` and `make-pdf.py` are committed with mode 100755; no PDF is committed.

## Exit codes observed per case (pdftotext 26.04.0, /bin/bash 3.2)

| Case | Exit | stdout / stderr |
|---|---|---|
| two-page PDF with `Été` and `1,250` | 0 | `extracted: <txt>`; markers for pages 1 and 2; PDF sha256 unchanged |
| pages text, `@empty`, text | 0 | markers for pages 1 and 3 only |
| `.PDF` upper case, path with spaces | 0 | `extracted: .../Upper Case.txt` |
| `-dash.pdf` passed as `-dash.pdf` | 0 | `extracted: -dash.txt` (the `--` guards the name) |
| re-run on an extracted PDF | 0 | `exists: <txt>`, sha256 unchanged |
| hand-written `.txt` already there | 0 | `exists: <txt>`, content untouched |
| dangling symlink at the `.txt` name | 0 | `exists: <txt>`, nothing created at the link's destination |
| race (fake pdftotext creates the `.txt` with `RACE` first) | 0 | `exists: <txt>`, `.txt` still holds `RACE` |
| scan (`@scan @scan`) | 65 | stderr `no text layer in ... (a scan?); nothing written.`, no `.txt` |
| plain text under a `.pdf` name | 1 | pdftotext's own message passed through, no `.txt` |
| no argument / `notes.txt` / missing `.pdf` | 64 | `usage: ...` / `no such file: ...`, nothing written |
| pdftotext hidden from PATH | 69 | exactly two stderr lines (`pdftotext not found; ...`, `brew install poppler` and `sudo apt-get install poppler-utils`), no `.txt`, PDF unchanged |

With a dedicated `TMPDIR`, the folder is empty again after every case. Static checks: `set -C` present,
`pdftotext -enc UTF-8 --` present, no layout or page-break-suppression flag, no bash array syntax,
`#!/usr/bin/env bash`, `/bin/bash -n` clean.

## Verification

- `bash tests/test-ingest-extract.sh`: `PASS 73 FAIL 0`, no SKIP (pdftotext is installed here).
- `bash tests/run.sh`: `TOTAL: 12 files, 0 failed`.

## Deviations from Plan

None - plan executed as written. Two small additions within the plan's intent, not Rule 1-4 deviations:
the test also covers a pre-existing hand-written `.txt` (distinct from a re-run) and asserts the two
stderr lines of the 69 exit are exactly two; the final-write failure branch distinguishes "target
exists" from any other write error (exit 1) instead of reporting `exists:` for both.

Execution note: the worktree predates the Phase 4 planning commits, so the plan files were read from
the main checkout; the sandbox refused a compound command, so the test additions were applied with
separate Edit calls.

## Known Stubs

None.

## Threat Flags

None. Mitigations T-04-20 (exists pre-check, `set -C`, race test), T-04-21 (temp file outside the
dossier, single final write, corrupt and scan tests), T-04-22 (`--`, `-dash.pdf` test) and T-04-24
(EXIT trap, empty-TMPDIR assertions) are implemented and tested. T-04-23 accepted as planned.

## Self-Check: PASSED

- FOUND: skills/dossier-ingest/scripts/extract-text.sh (100755)
- FOUND: tests/fixtures/make-pdf.py (100755)
- FOUND: tests/test-ingest-extract.sh
- FOUND: commits 50ab4b7, 088cb79
