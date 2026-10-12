---
phase: 02-linter-test-harness
plan: 07
subsystem: testing
tags: [linter, python-stdlib, difflib, yaml-subset, json, mutation-testing]

# Dependency graph
requires:
  - phase: 02-linter-test-harness
    provides: "scripts/lint.py's confidentiality gate (GATE_KEYS, gate_key_for, _misplaced_gate_keys), tests/fixtures/make-lint-fixtures.sh, tests/test-lint.sh"
provides:
  - "presence-aware near-miss rule in _misplaced_gate_keys: a fold-equal key is always C1, a difflib-only near-miss is C1 only while the exact gate key it resembles is absent from the top level"
  - "reworded C1 message ('looks like a misspelling of X') that no longer invites a gate-weakening rename"
  - "gate-key-extras / gate-key-extras-leak fixtures proving legitimate extension keys (consent_scope, confidential_notes, ...) lint clean beside the exact gate keys"
  - "gate-nested-typo fixture proving a nested difflib-only near-miss still fails closed while the exact key is absent"
  - "gate-key-beside-consent and gate-json-deep fixtures pinning the two WR-02 gate lines (gate_damaged wiring, nested recursion) with a hand-run mutation kill"
affects: [linter, confidentiality-gate, dossier-init]

# Actuals (#2632)
actuals:
  tokens: 3583
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "presence-aware near-miss rule: a difflib match is reported only while the exact key it resembles is absent from the top-level config, so a legitimate extension key never collides with a misspelling"

key-files:
  created: []
  modified:
    - scripts/lint.py
    - tests/fixtures/make-lint-fixtures.sh
    - tests/test-lint.sh

key-decisions:
  - "D-GAP-1 (reversible): the presence rule applies at every depth -- a nested fold-equal key stays C1 unconditionally; a nested difflib-only near-miss is C1 only while the gate key it resembles is absent from the top level, same as a top-level key"
  - "GATE_KEY_CUTOFF stays 0.8; gate_key_for()'s contract for _skipped_key() is unchanged (D-FIX-8)"

patterns-established:
  - "Certain vs. near-miss split: _certain_gate_key_for() (fold-equal only) is unconditional; gate_key_for() (fold-equal or difflib) is gated on presence at the top level, applied uniformly at every nesting depth"

requirements-completed: [LINT-01, LINT-02, LINT-03]

coverage:
  - id: D1
    description: "A dossier.yaml holding the three exact gate keys plus nine extension keys that only resemble them (consent_scope, consent_sources, consent_required, consent_revoked, consent_recorded_at, confidential, confidential_notes at top level and nested under a counterpart, non_confidential_names) lints 0 error(s), 0 warning(s); the same config with a leak reports only [E5]"
    requirement: LINT-01
    verification:
      - kind: unit
        ref: "tests/test-lint.sh: gate-key-extras / gate-key-extras-leak"
        status: pass
    human_judgment: false
  - id: D2
    description: "A key equal to a gate key after _fold_key (case, hyphen, space) is ERROR [C1] even beside the exact key, at top level and nested; a key that only difflib-resembles a gate key is ERROR [C1] only while the exact key is absent, and ignored once present, at every depth"
    requirement: LINT-01
    verification:
      - kind: unit
        ref: "tests/test-lint.sh: gate-key-dash, gate-key-case, gate-key-typo, gate-json-key-case (wording), gate-nested-typo (nested near-miss, gate key absent)"
        status: pass
    human_judgment: false
  - id: D3
    description: "The C1 message for a misspelt top-level gate key reads 'looks like a misspelling of X' and no longer tells the user to rename the key to the gate key"
    requirement: LINT-01
    verification:
      - kind: unit
        ref: "tests/test-lint.sh: gate-key-dash/-case/-typo, gate-json-key-case wording assertions; grep -c 'write the key exactly' scripts/lint.py == 0"
        status: pass
    human_judgment: false
  - id: D4
    description: "The two WR-02 mutations (gate_damaged forced False; visit() recursion dropped below the first nesting level) are killed by committed assertions"
    requirement: LINT-03
    verification:
      - kind: other
        ref: "hand-run mutation check against scratch copies of scripts/lint.py (never committed); see Mutation Check table below and commit 91581ea's message"
        status: pass
    human_judgment: false
  - id: D5
    description: "bash tests/run.sh stays green; fresh en and fr scaffolds still lint 0 error(s), 0 warning(s)"
    requirement: LINT-02
    verification:
      - kind: integration
        ref: "bash tests/run.sh"
        status: pass
    human_judgment: false

