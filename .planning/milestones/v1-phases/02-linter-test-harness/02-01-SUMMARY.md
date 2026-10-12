---
phase: 02-linter-test-harness
plan: 01
subsystem: linter
tags: [python3-stdlib, bash-tests, yaml-subset-parser, lint, dossier-yaml]

# Dependency graph
requires:
  - phase: 01-scaffold-templates
    provides: "skills/dossier-init/scripts/init.py (the producer whose output the linter must read clean), tests/lib.sh + tests/run.sh (the harness extended additively)"
provides:
  - "scripts/lint.py -- root discovery, quotedness-preserving YAML-subset parser + JSON branch, per-field schema (C1/C0), one pruned read-only walk, E6, E7, sorted compiler-shaped report with control-character escaping, exit 0/1/2/3"
  - "tests/lib.sh -- lint_py, assert_lint, assert_finding, assert_no_finding, LINT_OUT/LINT_ERR (additive)"
  - "tests/fixtures/make-lint-fixtures.sh -- runtime fixture generator with make_case / drop_line / replace_line and 10 cases"
  - "tests/test-lint.sh -- 144 assertions, picked up by the untouched tests/run.sh"
affects: [02-02, 02-03, 02-04, 02-05, 02-06]

actuals:
  tokens: 13400
  tasks: 3
  commits: 3
plan_head_before: d95847109d79db28d0ef44aeac3105afdcc06a9f

tech-stack:
  added: []
  patterns:
    - "Scalar(text, quoted, line) plus Seq/Map subclasses carrying the key's line: the parser never types, apply_schema() alone does (D-24)"
    - "Checks share one signature check(root, tree, config, findings) and are listed in the CHECKS tuple in identifier order; later plans append to it"
    - "Every printed line goes through sanitise_path() at exactly one call site, the reporter"
    - "Fixture injections go through drop_line / replace_line, which exit non-zero when the target line is absent, so a fixture can never silently ship without its violation"
    - "Assertions pinned by mutation: each new assertion group was proven to go red on a deliberate break of the behaviour it guards"

key-files:
  created:
    - scripts/lint.py
    - tests/fixtures/make-lint-fixtures.sh
    - tests/test-lint.sh
  modified:
    - tests/lib.sh

key-decisions:
  - "Committing on main despite the executor's protected-branch guard: the dispatch prompt, the plan (branching_strategy none) and the project's whole history put commits on main"
  - "sanitise_path escapes more than 0x00-0x1F/0x7F: also C1 controls 0x80-0x9F, surrogate-escaped bytes from non-UTF-8 filenames (would crash print), and U+2028/U+2029 (Python splitlines treats them as line breaks)"
  - "An invalid JSON dossier.yaml is a C1 error (exit 1), not an unreadable file (exit 2): the dossier exists, its config is broken"
  - "A nonexistent PATH argument exits 2 with its own message instead of walking upward from its parent"
  - "Empty confidential_names entries are dropped silently; a lone scalar where a list is expected is C1 and kept as a name (fail closed)"

patterns-established:
  - "Read-only proof: fresh never-linted scaffold, cp -R snapshot, diff -r, plus a find -newer mtime probe"
  - "Direct module probes from bash: python3 -B with importlib.util.spec_from_file_location on lint_py, used where no end-to-end finding can observe a behaviour yet"

# LINT-01..03 are advanced, not completed, by this plan: 2 of the 8 checks and 1 of 3 fixture
# families exist. REQUIREMENTS.md keeps them Pending until 02-06 closes the phase.
requirements-completed: []
requirements-advanced: [LINT-01, LINT-02, LINT-03]

coverage:
  - id: D1
    description: "A dossier freshly scaffolded by init.py lints to 0 error(s), 0 warning(s), exit 0"
    requirement: LINT-01
    verification:
      - kind: integration
        ref: "tests/test-lint.sh#clean: a fresh scaffold exits 0"
        status: pass
    human_judgment: false
  - id: D2
    description: "E7 fires alone on a living file without Last updated:; E6 fires alone on a sourceless consent"
    requirement: LINT-02
    verification:
      - kind: integration
        ref: "tests/test-lint.sh#e7 / e6 cases"
        status: pass
    human_judgment: false
  - id: D3
    description: "consent_recorded yes / quoted true and staleness_days abc raise C1 naming the field and fail closed (no E6)"
    requirement: LINT-01
    verification:
      - kind: integration
        ref: "tests/test-lint.sh#c1-yes, c1-quoted, c1-staleness"
        status: pass
    human_judgment: false
  - id: D4
    description: "Exit 2 with stderr message outside any dossier; sub-dossier pruned; byte-stable; read-only; forged filename escaped; JSON config parsed under the same name"
    requirement: LINT-03
    verification:
      - kind: integration
        ref: "bash tests/run.sh (TOTAL: 6 files, 0 failed)"
        status: pass
    human_judgment: false

