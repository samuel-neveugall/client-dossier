---
phase: 02-linter-test-harness
plan: 08
subsystem: testing
tags: [linter, python-stdlib, os-walk, filesystem, case-insensitive]

# Dependency graph
requires:
  - phase: 02-linter-test-harness
    provides: "scripts/lint.py's walk_tree/Tree/check_outbound_headers (02-01..02-07), tests/fixtures/make-lint-fixtures.sh, tests/test-lint.sh"
provides:
  - "case-variant E1: a folder spelt as a case variant of a fixed LAYOUT_DIRS name, or of an OUTBOUND_SUBS name directly under outbound/, is ERROR [E1] at the folder (casefold equality, never a prefix)"
  - "os.walk onerror collection: Tree.unreadable lists every folder os.scandir could not list; E1 under outbound/, an info line elsewhere"
  - "in-layout .git recording: Tree.git_dirs lists .git folders met inside the fixed layout (still never descended into); E1 under outbound/, an info line elsewhere; a root or out-of-layout .git stays silently pruned"
  - "eight new fixtures (case-outbound, case-outbound-sub, case-knowledge, case-lookalike, unreadable-outbound, unreadable-knowledge, git-outbound, git-knowledge) and their assertions"
  - "LOCKED_DIRS + extended EXIT trap in tests/test-lint.sh: chmod-000 test folders are always restored, even on a failed assertion"
affects: [linter, dossier-init, confidentiality-gate]

# Actuals (#2632)
actuals:
  tokens: 4742
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "case-variant folder check: iterate tree.dirs, split into (parent, name), compare name.casefold() against the fixed name set for that parent (LAYOUT_DIRS at root, OUTBOUND_SUBS under outbound/), never a prefix or substring test"
    - "walk-level fail-closed reporting: os.walk's onerror callback and PRUNED_DIRS' in-layout branch both record a path on a Tree list instead of dropping it, so check_outbound_headers can report E1 the same way it already does for a symlink"

key-files:
  created: []
  modified:
    - scripts/lint.py
    - tests/fixtures/make-lint-fixtures.sh
    - tests/test-lint.sh

key-decisions:
  - "D-GAP-2 (reversible, applied as written): the case-variant rule covers the four top-level LAYOUT_DIRS and the three OUTBOUND_SUBS directly under outbound/, reusing E1 (as D-FIX-11 reused it for symlinks) rather than adding an identifier (D-05). Dossier/ keeps its seven E7 findings on top of the new E1; Knowledge/ and Sources/ would otherwise raise nothing at all. init.py is left unchanged: --propose-renames already proposes the rename, and the linter is now the fail-closed guard while it is pending or declined."
  - "D-GAP-3 (reversible, applied as written): prune .git silently only outside the fixed layout. Inside the layout a .git folder is still never descended into (walking a repository's object store would bury the finding under one E1 per object file), but it is always reported: E1 below outbound/, an info line in sources/, dossier/ or knowledge/."

patterns-established:
  - "Tree gains new lists with empty-tuple defaults on __init__ (unreadable, git_dirs) so a caller constructing a Tree with the old positional signature keeps working -- the same backward-compatible shape pruned/symlinks already used"

requirements-completed: [LINT-01, LINT-02, LINT-03]

coverage:
  - id: D1
    description: "A case variant of a fixed layout folder (Outbound/, outbound/Mails/, Knowledge/) is ERROR [E1] at the folder (casefold equality only, never a prefix); a lookalike folder (outbound-old/, Outbounds/) stays silent"
    requirement: LINT-01
    verification:
      - kind: unit
        ref: "tests/test-lint.sh: case-outbound, case-outbound-sub, case-knowledge, case-lookalike"
        status: pass
    human_judgment: false
  - id: D2
    description: "An unreadable folder or a .git folder under outbound/ is ERROR [E1], never skipped in silence; the same folder elsewhere in the layout is named on an info line, never dropped; the root .git and an out-of-layout .git stay silent"
    requirement: LINT-03
    verification:
      - kind: unit
        ref: "tests/test-lint.sh: unreadable-outbound, unreadable-knowledge, git-outbound, git-knowledge"
        status: pass
    human_judgment: false
  - id: D3
    description: "bash tests/run.sh stays green; no chmod-000 folder is left behind after a test run"
    requirement: LINT-02
    verification:
      - kind: integration
        ref: "bash tests/run.sh; find \"$TMPDIR\" -maxdepth 6 -perm 000 -type d before/after"
        status: pass
    human_judgment: false

duration: ~4min (commit to commit)
completed: 2026-09-25
status: complete
---

# Phase 02 Plan 08: Case-variant and walk-level fail-closed gaps (G-02-4a, G-02-4e) Summary

**A folder spelt as a case variant of `outbound/`/`knowledge/`/`sources/`/`dossier/` (or of `mails/`/`deliverables/`/`calls/` directly under `outbound/`), an unreadable folder, or a `.git` folder inside the fixed layout is now `ERROR [E1]` at the folder under `outbound/` and an info line elsewhere -- none of them can silently escape every outbound check and still exit 0.**

## Performance

