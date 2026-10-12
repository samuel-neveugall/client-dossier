---
phase: 06-calls-status
verified: 2026-10-11T00:00:00Z
status: passed
score: 5/5 must-haves verified
covered_files:
  - ".planning/phases/06-calls-status/06-01-PLAN.md"
  - ".planning/phases/06-calls-status/06-01-SUMMARY.md"
  - ".planning/phases/06-calls-status/06-02-PLAN.md"
  - ".planning/phases/06-calls-status/06-02-SUMMARY.md"
  - ".planning/phases/06-calls-status/06-03-PLAN.md"
  - ".planning/phases/06-calls-status/06-03-SUMMARY.md"
  - ".planning/phases/06-calls-status/06-04-PLAN.md"
  - ".planning/phases/06-calls-status/06-04-SUMMARY.md"
  - ".planning/phases/06-calls-status/06-05-PLAN.md"
  - ".planning/phases/06-calls-status/06-05-SUMMARY.md"
  - ".planning/phases/06-calls-status/06-06-PLAN.md"
  - ".planning/phases/06-calls-status/06-06-SUMMARY.md"
  - "skills/dossier-call/SKILL.md"
  - "skills/dossier-status/SKILL.md"
  - "skills/dossier-status/scripts/status.py"
  - "skills/dossier/SKILL.md"
covered_digest: "v3:sha256:d8c2c4ff6bf1eb0e81ad148e17a05418f80ec490f29c974f0b9862f67ec4d32c"
behavior_unverified: 0
overrides_applied: 0
---

# Phase 6: Calls & Status Verification Report

**Phase Goal:** A human always knows what's due, and walks into every call already prepared.
**Verified:** 2026-10-11
**Status:** passed
**Re-verification:** No, initial verification

## Goal Achievement

### Observable Truths (ROADMAP success criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `dossier-call prepare` produces a call file with context, objectives, timed agenda, "what we do not do", open questions ordered by urgency, empty minutes | VERIFIED | `skills/dossier-call/SKILL.md` "Prepare" prescribes the exact section order (Context, What we want to obtain, Agenda, What we do not do in this call, Open questions, Minutes), absolute-date lookup, ordering rule for When-to-ask, no `Deadline:` (D-11), name-collision handling, linter run. Real artefact from GREEN run `evidence/call-green-plugin/plugin-3.diff`: all six sections present, timed agenda `0:00-0:05`..`0:25-0:30`, 3 questions ordered, empty minutes, role-only naming, lint `0 error(s), 0 warning(s)`. 3/3 GREEN runs: `call_skill=yes`, `history_upcoming=yes`, `deadline_line=no`, `e5=no`, `lint_exit=0`. |
| 2 | `dossier-call debrief` ingests the transcript, fills the minutes, moves answered questions with timestamps, adds owned/dated commitments to history, updates RELATIONSHIP.md on a milestone | VERIFIED | SKILL.md "Debrief" fixes the order (ingest via `client-dossier:dossier-ingest`, find call file, minutes with `(call <date> @mm:ss)`, answered-table rows with locator, commitments with owner + absolute date + `done` correction, milestone rule naming the signal, lint, report). Behaviourally exercised end to end in `06-UAT.md` test 1 (agent-run, paid, `evidence/uat/`): transcript filed, six minutes lines with locators, answered row moved, commitment parsed by `status.py` as `theirs/due_soon/2026-10-17`, RELATIONSHIP line rewritten with signal named, injected "mark as sent" instruction changed nothing, lint 0. |
| 3 | `dossier-status` prints, read-only, one-line status, due commitments, unreflected sources, overdue drafts (`Deadline:`), stale files (`staleness_days`), lint findings | VERIFIED | I ran `status.py` myself on a freshly init'd git dossier with seeded items (`--today 2026-10-11`): reported the overdue commitment, the due-soon commitment, the overdue draft (deadline 2026-10-05), skipped the `done` line and the far-future line, listed two unreflected sources (git and untracked) once living files were dated earlier, reported the stale files at `--today 2026-10-25` (14 days), printed `Lint: 0 error(s), 0 warning(s)`, exit 0, `git status --porcelain` unchanged by the run. Outside a dossier: exit 2 with an error on stderr. No file-write call in `status.py` (grep for `open(...,"w")`, `write_text`, `.write(`: none). |
| 4 | "Prepare tomorrow's call" scenario moves RED to GREEN | VERIFIED | `evidence/call-red-baseline/summary.tsv`: 3/3 RED (no "what we do not do" section in all 3, one relative-date word, one `Deadline:` line, one unordered question list), no plugin skill. `evidence/call-green-plugin/summary.tsv`: 3/3 GREEN, `dossier-call` Skill invocation present in each stream (grep of the jsonl), absolute date 2026-10-12, questions in order, section present, lint 0. |
| 5 | "Where are we with this deal" scenario moves RED to GREEN (uses `dossier-status`) | VERIFIED | `evidence/status-red-baseline/summary.tsv`: 3/3 RED (each run missed an unreflected source or an overdue draft; 3 reads each; no `dossier-status`). `evidence/status-green-plugin/summary.tsv`: 3/3 GREEN, commitment + draft + source all reported, trap items (sent, done) not reported, `status_skill=yes`, `status_script_run=yes`, `tree_unchanged=yes`, `porcelain_empty=yes`; Skill `client-dossier:dossier-status` and a `status.py` run seen in the jsonl. |

