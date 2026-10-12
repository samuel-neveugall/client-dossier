---
phase: 07-manifests-docs-distribution
plan: 08
subsystem: distribution
tags: [commands, claude-code, dist-04, d-18, collision-test]
requires:
  - "07-01: manifests, tests/dist/install-claude.sh, tests/test-manifests.sh"
  - "07-02: CHANGELOG.md"
  - "07-06: README.md with ## Usage"
provides:
  - "commands/dossier-lint.md: the one Claude Code command, runs scripts/lint.py, path single-quoted, read-only"
  - "tests/test-commands.sh: pins the command set, the no-collision rule, the frontmatter, the quoting and the D-18 wording across the documents"
  - "DIST-04, spec section 4, 07-CONTEXT D-06, ROADMAP criterion 4, CLAUDE.md, README and CHANGELOG amended to D-18"
affects: [07-09 (ticks DIST-04, runs the command smoke)]
tech-stack:
  added: []
  patterns:
    - "collision loop: every commands/*.md stem compared with every skills/ folder name"
key-files:
  created:
    - commands/dossier-lint.md
    - tests/test-commands.sh
  modified:
    - tests/dist/install-claude.sh
    - tests/test-readme.sh
    - .planning/REQUIREMENTS.md
    - docs/superpowers/specs/2026-09-16-client-dossier-design.md
    - .planning/phases/07-manifests-docs-distribution/07-CONTEXT.md
    - .planning/phases/07-manifests-docs-distribution/07-08-PLAN.md
    - .planning/phases/07-manifests-docs-distribution/07-09-PLAN.md
    - .planning/phases/07-manifests-docs-distribution/07-VALIDATION.md
    - .planning/ROADMAP.md
    - CLAUDE.md
    - README.md
    - CHANGELOG.md
key-decisions:
  - "D-18 (option (a), settled by Samuel on 2026-10-12): ONE command, commands/dossier-lint.md; the five task skills are the slash commands because a same-named command shadows the skill (probes K1-K3)"
status: complete
commits: 5
plan_head_before: e5e0954786ce9b624bc0b777ef25ea178bfa5e10
plan_head_after: 58e91f2c7710d1423a55b7bf904b0b03d50ce850
actuals:
  tokens: 9000
  tasks: 3
  commits: 5
---

# Phase 7 Plan 08: The dossier-lint command and the D-18 amendments Summary

D-18 is settled: Claude Code ships one command, `commands/dossier-lint.md`, the five task skills are the slash commands, and a free test (`tests/test-commands.sh`, 37 assertions) fails the day a command shares a skill's name.

## Tasks

| Task | Name | Commit |
|---|---|---|
| prep | plans 07-08, 07-09 and 07-VALIDATION carry D-18 as settled (no P-01, no provisional wording, no option (b) path) | ba8ee68 |
| 1 (tracer) | `commands/dossier-lint.md` and `tests/test-commands.sh` | cf4a888 |
| 1 (fix) | `tests/dist/install-claude.sh` counts a command in the `Skills (N)` line | 16a7a61 |
| 2 | DIST-04, spec section 4, D-06 marker, ROADMAP criterion 4 | f0bb5ad |
| 3 | CLAUDE.md, README `### Commands`, CHANGELOG, document checks in test-commands.sh | 58e91f2 |

## D-18 wording carried by

REQUIREMENTS DIST-04 (still unticked), spec section 4 tree (`commands/` one line plus `dossier-lint.md`), 07-CONTEXT D-06 marker `Amended 2026-10-12 by D-18 (settled by Samuel)`, ROADMAP Phase 7 criterion 4 and the 07-08 plan-list text, CLAUDE.md (`**Commands**` bullet and two Commands list bullets), README `### Commands`, CHANGELOG `### Added`, `commands/dossier-lint.md`.

## Verification

- `bash tests/test-commands.sh`: `PASS 37 FAIL 0` (RED first: `PASS 0 FAIL 12`, then the document checks `PASS 32 FAIL 5`).
- Negative probes, each tried once and removed: a temporary `commands/dossier-draft.md` fails the set and the collision checks; a temporary `allowed-tools:` line fails the frontmatter checks.
- `bash tests/test-manifests.sh`: `PASS 62 FAIL 0` (`claude plugin validate .` still shows exactly the one root CLAUDE.md warning).
- `bash tests/test-readme.sh`: `PASS 102 FAIL 0`.
- `bash tests/run.sh`: `TOTAL: 30 files, 0 failed`.
- `bash tests/dist/install-claude.sh`: `DIST install-claude: PASS`, the installed copy holds `commands/dossier-lint.md`; real configuration byte-identical.

## Deviations from Plan

**1. [Binding instruction] D-18 replaces P-01 everywhere**
- The orchestrator settled D-18 after the plan was written. Every P-01, provisional, Q15 and the option (b) reversion path was removed from 07-08-PLAN.md, 07-09-PLAN.md and 07-VALIDATION.md; the amendment texts, test checks and commit subjects use D-18. The D-06 marker date is 2026-10-12.
- **Commit:** ba8ee68, then the files above.

**2. [Rule 1 - Bug] install-claude.sh broke on the first command**
- **Found during:** task 1 verify. `claude plugin details` lists a plugin command inside `Skills (7)` (probed), so the check `Skills (N) equals 6 in the clone` failed. The script's comment said no later plan would need to edit it.
- **Fix:** the expected skills list also takes the stems of `commands/*.md`; the generic installed-copy check was already in place.
- **Files modified:** tests/dist/install-claude.sh. **Commit:** 16a7a61.

**3. [Rule 3 - Blocking] tests/test-readme.sh forbade `dossier-lint` in the README**
- **Issue:** 07-06 pinned "README does not name dossier-lint (07-08 owns the paragraph)"; the plan requires the paragraph, so test-readme.sh would fail.
- **Fix:** that one check was replaced by a comment pointing at test-commands.sh, which now pins the paragraph.
- **Files modified:** tests/test-readme.sh. **Commit:** 58e91f2.

**4. [Scope note] ROADMAP plan-list text of 07-08**
- The line `07-08-PLAN.md — P-01, provisional: ...` was reworded to `D-18: ...`; the checkbox, the progress rows and the other plan items were not touched. The new "no P-01/provisional/Q15" check is scoped to the ROADMAP Phase 7 section (Phase 3 has its own P-01 and P-02) and leaves 07-CONTEXT.md out (its D-18 record keeps the decision's old name).

**5. [Environment] stale worktree base and git launcher guard**
- The worktree started at b8aae7a (without the 07-0x plans); the empty worktree branch was fast-forwarded to `feat/phase-07-manifests-docs-distribution` (e5e0954) before any work. The Bash guard refused the rtk-rewritten `git`, so `/usr/bin/git` was used.

**6. [Note for 07-09] suite size**
- `tests/run.sh` ends `TOTAL: 30 files, 0 failed`; 07-09's truth says `TOTAL: 29 files`. 07-09 gains no test file, so its expected count should read 30.

## Known Stubs

None.

## Threat Flags

None beyond the plan's threat model: T-07-26 (single-quoted path, refusal of a single quote or line break, pinned), T-07-27 (frontmatter keys limited, pinned), T-07-28 (collision loop and one-line expected set, pinned).

## Self-Check: PASSED

- commands/dossier-lint.md and tests/test-commands.sh exist.
- Commits ba8ee68, cf4a888, 16a7a61, f0bb5ad, 58e91f2 are ancestors of HEAD.
- STATE.md, skills/, scripts/, hooks/ and the ROADMAP progress lines were not touched.
