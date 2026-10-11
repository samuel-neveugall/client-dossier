---
phase: 07-manifests-docs-distribution
plan: 07
subsystem: testing
tags: [distribution, install-evidence, plugin-eval, routing, claude-code, codex, skills-cli]
requires:
  - "07-01: Claude Code install check and manifests"
  - "07-04: evals/routing/ (8 cases) and tests/test-evals-shape.sh"
  - "07-05: Codex and bare-skills install checks, skills-CLI registry gate"
provides:
  - "evidence/dist/install-{claude,codex,skills-copy,skills-cli}.log: four redacted, passing isolated install checks of the merged tree (HEAD b838f268cf12)"
  - "evidence/eval/routing-haiku.json: Haiku shake-out, 8 cases load and scaffold"
  - "evidence/eval/routing-sonnet.json and .tsv: the recorded DIST-06 routing eval, all 8 cases at 1.0"
affects: [07-09 (UAT and publication checklist, ROADMAP criteria 1, 2, 5 ticks)]
tech-stack:
  added: []
  patterns:
    - "paid eval wrapped in before/after snapshots of the real Claude and Codex configuration"
key-files:
  created:
    - .planning/phases/07-manifests-docs-distribution/evidence/dist/install-claude.log
    - .planning/phases/07-manifests-docs-distribution/evidence/dist/install-codex.log
    - .planning/phases/07-manifests-docs-distribution/evidence/dist/install-skills-copy.log
    - .planning/phases/07-manifests-docs-distribution/evidence/dist/install-skills-cli.log
    - .planning/phases/07-manifests-docs-distribution/evidence/eval/routing-haiku.json
    - .planning/phases/07-manifests-docs-distribution/evidence/eval/routing-sonnet.json
    - .planning/phases/07-manifests-docs-distribution/evidence/eval/routing-sonnet.tsv
  modified: []
key-decisions:
  - "skills CLI route run on the pin recorded by 07-05, skills@1.7.0 (manager instruction), not the plan text's 1.7.2"
  - "install scripts run as shipped: each isolates CLAUDE_CONFIG_DIR, CODEX_HOME and HOME under its own mktemp -d and proves the real configuration byte-identical, which an outer throwaway HOME would have made vacuous"
status: complete
commits: 3
plan_head_before: b838f268cf12c793e4c3cd73da06d045c3ed7629
plan_head_after: 70a4451b000d08b483f9fe3764cf2105ae544519
actuals:
  tokens: 14000
  tasks: 3
  commits: 3
---

# Phase 7 Plan 07: Install evidence and recorded routing eval Summary

The merged tree installs cleanly through all four distribution paths (Claude Code plugin, Codex plugin, bare skills by copy, bare skills by the pinned skills CLI), and the paid Sonnet routing eval scores 1.0 on every one of the eight cases, so ROADMAP criterion 5 (DIST-06) has recorded evidence.

The `actuals.tokens` figure is `chars/4` over the seven committed evidence files (56270 characters); the `commits: 3` count is measured from the plan ledger (`plan_head_before..plan_head_after`), the SUMMARY commit comes after it.

## Task 1: install checks (HEAD b838f268cf12, DIST-01, DIST-02, DIST-03)

| Check | Command | Last line | Real config unchanged |
|---|---|---|---|
| Claude Code | `bash tests/dist/install-claude.sh` | `DIST install-claude: PASS` | yes (`OK real configuration unchanged`) |
| Codex | `bash tests/dist/install-codex.sh` | `DIST install-codex: PASS` | yes |
| bare skills, copy | `bash tests/dist/install-skills.sh --via copy` | `DIST install-skills: PASS` | yes |
| bare skills, skills CLI | `bash tests/dist/install-skills.sh --via skills-cli` | `DIST install-skills: PASS` | yes |

- Claude Code: marketplace add, plugin install, `plugin list --json` (version 0.1.0 equals the clone), `plugin details` lists Skills (6), Agents (2), Hooks (3) matching the clone.
- Codex: `codex debug prompt-input` lists the six `client-dossier:<name>` skills; hooks run-time behaviour is documentation-backed (isolated `CODEX_HOME` not logged in).
- Skills CLI: the in-script registry gate re-ran and printed `verdict: ok` for `skills@1.7.0` (published 2026-09-17, 23 days old, no lifecycle script, GitHub Actions publisher, SLSA provenance) before the CLI ran; it installed 6 skills into `.claude/skills/` and `.agents/skills/`, and the copied `init.py` and `status.py` ran with `lint.available` false.
- Logs: the scripts' own redaction left the throwaway root in the echoed command lines (`/var/folders/.../tmp.XXXX`); those were rewritten to `<tmp>` before committing. a grep for the home prefix and for `/var/folders` counts 0 on all four, `scrub_check` exits 0.

## Haiku shake-out

`claude plugin eval . --scaffold --trust-plugin --ablation none --model haiku --runs 1 --no-publish --max-cost-usd 0.5 --threshold 0`: exit 0, `partial` false, 8 cases, no run error, no scaffold failure, no case file changed. Cost 0.0693 USD (cap 0.5).

| Case | Score | Run error |
|---|---|---|
| call-prepare | 1.0 | none |
| deal-status | 1.0 | none |
| draft-reply | 1.0 | none |
| ingest-transcript | 1.0 | none |
| init-new-client | 1.0 | none |
| outside-dossier | 0.5 | none (grader `suggests-init` failed: pattern not found in last_message; the run used its 8 turns) |
| unrelated | 1.0 | none |
| write-to-client | 1.0 | none |

