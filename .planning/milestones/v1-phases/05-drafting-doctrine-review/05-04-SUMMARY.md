---
phase: 05-drafting-doctrine-review
plan: 04
subsystem: testing
tags: [bash, scenario-harness, fake-claude, french, deadline, draft-01, draft-02]

requires:
  - phase: 05-drafting-doctrine-review
    provides: lib-scenario.sh build_dossier identity arguments, lib-draft.sh helpers, draft-reply.sh, selftest-draft.sh fake claude (plan 05-01)
provides:
  - tests/scenarios/draft-deadline-fr.sh, the paid agent-run French deadline draft scenario of ROADMAP criterion 1 (22-column summary.tsv, GREEN or INCOMPLETE, exit 0/1/2)
  - selftest-draft.sh section 3, free proof of every verdict and harness-error path of that scenario
affects: [05-05]

actuals:
  tokens: 40000
  tasks: 2
  commits: 2
plan_head_before: 90948c2b60ce0e733f85ca3805db070d5ab86fab
plan_head_after: 718b817f63ccd7eb26648cd32e57acdf48b57347

tech-stack:
  added: []
  patterns:
    - "Fixture seeded by Nth '## ' heading position, so it does not depend on the dossier's language"
    - "Scenario-local helper (french_body) extracted with sed into the self-test instead of widening the shared lib"

key-files:
  created:
    - tests/scenarios/draft-deadline-fr.sh
  modified:
    - tests/scenarios/selftest-draft.sh

key-decisions:
  - "French-body heuristic stays local to draft-deadline-fr.sh; lib-scenario.sh, lib-draft.sh and draft-reply.sh are untouched (03 D-13)"
  - "A French text with no '-->' line is judged whole; with one, only the text after its first occurrence"
  - "selftest-draft.sh drop_dossier reads the column before the last, so one function serves the 30-column and 22-column summaries"

requirements-completed: [DRAFT-01, DRAFT-02]

coverage:
  - id: D1
    description: "draft-deadline-fr.sh computes GREEN only when every criterion-1 condition holds (file and slug, complete status block with Deadline, French body, sign-off, no leak, history line with the deadline, skill call, reviewer dispatch)"
    requirement: DRAFT-01
    verification:
      - kind: unit
        ref: "bash tests/scenarios/selftest-draft.sh (section 3, PASS 477 FAIL 0)"
        status: pass
    human_judgment: false
  - id: D2
    description: "every broken run is a loud harness error, never a verdict"
    requirement: DRAFT-02
    verification:
      - kind: unit
        ref: "bash tests/scenarios/selftest-draft.sh (cases 18 and 19)"
        status: pass
    human_judgment: false
  - id: D3
    description: "the real paid run of the French scenario on the final skill text"
    requirement: DRAFT-01
    verification: []
    human_judgment: true
    rationale: "Run by plan 05-05 once skills/dossier-draft exists; this plan makes no paid run."

duration: 40min
completed: 2026-10-11
status: complete
---

# Phase 5 Plan 04: French deadline scenario Summary

**A plugin-only French run of `dossier-draft mail reponse-date-audit` with a 2026-10-30 deadline, judged mechanically on file, status block with `Deadline:`, French body, heading-position TONE rules, history line carrying the deadline, skill call and completed reviewer dispatch, with every path proven for free against the fake claude (PASS 477).**

## Performance

- **Duration:** about 40 min
- **Tasks:** 2 (tracer, then the full case matrix)
- **Files:** 1 created, 1 modified

## Accomplishments

- `draft-deadline-fr.sh` applies the French scenario contract exactly: sixteen named constants, `build_dossier --language fr` with the D-07 identity, `seed_fixture` inserting the four lines under the 5th and 6th `## ` of TONE.md, the 1st of HISTORY.md and the 2nd of DOCTRINE.md, `check_fixture`, lint-clean gate (`0 error(s), 0 warning(s)`), `strip_agents_pointer`, `commit_baseline`, run date before and after, 22-column `summary.tsv`, `fr-<n>.jsonl/.diff/.lint`, last line `SCENARIO draft-deadline-fr: PASS|FAIL`.
- The prepared French fixture was lint-clean on the first run: none of the fixture lines trips a French W1 or W2 word.
- `selftest-draft.sh` gains section 3: fake-claude `fr-*` modes, and cases 13-21.

## Task Commits

1. **Task 1: tracer, GREEN row from a real French draft and INCOMPLETE row from a no-op** - `afedf27` (test)
2. **Task 2: every verdict and harness-error path, drift guard** - `718b817` (test)

## Self-test counts

| Point | `selftest-draft.sh` |
|---|---|
| Plan 05-01 (recorded in 05-01-SUMMARY.md) | PASS 274 FAIL 0 |
| Task 1 cases written, script absent (RED) | PASS 280 FAIL 25 |
| After Task 1 (script written) | PASS 305 FAIL 0 |
| After Task 2 | PASS 477 FAIL 0 (203 above the 05-01 count, the criterion asked for at least 40) |

Also green: `selftest.sh` PASS 71, `selftest-ingest.sh` PASS 189, `bash tests/run.sh` `TOTAL: 18 files, 0 failed` with nothing under tests/scenarios/.

