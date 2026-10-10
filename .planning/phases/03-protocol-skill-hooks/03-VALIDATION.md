---
phase: "03"
slug: protocol-skill-hooks
# status lifecycle: draft (seeded by plan-phase) -> validated (set by validate-phase)
status: draft
nyquist_compliant: false
wave_0_complete: false
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

Completed after planning (see the plan frontmatter `requirements` and each task `<automated>`).

| Requirement | Behavior | Test Type | Automated Command | File Exists | Status |
|-------------|----------|-----------|-------------------|-------------|--------|
| PROTO-01 | frontmatter `name: dossier`, description <= 1024 chars, starts "Use when", names dossier.yaml / client / counterpart / prospect / partner / call / message | unit (grep) | `bash tests/test-skill-dossier.sh` | W0 | pending |
| PROTO-01 | skill triggers in a dossier (Skill tool_use naming `dossier`) | behavioural | scenario harness plugin variant (`system/init.skills` assertion, D-12) | W0 | pending |
| PROTO-02 | layout names, 7 living files, six table rows, fact-line shape, status fields/values, Name (Organisation), never-list, pointer set equals skills that exist | unit | `bash tests/test-skill-dossier.sh` | W0 | pending |
| PROTO-03 | language rule present, keywords stay English | unit | `bash tests/test-skill-dossier.sh` | W0 | pending |
| PROTO-04 | SessionStart reminder in root and subfolder, nearest root, silent without dossier.yaml, malformed stdin, exit 0 | unit | `bash tests/test-hook-session-start.sh` | W0 | pending |
| PROTO-05 | guard denies Write/Edit/MultiEdit/NotebookEdit under sources/ (existing and new files), Bash heuristic table, allows new-file copy, fail open | unit | `bash tests/test-hook-guard-sources.sh` | W0 | pending |
| PROTO-06 | Stop block-once: outbound/sources changes without dossier/, `stop_hook_active` passes, silent outside git/dossier, prefix stripping, dossier-status sentence iff skill exists (P-02) | unit | `bash tests/test-hook-stop.sh` | W0 | pending |
| PROTO-07 | baseline >= 1 RED of 3; plugin 3 GREEN of 3 (hash + filed line + lint exit) | behavioural, paid | `bash tests/scenarios/fix-typo.sh <outdir>` | W0 | pending |
| PROTO-08 | hooks' `find_root` byte-identical to lint.py's; subfolder and nested-dossier cases; skill states nearest-wins and the task-skill stop rule | unit | `bash tests/test-hooks-config.sh` + hook tests + skill test | W0 | pending |
| all hooks | hooks.json parses, three events, quoted `${CLAUDE_PLUGIN_ROOT}`, scripts exist, 3.8 grammar, `claude plugin validate .` prints no hooks warning | unit | `bash tests/test-hooks-config.sh` | W0 | pending |

*Status: pending / green / red / flaky*

---

## Wave 0 Requirements

- [ ] `tests/test-hooks-config.sh` - hooks.json shape, 3.8 grammar, find_root parity, plugin validate (PROTO-04..06, PROTO-08)
- [ ] `tests/test-hook-session-start.sh` - PROTO-04, PROTO-08
- [ ] `tests/test-hook-guard-sources.sh` - PROTO-05, D-03, D-04
- [ ] `tests/test-hook-stop.sh` - PROTO-06, D-01, D-02, P-02
- [ ] `tests/test-skill-dossier.sh` - PROTO-01..03, PROTO-08 rule
- [ ] `tests/scenarios/lib-scenario.sh` + `tests/scenarios/fix-typo.sh` - PROTO-07, D-11, D-12, P-01
- [ ] RED baseline recorded (no plugin) BEFORE `skills/dossier/SKILL.md` exists (superpowers:writing-skills)

---

## Manual-Only Verifications

All phase behaviours have automated verification. The scenario harness is automated but paid and
agent-run (D-08); Samuel does not run tests himself.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60 s (mechanical tests)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
