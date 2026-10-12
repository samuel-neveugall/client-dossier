---
phase: 05-drafting-doctrine-review
verified: 2026-10-12T00:00:00Z
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
covered_digest: "v3:sha256:5fc8eedb3f1d8aea61fb093e57d70e4f536adc1177e261894cc5b353323de4e2"
behavior_unverified: 0
overrides_applied: 1
overrides:
  - must_have: "Confidential names never leak under outbound/ (D-05 / spec §6): E5 catches the name mechanically"
    reason: "E5 does not cover abbreviations or acronyms (e.g. BT for British Telecom), nicknames, translations, or homoglyphs outside the small table. These stay with doctrine-reviewer alone (documented v1 debt)."
    accepted_by: "Samuel (05 D-09)"
    accepted_at: "2026-10-11"
re_verification:
  previous_status: passed
  previous_score: 5/5
  gaps_closed: []
  gaps_remaining: []
  regressions: []
---

# Phase 5: Drafting & Doctrine Review Verification Report

**Phase Goal:** A draft addressed to the counterpart is never one unreviewed step away from going out.
**Verified:** 2026-10-12
**Status:** passed
**Re-verification:** Yes, after two review-fix rounds (iter1 report: `05-VERIFICATION.iter1.md`, passed 5/5). The fix rounds changed `scripts/lint.py` (E5 hardening), `skills/dossier-draft/SKILL.md`, `skills/dossier-ingest/SKILL.md`, `tests/scenarios/*` and `tests/test-*.sh`.

## Goal Achievement

### Observable Truths (ROADMAP success criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `dossier-draft mail <slug>` writes a file under `outbound/mails/` with a complete status header (`Deadline:` when given), in the dossier's language, following the tone file's structure | VERIFIED (no regression) | The skill's kind/folder table, status block and structure rule are intact. The skill still says never write `sent` or `reviewed by` (SKILL.md:104). Stored French run `evidence/fr-deadline-r2/fr-1`: verdict GREEN, `status_value=draft`, `lint_exit=0`. `tests/test-skill-draft.sh` and `tests/test-draft-shapes.sh` pass in `tests/run.sh`. |
| 2 | `doctrine-reviewer` findings are applied or listed as disagreements before the draft is left for a human | VERIFIED, strengthened | The skill now requires a foreground dispatch ("never set `run_in_background`, and wait for the findings", SKILL.md:134), which closes R5-M1. `evidence/green-plugin-r2/plugin-{1,2,3}` and `fr-deadline-r2/fr-1`: `reviewer_dispatched=yes`, `handback_before_review=0` in 4/4 runs. The agent file is unchanged (read-only tools; parity test passes). |
| 3 | `lint.py` runs on every draft, history gains a commitment line, status is never "sent" by the skill | VERIFIED, strengthened | The r2 summary rows show `history_line=yes`, `lint_exit=0` and `lint_after_last_draft_edit=yes` in 4/4 runs. The skill gate now treats lint exit outside {0,1}, or exit 1 with a `[C1]` line, as "gate not passed" (SKILL.md:232-238, R6-5). The never-`sent` rule is intact (SKILL.md:104, 307). |
| 4 | "Write a quick reply to the client" moves from RED to GREEN | VERIFIED | `evidence/red-baseline`: 3/3 RED (no skill, no reviewer, no history line). `green-plugin-r2`: 3/3 GREEN. `fr-deadline-r2`: 1/1 GREEN. All GREEN rows have `draft_skill=yes`, `leak=no`, `status_value=draft`. |
| 5 | Skill text contains the inline review procedure for a harness without subagents and says what it does when `lint.py` is absent | VERIFIED | SKILL.md:147 ("No subagent here: I am doing the doctrine-reviewer's job myself") and the "Without the linter" section (SKILL.md:280). Pinned by `tests/test-skill-draft.sh`. |

**Score:** 5/5 verified, 0 behavior-unverified.

### E5 confidential-name lint: round-3 hardening, verified by running `scripts/lint.py`

Scratch dossiers were scaffolded under the scratchpad (`.../scratchpad/r3v/`), never in the repo, with `--confidential-name 'Big Telco'`.

| Case | Expected | Observed |
|------|----------|----------|
| `Hello<br>Big Tel<wbr>co` (R6-1) | `[E5]` error | `outbound/mails/2026-10-11_x.md:9: ERROR [E5] confidential name 'Big Telco'`, exit 1 |
| `[Big](u 'title') [Telco](v)` (R6-2) | `[E5]` error | `[E5]` error, exit 1 |
| `Big<ZWSP>Telco` (R6-1) | `[E5]` error | `[E5]` error, exit 1 |
| UTF-16 non-empty `outbound/mails/.gitkeep` (R6-4) | unreadable `[E5]` error, fail closed | `.gitkeep:0: ERROR [E5] non-empty .gitkeep under outbound/ is unreadable ...`, exit 1 |
| Negative `Bigger Telco` | no finding | `0 error(s), 0 warning(s)`, exit 0 |
| Negative `Big Telcom` | no finding | `0 error(s), 0 warning(s)`, exit 0 |
| Control: plain `Big Telco` | `[E5]` error | `[E5]` error |

All six requested cases behave as specified. No new false positive was seen on the two negatives.

### Overrides (accepted debt, 05 D-09)

The truth "a confidential name never leaks under `outbound/`" is only partly mechanical. E5 does not cover abbreviations or acronyms (`BT`), nicknames, translations, or homoglyphs outside the small table. Samuel accepted this as v1 debt on 2026-10-11 (05 D-09). It is recorded in the `overrides:` frontmatter and still has a second line of defence in `doctrine-reviewer` rule 3. Also accepted from Phase 2 and not re-raised: OBS-01, double typo in the last word, the `_osa_distance` guard.

