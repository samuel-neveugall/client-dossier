---
phase: "06"
slug: calls-status
status: draft
nyquist_compliant: true
wave_0_complete: true
created: "2026-10-11"
---

# Phase 6 — Validation Strategy

> Per-phase validation contract. Source: 06-RESEARCH.md "Validation Architecture". The
> per-task rows below are seeded at requirement level; the planner binds them to task ids.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | bash 3.2 + python3 stdlib, hand-rolled assertions in `tests/lib.sh` |
| **Config file** | none; `tests/run.sh` globs top-level `tests/test-*.sh` |
| **Quick run command** | the touched file: `bash tests/test-status-script.sh`, `bash tests/test-skill-status.sh`, `bash tests/test-skill-call.sh`, `bash tests/test-skills-task.sh` |
| **Full suite command** | `bash tests/run.sh` (24 files at the end of Phase 6) |
| **Free harness proof** | `bash tests/scenarios/selftest-call.sh` (+ `selftest.sh`, `selftest-ingest.sh`, `selftest-draft.sh` whenever `lib-scenario.sh` changes) |
| **Paid (agent-run, NOT in run.sh)** | `tests/scenarios/call-prepare.sh --variant baseline --runs 3` and `tests/scenarios/deal-status.sh --variant baseline --runs 3` before each SKILL.md exists; `--variant plugin --runs 3` after; one debrief UAT run |
| **Estimated runtime** | run.sh under 60 s; paid runs about 0.05-0.20 USD each |

## Sampling Rate

- **After every task commit:** the touched test file, plus `bash tests/test-skill-dossier.sh` when a skill changes
- **After every plan wave:** `bash tests/run.sh` and every `tests/scenarios/selftest*.sh`
- **Before verify-work:** full suite green, `claude plugin validate .` exit 0 (two known warnings), paid gates met, evidence under `evidence/` after `scrub_check`
- **Max feedback latency:** 60 seconds (free checks)

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 06-01-T1 | 06-01 | 1 | CALL-04 | T-06-02, T-06-06 | prepare-call harness end to end, lib-scenario.sh additions only | free self-test | `bash tests/scenarios/selftest-call.sh` | ✅ | green |
| 06-01-T2 | 06-01 | 1 | CALL-05 | T-06-02, T-06-07 | deal-status harness on the hardened fixture, every verdict and error path | free self-test | `bash tests/scenarios/selftest-call.sh` | ✅ | green |
| 06-01-T3 | 06-01 | 1 | CALL-04, CALL-05 | T-06-01, T-06-03, T-06-05 | both baselines recorded RED 3/3 before either SKILL.md exists, scrubbed (D-16 fallback not needed) | paid (agent-run), committed evidence | `ls evidence/call-red-baseline evidence/status-red-baseline` (11 and 14 files) and `summary.tsv` | ✅ | green |
| 06-02-T1 | 06-02 | 1 | CALL-03, PROTO-08 | T-06-10 | status.py CLI, exits 2 and 3, static pins | unit + static | `bash tests/test-status-script.sh` | ✅ | green |
| 06-02-T2 | 06-02 | 1 | CALL-03 | T-06-12 | commitments, upcoming, overdue drafts, stale files, status line | unit | `bash tests/test-status-script.sh` | ✅ | green |
| 06-02-T3 | 06-02 | 1 | CALL-03, PROTO-08 | T-06-08, T-06-09, T-06-13, T-06-14 | unreflected sources, lint variants, read-only, escaping | unit + static | `bash tests/test-status-script.sh` | ✅ | green |
| 06-03-T1 | 06-03 | 2 | CALL-03, PROTO-02, PROTO-08 | T-06-15, T-06-16, T-06-17, T-06-18 | dossier-status skill contract and its pointer | static | `bash tests/test-skill-status.sh && bash tests/test-skill-dossier.sh` | ✅ | green |
| 06-03-T2 | 06-03 | 2 | CALL-03, PROTO-08 | T-06-19 | status.py on the CALL-05 fixture reports the three seeds; Stop reason names dossier-status | unit | `bash tests/test-skill-status.sh && bash tests/test-hook-stop.sh` | ✅ | green |
| 06-04-T1 | 06-04 | 3 | CALL-01, CALL-02 | T-06-20, T-06-21, T-06-22, T-06-23, T-06-24, T-06-25, T-06-26 | dossier-call prepare and debrief contract, lint-clean call file, status.py parity | static + cross-artefact | `bash tests/test-skill-call.sh` | ✅ | green |
| 06-04-T2 | 06-04 | 3 | PROTO-02, PROTO-08 | T-06-19 | exactly five pointers over six skills; stop sentence in every task skill | static | `bash tests/test-skills-task.sh` | ✅ | green |
| 06-05-T1 | 06-05 | 4 | CALL-04, CALL-01 | T-06-27, T-06-28, T-06-29, T-06-31 | GREEN 3/3 with dossier-call invoked, section, order, no Deadline | paid (agent-run), committed evidence | `ls evidence/call-green-plugin` (11 files); `summary.tsv` 3 GREEN | ✅ | green |
| 06-05-T2 | 06-05 | 4 | CALL-05, CALL-03 | T-06-27, T-06-28, T-06-29, T-06-31 | GREEN 3/3 with dossier-status invoked, status.py run, tree unchanged | paid (agent-run), committed evidence | `ls evidence/status-green-plugin` (14 files); `summary.tsv` 3 GREEN | ✅ | green |
| 06-05-T3 | 06-05 | 4 | CALL-02, PROTO-08 | T-06-28, T-06-30 | debrief end to end and outside a dossier (06-UAT.md, 3 of 3 pass) | paid (agent-run), committed evidence | `ls evidence/uat` (7 files); `uat-summary.tsv` PASS | ✅ | green |
| 06-06-T1 | 06-06 | 5 | CALL-01..05, PROTO-02, PROTO-08 | T-06-32 | CLAUDE.md lists Phase 6 and every free command runs | static + run | `bash tests/test-status-script.sh && bash tests/test-skill-status.sh && bash tests/test-skill-call.sh && bash tests/test-skills-task.sh && bash tests/scenarios/selftest-call.sh` | ✅ | green |
| 06-06-T2 | 06-06 | 5 | CALL-01..05, PROTO-02, PROTO-08 | T-06-32, T-06-33 | spec §4 tree amended; traceability ticked; D-16 not applied (3 RED) | static | grep of the spec tree and `.planning/REQUIREMENTS.md` | ✅ | green |
| 06-06-T3 | 06-06 | 5 | CALL-01..05, PROTO-02, PROTO-08 | T-06-34 | full suite, four self-tests, plugin validation, evidence counts | full run | `bash tests/run.sh` (24 files, 0 failed) and `claude plugin validate .` | ✅ | green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

