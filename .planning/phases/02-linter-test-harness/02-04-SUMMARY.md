---
phase: 02-linter-test-harness
plan: 04
subsystem: linter
tags: [python3-stdlib, bash-tests, lint, fixtures, isolation-sweep]

# Dependency graph
requires:
  - phase: 02-linter-test-harness
    plan: 02
    provides: "scripts/lint.py with walk_tree/Tree.dirs, EXEMPT_BASENAMES, OUTBOUND_DIR, the check(root, tree, config, findings) signature and E1-E7; make-lint-fixtures.sh with make_case, make_named_case, write_file, GOOD_MAIL; tests/lib.sh assert_lint/assert_finding/assert_no_finding"
provides:
  - "scripts/lint.py -- check_claude_dirs (E8), check_renders (E9), AGENT_DIR, RENDERED_EXTS, RENDER_SOURCE_EXTS; the nine error classes E1-E9 are complete"
  - "tests/fixtures/make-lint-fixtures.sh -- a stated in/out/side/fail contract, a four-way argument guard before anything is created, claim_case (no case built twice), and the cases e8, e9, e9-docx, claude-at-root, e9-source-only, render-html-ok, e9-outside-deliverables"
  - "tests/test-lint.sh -- the SWEEP loop (e1..e9 each fire their identifier, twelve others silent, exact 1/0 summary), assert_clean, the generator-contract assertions with a logging mktemp shim; 497 assertions (was 463 after 02-03)"
affects: [02-05, 02-06]

actuals:
  tokens: 5542
  tasks: 3
  commits: 3
plan_head_before: eb75accd0652f865811002d6bc30a044a761f6e3

tech-stack:
  added: []
  patterns:
    - "E8 reads Tree.dirs from the single walk instead of walking again, so pruning (.git, sub-dossiers) is decided in exactly one place"
    - "The error sweep is one space-separated fixture:identifier list split with parameter expansion (bash 3.2), with per-class location assertions in a case statement inside the loop"
    - "A generator's 'refused before creating anything' property is proven with a logging mktemp shim first on PATH, not with TMPDIR"

key-files:
  created: []
  modified:
    - scripts/lint.py
    - tests/fixtures/make-lint-fixtures.sh
    - tests/test-lint.sh

key-decisions:
  - "E8 and E9 keep the 02-01/02-02 signature check(root, tree, config, findings) instead of the plan's check_claude_dirs(root, dirs, findings) / check_renders(root, files, findings), so CHECKS stays one uniform tuple"
  - "E9 compares both the render and the source extension lowercased; stems are compared exactly; only files directly under outbound/deliverables/ are considered"
  - "The negative sweep uses all thirteen identifiers (C0 included), so each error fixture is checked against twelve others, one more than the plan's eleven"
  - "The generator refuses a case name built twice (claim_case), which turns 'two cases never share a tree' from prose into a failure"

patterns-established:
  - "assert_clean LABEL: a 0/0 summary plus assert_no_finding for every identifier in ALL_IDS"

# LINT-01..03 are advanced, not completed: W1, W2 and the French-content fixture land in 02-05.
requirements-completed: []
requirements-advanced: [LINT-01, LINT-02, LINT-03]

