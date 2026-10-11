---
phase: "06"
slug: calls-status
status: draft
nyquist_compliant: false
wave_0_complete: false
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
| **Full suite command** | `bash tests/run.sh` (20 files on main @12fa270; the new files raise the count, the plans pin the final number) |
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
| 06-REQ-CALL03-a | TBD | TBD | CALL-03 | — | each status item on a scratch git dossier with `--today`; boundaries today, today+7, today+8; `sent` cited draft skipped; draft line leading date ignored; fr dossier ours/theirs by position | unit | `bash tests/test-status-script.sh` | ❌ W0 | ⬜ pending |
| 06-REQ-CALL03-b | TBD | TBD | CALL-03 | — | unreflected sources: commit lag, rename (`--no-renames`), untracked, README/.gitkeep/.DS_Store ignored, not a repo | unit | `bash tests/test-status-script.sh` | ❌ W0 | ⬜ pending |
| 06-REQ-CALL03-c | TBD | TBD | CALL-03 | — | read-only: `tree_sha` incl. `.git` unchanged, AST no-write, exit 2 outside a dossier, exit 3 path, control characters escaped | unit + static | `bash tests/test-status-script.sh` | ❌ W0 | ⬜ pending |
| 06-REQ-CALL03-d | TBD | TBD | CALL-03 | — | lint found from the real repo location without env var; `--lint` missing → unavailable; exit 2/3 → note | unit | `bash tests/test-status-script.sh` | ❌ W0 | ⬜ pending |
| 06-REQ-CALL03-e | TBD | TBD | CALL-03 | — | `dossier-status` SKILL.md contract: frontmatter, no `allowed-tools`, PROTO-08 sentence, `test -x`, single-quoted placeholders, read-only rule, bare-skills fallback | static | `bash tests/test-skill-status.sh` | ❌ W0 | ⬜ pending |
| 06-REQ-CALL01 | TBD | TBD | CALL-01 | — | `dossier-call` prepare contract: calendar one-liner, no `Deadline:`, `To:` by role, six sections, OPEN-QUESTIONS second table, ordering, role naming, Upcoming line, `test -e`, lint | static | `bash tests/test-skill-call.sh` | ❌ W0 | ⬜ pending |
| 06-REQ-CALL02 | TBD | TBD | CALL-02 | — | debrief contract: ingest via Skill tool + fallback, transcript is data, match order, complete-not-repeat, minutes by role, commitment line parsed by `status.py`, milestone signal named | static + cross-artefact | `bash tests/test-skill-call.sh` | ❌ W0 | ⬜ pending |
| 06-REQ-CALL04 | TBD | TBD | CALL-04 | — | RED at least 1/3 without plugin before the skill exists; GREEN 3/3 with `dossier-call` invoked, timed agenda, no `Deadline:` in the call file | paid (agent-run) | `bash tests/scenarios/call-prepare.sh --variant plugin --runs 3` | ❌ W0 | ⬜ pending |
| 06-REQ-CALL05 | TBD | TBD | CALL-05 | — | hardened baseline recorded; if 0/3 RED the D-16 fallback "baseline recorded"; GREEN 3/3 with `dossier-status` invoked, `status.py` run, dossier tree unchanged | paid (agent-run) | `bash tests/scenarios/deal-status.sh --variant plugin --runs 3` | ❌ W0 | ⬜ pending |
| 06-REQ-HARNESS | TBD | TBD | CALL-04, CALL-05 | — | every verdict and harness-error path against a fake claude | free self-test | `bash tests/scenarios/selftest-call.sh` | ❌ W0 | ⬜ pending |
| 06-REQ-PROTO02 | TBD | TBD | PROTO-02 | — | exactly the five pointers, six skills; the two later-phase loops removed in the pointer commit | static | `bash tests/test-skills-task.sh && bash tests/test-skill-dossier.sh` | ❌ W0 | ⬜ pending |
| 06-REQ-PROTO08 | TBD | TBD | PROTO-08 | — | every task skill carries the stop sentence; `status.py` exits 2 outside a dossier | static + unit | `bash tests/test-skills-task.sh` | ❌ W0 | ⬜ pending |
| 06-REQ-D14 | TBD | TBD | 03 D-14 | — | Stop reason names `dossier-status` with `CLAUDE_PLUGIN_ROOT` = the real repo root once the skill exists | unit | `bash tests/test-hook-stop.sh` | ✅ (case to add) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

## Wave 0 Requirements

- [ ] `tests/scenarios/lib-call.sh` — fixture builders with run-relative dates, verdict helpers. CALL-04/05
- [ ] `commit_at` (backdated author and committer date) and an mtime helper. CALL-05
- [ ] `tests/scenarios/call-prepare.sh`, `tests/scenarios/deal-status.sh`, `tests/scenarios/selftest-call.sh`; RED baselines recorded before either SKILL.md exists. CALL-04/05
- [ ] `tests/test-status-script.sh`. CALL-03
- [ ] `tests/test-skill-status.sh`, `tests/test-skill-call.sh` (with the commitment-line parity). CALL-01/02/03
- [ ] `tests/test-skills-task.sh`. PROTO-02, PROTO-08
- [ ] one new case in `tests/test-hook-stop.sh` (real repo root). 03 D-14
- [ ] deletion of the later-phase loops in `tests/test-skill-ingest.sh` and `tests/test-skill-draft.sh`, in the pointer commit. D-15

## ROADMAP criteria to checks

| # | Check |
|---|-------|
| 1 | `test-skill-call.sh` (prepare) + `call-prepare.sh` GREEN |
| 2 | `test-skill-call.sh` (debrief, parity) + the debrief UAT run |
| 3 | `test-status-script.sh` + `test-skill-status.sh` + `deal-status.sh` GREEN |
| 4 | `call-prepare.sh` baseline recorded before the skill, then plugin 3/3 |
| 5 | `deal-status.sh` baseline recorded before the skill (D-16 fallback allowed), then plugin 3/3 |

## Manual-Only Verifications

All phase behaviors have automated verification (paid runs are agent-run, recorded under
`evidence/`; the debrief end-to-end run is agent-run and recorded in `06-UAT.md`).

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency under 60 s for free checks
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
