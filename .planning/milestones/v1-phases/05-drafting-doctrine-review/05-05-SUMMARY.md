---
phase: 05-drafting-doctrine-review
plan: 05
subsystem: testing
tags: [green-run, draft-04, doctrine-reviewer, dossier-draft, french-deadline, validation]

requires:
  - phase: 05-drafting-doctrine-review
    provides: dossier-draft skill and pointer (05-03), doctrine-reviewer agent (05-02), draft-reply.sh and the RED baseline (05-01), draft-deadline-fr.sh (05-04)
provides:
  - evidence/green-plugin (DRAFT-04 GREEN, 3 of 3 with G1-G6)
  - evidence/fr-deadline (ROADMAP criterion 1, GREEN)
  - CLAUDE.md Phase 5 state and the new commands
  - finalized 05-VALIDATION.md (12 rows green, nyquist_compliant true)
affects: [phase-06, phase-07]

actuals:
  tokens: 40000
  tasks: 3
  commits: 3
plan_head_before: 638f29de09f53b643cc861ff73e6b61b0837f350
plan_head_after: 45f762cfb8efc6c16c7d8779aad7bad73f8b6fcd

key-files:
  created:
    - .planning/phases/05-drafting-doctrine-review/evidence/green-plugin/ (11 files)
    - .planning/phases/05-drafting-doctrine-review/evidence/fr-deadline/ (5 files)
  modified:
    - CLAUDE.md
    - .planning/phases/05-drafting-doctrine-review/05-VALIDATION.md

key-decisions:
  - "No refinement round was needed: the first round on the shipped skill text was GREEN on both scenarios"
  - "Spec section 4 needs no amendment (checked and recorded below)"

requirements-completed: [DRAFT-01, DRAFT-02, DRAFT-03, DRAFT-04, DRAFT-05]
status: complete
---

# Phase 5 Plan 05: GREEN run, French deadline run and phase close-out Summary

**With `--plugin-dir`, three runs of three wrote a lint-clean `Status: draft` reply, recorded the commitment in history, applied the tone file and had `doctrine-reviewer` check it (completed dispatch); the French deadline run was GREEN too, on the first round and on the unchanged skill text.**

## Runs

Model `claude-sonnet-5-5`, Claude Code `2.1.296`, prompt kind `plain` (same as the recorded baseline, `evidence/red-baseline/`), AGENTS.md stripped. One round, zero refinements.

### Quick-reply scenario, plugin variant (`draft-reply.sh --variant plugin --runs 3 --prompt plain`, exit 0)

| Run | Verdict | Draft file | Status | leak | history | tone | draft_skill | reviewer dispatched | reviewer_tools_ok | lint | reldate | d04_shape | human_named | disagreements | Cost USD |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | GREEN | outbound/mails/2026-10-11_reply-start-date.md | draft | no | yes | yes | yes | yes | yes | 0 err, called | 0 | yes | yes | yes | 0.1677 |
| 2 | GREEN | outbound/mails/2026-10-11_reply-start-date.md | draft | no | yes | yes | yes | yes | yes | 0 err, called | 0 | yes | yes | yes | 0.1647 |
| 3 | GREEN | outbound/mails/2026-10-11_reply-start-date.md | draft | no | yes | yes | yes | yes | yes | 0 err, called | 0 | yes | yes | yes | 0.1707 |

In every run the transcript shows `Skill client-dossier:dossier`, then `Skill client-dossier:dossier-draft`, then an `Agent` call with `subagent_type` `client-dossier:doctrine-reviewer` (async, `task_notification` status `completed`); `inline_review_sentence` is `no`. The reviewer's runtime tools were only Read, Glob and Grep (T-05-07 and T-05-30 observed live). The sender named in history is the git `user.name` of the scratch repository (`Scenario Runner`), as the skill prescribes when the request names nobody.

History bullet added in all three runs (identical): `- 2026-10-11: draft mail 'reply-start-date' written, to be sent by Scenario Runner (outbound/mails/2026-10-11_reply-start-date.md).` plus `Last updated: 2026-10-11, after the draft mail 'reply-start-date'`. No `Deadline:` line (none was requested).

What the reviewer found, and what happened:

- Run 1: one minor `structural departure` (sign-off split over two lines); applied; Disagreements none. Informational: other checks pass, `knowledge/decisions/` empty, doctrine and tone sections empty.
- Run 2: one minor `structural departure` on the sign-off whose own wording said line 15 was already a separate line and to leave it if so; the writer made no edit and reported it. This is a self-cancelling finding handled in the report rather than under a `Disagreements` heading (the report said "Disagreements: none. I didn't edit the draft after the review"). Informational: the scoping call has no HISTORY entry.
- Run 3: two minor findings, `structural departure` (sign-off split) and `relative date` ("straight away"); both applied; Disagreements none.

No run produced a blocker or a major finding; no run set a status other than `draft`.

### French deadline run (`draft-deadline-fr.sh --runs 1`, exit 0, tracer run first)

| Verdict | Draft file | Slug kept | Status | Deadline | French body | tone | leak | history | draft_skill | reviewer | tools_ok | lint | Cost USD |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| GREEN | outbound/mails/2026-10-11_reponse-date-audit.md | yes | draft | `Deadline: 2026-10-30` (deadline_ok yes) | yes | yes | no | yes | yes | yes | yes | 0 err, 0 warn | 0.1832 |

