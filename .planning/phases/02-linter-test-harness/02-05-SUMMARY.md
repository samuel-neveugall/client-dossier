---
phase: 02-linter-test-harness
plan: 05
subsystem: linter
tags: [python3-stdlib, bash-tests, lint, fixtures, warnings, french]
status: complete

# Dependency graph
requires:
  - phase: 02-linter-test-harness
    plan: 04
    provides: "scripts/lint.py with E1-E9, C1/C0, LIVING_FILES, normalise (already folding U+2019), boundary_pattern, read_text_safe, walk_tree/Tree, report(findings, infos) and the check(root, tree, config, findings) signature; make-lint-fixtures.sh with make_case/make_named_case/write_file/GOOD_MAIL; tests/lib.sh assert_lint/assert_finding/assert_no_finding"
provides:
  - "scripts/lint.py -- LANGUAGE_WORDS (the only language-aware data), RELATIVE_DATE_DIRS, language_key/language_words/language_infos, check_relative_dates (W1), visible_lines (the HTML-comment depth tracker), check_bullet_sources (W2); CHECKS now nine functions"
  - "tests/fixtures/lint/fr/ -- the one committed lint fixture: an init.py --language fr scaffold plus a documented overlay; exits 0 with 4x[W1] and 3x[W2]"
  - "tests/fixtures/make-lint-fixtures.sh -- make_lang_case NAME LANGUAGE [INIT_ARG...] (make_named_case now delegates to it) and the cases w1-fr, w1-en, w1-boundary, w1-outbound, w1-nolist, w2-fr, w2-en, w2-many"
  - "tests/test-lint.sh -- line_of, assert_no_error, a clean French scaffold asserted 0/0, the W1/W2 assertions and ROADMAP criterion 3 on the committed tree; 675 assertions"
affects: [02-06]

actuals:
  tokens: 11279
  tasks: 3
  commits: 3
plan_head_before: b08eafa9a680edd3edb7686a0080b520b13748e2

tech-stack:
  added: []
  patterns:
    - "Language knowledge is one data block (LANGUAGE_WORDS) read through one accessor (language_words); an unlisted language is reported once by language_infos() in _run, and each warning check simply returns"
    - "W2 evaluates the visible text of a line (HTML comment spans removed by a depth counter carried across lines), so whole-line, multi-line and trailing inline comments are all handled by one mechanism"
    - "Test locations are derived from the fixture with line_of FILE TEXT, never hard-coded, so a template gaining a line cannot shift an assertion silently"

key-files:
  created:
    - tests/fixtures/lint/fr/README.md
    - tests/fixtures/lint/fr/dossier.yaml
    - tests/fixtures/lint/fr/dossier/HISTORY.md
    - tests/fixtures/lint/fr/dossier/CHANNELS.md
    - tests/fixtures/lint/fr/knowledge/CONTEXT.md
    - "tests/fixtures/lint/fr/ (22 tracked files in total)"
  modified:
    - scripts/lint.py
    - tests/fixtures/make-lint-fixtures.sh
    - tests/test-lint.sh
    - .planning/phases/02-linter-test-harness/02-05-PLAN.md

key-decisions:
  - "W1 and W2 keep the uniform check(root, tree, config, findings) signature instead of the plan's (root, files, config, findings) and (root, config, findings), so CHECKS stays one tuple (same call as 02-04 for E8/E9)"
  - "An unlisted language skips BOTH W1 and W2 (the plan's reading of D-20): W2 without the language's opinion markers would flag every legitimate reconstruction"
  - "The language key is config language stripped and lowercased, so `FR` selects the fr lists; `fr-FR` is unlisted and gets the info line"
  - "W1 covers every file under dossier/ and knowledge/ (README and comments included), minus BINARY_EXTS; both clean scaffolds stay at zero because the shipped templates contain no list entry on a word boundary"
  - "D-28 applied as amended: only tests/fixtures/lint/fr/ is committed; a test asserts no tests/fixtures/lint/clean/ is tracked"

patterns-established:
  - "assert_no_error LABEL: none of E1-E9 or C1 fired"
  - "line_of FILE TEXT: fixture-derived line numbers for path-and-line assertions"

# LINT-01..03 are advanced, not completed: plan 02-06 (zero-findings acceptance in both languages, the producer/consumer round trip, the commands and file-size window) still carries all three.
requirements-completed: []
requirements-advanced: [LINT-01, LINT-02, LINT-03]

