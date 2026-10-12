---
phase: "07"
slug: manifests-docs-distribution
status: draft
nyquist_compliant: true
wave_0_complete: true
created: "2026-10-11"
---

# Phase 7 — Validation Strategy

> Per-phase validation contract. Source: 07-RESEARCH.md "Validation Architecture". The per-task rows
> below were bound to task ids and run by the executor of plan 07-09 on 2026-10-12.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | bash 3.2 + python3 stdlib, hand-rolled assertions in `tests/lib.sh` (no bash arrays, target bash 3.2) |
| **Config file** | none; `tests/run.sh` globs top-level `tests/test-*.sh` |
| **Quick run command** | the touched file: `bash tests/test-manifests.sh`, `bash tests/test-commands.sh`, `bash tests/test-release.sh`, `bash tests/test-readme.sh`, `bash tests/test-evals-shape.sh` |
| **Full suite command** | `bash tests/run.sh` (25 files before Phase 7, 30 at the end: `TOTAL: 30 files, 0 failed`) |
| **Free install checks (outside run.sh)** | `bash tests/dist/install-claude.sh`, `bash tests/dist/install-codex.sh`, `bash tests/dist/install-skills.sh` (isolated `CLAUDE_CONFIG_DIR`, `CODEX_HOME`, `HOME`; source = fresh `git clone` of HEAD) |
| **Manifest gate** | `claude plugin validate .` and `claude plugin validate .claude-plugin/plugin.json`: exit 0, one warning (root `CLAUDE.md`, D-03); `--strict` exits 1 by design |
| **Paid (agent-run, NOT in run.sh)** | `claude plugin eval . --scaffold --trust-plugin --ablation none --model sonnet --runs 3 --no-publish --max-cost-usd 4 --json <evidence>.json` (recorded: 2.2627 USD); the command smoke `evidence/uat/command-smoke.sh` on Haiku (two runs, about 0.013 USD) |
| **Estimated runtime** | run.sh under 120 s; dist checks under 90 s each |

## Sampling Rate

- **After every task commit:** the test file of the artefact under change
- **After every plan wave:** `bash tests/run.sh` and `claude plugin validate .`
- **Before verify-work:** full suite green, three `tests/dist/*.sh` run and logged after `scrub_check`, eval JSON recorded
- **Max feedback latency:** 120 seconds (free checks)

## Per-Task Verification Map

