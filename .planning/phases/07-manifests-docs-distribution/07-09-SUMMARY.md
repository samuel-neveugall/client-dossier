---
phase: 07-manifests-docs-distribution
plan: 09
subsystem: distribution
tags: [closure, claude-md, spec, traceability, pre-publication, command-smoke, release-rehearsal, validation]
requires:
  - "07-01..07-08: manifests, release.sh, guard, evals, install checks, README, evidence, the dossier-lint command (D-18)"
provides:
  - "CLAUDE.md: Phase 7 state sentence, eval line, one remaining validate warning, the Phase 7 commands"
  - "spec 4 tree, 4.3 (Codex hooks and apply_patch) and 8 (directory, approval gates, versionless marketplace entries) aligned"
  - "REQUIREMENTS DIST-01..07 ticked with evidence rows; ROADMAP plan items 07-01..07-08 ticked"
  - "STATE.md pre-publication checklist (D-12, not executed in v1)"
  - "evidence/uat/: the recorded command smoke for 07-UAT"
  - "07-VALIDATION.md finalized: 24 green task rows"
affects: [phase verification, 07-UAT, milestone audit, publication]
tech-stack:
  added: []
  patterns:
    - "agent-run paid smoke driver sourcing lib-scenario.sh and lib-dist.sh, real-configuration snapshot before and after"
key-files:
  created:
    - .planning/phases/07-manifests-docs-distribution/evidence/uat/command-smoke.sh
    - .planning/phases/07-manifests-docs-distribution/evidence/uat/lint-smoke.jsonl
    - .planning/phases/07-manifests-docs-distribution/evidence/uat/status-smoke.jsonl
    - .planning/phases/07-manifests-docs-distribution/evidence/uat/smoke-summary.tsv
    - .planning/archives/state/racine-STATE-2026-10-12.md
  modified:
    - CLAUDE.md
    - docs/superpowers/specs/2026-09-16-client-dossier-design.md
    - .planning/REQUIREMENTS.md
    - .planning/ROADMAP.md
    - .planning/STATE.md
    - .planning/phases/07-manifests-docs-distribution/07-VALIDATION.md
key-decisions:
  - "DIST-06 ticked: the committed routing-sonnet.json gate holds (partial false, eight cases, every case 1.0, write-to-client 1.0)"
  - "The slash-command smoke proves the SKILL.md expansion by the expanded skill-folder path in a Bash command, not by the heading in the stream (stream-json does not echo the first user message)"
status: complete
commits: 3
plan_head_before: 719e3c81ff2a13adb2d11a688ede6b7343984e27
plan_head_after: 602924dda3abdaff598bf8f8daa3d184f0df90be
actuals:
  tokens: 25000
  tasks: 3
  commits: 3
---

# Phase 7 Plan 09: Closure, pre-publication checklist, command smoke and validation Summary

CLAUDE.md, the spec, REQUIREMENTS, ROADMAP and STATE now say what Phase 7 shipped, the two slash forms work on a real Haiku model without shadowing, `scripts/release.sh 1.0.0` cuts a clean release on a scratch clone while this repository stays untagged at 0.1.0, and 07-VALIDATION.md holds 24 green rows. Final suite: `TOTAL: 30 files, 0 failed`.

`actuals.tokens` is chars/4 over the realized diff (101966 characters, evidence JSONL included); `commits: 3` is measured from the plan ledger (`plan_head_before..plan_head_after`); the SUMMARY commit follows it.

## Tasks

| Task | Name | Commit |
|---|---|---|
| 1 (tracer) | CLAUDE.md records Phase 7 and every free command it lists runs green | f76daf8 |
| 2 | Spec amendments, traceability ticks, pre-publication checklist | 87768af |
| 3 | Command smoke, release rehearsal, full verification, validation contract | 602924d |

Task 1 ran each newly listed free command as written: `test-manifests` PASS 62, `test-release` PASS 359, `test-readme` PASS 102, `test-evals-shape` PASS 236, `test-hook-guard-sources` PASS 1883, `install-claude` PASS, `install-codex` PASS, `install-skills --via copy` PASS (each install check proved the real configuration byte-identical).

## Spec check

Lines before and after in `docs/superpowers/specs/2026-09-16-client-dossier-design.md`:

- 4 tree, `tests/`: `... scenarios/ holds the paid pressure-scenario harness` became `... scenarios/ holds the paid pressure-scenario harness; dist/ the isolated install checks (free, outside run.sh)`.
- 4 tree, new line after it: `evals/  claude plugin eval routing cases (paid, run by the team; results/ is ignored)`.
- 4 tree, `docs/`: `this spec, the protocol reference, the fact-line reference` became `this spec (the protocol lives in the dossier skill, the fact-line rules in section 3.4 and the linter)`.
- 4.3, after `Hooks are a convenience.`: new paragraph, Codex loads the same `hooks/hooks.json` after `/hooks` trust, and the PreToolUse guard judges the `*** Add File:`, `*** Update File:`, `*** Delete File:` and `*** Move to:` headers of `apply_patch` like the Write family (D-05).
- 8, after the submission-process paragraph: OpenAI's public directory does not list plugins with lifecycle hooks (D-13); publishing, pushing a tag and making the repository public each need Samuel's explicit approval (D-01).
- 8, versioning paragraph: added that the marketplace entries carry no version, `plugin.json` being the single version source in each harness.

