---
phase: 03-protocol-skill-hooks
plan: 01
subsystem: hooks
tags: [claude-code-hooks, pretooluse, python3-stdlib, shlex, bash-tests]

requires:
  - phase: 02-lint
    provides: "scripts/lint.py find_root, copied byte for byte into the hook"
  - phase: 01-scaffold-templates
    provides: "init.py used by the tests to build real dossiers"
provides:
  - "hooks/hooks.json with the PreToolUse matcher group Write|Edit|MultiEdit|NotebookEdit|Bash"
  - "hooks/guard-sources.py: D-03 Write-family deny and D-04 heuristic Bash guard, fail-open"
  - "tests/lib.sh hook helpers (hooks_dir, hook_json, run_hook, hook_field, HOOK_* globals)"
  - "tests/test-hooks-config.sh with REQUIRED_EVENTS, extended by plan 03-04"
affects: [03-04-session-start-and-stop-hooks, 03-05-dossier-skill, 03-06-green-scenario, phase-04-ingest]

actuals:
  tokens: 11700
  tasks: 2
  commits: 2
plan_head_before: ca8f62c4eb90be7c0389b31911eb0bfb7fcc9b1d
plan_head_after: d27a25bec537944a26f42ffb793452f9dfadc9a0

tech-stack:
  added: []
  patterns:
    - "Hook = stdlib Python 3.8 script, fail open (catch-all, exit 0, no output), deny-only decisions"
    - "Hook tests feed stdin JSON built by python3 and assert via hook_field"
    - "find_root duplicated into each hook and pinned by a sed-extracted parity test"

key-files:
  created:
    - hooks/hooks.json
    - hooks/guard-sources.py
    - tests/test-hooks-config.sh
    - tests/test-hook-guard-sources.sh
  modified:
    - tests/lib.sh

key-decisions:
  - "The Bash guard reports command substitution bodies it can see, because shlex tokenizes `$(rm sources/x)` into a subshell; only constructs the tokens hide stay allowed"
  - "`>&` and `<&` consume the next word without treating it as a write target, exactly as the plan states (so `echo x >& sources/f` is allowed)"
  - "No `re` import: the import allowlist stays json, os, sys, shlex, subprocess, pathlib.Path, so flag and assignment detection are hand-written"

patterns-established:
  - "Pattern: expect_deny/expect_silent in the guard test assert exit 0, empty stderr and never `allow` on every case"
  - "Pattern: hooks.json commands are looped over by the config test, so new events only extend REQUIRED_EVENTS"

requirements-completed: [PROTO-05, PROTO-08]

coverage:
  - id: D1
    description: "Every Write, Edit, MultiEdit or NotebookEdit target under the nearest dossier's sources/ (existing or new file; absolute, relative, .., symlink, case variant, nested dossier) is denied with the spec sentence; other paths and non-dossier trees stay silent"
    requirement: PROTO-05
    verification:
      - kind: integration
        ref: "bash tests/test-hook-guard-sources.sh (PASS 325 FAIL 0)"
        status: pass
    human_judgment: false
  - id: D2
    description: "The heuristic Bash guard denies in-place edits, deletes, moves out, overwrites and redirections onto an existing source file, allows new files in, reads and unparseable commands"
    requirement: PROTO-05
    verification:
      - kind: integration
        ref: "bash tests/test-hook-guard-sources.sh (Case 5, 80 assertions groups)"
        status: pass
    human_judgment: false
  - id: D3
    description: "The guard finds the dossier from the target path with a find_root byte-identical to lint.py's; nearest dossier wins"
    requirement: PROTO-08
    verification:
      - kind: unit
        ref: "bash tests/test-hooks-config.sh (find_root parity) and the nested-dossier cases"
        status: pass
    human_judgment: false
  - id: D4
    description: "hooks.json shell form with double-quoted CLAUDE_PLUGIN_ROOT runs end to end through sh -c, also from a plugin root containing a space; claude plugin validate prints no hooks warning"
    requirement: PROTO-05
    verification:
      - kind: integration
        ref: "bash tests/test-hooks-config.sh (PASS 23 FAIL 0, claude present, not skipped)"
        status: pass
    human_judgment: false
  - id: D5
    description: "Hook fails open: malformed stdin, missing fields and internal errors give exit 0, empty stdout and stderr; no allow decision is ever printed"
    requirement: PROTO-05
    verification:
      - kind: integration
        ref: "tests/test-hook-guard-sources.sh check_common on all 325 assertions"
        status: pass
    human_judgment: false

duration: 25min
completed: 2026-10-10
status: complete
---

# Phase 3 Plan 01: Sources guard hook Summary

**PreToolUse guard that denies every write under the nearest dossier's `sources/` (Write family, new files included) plus a shlex-based heuristic for Bash, wired through a shell-form `hooks/hooks.json` and proven by 348 bash assertions**

## Performance

- **Duration:** about 25 min (start time not captured at launch; estimated)
- **Completed:** 2026-10-10T12:55Z
- **Tasks:** 2
- **Files modified:** 5 (4 created, 1 modified)

## Accomplishments

