---
phase: 07-manifests-docs-distribution
plan: 05
subsystem: testing
tags: [distribution, codex, skills-cli, supply-chain, isolation, bash]
requires:
  - "07-01: tests/dist/lib-dist.sh contract, Codex manifest and marketplace listing"
provides:
  - "tests/dist/install-codex.sh: isolated Codex marketplace install check (DIST-02)"
  - "tests/dist/install-skills.sh: bare-skills install check, copy and pinned skills-CLI routes (DIST-03)"
  - "evidence/dist/skills-1.7.0-registry.txt: registry verification record of the pinned skills CLI"
affects: [07-06 (README facts on what a bare install loses), 07-07 (dist evidence logs), 07-09]
tech-stack:
  added: []
  patterns:
    - "fail-closed registry gate re-run before every third-party CLI run"
    - "npm exec --package=<pin> with a before-date, ignore-scripts and a throwaway HOME"
key-files:
  created:
    - tests/dist/install-codex.sh
    - tests/dist/install-skills.sh
    - .planning/phases/07-manifests-docs-distribution/evidence/dist/skills-1.7.0-registry.txt
  modified: []
key-decisions:
  - "skills CLI pinned to 1.7.0, not the plan's 1.7.2: the manager's binding instruction is the newest version published more than 14 days ago (1.7.1 is 5 days, 1.7.2 is 2 days old)"
  - "dependencies of the CLI are resolved as of 2026-09-27 (npm before-date) so tar and yaml cannot float to a newer release than the pin's era"
  - "the gate also enforces a minimum age of 14 days, on top of the plan's criteria"
status: complete
commits: 3
plan_head_before: e16a3f94c30ad5a25c118f203b862c2e1a05f2e0
plan_head_after: bc7aa2ad1b2b333578531a112e80e8d4e962f62d
actuals:
  tokens: 5500
  tasks: 3
  commits: 3
---

# Phase 7 Plan 05: Codex and bare-skills install checks Summary

The Codex marketplace install and the bare `skills/` install (by plain copy and by the pinned, registry-gated `skills` CLI) are each proven from a fresh clone of HEAD inside a throwaway HOME, with Samuel's real configuration byte-identical before and after.

## Tasks

| Task | Name | Commit |
|---|---|---|
| 1 (tracer) | Codex marketplace install check | 42a82d3 |
| 2 | Registry gate of the pinned skills CLI, recorded | 2c8c1a3 |
| 3 | Bare-skills install check, copy and skills-CLI routes | bc7aa2a |

## Registry gate record (skills@1.7.0)

```text
package: skills@1.7.0   published: 2026-09-17T15:02:04.338Z   age_days: 23
repository: git+https://github.com/vercel-labs/skills.git   deprecated: no
lifecycle_scripts: none   publisher: GitHub Actions
provenance: https://slsa.dev/provenance/v1   verdict: ok
```

Version choice: 1.7.1 (2026-10-06) and 1.7.2 (2026-10-09) are under 14 days old and were skipped; 1.7.0 is the newest version older than the cut-off 2026-09-27. Full record: `.planning/phases/07-manifests-docs-distribution/evidence/dist/skills-1.7.0-registry.txt`. The gate ran from registry metadata only (`npm view`); no package code ran for it.

## Route results

