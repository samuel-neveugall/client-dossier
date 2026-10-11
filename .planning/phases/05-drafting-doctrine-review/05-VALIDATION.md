---
phase: "05"
slug: drafting-doctrine-review
status: draft
nyquist_compliant: true
wave_0_complete: true
created: "2026-10-10"
---

# Phase 5 — Validation Strategy

> Per-phase validation contract. Source: 05-RESEARCH.md "Validation Architecture". The
> per-task rows below are seeded at requirement level; the planner binds them to task ids.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | bash 3.2 + python3 stdlib, hand-rolled assertions in `tests/lib.sh` |
| **Config file** | none; `tests/run.sh` globs top-level `tests/test-*.sh` |
| **Quick run command** | the touched file: `bash tests/test-skill-draft.sh`, `bash tests/test-agent-doctrine-reviewer.sh`, `bash tests/test-draft-shapes.sh` |
| **Full suite command** | `bash tests/run.sh` (expected 20 files after this phase: 17 + 3) |
| **Free harness proof** | `bash tests/scenarios/selftest-draft.sh` (+ `selftest.sh`, `selftest-ingest.sh` when `lib-scenario.sh` changes) |
| **Paid (agent-run, NOT in run.sh)** | `tests/scenarios/draft-reply.sh --variant baseline --runs 3` before the skill exists; `--variant plugin --runs 3` after; `tests/scenarios/draft-deadline-fr.sh --runs 1` |
| **Estimated runtime** | run.sh under 60 s; paid runs about 0.08 USD each |

## Sampling Rate

- **After every task commit:** the touched test file, plus `bash tests/test-skill-dossier.sh` when a skill changes
- **After every plan wave:** `bash tests/run.sh` and the three self-tests
- **Before verify-work:** full suite green, `claude plugin validate .` exit 0 (two known warnings), paid gates met
- **Max feedback latency:** 60 seconds (free checks)

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 05-01-T1 | 01 | 1 | DRAFT-04 | T-05-15 | `build_dossier` default unchanged; the D-07 identity makes only the end client confidential; tracer path RED and GREEN against the fake claude | free self-test | `bash tests/scenarios/selftest-draft.sh && bash tests/scenarios/selftest.sh && bash tests/scenarios/selftest-ingest.sh` | ✅ | green |
| 05-01-T2 | 01 | 1 | DRAFT-04 | T-05-11 | G1-G6 mechanical; leak checked twice; harness errors never verdicts | free self-test | `bash tests/scenarios/selftest-draft.sh` | ✅ | green |
| 05-01-T3 | 01 | 1 | DRAFT-04 | T-05-09, T-05-12 | RED baseline recorded in a tree without `skills/dossier-draft/SKILL.md`, evidence scrubbed | paid (agent-run) | 05-01 task 3 `<verify>` (baseline commit tree and rows in `evidence/red-baseline/summary.tsv`) | ✅ | green |
| 05-02-T1 | 02 | 1 | DRAFT-03, DRAFT-05 | T-05-07, T-05-08, T-05-16, T-05-17 | reviewer tools exactly Read, Grep, Glob; read list; data not instructions; parity once the skill exists | static | `bash tests/test-agent-doctrine-reviewer.sh` | ✅ | green |
| 05-02-T2 | 02 | 1 | DRAFT-03 | T-05-18 | heading positions hold in the en and fr templates | static | `bash tests/test-agent-doctrine-reviewer.sh` | ✅ | green |
| 05-03-T1 | 03 | 2 | DRAFT-01, DRAFT-02, DRAFT-05 (D-08) | T-05-01..T-05-06, T-05-10, T-05-19, T-05-20, T-05-21 | exact command set, single quotes, slug and kind validated, never sent, no overwrite, findings as data, parity, pointer, ancestry | static + unit | `bash tests/test-skill-draft.sh && bash tests/test-draft-shapes.sh && bash tests/test-agent-doctrine-reviewer.sh && bash tests/test-skill-dossier.sh && bash tests/test-skill-ingest.sh` | ✅ | green |
| 05-03-T2 | 03 | 2 | DRAFT-01, DRAFT-02, DRAFT-05 | T-05-01, T-05-06 | lint reports E1-E5 the fallback names; lint accepts a sent status, so the skill rule is load-bearing | unit | `bash tests/test-draft-shapes.sh && bash tests/run.sh` | ✅ | green |
| 05-04-T1 | 04 | 2 | DRAFT-01, DRAFT-02 | T-05-22 | French run GREEN only on a real French draft with its deadline | free self-test | `bash tests/scenarios/selftest-draft.sh` | ✅ | green |
| 05-04-T2 | 04 | 2 | DRAFT-01, DRAFT-02 | T-05-22, T-05-23, T-05-24 | each GREEN condition removed is INCOMPLETE; baseline harness untouched | free self-test | `bash tests/scenarios/selftest-draft.sh && bash tests/scenarios/selftest.sh && bash tests/scenarios/selftest-ingest.sh` | ✅ | green |
| 05-05-T1 | 05 | 3 | DRAFT-01..DRAFT-05 | T-05-25, T-05-26, T-05-30 (T-05-01 live) | GREEN 3/3 with G1-G6 and the French run GREEN on one skill text; reviewer tools observed at runtime | paid (agent-run) | 05-05 task 1 `<verify>` (re-derived from `evidence/green-plugin/` and `evidence/fr-deadline/`) | ✅ | green |
| 05-05-T2 | 05 | 3 | — (docs) | T-05-28 | CLAUDE.md lists every new command; spec §4 needs no amendment | static | 05-05 task 2 `<verify>` | ✅ | green |
| 05-05-T3 | 05 | 3 | all | — | full suite 20 files, self-tests, plugin validate | static | `bash tests/run.sh` (20 files, 0 failed) and the three self-tests | ✅ | green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

