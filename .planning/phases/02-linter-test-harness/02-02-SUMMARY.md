---
phase: 02-linter-test-harness
plan: 02
subsystem: linter
tags: [python3-stdlib, bash-tests, lint, outbound, confidential-names, consent-gate]

# Dependency graph
requires:
  - phase: 02-linter-test-harness
    plan: 01
    provides: "scripts/lint.py tracer (schema, walk, read_text_safe, normalise, reporter, CHECKS tuple, consent_is_recorded), tests/lib.sh lint helpers, make-lint-fixtures.sh with make_case/replace_line"
provides:
  - "scripts/lint.py -- check_outbound_headers (E1/E2/E3), check_outbound_names (E4), check_confidential_names (E5), boundary_pattern, is_absolute_date, outbound_files, read_status_header, BINARY_EXTS, REQUIRED_FIELDS/MAIL_REQUIRED_FIELDS, _DATE_RE/_FIELD_RE/_OUTBOUND_NAME_RE"
  - "tests/fixtures/make-lint-fixtures.sh -- write_file, make_named_case, GOOD_MAIL, and 24 new cases"
  - "tests/test-lint.sh -- 403 assertions (was 144)"
affects: [02-03, 02-04, 02-05, 02-06]

actuals:
  tokens: 5200
  tasks: 3
  commits: 3
plan_head_before: 08b3ff2faceb2b9fcbb486a35716648a3dd6dc83

tech-stack:
  added: []
  patterns:
    - "The checks keep the 02-01 signature check(root, tree, config, findings) and go into CHECKS in identifier order"
    - "Fixtures that need a confidential name or a consent are built by make_named_case, which runs init.py with the flags, so dossier.yaml keeps the producer's exact bytes"
    - "Every new assertion group was mutation-checked: each deliberate break of the behaviour it guards turns at least one assertion red"

key-files:
  created: []
  modified:
    - scripts/lint.py
    - tests/fixtures/make-lint-fixtures.sh
    - tests/test-lint.sh

key-decisions:
  - "Header lines are anchored: a protocol field counts only when non-alphanumeric characters alone precede it (comment syntax, indentation), so a prose line such as 'We said the Deadline: next week' is not read as a header"
  - "An outbound file outside BINARY_EXTS that cannot be read (symlink, over 5 MB, not UTF-8) is E1 with its own message, never silently skipped"
  - "A required header field with an empty value counts as missing (E1); an empty Status: is E2; an empty Deadline: is E3"
  - "E5 searches the whole path below outbound/ (subfolder names included), not only the basename"
  - "E5 deliberately does not honour EXEMPT_BASENAMES: a leaked name in outbound/README.md is a leak"

patterns-established:
  - "GOOD_MAIL baseline: each outbound case starts from one well-formed header and breaks it in exactly one place"

# LINT-01..03 are advanced, not completed: E8, E9, W1, W2 and the French fixture are still to come (02-04, 02-05).
requirements-completed: []
requirements-advanced: [LINT-01, LINT-02, LINT-03]

coverage:
  - id: D1
    description: "E1, E2, E3 each fire alone; well-formed headers in Markdown, HTML-comment and #-comment syntax, a binary deliverable and the shipped outbound README raise none of them"
    requirement: LINT-01
    verification:
      - kind: integration
        ref: "tests/test-lint.sh#e1, e2, e2-reviewed, e3, e3-baddate, mail-no-subject, calls-no-subject, header-ok, binary-ok"
        status: pass
    human_judgment: false
  - id: D2
    description: "E4 rejects a malformed name and an impossible date; E5 fires on body, filename, NFD and undecodable-binary cases and stays silent on Acmetal/AcmeCorp and on an empty name list"
    requirement: LINT-01
    verification:
      - kind: integration
        ref: "tests/test-lint.sh#e4, e4-baddate, e5, e5-filename, e5-boundary, e5-nfd, e5-binary, e5-nonames"
        status: pass
    human_judgment: false
  - id: D3
    description: "The consent gate: recorded and sourced suppresses E5; malformed gives C1+E5; sourceless gives E6+E5"
    requirement: LINT-02
    verification:
      - kind: integration
        ref: "tests/test-lint.sh#consent-ok-leak, c1-quoted-leak, consent-nosource-leak"
        status: pass
    human_judgment: false
  - id: D4
    description: "The README exemption covers E1-E4 but not E5; the forged-name file is reported with \\x0a end to end"
    requirement: LINT-03
    verification:
      - kind: integration
        ref: "tests/test-lint.sh#e5-readme, e5-readme-nonames, forged-name; bash tests/run.sh TOTAL: 6 files, 0 failed"
        status: pass
    human_judgment: false