- **Duration:** ~4 min from the first task commit (`6f881ac`, 15:18:04+02:00) to the second (`d50c3a2`, 15:21:30+02:00). The base commit (`288c730`, 15:07:57+02:00) predates the session start by an unrecorded margin, same as 02-07's summary noted -- the session-start timestamp was not separately captured.
- **Tasks:** 2/2 completed
- **Files modified:** 3 (`scripts/lint.py`, `tests/fixtures/make-lint-fixtures.sh`, `tests/test-lint.sh`)

## Accomplishments

- Closed G-02-4a (CR-01 of the iteration-3 review): `check_outbound_headers` now loops over `tree.dirs` beside the existing symlink loop. A folder whose name differs from a fixed layout name (`LAYOUT_DIRS` at the root, `OUTBOUND_SUBS` directly under `outbound/`) but is equal to it under `casefold()` is `ERROR [E1]` at the folder, at line 0. A folder that merely starts with a layout name (`outbound-old/`, `Outbounds/`) stays silent -- the rule is exact case-insensitive equality, never a prefix or substring match. Reproduced end to end before this plan: an `Outbound/` folder on this machine (a case-insensitive filesystem) linted `0 error(s), 0 warning(s)`, exit 0, with a leaking mail inside it.
- Closed G-02-4e (WR-03 of the iteration-3 review): `walk_tree` now passes an `onerror` callback to `os.walk`, recording every folder `os.scandir` could not list on the new `Tree.unreadable` list instead of letting `os.walk` drop it without calling any handler. A `.git` folder met inside the fixed layout is recorded on the new `Tree.git_dirs` list instead of being pruned in silence like one outside it -- still never descended into anywhere (a repository's object store would otherwise bury the finding under one `[E1]` per object file), but never hidden either. `check_outbound_headers` reports `ERROR [E1]` for both lists under `outbound/`; `_run` adds an info line for both elsewhere in the layout. The root `.git` and any `.git` outside the fixed layout are unaffected -- they stay silently pruned, exactly as before.
- Reused `E1` for both gaps (as D-FIX-11 reused it for the symlink case): no new identifier, per D-05.
- Extended the fixture generator with eight new cases and `tests/test-lint.sh` with their assertions, plus a `LOCKED_DIRS` variable and an extended (still single) `EXIT` trap so a chmod-000 test folder is always restored, even if an assertion aborts the script before the per-case unlock runs.
- `bash tests/run.sh`: `TOTAL: 6 files, 0 failed`; `bash tests/test-lint.sh`: `PASS 1375 FAIL 0`.

## Task Commits

Each task was committed atomically:

1. **Task 1: End to end -- a case variant of a layout folder fails closed (G-02-4a)** - `6f881ac` (fix)
2. **Task 2: Unreadable folders and .git folders inside the layout are reported, never skipped (G-02-4e)** - `d50c3a2` (fix)

_No separate plan-metadata commit for STATE.md/ROADMAP.md: per the objective, this worktree-isolated executor does not touch them -- the orchestrator applies those updates after this plan returns. This is a gap-closure execution; the phase itself is never marked complete here._

## Files Created/Modified

- `scripts/lint.py` -- `LAYOUT_DIRS`/`PRUNED_DIRS` comments extended with the case-variant and in-layout-`.git` rules (D-GAP-2, D-GAP-3); `Tree` gained `unreadable` and `git_dirs` (empty-tuple defaults, backward-compatible constructor); `walk_tree` now takes an `onerror` callback recording each failing folder's relative path, and its pruning loop records an in-layout `.git` on `git_dirs` instead of dropping it in silence; `check_outbound_headers` gained three loops beside the existing symlink loop -- a case-variant `tree.dirs` scan (`LAYOUT_DIRS` at the root, `OUTBOUND_SUBS` under `outbound/`, iterated in `sorted()` order), `tree.unreadable`, and `tree.git_dirs`, each `ERROR [E1]` under `outbound/`; `_run`'s info-line assembly gained two more list comprehensions for `tree.unreadable`/`tree.git_dirs` outside `outbound/`. No new identifier; `GATE_KEY_CUTOFF`, `GATE_KEYS`, the parser and `apply_schema` untouched.
- `tests/fixtures/make-lint-fixtures.sh` -- Added `case-outbound` (`outbound/` renamed to `Outbound/` in two `mv` steps through a temporary name, holding a headerless mail and a well-formed leak), `case-outbound-sub` (`outbound/mails/` renamed to `outbound/Mails/`, same two-step rename, holding a well-formed leak), `case-knowledge` (`knowledge/` renamed to `Knowledge/`), `case-lookalike` (`outbound-old/` and `Outbounds/`, a control that must stay clean), `unreadable-outbound` and `unreadable-knowledge` (lay out the leak/tree only -- the chmod is `tests/test-lint.sh`'s job, never the generator's), `git-outbound` (`outbound/mails/.git/` holding a leak) and `git-knowledge` (`knowledge/.git/HEAD`).
- `tests/test-lint.sh` -- Added the `LOCKED_DIRS` variable and extended the single `EXIT` trap to unlock every folder in it before its `rm -rf`; added assertions for all eight new fixtures, right after the existing symlink assertions; the two unreadable cases chmod 000 their folder, probe with `ls` for a still-listable result (root, or a permission-less filesystem) and print a `SKIP:` line on stderr in that case instead of asserting, mirroring the existing "no dossier" precedent, and restore the mode right after the lint run either way.

## Decisions for Samuel

- **D-GAP-2 (reversible):** the case-variant rule covers the four top-level `LAYOUT_DIRS` and the three `OUTBOUND_SUBS` directly under `outbound/`, reusing `E1` for all of them rather than adding a new identifier. `Dossier/` keeps its seven `E7` findings on top of the new `E1`; `Knowledge/` and `Sources/` would otherwise raise nothing at all. `init.py` is left unchanged: `--propose-renames` already proposes `Outbound -> outbound`, and the linter is now the fail-closed guard while the rename is pending or declined.
- **D-GAP-3 (reversible):** "prune `.git` only outside the layout" is implemented as *silent* pruning only outside the layout. Inside the layout a `.git` folder is still never descended into, but it is always reported: `E1` below `outbound/` (like a symlink), an `info:` line in `sources/`, `dossier/` or `knowledge/`.

Both decisions were spelled out verbatim in the plan and applied exactly as written; neither was renegotiated during execution.

## Deviations from Plan

None -- plan executed exactly as written. Every fixture, assertion and code change matches the plan's `<action>` text (loop placement, message wording, `Tree`/`walk_tree` signature changes, `LOCKED_DIRS`/trap extension). No new identifier was added (D-05); `check_outbound_names`, the confidentiality gate (`_misplaced_gate_keys`), and every check other than `check_outbound_headers`/`walk_tree`/`_run` are untouched.

One execution-environment note worth recording: this worktree has an `rtk` shell hook that refused several compound/chained `git`+other-command Bash invocations (e.g. `cd ... && git init ...`, `find "${TMPDIR:-/tmp}" ...`) as "too complex to verify it stays inside the worktree." Per the plan's `<parallel_execution>` guidance, every such command was split into plain, standalone commands (or a scratchpad script invoked via `bash`) using `/usr/bin/git` directly instead of the `git` shim. No functional impact -- every verification and commit ran successfully once split.

## Baseline RED (before each task's code change)

- **Task 1:** `bash tests/test-lint.sh` against the new fixtures/assertions with `scripts/lint.py` still unmodified: **7 assertions failed** (`case-outbound` x3: wrong exit code, missing `[E1]` line, wrong summary; `case-outbound-sub` x1: missing `[E1]` line -- its `assert_lint ... 1` already passed at baseline because the leaking mail under the correctly-spelled `outbound/` prefix already fired `[E5]` before any code change; `case-knowledge` x3: same shape as `case-outbound`). `case-lookalike` was green from the start, as the plan predicted (a control). After the `scripts/lint.py` change: `PASS 1363 FAIL 0`.
- **Task 2:** `bash tests/test-lint.sh` against the four new fixtures/assertions, run after Task 1's fix (so Task 1's assertions were already green): **8 assertions failed** (`unreadable-outbound` x3: wrong exit code, missing `[E1]` line, wrong summary; `unreadable-knowledge` x1: missing `info:` line -- `exits 0`/`nothing else fires` already passed at baseline, since a chmod-000 folder was already silently dropped by default `os.walk` behaviour with no handler; `git-outbound` x3: same shape as `unreadable-outbound`; `git-knowledge` x1: same shape as `unreadable-knowledge`). No `SKIP:` line was printed on this machine (not root, chmod 000 took effect both times). After the `scripts/lint.py` change: `PASS 1375 FAIL 0`.

