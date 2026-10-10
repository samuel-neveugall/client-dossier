---
phase: "03"
slug: protocol-skill-hooks
# status lifecycle: draft (seeded by plan-phase) -> validated (set by validate-phase)
status: draft
nyquist_compliant: true
wave_0_complete: true
created: "2026-10-10"
---

# Phase 3 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Source: `03-RESEARCH.md` section "Validation Architecture". The Per-Task Verification Map
> is completed against the final PLAN.md task ids after planning.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | bash 3.2 + python3, hand-rolled assertions in `tests/lib.sh` (no framework) |
| **Config file** | none; `tests/run.sh` globs top-level `tests/test-*.sh` |
| **Quick run command** | `bash tests/test-hook-guard-sources.sh` (or the single `tests/test-hook-*.sh` / `tests/test-skill-dossier.sh` touched) |
| **Full suite command** | `bash tests/run.sh` |
| **Behavioural (paid, agent-run, NOT in run.sh)** | `bash tests/scenarios/fix-typo.sh <outdir>` |
| **Estimated runtime** | quick < 5 s per file; full suite well under 60 s; scenario ~1-2 min (6 runs) |

---

## Sampling Rate

- **After every task commit:** run the hook or skill test file the task touched
- **After every plan wave:** run `bash tests/run.sh`
- **Before `/gsd-verify-work`:** full suite green, then the scenario harness run once with evidence recorded under `evidence/`
- **Max feedback latency:** 60 seconds (mechanical tests); the scenario harness is a phase gate, not a per-commit check

---

## Per-Task Verification Map

Seeded at planning (2026-10-10) against the final task ids of 03-01..03-06. Every test file is
created by the task that first uses it (tests before implementation, same task), so no task
waits on a separate Wave 0 plan. The Status cell is the last cell of each row; plan 03-06 task 3
sets it from the observed results.

