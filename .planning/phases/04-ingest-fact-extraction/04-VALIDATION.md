---
phase: "04"
slug: ingest-fact-extraction
# status lifecycle: draft (seeded by plan-phase) -> validated (set by validate-phase)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-10-10"
---

# Phase 4 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Source: `04-RESEARCH.md` section "Validation Architecture". The Per-Task Verification Map
> is completed against the final PLAN.md task ids after planning.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | bash 3.2 + python3, hand-rolled assertions in `tests/lib.sh` (no framework) |
| **Config file** | none; `tests/run.sh` globs top-level `tests/test-*.sh` |
| **Quick run command** | the single `tests/test-ingest-*.sh` / `tests/test-agent-fact-extractor.sh` / `tests/test-skill-ingest.sh` touched |
| **Full suite command** | `bash tests/run.sh` |
| **Free harness proof** | `bash tests/scenarios/selftest-ingest.sh` (and `bash tests/scenarios/selftest.sh`, since `lib-scenario.sh` gains helpers) |
| **Behavioural (paid, agent-run, NOT in run.sh)** | `bash tests/scenarios/ingest-transcript.sh --variant baseline --runs 3 <outdir>` then `--variant plugin --runs 3 <outdir>` |
| **Estimated runtime** | quick < 10 s per file; full suite well under 90 s; scenario ~2-4 min (about 0.03-0.05 USD per baseline run, 0.10-0.25 per plugin run) |

---

## Sampling Rate

- **After every task commit:** run the test file the task touched, plus `bash tests/test-skill-dossier.sh` when a skill changes
- **After every plan wave:** run `bash tests/run.sh`, `bash tests/scenarios/selftest-ingest.sh` and `bash tests/scenarios/selftest.sh`
- **Before `/gsd-verify-work`:** full suite green, selftests green, paid scenario gates met with evidence copied under `evidence/` after `scrub_check`
- **Max feedback latency:** 90 seconds (mechanical tests); the paid scenario is a phase gate, not a per-commit check

---

## Per-Task Verification Map

Seeded at planning against the final task ids of the 04-0N plans (see the plan files for the
exact commands). Every test file is created by the task that first uses it (tests before
implementation, same task). The Status cell is the last cell of each row and is set from the
observed results at the end of execution.

| Task ID | Plan | Wave | Requirement | Threat Ref | Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|----------|-----------|-------------------|-------------|--------|
| (filled after planning) | | | | | | | | | pending |

*Status: pending - green - red - flaky*

---

## Wave 0 Requirements

- [ ] `tests/fixtures/make-pdf.py` - stdlib PDF generator (text pages, image-only pages)
- [ ] `tests/test-ingest-file.sh` - INGEST-01, INGEST-04, URL cases with a local server
- [ ] `tests/test-ingest-extract.sh` - INGEST-01 extraction and the missing-tool path
- [ ] `tests/test-ingest-guard.sh` - D-04, the real guard on the exact filing and extraction commands
- [ ] `tests/test-agent-fact-extractor.sh` - INGEST-03, rules-block parity
- [ ] `tests/test-skill-ingest.sh` - INGEST-02, INGEST-06 prose
- [ ] `tests/scenarios/ingest-transcript.sh` + `tests/scenarios/selftest-ingest.sh` + helpers in `lib-scenario.sh` (`jsonl_has_agent`, `jsonl_agent_dispatched`, `backdate_last_updated`)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Paid pressure scenario, RED baseline then GREEN | INGEST-05 | Needs a live `claude` run, costs money; agent-run by the team, never by Samuel | `bash tests/scenarios/ingest-transcript.sh --variant baseline --runs 3 <outdir>` before `skills/dossier-ingest/SKILL.md` exists, then `--variant plugin --runs 3 <outdir>` after |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 90s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