coverage:
  - id: D1
    description: "W1 fires on relative-date words in dossier/ and knowledge/, as a phrase for multi-word entries and through a U+2019 apostrophe, never inside a longer word, never under outbound/, never as an error"
    requirement: LINT-01
    verification:
      - kind: integration
        ref: "tests/test-lint.sh#w1-fr, w1-en, w1-boundary, w1-outbound, clean-fr"
        status: pass
    human_judgment: false
  - id: D2
    description: "An unlisted language skips W1 and W2 with exactly one info: line, printed first, exit 0"
    requirement: LINT-01
    verification:
      - kind: integration
        ref: "tests/test-lint.sh#w1-nolist"
        status: pass
    human_judgment: false
  - id: D3
    description: "W2 fires on unsourced bullets in exactly the seven living files; a parenthetical source, an opinion marker, a heading and a multi-line comment block are silent; an inflected near-marker is not a marker"
    requirement: LINT-01
    verification:
      - kind: integration
        ref: "tests/test-lint.sh#w2-fr, w2-en"
        status: pass
    human_judgment: false
  - id: D4
    description: "Twenty warnings and no error still exit 0 (D-16, T-02-16)"
    requirement: LINT-01
    verification:
      - kind: integration
        ref: "tests/test-lint.sh#w2-many"
        status: pass
    human_judgment: false
  - id: D5
    description: "ROADMAP criterion 3: the committed French fixture exits 0 with W1 and W2 at asserted paths and lines, no error identifier (E7 included), English Last updated: on all seven living files, >= 20 files tracked"
    requirement: LINT-02
    verification:
      - kind: integration
        ref: "tests/test-lint.sh#fr"
        status: pass
    human_judgment: false
  - id: D6
    description: "Both clean scaffolds (en, fr) print 0 error(s), 0 warning(s)"
    requirement: LINT-03
    verification:
      - kind: integration
        ref: "tests/test-lint.sh#clean, clean-fr"
        status: pass
    human_judgment: false

duration: 6min
completed: 2026-09-24
---

# Phase 2 Plan 05: Prose warnings W1/W2 and the French fixture Summary

**Relative-date (W1) and unsourced-bullet (W2) warnings, driven by one `LANGUAGE_WORDS` block
and word-boundary matching, plus a committed French dossier that exits 0 with both warnings
and no error, which proves the English `Last updated:` label is still found in French content.**

## Performance

- **Duration:** about 6 min
- **Started:** 2026-09-24T20:05:16Z
- **Completed:** 2026-09-24T20:11:19Z
- **Tasks:** 3
- **Files modified:** 25 (22 of them the new fixture tree)

## Accomplishments

- `LANGUAGE_WORDS` holds the D-21 lists, copied from the decision as written: 11 relative-date
  entries and 6 opinion markers for `en`, 12 and 6 for `fr`, with ASCII apostrophes. The block
  is separated from the protocol keywords and its comment forbids a per-language label table.
- W1 (`check_relative_dates`) uses `boundary_pattern`, the same helper as the confidential-name
  check. A clean French scaffold therefore stays at zero warnings even though `hier` appears
  inside `fichier(s)` and `hiérarchie`.
- W2 (`check_bullet_sources`) only reads the seven files in `LIVING_FILES`. `visible_lines()`
  tracks HTML-comment depth across lines, and opinion markers are matched on word boundaries.
- Warnings never change the exit code. Both checks leave a one-line comment at the severity
  assignment explaining why, and a test pins that 20 warnings still exit 0.
- `tests/fixtures/lint/fr/` is committed, and its README records why it is the only committed
  lint fixture. On the fixture itself, `python3 scripts/lint.py tests/fixtures/lint/fr` exits 0
  and prints exactly:

```
dossier/HISTORY.md:12: WARNING [W1] relative-date word 'demain': write the absolute date
dossier/HISTORY.md:12: WARNING [W2] bullet line without a parenthetical source or an opinion marker
dossier/HISTORY.md:13: WARNING [W1] relative-date word 'la semaine prochaine': write the absolute date
dossier/HISTORY.md:15: WARNING [W2] bullet line without a parenthetical source or an opinion marker
dossier/HISTORY.md:16: WARNING [W1] relative-date word 'aujourd'hui': write the absolute date
dossier/HISTORY.md:23: WARNING [W2] bullet line without a parenthetical source or an opinion marker
knowledge/CONTEXT.md:7: WARNING [W1] relative-date word 'récemment': write the absolute date
0 error(s), 7 warning(s)
```

## Task Commits

1. **Task 1: W1, the relative-date word list** - `e445129` (feat)
2. **Task 2: W2, unsourced bullets with the comment tracker** - `f051d8e` (feat)
3. **Task 3: The committed French fixture and ROADMAP criterion 3** - `4b370f1` (test)

**Plan metadata:** see the `docs(02-05)` commit that carries this file.

## TDD Gate Compliance

- **Task 1 RED:** 11 failures before any change to `lint.py`. All were on the new W1
  assertions (w1-fr, w1-en, w1-nolist); nothing that already existed failed. GREEN: 586/0.
- **Task 2 RED:** 9 failures before any W2 code, all on the new W2 assertions. GREEN: 627/0.
- **Task 3** is not TDD. Its one expected failure before `git add` was the tracked-file count
  (0 < 20). After staging: 675/0.
- There are no separate RED commits. This follows the 02-02 precedent of one commit per task,
  with RED measured and recorded here.

