---
status: complete
phase: 02-linter-test-harness
source: [02-VERIFICATION.md, 02-REVIEW.md]
started: 2026-09-24T21:30:53Z
updated: 2026-10-10T11:12:52.479Z
---

## Current Test

[testing complete]

## Tests

### 1. D-FIX-8 — unparseable dossier.yaml lines are now C1 errors (narrows D-22)
expected: Samuel accepts the fail-closed reading of D-22, or requests a refinement. See 02-REVIEW-FIX.md.
result: pass

### 2. D-FIX-9 / D-FIX-10 — near-miss gate-key threshold (difflib ratio 0.8) and stricter plain scalars
expected: Samuel accepts the boundaries, knowing iteration-3 review WR-01 shows legitimate extra keys (consent_scope, confidential_notes, consent_required) now fail the run; or asks for tuning (e.g. an allowlist of known extra keys).
result: issue
reported: "corrige" (apply the WR-01 fix proposed by the iteration-3 review)
severity: major

### 3. D-FIX-3 / WR-03 — E5 text matching broadened to ASCII-folded, hyphenated and run-together spellings
expected: Samuel accepts "match more" (fewer missed leaks, occasional false positive such as Élan vs elan), or asks to narrow the separator set.
result: pass

### 4. Iteration-3 residual findings — accept as tracked debt, or order one more fix round
expected: |
  Samuel decides on the three reproduced critical paths (each lets a confidential name under
  outbound/ pass with exit 0), none introduced by the fix rounds:
  CR-01 an `Outbound/` folder on a case-insensitive filesystem gets no outbound checks;
  CR-02 zero-width / BOM / soft-hyphen characters in a name survive init.py and defeat the text match;
  CR-03 HTML entities in an outbound .html file hide names (`AT&amp;T`, `Soci&eacute;t&eacute;`).
  Plus warnings WR-01..04 of the iteration-3 review (02-REVIEW.md).
result: issue
reported: "tout" (fix CR-01..03 and WR-02..04 in the same gap-closure round as WR-01)
severity: blocker

### 5. Re-test item 2 — extension keys beside the gate keys (G-02-2, after 02-07)
expected: Recette scenarios 1-2. consent_scope + confidential_notes beside the exact keys lint clean (exit 0); a typo confidental_names beside the exact key is ERROR [C1] "looks like a misspelling of confidential_names" (exit 1).
result: pass
source: agent-run (Samuel delegated the recette, 2026-10-10: "test tout toi meme")
evidence: recette scenario 1 -> "0 error(s), 0 warning(s)", exit 0; scenario 2 -> "ERROR [C1] key 'confidental_names' looks like a misspelling of confidential_names", exit 1

### 6. Re-test item 4 — CR-01..03 and WR-02..04 closed (G-02-4a..4f, after 02-07..02-09)
expected: Recette scenarios 3-9 each exit 1 with the named error, no confidential name passes — Outbound/ case variant E1; zero-width/soft-hyphen in the name E5; HTML entities in .html E5 (AT&T and Société Exemple); outbound/mails/.git E1; unreadable folder E1; name wrapped across "> " quoted lines E5; misspelt Consent_recorded beside a recorded consent gives C1 AND E5.
result: pass
source: agent-run (Samuel delegated the recette, 2026-10-10: "test tout toi meme")
evidence: recette scenarios 3-9 all exit 1 with the expected class (3 E1 Outbound, 4 E5, 5 E5 x2, 6 E1 .git, 7 E1 unreadable, 8 E5, 9 C1+E5); bash tests/run.sh: 6 files, 0 failed

## Summary

total: 6
passed: 4
issues: 2
pending: 0
skipped: 0
blocked: 0

## Gaps

- gap_id: G-02-2
  truth: "A legitimate extension key beside the exact gate keys (consent_scope, confidential_notes) is ignored per D-22; only certain near-misses of a gate key fail the run"
  status: resolved
  resolved_by: 02-07-PLAN.md
  resolved_at: 2026-10-10
  reason: "User reported: corrige — apply the iteration-3 WR-01 fix"
  severity: major
  test: 2
  root_cause: "GATE_KEY_CUTOFF = 0.8 difflib ratio in scripts/lint.py flags distinct keys as misspelt gate keys even when the exact gate key is present; the C1 message ('write the key exactly') invites a gate-weakening edit"
  artifacts:
    - path: "scripts/lint.py"
      issue: "gate_key_for() / near-miss rule (around lines 226, 513-524, 821-828)"
  missing:
    - "Keep C1 for keys equal to a gate key after _fold_key (case, '-', space)"
    - "Keep C1 for a difflib-only near-miss only while the exact gate key is absent at top level; otherwise ignore it (D-22)"
    - "Reword the message to 'looks like a misspelling of X'"
    - "Fixture: consent_scope + confidential_notes beside the exact keys, asserting exit 0"
  debug_session: "02-REVIEW.md WR-01 (diagnosed by iteration-3 review)"

- gap_id: G-02-4a
  truth: "A case variant of a fixed layout folder (Outbound/, Mails/, Deliverables/, Calls/) never escapes the outbound checks: the linter fails closed"
  status: resolved
  resolved_by: 02-08-PLAN.md
  resolved_at: 2026-10-10
  reason: "User reported: tout — fix CR-01 of the iteration-3 review"
  severity: blocker
  test: 4
  root_cause: "Outbound checks select files by the exact on-disk prefix 'outbound/'; on a case-insensitive FS an 'Outbound/' folder is the same folder the agent writes to, yet nothing under it is checked; init.py makedirs(exist_ok) keeps it"
  artifacts:
    - path: "scripts/lint.py"
      issue: "outbound_files exact prefix (~1131-1134), walk_tree (~1026-1049)"
    - path: "skills/dossier-init/scripts/init.py"
      issue: "makedirs exist_ok keeps an existing Outbound/"
  missing:
    - "ERROR on any case variant of a fixed layout dir name (top level and outbound/ subs)"
    - "Fixture reproducing Outbound/ with a leaking name, asserting exit 1"
  debug_session: "02-REVIEW.md CR-01 (diagnosed and reproduced by iteration-3 review)"

