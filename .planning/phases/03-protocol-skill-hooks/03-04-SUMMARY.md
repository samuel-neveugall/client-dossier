---
phase: 03-protocol-skill-hooks
plan: 04
subsystem: hooks
tags: [claude-code-hooks, sessionstart, stop-hook, block-once, python3-stdlib, git-status, bash-tests]

requires:
  - phase: 03-protocol-skill-hooks
    provides: "03-01: hooks/hooks.json with PreToolUse, tests/lib.sh hook helpers, tests/test-hooks-config.sh with REQUIRED_EVENTS"
  - phase: 02-lint
    provides: "scripts/lint.py find_root, copied byte for byte into both new hooks"
  - phase: 01-scaffold-templates
    provides: "init.py used by the tests to build real dossiers"
provides:
  - "hooks/session-start.py: the PROTO-04 two-line reminder naming the nearest dossier root and client-dossier:dossier, never reading dossier.yaml"
  - "hooks/stop-check.py: the D-01 block-once update-before-handoff check with the D-02 stateless git trigger"
  - "status_sentence() in hooks/stop-check.py: the provisional P-02 behaviour, isolated"
  - "hooks/hooks.json declaring SessionStart (timeout 10), PreToolUse, Stop (timeout 15)"
  - "tests/test-hook-session-start.sh, tests/test-hook-stop.sh, and test-hooks-config.sh with REQUIRED_EVENTS 'PreToolUse SessionStart Stop' and one sh -c end-to-end block per event"
affects: [03-05-dossier-skill, 03-06-green-scenario, phase-06-dossier-status, phase-07-codex-mirror]

actuals:
  tokens: 10500
  tasks: 3
  commits: 3
plan_head_before: 35139d3dbab1ec742b2eb254fbbe7f985aa45bfc
plan_head_after: 663077260c63d50e3df779a4691ed8fb64de0e49

tech-stack:
  added: []
  patterns:
    - "Hook = stdlib Python 3.8 script, fail open (catch-all, exit 0, no output); find_root pinned byte-identical to lint.py's by test-hooks-config.sh"
    - "Stop hook trigger is stateless git status: --no-optional-locks, -z, argument list, -- before the pathspec, show-prefix stripped, R/C entries classified on both sides"
    - "test-hooks-config.sh declared_command EVENT + run_declared COMMAND ROOT JSON: a new event only adds its REQUIRED_EVENTS word and one end-to-end block"

key-files:
  created:
    - hooks/session-start.py
    - hooks/stop-check.py
    - tests/test-hook-session-start.sh
    - tests/test-hook-stop.sh
  modified:
    - hooks/hooks.json
    - tests/test-hooks-config.sh

key-decisions:
  - "P-02 stays provisional: dossier-status is named in the Stop reason only when CLAUDE_PLUGIN_ROOT/skills/dossier-status/SKILL.md is a file; one function and two marked assertions to change if Samuel answers differently"
  - "The Stop hook ignores the session cwd for git scoping and uses the dossier root with pathspec '.', so a sibling dossier in the same repository never triggers it"
  - "An unreadable dossier.yaml still produces the SessionStart reminder, because the hook only tests that the file exists"

patterns-established:
  - "Pattern: expect_block / expect_silent in the Stop test assert exit 0 and empty stderr on every case, and expect_block checks the reason starts with the touched folders"
  - "Pattern: mutation spot-check of a trigger test (prefix not stripped, renames ignored) fails the test, proving the cases bite"

requirements-completed: [PROTO-04, PROTO-06, PROTO-08]

