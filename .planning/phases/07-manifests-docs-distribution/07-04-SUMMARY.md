---
phase: 07-manifests-docs-distribution
plan: 04
subsystem: testing
tags: [evals, claude-plugin-eval, routing, skills, bash]
requires: []
provides:
  - "evals/routing/: eight claude plugin eval routing cases (DIST-06)"
  - "tests/test-evals-shape.sh: free shape and scaffold test of the suite, in tests/run.sh"
  - ".gitignore: evals/results/"
affects: [07-07 (paid eval run), 07-09 (CLAUDE.md commands list, DIST-06 tick)]
tech-stack:
  added: []
  patterns:
    - "case per folder: prompt.md + case.yaml + scaffold.sh + graders/*.md"
    - "scaffold seeds a dossier with the plugin's own init.py reached through BASH_SOURCE"
key-files:
  created:
    - tests/test-evals-shape.sh
    - evals/routing/write-to-client/
    - evals/routing/init-new-client/
    - evals/routing/ingest-transcript/
    - evals/routing/draft-reply/
    - evals/routing/call-prepare/
    - evals/routing/deal-status/
    - evals/routing/outside-dossier/
    - evals/routing/unrelated/
  modified:
    - .gitignore
key-decisions:
  - "Shape test is the single guard of the suite: documented keys only, allowed_tools pinned to [Read, Glob, Grep, Skill], every tool_used grader maps to an existing skills/ folder"
  - "outside-dossier and unrelated carry no case.yaml and no scaffold (empty workspace is the point); the test asserts their absence"
status: complete
commits: 3
plan_head_before: b8aae7a0df1bd0acc0644fcda0fbae042d373e9e
plan_head_after: 2cc4078655ff9aa6ee6f3f850deada95eb185477
actuals:
  tokens: 5200
  tasks: 3
  commits: 3
metrics:
  completed: 2026-10-11
---

# Phase 7 Plan 04: Routing eval suite Summary

Eight `claude plugin eval` routing cases for the six skills' trigger descriptions, pinned by a free shape and scaffold test (`tests/test-evals-shape.sh`, 236 assertions) and kept out of the tree by an `evals/results/` ignore line. No paid run was made; that is plan 07-07.

## Case table

| Case | Tags | Scaffold | Prompt | Graders |
|---|---|---|---|---|
| write-to-client | routing, draft, ambiguous | seeded | Write to the client to say we can deliver the audit on 2026-11-02 instead of 2026-10-28. | draft-fired (dossier-draft, min 1); ingest-not-fired (dossier-ingest, min 0, max 0) |
| init-new-client | routing, init | `git init` only | Set up a dossier in this repository for our new client Acme, contact Jane Doe. | init-fired (dossier-init, min 1) |
| ingest-transcript | routing, ingest | seeded + untracked `call-2026-10-10.txt` | Here is the transcript of today's call with Jane in call-2026-10-10.txt. What did we learn? | ingest-fired (dossier-ingest, min 1); draft-not-fired (dossier-draft, min 0, max 0) |
| draft-reply | routing, draft | seeded | Draft a short reply to Jane confirming Tuesday's meeting. | draft-fired (dossier-draft, min 1) |
| call-prepare | routing, call | seeded | Prepare tomorrow's call with Jane. | call-fired (dossier-call, min 1) |
| deal-status | routing, status | seeded | Where are we with this deal? | status-fired (dossier-status, min 1); draft-not-fired (dossier-draft, min 0, max 0) |
| outside-dossier | routing, step-aside | none | Write a short thank-you note to our client for yesterday's workshop. | suggests-init (regex `dossier-init`, last_message); names-missing-dossier (regex `dossier\.yaml\|no dossier`, flags i, last_message) |
| unrelated | routing, false-positive | none | Write a Python function that reverses a string. | no-dossier-skill (tool_used Skill, input_match `dossier`, min 0, max 0) |

Every case grants only `[Read, Glob, Grep, Skill]`, `max_turns: 8`, `timeout_seconds: 240`.

## Shape test

`bash tests/test-evals-shape.sh` ends `PASS 236 FAIL 0`. It checks the case set (`EXPECTED_CASES`), per-case prompt/grader/case.yaml shape via one python3 pass, the pinned write-to-client graders, and runs every scaffold for free in a fresh workspace with `env -i PATH HOME TMPDIR TERM=dumb` (exit 0; seeded cases: `dossier.yaml`, one commit, `lint.py` exit 0; init-new-client: `.git`, no `dossier.yaml`; ingest-transcript: the transcript is the only untracked file, four lines). Negative checks done once by hand on a scratch copy and discarded: an added `Bash` in `allowed_tools` and a grader naming `dossier-reply` both fail.

`bash tests/run.sh`: `TOTAL: 25 files, 0 failed`, no FAIL line (exit 0 by run.sh's own rule).

## Deviations from Plan

None - plan executed as written.

Execution-environment notes (not plan deviations):
- The worktree was created from the phase 6 merge (`b8aae7a`) and does not contain the phase 7 plan commits; the plan was read from the main checkout (read-only). The plan has `depends_on: []`, so nothing was missing for execution. This SUMMARY lives in the worktree phase directory.
- The sandbox guard refused `git` calls rewritten by rtk; git was run as `/usr/bin/git` with commit messages passed via `-F` files.
- The tracer gate (`type="tracer"`) is automated-only (`<verify>` is a free test); it was re-run green after task 2 and again at the end, no checkpoint raised.

## Known Stubs

None.

## Threat Flags

None. T-07-13/14/15 mitigations are in place: single `allowed_tools` line across the suite (asserted), scaffolds are repository scripts exercised for free, `evals/results/` ignored from the first case's commit.

## Commits

- 3040ce9 test(07-04): the write-to-client routing case and the eval shape test, tracer path
- 77a9938 test(07-04): one routing case per task skill
- 2cc4078 test(07-04): step-aside outside a dossier and the unrelated-prompt guard

## Self-Check: PASSED

All created paths exist, all three commits are ancestors of HEAD, working tree clean after the last task commit.