coverage:
  - id: D1
    description: "E8 fires on dossier/.claude and stays silent on <root>/.claude and on a sub-dossier's own .claude from both sides"
    requirement: LINT-01
    verification:
      - kind: integration
        ref: "tests/test-lint.sh#e8 (sweep), claude-at-root, sub-dossier"
        status: pass
    human_judgment: false
  - id: D2
    description: "E9 fires on a lone .pdf or .docx under outbound/deliverables/; a source alone, a .pdf beside .md or .html, and a lone .pdf under mails/ are all clean"
    requirement: LINT-01
    verification:
      - kind: integration
        ref: "tests/test-lint.sh#e9 (sweep), e9-docx, e9-source-only, render-html-ok, binary-ok, e9-outside-deliverables"
        status: pass
    human_judgment: false
  - id: D3
    description: "The fixture generator refuses absent, empty, missing, non-dossier and doubled arguments without ever reaching mktemp, and a successful run prints one line holding e1..e9"
    requirement: LINT-02
    verification:
      - kind: integration
        ref: "tests/test-lint.sh#generator contract"
        status: pass
    human_judgment: false
  - id: D4
    description: "Each of e1..e9 exits 1, fires its own identifier, fires none of the twelve others and summarises exactly 1 error(s), 0 warning(s); the fresh scaffold and consent-ok raise none of the thirteen"
    requirement: LINT-03
    verification:
      - kind: integration
        ref: "tests/test-lint.sh#SWEEP, assert_clean; bash tests/run.sh TOTAL: 6 files, 0 failed"
        status: pass
    human_judgment: false

duration: 6min
completed: 2026-09-24
status: complete
---

# Phase 2 Plan 04: E8, E9 and the Nine-Class Sweep Summary

