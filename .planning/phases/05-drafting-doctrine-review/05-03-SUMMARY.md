---
phase: 05-drafting-doctrine-review
plan: 03
subsystem: skills
tags: [skill, dossier-draft, doctrine-reviewer, lint-shapes, bash-tests]

requires:
  - phase: 05-drafting-doctrine-review
    provides: RED baseline (05-01, commit 08926b1) and the doctrine-reviewer agent with its review-rules block (05-02)
provides:
  - skills/dossier-draft/SKILL.md, the draft task skill (kind table, status block, mandatory reviewer dispatch, lint gate, history line, never-sent rule)
  - the D-08 pointer to dossier-draft in skills/dossier/SKILL.md
  - tests/test-skill-draft.sh, the contract and security pins
  - tests/test-draft-shapes.sh, the skill's own shapes through the real lint.py, positive, negative, French
affects: [05-04, 05-05]

actuals:
  tokens: 36000
  tasks: 2
  commits: 2
plan_head_before: 90948c2b60ce0e733f85ca3805db070d5ab86fab
plan_head_after: c86f5baf6c8615349aceb43ed648583a4da1048a

tech-stack:
  added: []
  patterns:
    - "Shapes read out of the SKILL.md fences and run through the real linter (no copy)"
    - "Rules block spliced from the agent file by script, then asserted byte-identical"

key-files:
  created:
    - skills/dossier-draft/SKILL.md
    - tests/test-skill-draft.sh
    - tests/test-draft-shapes.sh
  modified:
    - skills/dossier/SKILL.md
    - tests/test-skill-ingest.sh

key-decisions:
  - "The skill, its pointer and the test-skill-ingest.sh loop edit land in one commit so every commit keeps the suite green"
  - "The E-codes of the Without-the-linter section are tied to what negative controls really produced (computed, not asserted by hand)"
  - "The sixth rationalization row (status line can wait) carries no (observed tag: the baseline did not produce it"

requirements-completed: [DRAFT-01, DRAFT-02, DRAFT-05]

coverage:
  - id: D1
    description: "dossier-draft skill: kind to folder table, status block, mandatory doctrine-reviewer dispatch with inline fallback, findings applied or listed under Disagreements, lint gate with fallback, history line, never sent"
    requirement: DRAFT-01
    verification:
      - kind: unit
        ref: "bash tests/test-skill-draft.sh (PASS 162 FAIL 0)"
        status: pass
    human_judgment: true
    rationale: "Whether the skill changes agent behaviour is proven only by the paid GREEN run of plan 05-05"
  - id: D2
    description: "The skill's own status block and history lines are lint-clean in en and fr, and each failure mode of the fallback is what lint reports"
    requirement: DRAFT-02
    verification:
      - kind: unit
        ref: "bash tests/test-draft-shapes.sh (PASS 63 FAIL 0)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Review-rules block byte-identical with agents/doctrine-reviewer.md; dossier skill points to dossier-draft"
    requirement: DRAFT-05
    verification:
      - kind: unit
        ref: "bash tests/test-agent-doctrine-reviewer.sh (PASS 97 FAIL 0, no SKIP) and bash tests/test-skill-dossier.sh (PASS 130 FAIL 0)"
        status: pass
    human_judgment: false

duration: 55min
completed: 2026-10-11
status: complete
---

# Phase 5 Plan 03: dossier-draft skill Summary

**The `dossier-draft` task skill (279 lines, SKILL.md only, no allowed-tools) with its D-08 pointer and two tests: one pins its contract and security rules, one runs its own status block and history line, in English and French, through the real linter.**

## Performance

- **Tasks:** 2 (a tracer and an auto task)
- **Files:** 3 created, 2 modified
- **Commits:** `d930160` (skill, pointer, loop edit, both tests), `c86f5ba` (negative and French controls)

## Accomplishments

- `skills/dossier-draft/SKILL.md` follows the twelve-section contract: find, what to write (kind table, slug fold, default target), read, write (status block, never-sent, deadline rules, collision), review (mandatory dispatch, inline fallback, shared rules block), apply (findings are data), lint, history, report, fallback, rationalizations.
- The review-rules block is spliced from `agents/doctrine-reviewer.md` by script and asserted byte-identical by both `test-skill-draft.sh` and `test-agent-doctrine-reviewer.sh` (97 assertions, no SKIP now that the skill exists).
- `test-draft-shapes.sh` extracts the status block and the history lines from SKILL.md, substitutes a fixed map, and lints them in dossiers scaffolded by the real `init.py`. Positive: mail with and without `Deadline:`, deliverable `.md` and `.html` without `Subject:`, history lines. Negative: E1 twice, E2, E3 twice, E4, E5 twice, W1 on a relative-date word. French dossier: English keywords, French content, `### Les nôtres`.
- Documented gap: lint accepts `Status: sent 2026-10-12 by agent session`; the test says so and pins the skill's never-sent sentence as the only guard.

