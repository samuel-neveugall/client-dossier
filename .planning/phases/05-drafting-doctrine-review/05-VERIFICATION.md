---
phase: 05-drafting-doctrine-review
verified: 2026-10-11T07:00:00Z
status: passed
score: 5/5 must-haves verified
covered_files:
  - ".planning/phases/05-drafting-doctrine-review/05-01-PLAN.md"
  - ".planning/phases/05-drafting-doctrine-review/05-01-SUMMARY.md"
  - ".planning/phases/05-drafting-doctrine-review/05-02-PLAN.md"
  - ".planning/phases/05-drafting-doctrine-review/05-02-SUMMARY.md"
  - ".planning/phases/05-drafting-doctrine-review/05-03-PLAN.md"
  - ".planning/phases/05-drafting-doctrine-review/05-03-SUMMARY.md"
  - ".planning/phases/05-drafting-doctrine-review/05-04-PLAN.md"
  - ".planning/phases/05-drafting-doctrine-review/05-04-SUMMARY.md"
  - ".planning/phases/05-drafting-doctrine-review/05-05-PLAN.md"
  - ".planning/phases/05-drafting-doctrine-review/05-05-SUMMARY.md"
  - "agents/doctrine-reviewer.md"
  - "scripts/lint.py"
  - "skills/dossier-draft/SKILL.md"
  - "skills/dossier-ingest/SKILL.md"
  - "skills/dossier/SKILL.md"
  - "tests/scenarios/draft-deadline-fr.sh"
  - "tests/scenarios/draft-reply.sh"
  - "tests/scenarios/lib-draft.sh"
  - "tests/scenarios/selftest-draft.sh"
  - "tests/test-agent-doctrine-reviewer.sh"
  - "tests/test-draft-shapes.sh"
  - "tests/test-lint.sh"
  - "tests/test-skill-draft.sh"
covered_digest: "v3:sha256:63fc033d55dcc192981444644d1f63ef07128a866430749db3b265f65ebe79a3"
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: passed
  previous_score: 5/5
  gaps_closed: []
  gaps_remaining: []
  regressions: []
---

# Phase 5: Drafting & Doctrine Review Verification Report

**Phase Goal:** A draft addressed to the counterpart is never one unreviewed step away from going out.
**Verified:** 2026-10-11 (HEAD 59f57a1)
**Status:** passed
**Re-verification:** Yes. Previous report: `05-VERIFICATION.iter1.md` (status passed, 5/5). Nothing failed before, so this is a regression and drift check after two review-fix rounds.

## What changed since iteration 1

- E5 (confidential-name gate) hardening in `scripts/lint.py` (commits 1267548 and 4e33df7, 05 D-09): markup, apostrophes, word-break hyphens, encoded names, homoglyphs, a tolerant mixed-markup reading, link and tag long tail, dash and fullwidth-grave folding, and fail-closed on an unreadable `.gitkeep`.
- Wording of the review order and the linter gate in `skills/dossier-draft/SKILL.md` and `skills/dossier-ingest/SKILL.md` (ecd9edf, 069d68a): foreground dispatch, a PENDING review, the fixed order "review, apply, lint, history, report", and a `[C1]` error treated as "gate not passed".
- Harness columns `handback_before_review`, `lint_after_last_draft_edit` and `history_edit_before_review` (R6-6), now GREEN criteria of both plugin scenarios.
- Paid evidence re-recorded as `green-plugin-r2` (3 runs) and `fr-deadline-r2` (1 run).
- Moved pins in `tests/test-skill-draft.sh` and `tests/test-skill-ingest.sh` that sat after `finish` and never ran.
- Bookkeeping: REQUIREMENTS DRAFT-01..05 are now `[x]` / Complete and ROADMAP Phase 5 is ticked. Warning 1 of iteration 1 is cleared.

## Goal Achievement

