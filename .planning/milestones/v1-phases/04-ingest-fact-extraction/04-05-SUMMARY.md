---
phase: 04-ingest-fact-extraction
plan: 05
subsystem: testing
tags: [scenario-harness, headless-claude, writing-skills-green, pdf-ingest, validation]
requires:
  - phase: 04-ingest-fact-extraction
    provides: RED baseline (04-02), extract-text.sh and make-pdf.py (04-03), dossier-ingest skill and fact-extractor agent (04-04)
provides:
  - "spec section 4 tree and 4.1 and CLAUDE.md amended for the dossier-ingest folder and its private scripts (D-05)"
  - "tests/scenarios/ingest-pdf.sh: the paid, agent-run PDF ingest scenario of ROADMAP criterion 1 (19-column summary.tsv, exit 0/1/2)"
  - "evidence/green-plugin/: INGEST-05 GREEN 3 of 3 with dossier-ingest invoked and a correction observed"
  - "evidence/pdf-plugin/: ROADMAP criterion 1, one GREEN run on a generated PDF"
  - "04-VALIDATION.md finalized: 14 of 14 rows green, nyquist_compliant and wave_0_complete true"
affects: [verify-work, phase-5]
key-files:
  created:
    - tests/scenarios/ingest-pdf.sh
    - .planning/phases/04-ingest-fact-extraction/evidence/green-plugin/ (11 files)
    - .planning/phases/04-ingest-fact-extraction/evidence/pdf-plugin/ (5 files)
  modified:
    - docs/superpowers/specs/2026-09-16-client-dossier-design.md
    - CLAUDE.md
    - skills/dossier-ingest/SKILL.md
    - tests/test-skill-ingest.sh
    - .planning/phases/04-ingest-fact-extraction/04-VALIDATION.md
key-decisions:
  - "The dossier-ingest frontmatter carries no allowed-tools: the key makes the Skill tool ask for approval, which a headless or unattended session denies, so the skill never loads."
  - "The first date of Last updated: is the day of the edit, never the source's date."
requirements-completed: [INGEST-01, INGEST-02, INGEST-03, INGEST-04, INGEST-05, INGEST-06]
duration: 75min
completed: 2026-10-10
status: complete
commits: 6
plan_head_before: d1bebcb0d959568a9441a83d40369d115c9e5906
plan_head_after: e759a72b4f5f51ede1d5c4fe7a53e4a05e5baa83
actuals:
  tokens: 22000
  tasks: 3
  commits: 6
---

# Phase 4 Plan 05: Spec and CLAUDE.md, PDF scenario, GREEN run and validation Summary

**The plugin variant of the INGEST-05 scenario is GREEN 3 of 3 (dossier-ingest invoked, the seeded 15,000 line corrected in every run), a generated PDF is filed, extracted by extract-text.sh and applied with `p. N` locators in one GREEN run, after two refinement rounds that closed two real loopholes; 04-VALIDATION.md is finalized.**

`commits` counts the six commits before this SUMMARY's own commit (measured `git rev-list --count d1bebcb..e759a72`). The per-plan ledger file was not written (same as plans 04-01, 04-02, 04-04); `plan_head_before` is the phase branch tip `d1bebcb` the worktree was fast-forwarded to.

## Commits

| Task | Commit | Message |
|------|--------|---------|
| 1 | `c7d0e41` | docs(04-05): amend the spec tree and CLAUDE.md for the ingest skill |
| 2 (script) | `066e36f` | test(04-05): add the end-to-end PDF ingest scenario (ROADMAP criterion 1) |
| 2 (round 1) | `29765f9` | fix(04-05): close the approval-gated skill load in the ingest skill |
| 2 (round 2) | `57ec04c` | fix(04-05): close the source-date Last updated loophole in the ingest skill |
| 2 (evidence) | `01dcff7` | test(04-05): record the GREEN run of the what-did-we-learn scenario and the PDF ingest run |
| 3 | `e759a72` | docs(04-05): finalize the phase 4 validation contract |

## Task 1: spec and CLAUDE.md