duration: 8min
completed: 2026-09-24
status: complete
---

# Phase 2 Plan 01: Linter Tracer and Test Harness Summary

**`scripts/lint.py` lints a real `init.py` scaffold end to end. It walks up to the nearest `dossier.yaml`, reads it through a quotedness-preserving YAML-subset parser (or JSON under the same filename) and a fail-closed per-field schema, walks the tree once with sub-dossiers pruned, and runs E6 and E7. Findings come out sorted and escaped, followed by `N error(s), M warning(s)`, and the exit code is 0, 1, 2 or 3. A 144-assertion bash test file checks all of this, and each of its assertions was mutation-checked.**

## Performance

- **Duration:** about 8 min wall clock (2026-09-24T19:32Z to 19:40Z)
- **Tasks:** 3 of 3
- **Files:** 3 created, 1 modified

## Accomplishments

- `scripts/lint.py` (847 lines, mode 100755). It imports exactly the eight allowed stdlib modules, and its source is ASCII only. It follows the same house style as `init.py`: `.format()`, a why-comment on every constant, and `main()` returns an int. The parser keeps track of whether a value was quoted, and `apply_schema()` is the only place a field gets a type. `consent_recorded` accepts only an unquoted Core Schema boolean. Anything else raises C1 and is read as False.
- The reporter sorts on (path, line, identifier, message) and passes every line through `sanitise_path()`, its only call site. The summary is always the last line. An unexpected exception exits 3, never 1.
- `tests/lib.sh` gained four helpers and two globals, and no existing line changed. `tests/run.sh` is byte-identical (blob `16afa12...`).
- `tests/fixtures/make-lint-fixtures.sh` builds 10 cases: `e7`, `sub-dossier`, `forged-name`, `json-config`, `c1-yes`, `c1-quoted`, `c1-staleness`, `e6`, `consent-ok` and `c0-junk`. Its header documents the clean layout (D-28 as amended).
- `tests/test-lint.sh` has 144 assertions. `bash tests/run.sh` prints `TOTAL: 6 files, 0 failed`.

## Task Commits

1. **Task 1 (tracer): lint a real dossier end to end.** `22ee1ca` (feat). The tracer gate re-ran the automated verify, it passed, and execution continued.
2. **Task 2: sub-dossier boundary, byte-stable output, read-only proof.** `cb34433` (test)
3. **Task 3: fail-closed configuration gate (C1, C0, E6).** `b5842b7` (test)

## TDD Note

Tasks 2 and 3 are marked `tdd="true"`, but the plan's Task 1 action already required the behaviour they pin (pruning, escaping, sorting, the schema). So their assertions passed on the first run, and there was no honest RED to record. To show the assertions are not vacuous, each group was checked against deliberate mutations of `lint.py`, restored afterwards:

- **Task 2 mutations, each caught:**
  - dropping the sub-dossier prune
  - removing the escaping
  - randomising the sort
  - keeping `.gitkeep`
  - writing a new file
  - rewriting an existing file with identical content
- **Task 3 mutations, each caught:**
  - accepting a quoted boolean
  - accepting `yes`
  - returning True on C1 (fail-open)
  - raising on an unparseable line

The first mutation round exposed two weak tests, which were then fixed (see Deviations 2 and 3).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Security] Wider control-character escaping in `sanitise_path`**
- **Found during:** Task 1
- **Issue:** Escaping only 0x00-0x1F and 0x7F still leaves three problems:
  - U+2028/U+2029 and 0x85 are line breaks to Python's `str.splitlines()`, which a later Python consumer such as `dossier-status` would use.
  - A filename that is not valid UTF-8 comes back from `os.walk` as surrogate escapes, and `print` crashes on those (exit 3).