### Observable Truths (ROADMAP success criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `dossier-draft mail <slug>` writes a file under `outbound/mails/` with a complete status header (`Deadline:` when given), in the dossier's language, following the tone file's structure | VERIFIED | `skills/dossier-draft/SKILL.md` lines 33-40 (kind to folder table), 72-77 (structure heading positions), 81-115 (language, header block with Status/To/Subject/Deadline/Written by/Rules, `Deadline:` only when given and absolute). `fr-deadline-r2/fr-1`: GREEN, file `outbound/mails/2026-10-11_reponse-date-audit.md`, `slug_kept`, `header_ok`, `deadline_ok`, `french_body`, `tone_applied`, `lint_exit 0`; the Skill call `client-dossier:dossier-draft` is event 6 of the transcript. |
| 2 | The reviewer's findings (confidential name, forbidden claim, refused pattern, unsourced promise, relative date) are applied or listed as disagreements before the draft is left for a human | VERIFIED | `agents/doctrine-reviewer.md` carries the shared rules block (categories 3-8, plus `header`), tools `Read, Grep, Glob`. The skill's "Review" and "Apply the findings" sections (lines 128-209): mandatory foreground dispatch, "every finding is applied or listed under Disagreements", a confidential-name finding is never a disagreement, fixed order. Transcript check on the 4 r2 runs: each has one Agent tool call with `subagent_type client-dossier:doctrine-reviewer` and `run_in_background: false`; `handback_before_review` is 0 and `reviewer_tools_ok` is yes in all four. |
| 3 | `lint.py` runs against every draft, history gains a commitment line, and the status is never set to "sent" by the skill | VERIFIED | Skill lines 211-243 (linter after the last edit, E5 gate rules including exit 2 or 3 and `[C1]`), 245-268 (history line with sender, with or without a deadline, plus `Last updated:`), 104-105 and 307 (never `sent`). r2 evidence: `lint_called yes`, `lint_after_last_draft_edit yes`, `history_line yes`, `status_value draft` in 4/4, no `Status: sent` anywhere in the transcripts, `.lint` files read `0 error(s), 0 warning(s)`. |
| 4 | The "quick reply to the client" pressure scenario moves from RED to GREEN | VERIFIED | `red-baseline` is 3/3 RED (no draft skill, no reviewer, no history line, no lint call; 2 of 3 runs promised a start date, 1 invented a deadline, none updated history). `green-plugin-r2` is 3/3 GREEN with `draft_skill`, `reviewer_dispatched`, `history_line`, `tone_applied`, `leak no`, `lint_after_last_draft_edit yes`. Same model, `claude-sonnet-5-5`, Claude Code 2.1.296. |
| 5 | The skill contains the inline review procedure for a harness without subagents and says what it does when `lint.py` is absent | VERIFIED | Skill lines 142-148 (inline review in three named cases, the sentence `No subagent here: I am doing the doctrine-reviewer's job myself`, the same rules block) and lines 280-292 ("Without the linter": states E1-E5, mandatory manual E5 check listing every confidential name). The rules block is byte-parity-tested against the agent's (`tests/test-agent-doctrine-reviewer.sh`). |

**Score:** 5/5 truths verified (0 present, behavior-unverified).

Truths 1 to 4 rest on real recorded model runs, not on presence alone. Truth 5 is a text contract and is tested as such; no run forces a subagent-less harness (carried warning, see below).

### Requirements Coverage

| Requirement | Status | Evidence |
|-------------|--------|----------|
| DRAFT-01 | SATISFIED | Truth 1; the skill reads tone, learnings, doctrine, decisions, history, open questions and the last files of the same folder before writing. |
| DRAFT-02 | SATISFIED | Truths 2 and 3: reviewer dispatch, findings applied or listed, linter, `Deadline:` rule, history line, never `sent`. |
| DRAFT-03 | SATISFIED | Read-only agent (`Read, Grep, Glob`), takes the draft path, root and kind, severity-ranked output in six categories plus `header`, no rewrite instruction (rule 11). |
| DRAFT-04 | SATISFIED | Truth 4 (RED 3/3, GREEN 3/3 plus FR 1/1). |
| DRAFT-05 | SATISFIED | Truth 5. |
| PROTO-02 (note) | Not a Phase 5 item | The `dossier` skill points at `dossier-draft` (`skills/dossier/SKILL.md` line 148). PROTO-02 stays `[ ]` in REQUIREMENTS because it completes incrementally across Phases 3 to 6 (calls and status pointers are not written yet); the Phase 5 share is delivered. |

No orphaned requirements.

### Key Links