## Wave 0 Requirements

- [x] `tests/scenarios/draft-reply.sh` + `tests/scenarios/lib-draft.sh` + `tests/scenarios/selftest-draft.sh` + `build_dossier` identity arguments in `lib-scenario.sh` (plan 05-01). DRAFT-04
- [x] `tests/test-agent-doctrine-reviewer.sh`. DRAFT-03, DRAFT-05
- [x] `tests/test-skill-draft.sh` incl. git-ancestry gate on `evidence/red-baseline/summary.tsv`. DRAFT-01/02/05
- [x] `tests/test-draft-shapes.sh`. DRAFT-01/02
- [x] `tests/scenarios/draft-deadline-fr.sh`. ROADMAP criterion 1
- [x] edit `tests/test-skill-ingest.sh:290` (drops `dossier-draft` from the "not yet" list). D-08

## ROADMAP criteria to checks

| # | Check |
|---|-------|
| 1 | `draft-reply.sh` G1, G2, G5 (en) + `draft-deadline-fr.sh` + `test-draft-shapes.sh` |
| 2 | static pins (`Disagreements`, never silently dropped, consent rule) + G6 dispatch completed |
| 3 | G2 (lint, `Status: draft`), G4 (history), never-sent pin |
| 4 | `draft-reply.sh` gates: baseline at least 1 RED of 3, plugin 3 of 3 GREEN |
| 5 | reviewer/SKILL parity + inline sentence + lint-absent pins |

## Manual-Only Verifications

All phase behaviors have automated verification (paid runs are agent-run, recorded under `evidence/`).

Agent-run behavioural rows, as executed:

| Row | Prompt kind | Result | Evidence |
|-----|-------------|--------|----------|
| RED baseline (no plugin) | `plain` | RED 3 of 3; the 05-01 fallback (pressured branch) did not apply | `evidence/red-baseline/` |
| GREEN (`--plugin-dir`) | `plain` (same as the baseline) | GREEN 3 of 3, G1-G6 held, dossier-draft invoked and doctrine-reviewer dispatched and completed in every run | `evidence/green-plugin/` |
| French deadline run | French prompt of `draft-deadline-fr.sh` | GREEN 1 of 1: `outbound/mails/2026-10-11_reponse-date-audit.md`, `Deadline: 2026-10-30`, French body | `evidence/fr-deadline/` |

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency under 60 s for free checks
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** verified by the executor on 2026-10-11; `status` is left to /gsd-validate-phase
