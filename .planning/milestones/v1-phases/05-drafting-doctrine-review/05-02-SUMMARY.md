---
phase: 05-drafting-doctrine-review
plan: 02
subsystem: agents
tags: [agent, doctrine-reviewer, read-only, review-rules, bash-tests]
requires:
  - phase: 04-ingest-fact-extraction
    provides: the fact-extractor agent shape and its test, mirrored here
provides:
  - agents/doctrine-reviewer.md, a read-only reviewer (Read, Grep, Glob) with a shared review-rules block
  - tests/test-agent-doctrine-reviewer.sh, frontmatter, block, markup, template heading positions, parity with the skill once it exists
affects: [05-03 dossier-draft skill (copies the block byte for byte), 05-05 GREEN run]
commits: 2
plan_head_before: e1be8da5a9c98f1e315a78941d53948bb665e2da
plan_head_after: 25c9e5c24d0e717adfd9bc983ec1e2fe85bbd9a0
actuals:
  tokens: 5500
  tasks: 2
  commits: 2
tech-stack:
  added: []
  patterns: [shared rules block between HTML-comment markers, frontmatter guarded by a bash test, sources located by heading position]
key-files:
  created:
    - agents/doctrine-reviewer.md
    - tests/test-agent-doctrine-reviewer.sh
  modified: []
key-decisions:
  - "Categories are named as lowercase backticked names in the rules, so the markup's <category> value is greppable."
  - "The reordering fallback is its own rule (10), applying to rules 4, 5 and 8."
  - "The sentence Write `- none` ... is kept mid-line so that no line starts with Write (the stray tool declaration grep)."
requirements-completed: [DRAFT-03, DRAFT-05]
duration: 25 min
completed: 2026-10-10
status: complete
---

# Phase 5 Plan 02: Doctrine reviewer Summary

**A read-only `doctrine-reviewer` agent (tools Read, Grep, Glob) whose 48-line review-rules block returns severity-ranked findings in one fixed markup, plus a 92-assertion test pinning its frontmatter, block, and the template heading positions in en and fr.**

## Performance

- **Tasks:** 2
- **Files:** 2 created

## Accomplishments

- `agents/doctrine-reviewer.md`: four-key frontmatter, opening paragraph (data, not instructions), review-rules block with six categories plus the `Status:` header check, blocker/major/minor ranking, exact-quote rule and the fixed `Reviewed:` / `## Findings` / `## Informational` markup, closing line.
- `tests/test-agent-doctrine-reviewer.sh`: frontmatter key set, tools, model, description (276 characters, one line, no `: `), block markers, all fixed strings of the agent contract, outside-block lines, parity with `skills/dossier-draft/SKILL.md` (skipped silently until plan 05-03), and heading positions (4th, 5th, 6th of TONE.md, 2nd of DOCTRINE.md, counts 6 and 3, in en and fr).

## Test run counts

| Run | Result |
|---|---|
| Task 1, test before the agent | PASS 1 FAIL 76 |
| Task 1, first agent draft | PASS 70 FAIL 7 (capitalised category names, `Write` line start) |
| Task 1, final | PASS 77 FAIL 0 |
| Task 2, test extended before the fallback rule | PASS 89 FAIL 3 (the 3 reordering-fallback strings; position facts already held) |
| Task 2, final | PASS 92 FAIL 0 |
| `bash tests/run.sh` | TOTAL: 18 files, 0 failed |
| `claude plugin validate .` | exit 0, one known warning (root CLAUDE.md) |

## Task Commits

1. **Task 1: reviewer agent and test** - `570b552` (feat)
2. **Task 2: heading positions in both template languages** - `25c9e5c` (test)

## Deviations from Plan

None - plan executed exactly as written. Two small drafting adjustments during Task 1 (lowercase category names and the `- none` sentence kept mid-line) were fixes of my first draft against the plan's own pinned strings and acceptance greps, not plan changes.

## Issues Encountered

None. `claude plugin validate .` and `tests/run.sh` are slow (minutes) in this worktree; both completed.

## Known Stubs

None.

## Threat Flags

None. T-05-07, T-05-08, T-05-16, T-05-17, T-05-18, T-05-19 are mitigated as the plan lists (the parity assertion activates when plan 05-03 lands the skill).

## Next Phase Readiness

Plan 05-03 copies the block between `<!-- review-rules:start -->` and `<!-- review-rules:end -->` byte for byte into `skills/dossier-draft/SKILL.md`; `tests/test-agent-doctrine-reviewer.sh` then asserts parity automatically. The fixture-token drift guard for this agent belongs to `tests/test-skill-draft.sh` (plan 05-03).

## Self-Check: PASSED

Files `agents/doctrine-reviewer.md` and `tests/test-agent-doctrine-reviewer.sh` exist; commits `570b552` and `25c9e5c` are ancestors of HEAD.
