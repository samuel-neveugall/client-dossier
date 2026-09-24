---
phase: 02-linter-test-harness
verified: 2026-09-24T21:30:00Z
status: human_needed
score: 4/4 must-haves verified
covered_files: [".planning/REQUIREMENTS.md", ".planning/WINDOWS.md", ".planning/phases/02-linter-test-harness/02-01-PLAN.md", ".planning/phases/02-linter-test-harness/02-01-SUMMARY.md", ".planning/phases/02-linter-test-harness/02-02-PLAN.md", ".planning/phases/02-linter-test-harness/02-02-SUMMARY.md", ".planning/phases/02-linter-test-harness/02-03-PLAN.md", ".planning/phases/02-linter-test-harness/02-03-SUMMARY.md", ".planning/phases/02-linter-test-harness/02-04-PLAN.md", ".planning/phases/02-linter-test-harness/02-04-SUMMARY.md", ".planning/phases/02-linter-test-harness/02-05-PLAN.md", ".planning/phases/02-linter-test-harness/02-05-SUMMARY.md", ".planning/phases/02-linter-test-harness/02-06-PLAN.md", ".planning/phases/02-linter-test-harness/02-06-SUMMARY.md", ".planning/phases/02-linter-test-harness/02-REVIEW-FIX.iter1.md", ".planning/phases/02-linter-test-harness/02-REVIEW-FIX.md", "CLAUDE.md", "scripts/lint.py", "skills/dossier-init/scripts/init.py", "tests/fixtures/make-adopt-fixture.sh", "tests/fixtures/make-lint-fixtures.sh", "tests/lib.sh", "tests/run.sh", "tests/test-init-adopt.sh", "tests/test-init-empty.sh", "tests/test-init-fr.sh", "tests/test-init-pointer.sh", "tests/test-lint.sh", "tests/test-skill-shape.sh"]
covered_digest: "v1:sha256:7e661b7c93c8613fcc11229749b82af47d108b9bc159c4fb6dc1852c05dcf6c6"
behavior_unverified: 0
overrides_applied: 0
human_verification:
  - test: "Confirm D-FIX-8 (02-REVIEW-FIX.md, iteration 2): an unparseable/misindented line in dossier.yaml now reports [C1] (error, exit 1) instead of the locked-decision D-22 behaviour of 'unknown or unparseable lines are skipped with a warning' (which would have been [C0], exit 0)."
    expected: "Samuel confirms this narrowing of D-22 is intentional and accepted (fail-closed on the confidentiality gate), or asks for it to be reverted to a warning for lines under a clearly non-gate key."
    why_human: "This is a deliberate deviation from a locked spec decision (D-22), flagged by the executor itself as 'requires human verification' — a policy choice, not a mechanical defect. Behaviour is internally consistent and covered by tests (gate-misindent-block, gate-misindent-scalar, c1-counterpart-broken)."
  - test: "Confirm D-FIX-9/D-FIX-10 (02-REVIEW-FIX.md): the difflib-ratio-0.8 near-miss threshold for misspelt gate keys (e.g. confidential_names vs confidential-names, nested confidential_names under counterparts) and the stricter plain-scalar rejection (values containing ': ', or starting with '- ', '? ', ': ') are the right boundaries."
    expected: "Samuel agrees the 0.8 threshold and the plain-scalar restrictions do not produce unwanted false positives on real dossier.yaml files, or requests the threshold/rules be tuned."
    why_human: "Explicitly flagged 'requires human verification (the near-miss threshold is a judgement call)' by the executor. Mechanically tested and passing, but the boundary itself is a design judgement, not a fact verifiable by grep."
  - test: "Confirm D-FIX-3/WR-03 (02-REVIEW-FIX.md): the E5 confidential-name text check now also matches the ASCII-folded spelling of a name in prose (accents dropped, punctuation-joined, e.g. 'Big. Telco' or 'jane.doe' matching 'Jane Doe'), which the fix report itself frames as a 'match more' choice made to keep the confidentiality gate closed, with named false-positive risks (e.g. 'Élan' matching common word 'elan')."
    expected: "Samuel accepts the broadened matching (fewer missed leaks, occasional false positive) as the right default for a confidentiality linter, or asks to narrow it (e.g. drop '.' from the separator set)."
    why_human: "Explicitly flagged 'requires human verification ... settles D-FIX-3 on the match more side' by the executor. This is a security/UX tradeoff, not a bug."
---

# Phase 2: Linter & Test Harness Verification Report