**`scripts/lint.py` now reports a `.claude/` folder anywhere below the dossier root (E8, read from the walk's own pruned directory list) and a `.pdf`/`.docx` under `outbound/deliverables/` with no same-stem `.md`/`.html` beside it (E9, the reverse deliberately silent). With that, E1-E9 are complete. `tests/test-lint.sh` now sweeps each of the nine error fixtures for the one identifier that must fire and the twelve that must not, with an exact `1 error(s), 0 warning(s)` summary, so a linter that reported one class everywhere cannot pass.**

## Performance

- **Duration:** about 6 min (2026-09-24T19:57Z to 20:03Z)
- **Tasks:** 3 of 3
- **Files:** 3 modified (+282 / -62 lines)

## Accomplishments

- **E8.** `check_claude_dirs` reports every directory named `.claude` whose relative path is not exactly `.claude`, at line 0 with the folder path. It reads `tree.dirs`, so a sub-dossier's own `.claude/` is already pruned from the parent run, and linted directly it is that root's own folder.
- **E9.** `check_renders` gathers the stems with a source (`RENDER_SOURCE_EXTS`) and the renders (`RENDERED_EXTS`) directly under `outbound/deliverables/`, and reports each render whose stem has no source. The docstring says why the reverse direction stays silent.
- **Generator contract.** The header of `make-lint-fixtures.sh` now states in, out, side effects and failure. The guard gives four named refusals (absent, empty, not a directory, no `dossier.yaml`), all before `mktemp -d`. `claim_case` refuses a name built twice. The file keeps exactly one `mktemp -d`, no `trap`, `set -eu`, 37 `# --- ` banners and mode 100755. `make-adopt-fixture.sh` is untouched.
- **Nine-class sweep.** A single `SWEEP='e1:E1 … e9:E9'` loop replaces the per-class blocks. The location assertions (path and line per class) moved into a `case` inside the loop. The variant fixtures (`e2-reviewed`, `e3-baddate`, `e4-baddate`, the E5 family, `e9-docx`) keep their own `assert_only` checks.
- **Clean-side sweeps.** `assert_clean` checks the fresh scaffold and `consent-ok` against all thirteen identifiers and a `0 error(s), 0 warning(s)` summary.
- **Tests.** `tests/test-lint.sh` passes 497 assertions with 0 failures. `bash tests/run.sh` prints `TOTAL: 6 files, 0 failed`.

## Task Commits

1. **Task 1: E8 and E9, the two filesystem-shaped checks.** `918d1c1` (feat)
2. **Task 2: the fixture generator's stated contract.** `b53cb95` (test)
3. **Task 3: the nine-class sweep.** `498c85d` (test)

## TDD Gate Compliance

- **Task 1 RED:** 10 failures, all on the new `e8`/`e9`/`e9-docx` assertions, before `lint.py` changed (453 passing). GREEN: 463/0. As in 02-02, RED and GREEN share one commit, because the dispatch asks for one commit per task.
- **Tasks 2 and 3** are not TDD tasks. They were pinned by mutation instead.

Mutations, each applied, run, then reverted. Every one turned the suite red:

- E8 without the `rel != AGENT_DIR` root exemption: 3 failures (`claude-at-root`, and the sub-dossier linted directly)
- E9 applied to every outbound subfolder: 2 failures (`e9-outside-deliverables`)
- the generator without its `dossier.yaml` guard: 2 failures
- the generator creating its parent before the guard: 6 failures
- `check_living_files` reporting E7 on every file (the plan's mandated check): 73 failures
- E8 relabelled as E1: caught on `e8` (the identifier is missing, `[E1]` is unexpected, and the location check fails)

## Decisions Made

- E8 and E9 keep the phase's uniform `check(root, tree, config, findings)` signature, as the 02-02 note required. The plan text named narrower signatures.
- E9 lowercases both extensions and scopes itself to direct children of `outbound/deliverables/`.
- The negative half of the sweep uses the full `ALL_IDS` list (C0 included): twelve absences per fixture.
- `claim_case` makes a duplicate case name a hard failure of the generator.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] The first "refused run created nothing" assertion was vacuous**
- **Found during:** Task 2 (mutation check)
- **Issue:** The assertion pointed `TMPDIR` at an empty directory and checked that it stayed empty. macOS `/usr/bin/mktemp -d` ignores `TMPDIR` (it uses the per-user `/var/folders` directory), so both mutants (guard removed, parent created before the guard) passed.
- **Fix:** A logging `mktemp` shim goes first on `PATH`. The shim log must stay empty after the five refused runs. A positive control confirms the shim is reached once the guard passes.
- **Files modified:** `tests/test-lint.sh`
- **Commit:** `b53cb95`

**2. [Rule 2 - Missing critical] No enforcement that two cases never share a tree**
- **Found during:** Task 2
- **Issue:** The plan's adjacency truth ("two sibling fixtures never share a tree") held only by convention. A repeated `make_case` or `make_named_case` name would silently merge two injections into one tree.
- **Fix:** `claim_case` in both helpers exits 1 on an existing name.
- **Files modified:** `tests/fixtures/make-lint-fixtures.sh`
- **Commit:** `b53cb95`

### Other deviations

- **Plan wording vs. convention:** the plan says `make_case` is "the only way a case tree comes into existence". `make_named_case` from 02-02 is kept as a second way (a fresh `init.py` scaffold with producer flags), because copying the clean tree cannot give those cases the producer's exact `dossier.yaml` bytes. The header states both helpers, and both are keyed by name and guarded by `claim_case`.
- **Acceptance proxy not met literally:** `grep -c 'assert_finding' tests/test-lint.sh` returns 7, where the plan wanted at least 9. The nine positive assertions run from the single `assert_finding "$want"` line inside the sweep loop. The behaviour the proxy stands for is met and measured: 9 positives plus 108 absences per run, 497 assertions in total, and the plan's own `PASS >= 120` check passes. Unrolling the loop just to raise a line count would undo the structure the plan asked for. `grep -c 'assert_no_finding'` is 13 (it needed at least 9).
- **Extra fixtures beyond the plan:** `e9-docx`, `render-html-ok` and `e9-outside-deliverables`. They cover three `<behavior>` bullets (`.docx`, a source that is `.html`, and scope limited to deliverables) that the plan's four listed cases left unexercised.
- **Commit trailer:** the dispatch's `Co-Authored-By: Claude Opus 5.5` plus `Claude-Session` trailer is used, as in every earlier 02-xx commit. The plan body names a different trailer.

## Known Stubs

None.

## Next Phase Readiness

- 02-05 adds W1 and W2. `ALL_IDS` already lists both, so the sweep and `assert_clean` start asserting W1/W2 behaviour as soon as a check emits them. A W1/W2 check that fires on the clean scaffold or on any e1..e9 fixture will turn the sweep red, which is intended.

## Self-Check: PASSED
