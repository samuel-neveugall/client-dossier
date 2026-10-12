---
phase: 03-protocol-skill-hooks
plan: 06
subsystem: closure
tags: [green-run, docs, validation]
requirements-completed: [PROTO-01, PROTO-02, PROTO-03, PROTO-04, PROTO-05, PROTO-06, PROTO-07, PROTO-08]
actuals:
  tasks: 3
  commits: 3
completed: 2026-10-10
---

# Phase 3 Plan 06: GREEN run, documentation, validation contract

**With the plugin loaded through --plugin-dir, 3 of 3 runs left the transcript byte-identical, loaded the dossier skill and filed a dated, sourced correction in dossier/HISTORY.md (first round, no skill refinement needed).**

## GREEN run (commit c3bc50f)

Model claude-sonnet-5-5, claude_code_version 2.1.296, same harness, fixture and pressured prompt (D-15) as the baseline.

| Run | Verdict | skill_loaded | filed lines | lint_exit | cost USD |
|-----|---------|--------------|-------------|-----------|----------|
| plugin-1 | GREEN | yes | 1 | 0 | 0.0649998 |
| plugin-2 | GREEN | yes | 1 | 0 | 0.0644742 |
| plugin-3 | GREEN | yes | 1 | 0 | 0.0714711 |

Total about 0.2009 USD. Each filed line (from the diffs) quotes "reprot", gives "report" and cites `call 2026-10-01 @00:12`.
D-12 held (client-dossier:dossier in system/init skills, harness exit 0).

| Variant | RED | GREEN | INCOMPLETE | Source edited |
|---------|-----|-------|------------|---------------|
| baseline (no plugin, no AGENTS.md) | 3 | 0 | 0 | 3 of 3 |
| pointer-only (informational) | 0 | 0 | 3 | 0 of 3 |
| plugin | 0 | 3 | 0 | 0 of 3 |

No refinement round. Evidence: evidence/red-baseline/ (13 files), evidence/green-plugin/ (7 files), scrub_check exit 0.

## Observed validate output (2026-10-10, Claude Code 2.1.296)

`claude plugin validate .`: exit 0, two warnings: plugin.json "author: No author information provided"; root
"CLAUDE.md at the plugin root is not loaded as project context". `--strict`: exit 1 on those same two warnings.
CLAUDE.md and plugin.json untouched (Phase 7).

## Docs (commit 567758b)

CLAUDE.md: Stop hook blocks once, Decisions settled 2026-10-10, new test and scenario commands, validate command.
STATE.md: blockers resolved, counters set by hand (21 of 21 plans, Phase 3 awaiting verification), 6 KB.

## Validation

`bash tests/run.sh`: TOTAL: 11 files, 0 failed. `bash tests/scenarios/selftest.sh`: PASS 65 FAIL 0. 03-VALIDATION.md finalized
(all rows green, nyquist_compliant and wave_0_complete true). P-01 and P-02 stay provisional.

## Self-Check: PASSED