**Phase Goal:** Anyone (human or agent) can mechanically verify a dossier obeys the plugin's
rules with zero setup beyond python3.
**Verified:** 2026-09-24T21:30:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth (ROADMAP Phase 2 success criteria) | Status | Evidence |
|---|---|---|---|
| 1 | Running `scripts/lint.py` against a clean fixture dossier exits 0 | ✓ VERIFIED | Fresh `python3 skills/dossier-init/scripts/init.py --language en --target $TMPD/clean` piped into `python3 scripts/lint.py $TMPD/clean` printed `0 error(s), 0 warning(s)` and exited 0 (run directly by this verifier, not taken from SUMMARY). Also asserted as three committed cases in `tests/test-lint.sh` (`scaffold_lints_clean` for `en`, `fr`, and a fully-flagged scaffold). |
| 2 | Running it against error fixtures exits 1 and names the violation, for each of the nine error classes (missing status header, `sent` w/o date/sender, non-absolute `Deadline:`, malformed outbound filename, leaked confidential name, `consent_recorded: true` with empty `consent_source`, missing `Last updated:`, nested `.claude/`, rendered deliverable w/o source) | ✓ VERIFIED | `scripts/lint.py` implements `check_outbound_headers` (E1/E2/E3), `check_outbound_names` (E4), `check_confidential_names` (E5), `check_consent_source` (E6), `check_living_files` (E7), `check_claude_dirs` (E8), `check_renders` (E9). `tests/test-lint.sh`'s nine-class sweep (`SWEEP='e1:E1 e2:E2 ... e9:E9'`) asserts each fixture exits 1, fires only its own identifier, and reports at the correct location (D-07..D-15). Confirmed by running `bash tests/test-lint.sh` directly: `PASS 1290 FAIL 0`. |
| 3 | French-language fixture flags relative-date words and unsourced bullet lines as warnings (exit 0), and still finds the English `Last updated:` label | ✓ VERIFIED | Ran `python3 scripts/lint.py tests/fixtures/lint/fr` directly: output is 7 `WARNING [W1]`/`[W2]` lines (relative-date words `demain`, `la semaine prochaine`, `aujourd'hui`, `récemment`; unsourced bullets), `0 error(s), 7 warning(s)`, exit 0. No `[E7]` (missing `Last updated:`) fired, confirming the English label is found in French-content files. |
| 4 | A bash test runner in `tests/` runs every fixture and asserts `lint.py`'s exit codes and messages, and passes end to end | ✓ VERIFIED | `bash tests/run.sh` run directly by this verifier: `ok tests/test-init-adopt.sh`, `ok tests/test-init-empty.sh`, `ok tests/test-init-fr.sh`, `ok tests/test-init-pointer.sh`, `ok tests/test-lint.sh`, `ok tests/test-skill-shape.sh`, `TOTAL: 6 files, 0 failed`. No framework beyond bash/python3 (`#!/usr/bin/env bash` shebangs only, no `jq`/`node`/`perl` calls in `tests/`). |
| 5 (carried Phase 1 debt a) | YAML 1.1 reserved spellings (`no`, `yes`, `true`, ...) fed to `--language` are written quoted by `init.py`, and read back by `lint.py` as the literal string | ✓ VERIFIED | `skills/dossier-init/scripts/init.py` has `_YAML_RESERVED_SCALARS` (frozenset of `y n yes no on off true false null ~`) and `emit_scalar` quotes any value whose `.casefold()` is in that set. `scripts/lint.py`'s config schema reads the `language` field "verbatim ... `no` stays `\"no\"`" (line 707). `tests/test-lint.sh`'s round-trip case (from 02-06) scaffolds `--language no`, lints, and asserts a clean run with `info: language 'no' ...`, plus an unreserved `it` control. Verified passing inside the full `1290/1290` run above. |
| 6 (carried Phase 1 debt b) | `_SAFE_PLAIN_SCALAR_RE` anchors with `fullmatch` (not `match`), so a value ending in a newline is quoted/stripped rather than leaving a blank line | ✓ VERIFIED | `skills/dossier-init/scripts/init.py` line 254: `_SAFE_PLAIN_SCALAR_RE.fullmatch(value) is not None`. `tests/test-init-empty.sh` case d15 (trailing-newline payload built via sentinel to survive command substitution) is part of the green 6/6 suite run. |