duration: 7min
completed: 2026-09-24
status: complete
---

# Phase 2 Plan 02: Outbound Checks E1-E5 Summary

**`scripts/lint.py` now checks outbound files. It reads the status block (E1 missing or incomplete, E2 bad status value, E3 bad `Deadline:`) with a single regex built from `PROTOCOL_FIELDS`, checks the `YYYY-MM-DD_slug.ext` filename against the real calendar (E4), and looks for confidential names (E5) in both the text and the filename. The name match uses an escaped needle between `[^\W_]` lookarounds with NFC applied to both sides. E5 is suppressed only when consent is both recorded and sourced, and the fixtures show the gate stays armed (fails closed) otherwise.**

## Performance

- **Duration:** about 7 min (2026-09-24T19:44Z to 19:51Z)
- **Tasks:** 3 of 3
- **Files:** 3 modified (+562 / -9 lines)

## Accomplishments

- **E1-E3.** Only the first 10 lines are read, and the first occurrence of each field wins. The HTML-comment, `#`-comment and plain Markdown header styles all parse with one regex; there is no parser per format and no label table per language.
  - Required fields are `Status:`, `To:` and `Written by:`. `Subject:` is also required under `outbound/mails/` (A-02).
  - The status value must be `draft`, `reviewed by <name>`, or `sent YYYY-MM-DD [HH:MM[:SS]] by <name>`.
  - `is_absolute_date()` is the one calendar helper, shared by E2, E3 and E4.
- **E4.** It applies only to files directly under `deliverables/`, `mails/` or `calls/`. The name is checked with `fullmatch` (never `$`, which accepts a trailing newline), and the date part goes through the same calendar helper.
- **E5.**
  - `boundary_pattern()` escapes the needle and wraps it in `[^\W_]` lookarounds. The test shows the naive `\w` boundary misses `2026-09-17_acme-offer.md` (mutation: 6 failures).
  - Both halves (text and path) are NFC-normalised.
  - A binary that will not decode skips the text half only.
  - The message names the needle, never the sentence around it.
- **WINDOWS.md item 3 is closed.** `forged-name` now fails E4, and the escaped `\x0a` is asserted end to end (`gsd-tools windows fixed 3`).
- **Tests.** `tests/test-lint.sh` has 403 assertions. `bash tests/run.sh` prints `TOTAL: 6 files, 0 failed`.

## Task Commits

1. **Task 1: E1, E2, E3 (the status block).** `df73a44` (feat)
2. **Task 2: E4, E5 (both halves of the leak check).** `ba3bfcf` (feat)
3. **Task 3: consent gate and README exemption, pinned by fixtures.** `a30f367` (test)

## TDD Gate Compliance

- **Task 1 RED:** 17 failures, all on the new E1-E3 assertions, before any change to `lint.py`. GREEN: 244/0.
- **Task 2 RED:** 22 failures (E4, E5, the `c1-quoted-leak` E5 half, and the `forged-name` exit code), before `lint.py` changed. GREEN: 368/0.
- **Task 3** is not TDD. Its behaviour already existed after Task 2, so it was pinned by mutation instead.

A RED commit separate from its GREEN was not made: the dispatch asked for one commit per task.

Mutations, each applied to `lint.py`, run, then reverted. Every one turned the suite red:

- window 10→100
- no calendar check in `is_absolute_date`
- `Subject:` not required
- first-occurrence-wins dropped
- header regex unanchored (`.*?` prefix)
- naive `\w` boundary
- no boundary at all
- haystack not normalised
- filename half dropped
- case-sensitive match
- E4 without a calendar check
- consent gate ignoring the source
- consent gate removed
- E5 honouring `EXEMPT_BASENAMES`

