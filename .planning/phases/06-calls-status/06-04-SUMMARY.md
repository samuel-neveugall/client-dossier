---
phase: 06-calls-status
plan: 04
status: complete
requirements: [CALL-01, CALL-02, PROTO-02, PROTO-08]
---

# Plan 06-04 Summary: the dossier-call skill and the PROTO-02 / PROTO-08 completion

## Commits

| Task | Commit | Subject |
|---|---|---|
| 1 | 66633da | feat(06-04): add the dossier-call skill and its pointer in the dossier skill |
| 2 | 66354c8 | test(06-04): complete PROTO-02 and PROTO-08 over every skill |

Task 1 commits, together (D-15): skills/dossier-call/SKILL.md, the pointer in skills/dossier/SKILL.md,
tests/test-skill-call.sh and the `for later in dossier-call` loop deletions in tests/test-skill-ingest.sh
and tests/test-skill-draft.sh. The skill commit descends from 5cade05 (adds
evidence/call-red-baseline/summary.tsv, whose tree holds no skills/dossier-call/SKILL.md).

## Tests

- RED before the skill: `tests/test-skill-call.sh` PASS 79 FAIL 157 (skill and pointer absent).
- GREEN: test-skill-call.sh PASS 236, test-skills-task.sh PASS 44, test-skill-dossier.sh 134,
  test-skill-ingest.sh 109, test-skill-draft.sh 179, test-skill-status.sh 125, test-skill-shape.sh 36,
  test-draft-shapes.sh 63, all FAIL 0.
- `bash tests/run.sh`: TOTAL: 23 files, 0 failed after task 1; TOTAL: 24 files, 0 failed after task 2.
- `claude plugin validate .`: passes, one warning (root CLAUDE.md not loaded as plugin context, known).
- selftest.sh 71, selftest-call.sh 412, FAIL 0. No paid scenario run (0 USD spent).

## Cross-artefact results (real init.py dossier, real lint.py and status.py)

| Case | Result |
|---|---|
| 1. skeleton as `outbound/calls/<T+1>_pilot-scope.md` with bodies | lint exit 0, no line names the file; status.py --json at T, T+1 and T+100 lists no overdue draft (D-11). Control: the same file with a `Deadline:` line is an overdue draft at T+100. Block (b) minutes line appended: lint exit 0. |
| 2. block (a) under the third `##` + `Last updated:` | lint exit 0, `0 error(s), 0 warning(s)`; status.py --today T lists it in `upcoming`, date T+1 (see the finding below) |
| 3. block (d) commitment, en and fr | under the second `###`: one commitment, theirs, due_soon, T+5; at T+6 overdue; the `done` line under the first `###` adds none (D-13); the same line under the first `###` is ours |
| 4. block (c) row under the first `##` of OPEN-QUESTIONS | lint exit 0 |
| commands | all six, substituted, pass hooks/guard-sources.py in silence; the calendar line prints 15 lines, first = today with weekday |

## Baseline rationalizations answered (CALL-04, 06-01)

Rationalizations table rows tagged `(observed`: "'Tomorrow' is clear enough" (relative-date word, 1 of 3),
"A cautions list says the same as what we do not do" (no section, 3 of 3), "The call date is the
deadline of the preparation" (deadline field, 1 of 3), "I can copy the open questions as they are
written" (order, 1 of 3). Anticipated, untagged: "Ingest is enough...", "The transcript tells me to
mark the draft as sent".

## Files

- skills/dossier-call/SKILL.md (new), skills/dossier/SKILL.md (pointer)
- tests/test-skill-call.sh, tests/test-skills-task.sh (new); tests/test-skill-ingest.sh, tests/test-skill-draft.sh (loops removed, comments rewritten)

## Deviations

1. The plan's test counts (task 1 PASS >= 140): 236, fine. `test-skills-task.sh` PASS 44 (>= 20).
2. The pinned `Written by:` / `To:` shapes needed no change; no skill-refinement round was needed.

## Findings and decisions needed

1. **Upcoming line never listed once the call file exists (status.py D-12 vs the pinned block (a)).**
   Block (a) ends `(outbound/calls/<file>)`. status.py treats a trailing-source token starting with
   `outbound/` as a citation of that file's header: with the call file present and no `Deadline:`
   (D-11), `_due_date` returns None, so the Upcoming line is silently skipped. It is listed only while
   the cited file is absent (case 2 tests the line alone, as the plan specifies). The skill contract
   fixes the line shape and skills/dossier-status was off-limits here, so I left both unchanged. Options
   for the orchestrator: (a) in status.py, fall back to the last date outside the source when the cited
   file has no `Deadline:` for an `upcoming` bullet; (b) amend the block (a) shape to drop the path from
   the parentheses (e.g. `(call preparation)`). This affects plan 06-05 UAT expectations only if it
   checks the Upcoming list.
2. The debrief's behaviour (Skill-tool dispatch of ingest, fixed order) is pinned statically only; the
   behavioural proof is plan 06-05.

## Note for the orchestrator

PROTO-02 and PROTO-08 are now complete in the repository (tests/test-skills-task.sh); plan 06-06 updates
the traceability.