## Issues Encountered

None beyond the `rtk` shell-hook workaround already documented above under Deviations.

## User Setup Required

None -- no external service configuration required.

## Next Phase Readiness

- G-02-4a and G-02-4e are closed. `scripts/lint.py`'s walk-level fail-closed coverage now spans symlinks (02-06/prior), case variants of the fixed layout, unreadable folders, and in-layout `.git` folders -- all reported, none silently pruned, under `outbound/` as `[E1]` and elsewhere as an info line.
- Remaining Phase 2 gaps from the 2026-09-25 UAT not in this plan's scope (`files_modified` was `scripts/lint.py`, `tests/fixtures/make-lint-fixtures.sh`, `tests/test-lint.sh` for these two gaps only): G-02-4b (Unicode format characters), G-02-4c (HTML entities), G-02-4f (quoted-reply wrapping) are addressed by sibling gap-closure plans.
- `bash tests/run.sh`: `TOTAL: 6 files, 0 failed`. No mode-000 folder was found under `$TMPDIR` after the run.

## Self-Check

FOUND: scripts/lint.py, tests/fixtures/make-lint-fixtures.sh, tests/test-lint.sh
FOUND commits: 6f881ac (Task 1), d50c3a2 (Task 2)
`git status --short`: clean before this SUMMARY's own commit.

---
*Phase: 02-linter-test-harness*
*Completed: 2026-09-25*
