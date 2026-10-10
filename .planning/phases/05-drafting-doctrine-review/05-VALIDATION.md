---
phase: "05"
slug: drafting-doctrine-review
status: draft
nyquist_compliant: false
wave_0_complete: false
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
| 05-W0-a | 01 | 1 | DRAFT-04 | T-05-01 | harness leaves confidential name out of the fixture identity | free self-test | `bash tests/scenarios/selftest-draft.sh` | ❌ W0 | ⬜ pending |
| 05-W0-b | 01 | 1 | DRAFT-04 | — | baseline RED recorded without plugin, before SKILL.md exists | paid | `bash tests/scenarios/draft-reply.sh --variant baseline --runs 3` | ❌ W0 | ⬜ pending |
| 05-agent | 02 | 2 | DRAFT-03, DRAFT-05 | T-05-07, T-05-08 | reviewer tools exactly Read, Grep, Glob | static | `bash tests/test-agent-doctrine-reviewer.sh` | ❌ W0 | ⬜ pending |
| 05-skill | 03 | 3 | DRAFT-01, DRAFT-02, DRAFT-05 | T-05-02..06, T-05-10 | slug/kind validated, single quotes, never sent, no overwrite | static + unit | `bash tests/test-skill-draft.sh && bash tests/test-draft-shapes.sh` | ❌ W0 | ⬜ pending |
| 05-pointer | 03 | 3 | D-08 | — | `dossier` names `dossier-draft` | static | `bash tests/test-skill-dossier.sh && bash tests/test-skill-ingest.sh` | ✅ edit | ⬜ pending |
| 05-green | 04 | 4 | DRAFT-04 | T-05-01 | GREEN 3/3 with plugin, G1..G6 | paid | `bash tests/scenarios/draft-reply.sh --variant plugin --runs 3` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

## Wave 0 Requirements

- [ ] `tests/scenarios/draft-reply.sh` + `tests/scenarios/selftest-draft.sh` + `build_dossier` identity parameter in `lib-scenario.sh`. DRAFT-04
- [ ] `tests/test-agent-doctrine-reviewer.sh`. DRAFT-03, DRAFT-05
- [ ] `tests/test-skill-draft.sh` incl. git-ancestry gate on `evidence/red-baseline/summary.tsv`. DRAFT-01/02/05
- [ ] `tests/test-draft-shapes.sh`. DRAFT-01/02
- [ ] `tests/scenarios/draft-deadline-fr.sh`. ROADMAP criterion 1
- [ ] edit `tests/test-skill-ingest.sh:290` (drops `dossier-draft` from the "not yet" list). D-08

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

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency under 60 s for free checks
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