## Wave 0 Requirements

- [x] `tests/scenarios/lib-call.sh` — fixture builders with run-relative dates, verdict helpers. CALL-04/05
- [x] `commit_at` (backdated author and committer date) and an mtime helper. CALL-05
- [x] `tests/scenarios/call-prepare.sh`, `tests/scenarios/deal-status.sh`, `tests/scenarios/selftest-call.sh`; RED baselines recorded before either SKILL.md exists. CALL-04/05
- [x] `tests/test-status-script.sh`. CALL-03
- [x] `tests/test-skill-status.sh`, `tests/test-skill-call.sh` (with the commitment-line parity). CALL-01/02/03
- [x] `tests/test-skills-task.sh`. PROTO-02, PROTO-08
- [x] one new case in `tests/test-hook-stop.sh` (real repo root). 03 D-14
- [x] deletion of the later-phase loops in `tests/test-skill-ingest.sh` and `tests/test-skill-draft.sh`, in the pointer commit. D-15

## ROADMAP criteria to checks

| # | Check |
|---|-------|
| 1 | `test-skill-call.sh` (prepare) + `call-prepare.sh` GREEN |
| 2 | `test-skill-call.sh` (debrief, parity) + the debrief UAT run |
| 3 | `test-status-script.sh` + `test-skill-status.sh` + `deal-status.sh` GREEN |
| 4 | `call-prepare.sh` baseline recorded before the skill, then plugin 3/3 |
| 5 | `deal-status.sh` baseline recorded before the skill (D-16 fallback allowed), then plugin 3/3 |

## Manual-Only Verifications

All phase behaviors have automated verification; paid runs are agent-run and recorded under `evidence/`.

- CALL-04 baseline: prompt kind `plain`, RED 3 of 3 (the pressured attempt did not run, it was not needed); GREEN prompt kind `plain`, 3 of 3 on the second round (round 1 was 2 of 3 and was refined, not committed).
- CALL-05 baseline: prompt kind `pressured`, RED 3 of 3, so the D-16 fallback was not needed and no REQUIREMENTS or ROADMAP amendment applies; GREEN prompt kind `pressured`, 3 of 3.
- UAT (`06-UAT.md`): debrief end to end, pass; call request outside a dossier, pass; suite, manifest and scrub, pass. The widened milestone check of the UAT driver was accepted by the orchestrator.

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency under 60 s for free checks
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** verified by the executor on 2026-10-11; `status` is left to /gsd-validate-phase