coverage:
  - id: D1
    description: "A dossier.yaml found upward (root, subfolder, nested inner dossier) gives one JSON reminder naming the nearest root and client-dossier:dossier on every session source; no dossier.yaml, malformed stdin or empty stdin give nothing"
    requirement: PROTO-04
    verification:
      - kind: integration
        ref: "bash tests/test-hook-session-start.sh (PASS 135 FAIL 0)"
        status: pass
    human_judgment: false
  - id: D2
    description: "The SessionStart reminder never reads or repeats dossier.yaml: the confidential name Acme never appears and an unreadable dossier.yaml still works"
    requirement: PROTO-04
    verification:
      - kind: integration
        ref: "tests/test-hook-session-start.sh expect_reminder (no-Acme assertion) and Case 7"
        status: pass
    human_judgment: false
  - id: D3
    description: "The Stop check blocks once when outbound/ or sources/ (or both) changed and dossier/ did not; stop_hook_active true is silent; a dossier/ change, knowledge/ alone, renames out of dossier/ are silent"
    requirement: PROTO-06
    verification:
      - kind: integration
        ref: "bash tests/test-hook-stop.sh (PASS 125 FAIL 0), Cases 1-7"
        status: pass
    human_judgment: false
  - id: D4
    description: "The Stop trigger is stateless and silent outside its scope: not a git repository, git missing from PATH, no dossier.yaml, a fresh or wholly untracked dossier, a sibling dossier's changes; a dossier in a repository subfolder is handled through the stripped prefix"
    requirement: PROTO-06
    verification:
      - kind: integration
        ref: "bash tests/test-hook-stop.sh Cases 8-11"
        status: pass
    human_judgment: false
  - id: D5
    description: "Both hooks resolve the root with a find_root byte-identical to lint.py's, so nested dossiers resolve to the nearest; hooks.json declares SessionStart, PreToolUse, Stop in shell form and each command passes sh -c end to end, also from a plugin root containing a space"
    requirement: PROTO-08
    verification:
      - kind: integration
        ref: "bash tests/test-hooks-config.sh (PASS 59 FAIL 0, claude plugin validate with no hook line)"
        status: pass
    human_judgment: false
  - id: D6
    description: "P-02 (provisional): the Stop reason names dossier-status exactly when the skill file exists beside the hook; both states pinned"
    requirement: PROTO-06
    verification:
      - kind: integration
        ref: "tests/test-hook-stop.sh block '# --- P-02 (PROVISIONAL): dossier-status sentence ---'"
        status: pass
    human_judgment: true
    rationale: "The behaviour is Samuel's pending call (03-CONTEXT.md P-02: name always, never, or once the skill exists); tests pin the provisional choice, not its desirability"

duration: 6min
completed: 2026-10-10
status: complete
---

# Phase 3 Plan 04: SessionStart reminder and block-once Stop check Summary

**SessionStart reminder that names the nearest dossier root and the client-dossier:dossier skill without ever opening dossier.yaml, plus a stateless git-status Stop check that blocks the agent once when outbound/ or sources/ changed without dossier/, proven by 260 new bash assertions**

## Performance

- **Duration:** about 6 min (start 2026-10-10T13:07:48Z, end 2026-10-10T13:13Z)
- **Tasks:** 3
- **Files modified:** 6 (4 created, 2 modified)

## Accomplishments

- A session started in a dossier (root, any subfolder, or a nested inner dossier) receives a fixed two-line additionalContext on every `source` value (startup, resume, clear, compact, fork); outside a dossier, or with malformed stdin, the hook prints nothing and exits 0 (PROTO-04).
- The reminder never opens dossier.yaml, so the confidential name configured there cannot reach the model; an unreadable dossier.yaml still yields the reminder (T-03-15).
- The Stop check blocks the agent exactly once: outbound/, sources/ or both changed, dossier/ did not, the reason asks to update the living files or say in one sentence why none needed it; `stop_hook_active` true is silent, so there is no loop (D-01, T-03-16).
- The git trigger is stateless and handles the awkward cases: dossier in a repository subfolder (prefix stripped), sibling dossier, wholly untracked or never committed dossier, renames classified on both sides, not a repository, `git` missing, timeout (D-02, T-03-17 to T-03-20).
- `hooks/hooks.json` now declares SessionStart (10 s), PreToolUse and Stop (15 s); `tests/test-hooks-config.sh` runs each command through `sh -c`, including from a plugin root with a space.
- P-02 (provisional) is isolated in `status_sentence()`: the Stop reason names `dossier-status` only once `skills/dossier-status/SKILL.md` exists beside the hook.

## Test Evidence

RED observed before each implementation step (tests written first, run against the absent hook):

| Step | Command | Result before implementation |
|------|---------|------------------------------|
| Task 1, SessionStart test | `bash tests/test-hook-session-start.sh` | PASS 31 FAIL 104 (hook script absent) |
| Task 2, Stop test | `bash tests/test-hook-stop.sh` | PASS 19 FAIL 98 (hook script absent) |
| Task 3, P-02 block | `bash tests/test-hook-stop.sh` with `status_sentence` not yet written | PASS 124 FAIL 1 (skill-present case fails; skill-absent passes by construction) |

GREEN after implementation (final run on `6630772`):

| Command | Result |
|---------|--------|
| `bash tests/test-hook-session-start.sh` | PASS 135 FAIL 0 |
| `bash tests/test-hook-stop.sh` | PASS 125 FAIL 0 |
| `bash tests/test-hooks-config.sh` | PASS 59 FAIL 0 (no SKIP: `claude` on PATH, `claude plugin validate` prints no hook line) |
| `bash tests/test-hook-guard-sources.sh` | PASS 325 FAIL 0 |
| `bash tests/run.sh` | `TOTAL: 10 files, 0 failed` (was 8 files before 03-01, 9 after Task 1) |