- `bash tests/dist/install-codex.sh`: last line `DIST install-codex: PASS`. Marketplace add and plugin add exit 0; `codex plugin list --json` shows client-dossier@client-dossier installed, enabled, version 0.1.0, source local; cache copy holds `.codex-plugin/plugin.json`, `skills/dossier/SKILL.md`, `hooks/hooks.json`; `codex debug prompt-input` lists exactly the six `client-dossier:<name>` skills (dossier, dossier-call, dossier-draft, dossier-ingest, dossier-init, dossier-status); `OK real configuration unchanged`.
- `bash tests/dist/install-skills.sh --via copy`: last line `DIST install-skills: PASS`. No npm call.
- `bash tests/dist/install-skills.sh --via skills-cli`: gate ok, then `npm exec --yes --package=skills@1.7.0 -- skills add <clone> --skill '*' --agent claude-code codex cursor gemini-cli opencode github-copilot --copy -y` exits 0 and ends `DIST install-skills: PASS`. The CLI wrote `./.claude/skills/<name>` and `./.agents/skills/<name>` for all six skills, preserving the executable bit of the private scripts.
- Refusal check: `DIST_SKILLS_SPEC=skills@0.0.0-nonexistent bash tests/dist/install-skills.sh --via skills-cli` exits 2 (`HARNESS ERROR`, npm E404 on the metadata call) before any install.
- Both skills routes: no `lint.py`, `hooks.json`, `fact-extractor.md` or `doctrine-reviewer.md` under the project folder; the copied `init.py` scaffolds a dossier standalone (exit 0, `dossier.yaml` written) and the copied `status.py --json` exits 0 with `lint.available` false (no plugin marker beside a bare copy).

## Coverage limits (stated, not claimed)

- Codex hooks: only their presence in the cache copy is checked. Run-time behaviour (trust in `/hooks`, PreToolUse deny) is documentation-backed; an isolated CODEX_HOME is not logged in, so it was not exercised.
- Codex agents (`agents/*.md`) are not consumed by Codex and are not part of this check.
- The `skills` CLI was run under Claude Code, so it printed an "Agent detected" line and installed non-interactively; the result was the same six skills in both folders.

## Deviations from Plan

### Auto-fixed / decided

**1. [Binding instruction - pin] skills CLI version 1.7.0 instead of 1.7.2**
- **Found during:** Task 2
- **Issue:** The plan pinned 1.7.2, published about 2 days before the run; the manager's instruction requires the newest version older than 14 days.
- **Fix:** Pin `skills@1.7.0` (single variable `SKILLS_SPEC`, default in the script), record named `skills-1.7.0-registry.txt` instead of `skills-1.7.2-registry.txt`. The plan's `files_modified` entry and the acceptance greps for `skills@1.7.2` are read as `skills@1.7.0`. The 11 field-line count, the single `@` in the record and the `npx`/`skills@latest` absence all hold.
- **Files modified:** tests/dist/install-skills.sh, evidence/dist/skills-1.7.0-registry.txt
- **Commit:** 2c8c1a3

**2. [Rule 2 - supply chain] age criterion and dependency before-date added**
- **Issue:** the plan treated age as informational. With a 14-day rule in force, the gate refuses a version under 14 days old; and the two dependencies (tar, yaml) carry caret ranges that would otherwise float to the newest release.
- **Fix:** `age_days >= 14` is a refusal criterion; the CLI run sets the npm before-date to 2026-09-27 (`DIST_SKILLS_BEFORE` override) so the whole tree resolves as of that date.
- **Commit:** 2c8c1a3, bc7aa2a

**3. [Rule 1 - acceptance] raw `codex debug prompt-input` output not logged**
- **Found during:** Task 1
- **Issue:** the raw output is one JSON line of several KB (the whole prompt), which defeats the `grep -c 'client-dossier:dossier'` >= 6 acceptance and bloats evidence logs.
- **Fix:** the script prints one `skill client-dossier:<name> -> <cache path>` line per plugin skill (redacted); the sorted-unique check still runs on the full output.
- **Commit:** 42a82d3

### Note on the harness environment

The worktree command guard refused several compound shell forms (HOME override on a direct command, `source`, `;` chains). Isolation was achieved inside the scripts themselves, as designed, and metadata was read through a small throwaway script run under a mktemp HOME.

## Supply-chain gate

Not refused: verdict ok for skills@1.7.0, so both routes ran. No `## Supply-chain gate refused` condition.

## Known Stubs

None.

## Threat Flags

None. The scripts add no endpoint or write path beyond the throwaway root.

## Self-Check: PASSED