- **Fix:** also escape 0x80-0x9F and surrogate-escaped bytes as `\xNN`, and U+2028/U+2029 as `\uNNNN`.
- **Files modified:** `scripts/lint.py`
- **Commit:** `22ee1ca`

**2. [Rule 1 - Bug in test] The read-only assertion could not catch an idempotent write**
- **Found during:** Task 2 mutation check
- **Issue:** The snapshot was taken after earlier lint runs. A linter that recreated the same file on every run was therefore already in the snapshot, and the test passed.
- **Fix:** the snapshot is now taken from a fresh scaffold (with a nested dossier) that has never been linted. A `find -newer` mtime probe was added to catch rewrites with identical content.
- **Files modified:** `tests/test-lint.sh`
- **Commit:** `cb34433`

**3. [Rule 1 - Bug in test] The sub-dossier prune could not be observed end to end**
- **Found during:** Task 2 mutation check
- **Issue:** E6 and E7 only look at fixed root-level paths, so removing the prune changed no finding.
- **Fix:** added a direct `walk_tree()` probe. It asserts the parent's own files are present and that nothing under `clients/other/` or `.git/` appears, and it also checks that `.gitkeep` is dropped.
- **Files modified:** `tests/test-lint.sh`
- **Commit:** `cb34433`

**4. [Rule 3 - Blocking] The forged-name end-to-end `\x0a` assertion needs a check that does not exist yet**
- **Found during:** Task 2
- **Issue:** The acceptance criterion `grep -c '\\x0a'` on the `forged-name` run needs a finding that carries an outbound filename. Only E1 and E4 would produce one, and both arrive in plan 02-02.
- **Fix (interim):**
  - The `forged-name` fixture exists, and its crafted name has no extension, so a raw print would produce an exact fake summary line.
  - The end-to-end run asserts exactly one summary-shaped line, and that it is the last line.
  - A direct `report()` probe asserts `\x0a` is printed, the summary is still last, and the output is exactly 2 lines.
- **Handoff:** recorded in `.planning/WINDOWS.md` as a deviation. Plan 02-02 should add the `\x0a` assertion to the `forged-name` run once E4 fires.
- **Files modified:** `tests/test-lint.sh`, `tests/fixtures/make-lint-fixtures.sh`
- **Commit:** `cb34433`

### Judgement Calls Inside Claude's Discretion

- Invalid JSON is C1 (exit 1). A nonexistent PATH exits 2 with its own message.
- `assert_lint` writes stderr to a `mktemp` file rather than `$dossier.stderr`, so no file is written beside the tree under test.
- `test-lint.sh` defines three local helpers: `assert_only`, `assert_out_line` and `assert_last_line`. They stay out of `lib.sh` to keep D-27's additive surface to exactly what the plan listed.

### Process Note

The executor's protected-branch guard flags `main` as protected. The commits still landed on `main`, because the dispatch prompt, the plan (`branching_strategy: none`) and every earlier commit in the project all put them there.

## Known Stubs

None. The CHECKS tuple holds E6 and E7 only by design: E1-E5 and E8/E9, and W1/W2, are later plans' scope and are named in a comment, with no stub functions.

## Threat Flags

None beyond the plan's threat model. T-02-01, T-02-02, T-02-03, T-02-04, T-02-06 and T-02-07 are implemented, and T-02-08 is covered by quoting every expansion in the new bash files. The `vibeflow:allow-large-file` marker on `lint.py` names `.planning/WINDOWS.md`, where plan 02-06 records the window deliberately (Q-6).

## Requirements Status

`requirements.mark-complete` flipped LINT-01..03 to Complete. That was reverted: LINT-01 asks
for all eight checks and LINT-02 for the French and every-error-class fixtures, and this plan
delivers E6/E7 and the harness only. The three requirements stay Pending in REQUIREMENTS.md.

## Next Plan Readiness

- 02-02 appends E1-E5 to `CHECKS`, and `consent_is_recorded(config)` is ready as its suppression predicate. It should add the forged-name `\x0a` end-to-end assertion (WINDOWS.md) and extend `ALL_IDS`-based isolation to its new fixtures.
- The `sub-dossier` fixture already holds a `.claude/` folder and a malformed outbound name, so E1, E4 and E8 will make the D-03 end-to-end assertion meaningful without new fixtures.

## Self-Check: PASSED
