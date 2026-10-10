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
| **Behavioural (paid, agent-run, NOT in run.sh)** | `bash tests/scenarios/ingest-transcript.sh --variant baseline --runs 3 --prompt plain <outdir>` (04-02, before the skill; `--prompt pressured` only if the plain prompt gives 0 RED) then `--variant plugin --runs 3 --prompt <same kind> <outdir>` (04-05); and `bash tests/scenarios/ingest-pdf.sh --runs 1 <outdir>` (04-05, ROADMAP criterion 1: one plugin run on a generated PDF) |
| **Estimated runtime** | quick < 10 s per file; full suite well under 90 s; scenario ~2-4 min (about 0.03-0.05 USD per baseline run, 0.10-0.25 per plugin run, the PDF run included; each run capped at `SCENARIO_BUDGET_USD=1`) |

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
| 04-01-T1 | 04-01 | 1 | INGEST-01 | T-04-13 | tracer: the skill's filing command passes the real guard and files one local transcript as YYYY-MM-DD_slug, JSON `filed`, exit codes, find_root parity (D-01, D-04, D-07) | unit (tracer) | `bash tests/test-ingest-file.sh && test -x skills/dossier-ingest/scripts/file_source.py` | ❌ W0 (created by the task) | pending |
| 04-01-T2 | 04-01 | 1 | INGEST-01, INGEST-04 | T-04-07..T-04-12 | sha256 dedup incl. the filed file and a symlink (D-06, D-14), O_EXCL no overwrite, bad dates, slug folding, FIFO//dev/zero/empty/missing, sources/ symlinked out, staging inside the dossier, ASCII JSON, 3.8 + stdlib static checks | unit | `bash tests/test-ingest-file.sh && bash tests/run.sh` | ❌ W0 | pending |
| 04-01-T3 | 04-01 | 1 | INGEST-01 | T-04-01..T-04-06, T-04-14 | `fetch URL` (D-02): schemes, userinfo, non-public addresses refused before connecting, per-hop redirect check (max 5), cap, timeout, deadline, no proxy handler, staging outside the dossier, D-02 hint | unit (local http.server, network patched) | `bash tests/test-ingest-fetch.sh && bash tests/test-ingest-file.sh` | ❌ W0 | pending |
| 04-02-T1 | 04-02 | 1 | INGEST-05 | T-04-16 | lib-scenario.sh helpers: agents in system/init, Agent/Task dispatch, backdating `Last updated:` (D-12, D-13); Phase 3 selftest unaffected | free self-test | `bash tests/scenarios/selftest-ingest.sh && bash tests/scenarios/selftest.sh` | ❌ W0 | pending |
| 04-02-T2 | 04-02 | 1 | INGEST-05 | T-04-15, T-04-16 | ingest-transcript.sh: fixture, prompts, D-10 verdicts with D-12, D-13 columns, gates, harness errors, against a fake claude | free self-test | `bash tests/scenarios/selftest-ingest.sh && bash tests/scenarios/selftest.sh` | ❌ W0 | pending |
| 04-02-T3 | 04-02 | 1 | INGEST-05 | T-04-17, T-04-18, T-04-19 | paid RED baseline without the plugin, before skills/dossier-ingest/SKILL.md exists; 03 D-15 branch planned (pressured prompt, then fallback) | paid scenario (agent-run) | `bash tests/scenarios/ingest-transcript.sh --variant baseline --runs 3 --prompt plain <outdir>` + evidence check in the plan's verify | ❌ W0 | pending |
| 04-03-T1 | 04-03 | 1 | INGEST-01 | T-04-21 | extract-text.sh (D-05): `.txt` next to the PDF, UTF-8, `--- page N ---` markers; make-pdf.py fixtures | unit | `bash tests/test-ingest-extract.sh` | ❌ W0 | pending |
| 04-03-T2 | 04-03 | 1 | INGEST-01 | T-04-20, T-04-22, T-04-24 | exists, dangling symlink and race (`set -C`), scan 65, corrupt 1, usage 64, pdftotext hidden 69 + poppler hint (D-15), `-dash.pdf`, temp cleanup | unit | `bash tests/test-ingest-extract.sh && bash tests/run.sh` | ❌ W0 | pending |
| 04-04-T1 | 04-04 | 2 | INGEST-03 | T-04-25, T-04-26 | fact-extractor frontmatter (keys exactly name/description/tools/model, Read, Grep, Glob, inherit), rules block, output format (D-08) | static | `bash tests/test-agent-fact-extractor.sh && claude plugin validate .` | ❌ W0 | pending |
| 04-04-T2 | 04-04 | 2 | INGEST-02, INGEST-04, INGEST-06 | T-04-25, T-04-27, T-04-29, T-04-30, T-04-31 | dossier-ingest SKILL.md checklist, existence checks before the scripts, inline fallback, rules-block parity, dossier pointer in the same commit, git-ancestry gate after the RED baseline (D-01..D-03, D-07, D-09, D-11, D-14, D-15) | static | `bash tests/test-skill-ingest.sh && bash tests/test-agent-fact-extractor.sh && bash tests/test-skill-dossier.sh && bash tests/test-skill-shape.sh` | ❌ W0 | pending |
| 04-04-T3 | 04-04 | 2 | INGEST-01, INGEST-04 | T-04-28, T-04-29 | the SKILL.md bash-block lines through the real guard (allowed), denials kept (cp/redirect onto existing, Write/Edit under sources/), scripts refuse where the guard is blind, real runs incl. already_filed and pdftotext hidden (D-04) | unit | `bash tests/test-ingest-guard.sh && bash tests/run.sh` | ❌ W0 | pending |
| 04-05-T1 | 04-05 | 3 | INGEST-01 | T-04-35 | spec §4 tree and §4.1, CLAUDE.md state, scripts rule and commands (D-05) | static | the awk/grep checks in the plan's verify | ✅ (docs exist) | pending |
| 04-05-T2 | 04-05 | 3 | INGEST-05, INGEST-01, INGEST-02 | T-04-32..T-04-34, T-04-36, T-04-37 | paid GREEN 3/3 with `--plugin-dir` on the baseline's prompt kind, ingest_skill yes (D-12), at least one correction (D-13); on the same skill text, ROADMAP criterion 1 end to end: a generated PDF filed under sources/received/ as YYYY-MM-DD_*.pdf, its `.txt` with extract-text.sh's page markers, a `p. N` line added, the new contact in ACTORS.md, `Last updated:` refreshed, lint below 1 (D-01 recorded, D-12); ingest-pdf.sh proven first by a no-op fake (INCOMPLETE) and a scripted fake (GREEN) | paid scenario (agent-run) | `bash tests/scenarios/ingest-pdf.sh --runs 1 <outdir>` then `bash tests/scenarios/ingest-transcript.sh --variant plugin --runs 3 --prompt <kind> <outdir>` + the evidence checks in the plan's verify (summary rows, and the PDF diff and lint read independently) | ❌ W0 | pending |
| 04-05-T3 | 04-05 | 3 | INGEST-01..INGEST-06 | — | full suite 17 files, both self-tests, plugin validate, ingest-pdf.sh parses, evidence counts (11 + 11 + 5), this map finalized | suite | `bash tests/run.sh && bash tests/scenarios/selftest-ingest.sh && bash tests/scenarios/selftest.sh && claude plugin validate . && bash -n tests/scenarios/ingest-pdf.sh` | ✅ | pending |