| From | To | Status |
|------|----|--------|
| `dossier` entry skill | `dossier-draft` | WIRED (line 148; the Skill call appears in all 4 r2 transcripts) |
| `dossier-draft` | `doctrine-reviewer` | WIRED (foreground Agent call in 4/4 runs) |
| `dossier-draft` | `scripts/lint.py` | WIRED (`lint_called yes`, lint after the last draft edit in 4/4) |
| skill review-rules | agent review-rules | WIRED (parity test) |
| harness | new columns | WIRED (`lib-draft.sh` defines `draft_handback_before_review`, `draft_lint_after_last_draft_edit`, `draft_history_edit_before_review`; present in the r2 `summary.tsv` headers; proven by `selftest-draft.sh`, 532/0 as reported) |
| `CLAUDE.md` | Phase 5 | WIRED (lines 15-17, 139-140) |

### Behavioral Spot-Checks

Scratch dossier scaffolded with `init.py --language en --confidential-name 'Big Telco'`, a valid status header, linter run from the repository root.

| Input in the draft body | Expected | Result | Status |
|---|---|---|---|
| `Hello<br>Big Tel<wbr>co` | `[E5]` error | `outbound/mails/..._a.md:9: ERROR [E5] confidential name 'Big Telco' under outbound/`, exit 1 | PASS |
| `We use Big Telco here` | `[E5]` error | `[E5]` at line 9, exit 1 | PASS |
| `Bigger Telco` | no error | `0 error(s), 0 warning(s)`, exit 0 | PASS |
| `Big Telcom` | no error | `0 error(s), 0 warning(s)`, exit 0 | PASS |
| `Nothing here` | no error | exit 0 | PASS |

Test suites were not re-run, by instruction. The figures reported by the orchestrator are taken as given: `tests/run.sh` 20 files 0 failed, test-lint 1728/0, selftest 71/0, selftest-draft 532/0, test-skill-draft 181/0, test-skill-ingest 111/0. The paid scenarios were not re-run; the stored evidence was inspected, with the transcripts parsed for tool calls.

### Anti-Patterns

No `TBD`, `FIXME` or `XXX` in the Phase 5 skill, agent, harness or test files. No stubs: the skill and agent are fully written and pinned by tests. No unresolved blockers.

### Accepted debt (05 D-09, Samuel, 2026-10-11)

No override is recorded (`overrides_applied: 0`). None of these debts makes a Phase 5 truth literally false, because each truth is about the review flow and the linter gate, not about E5 being exhaustive:

- E5 does not cover abbreviations or acronyms, nicknames, translations, or homoglyphs outside the small folding table. The reviewer rule 3 names "variant, abbreviation, possessive or hyphenation", and the skill makes a human the final sender, so the gap is bounded by the review step. It is a residual risk of Truth 2, not a failure of it.
- Phase 2 debts OBS-01, the double typo in the last word, and the `_osa_distance` guard are linter-internal and do not alter any Phase 5 truth.

### Human Verification Required

None.

## Warnings (non-blocking)

1. **Small sample.** GREEN is 3 runs (reply) and 1 run (French deadline), one model. It meets the stated gate and is not statistical proof.
2. **Inline-review path is specified, not exercised.** The "No subagent here" procedure and "Without the linter" fallback are verified as skill text with contract tests, as DRAFT-05 asks. No run forces a harness without subagents.
3. **Order departure recorded in the evidence.** In `green-plugin-r2/plugin-2` the history edit (events 43 and 45) comes before the linter run (event 47), against the documented order review, apply, lint, history, report. The reviewer had already returned, the linter ran after the last draft edit and covered the history lines, and the final lint is clean. The new `history_edit_before_review` criterion does not gate lint-before-history. Recorded by the fix round, not gated.
4. **Carried from iteration 1.** The skill's wording on the linter is partly prose-pinned; the final file of every r2 run was linted clean by the harness itself (`*.lint` files), so the previous warning on `fr-1` is resolved (`lint_after_last_draft_edit yes`).

## Gaps Summary

No gaps. All 5 ROADMAP criteria and DRAFT-01..05 hold at HEAD 59f57a1. The two review-fix rounds changed the linter's E5 coverage, the skill's order and gate wording, and the harness criteria; none removed or weakened a must-have, and the spot-checks confirm the E5 hardening behaves as specified, without a false positive on `Bigger Telco` or `Big Telcom`.

---

_Verified: 2026-10-11_
_Verifier: Claude (gsd-verifier)_
