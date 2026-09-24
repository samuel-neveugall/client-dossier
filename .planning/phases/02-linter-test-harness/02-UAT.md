---
status: testing
phase: 02-linter-test-harness
source: [02-VERIFICATION.md, 02-REVIEW.md]
started: 2026-09-24T21:30:53Z
updated: 2026-09-24T21:30:53Z
---

## Current Test

number: 1
name: D-FIX-8 — unparseable dossier.yaml lines are now C1 errors (narrows locked decision D-22)
expected: |
  Samuel confirms the fail-closed behaviour (any line the parser cannot attribute makes the run
  exit 1), or asks for a revert to a warning for lines under a clearly non-gate key.
awaiting: user response

## Tests

### 1. D-FIX-8 — unparseable dossier.yaml lines are now C1 errors (narrows D-22)
expected: Samuel accepts the fail-closed reading of D-22, or requests a refinement. See 02-REVIEW-FIX.md.
result: [pending]

### 2. D-FIX-9 / D-FIX-10 — near-miss gate-key threshold (difflib ratio 0.8) and stricter plain scalars
expected: Samuel accepts the boundaries, knowing iteration-3 review WR-01 shows legitimate extra keys (consent_scope, confidential_notes, consent_required) now fail the run; or asks for tuning (e.g. an allowlist of known extra keys).
result: [pending]

### 3. D-FIX-3 / WR-03 — E5 text matching broadened to ASCII-folded, hyphenated and run-together spellings
expected: Samuel accepts "match more" (fewer missed leaks, occasional false positive such as Élan vs elan), or asks to narrow the separator set.
result: [pending]

### 4. Iteration-3 residual findings — accept as tracked debt, or order one more fix round
expected: |
  Samuel decides on the three reproduced critical paths (each lets a confidential name under
  outbound/ pass with exit 0), none introduced by the fix rounds:
  CR-01 an `Outbound/` folder on a case-insensitive filesystem gets no outbound checks;
  CR-02 zero-width / BOM / soft-hyphen characters in a name survive init.py and defeat the text match;
  CR-03 HTML entities in an outbound .html file hide names (`AT&amp;T`, `Soci&eacute;t&eacute;`).
  Plus warnings WR-01..04 of the iteration-3 review (02-REVIEW.md).
result: [pending]

## Summary

total: 4
passed: 0
issues: 0
pending: 4
skipped: 0
blocked: 0

## Gaps