- gap_id: G-02-4b
  truth: "A Unicode format character (Cf: ZWSP, BOM, soft hyphen, ZWNJ, word joiner) in a confidential name or in a body never hides the name from E5"
  status: resolved
  resolved_by: 02-09-PLAN.md
  resolved_at: 2026-10-10
  reason: "User reported: tout — fix CR-02 of the iteration-3 review"
  severity: blocker
  test: 4
  root_cause: "init.py _SCALAR_BREAKS_RE only strips Cc and U+2028/2029; lint.py keeps Cf chars inside the needle (exact pattern needs the literal char, _TEXT_FOLDABLE_RE rejects the needle) and inside the haystack"
  artifacts:
    - path: "skills/dossier-init/scripts/init.py"
      issue: "_SCALAR_BREAKS_RE (~184)"
    - path: "scripts/lint.py"
      issue: "boundary_pattern (~1254-1273), _TEXT_FOLDABLE_RE (~1336), needle build (~853)"
  missing:
    - "Make needles and haystacks blind to category Cf in lint.py (Cf in needle -> separator, Cf in body dropped)"
    - "Producer side: init.py treats Cf like the other breaks"
    - "Fixtures for each char in the name and in the body"
  debug_session: "02-REVIEW.md CR-02 (diagnosed and reproduced by iteration-3 review)"

- gap_id: G-02-4c
  truth: "HTML character references in an outbound .html file (&amp; &#39; &eacute; &#233; &rsquo;) never hide a confidential name"
  status: resolved
  resolved_by: 02-09-PLAN.md
  resolved_at: 2026-10-10
  reason: "User reported: tout — fix CR-03 of the iteration-3 review"
  severity: blocker
  test: 4
  root_cause: "check_confidential_names searches the raw text only; .html is a sanctioned render source"
  artifacts:
    - path: "scripts/lint.py"
      issue: "check_confidential_names (~1386-1409)"
  missing:
    - "Add a line-preserving html.unescape haystack for both exact and folded passes"
    - "Fixture with Johnson & Johnson, AT&T, Société Exemple, O'Brien encoded"
  debug_session: "02-REVIEW.md CR-03 (diagnosed and reproduced by iteration-3 review)"

- gap_id: G-02-4d
  truth: "Every gate line is pinned by a test: gate_damaged keeps E5 armed beside a recorded consent, and nested-key recursion is exercised"
  status: resolved
  resolved_by: 02-07-PLAN.md
  resolved_at: 2026-10-10
  reason: "User reported: tout — fix WR-02 of the iteration-3 review"
  severity: major
  test: 4
  root_cause: "Two mutations survive tests/test-lint.sh: gate_damaged forced False, and dropping recursion in visit()"
  artifacts:
    - path: "scripts/lint.py"
      issue: "gate_damaged (~841), visit recursion (~816)"
    - path: "tests/test-lint.sh"
      issue: "missing fixtures"
  missing:
    - "Fixture gate-key-beside-consent (consent_recorded true + sourced consent_source + Consent_recorded false + leak) -> exit 1, C1 + E5"
    - "Fixture gate-json-deep -> C1 naming confidential_names"
  debug_session: "02-REVIEW.md WR-02 (diagnosed and reproduced by iteration-3 review)"

- gap_id: G-02-4e
  truth: "An unreadable folder or a .git/ folder under outbound/ is reported (E1), never skipped silently with exit 0"
  status: resolved
  resolved_by: 02-08-PLAN.md
  resolved_at: 2026-10-10
  reason: "User reported: tout — fix WR-03 of the iteration-3 review"
  severity: major
  test: 4
  root_cause: "os.walk has no onerror handler; PRUNED_DIRS prunes .git inside the layout too"
  artifacts:
    - path: "scripts/lint.py"
      issue: "walk_tree os.walk (~1026), PRUNED_DIRS (~1034-1035)"
  missing:
    - "os.walk onerror collects unreadable dirs; E1 for those under outbound/"
    - "Prune .git only outside LAYOUT_DIRS; E1 below outbound/"
    - "Fixtures (chmod 000 dir, outbound/mails/.git/)"
  debug_session: "02-REVIEW.md WR-03 (diagnosed and reproduced by iteration-3 review)"

- gap_id: G-02-4f
  truth: "A confidential name hard-wrapped inside a quoted mail reply ('> ' prefix) is found by E5"
  status: resolved
  resolved_by: 02-09-PLAN.md
  resolved_at: 2026-10-10
  reason: "User reported: tout — fix WR-04 of the iteration-3 review"
  severity: major
  test: 4
  root_cause: "Exact pattern joins tokens with \s+ and folded separator is [\s_'.\-]*; neither crosses a leading '> '"
  artifacts:
    - path: "scripts/lint.py"
      issue: "boundary_pattern \s+ (~1272), _TEXT_FOLD_SEPARATOR (~1339)"
  missing:
    - "Strip quote markers from the E5 haystack without touching newlines"
    - "Add a '> ' wrapped case to e5-wrapped"
  debug_session: "02-REVIEW.md WR-04 (diagnosed and reproduced by iteration-3 review)"