- Spec section 4 tree: `dossier-ingest/` now lists `SKILL.md`, `scripts/file_source.py` and `scripts/extract-text.sh`; `extract-text.sh` is gone from the root `scripts/` block (`lint.py` and `release.sh` remain). The private-scripts paragraph names `dossier-init` and `dossier-ingest`. Section 4.1 says the source is filed through `file_source.py` (a copy, or a URL staged first), never the Write tool. Section 6 (bare skills, `pdftotext`) still reads true and was left alone.
- CLAUDE.md: Phase 3 delivered, Phase 4 state, `skills/dossier-ingest/scripts/{file_source.py,extract-text.sh}` as the second private-mechanics example (bash 3.2), and Commands lines for the six new tests, `selftest-ingest.sh`, `ingest-transcript.sh` and `ingest-pdf.sh`.
- The plan's verify passed (tree counts 1 and 1, every path in CLAUDE.md); `bash tests/run.sh` stayed green.

## Task 2: the PDF scenario and its two free controls

`tests/scenarios/ingest-pdf.sh` follows the plan's contract (named constants, preflight, 19 columns, GREEN/INCOMPLETE verdict, exit 0/1/2, last line `SCENARIO ingest-pdf: PASS|FAIL`). `bash -n` clean; `bash tests/run.sh` names nothing under `tests/scenarios/`. The harness files (`ingest-transcript.sh`, `lib-scenario.sh`, `selftest-ingest.sh`, `make-pdf.py`) are untouched. Two throwaway fake-claude controls (fake written into a `mktemp -d` folder outside the repository) ran before any paid run and the script was committed alone:

| Control | Exit | Verdict | filed_name | page_lines | other |
|---|---|---|---|---|---|
| no-op (fake changes nothing) | 1 | INCOMPLETE | `none` | 0 | right_file no, refreshed none |
| scripted (copy, real extract-text.sh, ACTORS.md bullet with `p. 2`, `Last updated:` today) | 0 | GREEN | `sources/received/2026-10-06_onboarding-pack.pdf` | 1 | text_extracted yes, filed_date_is_content yes |

Pre-flight before the paid runs: `selftest-ingest.sh` PASS 165 FAIL 0, `selftest.sh` PASS 71 FAIL 0, `tests/run.sh` 17 files 0 failed.

## Paid runs, every round

Prompt kind of the transcript runs: **plain** (the RED baseline was 3 of 3 RED on the plain prompt, no pressured baseline exists). Model `claude-sonnet-5-5`, Claude Code `2.1.296`. Each run capped at `SCENARIO_BUDGET_USD=1`. Costs are the `total_cost_usd` of each result event.

