---
phase: 07-manifests-docs-distribution
verified: 2026-10-12T00:00:00Z
status: passed
score: 6/6 must-haves verified
covered_files:
  - ".agents/plugins/marketplace.json"
  - ".claude-plugin/marketplace.json"
  - ".claude-plugin/plugin.json"
  - ".codex-plugin/plugin.json"
  - ".planning/phases/07-manifests-docs-distribution/07-01-PLAN.md"
  - ".planning/phases/07-manifests-docs-distribution/07-01-SUMMARY.md"
  - ".planning/phases/07-manifests-docs-distribution/07-02-PLAN.md"
  - ".planning/phases/07-manifests-docs-distribution/07-02-SUMMARY.md"
  - ".planning/phases/07-manifests-docs-distribution/07-03-PLAN.md"
  - ".planning/phases/07-manifests-docs-distribution/07-03-SUMMARY.md"
  - ".planning/phases/07-manifests-docs-distribution/07-04-PLAN.md"
  - ".planning/phases/07-manifests-docs-distribution/07-04-SUMMARY.md"
  - ".planning/phases/07-manifests-docs-distribution/07-05-PLAN.md"
  - ".planning/phases/07-manifests-docs-distribution/07-05-SUMMARY.md"
  - ".planning/phases/07-manifests-docs-distribution/07-06-PLAN.md"
  - ".planning/phases/07-manifests-docs-distribution/07-06-SUMMARY.md"
  - ".planning/phases/07-manifests-docs-distribution/07-07-PLAN.md"
  - ".planning/phases/07-manifests-docs-distribution/07-07-SUMMARY.md"
  - ".planning/phases/07-manifests-docs-distribution/07-08-PLAN.md"
  - ".planning/phases/07-manifests-docs-distribution/07-08-SUMMARY.md"
  - ".planning/phases/07-manifests-docs-distribution/07-09-PLAN.md"
  - ".planning/phases/07-manifests-docs-distribution/07-09-SUMMARY.md"
  - "CHANGELOG.md"
  - "LICENSE"
  - "README.md"
  - "commands/dossier-lint.md"
  - "scripts/release.sh"
covered_digest: "v3:sha256:4df0aea62169317b4508e2c3bb22c64d1ec1bb94abce67c9d8b0774f229174c8"
behavior_unverified: 0
overrides_applied: 0
---

# Phase 7: Manifests, Docs & Distribution Verification Report

**Phase Goal:** Someone outside this repository can install and trust the plugin on the harness of their choice.
**Verified:** 2026-10-12 (branch feat/phase-07-manifests-docs-distribution, HEAD 226f1b2)
**Status:** passed
**Re-verification:** No, initial verification

## Goal Achievement