| Task ID | Plan | Wave | Requirement | Threat Ref | Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|----------|-----------|-------------------|-------------|--------|
| 03-01-T1 | 01 | 1 | PROTO-05, PROTO-08 (D-03) | T-03-01, T-03-02, T-03-03, T-03-06 | tracer: Write/Edit/MultiEdit/NotebookEdit under sources/ denied, new files too; silent elsewhere; hooks.json shape and quoting; command run through sh -c; find_root parity; 3.8 grammar; validate prints no hooks warning | unit (tracer) | `bash tests/test-hook-guard-sources.sh && bash tests/test-hooks-config.sh` | created by the task | green |
| 03-01-T2 | 01 | 1 | PROTO-05 (D-04) | T-03-01, T-03-04, T-03-05 | Bash heuristic deny and allow cases; new file copied into sources/ allowed; unparseable command allowed | unit | `bash tests/test-hook-guard-sources.sh && bash tests/test-hooks-config.sh && bash tests/run.sh` | yes (03-01-T1) | green |
| 03-02-T1 | 02 | 1 | PROTO-07 (D-08, D-09, D-10, D-11, D-12) | T-03-08, T-03-09, T-03-10, T-03-12 | harness verdicts RED, GREEN, INCOMPLETE; gates; harness errors exit 2; D-12 and contamination guards | unit (fake claude) | `bash tests/scenarios/selftest.sh && bash -n tests/scenarios/lib-scenario.sh && bash -n tests/scenarios/fix-typo.sh` | created by the task | green |
| 03-02-T2 | 02 | 1 | PROTO-07 (P-01, provisional) | T-03-10 | AGENTS.md removed in the baseline and plugin variants, kept in pointer-only | unit (fake claude) | `bash tests/scenarios/selftest.sh` | yes (03-02-T1) | green |
| 03-02-T3 | 02 | 1 | PROTO-07 (RED) | T-03-08, T-03-10, T-03-11 | baseline at least 1 RED of 3, recorded before skills/dossier/SKILL.md exists; evidence scrubbed and copied | behavioural, paid, agent-run | `bash tests/scenarios/fix-typo.sh --variant baseline --variant pointer-only --runs 3 "$OUT"`, then the awk checks on evidence/red-baseline/summary.tsv | evidence | green |
| 03-03-T1 | 03 | 1 | PROTO-05, PROTO-06 (D-01, D-03, D-04) | T-03-13 | spec section 4 tree, 4.3 table, 11 #3, 12 amended; test-skill-shape.sh still green | doc grep | the grep chain of 03-03 task 1, ending with `bash tests/test-skill-shape.sh` | n/a | green |
| 03-03-T2 | 03 | 1 | PROTO-02, PROTO-05, PROTO-06, PROTO-07, PROTO-08 (D-01, D-05, D-07, D-09, D-10) | T-03-13 | PROJECT Open Decisions closed; ROADMAP criteria 4, 5, 6; REQUIREMENTS wording and incremental traceability with Status cells intact | doc grep | the grep chain of 03-03 task 2 | n/a | green |
| 03-03-T3 | 03 | 1 | hygiene | T-03-14 | `.gsd/` ignored | config | `git check-ignore -q .gsd/dispatch-isolation-sentinel.json && grep -qx '.gsd/' .gitignore` | n/a | green |
| 03-04-T1 | 04 | 2 | PROTO-04, PROTO-08 | T-03-15, T-03-20 | reminder in root, subfolder and nested dossier; silent outside; no confidential name; fail open; end to end through hooks.json | unit | `bash tests/test-hook-session-start.sh && bash tests/test-hooks-config.sh && bash tests/test-hook-guard-sources.sh` | created by the task | green |
| 03-04-T2 | 04 | 2 | PROTO-06, PROTO-08 (D-01, D-02) | T-03-16, T-03-17, T-03-18, T-03-20 | block once; stop_hook_active passes; stateless silent cases; prefix stripping; sibling and nested dossiers; renames | unit | `bash tests/test-hook-stop.sh && bash tests/test-hooks-config.sh && bash tests/run.sh` | created by the task | green |
| 03-04-T3 | 04 | 2 | PROTO-06 (P-02, provisional) | T-03-19 | dossier-status sentence present iff the skill file exists under CLAUDE_PLUGIN_ROOT | unit | `bash tests/test-hook-stop.sh && bash tests/test-hooks-config.sh` | yes (03-04-T2) | green |
| 03-05-T1 | 05 | 2 | PROTO-01, PROTO-03, PROTO-08 (D-05, D-06, D-07) | T-03-22 | frontmatter; description at most 1024 chars, starts Use when, trigger words; nearest dossier and step-aside; language rule; self-updating pointer set | unit (grep) | `bash tests/test-skill-dossier.sh && bash tests/test-skill-shape.sh` | created by the task | green |
| 03-05-T2 | 05 | 2 | PROTO-02 | T-03-21, T-03-23, T-03-24 | layout; six-row table; fact line; worked correction not reusing the fixture; status header; Name (Organisation); never-list; hook rules in prose; linter pointer with fallback | unit (grep) | `bash tests/test-skill-dossier.sh && bash tests/run.sh` | yes (03-05-T1) | green |
| 03-06-T1 | 06 | 3 | PROTO-05, PROTO-06 (D-01) | T-03-27 | CLAUDE.md and STATE.md amended; validate command observed | doc grep and CLI | the grep chain of 03-06 task 1, ending with `claude plugin validate .` | n/a | green |
| 03-06-T2 | 06 | 3 | PROTO-07 (GREEN), PROTO-01 behavioural (D-09, D-10, D-11, D-12) | T-03-25, T-03-26, T-03-28 | plugin 3 GREEN of 3, skill loaded in each run, transcript byte-identical, evidence scrubbed and copied | behavioural, paid, agent-run | `bash tests/scenarios/fix-typo.sh --variant plugin --runs 3 "$OUT"`, then the awk checks on evidence/green-plugin/summary.tsv | evidence | green |
| 03-06-T3 | 06 | 3 | PROTO-01 to PROTO-08 | none | full suite 11 files 0 failed; harness self-test green; both evidence sets present; this contract finalized | suite | `bash tests/run.sh && bash tests/scenarios/selftest.sh` | yes | green |

*Status: pending / green / red / flaky*

### Requirement → test map (reference)