### Required Artifacts

| Artifact | Status | Details |
|----------|--------|---------|
| `skills/dossier-draft/SKILL.md` | VERIFIED | Substantive and wired from `skills/dossier/SKILL.md` (iter1 link check, file unchanged in that respect). Foreground-dispatch and `[C1]` rules present. |
| `agents/doctrine-reviewer.md` | VERIFIED | Unchanged since iter1. Parity test with the skill passes. |
| `scripts/lint.py` | VERIFIED | E5 hardening confirmed by the spot-checks above. `tests/test-lint.sh`: PASS 1728, FAIL 0. |
| `tests/scenarios/{draft-reply,draft-deadline-fr,lib-draft,selftest-draft}.sh` | VERIFIED | `selftest-draft.sh`: PASS 532, FAIL 0, exit 0. |
| `evidence/{red-baseline,green-plugin-r2,fr-deadline-r2}` | VERIFIED | Transcripts, diffs, lint output and `summary.tsv` are present for every run. |

### Behavioral Spot-Checks and Test Runs (run this session)

| Check | Result |
|-------|--------|
| `bash tests/run.sh` | `TOTAL: 20 files, 0 failed` |
| `bash tests/test-lint.sh` | PASS 1728, FAIL 0 |
| `bash tests/scenarios/selftest.sh` | PASS 71, FAIL 0 |
| `bash tests/scenarios/selftest-draft.sh` | PASS 532, FAIL 0, exit 0 (iter1: 477) |
| `claude plugin validate .` | exit 0, the two known warnings only (`author` missing, root `CLAUDE.md` not loaded) |
| Paid scenarios (`draft-reply.sh`, `draft-deadline-fr.sh`) | Not run, by instruction. Stored r2 evidence inspected instead. |

### Requirements Coverage

| Req | Status | Evidence |
|-----|--------|----------|
| DRAFT-01 | SATISFIED | Truth 1. |
| DRAFT-02 | SATISFIED | Truths 2 and 3. |
| DRAFT-03 | SATISFIED | The agent is read-only and unchanged. Confidential-name findings are covered, with the D-09 override noted. |
| DRAFT-04 | SATISFIED | Truth 4: RED 3/3, then GREEN 3/3 plus 1/1 in r2. |
| DRAFT-05 | SATISFIED | Truth 5. |
| PROTO-02 (note) | SATISFIED for this phase | The `dossier` skill routes to `dossier-draft`. The requirement is completed incrementally across phases. |

No orphaned requirements. `.planning/REQUIREMENTS.md` now shows DRAFT-01..05 as `[x]` / Complete and the ROADMAP Phase 5 line is checked, so the iter1 bookkeeping warning is closed.

### Anti-Patterns

No unreferenced TBD/FIXME/XXX markers were found in the changed files. The review-fix notes say the R5-M1/A5-F1 pins in `tests/test-skill-draft.sh` and `tests/test-skill-ingest.sh` previously sat after `finish` (which exits) and never ran. Moving them before it is confirmed by the passing runs of both files.

### Comparison with iter1

- Gaps closed: none were open. The review findings R5-M1, R5-m2, A5-F1 to A5-F5, A5-F8 and R6-1 to R6-6 were fixed in the fix rounds. R6-1, R6-4 and R6-2 were reproduced here (see the E5 table).
- Regressions: none. All suites that passed in iter1 still pass, with larger counts (selftest-draft 477 to 532).
- Evidence: the harness now gates `handback_before_review`, `lint_after_last_draft_edit` and `history_edit_before_review`. The r2 evidence is GREEN on the first two in 4/4 runs.

### Human Verification Required

None.

## Warnings (non-blocking)

1. **`history_edit_before_review` is not recorded in the stored r2 `summary.tsv`.** The column was added in round 3 (R6-6), after the r2 runs. Only `handback_before_review` and `lint_after_last_draft_edit` appear in the stored columns. The claim that all four r2 flows have 0 history edits before the reviewer's completion comes from the coder's replay in `05-REVIEW-FIX.md`. I did not independently reproduce it, since I was told not to re-run the paid scenarios. It is a minor evidence gap, not a failed truth, because `handback_before_review=0` and `lint_after_last_draft_edit=yes` are recorded.
2. **`green-plugin-r2/plugin-2` departs from the documented order.** It edited the history before running the linter (events 43/45 before 47), against the order review, apply, lint, history, report. The review-fix notes record this and say it is not gated. The lint ran after the last draft edit and covered the history lines, so the outcome is sound.
3. **Small sample and one model.** GREEN is 3 English runs and 1 French run, all on claude-sonnet-5-5. The stated gate is met but this is not statistical proof.
4. **The inline-review and no-linter paths are specified and contract-tested, but no scenario exercises them.** No scenario forces a harness without subagents.
5. **E5 is a mechanical net, not a complete one.** See the override above. Abbreviations, nicknames, translations and homoglyphs outside the table depend on `doctrine-reviewer` alone.

## Gaps Summary

No gaps. All 5 ROADMAP criteria and DRAFT-01..05 hold after the fix rounds. One override is applied (05 D-09, E5 scope). The free suites pass, the round-3 E5 cases behave as specified, and the stored r2 evidence is GREEN against the harness criteria that existed when it was recorded.

---

_Verified: 2026-10-12_
_Verifier: Claude (gsd-verifier)_