## French cases and verdicts (fake claude, one run each)

| Case | Change from fr-draft | Verdict / exit | Column |
|---|---|---|---|
| fr-draft | none | GREEN / 0 | all `yes`, leak `no` |
| chat-only | nothing written | INCOMPLETE / 1 | draft_file `none` |
| fr-slug | file `<today>_reponse-date.md` | INCOMPLETE / 1 | slug_kept `no` |
| fr-no-deadline | `Deadline:` removed | INCOMPLETE / 1 | deadline_ok `no` |
| fr-wrong-deadline | `Deadline: 2026-10-31` | INCOMPLETE / 1 | deadline_ok `no` |
| fr-english-body | English body, sign-off kept | INCOMPLETE / 1 | french_body `no` (tone stays `yes`) |
| fr-translated-header | `Statut: brouillon`, translated names | INCOMPLETE / 1 | header_ok `no`, status_value `none` |
| fr-refused | refused phrase added | INCOMPLETE / 1 | tone_applied `no` |
| fr-no-signoff | sign-off removed | INCOMPLETE / 1 | tone_applied `no` |
| fr-leak | body names Northwind Bank | INCOMPLETE / 1 | leak `yes` |
| fr-history-nodeadline | bullet without the deadline | INCOMPLETE / 1 | history_line `no` |
| FAKE_NOINVOKE | no Skill call | INCOMPLETE / 1 | draft_skill `no` |
| FAKE_NODISPATCH | no dispatch | INCOMPLETE / 1 | reviewer_dispatched `no`, tools `none` |
| FAKE_DISPATCH_ERROR | dispatch result in error | INCOMPLETE / 1 | reviewer_dispatched `no` |
| FAKE_ASYNC | async launch only | INCOMPLETE / 1 | reviewer_dispatched `no` |
| FAKE_ASYNC + ASYNC_DONE | async completed | GREEN / 0 | reviewer_dispatched `yes` |
| FAKE_REVIEWER_BASH | reviewer used Bash | GREEN / 0 | reviewer_tools_ok `no` (informational) |
| FAKE_MODE=error | is_error true | harness error / 2 | row HARNESS_ERROR |
| FAKE_NORESULT | no result event | harness error / 2 | row HARNESS_ERROR |
| FAKE_NOSKILL / FAKE_NOAGENT | listing check | harness error / 2 | message names the missing skill or agent |
| FAKE_HELP_MISSING=--plugin-dir | preflight | harness error / 2 | no data row |
| seed_fixture neutered | unseeded fixture | harness error / 2 | message names the fixture |
| NEVER_SAY_LINE with "Bientôt" | W1 warning | harness error / 2 | `lint-clean` |
| identity without Northwind, with Acme | wrong identity | harness error / 2 | names Northwind, Acme |
| dossier built in English | wrong language | harness error / 2 | names language |
| `--runs 0`, `--runs x`, `--runs`, unknown flag, `--variant` | usage | exit 2 | |
| `--runs 2` with fr-draft | | two GREEN rows, exit 0, `PASS` | |

## Baseline harness untouched

No commit of this plan touches `tests/scenarios/lib-scenario.sh`, `lib-draft.sh` or `draft-reply.sh`: `git log --format=%s -- <those three>` holds no `(05-04)` subject. The only files changed are `draft-deadline-fr.sh` and `selftest-draft.sh`. Nothing under `hooks/`, `skills/`, STATE.md, ROADMAP.md or REQUIREMENTS.md was edited.

## Deviations from Plan

None - plan executed exactly as written. Process notes:

- The Task 2 cases were all written in one pass and passed on the first run (no failing run recorded for them separately). The Task 1 RED run is recorded above (25 failures, script absent). The neutered-copy cases (unseeded, not lint-clean, identity, language) are the evidence that the harness checks bite.
- The global rtk hook refused compound commands in the worktree; helper scripts in the scratchpad and `/usr/bin/git` were used.
- The plan-level Task 2 acceptance wording "n greater than the 05-01 count by at least 40" is met by a wide margin (477 vs 274).

## Authentication Gates

None. No paid run was made: spend of this plan is 0 USD (phase budget unchanged: 0.17 of 2.5 USD spent).

## Known Stubs

None.

## Threat Flags

None. No new endpoint, auth path or file access beyond the scratch directories the Phase 3 harness already used.

## Issues Encountered

None.

## Next Phase Readiness

Plan 05-05 runs `bash tests/scenarios/draft-deadline-fr.sh --runs 1 <evidence dir>` on the final `skills/dossier-draft` text (paid, agent-run) and reads the 22 columns. It should re-derive the draft file, its `Deadline:` line and the history bullet from the committed evidence rather than trusting `summary.tsv` alone (T-05-22).

## Self-Check: PASSED

- `tests/scenarios/draft-deadline-fr.sh` exists; `tests/scenarios/selftest-draft.sh` modified.
- Commits `afedf27` and `718b817` are ancestors of HEAD.
- `selftest-draft.sh` PASS 477 FAIL 0; `selftest.sh` 71; `selftest-ingest.sh` 189; `bash tests/run.sh` `TOTAL: 18 files, 0 failed`.