- An `Edit` under a dossier's `sources/` is denied through the real hooks.json command run via `sh -c`, also from a plugin root path containing a space, with the spec sentence `sources are immutable; file a correction in the dossier instead: <root-relative path>`.
- The path rule resolves the target (join to cwd, realpath, root searched from the target, casefolded first component), so `..`, symlinks, `Sources/`, a separate-call cwd under `sources/` and a nested inner dossier are all handled; the nearest dossier wins (PROTO-08).
- The Bash heuristic denies in-place `sed`/`perl`/`ruby`, `rm`/`unlink`/`shred`/`truncate`, `mv` out of or onto an existing source, `cp`/`install`/`rsync` onto an existing source, `>`/`>>`/`tee`/`dd of=` onto an existing file, `git rm`/`git mv`, through `cd`, subshells, newlines and `bash -c`; new files into `sources/` and unparseable commands are allowed.
- `tests/lib.sh` gained `hooks_dir`, `hook_json`, `run_hook`, `hook_field`; `tests/test-hooks-config.sh` loops over declared commands so plan 03-04 only extends `REQUIRED_EVENTS`.

## Test Evidence

RED observed before each implementation step (tests written first, run against an absent or stubbed hook):

| Step | Command | Result before implementation |
|------|---------|------------------------------|
| Task 1, guard test | `bash tests/test-hook-guard-sources.sh` | PASS 43 FAIL 72 (hook script absent) |
| Task 1, config test | `bash tests/test-hooks-config.sh` | PASS 3 FAIL 4 (hooks.json absent) |
| Task 2, Bash cases | `bash tests/test-hook-guard-sources.sh` with `bash_hit` returning None | PASS 245 FAIL 80 (the 115 Task 1 assertions stayed green) |

GREEN after implementation (final run):

| Command | Result |
|---------|--------|
| `bash tests/test-hook-guard-sources.sh` | PASS 325 FAIL 0 |
| `bash tests/test-hooks-config.sh` | PASS 23 FAIL 0 (no SKIP: `claude` on PATH, `claude plugin validate .` exits 0 with no hook line) |
| `bash tests/run.sh` | `TOTAL: 8 files, 0 failed` (was 6 files before this plan) |

Acceptance spot checks: `find_root` block is 14 lines and `diff`-identical to lint.py's; `printf 'not json' | python3 hooks/guard-sources.py` prints nothing and exits 0; the hooks.json matcher and command print exactly as required.

## Task Commits

1. **Task 1: End to end "an Edit under sources/ is denied"** - `26f876d` (feat)
2. **Task 2: Heuristic Bash guard (D-04)** - `d27a25b` (feat)

**Plan metadata:** recorded in the docs commit that carries this SUMMARY, STATE.md and ROADMAP.md.

## Files Created/Modified

- `hooks/hooks.json` - PreToolUse matcher group, shell form, double-quoted `${CLAUDE_PLUGIN_ROOT}`, timeout 10
- `hooks/guard-sources.py` - D-03 Write-family deny, D-04 `bash_hit` heuristic, `find_root` copied from lint.py, fail-open `__main__`
- `tests/lib.sh` - hook helpers and `HOOK_OUT/HOOK_ERR/HOOK_STATUS` globals
- `tests/test-hooks-config.sh` - hooks.json shape, quoting, script existence, 3.8 grammar, import allowlist, 3.9+ API avoid list, no-write check, find_root parity, `sh -c` end to end, plugin validate
- `tests/test-hook-guard-sources.sh` - Write-family and Bash deny/allow cases, nested dossier, fail-open

## Decisions Made

- Command substitution bodies visible to shlex (`$(rm sources/x)`) are scanned like a subshell; this is a cheap extra catch, not a promise. Opaque constructs (variables, interpreters, `xargs`, `find -exec`) stay allowed per D-04.
- Followed the plan on `>&`/`<&` (descriptor duplication, never a write target), accepting that `cmd >& sources/file` slips past a heuristic that is not the boundary.
- The hand-written flag and assignment helpers keep the import allowlist at the plan's list (no `re`).

## Deviations from Plan

None - plan executed exactly as written. (Rule 1-3 fixes: none needed. One self-correction during Task 2 before the first commit: an initial `import re` was removed to honour the plan's import allowlist, so it never reached a commit.)

**Total deviations:** 0
**Impact on plan:** none.

## Issues Encountered

None. Note for reviewers: a quoted lone punctuation word (for example `';'`) is indistinguishable from the operator after `shlex` posix unquoting; the effect is a mis-split segment on a rare command, in the fail-open direction.

## Known Stubs

None. No placeholder values, TODOs or unwired data in the files created.

## Threat Flags

None beyond the plan's threat register. The hook only emits `deny`, never executes or evaluates the command, and fails open (T-03-01 to T-03-04, T-03-06 mitigated as planned; T-03-05 and T-03-07 accepted).

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 03-04 can add the SessionStart and Stop scripts and extend `REQUIRED_EVENTS='PreToolUse'` in `tests/test-hooks-config.sh`; the helpers in `tests/lib.sh` are ready for its hook tests.
- Plan 03-05 (skill) must restate the sources rule and the heuristic nature of the guard (CLAUDE.md: every hook rule also lives in a skill).
- Phase 4 consequence of D-03 stands: `dossier-ingest` must file sources through its script or `cp`, never the Write tool.
- `.planning/ROADMAP.md` and `.planning/STATE.md` are updated by the executor after this SUMMARY, not by plan tasks.

## Self-Check: PASSED

- FOUND: hooks/hooks.json, hooks/guard-sources.py, tests/lib.sh, tests/test-hooks-config.sh, tests/test-hook-guard-sources.sh
- FOUND commits: 26f876d, d27a25b (ancestors of HEAD)

---
*Phase: 03-protocol-skill-hooks*
*Completed: 2026-10-10*