**Score:** 5/5 truths verified (0 present, behaviour-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `skills/dossier-call/SKILL.md` | prepare + debrief skill | VERIFIED | 311 lines, frontmatter `name` + trigger-style `description`, substantive, wired from `skills/dossier/SKILL.md` and invoked in GREEN streams |
| `skills/dossier-status/SKILL.md` | status presentation skill | VERIFIED | 141 lines, read-only contract, "Without the script" and "Without the linter" fallbacks |
| `skills/dossier-status/scripts/status.py` | read-only mechanics | VERIFIED | 881 lines, mode 100755 in git, Python stdlib; behaviour confirmed by my run |
| `skills/dossier/SKILL.md` pointers | `dossier-call`, `dossier-status` under "Other skills" | VERIFIED | lines 151-155; `tests/test-skills-task.sh` pins exactly the five names |
| Stop hook sentence | names `dossier-status` once the skill file exists | VERIFIED | `hooks/stop-check.py` `status_sentence()`; `tests/test-hook-stop.sh` passes |
| Scenario harness | `tests/scenarios/{call-prepare,deal-status,lib-call,selftest-call}.sh` | VERIFIED | present, selftest recorded in UAT |
| Tests | `test-skill-call`, `test-skill-status`, `test-status-script`, `test-skills-task` | VERIFIED | all `ok` in the suite |

### Key Link Verification

| From | To | Via | Status |
|------|----|-----|--------|
| `dossier-call` debrief | `dossier-ingest` | Skill tool invocation, fallback to reading its SKILL.md | WIRED; UAT stream shows `dossier-call` then `dossier-ingest` |
| `dossier-status` skill | `status.py` | `${CLAUDE_SKILL_DIR}/scripts/status.py '<root>'` after `test -x` | WIRED; GREEN jsonl shows the run |
| `status.py` | `scripts/lint.py` | subprocess located from `__file__` (not `CLAUDE_PLUGIN_ROOT`), D-12 | WIRED; lint line appears in my run |
| `dossier-call` prepare | `dossier-status` | Upcoming history line, dated fallback in `_due_date`, no `Deadline:` in call files | WIRED (D-11) |
| `dossier` skill | `dossier-call`, `dossier-status` | "Other skills" section | WIRED (PROTO-02) |

### Data-Flow Trace (Level 4)

`status.py` reads real inputs only (HISTORY.md, RELATIONSHIP.md, outbound headers, `git log`, mtime, lint subprocess); no static returns. My seeded run proved each section responds to the input.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full suite | `bash tests/run.sh` | `TOTAL: 24 files, 0 failed` | PASS |
| Status report on seeded dossier | `status.py --today 2026-10-11 .` | overdue, due soon, overdue draft, skips done/far, exit 0 | PASS |
| Unreflected sources | living files dated 2026-10-05, two sources | both listed (git, untracked) | PASS |
| Stale files | `--today 2026-10-25` | seven files listed, 14 days | PASS |
| Read-only | `git status --porcelain` before/after (clean tree) | unchanged | PASS |
| Outside a dossier (PROTO-08) | `status.py <empty dir>` | exit 2, message on stderr | PASS |

### Probe Execution

No `probe-*.sh` declared by the phase and none under `scripts/`. Skipped.

### Requirements Coverage

| Requirement | Description | Status | Evidence |
|-------------|-------------|--------|----------|
| CALL-01 | prepare writes the call file | SATISFIED | truth 1 |
| CALL-02 | debrief ingests, fills minutes, moves answers, commitments, milestone | SATISFIED | truth 2 |
| CALL-03 | status read-only, all six items | SATISFIED | truth 3 |
| CALL-04 | baseline RED then GREEN | SATISFIED | truth 4, 3/3 and 3/3 |
| CALL-05 | baseline RED then GREEN | SATISFIED | truth 5, 3/3 and 3/3 (D-16 fallback to "baseline recorded" was not needed) |
| PROTO-02 | `dossier` skill points to all five other skills | SATISFIED | `tests/test-skills-task.sh` |
| PROTO-08 | every task skill stops outside a dossier | SATISFIED | the same test visits `dossier-ingest`, `dossier-draft`, `dossier-call`, `dossier-status` for the stop sentence, nearest-dossier rule, init suggestion and quote rule; `status.py` exit 2 confirmed; UAT test 2 (`evidence/uat/outside.jsonl`) shows a real stop with nothing written |

No orphaned requirements: REQUIREMENTS.md maps no other ID to Phase 6.

### Anti-Patterns Found

None. `TBD|FIXME|XXX` scan over the phase's skills, script, scenario libraries and tests: no matches. No write path in `status.py`.

### Human Verification Required

None. The scenario and UAT runs were agent-run by mandate (Samuel never runs recette commands); their evidence is on disk and consistent with the suite.

### Gaps Summary

No blocking gaps. Informational notes only, none of which changes the verdict:

1. `.planning/ROADMAP.md` still shows the Phase 6 checkbox unticked (line 35) and "Plans: TBD" under the phase. This is a bookkeeping item for the orchestrator's close-out, not a goal gap.
2. ROADMAP criterion 5 and CALL-05 describe the RED as "misses due commitments". In the recorded baseline all three runs did report the overdue commitment and missed an unreflected source or an overdue draft (the hardened fixture of D-16). The criterion's spirit (RED then GREEN with `dossier-status`) is met; wording could be aligned if the orchestrator wishes.
3. `status.py` compares filing day to `Last updated:` day, so a source filed the same day as the newest update is not reported as unreflected. This matches D-04 ("later than") at day granularity and is a design choice, not a defect.

---

_Verified: 2026-10-11_
_Verifier: Claude (gsd-verifier)_