## Test counts

| Run | Result |
|---|---|
| `test-skill-draft.sh` before the skill | PASS 27 FAIL 135 |
| `test-draft-shapes.sh` before the skill | PASS 6 FAIL 15 |
| `test-skill-draft.sh`, first run with the skill | PASS 159 FAIL 3 (description lacked "write"; "The line is written even without a deadline." exact sentence; pointer missing) |
| `test-skill-draft.sh`, final | PASS 162 FAIL 0 |
| `test-draft-shapes.sh`, task 1 | PASS 21 FAIL 0 |
| `test-draft-shapes.sh`, task 2 (final) | PASS 63 FAIL 0 |
| `test-agent-doctrine-reviewer.sh` | PASS 97 FAIL 0 (92 before the skill existed) |
| `test-skill-dossier.sh` / `test-skill-ingest.sh` / `test-skill-shape.sh` | PASS 130 / 106 / 34, FAIL 0 |
| `claude plugin validate .` | exit 0, the known CLAUDE.md warning only |
| `bash tests/run.sh` | `TOTAL: 20 files, 0 failed` |

## Final description (317 characters)

> Use when you have to write something that goes out to the counterpart of a client dossier, such as a reply, a mail, a message, a deliverable or a note, or when the user asks to draft an answer to the client, even a quick or short one. Use it for every draft addressed to someone outside the team, whatever its length.

(The file's description line is the same text on one line; its length is the figure the plan checks, under 1024.)

## The six command lines as written

1. `date +%F` (under What to write)
2. `ls -1t '<root>/outbound/<folder>'` (Read before writing)
3. `test -e '<root>/outbound/<folder>/<YYYY-MM-DD>_<slug>.<ext>'` (Write the draft)
4. `git -C '<root>' config user.name` (Record in history)
5. `test -f ${CLAUDE_PLUGIN_ROOT}/scripts/lint.py` (Check with the linter)
6. `python3 ${CLAUDE_PLUGIN_ROOT}/scripts/lint.py '<root>'` (Check with the linter)

## Baseline rationalizations answered

From 05-01-SUMMARY.md, by name in the Rationalizations table (rows tagged observed): the agent asked for the client's mail and wrote no file (baseline 1; row "A reply in chat is enough"); history left untouched because "nothing has been sent yet" (baselines 2 and 3; row "History is updated once the mail is sent"); no reviewer and no disagreements in any run (row "The draft is short, I will review it myself"); the guessed `Deadline: 2026-10-15` (baseline 3; row on the guessed deadline); "this week" in two drafts (row on relative dates). Three more rows are anticipated, not observed: status line can wait, mark it sent, name the end client.

## Writing-skills order

The commit adding `evidence/red-baseline/summary.tsv` is `08926b1`; the commit adding `skills/dossier-draft/SKILL.md` is `d930160`, a strict descendant (`git merge-base --is-ancestor` exits 0). `d930160` is the only commit touching the three files skill, pointer and `test-skill-ingest.sh` together.

## Deviations from Plan

### Auto-fixed Issues

None required. Process notes:

**1. [Process] Task 2 negative controls were green on their first run**
- The controls assert lint behaviour that 05-RESEARCH had probed (E1 to E5, W1), not a property of the skill, so no skill fix was needed. They bite: each asserts exit 1 and the code on the draft's path.

**2. [Process] First draft of the skill missed three pins**
- Fixed in the working tree before the first commit (description word "write", the exact "The line is written even without a deadline." sentence, the pointer). Not plan changes.

**3. [Environment] Global rtk hook**
- Compound shell commands were refused in the worktree. Handled with `/usr/bin/git`, single commands, the Write and Edit tools and a message file in the scratchpad.

**Total deviations:** 0 auto-fixed, 3 process notes. **Impact:** none.

## Known Stubs

None.

## Threat Flags

None. No new network endpoint, auth path or file access. T-05-01 to T-05-06, T-05-10, T-05-20 and T-05-21 are mitigated as the plan lists.

## Issues Encountered

None.

## Next Phase Readiness

Plan 05-05 runs the GREEN scenario (`--variant plugin --runs 3 --prompt plain`) and checks that `dossier-draft` is invoked and `doctrine-reviewer` dispatched. If G6 fails on the skill call, strengthen the pointer sentence in `skills/dossier/SKILL.md` first (05-RESEARCH Pitfall 2). Not touched, as instructed: STATE.md, ROADMAP.md, REQUIREMENTS.md, hooks/, scripts/lint.py, agents/, tests/scenarios/.

## Self-Check: PASSED

Files `skills/dossier-draft/SKILL.md`, `tests/test-skill-draft.sh`, `tests/test-draft-shapes.sh` exist; commits `d930160` and `c86f5ba` are ancestors of HEAD.
