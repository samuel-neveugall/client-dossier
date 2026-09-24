---
phase: 02-linter-test-harness
plan: 03
subsystem: scaffold-producer
tags: [python3-stdlib, bash-tests, yaml-serialisation, init, debt]

# Dependency graph
requires:
  - phase: 02-linter-test-harness
    plan: 01
    provides: "scripts/lint.py per-field schema (D-24 points 1-2), the consumer half of the rule this plan completes"
provides:
  - "skills/dossier-init/scripts/init.py -- _YAML_RESERVED_SCALARS, and emit_scalar using fullmatch plus the reserved-spelling exclusion"
  - "tests/test-init-empty.sh -- cases d14 (--language no) and d15 (trailing newline), 111 assertions (was 107)"
affects: [02-06]

actuals:
  tokens: 1000
  tasks: 2
  commits: 2
plan_head_before: 3dfaebb81dce41c412d375fb6cc46715d4910b57

tech-stack:
  added: []
  patterns:
    - "Producer quoting is a serialisation rule only; the lint.py schema remains the single typing authority (D-24)"
    - "A bash payload that must end in a newline is built with a sentinel (printf 'en\\nx' then ${v%x}), because command substitution strips trailing newlines"

key-files:
  created: []
  modified:
    - skills/dossier-init/scripts/init.py
    - tests/test-init-empty.sh

key-decisions:
  - "02-03: the reserved-spelling check is on value.casefold(), so YES / No / TRUE are quoted too, not just the lower-case forms"
  - "02-03: the d15 trailing-newline payload uses a sentinel, because the plan's suggested printf inside command substitution strips the newline and would have made the case vacuous"

patterns-established:
  - "Producer regression cases state in their comment why they are red without the fix, and are observed red before the fix lands"

# LINT-01 and LINT-03 are advanced, not complete: E8, E9, W1, W2, the French fixture and the
# D-24.4 round-trip (02-06) are still ahead.
requirements-completed: []
requirements-advanced: [LINT-01, LINT-03]

coverage:
  - id: D1
    description: "Every YAML 1.1 reserved spelling fed to --language is written quoted (debt (a)); en, fr, es and required are written unquoted, byte-identical to the pre-change script"
    requirement: LINT-01
    verification:
      - kind: integration
        ref: "tests/test-init-empty.sh#d14; ad-hoc loop over y n yes no on off true false null YES No; cmp of en/fr dossier.yaml against HEAD~ init.py"
        status: pass
    human_judgment: false
  - id: D2
    description: "A --language value ending in a newline writes language: \"en\" directly followed by counterparts:, with no blank line (debt (b))"
    requirement: LINT-01
    verification:
      - kind: integration
        ref: "tests/test-init-empty.sh#d15"
        status: pass
    human_judgment: false
  - id: D3
    description: "No Phase 1 assertion was weakened: tests/run.sh and four Phase 1 test files keep their blob hashes, test-init-empty.sh only gained lines, and the full suite is green"
    requirement: LINT-03
    verification:
      - kind: integration
        ref: "git ls-files -s blob pin; git diff -U0 shows 0 removed lines; bash tests/run.sh TOTAL: 6 files, 0 failed"
        status: pass
    human_judgment: false

duration: 3min
completed: 2026-09-24
status: complete
---

# Phase 2 Plan 03: Producer Serialisation Rule (Phase 1 debts (a) and (b)) Summary

**`init.py` now quotes any value whose case-folded form is a YAML 1.1 reserved spelling, so `--language no` writes `language: "no"` instead of a value a strict parser reads as boolean false. It also matches the plain-scalar allowlist end to end with `fullmatch`, so a value ending in a newline is quoted and stripped instead of leaving a blank line. Non-reserved values are written exactly as before.**

## Performance

- **Duration:** about 3 min (2026-09-24T19:53Z to 19:56Z)
- **Tasks:** 2 of 2
- **Files:** 2 modified (+62 / -1 lines)

## Accomplishments