CLAUDE.md does not contradict the amended spec (its Commands list names `apply_patch`, the one remaining validate warning and the D-18 command).

## UAT evidence (for 07-UAT)

Driver: `evidence/uat/command-smoke.sh` (agent-run, bash 3.2, exit 0 both pass), Haiku (`claude-haiku-5-5`), `--max-budget-usd 0.25` per run, scratch dossier from `build_dossier` holding `outbound/mails/<today>_note.md` with one plain sentence and no status header. The direct `python3 scripts/lint.py` run exits 1 with the single finding id `E1`.

| Run | Verdict | Checks | Model | Cost USD | is_error |
|---|---|---|---|---|---|
| `/client-dossier:dossier-lint` | PASS | `/client-dossier:dossier-lint` listed in the init slash commands; a Bash command ran `scripts/lint.py` with `${CLAUDE_PLUGIN_ROOT}` expanded; the result relays `E1` and `exit code: 1`; dossier tree hash unchanged | claude-haiku-5-5 | 0.00243 | false |
| `/client-dossier:dossier-status` | PASS | the Bash commands use the expanded `.../skills/dossier-status/scripts/status.py` path (no literal `${CLAUDE_SKILL_DIR}`); `already loaded above` never appears; dossier tree hash unchanged; `status.py` was run (informational) | claude-haiku-5-5 | 0.00402 | false |

Evidence files: `lint-smoke.jsonl`, `status-smoke.jsonl`, `smoke-summary.tsv`, `command-smoke.sh`, all redacted with `dist_redact` (repository `<repo>`, throwaway root `<tmp>`, home `~`) and `scrub_check`ed; `grep -c '/Users/'` on the tsv prints 0. The real Claude Code and Codex configuration was byte-identical before and after (`OK real configuration unchanged`).

The recorded command text shows two observations the 07-UAT should know: the `dossier-lint` run used `.` as the path (cwd), and the `dossier-status` run also loaded the `dossier` entry skill, as the status skill's own text asks.

### Smoke cost

| Run | Cost USD |
|---|---|
| First attempt (lint 0.00236, status 0.00405; the status check was wrong, see Deviations; the evidence was overwritten) | 0.00641 |
| Recorded run (lint 0.00243, status 0.00402) | 0.00645 |
| Total of plan 07-09 | 0.01286 |

Phase 7 paid spend: plan 07-07 2.3320 USD (Haiku 0.0693 and Sonnet 2.2627) plus plan 07-09 0.0129 = 2.3449 USD. Plan 07-09 stayed far under its 0.3 USD ceiling.

## Release rehearsal

Run on a scratch clone of the plan's HEAD (script `rehearsal.sh` in the session scratchpad, not committed; the clone, its bare origin and the throwaway committer identity lived under `mktemp -d` and were removed). The clone's origin was re-pointed to an empty bare repository before `release.sh` ran.

```text
clone branch: worktree-agent-a41f78a6e0e27ae75  origin: <tmp>/bare.git
release: tagged v1.0.0 locally. Nothing was pushed.        (scripts/release.sh 1.0.0, exit 0)
release commit: chore(release): v1.0.0
[.claude-plugin/plugin.json]  -  "version": "0.1.0",   +  "version": "1.0.0",
[.codex-plugin/plugin.json]   -  "version": "0.1.0",   +  "version": "1.0.0",
files in the release commit: .claude-plugin/plugin.json, .codex-plugin/plugin.json, CHANGELOG.md (3 files, 4 insertions, 2 deletions)
CHANGELOG: line 8 `## [Unreleased]`, line 10 `## [1.0.0] - 2026-10-12`
git cat-file -t v1.0.0: tag          (annotated)
git ls-remote <bare origin>: 0 refs  (nothing pushed)
```

This repository: both manifests at `0.1.0`, `grep -cE '^## \[[0-9]' CHANGELOG.md` prints 0, `git tag -l 'v*'` is empty.

## Verification

- `bash tests/run.sh`: `TOTAL: 30 files, 0 failed` (25 before the phase plus test-manifests, test-release, test-evals-shape, test-readme, test-commands).
- `claude plugin validate .` under temporary config and home: exit 0, exactly one warning (root CLAUDE.md, D-03); `--strict` exits 1 by design.
- 07-VALIDATION.md: 24 task rows, all `green`, each from the exit code of the task's own `<automated>` verify re-run on 2026-10-12 against this plan's tree; 07-09-T3's verify (smoke rows, scrub, suite, no tag, manifests, CHANGELOG, 24 green) exits 0.
- Codex real-hook tests were NOT run (no OpenAI login on this machine): the 07-VALIDATION manual-only row and checklist item 5 say so; the `apply_patch` guard is proven with Codex-shaped stdin only.

## Deviations from Plan

**1. [Rule 1 - Bug] The status-smoke check could not observe the injected heading**
- **Found during:** task 3 first paid run. The plan's check required the line `# dossier-status` in a non-assistant stream message. stream-json does not echo the first user message, where a slash command places the expanded SKILL.md, so the check failed although the skill had been expanded (the model's first Bash command was the skill's own `test -x ".../skills/dossier-status/scripts/status.py"`, with `${CLAUDE_SKILL_DIR}` already substituted).
- **Fix:** the check now requires a Bash command using the expanded `/skills/dossier-status/scripts/status.py` path with no literal `CLAUDE_SKILL_DIR`, keeps the `already loaded above` absence check, and records the heading observation as informational (`info:heading-in-stream=none`). The smoke was rerun once (0.0064 USD) and passed; the evidence is from the second run.
- **Files modified:** evidence/uat/command-smoke.sh. **Commit:** 602924d.