Each row is one task of plans 07-01 to 07-09. The command column names the test files the task's
`<automated>` verify runs (the rest of each verify is greps over the task's own files); every row
was re-run on 2026-10-12 against the tree of plan 07-09 and its Status set from the exit code.
Two adaptations, both because the plan text predates a later fact: the registry record is
`skills-1.7.0-registry.txt` (07-05 pinned `skills@1.7.0`, the plans say 1.7.2), and the skills-CLI
route of 07-05 task 3 is proven by the committed `install-skills-cli.log` instead of being run again
(no package is installed by plan 07-09, T-07-SC).

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 07-01-T1 | 07-01 | 1 | DIST-01 | T-07-02, T-07-04 | every `claude` call under temporary config and home; install source is a clone of HEAD; real configuration byte-identical | static + integration | `bash tests/test-manifests.sh && bash tests/dist/install-claude.sh` | ✅ | green |
| 07-01-T2 | 07-01 | 1 | DIST-02 | T-07-01, T-07-03 | Codex identity equals Claude's; no e-mail field; marketplace entries carry name and source only | static | `bash tests/test-manifests.sh` | ✅ | green |
| 07-02-T1 | 07-02 | 1 | DIST-07 | T-07-05, T-07-06 | semver fullmatch on argv before any use; injection strings refused; no remote-talking command; annotated local tag | unit (scratch clone) | `bash tests/test-release.sh` | ✅ | green |
| 07-02-T2 | 07-02 | 1 | DIST-07 | T-07-07, T-07-08 | every refusal leaves files and tags unchanged; diverged manifests refused; marketplace entries rule | unit (scratch clone) | `bash tests/test-release.sh && bash tests/run.sh` | ✅ | green |
| 07-02-T3 | 07-02 | 1 | DIST-05 | T-07-08 | MIT LICENSE in the name of Samuel Neveu; CHANGELOG holds `## [Unreleased]` only | static | grep gate on LICENSE and CHANGELOG.md (MIT text, `## [Unreleased]` only) | ✅ | green |
| 07-03-T1 | 07-03 | 1 | DIST-02 | T-07-09, T-07-10 | Codex `apply_patch` headers judged like the Write family; linear scan under a 4 s bound | integration | `bash tests/test-hook-guard-sources.sh && bash tests/test-hooks-config.sh` | ✅ | green |
| 07-03-T2 | 07-03 | 1 | DIST-03 | T-07-11, T-07-12 | script calls double-quoted and guarded by `test -x` with a stated fallback in every skill | static | `bash tests/test-skill-shape.sh && bash tests/test-skill-dossier.sh && bash tests/test-skills-task.sh && bash tests/test-init-empty.sh` ... | ✅ | green |
| 07-04-T1 | 07-04 | 1 | DIST-06 | T-07-13, T-07-15 | read-only tools plus `Skill` only; `evals/results/` ignored from the first case | static + scaffold run | `bash tests/test-evals-shape.sh` | ✅ | green |
| 07-04-T2 | 07-04 | 1 | DIST-06 | T-07-13 | one positive routing case per task skill, same tool grant | static + scaffold run | `bash tests/test-evals-shape.sh` | ✅ | green |
| 07-04-T3 | 07-04 | 1 | DIST-06 | T-07-13, T-07-14 | step-aside and false-positive cases; scaffolds `set -eu`, workspace-relative | static + scaffold run | `bash tests/test-evals-shape.sh && bash tests/run.sh` | ✅ | green |
| 07-05-T1 | 07-05 | 2 | DIST-02 | T-07-17 | CODEX_HOME and HOME under mktemp; real Codex, Claude and ~/.agents configuration byte-identical | integration | `bash tests/dist/install-codex.sh` | ✅ | green |
| 07-05-T2 | 07-05 | 2 | DIST-03 | T-07-16 | registry gate of the pinned `skills` CLI recorded before any install (record names skills@1.7.0, plan text said 1.7.2) | agent-run record | grep gate on evidence/dist/skills-1.7.0-registry.txt (package, verdict, provenance, no home path) and `bash -n tests/dist/install-skills.sh` | ✅ | green |
| 07-05-T3 | 07-05 | 2 | DIST-03 | T-07-16, T-07-17, T-07-18 | bare copy degrades with stated fallbacks; skills CLI refused on a bad pin (exit 2); logs redacted | integration | `bash tests/dist/install-skills.sh --via copy && bash tests/dist/install-skills.sh --via skills-cli` | ✅ | green |
| 07-06-T1 | 07-06 | 3 | DIST-05 | T-07-19, T-07-20 | README installation for the four targets pinned by the test with LICENSE, CHANGELOG and version coherence | static | `bash tests/test-readme.sh` | ✅ | green |
| 07-06-T2 | 07-06 | 3 | DIST-05 | T-07-19, T-07-21 | guard and confidential-name limits stated; no home path, no e-mail | static | `bash tests/test-readme.sh && bash tests/run.sh` | ✅ | green |
| 07-07-T1 | 07-07 | 3 | DIST-01, DIST-02, DIST-03 | T-07-22 | install logs redacted (`<repo>`, `<tmp>`, `~`) then scrub_check; four PASS logs | recorded evidence | `tail -1` of the four evidence/dist logs, home-path count 0, `scrub_check` | ✅ | green |
| 07-07-T2 | 07-07 | 3 | DIST-06 | T-07-22, T-07-23, T-07-25 | Haiku shake-out capped at 0.5 USD; eight cases load and scaffold; no home path in the JSON | paid (agent-run), recorded | `bash tests/test-evals-shape.sh` | ✅ | green |
| 07-07-T3 | 07-07 | 3 | DIST-06 | T-07-22, T-07-23, T-07-24 | one Sonnet run, gate fixed before the run; partial false, write-to-client 1.0, every case at least 0.66 | paid (agent-run), recorded | python gate on evidence/eval/routing-sonnet.json (partial false, eight cases, write-to-client 1.0, all at least 0.66) and routing-sonnet.tsv | ✅ | green |
| 07-08-T1 | 07-08 | 4 | DIST-04 | T-07-26, T-07-27, T-07-28 | single-quoted path, no tool grant, no command named like a skill | static + integration | `bash tests/test-commands.sh && bash tests/test-manifests.sh && bash tests/dist/install-claude.sh` | ✅ | green |
| 07-08-T2 | 07-08 | 4 | DIST-04 | T-07-28 | DIST-04, spec section 4, D-06 and ROADMAP criterion 4 carry the D-18 wording | static | grep gate on REQUIREMENTS DIST-04, the spec section 4 tree, 07-CONTEXT D-06 and ROADMAP criterion 4 | ✅ | green |
| 07-08-T3 | 07-08 | 4 | DIST-04 | T-07-28 | CLAUDE.md, README and CHANGELOG state the one command, pinned by test-commands.sh | static | `bash tests/test-commands.sh && bash tests/test-readme.sh && bash tests/run.sh` | ✅ | green |
| 07-09-T1 | 07-09 | 5 | DIST-01..07 | T-07-30 | CLAUDE.md documents Phase 7; every free command it lists runs green as written | static + integration | `bash tests/test-manifests.sh && bash tests/test-release.sh && bash tests/test-readme.sh && bash tests/test-evals-shape.sh` ... | ✅ | green |
| 07-09-T2 | 07-09 | 5 | DIST-01..07 | T-07-29, T-07-30 | spec, ticks and the pre-publication checklist; DIST-06 ticked only from the committed gate | static | grep gate on the spec tree, 4.3 and 8, the DIST ticks, the STATE checklist and the ROADMAP ticks | ✅ | green |
| 07-09-T3 | 07-09 | 5 | DIST-04, DIST-07 | T-07-31, T-07-32 | Haiku smoke capped at 0.25 USD per run; rehearsal origin re-pointed to an empty bare repository; no tag, manifests at 0.1.0 | paid smoke (agent-run) + unit | smoke-summary.tsv two PASS, `scrub_check` on evidence/uat, `bash tests/run.sh` ends `TOTAL: 30 files, 0 failed`, no `v*` tag, manifests at 0.1.0, 24 green rows | ✅ | green |

*Status: green · red · flaky*

## Wave 0 Requirements

- [x] `tests/test-manifests.sh` — DIST-01/02 static + validate
- [x] `tests/test-commands.sh` — DIST-04 collision + shape (D-18, settled by Samuel)
- [x] `tests/test-release.sh` — DIST-07
- [x] `tests/test-readme.sh` — DIST-05
- [x] `tests/test-evals-shape.sh` — DIST-06 static
- [x] `tests/dist/install-claude.sh`, `install-codex.sh`, `install-skills.sh` — free, outside run.sh
- [x] `.gitignore` gains `evals/results/`

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Codex hooks at run time | DIST-02 | isolated `CODEX_HOME` is not logged in (no OpenAI login on this machine): the real-hook tests were NOT run | documentation-backed only (Codex loads `hooks/hooks.json` after `/hooks` trust); the `apply_patch` guard is proven with Codex-shaped stdin by `tests/test-hook-guard-sources.sh`, never against a live Codex; never auto-answered |
| Command smoke on a real model | DIST-04 | paid, agent-run (no longer manual): `bash .planning/phases/07-manifests-docs-distribution/evidence/uat/command-smoke.sh` | recorded in `evidence/uat/` (two Haiku runs, `smoke-summary.tsv`) and in the 07-09 SUMMARY for 07-UAT |
| Pre-publication checklist | DIST-05 | publication needs Samuel's explicit approval (D-01) | recorded in STATE.md ("Pre-publication checklist"), never executed in v1 |

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 120 s (free checks; the install checks and the release tests run under 60 s each)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** verified by the executor on 2026-10-12; `status` is left to /gsd-validate-phase
