---
phase: 07-manifests-docs-distribution
plan: 01
subsystem: distribution
tags: [manifests, marketplace, claude-code, codex, install-check]
requires: []
provides:
  - completed Claude Code manifest and self-hosted marketplace (DIST-01)
  - Codex manifest and marketplace listing (DIST-02, D-14)
  - tests/test-manifests.sh (static pins + claude plugin validate gate)
  - tests/dist/lib-dist.sh and tests/dist/install-claude.sh (isolated install checks)
affects: [07-02, 07-05, 07-07, 07-09]
tech-stack:
  added: []
  patterns: ["python3 -I heredoc reading JSON via argv, label/expected/actual lines", "isolated CLI runs under mktemp CLAUDE_CONFIG_DIR + HOME", "install from a fresh clone of HEAD"]
key-files:
  created:
    - .claude-plugin/marketplace.json
    - .codex-plugin/plugin.json
    - .agents/plugins/marketplace.json
    - tests/test-manifests.sh
    - tests/dist/lib-dist.sh
    - tests/dist/install-claude.sh
  modified:
    - .claude-plugin/plugin.json
decisions:
  - "Versions stay 0.1.0 in both manifests (D-01, D-16); release.sh bumps later"
  - "Marketplace entries carry name and source only (Pitfall 4)"
status: complete
metrics:
  duration: "~25 min"
  completed: 2026-10-11
actuals:
  tokens: 6745
  tasks: 2
  commits: 2
plan_head_before: 00d713a5b08192a37ed8e2c017a78c3c682c9c4d
plan_head_after: 81f87ee9880027baca92fb75bf89426fd5d8caa6
---

# Phase 7 Plan 01: Manifests, marketplaces and isolated Claude install Summary

Four distribution manifests (Claude plugin + marketplace, Codex plugin + marketplace listing) pinned by a free static test, with `claude plugin validate` gated at one warning, and an isolated clone-of-HEAD install check that proves the Claude Code marketplace path end to end.

## Commits

| Task | Commit | Files |
|------|--------|-------|
| 1 (tracer) | 29b5ff7 | .claude-plugin/plugin.json, .claude-plugin/marketplace.json, tests/test-manifests.sh, tests/dist/lib-dist.sh, tests/dist/install-claude.sh |
| 2 | 81f87ee | .codex-plugin/plugin.json, .agents/plugins/marketplace.json, tests/test-manifests.sh |

## Verification

- `bash tests/test-manifests.sh`: PASS 62 FAIL 0 (red first at each task: 10 failures before the Claude files, 4 before the Codex files).
- Negative check by hand (reverted): a marketplace entry given `"version"` fails the entry-keys check.
- `bash tests/run.sh`: `TOTAL: 25 files, 0 failed`, exit 0.
- `bash tests/dist/install-claude.sh`: `DIST install-claude: PASS`, run on HEAD 29b5ff7 and again on HEAD 81f87ee. The log carries zero `/Users/` lines and the real configuration snapshot was identical before and after (`OK real configuration unchanged`). No temporary root was left behind.
- ROADMAP criterion 1 (install end to end from its own marketplace) holds, verified in isolation.

### Observed shapes

`claude plugin validate . --json` (Claude Code 2.1.296): `target` is `.claude-plugin/marketplace.json`, `manifest.type` is `marketplace` with empty `errors`/`warnings`; the plugin appears under `contents[]` (`CLAUDE.md`, `type: plugin`) with one warning:
`CLAUDE.md at the plugin root is not loaded as project context. To ship context with your plugin, use a skill (skills/<name>/SKILL.md) instead.` Exit 0; `--strict` exits 1. Before this plan's author field there were two warnings.

`claude plugin list --json`: array of `{id, version, scope: user, enabled, installPath, readFromFolder, folderVersion, installedAt, lastUpdated, projectEnabled}`; `installPath` is `<cfg>/plugins/cache/client-dossier/client-dossier/0.1.0`, `readFromFolder` the clone.

`claude plugin details client-dossier@client-dossier` (same format as at planning time, no parser adaptation needed):

```text
Component inventory
  Skills (6)  dossier, dossier-call, dossier-draft, dossier-ingest, dossier-init, dossier-status
  Agents (2)  fact-extractor, doctrine-reviewer
  Hooks (3)  SessionStart, PreToolUse, Stop  (harness-only — no model context cost)
  MCP servers (0)
  LSP servers (0)
```

Last lines of the install log:

```text
ok: installed copy holds scripts/lint.py
OK real configuration unchanged
ok: real Claude Code and Codex configuration byte-identical
DIST install-claude: PASS
```

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Worktree base behind the phase branch**
- **Found during:** start
- **Issue:** the worktree branch sat at b8aae7a (phase 6 merge), so the phase 7 plan files were absent.
- **Fix:** fast-forwarded the worktree branch to `feat/phase-07-manifests-docs-distribution` (00d713a, a strict descendant: `git merge --ff-only`), no history rewritten.
- **Commit:** none (ref move only)

**2. [Environment] Global shell guard**
- The isolated-worktree guard refused compound shell commands and the `rtk git` rewrite, so git ran as `/usr/bin/git` and commit messages via `-F`. The per-plan HEAD ledger (protocol 0c) lives in the shared git dir, outside the worktree, so `plan_head_before` was recorded from `git rev-parse HEAD` before the first commit instead; `commits: 2` is measured with `git rev-list --count` from it.

Otherwise: plan executed as written. No changes to CLAUDE.md, `.planning/` (other than this summary), skills, hooks, scripts, `tests/run.sh`, `tests/lib.sh`, `tests/scenarios/`. STATE.md and ROADMAP.md untouched by instruction.

## Known Stubs

None.

## Threat Flags

None. T-07-01..04 mitigations are implemented as planned: no e-mail field (walked recursively by the test), all `claude` calls under mktemp config/home with real-config snapshot compare, entries pinned to `name source`, install source is a fresh clone of HEAD with redacted output.

## Self-Check: PASSED

- FOUND: .claude-plugin/plugin.json, .claude-plugin/marketplace.json, .codex-plugin/plugin.json, .agents/plugins/marketplace.json, tests/test-manifests.sh, tests/dist/lib-dist.sh, tests/dist/install-claude.sh
- FOUND commits: 29b5ff7, 81f87ee