| Round | Skill text | Run | Verdict | Cost USD | What happened |
|---|---|---|---|---|---|
| 1 | with `allowed-tools` | PDF | INCOMPLETE | 0.0934674 | Skill call denied (see loophole 1); filed by hand with a raw `pdftotext -layout`, no page markers (text_extracted no), no skill load |
| 2 | no `allowed-tools` | PDF | INCOMPLETE | 0.1269659 | Skill loaded, filed `2026-10-06_supplier-onboarding-pack.pdf`, text_extracted yes, but `Last updated: 2026-10-06` (the source's date): refreshed no |
| 3 | + edit-day date | PDF | **GREEN** | 0.1294105 | all conditions met |
| 3 | same | transcript plugin-1 | **GREEN** | 0.1140270 | corrected yes |
| 3 | same | transcript plugin-2 | **GREEN** | 0.1161820 | corrected yes |
| 3 | same | transcript plugin-3 | **GREEN** | 0.1063336 | corrected yes |

Transcript runs of rounds 1 and 2 were skipped by the plan's rule (the skill was about to change).

### Cost

| Item | USD |
|---|---|
| RED baseline, plan 04-02 (3 runs) | 0.0970635 |
| Round 1, PDF | 0.0934674 |
| Round 2, PDF | 0.1269659 |
| Round 3, PDF | 0.1294105 |
| Round 3, 3 transcript runs (0.1140270 + 0.1161820 + 0.1063336) | 0.3365426 |
| **Total Phase 4 paid runs** | **0.7834499** |

Under the 2 USD cap (39 percent used); this plan alone spent 0.6863864.

### Refinement rounds (2 of the 3 allowed)

1. **Approval-gated skill load (`29765f9`).** The agent's `Skill` call for `client-dossier:dossier-ingest` came back "Permission for this tool use was denied ... What required approval: Execute skill: client-dossier:dossier-ingest". The skill's frontmatter carried `allowed-tools`, which is not a safe-only property, so the Skill tool asks for approval, and an unattended session denies it. The agent then followed the `dossier` skill by hand and ran `pdftotext -layout` itself (no page markers, so every fact got `p. 1`). Fix: the `allowed-tools` line is removed from `skills/dossier-ingest/SKILL.md`. `tests/test-skill-ingest.sh` pinned the old line verbatim, so that one assertion now asserts the key is absent, with the observed reason in a comment (a deliberate replacement, not a weakening: the old pin would block the only working form). Rules block untouched.
2. **Source date written as `Last updated:` (`57ec04c`).** The skill loaded and everything was right except the first `Last updated:` date, set to the pack's issue date 2026-10-06 instead of the day of the edit; the skill's only example had both dates equal. Fix: the skill now says the first date is the day of the edit (`date +%F`), never the source's, with an example whose two dates differ, and the correction example uses two different dates. Rules block untouched.

Tests kept green after each round: `test-skill-ingest` 82/0, `test-ingest-guard` 153/0, `test-agent-fact-extractor` 57/0, `test-skill-dossier` 128/0, `test-skill-shape` 30/0.

## INGEST-05: RED versus GREEN (same harness, fixture and plain prompt)

| | RED baseline (no plugin, 04-02) | GREEN (plugin, round 3) |
|---|---|---|
| Verdicts | RED 3/3 | GREEN 3/3 |
| filed_name | none, none, none | `sources/transcripts/2026-10-10_kickoff-call.txt` in all three |
| timestamped_lines | 0, 0, 0 | 7, 8, 9 |
| refreshed | none | yes in all three |
| lint_exit / warnings | 0 / 0 | 0 / 0 in all three |
| ingest_skill | not applicable | yes in all three (no denied call in any of the three streams) |
| extractor_dispatched | not applicable | no in all three |
| corrected (ROADMAP criterion 3) | no (seeded line untouched) | yes in all three |
| cost per run USD | 0.0328 / 0.0320 / 0.0323 | 0.1140 / 0.1162 / 0.1063 |

Filed name in every run: `sources/transcripts/2026-10-10_kickoff-call.txt` (D-01: the transcript is "today's call", so content date and filing date coincide). Timestamped lines of run 1 (from its diff): Jane Doe and Tom Becker in ACTORS (`@00:04`), the accounts@ mailing rule in CHANNELS (`@00:41`), the commitments for 2026-10-24 (`@01:32`) and 2026-11-14 (`@01:05`) in HISTORY, the phase-two question as an OPEN-QUESTIONS table row (`@02:10`), and the correction in place of the seeded line: `Jane Doe (Acme Consulting) confirmed the phase one budget at 18,000 euros on 2026-10-10 (call 2026-10-10 @00:19) (corrects a line dated 2026-10-01).` Runs 2 and 3 carry the same correction line byte for byte. `Last updated:` in each changed file reads `2026-10-10, after the kickoff call of 2026-10-10`.

## ROADMAP criterion 1: the PDF run (round 3, GREEN)

| Column | Value |
|---|---|
| verdict | GREEN |
| filed_name | `sources/received/2026-10-06_onboarding-pack.pdf` (sha256 equals the fixture's) |
| text_extracted | yes: `2026-10-06_onboarding-pack.txt` holds `--- page 1 ---`, `--- page 2 ---`, `--- page 3 ---` (written by extract-text.sh, exit 0) |
| page_lines | 3 |
| right_file | yes (`### Priya Raman (Acme Consulting)` heading and bullet in ACTORS.md, `p. 2`) |
| refreshed | yes (`Last updated: 2026-10-10, after the onboarding pack of 2026-10-06` in ACTORS, HISTORY, LEARNINGS) |
| lint_exit / warnings | 0 / 0 |
| ingest_skill | yes (call not denied) |
| extractor_dispatched | no |
| filed_date_is_content | yes (D-01: named with the pack's issue date 2026-10-06) |
| model / version / cost | claude-sonnet-5-5 / 2.1.296 / 0.1294105 |

Added `p. N` lines: HISTORY.md (`p. 1`, the pack was issued 2026-10-06), ACTORS.md (`p. 2`, procurement contact), LEARNINGS.md (`p. 3`, 45-day payment). Independent re-derivation from the committed `pdf-1.diff` and `pdf-1.lint` (plan verify): the added `p. N` bullet, the added `Last updated:` line dated after the backdate, the filed `.pdf` and `.txt` in the untracked list and `0 error(s), 0 warning(s)` all hold; `Priya Raman` and `onboarding-pack` appear nowhere under `skills/` or `agents/`.

## Verification

- `bash tests/run.sh`: `TOTAL: 17 files, 0 failed` (103 s wall clock).
- `bash tests/scenarios/selftest-ingest.sh`: PASS 165 FAIL 0. `bash tests/scenarios/selftest.sh`: PASS 71 FAIL 0. `bash -n tests/scenarios/ingest-pdf.sh`: clean.
- `claude plugin validate .`: exit 0, "Validation passed with warnings", the two known warnings (`author` missing in plugin.json; the root CLAUDE.md not loaded as plugin context).
- Evidence file counts: red-baseline 11, green-plugin 11, pdf-plugin 5; `scrub_check` clean on both new folders (no `sk-ant-`, no git email; home-path warnings only, as in the existing evidence).
- Task 2 verify and acceptance greps (rows, columns, metadata, scrub, no `test-*` in `tests/scenarios/`): all pass. No commit of this plan touches `ingest-transcript.sh`, `lib-scenario.sh`, `selftest-ingest.sh` or `make-pdf.py`.
- 04-VALIDATION.md: 14 of 14 rows green, `nyquist_compliant: true`, `wave_0_complete: true`, `status:` left as `draft`. One sign-off item stays unticked, honestly: "Feedback latency < 90s", because the full suite takes 103 s.

## Deviations from Plan

### Auto-fixed

**1. [Rule 1 - Bug] The ingest skill could not be loaded without approval.** Found in round 1 (see above). Fix in `29765f9`. Files: `skills/dossier-ingest/SKILL.md`, `tests/test-skill-ingest.sh` (the second file is outside the task's `files_modified` list; it pinned the buggy line, so it had to change with it).

**2. [Rule 1 - Bug] `Last updated:` ambiguity.** Found in round 2. Fix in `57ec04c`. File: `skills/dossier-ingest/SKILL.md`.

### Observations for the orchestrator (not fixed, out of scope)

- **`skills/dossier-init/SKILL.md` has the same `allowed-tools` frontmatter** (`Bash(${CLAUDE_SKILL_DIR}/scripts/init.py *)`). By the round 1 finding it also asks for approval when invoked through the Skill tool in a session nobody can answer. Not touched (Phase 2 artefact, not in this plan); worth a follow-up fix in the same way, with its test pin changed.
- **`ingest_skill` counts a denied `Skill` call as yes.** `jsonl_skill_invoked` in the frozen `lib-scenario.sh` matches the `tool_use` only. In round 1 the column read `yes` although the skill never loaded; the INCOMPLETE verdict came from other conditions. For the three GREEN transcript runs and the GREEN PDF run, the streams were checked for tool_result denials and none exists. A later hardening of the helper (a result check) belongs to a change of the shared harness, which this plan could not make.
- **`fact-extractor` was never dispatched** (extractor_dispatched no in all four GREEN runs): the main agent did the extraction inline. Recorded, not gating (D-12), valid by spec section 6, but the agent's own path (isolated reading of a long source) has no behavioural evidence yet.
- Environment: the worktree was fast-forwarded to the phase branch as authorised; the sandbox refuses compound git commands, so commits used single `/usr/bin/git` calls with `-F <message file>`. `hooks/`, `.planning/phases/05-*`, `STATE.md`, `ROADMAP.md` and `REQUIREMENTS.md` untouched.

## Known Stubs

None.

## Threat Flags

None. The new script only builds scratch dossiers and runs the already-isolated harness; T-04-32 to T-04-37 mitigations hold: verdicts computed by the scripts, no relabelled harness error, every round reran the PDF run (transcript runs only skipped where the plan says so), scrubbed evidence, fixture tokens absent from `skills/` and `agents/`, controls run before the first paid run.

## Self-Check: PASSED

- FOUND: tests/scenarios/ingest-pdf.sh, evidence/green-plugin/ (11 files), evidence/pdf-plugin/ (5 files), this SUMMARY.
- FOUND commits: c7d0e41, 066e36f, 29765f9, 57ec04c, 01dcff7, e759a72 (checked with `git merge-base --is-ancestor`).
