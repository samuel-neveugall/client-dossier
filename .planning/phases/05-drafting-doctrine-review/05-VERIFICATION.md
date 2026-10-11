---
phase: 05-drafting-doctrine-review
verified: 2026-10-11T04:30:00Z
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
  - "skills/dossier-draft/SKILL.md"
  - "skills/dossier/SKILL.md"
  - "tests/scenarios/draft-deadline-fr.sh"
  - "tests/scenarios/draft-reply.sh"
  - "tests/scenarios/lib-draft.sh"
  - "tests/scenarios/selftest-draft.sh"
  - "tests/test-agent-doctrine-reviewer.sh"
  - "tests/test-draft-shapes.sh"
  - "tests/test-skill-draft.sh"
covered_digest: "v3:sha256:4a57f30181eebf985e0c50eb1c2746e07ca8fc003320a26c64ed496bbefbfc4c"
behavior_unverified: 0
overrides_applied: 0
---

# Phase 5: Drafting & Doctrine Review Verification Report

**Phase Goal:** A draft addressed to the counterpart is never one unreviewed step away from going out.
**Verified:** 2026-10-11
**Status:** passed
**Re-verification:** No, initial verification

## Goal Achievement

### Observable Truths (ROADMAP success criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `dossier-draft mail <slug>` writes a file under `outbound/mails/` with a complete status header (`Deadline:` when given), in the dossier's language, following the tone file's structure | VERIFIED | `skills/dossier-draft/SKILL.md` has the kind/folder table (mail -> `outbound/mails/`), the status block template (Status, To, Subject, Deadline, Written by, Rules), the language rule and the "fifth `## ` heading" structure rule. The templates confirm the positions in both languages: TONE.md headings 4 (long), 5 (short), 6 (Refused); DOCTRINE.md heading 2 (never say). Paid French run `evidence/fr-deadline/fr-1`: file `outbound/mails/2026-10-11_reponse-date-audit.md`, header has `Status: draft`, `To:`, `Subject:`, `Deadline: 2026-10-30`, `Written by:`, `Rules:`, French body, slug kept, linter `0 error(s), 0 warning(s)`. Transcript shows `Skill client-dossier:dossier-draft` invoked. |
| 2 | `doctrine-reviewer` findings are applied or explicitly listed as disagreements before the draft is left for a human | VERIFIED | The skill's "Apply the findings" section requires each finding to be applied or listed under `Disagreements`, and makes a mandatory dispatch whenever a subagent tool exists. Transcripts of `green-plugin/plugin-{1,2,3}` and `fr-1` show an `Agent` call with `subagent_type: client-dossier:doctrine-reviewer`. `summary.tsv` has `reviewer_dispatched=yes`, `reviewer_tools_ok=yes` and `disagreements_listed=yes` for 3/3. In `fr-1` the reviewer returned 3 findings (unsourced promise, relative date, structure), all applied via Edit, and the final report says "sans désaccord". `agents/doctrine-reviewer.md` has tools `Read, Grep, Glob` only (read-only). |
| 3 | `lint.py` runs on every draft, history gains a commitment line, status is never "sent" by the skill | VERIFIED | The skill has a "Check with the linter" section (`test -f ${CLAUDE_PLUGIN_ROOT}/scripts/lint.py`, then `lint.py '<root>'`), a "Record in history" section (commitment line with and without a deadline, plus `Last updated:`) and an explicit never-`sent` rule. Evidence diffs: `plugin-1.diff` and `fr-1.diff` add the line `draft mail '<slug>' written, to be sent by Scenario Runner ...` under "Ours" and update `Last updated:`. `fr-1.diff` includes the deadline in the history line. All `summary.tsv` rows have `status_value=draft`, `history_line=yes`, `lint_exit=0`, `lint_called=yes`. |
| 4 | "Write a quick reply to the client" moves from RED to GREEN | VERIFIED | `evidence/red-baseline` (no plugin): 3/3 RED. 0 of 3 had a history line, 0 had a reviewer, 0 invoked the skill. Run 1 filed nothing (asked for the mail). Runs 2 and 3 wrote a draft with a relative date and a guessed start date. Run 3 invented a `Deadline: 2026-10-15`. `evidence/green-plugin` (plugin loaded): 3/3 GREEN. Skill invoked, reviewer dispatched, history line, no leak, `Status: draft`, linter 0/0, human sender named, no relative-date words, no deadline guessed. The skill's commit (d930160, 03:35) predates the GREEN evidence commit (dbe8f07, 03:47), so GREEN ran against the shipped skill text. |
| 5 | Skill text contains the inline review procedure for a harness without subagents and says what it does when `lint.py` is absent | VERIFIED | `skills/dossier-draft/SKILL.md` has the `review-rules` block (11 rules, byte-identical to the agent's, parity enforced by `tests/test-agent-doctrine-reviewer.sh`), the sentence "No subagent here: I am doing the doctrine-reviewer's job myself", and a "Without the linter" section stating E1-E5. `tests/test-skill-draft.sh` asserts these. The E-codes match `scripts/lint.py`. |

**Score:** 5/5 truths verified, 0 behavior-unverified.

The behavior-dependent truths (reviewer dispatch, never `sent`, history written) are backed by behavioral evidence: transcripts from real headless runs, not symbol presence alone.

### Required Artifacts

| Artifact | Status | Details |
|----------|--------|---------|
| `skills/dossier-draft/SKILL.md` (279 lines) | VERIFIED | Substantive and wired. `skills/dossier/SKILL.md:148` routes to it. Invoked in all 4 GREEN transcripts. |
| `agents/doctrine-reviewer.md` (62 lines) | VERIFIED | Read-only tools, shared rules block, dispatched in all 4 GREEN transcripts. |
| `tests/test-skill-draft.sh`, `tests/test-agent-doctrine-reviewer.sh`, `tests/test-draft-shapes.sh` | VERIFIED | Run by `tests/run.sh`, all pass. |
| `tests/scenarios/{draft-reply,draft-deadline-fr,lib-draft,selftest-draft}.sh` | VERIFIED | Selftest passes. |
| `evidence/{red-baseline,green-plugin,fr-deadline}` | VERIFIED | Transcripts, diffs, lint output and `summary.tsv` are present for every run. |

### Key Links

| From | To | Status |
|------|----|--------|
| `dossier` entry skill | `dossier-draft` | WIRED (line 148, and the Skill call appears in transcripts) |
| `dossier-draft` | `doctrine-reviewer` | WIRED (`Agent` call with `subagent_type client-dossier:doctrine-reviewer` in 4/4 runs) |
| `dossier-draft` | `scripts/lint.py` | WIRED (`lint_called=yes`; lint output stored per run) |
| skill's review-rules | agent's review-rules | WIRED (parity test) |
| rule heading positions | `skills/dossier-init/templates/{en,fr}/{TONE,DOCTRINE}.md` | WIRED (positions 5/4/6 and 2 confirmed in both languages) |
| `CLAUDE.md` | Phase 5 | WIRED (lines 15-17, 139-140) |

### Behavioral Spot-Checks and Test Runs

| Check | Result |
|-------|--------|
| `bash tests/run.sh` | `TOTAL: 20 files, 0 failed` |
| `tests/scenarios/selftest.sh` | PASS 71, FAIL 0 |
| `tests/scenarios/selftest-draft.sh` | PASS 477, FAIL 0 |
| `tests/scenarios/selftest-ingest.sh` | PASS 189, FAIL 0 |
| Paid scenarios | Not re-run, by instruction. Stored evidence inspected instead. |

### Requirements Coverage

| Req | Status | Evidence |
|-----|--------|----------|
| DRAFT-01 | SATISFIED | Truth 1. The skill reads tone, learnings, doctrine, decisions, history, open questions and the last files of the same folder, then writes the header and body in the dossier's language. |
| DRAFT-02 | SATISFIED | Truths 2 and 3, including the `Deadline:` rule, the history line and no `sent`. |
| DRAFT-03 | SATISFIED | The agent is read-only (`Read, Grep, Glob`), takes the draft path, root and kind, and returns severity-ranked findings in six categories (plus `header`). It has the Refused log and confidential-name rules and no rewrite instruction. |
| DRAFT-04 | SATISFIED | Truth 4, RED 3/3 then GREEN 3/3. |
| DRAFT-05 | SATISFIED | Truth 5. |

No orphaned requirements. DRAFT-01..05 are the only ones mapped to Phase 5.

### Anti-Patterns

No unreferenced TBD/FIXME/XXX markers found in the Phase 5 files. No stubs: the skill and agent are fully written, and the tests assert their content.

### Human Verification Required

None.

## Warnings (non-blocking)

1. **Bookkeeping not updated.** `.planning/REQUIREMENTS.md` still shows DRAFT-01..05 as `[ ]` / "Pending" (traceability rows at lines 235-239), and the Phase 5 line in `.planning/ROADMAP.md` is still unchecked (the Plans block lists `- [ ] 05-0x`). This does not affect goal achievement, but the orchestrator should tick them when closing the phase.
2. **Small sample.** GREEN is 3 runs for the English reply and 1 run for the French deadline case, on one model (claude-sonnet-5-5). The evidence meets the stated gate but is not statistical proof.
3. **Inline-review path is only specified, not exercised.** The "No subagent here" procedure and the "Without the linter" fallback are verified as skill text with contract tests (what DRAFT-05 asks for), but no run exercised them. No scenario forces a harness without subagents.
4. **Lint timing in the French run.** In `fr-1` the agent states it did not re-run the linter after its final wording edit. The harness's post-run `fr-1.lint` shows `0 error(s), 0 warning(s)`, so the final file is clean.

## Gaps Summary

No gaps. All 5 ROADMAP criteria and DRAFT-01..05 are met by code present in the repository and by stored real-run evidence. The free test suites pass.

---

_Verified: 2026-10-11_
_Verifier: Claude (gsd-verifier)_