**Score:** 4/4 ROADMAP success criteria verified (criteria 1–4), plus both carried-over Phase 1
debts (a) and (b) independently confirmed resolved in both producer (`init.py`) and consumer
(`lint.py`) code.

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `scripts/lint.py` | Python 3 stdlib-only linter implementing all 8(→9) mechanical checks + 2 warning classes | ✓ VERIFIED | 1728 lines; `CHECKS` tuple wires all 9 error-producing functions (E1–E9) plus C0/C1 config gate and W1/W2 warning functions; no non-stdlib imports found (`import` lines are `argparse, os, re, sys, json, unicodedata, difflib, ...` — verified by grep, all stdlib). |
| `skills/dossier-init/scripts/init.py` | Producer, hardened per Phase 1 debts (a)/(b) | ✓ VERIFIED | `_YAML_RESERVED_SCALARS`, `.fullmatch` confirmed present (see truths 5–6 above). |
| `tests/run.sh`, `tests/lib.sh`, `tests/test-lint.sh` | Bash test runner + harness + lint-specific assertions | ✓ VERIFIED | Ran directly: `bash tests/run.sh` → 6/6 files pass; `bash tests/test-lint.sh` → 1290/1290 assertions pass. |
| `tests/fixtures/make-lint-fixtures.sh` | Generates clean + nine error fixtures from a real `init.py` scaffold at test time | ✓ VERIFIED | Script reads `$1` (a clean tree from a real `init.py` run), never hand-writes the clean fixture, emits one throwaway subdir per case (`e1`..`e9`, `c0-*`, `c1-*`, `gate-*`, `symlink-*`, etc.). Confirmed by reading the script and by the sweep passing in `test-lint.sh`. |
| `tests/fixtures/lint/fr/` | Committed French-language fixture exercising W1/W2 and the English `Last updated:` label | ✓ VERIFIED | Directory exists with `dossier.yaml`, all 7 living files under `dossier/`, `knowledge/`, `outbound/`, `sources/` folders with `.gitkeep`; linted directly with expected W1/W2-only, exit-0 result (truth 3 above). |
| `CLAUDE.md` Commands section | Documents `python3 scripts/lint.py [PATH]` and `bash tests/run.sh` | ✓ VERIFIED | Lines 105/110/111 contain the documented invocations and exit-code notes. |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `skills/dossier-init/scripts/init.py` | `scripts/lint.py` | producer/consumer agreement on YAML reserved spellings (`language`) | ✓ WIRED | Confirmed end-to-end via the round-trip test and by reading both sides' code (see truth 5). |
| `CLAUDE.md` | `scripts/lint.py` | documented invocation | ✓ WIRED | `python3 scripts/lint.py [PATH]` literal string present in CLAUDE.md. |
| `tests/run.sh` | `tests/test-*.sh` | dispatcher globs and runs every test file, no per-file registration needed | ✓ WIRED | Confirmed by reading `tests/run.sh` (`for f in "$DIR"/test-*.sh`) and observing all 6 current test files execute. |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Clean scaffold lints 0/0, exit 0 | `init.py --language en --target $TMPD` then `lint.py $TMPD` | `0 error(s), 0 warning(s)`, exit 0 | ✓ PASS |
| French fixture warns only, exit 0, finds `Last updated:` | `lint.py tests/fixtures/lint/fr` | 7 warnings (`W1`/`W2`), 0 errors, exit 0, no `E7` | ✓ PASS |
| Full bash suite | `bash tests/run.sh` | `TOTAL: 6 files, 0 failed` | ✓ PASS |
| Lint-specific assertion count | `bash tests/test-lint.sh` | `PASS 1290 FAIL 0` | ✓ PASS |
| No debt markers in core files | `grep -rnE "TBD|FIXME|XXX|TODO|HACK|PLACEHOLDER" scripts/lint.py skills/dossier-init/scripts/init.py tests/*.sh` | Only hits are `PLACEHOLDER.md` filenames written by `make-adopt-fixture.sh` (a Phase 1 fixture-file naming convention, not a debt marker) | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan(s) | Description | Status | Evidence |
|---|---|---|---|---|
| LINT-01 | 02-01, 02-02, 02-03, 02-04, 02-05, 02-06 | `scripts/lint.py` implements all mechanical checks, exits 1 on error / 0 on warnings-only, ignores `.gitkeep` | ✓ SATISFIED | All 9 error + 2 warning checks present and independently exercised; `.gitkeep` dropped from the walk (line 102, 1017, 1132 in lint.py); REQUIREMENTS.md marks it Complete. |
| LINT-02 | 02-01, 02-02, 02-04, 02-05 | Fixture repositories: clean baseline, French-language fixture, error fixtures covering every class | ✓ SATISFIED | `make-lint-fixtures.sh` generates clean + e1..e9 + gate/symlink fixtures from a real `init.py` run; `tests/fixtures/lint/fr/` committed; REQUIREMENTS.md marks it Complete. |
| LINT-03 | 02-01 through 02-06 | Bash test runner asserting exit codes/messages, no framework beyond bash+python3 | ✓ SATISFIED | `tests/run.sh` + `tests/test-lint.sh`, 1290 assertions, 0 non-bash/python3 dependencies found; REQUIREMENTS.md marks it Complete. |