The Haiku mis-route on `outside-dossier` is recorded and was not acted on (the gate is the Sonnet run). Sonnet scored the same case 1.0 in 3 of 3 runs.

## Task 3: the recorded Sonnet run (DIST-06, ROADMAP criterion 5)

Command, run once: `claude plugin eval . --scaffold --trust-plugin --ablation none --model sonnet --runs 3 --no-publish --max-cost-usd 4 --threshold 0.66 --json <raw>`. Exit code 0. `partial` false, `claudeVersion` 2.1.296, model passed as the alias `sonnet` (the JSON does not record a resolved model id). Mechanical gate: PASS.

| Case | Score (mean of 3 runs) | Graders (all runs) | Run errors | Cost, 3 runs (USD) |
|---|---|---|---|---|
| call-prepare | 1.0 | call-fired 3/3 | none | 0.379 |
| deal-status | 1.0 | status-fired 3/3, draft-not-fired 3/3 | none | 0.253 |
| draft-reply | 1.0 | draft-fired 3/3 | none | 0.400 |
| ingest-transcript | 1.0 | ingest-fired 3/3, draft-not-fired 3/3 | none | 0.414 |
| init-new-client | 1.0 | init-fired 3/3 | none | 0.173 |
| outside-dossier | 1.0 | names-missing-dossier 3/3, suggests-init 3/3 | none | 0.196 |
| unrelated | 1.0 | no-dossier-skill 3/3 | none | 0.078 |
| write-to-client | 1.0 | draft-fired 3/3, ingest-not-fired 3/3 | none | 0.369 |
| TOTAL | 1.0 | | | 2.2627 |

No grader was edited, no skill description was edited, the Sonnet run was not repeated. There is no `## Routing gaps` section because the gate passed.

### Spend

| Run | Cap | Real `costUsd` |
|---|---|---|
| Haiku shake-out | 0.5 | 0.0693 |
| Sonnet recorded run | 4 | 2.2627 |
| Total | 4 (hard cap) | 2.3320 |

### Real configuration was not touched by the paid runs

The paid eval has to use the real session. Before and after each run a snapshot was taken of `~/.claude.json` (hash plus every key matching trust, plugin, marketplace, onboarding or eval, and the per-project trust flags of all 51 projects), `~/.claude/settings.json` and `settings.local.json` (hash plus plugin and trust keys), `~/.claude/plugins/{known_marketplaces,installed_plugins}.json`, `~/.codex/config.toml` (hash plus trust, project and plugin lines), `~/.agents/plugins/marketplace.json`, and the listings of `~/.claude/plugins`, `~/.claude/skills`, `~/.codex`, `~/.agents`.

- Haiku run: settings, plugin registries, Codex config and listings are hash-identical; `~/.claude.json` hash differs (it is rewritten by the live session) but the trust, project and plugin related keys differ in 0 places and the project count stays 51.
- Sonnet run: same result, and a full key-level diff of `~/.claude.json` before and after shows exactly one changed path, `/cachedGrowthBookFeaturesAt` (a feature-flag cache timestamp). No project entry, no `hasTrustDialogAccepted`, no plugin or marketplace entry was added.
- `--trust-plugin` therefore did not persist a trust entry; the stop condition was never met.

## Deviations from Plan

### Auto-fixed Issues

None.

### Plan text differences (not defects)

**1. [Instruction] skills CLI pin is 1.7.0, not 1.7.2.**
- The plan names `skills-1.7.2-registry.txt` and `skills@1.7.2`; 07-05 pinned `skills@1.7.0` (evidence/dist/skills-1.7.0-registry.txt, verdict ok) on the manager's 14-day rule. The verify command was run against the 1.7.0 record. The CLI route ran, and passed.

**2. [Interpretation] isolation of the install scripts.**
- The instruction asked for `CLAUDE_CONFIG_DIR`, `CODEX_HOME` and `HOME` set to fresh `mktemp -d` roots. Each script already does this for every CLI call (`$DIST_ROOT/cfg`, `$DIST_ROOT/home`) and compares the real configuration before and after, so they were run with the real environment around them: wrapping them in a throwaway `HOME` would have turned the `OK real configuration unchanged` proof into a comparison of two empty folders and left the real home path unredacted. The real `~/.claude`, `~/.codex` and `~/.agents` snapshots were byte-identical after all four runs.

**3. [Acceptance criterion] `grep -c 'Skills (6)'` prints 2, not 1.**
- The log holds the `plugin details` line `Skills (6)  dossier, ...` and the check line `ok: Skills (6) equals 6 in the clone`. Both are genuine output; the criterion's count of 1 did not anticipate the check line. `grep -c 'Skills (6)  '` (two spaces) prints 1.

**4. [Evidence] resolved model id.**
- The eval JSON carries `modelOverride` (`haiku`, `sonnet`) and `claudeVersion` but no resolved model id, and the per-run traces are deleted by the runner; the aliases are the only model identification available.

## Known Stubs

None.

## Threat Flags

None.

## Self-Check: PASSED

- Seven evidence files FOUND: the four `evidence/dist/install-*.log`, `evidence/eval/routing-haiku.json`, `routing-sonnet.json`, `routing-sonnet.tsv`.
- Commits FOUND on the branch: 9b50256 (install checks), 671c940 (Haiku shake-out), 70a4451 (Sonnet routing eval).
- `bash tests/run.sh` exits 0 (`TOTAL: 27 files, 0 failed`); `scrub_check` exits 0 on all committed evidence; `/Users/` count is 0 in all of them.
