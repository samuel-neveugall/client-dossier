---
phase: 07-manifests-docs-distribution
plan: 06
subsystem: docs
tags: [readme, distribution, documentation, limits, versioning]
requires:
  - "07-01: manifests and marketplace listings, tests/dist/install-claude.sh"
  - "07-02: LICENSE, CHANGELOG.md, scripts/release.sh"
  - "07-03: apply_patch branch of the sources guard, DIST-03 checks"
  - "07-05: Codex and bare-skills install checks, skills@1.7.0 gate"
provides:
  - "README.md: install for Claude Code, Codex, Agent Skills harnesses, AGENTS.md only; usage; documented guard and confidential-name limits; requirements; versioning; licence; privacy"
  - "tests/test-readme.sh: free pins of the README, LICENSE, CHANGELOG and the permanent version coherence rule"
affects: [07-08 (appends ### Commands after Usage), 07-09]
tech-stack:
  added: []
  patterns:
    - "grep -F helpers (has_fixed, has_fixed_i) so strings with regex characters are literal"
key-files:
  created:
    - README.md
    - tests/test-readme.sh
  modified: []
key-decisions:
  - "skills CLI pin written as skills@1.7.0 everywhere (the version tested in 07-05), and the test fails if skills@1.7.2 appears"
  - "Privacy states the one real network access (dossier-ingest downloads a link the user asks it to file) instead of claiming no network at all"
  - "The apply_patch guard is described as checked against its input contract, not on a live Codex run (07-03 coverage limit)"
status: complete
commits: 2
plan_head_before: b838f26
plan_head_after: 5d823633d3d3b394419b0785ad382464fb7efd76
actuals:
  tokens: 4600
  tasks: 2
  commits: 2
---

# Phase 7 Plan 06: README and its test Summary

An English README documents installation on the four targets, what a bare-skills install loses, where the sources guard and the confidential-name check stop, versioning, licence and privacy; `tests/test-readme.sh` pins it (103 assertions) together with LICENSE, CHANGELOG and the version coherence rule.

## Tasks

| Task | Name | Commit |
|---|---|---|
| 1 (tracer) | README items 1 to 4 (what it is, layout, installation) and the test | 71bd85a |
| 2 | Usage, limits, requirements, versioning, licence, privacy | 5d82363 |

## README outline as written

`# client-dossier` / `## What it is` / `## The dossier layout` / `## Installation` (`### Claude Code`, `### Codex`, `### Agent Skills harnesses (Cursor, Copilot CLI, Gemini CLI, OpenCode)` with the paragraph "What this install loses", `### Without a plugin (AGENTS.md only)`) / `## Usage` (ends with its last paragraph, no `### Commands`, left for 07-08) / `## Limits` (`### The sources guard`, `### Confidential names`) / `## Requirements` / `## Versioning` / `## License` / `## Privacy`. Sixteen headings, each a whole line pinned by the test.

## Test result

`bash tests/test-readme.sh`: `PASS 103 FAIL 0` (minimum 60). `bash tests/run.sh`: `TOTAL: 28 files, 0 failed`, exit 0.

TDD: task 1 test run before the README existed gave `PASS 12 FAIL 42` (RED), then `PASS 54 FAIL 0`; task 2 checks added gave `PASS 62 FAIL 41` (RED), then `PASS 103 FAIL 0`.

## Facts checked against the repository

- Install commands match the isolated checks: `tests/dist/install-claude.sh` (`claude plugin marketplace add`, `claude plugin install client-dossier@client-dossier`), `tests/dist/install-codex.sh` (`codex plugin marketplace add`, `codex plugin add`), `tests/dist/install-skills.sh` (`skills@1.7.0`, `skills add`).
- `scripts/release.sh`: bumps both manifests (and marketplace entries carrying a version), inserts the changelog heading, commits, creates the local annotated tag, never contacts a remote.
- `scripts/lint.py` exit codes 0, 1, 2, 3 and "read-only, no repair mode" as in CLAUDE.md.
- Guard denial list and unseen classes taken from 03 D-04, 03 D-17 and the STATE accepted-debt rows; confidential-name limits from 05 D-09.
- `dossier-init` writes the pointer into `AGENTS.md` always and into `CLAUDE.md` only when it exists (skill step 6 / template `AGENTS-pointer.md`); the README says exactly that.
- No `commands/dossier-*.md` and no mention of `dossier-lint` in the README.

## Deviations from Plan

**1. [Binding instruction] skills@1.7.0 instead of skills@1.7.2**
- **Issue:** the plan text and the T-07-20 mitigation name `skills@1.7.2`; the version actually gated and tested in 07-05 is `skills@1.7.0` (1.7.2 was under 14 days old).
- **Fix:** README and `tests/test-readme.sh` use `skills@1.7.0`; the test also asserts `skills@1.7.2` is absent. Evidence file is `evidence/dist/skills-1.7.0-registry.txt`.
- **Commit:** 71bd85a

**2. [Rule 1 - accuracy] privacy wording**
- **Issue:** a flat "no network" claim would be false: `dossier-ingest` downloads a link the user gives it (`file_source.py fetch`).
- **Fix:** the Privacy section keeps the pinned phrase "never sends anything" and states that download as the only network access.
- **Commit:** 5d82363

**3. [Rule 1 - accuracy] apply_patch wording**
- **Issue:** 07-03 records the Codex `apply_patch` behaviour as documentation-backed, not exercised on a live Codex.
- **Fix:** the Codex subsection says it is checked against the guard's input contract, not on a live Codex run.
- **Commit:** 71bd85a

**4. [Test precision]** the short guard-verb checks `rm`, `mv`, `tee`, `truncate` are pinned in backticks, and the nesting limit as "deeper than two levels", so the checks cannot be satisfied by unrelated words ("form", "term").

## Known Stubs

None.

## Threat Flags

None. README and a free test only; no endpoint, no write path.

## Self-Check: PASSED

- README.md and tests/test-readme.sh exist; commits 71bd85a and 5d82363 are ancestors of HEAD.
- Not touched, as instructed: LICENSE, CHANGELOG.md, CLAUDE.md, spec, tests/run.sh, STATE.md, ROADMAP.md.