**2. [Environment] The paid smoke ran under the real session, not an isolated CLAUDE_CONFIG_DIR/HOME**
- An isolated config or HOME loses the login: `claude auth status` reports `loggedIn: false` in all three variants (isolated config and home, config only, home only), probed. Like plan 07-07's eval, the run uses the real session with `--setting-sources project,local` and `--no-session-persistence` (from `run_claude`), `--plugin-dir` loads the plugin for the session only, and the script proves the real settings and plugin registries byte-identical before and after (`dist_real_snapshot`): `OK real configuration unchanged`. `claude plugin validate` and the install checks do run with temporary config and home.

**3. [Size cap vs acceptance] STATE.md lines removed exceed the plan's "at most three"**
- STATE.md was 8006 bytes before the checklist; the instruction was to keep it under 8 KB. The plan's task 2 acceptance allows at most three removed lines. To fit, resolved history was moved verbatim to `.planning/archives/state/racine-STATE-2026-10-12.md` (three resolved debt rows, three resolved Blockers bullets, with a `vf-archive` pointer comment), and the stale Pending Todos item (Q15, settled by D-18) was replaced by a one-line note. The diff shows 9 removed lines; STATE.md is 7056 bytes. The three required amendments (the validate line and the two accepted-debt Status cells) were made as appended text. The frontmatter, Current Position and Session Continuity were not touched.

**4. [Plan text predates a later fact] skills pin 1.7.0 and no package install**
- The plan texts of 07-05 and 07-07 name `skills@1.7.2`; 07-05 pinned 1.7.0. When re-running the verify commands for 07-VALIDATION, `1.7.2` was read as `1.7.0` and the skills-CLI half of 07-05-T3 was replaced by the committed `install-skills-cli.log` (07-07, PASS) plus the live refusal of a bad pin, because plan 07-09 installs no package (T-07-SC). The 07-VALIDATION preamble says so.

**5. [Environment] Git launcher guard**
- The Bash guard refused rtk-wrapped `git` and compound commands in the worktree; `/usr/bin/git` and plain commands or script files were used. The worktree branch (empty at b8aae7a) was fast-forwarded to `feat/phase-07-manifests-docs-distribution` (719e3c8) before any work.

**6. [Interpretation] ROADMAP, REQUIREMENTS and STATE scope**
- Only the DIST-01..07 boxes and traceability rows, the 07-01..07-08 plan items and the STATE sections above were edited. The ROADMAP phase checkbox, the progress row, the 07-09 plan item and STATE's position fields are left to the engine, after verification and UAT. `gsd-tools state` verbs were not used.

## Known Stubs

None.

## Threat Flags

None beyond the plan's threat model: T-07-29 (the checklist names the four surfaces, nothing published), T-07-30 (task 1 ran every documented free command; DIST-06 ticked from the committed gate), T-07-31 (rehearsal origin was an empty bare repository, 0 refs, no `v*` tag here), T-07-32 (two Haiku runs, 0.0129 USD in total).

## Self-Check: PASSED

- Files FOUND: evidence/uat/{command-smoke.sh, lint-smoke.jsonl, status-smoke.jsonl, smoke-summary.tsv}, `.planning/archives/state/racine-STATE-2026-10-12.md`, 07-VALIDATION.md.
- Commits FOUND on the branch: f76daf8, 87768af, 602924d (ancestors of HEAD).
- `git tag -l 'v*'` is empty; both manifests at 0.1.0; CHANGELOG holds no released heading.
