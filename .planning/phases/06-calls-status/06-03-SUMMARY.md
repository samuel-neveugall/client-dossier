---
phase: 06-calls-status
plan: 03
status: complete
requirements: [CALL-03, PROTO-02, PROTO-08]
requirements-completed: [CALL-03, PROTO-02, PROTO-08]
key-files:
  created:
    - skills/dossier-status/SKILL.md
    - tests/test-skill-status.sh
  modified:
    - skills/dossier/SKILL.md
    - tests/test-skill-ingest.sh
    - tests/test-skill-draft.sh
    - tests/test-hook-stop.sh
---

# Plan 06-03 Summary: the dossier-status skill (CALL-03, PROTO-02, PROTO-08)

The read-only judgement layer over status.py, its pointer in the `dossier` skill, the contract and
cross-artefact test, and the Stop-hook case of 03 D-14. No paid scenario was run (spend 0 USD).

## Commits

| Task | Commit | Subject |
|---|---|---|
| 1 | 3f2a0bd | feat(06-03): add the dossier-status skill and its pointer in the dossier skill |
| 2 | db4cded | test(06-03): scenario-fixture parity of status.py and the real-root Stop hook case |

## Test results

- tests/test-skill-status.sh written first: RED PASS 42 FAIL 82 (no SKILL.md, no pointer); GREEN PASS 124 FAIL 0.
- test-skill-dossier.sh 132, test-skill-ingest.sh 110, test-skill-draft.sh 180, test-skill-shape.sh 35, all FAIL 0.
- tests/test-hook-stop.sh: PASS 125 before, PASS 129 after (the new case asserts exit, stderr, decision, reason: 4 assertions).
- `bash tests/run.sh`: TOTAL: 22 files, 0 failed. `claude plugin validate .` exit 0 (one known warning: root CLAUDE.md).
- Scenario selftests: selftest-call 412, selftest-draft 532, selftest-ingest 189, selftest 71, all FAIL 0.
- Fixture parity (CALL-05 `status_fixture`, today's date): exactly the overdue security questionnaire commitment
  (ours, D-3), the overdue steering-agenda draft (D-6), the unreflected pilot-brochure source (git, D-2); the
  sent-quote and signed-NDA traps absent; the pilot-plan line due soon (D+4), not an overdue draft;
  RELATIONSHIP.md stale; lint 0 errors; the tree hash, .git included, identical before and after.
- The skill's three command lines, substituted, pass the real hooks/guard-sources.py in silence; the second runs the real status.py (exit 0).

## Baseline rationalizations answered (CALL-05, 06-01-SUMMARY)

Reading three files and writing a confident summary (3 of 3 runs, one seed missed each time); the newly arrived
file missed (2 of 3); the overdue draft missed (1 of 3); pressure for a quick answer. The Rationalizations table
carries three `(observed` rows for these plus four anticipated rows (sent file, in-passing fix, marking sent, lint silence).

## Deviations

1. The scenario-fixture parity cases were written into tests/test-skill-status.sh in task 1 (one file, written
   before the skill), so the task 2 commit holds only the Stop-hook case; `status_fixture` is present in that file.
2. The Stop case adds 4 assertions, not 1 (PASS 125 to 129), because it repeats the P-02 shape (exit, stderr, decision, reason).
3. The skill avoids every scenario seed/trap token and both prompts (drift guard), so its baseline paragraph speaks of
   "a file that arrived" and "an overdue draft" instead of naming fixture files.

## Decisions needed

None. Plan 06-05 runs the CALL-05 GREEN with `--prompt pressured` against this skill.