The first round found two blind spots: first-wins inside the window, and the line-start anchor. Both were closed by adding `outbound/calls/2026-09-21_debrief.md` to `header-ok`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Correctness] An outbound text file that cannot be read now raises E1**
- **Found during:** Task 1
- **Issue:** The plan does not say what happens to an outbound file outside `BINARY_EXTS` that `read_text_safe` refuses (a symlink, a file over 5 MB, non-UTF-8). Skipping it silently would let a draft through with no header check.
- **Fix:** E1 at line 0, with a message saying the file cannot be read.
- **Files modified:** `scripts/lint.py`
- **Commit:** `df73a44`

**2. [Rule 1 - Bug in the pattern] Header regex anchored at the start of the line**
- **Found during:** Task 1
- **Issue:** Research Pattern 4 used `re.search` with `\b`. That reads "Reply To: x" or "the Deadline: next week" in the first 10 lines as header fields, which gives a false E3 or a wrong `To:`.
- **Fix:** `fullmatch` with only `[^A-Za-z0-9]*?` allowed before the field name. Comment syntax still passes. Pinned by the debrief fixture.
- **Files modified:** `scripts/lint.py`, `tests/fixtures/make-lint-fixtures.sh`
- **Commit:** `df73a44`

**3. [Rule 3 - Forward compatibility] `e5-binary` carries a `.md` sibling**
- **Found during:** Task 2
- **Issue:** Without a sibling, the PDF would also fire E9 once plan 02-04 lands, and the isolation assertion would break.
- **Fix:** Added `2026-09-17_acme-scan.md` beside it. Its filename is a second legitimate E5, so the fixture still raises only E5.
- **Commit:** `ba3bfcf`

### Judgement Calls Inside Claude's Discretion

- **Check signature.** It is `check(root, tree, config, findings)`, the convention 02-01 established, not the plan's `(root, files, findings)`.
- **Extra fixtures.** These go beyond the plan's list and exist to satisfy its behaviours and acceptance lines: `e2-reviewed`, `e3-baddate`, `calls-no-subject`, `header-ok`, `binary-ok`, `e5-binary`, `e5-nonames`, `e5-readme-nonames`.
- **`forged-name`.** The interim 02-01 assertion expected exit 0; it now expects 1 (only E4), as the WINDOWS handoff planned.
- **`EXEMPT_BASENAMES` count.** `grep -c` gives exactly 4: the definition, the E1-E3 use site, the E4 use site, and the one-line comment in E5 explaining why E5 does not honour it. The render check (E9) arrives in 02-04 and will be a fifth use site.
- **Commit trailer.** The plan's trailer says `Claude Opus 5 (1M context)`. The orchestrator-supplied trailer was used instead.

## Known Stubs

None. The `CHECKS` tuple now holds E1-E7. E8, E9, W1 and W2 belong to plans 02-04 and 02-05, which a comment names; there are no stub functions for them.

## Threat Flags

None beyond the plan's threat model:

- **T-02-02:** `c1-quoted-leak` and `consent-nosource-leak` both assert two identifiers.
- **T-02-05:** `re.escape` is applied before the boundary wrapper.
- **T-02-03:** the text half is skipped on a symlink, an oversized file or a decode failure; the filename half always runs.
- **T-02-09:** the test asserts the E5 line does not contain the surrounding sentence.

All fixture names are invented placeholders: Jane Doe, Sam, Acme, Société Exemple.

## Requirements Status

LINT-01, LINT-02 and LINT-03 are **advanced, not complete**. E8, E9, W1, W2, the French fixture and the full every-error-class set are still ahead in 02-04 and 02-05, so REQUIREMENTS.md keeps all three as Pending.

## Open Questions for Samuel

- **A-03 slug strictness:** uppercase or `_` in the slug is E4. Keep it, or loosen it after real use?
- **Status spelling:** the time in `sent` accepts only `HH:MM[:SS]`. Status values are case-sensitive, so `Draft` is E2.
- **README scope:** `README.md` is exempt from E1-E3 by basename at any depth under `outbound/`, not only `outbound/README.md`, because that is the semantics of the 02-01 constant. D-06's wording ("at the root of") is narrower.

## Next Plan Readiness

- 02-04 (E8 `.claude/`, E9 render check) can reuse `outbound_files()` and `BINARY_EXTS`, and should add an `EXEMPT_BASENAMES` use site of its own.
- The `sub-dossier` fixture's `outbound/mails/BADNAME.md` now raises E1 and E4 when that dossier is linted directly, and stays invisible from the parent.

## Self-Check: PASSED