| Requirement | Behavior | Test Type | Automated Command | Tasks |
|-------------|----------|-----------|-------------------|-------|
| PROTO-01 | frontmatter `name: dossier`, description <= 1024 chars, starts "Use when", names dossier.yaml / client / counterpart / prospect / partner / call / message | unit (grep) | `bash tests/test-skill-dossier.sh` | 03-05-T1 |
| PROTO-01 | skill triggers in a dossier (Skill tool_use naming `dossier`; `system/init.skills` assertion, D-12) | behavioural | `bash tests/scenarios/fix-typo.sh --variant plugin --runs 3 <outdir>` | 03-02-T1, 03-06-T2 |
| PROTO-02 | layout names, 7 living files, six table rows, fact-line shape, status fields/values, Name (Organisation), never-list, pointer set equals skills that exist (D-07) | unit | `bash tests/test-skill-dossier.sh` | 03-05-T1, 03-05-T2 |
| PROTO-03 | language rule present, keywords stay English | unit | `bash tests/test-skill-dossier.sh` | 03-05-T1 |
| PROTO-04 | SessionStart reminder in root and subfolder, nearest root, silent without dossier.yaml, malformed stdin, exit 0 | unit | `bash tests/test-hook-session-start.sh` | 03-04-T1 |
| PROTO-05 | guard denies Write/Edit/MultiEdit/NotebookEdit under sources/ (existing and new files), Bash heuristic table, allows new-file copy, fail open | unit | `bash tests/test-hook-guard-sources.sh` | 03-01-T1, 03-01-T2 |
| PROTO-06 | Stop block-once: outbound/sources changes without dossier/, `stop_hook_active` passes, silent outside git/dossier, prefix stripping, dossier-status sentence iff skill exists (P-02) | unit | `bash tests/test-hook-stop.sh` | 03-04-T2, 03-04-T3 |
| PROTO-07 | baseline >= 1 RED of 3; plugin 3 GREEN of 3 (hash + filed line; lint exit recorded) | behavioural, paid | `bash tests/scenarios/fix-typo.sh <outdir>` (selftest: `bash tests/scenarios/selftest.sh`) | 03-02-T1..T3, 03-06-T2 |
| PROTO-08 | hooks' `find_root` byte-identical to lint.py's; subfolder and nested-dossier cases; skill states nearest-wins and the task-skill stop rule | unit | `bash tests/test-hooks-config.sh` + hook tests + skill test | 03-01-T1, 03-04-T1, 03-04-T2, 03-05-T1 |
| all hooks | hooks.json parses, three events, quoted `${CLAUDE_PLUGIN_ROOT}`, scripts exist, 3.8 grammar, `claude plugin validate .` prints no hooks warning | unit | `bash tests/test-hooks-config.sh` | 03-01-T1, 03-04-T1, 03-04-T2 |

---

## Wave 0 Requirements

Folded into the tasks (each test file is written first, inside the task that implements the
behaviour):

- [x] `tests/test-hooks-config.sh` - hooks.json shape, 3.8 grammar, find_root parity, plugin validate (PROTO-04..06, PROTO-08) — 03-01-T1, extended by 03-04-T1/T2
- [x] `tests/test-hook-session-start.sh` - PROTO-04, PROTO-08 — 03-04-T1
- [x] `tests/test-hook-guard-sources.sh` - PROTO-05, D-03, D-04 — 03-01-T1/T2
- [x] `tests/test-hook-stop.sh` - PROTO-06, D-01, D-02, P-02 — 03-04-T2/T3
- [x] `tests/test-skill-dossier.sh` - PROTO-01..03, PROTO-08 rule — 03-05-T1/T2
- [x] `tests/scenarios/lib-scenario.sh` + `tests/scenarios/fix-typo.sh` + `tests/scenarios/selftest.sh` - PROTO-07, D-11, D-12, P-01 — 03-02-T1/T2
- [x] RED baseline recorded (no plugin) BEFORE `skills/dossier/SKILL.md` exists (superpowers:writing-skills) — 03-02-T3 (wave 1) precedes 03-05 (wave 2)

---

## Manual-Only Verifications

All phase behaviours have automated verification. The scenario harness is automated but paid and
agent-run (D-08); Samuel does not run tests himself.

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 60 s (mechanical tests)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** verified by the executor on 2026-10-10; `status` is left to /gsd-validate-phase.

## Provisional decisions

- P-01 (D-13, AGENTS.md stripped in the baseline and plugin variants): applied, still awaiting Samuel's confirmation; reversion lives in `strip_agents_pointer` (`tests/scenarios/lib-scenario.sh`) and its call in `tests/scenarios/fix-typo.sh`.
- P-02 (D-14, dossier-status sentence only once the skill exists): applied, awaiting Samuel; reversion lives in `status_sentence()` (`hooks/stop-check.py`).
- D-15: the baseline ran under the pressured prompt and was RED 3/3, so the D-10 fallback (amending the barrier) was not needed.