- **Debt (a) is closed.** `_YAML_RESERVED_SCALARS` is a frozenset of `y n yes no on off true false null ~`, placed just above `_SAFE_PLAIN_SCALAR_RE`. It has a comment in the file's existing style. `emit_scalar` writes a value bare only when it passes the allowlist and its casefold is not in that set; anything else goes through `yaml_quote()`. No new escaping code was written.
- **Debt (b) is closed.** `_SAFE_PLAIN_SCALAR_RE.match` became `.fullmatch`. `re.match(...$)` also matched just before a final `\n`.
- **Output is unchanged.** Scaffolds with `en` and `fr` give a `dossier.yaml` that `cmp` finds byte-identical to the pre-change script's output. `es` and `required` are still unquoted, `staleness_days: 7` is still a bare integer, and `consent_recorded: false` is still an unquoted boolean.
- **Scope held.** `emit_scalar` still has its two call sites in `render_dossier_yaml`, the docstring saying this script never parses YAML is still true, and `skills/dossier-init/SKILL.md` keeps blob `3e661e3`.
- **Tests.** `tests/test-init-empty.sh` has `PASS 111 FAIL 0`, and `bash tests/run.sh` prints `TOTAL: 6 files, 0 failed`.

## Task Commits

1. **Task 1: reserved spellings quoted, allowlist anchored.** `bd2ecd2` (fix)
2. **Task 2: producer regression cases d14 and d15.** `a178e88` (test)

## TDD Gate Compliance

- **RED:** d14 and d15 were appended first and run against the unmodified `init.py`. Result: `PASS 107 FAIL 4`, and all four failures were the new assertions. d14 found `language: no` bare; d15 found `language: en` followed by an empty line.
- **GREEN:** after the Task 1 change, `PASS 111 FAIL 0`.
- The plan orders the tasks fix-then-tests and the dispatch asks for one commit per task, so the RED state was observed but not committed separately. Task 1 was committed before Task 2.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug in the test recipe] The d15 payload uses a sentinel**
- **Found during:** Task 2
- **Issue:** The plan asks for the d15 payload to be built with `printf` inside command substitution. Command substitution strips trailing newlines, so `"$(printf 'en\n')"` gives plain `en`, and the case would have passed without testing debt (b).
- **Fix:** `lang15="$(printf 'en\nx')"; lang15="${lang15%x}"`, explained in the case's comment. The RED run confirmed the payload reaches `init.py` with the newline.
- **Files modified:** `tests/test-init-empty.sh`
- **Commit:** `a178e88`

### Judgement Calls Inside Claude's Discretion

- **`grep -c 'emit_scalar('` returns 5, not the 3 the acceptance line expects.** It was already 5 at `3dfaebb`, because two prose comments (l.201 and l.742) say `emit_scalar()`. The real count is one definition (l.227) plus two call sites (l.277 and l.298), which is what the criterion checks. I left the comments alone.
- **The d15 adjacency check** compares `grep -A1 '^language:'` against the two expected lines with `assert_eq`, as the plan asks. It does not grep for emptiness.
- **Commit trailer.** The plan's trailer says `Claude Opus 5 (1M context)`. I used the trailer the orchestrator supplied instead, as 02-01 and 02-02 did.

## Known Stubs

None.

## Threat Flags

None beyond the plan's threat model:

- **T-02-10:** closed by `fullmatch`.
- **T-02-11:** closed by `_YAML_RESERVED_SCALARS`.
- **T-02-12:** checked mechanically. The blob pin passed and `git diff -U0` shows 0 removed lines in `test-init-empty.sh`.

## Requirements Status

LINT-01 and LINT-03 are **advanced, not complete**. The D-24.4 round-trip, where `init.py` output is read back by `lint.py`'s parser as the string `"no"`, lands in 02-06. The remaining checks and the French fixture land in 02-04 and 02-05. REQUIREMENTS.md keeps both as Pending.

## Phase 1 Debts

STATE.md "Deferred Items" rows (a) and (b) are now marked resolved by 02-03 (`bd2ecd2`).

## Self-Check: PASSED

- FOUND: skills/dossier-init/scripts/init.py (`_YAML_RESERVED_SCALARS` count 2, `fullmatch` present, `_SAFE_PLAIN_SCALAR_RE.match(` count 0)
- FOUND: tests/test-init-empty.sh (d14, d15, `language: "no"`)
- FOUND: commit bd2ecd2
- FOUND: commit a178e88
- `bash tests/run.sh`: TOTAL: 6 files, 0 failed