Acceptance spot checks: both new `find_root` blocks are `diff`-identical to lint.py's; hooks.json prints `['PreToolUse', 'SessionStart', 'Stop']` and Stop timeout `15`; `printf '{"hook_event_name":"Stop","cwd":"/","stop_hook_active":false}' | python3 hooks/stop-check.py` and the SessionStart equivalent print nothing, rc=0; `grep -rl dossier-status hooks/` prints only `hooks/stop-check.py`.

Mutation spot-check of the Stop test (not committed): removing the prefix stripping fails 13 assertions; ignoring the rename original-path field fails 2 (rename from `dossier/` to `outbound/`, rename from `outbound/` to `sources/`).

## Task Commits

1. **Task 1: SessionStart reminder (PROTO-04)** - `f422b76` (feat)
2. **Task 2: Block-once Stop check (D-01, D-02)** - `58472a7` (feat)
3. **Task 3: status_sentence(), P-02 provisional** - `6630772` (feat)

**Plan metadata:** recorded in the docs commit that carries this SUMMARY, STATE.md and ROADMAP.md.

## Files Created/Modified

- `hooks/session-start.py` - fixed two-line reminder, find_root from lint.py, fail-open `__main__`
- `hooks/stop-check.py` - `git_output`, `changed_top_dirs`, `status_sentence` (P-02), `block_reason`, block-once `main`
- `hooks/hooks.json` - SessionStart and Stop entries added beside PreToolUse
- `tests/test-hook-session-start.sh` - root, subfolder, nested, silent, malformed, cwd fallback, every source value, unreadable dossier.yaml, no-leak cases
- `tests/test-hook-stop.sh` - block-once, stateless-trigger, prefix, sibling, nested, rename, fresh-scaffold, no-git, git-missing cases and the two P-02 assertions
- `tests/test-hooks-config.sh` - `REQUIRED_EVENTS='PreToolUse SessionStart Stop'`, `declared_command`, `run_declared COMMAND ROOT JSON`, end-to-end blocks for the three events

## Decisions Made

- P-02 remains the provisional option exactly as the plan states; nothing outside `status_sentence()` and its two assertions depends on it. 03-CONTEXT.md "Pending decisions" was not touched.
- The test-only helper `scaffold` runs `mkdir -p` on its target because `init.py` does not create a missing nested target; this also keeps every nested-dossier case honest.

## Deviations from Plan

None - plan executed exactly as written. (One test-authoring correction before the Task 2 commit: the fixture helper initially passed a nonexistent subfolder to `init.py`, so the subfolder and nested cases ran against no inner dossier; `mkdir -p` in the helper fixed it, and the final run is green with the mutation spot-checks above showing the cases bite. No production code was affected.)

**Total deviations:** 0
**Impact on plan:** none.

## Issues Encountered

None. Note: the plan's acceptance wording `grep -c 'no-optional-locks'` counts the docstring and the argument list, so it prints 2 rather than 1; both are intended.

## Known Stubs

None. No placeholder values, TODOs or unwired data in the files created. The absence of `skills/dossier-status/SKILL.md` is the P-02 condition itself, not a stub.

## Threat Flags

None beyond the plan's threat register. T-03-15 (no dossier.yaml read, tested), T-03-16 (`stop_hook_active`, tested), T-03-17 and T-03-18 (`--no-optional-locks`, `--untracked-files=normal`, pathspec, `timeout=10`, argument list, `-z`, `--`), T-03-20 (catch-all, exit 0) are mitigated as planned; T-03-19 is accepted (it only toggles one sentence of the reason).

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 03-05 (the `dossier` skill) must restate the two reminders and the rule behind each hook (CLAUDE.md: every hook rule also lives in a skill): sources immutable, update the living files before handing back, or say why none needed it. Hooks are in place for the 03-06 GREEN run.
- Plan 03-02 stays BLOCKED at its RED baseline gate (0/3); this plan did not touch or unblock it. P-01 and P-02 stay pending with Samuel.
- Phase 6 landing `skills/dossier-status/SKILL.md` makes the Stop reason start naming `dossier-status` with no hook edit (P-02).

## Self-Check: PASSED

- FOUND: hooks/session-start.py, hooks/stop-check.py, hooks/hooks.json, tests/test-hook-session-start.sh, tests/test-hook-stop.sh, tests/test-hooks-config.sh
- FOUND commits: f422b76, 58472a7, 6630772 (ancestors of HEAD)

---
*Phase: 03-protocol-skill-hooks*
*Completed: 2026-10-10*