## Files Created/Modified

- `scripts/lint.py`: LANGUAGE DATA block, `RELATIVE_DATE_DIRS`, W2 regex constants,
  `language_key`/`language_words`/`language_infos`, `check_relative_dates`, `visible_lines`,
  `check_bullet_sources`. `_run` passes `language_infos(config)` to `report()`.
- `tests/fixtures/make-lint-fixtures.sh`: `make_lang_case`, and eight W1/W2 cases.
- `tests/test-lint.sh`: `line_of`, `assert_no_error`, `CLEAN_FR` (added to the trap), and the
  W1, W2 and criterion-3 sections.
- `tests/fixtures/lint/fr/**`: 22 tracked files. There is no `sources/transcripts/.gitkeep`
  (see its README).
- `02-05-PLAN.md`: the D-28 blockquote now reads "arbitrated, applied" instead of "pending".

## Decisions Made

See `key-decisions` in the frontmatter. The one with a behavioural consequence is that an
unlisted language skips W2 as well as W1, as the plan says.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Check signatures kept uniform**
- **Found during:** Task 1 and Task 2
- **Issue:** The plan names `check_relative_dates(root, files, config, findings)` and
  `check_bullet_sources(root, config, findings)`. The `CHECKS` loop calls every check as
  `check(root, tree, config, findings)`.
- **Fix:** Both use the uniform signature, the same choice 02-04 made for E8/E9.
- **Commits:** `e445129`, `f051d8e`

**2. [Rule 3 - Blocking] `make_lang_case` added to the fixture generator**
- **Found during:** Task 1
- **Issue:** `make_named_case` hard-coded `--language en`, so there was no clean way to build
  French or unlisted-language cases. The file is not in the plan's `files_modified`.
- **Fix:** Added `make_lang_case NAME LANGUAGE [INIT_ARG...]`. `make_named_case` now delegates
  to it, and the header's helper inventory was updated.
- **Commit:** `e445129`

**3. [Rule 2 - Correctness] W2 checks each line's visible text, not only whether the line is
inside a comment**
- **Found during:** Task 2
- **Issue:** Skipping only lines that start inside a comment would miss a sourced bullet with a
  trailing inline comment (`- fact (mail ...). <!-- note -->`) and flag it. It would also
  misjudge text after a mid-line `-->`.
- **Fix:** `visible_lines()` removes comment spans using a depth counter carried across lines.
  The plan's multi-line block behaviour is still met and asserted.
- **Commit:** `f051d8e`

**4. [Rule 1 - Bug, own test] A test locator that could never fail**
- **Found during:** Task 2 RED
- **Issue:** `no_w2_at '(appel @12:34).'` resolved to the template's commented example on
  line 9, not to the appended sourced bullet.
- **Fix:** The locator is now `'rappelle le 2026-10-01 (appel'`.
- **Commit:** `f051d8e`

**5. [Scope] The French fixture carries 7 warnings, not RESEARCH Example 5's 4**
- The overlay adds the U+2019 bait, a sourced bullet before the others, and an unsourced bullet
  after the multi-line comment block (to prove the tracker closes). The committed README lists
  what each line is for. The exact `0 error(s), 7 warning(s)` summary is asserted in addition
  to every path and line.

**6. [Orchestrator directive] D-28 as amended**
- Only `tests/fixtures/lint/fr/` is committed. A test asserts that no `tests/fixtures/lint/clean/`
  is tracked. The plan's "pending arbitration" note was updated to say the arbitration was
  applied, and the reversal path is kept.

**Total deviations:** 4 auto-fixed (2 blocking, 1 correctness, 1 test bug), plus 2 documented
scope notes. **Impact on plan:** none on scope. Every acceptance criterion and every `<verify>`
command in the plan passes.

## Issues Encountered

None.

## Known Stubs

None. `lint.py` contains no placeholder, and the old `LANGUAGE_WORDS lands here` marker was
replaced.

## Threat Flags

None. The only new input surface is dossier prose read by two read-only checks. The warning
messages carry only the matched entry and the location (T-02-17, asserted on `périmètre` and
`livrable`).

## Next Phase Readiness

- Plan 02-06 can build on this: both clean scaffolds already print `0 error(s), 0 warning(s)`
  with all thirteen identifiers silent, and all 13 identifiers now exist.
- `lint.py` is now 1279 lines under its `vibeflow:allow-large-file` marker. Plan 02-06
  Task 3 records that window.

## Self-Check: PASSED

- FOUND: scripts/lint.py, tests/test-lint.sh, tests/fixtures/make-lint-fixtures.sh,
  tests/fixtures/lint/fr/README.md, tests/fixtures/lint/fr/dossier.yaml (22 files tracked)
- FOUND commits: e445129, f051d8e, 4b370f1
- `bash tests/run.sh`: `TOTAL: 6 files, 0 failed`; `tests/test-lint.sh`: `PASS 675 FAIL 0`