History bullet: `- 2026-10-11 : brouillon mail 'reponse-date-audit' rédigé, à envoyer par Scenario Runner, échéance 2026-10-30 (outbound/mails/2026-10-11_reponse-date-audit.md).` under the French `### Les nôtres` heading, with `Last updated:` kept in English. Reviewer findings: 1 major (`unsourced promise`, the written confirmation of the start date), 2 minor (`relative date` "aujourd'hui", sign-off split); all three applied, no disagreement. The final prose retouch after the review was not re-linted by the model, but the harness lint run on the final file is clean (`fr-1.lint`: 0 error(s), 0 warning(s)).

## RED vs GREEN (same harness, fixture and plain prompt)

| | Baseline (no plugin, 3 runs) | Plugin (3 runs) |
|---|---|---|
| Verdict | RED 3 of 3 | GREEN 3 of 3 |
| File under outbound/mails/ | 1 of 3 runs wrote nothing (asked for the mail); 2 wrote `2026-10-11_reply-start-date.md` | 3 of 3 |
| History updated | 0 of 3 | 3 of 3 |
| dossier-draft invoked / reviewer dispatched | 0 / 0 | 3 / 3 |
| Relative-date words in the draft | 1 in each written draft | 0 |
| Guessed `Deadline:` | 1 run (2026-10-15) | 0 |
| Cost per run USD | 0.047 to 0.066 | 0.165 to 0.171 |

The 05-01 fallback (pressured prompt) did not apply. `reldate_words` was 1 in both baseline drafts (the probe drafts' relative dates) and 0 in the three plugin drafts.

## Costs

| Item | USD |
|---|---|
| Plugin runs 1-3 | 0.1677 + 0.1647 + 0.1707 = 0.5031 |
| French run | 0.1832 |
| This plan | 0.6862 |
| Plan 05-01 baseline | 0.1716 |
| **Phase total** | **0.8578 of the 2.5 USD budget** |

## Task Commits

1. Task 1 (tracer, paid runs and evidence): `dbe8f07` test(05-05): record the GREEN run of the quick-reply scenario and the French deadline run
2. Task 2 (CLAUDE.md): `bd2f136` docs(05-05): record Phase 5 in CLAUDE.md
3. Task 3 (validation contract): `45f762c` docs(05-05): finalize the phase 5 validation contract

No refinement or harness-fix commit: the skill, the agent, the pointer and the baseline harness are unchanged by this plan.

## Verification

- Task 1 verify: `VERIFY_OK`; acceptance counts: non-GREEN-column violations 0, d04_shape 3 and human_named 3 (at least 1 required), cost/model/version columns filled, French acceptance 0 violations, evidence folders 11 and 5 files, `scrub_check` exit 0 (it warns that the four jsonl transcripts hold a home path; no secret or email), baseline harness untouched by any `(05-05)` commit (0).
- Task 2 verify: passed; `grep -c doctrine-reviewer CLAUDE.md` = 4.
- Task 3: `bash tests/run.sh` `TOTAL: 20 files, 0 failed`; `selftest-draft.sh` 477 pass, `selftest.sh` 71 pass, `selftest-ingest.sh` 189 pass; `claude plugin validate .` exit 0 (the two known warnings); `bash -n` of both scenario scripts clean; evidence counts 11 / 11 / 5; 12 per-task rows `green`, `wave_0_complete` and `nyquist_compliant` true, `status:` left as `draft`.

## Spec check

Commands run and output:

- `awk '/^client-dossier\/$/,/README.md  LICENSE  CHANGELOG.md/'` on the spec: `dossier-draft/SKILL.md` appears 1 time and `doctrine-reviewer.md` 1 time in the section 4 tree (lines 222 and 227).
- `git ls-files skills/dossier-draft`: `skills/dossier-draft/SKILL.md` only.
- Section 4.1 (`dossier-draft`, lines 307-317): reads tone, learnings, doctrine, decisions and the last files of the same kind; writes under the outbound folder with the status header; dispatches `doctrine-reviewer` and lists disagreements; runs `lint.py`; writes `Deadline:` and updates history with "draft written, to be sent by <human>, deadline <date>"; never marks sent. The shipped skill does each of these (D-04's line extends the history sentence and adds the draft path).
- Section 4.2 (`doctrine-reviewer`, lines 349-355): read-only, findings ranked by severity over the six categories, does not rewrite. The shipped agent matches (tools Read, Grep, Glob, observed at runtime).

spec §4: no amendment needed

## Deviations from Plan

None - plan executed exactly as written. No refinement round and no harness bug occurred.

## Observations (not defects)

- The reviewer is dispatched asynchronously (`is_backgrounded`). In plugin runs 1 and 3 the writer's first chat message said the reviewer had not reported yet and went on to record history, then applied the findings after the `task_notification`. The order (draft, review, apply, lint, history) in the skill is thus partly reordered by the model, with no effect on the files.
- Plugin run 2's single review finding was self-cancelling and was reported rather than applied or listed under `Disagreements`; the harness column `disagreements_listed` is `yes` for all three rows through the report wording. If Phase 7 hardens the skill, the "every finding applied or listed" rule could name the non-actionable finding case.

## Known Stubs

None.

## Threat Flags

None (no new network endpoint, auth path or file-access surface).

## Notes for the orchestrator

REQUIREMENTS.md's PROTO-02 partial note can now name the `dossier-draft` pointer sentence in `skills/dossier/SKILL.md` (the engine owns that file; not edited here).

## Self-Check: PASSED

Evidence folders (`green-plugin` 11 files, `fr-deadline` 5 files), `CLAUDE.md` and `05-VALIDATION.md` exist; commits `dbe8f07`, `bd2f136`, `45f762c` are ancestors of HEAD.
