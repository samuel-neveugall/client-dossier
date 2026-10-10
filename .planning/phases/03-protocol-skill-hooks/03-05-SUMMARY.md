---
phase: 03-protocol-skill-hooks
plan: 05
subsystem: skills
tags: [skill, protocol, writing-skills]
requirements-completed: [PROTO-01, PROTO-02, PROTO-03, PROTO-08]
actuals:
  tasks: 2
  commits: 1
key-files:
  created:
    - skills/dossier/SKILL.md
    - tests/test-skill-dossier.sh
completed: 2026-10-10
---

# Phase 3 Plan 05: the dossier entry skill

**One SKILL.md (140 lines, description 510 characters) holds the whole protocol; its mechanical checklist is 89 assertions, 0 failures.**

Written after the RED baseline of 03-02 was recorded (3/3 RED under D-15), so the writing-skills order holds.
The test was written first and failed 80 of 89 assertions before the skill existed (PASS 9 FAIL 80), then passed
89/0.

- Triggering (PROTO-01): description starts "Use when", names dossier.yaml, client, counterpart, prospect, partner, call, message.
- Discovery and step-aside (PROTO-08, D-05): nearest dossier.yaml wins; none means one line, suggest dossier-init, continue.
- Content (PROTO-02): layout, six-row read/update table, fact line, status header, Name (Organisation), never-list.
- Language (PROTO-03): content in the `language` key, keywords stay English.
- Hook rules in prose (D-01, D-03, D-04): block-once Stop rule applied by the agent itself; sources untouched by every route;
  the Bash guard is stated to be a heuristic and the skill rule the real boundary; baseline rationalizations answered by name
  ("because you asked me to", deadline pressure).
- Pointers (D-07): only dossier-init; the test recomputes the set from skills/*/SKILL.md and bans the four later names.
- Worked example uses another case than the scenario fixture (test drift guard on the typo token and the transcript name).

## Deviations

- The two plan commits (task 1 frontmatter and discovery, task 2 body) were made as one commit (d3e864d): the test was written
  complete before the skill, and the skill in one pass. No behaviour differs.
- The skill does not name `dossier-status` (P-02: it does not exist yet; the Stop hook adds that sentence itself).

## Self-Check: PASSED

`bash tests/test-skill-dossier.sh` PASS 89 FAIL 0; `bash tests/run.sh` TOTAL: 11 files, 0 failed.