### Observable Truths (ROADMAP success criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `/plugin marketplace add` then `/plugin install` installs the plugin end to end in Claude Code | VERIFIED | `.claude-plugin/plugin.json` and `marketplace.json` are complete (name, 0.1.0, author, MIT, repo URLs, plugin entry `source: "./"`). `evidence/dist/install-claude.log` (from `tests/dist/install-claude.sh`, isolated config, clone of HEAD `b838f26`): marketplace add exit 0, install exit 0, `plugin list --json` enabled at 0.1.0, `plugin details` shows Skills (6), Agents (2), Hooks (3), installed copy holds `skills/dossier/SKILL.md`, `hooks/hooks.json`, `scripts/lint.py`, real config byte-identical. Manifests and marketplaces are unchanged since `b838f26` (`git diff --stat b838f26 HEAD -- .claude-plugin .codex-plugin .agents` shows only the added `commands/dossier-lint.md`). I re-ran `claude plugin validate .`: exit 0, one warning (root CLAUDE.md). |
| 2 | Codex manifests and a bare copy of `skills/*/SKILL.md` each install on their harness; README states what the bare install loses | VERIFIED | `install-codex.log`: `codex plugin marketplace add` + `plugin add` exit 0, installed and enabled, `codex debug prompt-input` lists the 6 `client-dossier:<name>` skills, cache copy holds manifest, skills, hooks. `install-skills-copy.log` and `install-skills-cli.log`: 6 skill folders copied into `.claude/skills/` and `.agents/skills/`, no `lint.py`/hooks/agents leak, copied `init.py` and `status.py` run (`lint.available=false`), plus the `skills@1.7.0` CLI route. README "What this install loses" names scripts/lint.py, the three hooks, and both agents, with the fallback. Limitation: see below on Codex hooks. |
| 3 | README documents all four install targets plus versioning and license; CHANGELOG.md and MIT LICENSE exist | VERIFIED | `README.md` sections: Claude Code, Codex, Agent Skills harnesses (Cursor, Copilot CLI, Gemini CLI, OpenCode), AGENTS.md-only, Versioning (semver, CHANGELOG, tag `vX.Y.Z`), License (MIT), Limits (sources guard D-04 limits: eval, interpreters, substitutions, variables, loops, piped patches, nested shells, size bounds), Privacy. `LICENSE` is "MIT License". `CHANGELOG.md` is Keep a Changelog with `[Unreleased]`. `tests/test-readme.sh` passes. |
| 4 | Five task skills are the slash commands `/client-dossier:dossier-<name>`, arguments passed through; one command `dossier-lint` runs `scripts/lint.py`; no command shadows a skill (DIST-04 as amended by D-18) | VERIFIED | `commands/` holds exactly one file, `dossier-lint.md`, which runs `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/lint.py" '<path>'`, passes `$ARGUMENTS`, refuses a quote or newline in the path, relays the exit codes 0/1/2/3. No skill is named `dossier-lint`; the `dossier` skill has no command. Six skill folders exist with `name:` frontmatter equal to the folder. `tests/test-commands.sh` passes. Live smoke `evidence/uat/smoke-summary.tsv`: `lint-smoke` PASS (command listed, bash ran lint.py, finding IDs and exit 1 relayed, dossier unchanged) and `status-smoke` PASS (the skill body expanded as a slash command, no shadowing sign). |
| 5 | `claude plugin eval` confirms "write to the client" routes to `dossier-draft`, not `dossier-ingest` | VERIFIED | `evals/routing/` holds 8 cases (call-prepare, deal-status, draft-reply, ingest-transcript, init-new-client, outside-dossier, unrelated, write-to-client), each with `case.yaml`, `prompt.md`, scaffold and graders. `write-to-client` graders: `dossier-draft` fired (min 1) and `dossier-ingest` never (max 0). `evidence/eval/routing-sonnet.json`: 8/8 cases passed, score 1, 3 runs each, `partial=false`, claude 2.1.296, cost $2.26; a Haiku run is recorded too. `tests/test-evals-shape.sh` passes (free). |
| 6 | `scripts/release.sh <version>` leaves both manifests at the same version, a matching CHANGELOG heading and a git tag | VERIFIED | I ran it in a scratch clone (`--allow-branch`, because the clone's origin/HEAD is the feature branch): exit 0, commit `chore(release): v9.9.9`, both manifests at 9.9.9, CHANGELOG `## [Unreleased]` then `## [9.9.9] - 2026-10-12`, annotated tag `v9.9.9`, `Nothing was pushed`. A second run was refused (branch check), and the injection string `1.0.0;rm -rf x` was refused as a non-semver. No tag leaked into this repository (`git tag -l` is empty, working tree has only the pre-existing dag.json modification). `tests/test-release.sh` passes; the 07-09 summary records a 1.0.0 rehearsal with an empty bare origin. |

**Score:** 6/6 truths verified (0 behavior-unverified).

### Requirements Coverage

| Requirement | Description | Status | Evidence |
|-------------|-------------|--------|----------|
| DIST-01 | Claude manifest + marketplace install via marketplace add / install | SATISFIED | Criterion 1; `install-claude.log` |
| DIST-02 | Codex manifest + `.agents/plugins/marketplace.json` | SATISFIED | Criterion 2; `.codex-plugin/plugin.json` (`skills: ./skills/`, interface block), marketplace entry (`source local ./`, `AVAILABLE`); `install-codex.log` |
| DIST-03 | Bare `skills/*/SKILL.md` installable, behaves without scripts/hooks/agents, README says what is lost | SATISFIED | `install-skills-copy.log`, `install-skills-cli.log`, README section; `tests/test-skills-task.sh`, `test-skill-shape.sh` |
| DIST-04 | Task skills are slash commands; one `dossier-lint` command; no shadowing (as amended by D-18) | SATISFIED | Criterion 4; see warning on argument pass-through below |
| DIST-05 | README for four targets, versioning, MIT LICENSE, Bash guard D-04 limits | SATISFIED | Criterion 3; README "Limits / The sources guard" |
| DIST-06 | `claude plugin eval` suites verify trigger descriptions | SATISFIED | Criterion 5; `evals/routing/`, `routing-sonnet.json` |
| DIST-07 | `release.sh` bumps both manifests, updates CHANGELOG heading, creates tag | SATISFIED | Criterion 6; own scratch rehearsal |

No orphaned requirements: REQUIREMENTS.md maps DIST-01..07 to Phase 7 and all seven are claimed.

### Behavioral Spot-Checks and Test Runs

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full suite | `bash tests/run.sh` | `TOTAL: 30 files, 0 failed` (includes test-manifests, test-release, test-evals-shape, test-readme, test-commands) | PASS |
| Manifest validation | `claude plugin validate .` | exit 0, one warning (root CLAUDE.md not loaded as plugin context) | PASS |
| Release rehearsal | `scripts/release.sh --allow-branch 9.9.9` in a scratch clone | tagged locally, nothing pushed, refusals work | PASS |

### Anti-Patterns Found

None. `TBD|FIXME|XXX` scan over README, CHANGELOG, release.sh, commands/ and evals/ found no marker. Phase 7 review rounds (07-REVIEW, 07-REVIEW-FIX) end `passed`; their findings (quoting, heredoc apply_patch guard, release rollback) are reflected in the current tests and code.

### Intentional state, not gaps

- Manifests stay at 0.1.0 and CHANGELOG holds only `[Unreleased]` until after the milestone audit (07 D-01). Confirmed: both manifests 0.1.0, no `## [x.y.z]` heading, no tags.
- Pushing, publishing to a marketplace and making the repository public need Samuel's approval (D-01). README install commands use `samuel-neveugall/client-dossier`; that GitHub path cannot be installed from before publication, so the install evidence uses a local clone of HEAD. This is the same install mechanism, not a different one.

### Limitations (stated, not passes, not gaps)

1. **Codex hooks were not exercised at run time.** No OpenAI login on this machine. Codex install, enablement and skill listing are proven; the hooks' behaviour on Codex (trust in `/hooks`, the `apply_patch` guard on a live Codex run) is only proven with Codex-shaped stdin against the guard, and the README says so ("checked against the guard's input contract, not on a live Codex run"). No ROADMAP criterion or DIST requirement asserts live Codex hook behaviour, so this is a documented residual risk, recorded as the manual-only row in 07-VALIDATION.
2. **The slash-command smoke ran on the real Claude login, not an isolated config** (an isolated config or HOME loses the login). It used `--setting-sources project,local`, `--no-session-persistence` and `--plugin-dir`, and the script proves the real settings and plugin registries byte-identical before and after. The install and validate checks do use temporary config and home.
3. **Pin syntax `owner/repo@v1.0.0`** (README, Claude) is unverified until a tag and a public repository exist (review finding R8-F3, to check before publication).

### Warnings (non-blocking)

- Argument pass-through for the task-skill slash commands was not smoked with an argument. Evidence shows `dossier-status` expanding as a slash command and `dossier-lint` relaying `$ARGUMENTS`; `dossier-draft` and `dossier-call` read an `ARGUMENTS:` line and `dossier-init` takes inputs "given as an argument". This relies on Claude Code's own skill-argument handling. It does not fail DIST-04 (the amended text defines the slash commands as the skills themselves), but a one-line live check with an argument on `dossier-draft` would close it.

### Human Verification Required

None required for the phase goal. The limitations above are for the milestone audit and pre-publication checklist (07-09 delivered the checklist).

### Gaps Summary

No gaps. All six roadmap criteria and DIST-01..DIST-07 are met by files that exist and by commands I re-ran: the suite (30 files, 0 failed), the manifest validation (exit 0, one warning), and a release rehearsal. The remaining items are publication steps deliberately held back by D-01, and the Codex live-hook test that could not be run here.

---

_Verified: 2026-10-12_
_Verifier: Claude (gsd-verifier)_