No orphaned requirements: REQUIREMENTS.md's Phase 2 row (LINT-01/02/03) matches exactly what all
six 02-0N-PLAN.md files declare in their `requirements:` frontmatter.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---|---|---|---|
| — | — | None found in `scripts/lint.py`, `skills/dossier-init/scripts/init.py`, or `tests/*.sh` | — | Clean |

### Open Item Outside This Phase's Blocking Scope

`.planning/WINDOWS.md` row 4 (open, phase 02): `scripts/lint.py` is 1279 lines, over the
project's global 300-line file-size guard hook. This is a **deliberate, documented** deviation
(single-file layout required for a bare-skills install to copy `scripts/` wholesale and run
`lint.py` by path — DIST-03), explicitly deferred to the Phase 7 manifests/distribution
conversation per the plan's own Q-6 decision. Not a gap against this phase's goal (mechanical
verification works correctly regardless of file length); listed here for visibility only, not
as a blocking finding.

### Human Verification Required

Three items, all inherited from `02-REVIEW-FIX.md`'s own "Decisions for Samuel" section, where
the executor itself marked the underlying fix `status: fixed: requires human verification`.
Behaviour is mechanically correct and covered by regression tests in every case — what needs a
human is a **policy/design judgement**, not a defect:

1. **D-FIX-8 — narrows locked decision D-22**
   **Test:** Review whether an unparseable/misindented line anywhere in `dossier.yaml`
   (including nested under `counterparts`) should hard-fail the lint run (`[C1]`, exit 1) as it
   now does, versus D-22's original "unknown or unparseable lines are skipped with a warning."
   **Expected:** Samuel confirms the narrower, fail-closed behaviour is the intended reading of
   D-22 for the confidentiality gate specifically, or requests a revert/refinement.
   **Why human:** Explicit deviation from a locked spec decision; a policy call the executor
   flagged rather than settled unilaterally.

2. **D-FIX-9 / D-FIX-10 — near-miss gate-key threshold and stricter plain-scalar rejection**
   **Test:** Review the `difflib` ratio-0.8 threshold for flagging a misspelt/misplaced gate
   key (`confidential_names` variants) as `[C1]`, and the new plain-scalar rejection rules
   (values containing `: `, or starting with `- `/`? `/`: `).
   **Expected:** Samuel agrees these thresholds avoid false positives on real dossiers, or asks
   for tuning.
   **Why human:** Explicitly flagged by the executor as "a judgement call" — not verifiable by
   inspecting code correctness alone.

3. **D-FIX-3 / WR-03 — E5 text-match broadened to ASCII-folded spellings**
   **Test:** Review the "match more" tradeoff: the confidential-name text check now also
   matches accent-dropped/punctuation-joined spellings in prose (e.g. `jane.doe` matches
   `Jane Doe`), with named false-positive risks (e.g. `Élan` matching the common word "elan").
   **Expected:** Samuel accepts broader matching as the safer default for a confidentiality
   linter, or asks to narrow the separator set.
   **Why human:** Explicitly flagged by the executor as settling an open design question "on
   the match more side" — a security/precision tradeoff, not a bug.

None of these three items block the phase goal ("mechanically verify... with zero setup beyond
python3") — the mechanism works, passes 1290 assertions, and each item is a request for Samuel
to bless (or adjust) a specific judgement call the executor made while closing the
confidentiality gate.

### Gaps Summary

No gaps found. All 4 ROADMAP success criteria for Phase 2, both carried-over Phase 1 debts, and
LINT-01/02/03 are verified directly against the codebase (not taken from SUMMARY.md claims):
clean scaffolds lint 0/0, all nine error classes fire correctly and only correctly, the French
fixture warns without erroring and still finds `Last updated:`, and the full bash+python3 suite
(6 files, 1290 lint-specific assertions) passes end to end when run fresh by this verifier.
Status is `human_needed` solely because three design judgements made during the review-fix
loop — all already self-flagged by the executor — deviate from or narrow prior locked
decisions and need Samuel's sign-off before the confidentiality-gate behaviour is considered
final.

---

_Verified: 2026-09-24T21:30:00Z_
_Verifier: Claude (gsd-verifier)_