duration: ~13min
completed: 2026-09-25
status: complete
---

# Phase 02 Plan 07: Confidentiality gate near-miss precision Summary

**A difflib near-miss on a `dossier.yaml` gate key (`confidential_names`, `consent_recorded`, `consent_source`) is C1 only while the exact key it resembles is absent, at any nesting depth; a fold-equal variant (case/hyphen/space) is always C1; the message now reads "looks like a misspelling of X" instead of inviting a gate-weakening rename.**

## Performance

- **Duration:** ~13 min (base commit 34f3214 to final task commit 91581ea; exact session-start timestamp was not separately recorded)
- **Tasks:** 2/2 completed
- **Files modified:** 3 (`scripts/lint.py`, `tests/fixtures/make-lint-fixtures.sh`, `tests/test-lint.sh`)

## Accomplishments

- Closed G-02-2: legitimate extension keys (`consent_scope`, `confidential_notes`, and the rest of WR-01's measured near-miss mappings) beside the exact gate keys no longer fail the linter run, at top level and nested under a counterpart.
- Kept the gate strict on certain misspellings: a case/hyphen/space variant of a gate key (`Confidential_names`, `confidential-names`) is still `ERROR [C1]` unconditionally, at any depth.
- A difflib-only near-miss (`confidental_names`) is still `ERROR [C1]` while the exact gate key it resembles is genuinely absent — the presence rule, not a blanket allowlist.
- Reworded the C1 message from "write the key exactly" (which could turn an unrelated note into `consent_source` and silently disable the leak check) to "looks like a misspelling of X", naming no rename target.
- Closed G-02-4d: pinned the two gate lines WR-02 found untested (`gate_damaged` wiring into E5, and `visit()`'s recursion below the first nesting level) with dedicated fixtures and a hand-run mutation kill.

## Task Commits

Each task was committed atomically:

1. **Task 1: End to end — extension keys ignored, certain misspellings still fail closed (G-02-2)** - `b224542` (fix)
2. **Task 2: Pin the two gate lines no test covered (G-02-4d)** - `91581ea` (test)

_No separate plan-metadata commit: per the objective, STATE.md/ROADMAP.md are not touched by this worktree-isolated executor; the orchestrator applies those after this plan returns._

## Files Created/Modified

- `scripts/lint.py` - Added `_certain_gate_key_for()` (fold-equal only, unconditional); rewrote `_misplaced_gate_keys()` to apply a uniform presence rule (certain → always C1; near-miss → C1 only while the exact key is absent from the top level of `raw`) at every nesting depth via `visit()`; reworded both top-level and nested-near-miss C1 messages to "looks like a misspelling of X"; updated the `GATE_KEY_CUTOFF` comment and `gate_key_for()`'s docstring to state the presence rule and cite D-22/D-GAP-1/the 2026-09-25 UAT decision. `GATE_KEY_CUTOFF` (0.8) and `GATE_KEYS` unchanged; the parser, JSON branch, `apply_schema`'s field reading and `consent_is_recorded` untouched.
- `tests/fixtures/make-lint-fixtures.sh` - Added `gate-key-extras` / `gate-key-extras-leak` (extension keys beside the exact gate keys, at top level and nested under a counterpart; the leak twin proves only `[E5]` fires), `gate-nested-typo` (JSON nested near-miss, exact key absent, still C1), `gate-key-beside-consent` (certain misspelling beside a recorded, sourced consent; pins WR-02's `gate_damaged` wiring), `gate-json-deep` (a gate key two levels below the top, a depth the YAML subset cannot express; pins WR-02's recursion).
- `tests/test-lint.sh` - Added assertions for all four new fixtures above, plus a wording assertion loop (`gate-key-dash`, `gate-key-case`, `gate-key-typo`, `gate-json-key-case`) asserting the new "looks like a misspelling of confidential_names" message.

## Decisions Made

- **D-GAP-1 (reversible, taken by the plan and applied as written):** the presence rule applies at every depth. A nested key that is `_fold_key`-equal to a gate key stays C1 unconditionally (a misplaced gate key, as before this plan). A nested key that is only a difflib near-miss is C1 only while the gate key it resembles is absent from the top level, and ignored otherwise — the same rule as a top-level key, so a counterpart-level `confidential_notes` beside a top-level `confidential_names` is silent.
- Kept `GATE_KEY_CUTOFF = 0.8` and `gate_key_for()`'s existing contract for `_skipped_key()` unchanged (D-FIX-8): that function only words the message of a line that is already C1 through the unreadable-line path, independent of this plan's presence rule.
- Split the single `gate_key_for()` lookup into two: `gate_key_for()` (fold-equal or difflib, unchanged signature, still used by `_skipped_key()`) and the new `_certain_gate_key_for()` (fold-equal only), so `_misplaced_gate_keys()` can apply "certain is unconditional, near-miss is presence-gated" without re-deriving the fold check inline.

## Deviations from Plan

None — plan executed exactly as written. `_misplaced_gate_keys()` was rewritten per the plan's spelled-out rule (certain reported unconditionally at any depth; near-miss reported only while the exact gate key is absent from `raw`'s top level); messages worded per the plan's exact phrasing ("looks like a misspelling of" at top level for both kinds; nested-certain keeps the pre-existing "is written under X: read only at the top level" wording; nested-near-miss gets the new wording naming where it sits). No new identifier was added (D-05); `GATE_KEY_CUTOFF` and `GATE_KEYS` are untouched.

One process note worth recording: my first draft of the four wording assertions (`gate-key-dash`/`-case`/`-typo`, `gate-json-key-case`) reused `LINT_OUT` from the tail end of the preceding `for` loop instead of calling `assert_lint` per case first, so the assertions silently checked the wrong fixture's output. Caught immediately by the baseline-RED run (it should have failed 8 ways and only failed 4), fixed before the code change, and confirmed against the real fixtures afterward — not a deviation from the plan's design, just a self-caught test-authoring bug during the same task.

## Baseline RED (before the code change, Task 1)

Running `bash tests/test-lint.sh` against the fixtures/assertions with `scripts/lint.py` still unmodified: **8 assertions failed** — the 4 new wording assertions (`gate-key-dash`, `gate-key-case`, `gate-key-typo`, `gate-json-key-case`, each expecting "looks like a misspelling of confidential_names") plus 3 for `gate-key-extras` (wrong exit code, non-clean summary, unexpected `[C1]`) and 1 for `gate-key-extras-leak` (unexpected `[C1]` alongside `[E5]`). After the `scripts/lint.py` rewrite: `PASS 1330 FAIL 0`.

## Mutation Check (Task 2, G-02-4d / WR-02)

Done by hand against scratch copies of `scripts/lint.py`, never committed (confirmed via `git status --porcelain scripts/` after cleanup):

| Mutation | Target | Case | Real `lint.py` | Mutant | Verdict |
|---|---|---|---|---|---|
| M1 | `apply_schema`: `config["gate_damaged"]` set to `False` after `_misplaced_gate_keys()` still runs and reports | `gate-key-beside-consent` | `[C1]` + `[E5]`, exit 1 | `[C1]` only, `[E5]` gone, exit 1 | **Killed** — `assert_finding E5` fails against the mutant |
| M2 | `_misplaced_gate_keys`: `visit()`'s recursive call into a dict's values removed | `gate-json-deep` | `[C1]` naming `confidential_names`, exit 1 | no finding at all, `0 error(s), 0 warning(s)`, exit 0 | **Killed** — `assert_out_line`/`assert_lint` fail against the mutant |

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- G-02-2 and G-02-4d are closed. The confidentiality gate's config side (`_misplaced_gate_keys`) is now presence-aware and both previously-untested `gate_damaged` lines are pinned.
- Remaining Phase 2 gaps from the 2026-09-25 UAT (G-02-4a case-insensitive `Outbound/`, G-02-4b Unicode format characters, G-02-4c HTML entities, G-02-4e unreadable/`.git` folders under `outbound/`, G-02-4f quoted-reply wrapping) are out of this plan's scope (files_modified: `scripts/lint.py`, `tests/fixtures/make-lint-fixtures.sh`, `tests/test-lint.sh` only for the near-miss rule) and are addressed by sibling gap-closure plans 02-08/02-09.
- `bash tests/run.sh`: `TOTAL: 6 files, 0 failed`.

## Self-Check: PASSED

- FOUND: `scripts/lint.py`, `tests/fixtures/make-lint-fixtures.sh`, `tests/test-lint.sh`
- FOUND commits: `b224542` (Task 1), `91581ea` (Task 2), `f116a8d` (this SUMMARY)
- `git status --short` after the SUMMARY commit: clean (no leftover mutant files, no uncommitted changes)

---
*Phase: 02-linter-test-harness*
*Completed: 2026-09-25*
