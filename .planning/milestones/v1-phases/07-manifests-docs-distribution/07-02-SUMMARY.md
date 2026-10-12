---
phase: 07-manifests-docs-distribution
plan: 02
subsystem: distribution
tags: [release, semver, license, changelog, bash]
requires: []
provides:
  - scripts/release.sh (local release tool, DIST-07)
  - tests/test-release.sh (scratch-repository tests, in tests/run.sh)
  - LICENSE (MIT, Samuel Neveu)
  - CHANGELOG.md (Unreleased only)
affects: [07-01 manifests (consumed at release time), 07-08 changelog command line, 07-09 release rehearsal]
tech-stack:
  added: []
  patterns: ["python3 -I - with values through argv only", "all checks before any write, temp file + os.replace", "scratch repository with an empty bare origin as the no-push proof"]
key-files:
  created: [scripts/release.sh, tests/test-release.sh, LICENSE, CHANGELOG.md]
  modified: []
decisions:
  - "release.sh restores the five files (git reset + checkout by pathspec) if the commit fails, then refuses with 'the commit failed; the five files were restored'"
  - "marketplace files are rewritten only when an entry already carried a version, so an unversioned marketplace stays byte-identical"
metrics:
  duration: ~35 min
  completed: 2026-10-11
status: complete
actuals:
  tokens: 6450
  tasks: 3
  commits: 3
plan_head_before: 00d713a5b08192a37ed8e2c017a78c3c682c9c4d
plan_head_after: 89e8e02
---

# Phase 7 Plan 02: release.sh, LICENSE, CHANGELOG Summary

`scripts/release.sh <version>` takes a clean checkout to a committed, annotated, LOCAL release tag
(both plugin.json files bumped, CHANGELOG heading inserted), refusing every unsafe input without
touching anything, and never contacting a remote; MIT licence and an Unreleased-only changelog added.

## Tasks

| Task | Commit | Files |
|------|--------|-------|
| 1 (tracer) release.sh success path + injection refusals | 5e82081 | scripts/release.sh, tests/test-release.sh |
| 2 every other refusal, marketplace rule, pre-releases | 4662964 | tests/test-release.sh |
| 3 MIT licence and Unreleased changelog | 89e8e02 | LICENSE, CHANGELOG.md |

## Results

- `bash tests/test-release.sh`: `PASS 286 FAIL 0`. `bash tests/run.sh`: exit 0, `TOTAL: 25 files, 0 failed` (run after tasks 2 and 3).
- Tracer gate: success path and five injection strings green before expansion.
- This repository: no tag, no manifest touched (the manifests belong to 07-01), release.sh never run here.

## Case list (all in scratch repositories, run from `.claude-plugin/`)

Static: executable, `#!/usr/bin/env bash`, `set -euo pipefail`, `bash -n`, zero matches of
`git push|fetch|pull|ls-remote|remote`, `curl`, `wget`, `eval`, `[@]`, `=(`, `=~`; two `python3 -I - ` blocks.

Success (each asserts exit 0, empty stderr, versions, a diff of exactly the two version lines per
plugin.json, changelog `## [Unreleased]` + blank + `## [v] - today`, older bullet kept, subject
`chore(release): v<version>`, HEAD touches only the changed files, annotated tag on HEAD, clean tree,
`git ls-remote origin` empty, bare origin without any ref): `1.0.0` from the top; `1.0.0` from a
subfolder; `1.1.0-rc.1`; `1.0.0+build.5`; entry carrying a version (Codex entry follows to 1.0.0,
Claude entry never gains the key, Codex marketplace file in HEAD's changed set); second release
`1.0.1` (headings newest first).

Refused (each asserts exit 1, stderr starts `release: `, HEAD/tags/five file hashes/porcelain status
unchanged, no PWNED file), 27 `refuse` calls:

| Input / state | Message |
|---|---|
| no argument; two arguments | `release: usage: scripts/release.sh <version> (exactly one semantic version, for example 1.0.0)` |
| `''`, `1.0`, `v1.0.0`, `01.0.0`, `1.0.0.0`, `1.0.0-`, `--help` | `release: not a semantic version: <value via printf %q>` |
| `1.0.0; touch PWNED`, `1.0.0$(touch PWNED)`, backticks, `&& touch PWNED`, newline form, `1.0.0$(id)` | same message; newline shown as `$'1.0.0\nx'`, `$(` shown escaped, nothing executed |
| untracked file; modified tracked file (modification kept) | `release: working tree is not clean; commit first` |
| `1.0.0` again after a release; manual `v1.1.0` tag | `release: tag v<version> already exists` |
| Codex manifest at 0.9.0 | `release: the two manifests disagree: 0.1.0 vs 0.9.0` |
| `0.1.0` on a 0.1.0 fixture | `release: already at 0.1.0` |
| a tracked file removed | `release: missing file: .agents/plugins/marketplace.json` |
| changelog without / with two Unreleased headings | `release: CHANGELOG.md must hold exactly one '## [Unreleased]' heading` |
| changelog already holding `## [1.0.0]` | `release: CHANGELOG.md already holds a '## [1.0.0]' heading` |
| pre-commit hook rejecting the commit | `release: the commit failed; the five files were restored` |
| outside any git repository | `release: not inside a git repository` |

Success line: `release: tagged v<version> locally. Nothing was pushed.`

## Deviations from Plan

### Auto-added

**1. [Rule 2 - Missing critical functionality] Rollback when the release commit fails**
- **Found during:** Task 1 (threat T-07-07, partial writes)
- **Issue:** files are written before the commit, so a failing hook would leave a bumped, uncommitted tree.
- **Fix:** `rollback()` (git reset + git checkout of the five paths, safe because the tree was verified clean) and a refusal message; covered by a test with a failing pre-commit hook.
- **Files modified:** scripts/release.sh, tests/test-release.sh (task 1 and 2 commits)

**2. [Rule 3 - Blocking] Two non-plan test details**
- `GIT_CONFIG_GLOBAL=/dev/null` and `GIT_CONFIG_NOSYSTEM=1` exported in the test so the maintainer's git signing or hook settings cannot affect the scratch repositories; the fixture also carries a tracked `notes.txt` (needed for the "modified tracked file" case) and the semver regex uses `re.ASCII` so non-ASCII digits are refused.

### Execution environment

- The worktree base (b8aae7a) pre-dated the phase 7 planning commits; it was fast-forwarded to `feat/phase-07-manifests-docs-distribution` (00d713a) to obtain the plan. Commits therefore sit on the worktree branch `worktree-agent-ac1845053d4d43468`, not on the phase branch itself.
- The tracer acceptance line `git diff --quiet "$C^" "$C" -- .claude-plugin .codex-plugin .agents` holds trivially: none of those paths exist in this branch yet (07-01 owns them).

No auth gates, no stubs, no threat flags beyond the plan's register (T-07-05..08 all mitigated and tested).

## Self-Check: PASSED

- scripts/release.sh (mode 755), tests/test-release.sh, LICENSE, CHANGELOG.md exist.
- Commits 5e82081, 4662964, 89e8e02 are ancestors of HEAD; `git rev-list --count 00d713a..HEAD` = 3 at write time.
