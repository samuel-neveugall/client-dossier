---
phase: "07"
slug: manifests-docs-distribution
status: draft
nyquist_compliant: true
wave_0_complete: false
created: "2026-10-11"
---

# Phase 7 — Validation Strategy

> Per-phase validation contract. Source: 07-RESEARCH.md "Validation Architecture". The per-task rows
> below are seeded at requirement level; the planner binds them to task ids.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | bash 3.2 + python3 stdlib, hand-rolled assertions in `tests/lib.sh` (no bash arrays, target bash 3.2) |
| **Config file** | none; `tests/run.sh` globs top-level `tests/test-*.sh` |
| **Quick run command** | the touched file: `bash tests/test-manifests.sh`, `bash tests/test-commands.sh`, `bash tests/test-release.sh`, `bash tests/test-readme.sh`, `bash tests/test-evals-shape.sh` |
| **Full suite command** | `bash tests/run.sh` (24 files at the start of Phase 7, 29 expected at the end) |
| **Free install checks (outside run.sh)** | `bash tests/dist/install-claude.sh`, `bash tests/dist/install-codex.sh`, `bash tests/dist/install-skills.sh` (isolated `CLAUDE_CONFIG_DIR`, `CODEX_HOME`, `HOME`; source = fresh `git clone` of HEAD) |
| **Manifest gate** | `claude plugin validate .` and `claude plugin validate .claude-plugin/plugin.json`: exit 0, one warning (root `CLAUDE.md`, D-03); `--strict` exits 1 |
| **Paid (agent-run, NOT in run.sh)** | `claude plugin eval . --scaffold --trust-plugin --ablation none --model sonnet --runs 3 --no-publish --max-cost-usd 4 --json <evidence>.json` (about 3-3.5 USD, D-11); one `/client-dossier:dossier-lint` smoke on Haiku |
| **Estimated runtime** | run.sh under 120 s; dist checks under 90 s each |

## Sampling Rate

- **After every task commit:** the test file of the artefact under change
- **After every plan wave:** `bash tests/run.sh` and `claude plugin validate .`
- **Before verify-work:** full suite green, three `tests/dist/*.sh` run and logged after `scrub_check`, eval JSON recorded
- **Max feedback latency:** 120 seconds (free checks)

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 07-REQ-01 | tbd | tbd | DIST-01 | no credentials, https URLs, no version on the marketplace entry | `plugin.json` identity, `marketplace.json` one entry `{name, source "./"}`, `json.dumps(indent=2)` form | static | `bash tests/test-manifests.sh` | ❌ W0 | ⬜ pending |
| 07-REQ-02 | tbd | tbd | DIST-01 | tests never touch real config | validate exit 0 + one warning; isolated add + install, `plugin details` 6 skills / 2 agents / 3 hooks | static (CLI) + integration | `bash tests/test-manifests.sh && bash tests/dist/install-claude.sh` | ❌ W0 | ⬜ pending |
| 07-REQ-03 | tbd | tbd | DIST-02 | tests never touch real config (CODEX_HOME and HOME) | Codex manifest identity equals Claude's; `.agents` marketplace policy/category, no version | static | `bash tests/test-manifests.sh` | ❌ W0 | ⬜ pending |
| 07-REQ-04 | tbd | tbd | DIST-02 | same | isolated `codex plugin marketplace add` + `plugin add`; `debug prompt-input` lists every skill | integration | `bash tests/dist/install-codex.sh` | ❌ W0 | ⬜ pending |
| 07-REQ-05 | tbd | tbd | DIST-03 | pinned `skills@1.7.2`, human-verify checkpoint (SUS) | skill folders copied whole; no `lint.py`, `hooks`, `agents`; skills degrade (guards + stated fallbacks) | integration + static | `bash tests/dist/install-skills.sh && bash tests/test-skill-shape.sh` | ❌ W0 | ⬜ pending |
| 07-REQ-06 | tbd | tbd | DIST-04 (amended, P-01) | no `allowed-tools`, single-quoted path | `commands/` = exactly `dossier-lint.md`; no command stem equals a skill name | static | `bash tests/test-commands.sh` | ❌ W0 | ⬜ pending |
| 07-REQ-07 | tbd | tbd | DIST-04 | none | `/client-dossier:dossier-lint` relays lint output and exit code; a task skill slash loads SKILL.md | paid smoke (agent-run) | recorded in `07-UAT.md` | manual-only | ⬜ pending |
| 07-REQ-08 | tbd | tbd | DIST-05 | README states D-04/D-17 limits and 05 D-09 debt | four target headings, install commands, loses-list, Bash guard limits, semver, MIT, `/hooks` trust; LICENSE MIT "Samuel Neveu"; CHANGELOG `## [Unreleased]` only | static | `bash tests/test-readme.sh` | ❌ W0 | ⬜ pending |
| 07-REQ-09 | tbd | tbd | DIST-06 | read-only tools + `Skill` only | every case has frontmatter keys from the allowed set, graders naming an existing skill, executable `set -eu` scaffolds; `evals/results/` ignored | static | `bash tests/test-evals-shape.sh` | ❌ W0 | ⬜ pending |
| 07-REQ-10 | tbd | tbd | DIST-06 | `--trust-plugin` on this repo only | routing suite passes, `write-to-client` 3/3 → `dossier-draft`, never `dossier-ingest` | paid (agent-run), recorded | `claude plugin eval . --scaffold --trust-plugin --ablation none --model sonnet --runs 3 --no-publish --max-cost-usd 4 --json <evidence>.json` | ❌ W0 | ⬜ pending |
| 07-REQ-11 | tbd | tbd | DIST-07 | version via argv + `re.fullmatch`, never pushes | refusals (non-semver incl. injection strings, dirty tree, existing tag, diverged manifests, same version, missing Unreleased) leave files and tags unchanged; success bumps both manifests, heading, annotated tag, bare origin has no tag | unit (scratch clone) | `bash tests/test-release.sh` | ❌ W0 | ⬜ pending |
| 07-REQ-12 | tbd | tbd | DIST-01..07 | CLAUDE.md, spec, REQUIREMENTS, STATE amended | spec §4 tree, DIST-04 wording, CLAUDE.md commands/state, STATE pre-publication checklist (D-12) | static | grep + `bash tests/run.sh` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

## Wave 0 Requirements

- [ ] `tests/test-manifests.sh` — DIST-01/02 static + validate
- [ ] `tests/test-commands.sh` — DIST-04 collision + shape (P-01 isolated plan)
- [ ] `tests/test-release.sh` — DIST-07
- [ ] `tests/test-readme.sh` — DIST-05
- [ ] `tests/test-evals-shape.sh` — DIST-06 static
- [ ] `tests/dist/install-claude.sh`, `install-codex.sh`, `install-skills.sh` — free, outside run.sh
- [ ] `.gitignore` gains `evals/results/`

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Codex hooks at run time | DIST-02 | isolated `CODEX_HOME` is not logged in; documented only | stated in VERIFICATION as documentation-backed, never auto-answered |
| Command smoke on a real model | DIST-04 | paid, about 0.005 USD | agent runs `claude -p --plugin-dir . --model haiku` and records it in `07-UAT.md` |
| Pre-publication checklist | DIST-05 | publication needs Samuel's explicit approval (D-01) | recorded in STATE, never executed in v1 |

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 120 s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
