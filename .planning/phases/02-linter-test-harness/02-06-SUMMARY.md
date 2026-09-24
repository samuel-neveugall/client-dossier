---
phase: 02-linter-test-harness
plan: 06
subsystem: linter
tags: [bash-tests, lint, acceptance, round-trip, docs, windows-ledger]
status: complete

# Dependency graph
requires:
  - phase: 02-linter-test-harness
    plan: 03
    provides: "init.py quotes YAML 1.1 reserved spellings (language: \"no\") -- the producer side of Phase 1 debt (a)"
  - phase: 02-linter-test-harness
    plan: 05
    provides: "lint.py with W1/W2, LANGUAGE_WORDS, language_infos (the `info: language '<code>' has no word list` line); tests/test-lint.sh helpers assert_clean, assert_last_line, count_out_lines"
provides:
  - "tests/test-lint.sh -- scaffold_lints_clean LABEL [INIT_ARG...]: ROADMAP criterion 1 as three committed zero-findings cases (default en, default fr, every optional init.py flag)"
  - "tests/test-lint.sh -- the init.py -> lint.py round trip on --language no (quoted on write, read back as the string 'no', dossier clean) with the unreserved unknown code 'it' as negative control"
  - "CLAUDE.md -- a Commands section: python3 scripts/lint.py [PATH] with exit codes 0/1/2/3 and read-only/no-other-flag note, bash tests/run.sh, bash tests/test-lint.sh"
  - ".planning/WINDOWS.md -- row 4: scripts/lint.py file-size deviation (1279 lines, single file on purpose, Phase 7 split conversation)"
affects: [03-protocol-skill-hooks, 07-manifests-distribution]

actuals:
  tokens: 1841
  tasks: 3
  commits: 3
plan_head_before: 289138451b6d77811d9f79d8090956abad04f05e

tech-stack:
  added: []
  patterns:
    - "A zero-findings acceptance asserts three independent things -- exit code, summary as last line, absence of every identifier -- because each alone can be fooled"
    - "A round-trip test pairs the reserved-spelling case with an unreserved unknown-language control, so it isolates the path under test rather than the generic one"

key-files:
  created: []
  modified:
    - tests/test-lint.sh
    - CLAUDE.md
    - .planning/WINDOWS.md

key-decisions:
  - "The round-trip assertion matches the informational line on `^info: language 'no' ` rather than a bare `no`: the line always contains the word `no` (`has no word list`), so the plan's looser grep could not have turned red on a coercion"
  - "CLAUDE.md keeps the two pre-existing commands (claude plugin validate, claude --plugin-dir) inside the new Commands section, and documents all four lint exit codes (0/1/2/3), not three: lint.py has an internal-error exit 3 (P-08)"
  - "LINT-01..03 marked complete: ROADMAP Phase 2 criteria 1-4 are each a committed, passing assertion after this plan"

requirements-completed: [LINT-01, LINT-02, LINT-03]

# Metrics
duration: 8min
completed: 2026-09-24
---

# Phase 2 Plan 06: Zero-findings acceptance, round trip, commands Summary

**ROADMAP criterion 1 is now a committed assertion: a dossier scaffolded by `init.py` lints `0 error(s), 0 warning(s)` with no identifier in en, fr and fully configured; the `--language no` round trip is proven end to end; CLAUDE.md records the linter and suite commands.**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-09-24T20:08Z (approx.)
- **Completed:** 2026-09-24T20:16Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments

- `scaffold_lints_clean` in `tests/test-lint.sh`: scaffold a scratch repo, lint, assert exit 0, last line `0 error(s), 0 warning(s)`, all thirteen identifiers absent (both per identifier and with one `\[(E[1-9]|W[12]|C[01])\]` count), then tear the repo down. Three cases: default `en`, default `fr` (the P-04 `fichier`/`hier` catcher), and every optional flag (two counterparts with role and contacts, `--confidential-name`, `--consent-recorded true` with `--consent-source`, `--timestamps '@hh:mm:ss'`, `--staleness-days 14`). A mutation probe (`--consent-recorded true` with no source) turned the helper red on four assertions.
- Round trip on the YAML reserved spelling: `dossier.yaml` holds `language: "no"`, lint exits 0, exactly one `info: language 'no' ` line, no `True/False/true/false` on any `info:` line, dossier clean. Control: `--language it` writes `language: it` bare and takes the same info path. Phase 1 debt (a) is now closed on both sides by one committed test.
- `CLAUDE.md` Commands section (in "Implementation order and testing"), `.planning/WINDOWS.md` row 4 recorded through `gsd-tools windows append`. Front-matter counts moved together: open 2→3, total 3→4.
- `bash tests/test-lint.sh`: PASS 763 FAIL 0 (up from 726 after Task 1 and 675 before this plan). `bash tests/run.sh`: `TOTAL: 6 files, 0 failed`.

## Task Commits

1. **Task 1: zero-findings acceptance in en, fr and fully configured** - `40d598e` (test)
2. **Task 2: init.py -> lint.py round trip on `no`** - `42999df` (test)
3. **Task 3: Commands section and file-size window** - `87c5f26` (docs)

## Files Created/Modified

- `tests/test-lint.sh` - the three zero-findings cases and the round-trip block, inserted before the no-dossier section
- `CLAUDE.md` - the Commands section replaces the one-line "Commands that exist today" paragraph
- `.planning/WINDOWS.md` - row 4, the `scripts/lint.py` deviation

## Decisions Made

See `key-decisions` in the frontmatter.

## Deviations from Plan

### Plan text vs repository state (no code impact)

**1. Ledger counts: `total_count: 4`, not 3**
- **Found during:** Task 3
- **Issue:** The acceptance check expects `total_count: 3` after the new row. The plan was written before 02-01 added row 3 (a phase-02 deviation, since marked fixed), so the ledger already had 3 rows.
- **Result:** `open_count: 3` as expected; `total_count: 4` is correct for four rows. The ledger command maintained both counts.

**2. The CLAUDE.md placeholder sentence had already changed**
- **Found during:** Task 3
- **Issue:** The plan targets "No build, lint or test commands exist yet". The file actually said "Commands that exist today: `bash tests/run.sh` ..., `claude plugin validate . --strict` ..., `claude --plugin-dir .` .... Add more here as they are created." (updated in Phase 1).
- **Fix:** Replaced that paragraph with the Commands section. The two pre-existing commands are kept so no record is lost, and the "Add more here" line is kept too. The grep for the old sentence stays at 0.

**3. [Rule 1 - Bug] The round-trip grep was tightened**
- **Found during:** Task 2
- **Issue:** The plan's verify command `grep '^info:' | grep -q "no"` always passes because the info line contains "has **no** word list".
- **Fix:** The test matches `^info: language 'no' ` (exactly one line) and `^info: language 'it' ` for the control.
- **Commit:** `42999df`

**4. Commit trailer**
- The plan names `Claude Opus 5 (1M context)`. Commits use the orchestrator/session attribution instead (`Claude Opus 5.5` plus `Claude-Session`), as instructed for this run.

---

**Total deviations:** 1 auto-fixed (Rule 1, test precision), 3 plan-text drifts.
**Impact on plan:** None on scope. All must-haves hold.

## Issues Encountered

None.

## Known Stubs

None.

## Threat Flags

None. No new surface. T-02-19 is mitigated by the round-trip test, T-02-20 by the "read-only, no other flag in v1" line and T-02-21 by ledger row 4.

## Next Phase Readiness

- Phase 2 is complete: criteria 1-4 are committed, passing assertions, and LINT-01..03 are satisfied.
- Open ledger rows 1, 2 and 4 all point at Phase 7 (manifest validation, and the file-size decision for `init.py` and `lint.py`).
- Phase 3 open point (Stop hook in v1) is still to be settled with Samuel.

## Self-Check: PASSED

- FOUND: tests/test-lint.sh, CLAUDE.md, .planning/WINDOWS.md
- FOUND commits: 40d598e, 42999df, 87c5f26