*Status: pending - green - red - flaky*

---

## Wave 0 Requirements

- [ ] `tests/fixtures/make-pdf.py` - stdlib PDF generator (text pages, image-only pages)
- [ ] `tests/test-ingest-file.sh` - INGEST-01, INGEST-04 (local filing, dedup, no overwrite, refusals, static checks)
- [ ] `tests/test-ingest-fetch.sh` - INGEST-01 URL download (D-02) and its SSRF guard-rails, against a local server
- [ ] `tests/test-ingest-extract.sh` - INGEST-01 extraction and the missing-tool path
- [ ] `tests/test-ingest-guard.sh` - D-04, the real guard on the exact filing and extraction commands
- [ ] `tests/test-agent-fact-extractor.sh` - INGEST-03, rules-block parity
- [ ] `tests/test-skill-ingest.sh` - INGEST-02, INGEST-06 prose
- [ ] `tests/scenarios/ingest-transcript.sh` + `tests/scenarios/selftest-ingest.sh` + helpers in `lib-scenario.sh` (`jsonl_has_agent`, `jsonl_agent_dispatched`, `backdate_last_updated`)
- [ ] `tests/scenarios/ingest-pdf.sh` - ROADMAP criterion 1 end to end (created by 04-05-T2, proven by its two throwaway fake controls before the paid run; reuses `lib-scenario.sh` and `tests/fixtures/make-pdf.py` unchanged)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Paid pressure scenario, RED baseline then GREEN | INGEST-05 | Needs a live `claude` run, costs money; agent-run by the team, never by Samuel | `bash tests/scenarios/ingest-transcript.sh --variant baseline --runs 3 --prompt plain <outdir>` before `skills/dossier-ingest/SKILL.md` exists (04-02-T3), then `--variant plugin --runs 3 --prompt <same kind> <outdir>` after (04-05-T2) |
| Live end-to-end ingest of a PDF (ROADMAP criterion 1) | INGEST-01, INGEST-02 | Needs a live `claude` run, costs money (one run, capped at `SCENARIO_BUDGET_USD=1`); agent-run by the executor in 04-05-T2, never by Samuel. The skill's own filing and extraction lines are also proven mechanically on a generated PDF (04-04-T3) | `bash tests/scenarios/ingest-pdf.sh --runs 1 <outdir>` with the plugin loaded through `--plugin-dir`, prompt "Acme Consulting sent us their supplier onboarding pack: incoming/onboarding-pack.pdf. Please ingest it."; GREEN = filed under sources/received/ as YYYY-MM-DD_*.pdf, `.txt` with page markers, a `p. N` line, the contact in ACTORS.md, `Last updated:` refreshed, lint below 1, dossier-ingest invoked; evidence in `evidence/pdf-plugin/` |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 90s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
