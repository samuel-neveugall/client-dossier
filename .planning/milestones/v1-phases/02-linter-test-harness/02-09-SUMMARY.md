---
phase: 02-linter-test-harness
plan: 09
subsystem: testing
tags: [linter, python-stdlib, html-unescape, unicodedata, e5-haystack]

# Dependency graph
requires:
  - phase: 02-linter-test-harness
    provides: "scripts/lint.py's check_confidential_names / boundary_pattern / folded_text_pattern / fold_ascii (02-01..02-08), tests/fixtures/make-lint-fixtures.sh, tests/test-lint.sh"
provides:
  - "e5_haystacks(): an ordered, line-preserving list of haystack strings E5 searches -- quote-marker stripping (stage 1), an HTML-reference-decoded variant (stage 2), and every string's Unicode-format-character readings (stage 3)"
  - "format_readings(): the deletion reading and the space reading of a string holding Unicode category Cf characters, shared by the haystack side and the needle/path side of E5"
  - "_build_needle(): a configured name -> (display, exact_patterns, filename_pattern, folded_pattern), display-name and de-duplication driven by the space reading (D-GAP-6)"
  - "init.py yaml_quote() maps every category-Cf character to a space before the existing break/control collapse, so dossier.yaml never carries a raw format character"
  - "three new fixture groups (e5-wrapped extended, e5-html-entities, format-name-yaml/format-name-init/format-body) and their assertions"
affects: [linter, dossier-init, confidentiality-gate]

# Actuals (#2632)
actuals:
  tokens: 6870
  tasks: 3
  commits: 3
plan_head_before: 52d1d852040563399c7c90170ea0459d664064ea

tech-stack:
  added: []
  patterns:
    - "e5_haystacks(): a staged, ordered list of line-preserving text variants, each searched by both the exact and the folded pass, replacing the prior two-key {False: norm, True: folded} dict"
    - "format_readings(): a string's Cf-blind readings (deletion, space) shared by the haystack builder, the needle builder and the filename-path builder, so the same two-sided rule (D-GAP-6) covers all three surfaces"

key-files:
  created: []
  modified:
    - scripts/lint.py
    - skills/dossier-init/scripts/init.py
    - tests/fixtures/make-lint-fixtures.sh
    - tests/test-lint.sh

key-decisions:
  - "D-GAP-4 (reversible, applied as written): quote markers are stripped from the E5 haystack in place (the stripped text replaces the base) rather than added as a variant -- the strip removes only leading whitespace and `>` characters that precede a quote, which no name contains, so no match is lost"
  - "D-GAP-5 (reversible, applied as written): HTML references are decoded for every outbound text file, not only .html; the decoded variant is only built when decoding changes something"
  - "D-GAP-6 (reversible, applied as written): a format character is read two ways on every side -- as nothing (deletion) and as a word break (space) -- because either reading alone misses a real case. The finding names the space reading of the configured name. init.py writes the space reading on every quoted field (D-FIX-12 extended)"

patterns-established:
  - "Certain-vs-near-miss precedent (02-07) extended to a third domain: E5's exact pass now carries multiple distinct patterns per needle (one per format reading), deduplicated by compiled-pattern text, mirroring the presence-rule split already used for the confidentiality gate's near-miss check"

requirements-completed: [LINT-01, LINT-02, LINT-03]

coverage:
  - id: D1
    description: "A confidential name hard-wrapped inside a quoted mail reply (single '> ', nested '> > ', or a bare '>' with no space) is ERROR [E5] at the line the name starts on; every earlier E5 case (including header-ok's own quoted header) is unaffected"
    requirement: LINT-01
    verification:
      - kind: unit
        ref: "tests/test-lint.sh: e5-wrapped (extended)"
        status: pass
      - kind: other
        ref: "manual verify command from 02-09-PLAN.md Task 1 (a fresh init.py scaffold, a quoted-reply mail, lint.py reporting E5 at line 6)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Named and numeric HTML character references (amp, eacute, the decimal 39 and 233 references, rsquo) in any outbound text file -- an .html deliverable or a Markdown mail -- never hide a confidential name; each is reported at its own line"
    requirement: LINT-01
    verification:
      - kind: unit
        ref: "tests/test-lint.sh: e5-html-entities"
        status: pass
      - kind: other
        ref: "manual verify command from 02-09-PLAN.md Task 2 (an .html deliverable with the decimal-39 and eacute spellings, lint.py reporting both E5 findings)"
        status: pass
    human_judgment: false
  - id: D3
    description: "A Unicode format character (ZWSP, BOM, soft hyphen, ZWNJ, word joiner) inside a configured name, an outbound body, or a path below outbound/ never hides the name, whether embedded in a word or sitting between two words, or decoded from an HTML reference (&shy;); init.py never writes one raw into dossier.yaml"
    requirement: LINT-01
    verification:
      - kind: unit
        ref: "tests/test-lint.sh: format-name-yaml, format-name-init, format-body"
        status: pass
      - kind: other
        ref: "manual verify commands from 02-09-PLAN.md Task 3 (a hand-written ZWSP-carrying name reporting E5, and an init.py round trip writing no raw ZWSP)"
        status: pass
    human_judgment: false
  - id: D4
    description: "bash tests/run.sh stays green; fresh en/fr scaffolds still lint 0 error(s), 0 warning(s); every earlier E5 count (linebreak-*, e5-slug-*, e5-text-fold*, e5-spacing, e5-boundary, e5-slug-boundary) is unchanged"
    requirement: LINT-02
    verification:
      - kind: integration
        ref: "bash tests/run.sh"
        status: pass
    human_judgment: false

duration: ~6min (commit to commit)
completed: 2026-09-25
status: complete
---

# Phase 02 Plan 09: E5 haystack -- quoted replies, HTML entities, Unicode format characters Summary

**A confidential name wrapped inside a quoted mail reply, spelt with an HTML character reference (`&amp;`, `&#39;`, `&eacute;`), or carrying a Unicode format character (ZWSP, BOM, soft hyphen, ZWNJ, word joiner) anywhere -- the configured name, the body, or a path below `outbound/` -- is now `ERROR [E5]`, at the line the name starts on; `init.py` never writes a raw format character into `dossier.yaml`.**

## Performance

- **Duration:** ~6 min from the first task commit (`856b5bc`, 15:34:44+02:00) to the third (`616e7e7`, 15:40:58+02:00). The base commit (`52d1d85`) predates the session start by an unrecorded margin, same as 02-07's and 02-08's summaries noted.
- **Tasks:** 3/3 completed
- **Files modified:** 4 (`scripts/lint.py`, `skills/dossier-init/scripts/init.py`, `tests/fixtures/make-lint-fixtures.sh`, `tests/test-lint.sh`)

## Accomplishments

- Closed G-02-4f (WR-04 of the iteration-3 review): introduced `e5_haystacks()`, an ordered list of line-preserving haystack strings; stage 1 strips a mail reply's quote markers (`> `, `> > `, a bare `>`) from the start of every line, in place (D-GAP-4). `check_confidential_names()` now runs the exact and folded passes on every string the list returns, keeping one newline index per string and the existing one-finding-per-(line, name) de-duplication across all of them. `e5-wrapped` gained three quoting styles beside its existing plain wrap; every earlier E5 case, including `header-ok`'s own quoted header, is unaffected.
- Closed G-02-4c (CR-03): `e5_haystacks()` stage 2 appends an HTML-reference-decoded variant (built line by line with `html.unescape()`, re-`normalise()`d, a numeric `\n` turned into a space) whenever decoding changes the already quote-stripped text -- applied to every outbound text file, not only `.html`, since `&amp;`-style text also reaches Markdown and pasted mail drafts (D-GAP-5). Added `e5-html-entities`: Johnson &amp; Johnson, AT&amp;T, the `eacute` and decimal-233 spellings of Société Exemple, the decimal-39 and `rsquo` spellings of O'Brien, plus a pasted `&amp;` reference in a mail -- five findings, one per (line, name).
- Closed G-02-4b (CR-02 of the iteration-3 review and D-FIX-12 of its fix round): added `format_readings()` (the deletion reading and the space reading of a string holding Unicode category Cf characters); `e5_haystacks()` stage 3 replaces every string built so far by its readings, in order, duplicates dropped -- so a format character decoded from an HTML reference by stage 2 (`&shy;`) is covered too. `check_confidential_names()`'s needle builder (`_build_needle()`) now carries every distinct exact boundary pattern a name's readings produce, and the display name used in messages and de-duplication is the last (space) reading, collapsed. The filename half now searches every reading of the path below `outbound/` too, at most one finding per (file, name). On the producer side, `init.py`'s `yaml_quote()` maps every category-Cf character to a space before the existing break/control collapse, extending D-FIX-12 to format characters. Added `format-name-yaml` (five hand-written names, one format character each), `format-name-init` (the same five through the `init.py` round trip, asserting no raw character reaches `dossier.yaml`), and `format-body` (eight body lines -- five single-word embeddings, one two-word separator, one boundary already open before the fix, one `&shy;` reference needing stages 2 and 3 together -- plus a name surviving only in a path below E4's scope).
- Reused `E5` for all three gaps (D-05): no new identifier.
- `bash tests/run.sh`: `TOTAL: 6 files, 0 failed`; `bash tests/test-lint.sh`: `PASS 1468 FAIL 0`.

## Task Commits

Each task was committed atomically:

1. **Task 1: End to end -- the E5 haystack list, first stage: a name wrapped in a quoted reply (G-02-4f)** - `856b5bc` (fix)
2. **Task 2: Second stage -- HTML character references never hide a name (G-02-4c)** - `7ca0e42` (fix)
3. **Task 3: Third stage -- Unicode format characters are invisible to E5 on both sides, and init.py never writes one (G-02-4b)** - `616e7e7` (fix)

_No separate plan-metadata commit for STATE.md/ROADMAP.md: per the objective, this worktree-isolated executor does not touch them -- the orchestrator applies those updates after this plan returns. This is a gap-closure execution; the phase itself is never marked complete here._

## Files Created/Modified

- `scripts/lint.py` -- Added `import html`; `_QUOTE_STRIP_RE` (multiline, strips leading `>`-quote markers); `_decode_html_entities()` (line-wise `html.unescape()` + re-`normalise()`, a numeric `\n` turned into a space); `format_readings()` (the deletion/space readings of a Cf-holding string); `e5_haystacks()` (the three-stage ordered haystack list, replacing the old `{False: norm, True: folded}` two-key dict); `_build_needle()` (a configured name -> display name plus every distinct exact pattern its readings produce, plus the filename and folded patterns built from the display name); `check_confidential_names()` rewritten around these -- the text-matching loop now iterates `e5_haystacks(norm)` and, per haystack, every needle's exact patterns then its folded pattern, still one `seen` set of `(line, name)` per file; the filename half now searches every `format_readings()` of the path below `outbound/`, at most one finding per (file, name). Docstrings of all touched functions updated to cite D-GAP-4/5/6, G-02-4f/4c/4b and CR-02/CR-03/WR-04. No other check touched; `GATE_KEY_CUTOFF`, `GATE_KEYS`, the parser and `apply_schema` untouched.
- `skills/dossier-init/scripts/init.py` -- Added `import unicodedata`; `yaml_quote()` now maps every character of Unicode category Cf to a space before `_SCALAR_BREAKS_RE`'s existing collapse-and-trim, so a raw format character never reaches `dossier.yaml`; `_SCALAR_BREAKS_RE`'s neighbouring comment and `yaml_quote()`'s docstring extended to state the new class and why a space, never a deletion (a deletion fuses two words into a needle nothing matches). `emit_scalar()`'s plain-scalar path is unaffected: its allowlist (`_SAFE_PLAIN_SCALAR_RE`) admits no format character.
- `tests/fixtures/make-lint-fixtures.sh` -- Extended `e5-wrapped` with three quoted-reply wraps (single, nested, bare `>`) after its existing plain wrap. Added `e5-html-entities` (four names spelt with named/numeric HTML references across three `.html` paragraphs plus a pasted reference in a mail). Added `format-name-yaml`, `format-name-init` and `format-body` right after `linebreak-yaml`, each behind a banner citing CR-02/D-GAP-6, building every format character from octal bytes with `printf` (ZWSP, BOM, SHY, ZWNJ, WJ) as the `LS`/`PS`/`NEL` precedent already does.
- `tests/test-lint.sh` -- Extended the `e5-wrapped` assertion block with the three new quoted-wrap findings and the updated summary count (`4 error(s)`). Added the `e5-html-entities` assertion block after `e5-spacing`. Added the `format-name-yaml`/`format-name-init`/`format-body` assertion block after `linebreak-yaml`, including the five `grep -c -F` producer assertions on `format-name-init/dossier.yaml` for each raw format character.

## Decisions Made

- **D-GAP-4 (reversible, taken by the plan and applied as written):** quote markers are stripped from the E5 haystack in place, replacing the base text rather than adding a second variant -- the strip removes only leading whitespace and `>` characters that precede a quote, and no configured name legitimately starts with `>`, so no real match is ever lost by this in-place replacement.
- **D-GAP-5 (reversible, applied as written):** HTML references are decoded for every outbound text file, not only `.html` -- `&amp;`-style text also reaches Markdown and mail drafts pasted from a web page -- and the decoded variant is built (and searched) only when decoding actually changes the text, keeping the common case (no `&` at all) to a single haystack.
- **D-GAP-6 (reversible, applied as written):** a format character is read two ways on every side it appears -- deletion (for one sitting inside a single word) and space (for one sitting between two words) -- because either reading alone misses a real case (pinned by `format-body`'s L1-L5 needing deletion and L6 needing space, and `L7` already passing on the *unmodified* linter because a format character is already `\W` for `boundary_pattern()`'s purposes, which a deletion-only fix would have broken). Every E5 message and the `(line, name)` de-duplication key name the space reading of the configured name (e.g. `'Glo bex'` for a name holding an internal soft hyphen), which also keeps bidirectional-control characters out of E5 message text. `init.py` writes that same space reading into `dossier.yaml`, extending D-FIX-12 (which already did this for line breaks) to Unicode format characters.

## Deviations from Plan

None -- all three tasks executed exactly as written. Every fixture, assertion and code change matches the plan's `<action>` text (helper names `e5_haystacks`/`format_readings`/`_build_needle` -- the plan only mandated `e5_haystacks`' name and suggested the other two, both kept as suggested; the haystack-list contract; the needle-building rule; the producer-side `yaml_quote()` change). No new identifier was added (D-05); `check_outbound_headers`, `check_outbound_names`, the confidentiality gate (`_misplaced_gate_keys`), and every check other than `check_confidential_names` are untouched.

One execution-environment note worth recording, consistent with 02-07's and 02-08's summaries: this worktree's `rtk` shell hook refused several compound Bash invocations (`cd ... && git ...`, `cd ... && python3 -c '...'`) as "too complex to verify it stays inside the worktree" -- including some that did not even reference `git` directly but were flagged for shell-text complexity. Per the plan's `<parallel_execution>` guidance, every such command was split into plain, standalone commands (one per Bash tool call), using `/usr/bin/git` directly instead of the `git` shim, and a scratchpad Python script instead of an inline `python3 -c` for the one manual `dossier.yaml` edit in Task 3's verify. No functional impact -- every verification and commit ran successfully once split.

## Baseline RED (before each task's code change)

- **Task 1:** `bash tests/test-lint.sh` against the extended `e5-wrapped` fixture/assertions with `scripts/lint.py` still unmodified: **4 assertions failed** (the three new quoted-wrap findings missing, plus the summary showing `1 error(s)` instead of `4`). After the `scripts/lint.py` change: `PASS 1379 FAIL 0`.
- **Task 2:** `bash tests/test-lint.sh` against the new `e5-html-entities` fixture/assertions, run after Task 1's fix: **8 assertions failed** (exit code, `assert_only E5`, all five findings missing, and the summary showing `0 error(s)` instead of `5`). After the `scripts/lint.py` change: `PASS 1399 FAIL 0`.
- **Task 3:** `bash tests/test-lint.sh` against the three new fixtures/assertions, run after Tasks 1-2's fixes: **28 assertions failed** -- every assertion of `format-name-yaml` (7), `format-name-init` (13), and `format-body` (9, `L1`-`L6` and `L8` plus the path and the summary) except **`L7`'s finding, which was already green on the unmodified linter** -- exactly as the plan's `<acceptance_criteria>` predicted (a format character already counts as `\W` for `boundary_pattern()`'s lookaround, so `Contact<ZWSP>Acme` already matched before any Cf-aware code existed; the plan calls this out as the case a deletion-only fix would have broken). After the `scripts/lint.py`/`init.py` change: `PASS 1468 FAIL 0`.

## Issues Encountered

None beyond the `rtk` shell-hook workaround already documented above under Deviations.

## User Setup Required

None -- no external service configuration required.

## Next Phase Readiness

- G-02-4f, G-02-4c and G-02-4b are closed. Combined with 02-07 (confidentiality-gate near-miss precision, G-02-2/G-02-4d) and 02-08 (case-variant and walk-level fail-closed gaps, G-02-4a/G-02-4e), every gap the 2026-09-25 UAT and the iteration-3 code review recorded for Phase 2 is now closed.
- `scripts/lint.py`'s E5 check now searches an ordered, line-preserving list of haystack variants (quote-stripped, HTML-decoded, format-character-blind) instead of a single normalised string, and its needle builder produces one display name plus every exact pattern its Unicode readings require -- a shape any future E5 extension (e.g. IN-01's rendered-binary text extraction) should build on rather than duplicate.
- `bash tests/run.sh`: `TOTAL: 6 files, 0 failed`.
- The final human recette (Samuel's, per the plan's guardrails) is the only remaining step for this gap-closure mandate; this executor does not mark the phase itself complete.

## Self-Check

- FOUND: `scripts/lint.py`, `skills/dossier-init/scripts/init.py`, `tests/fixtures/make-lint-fixtures.sh`, `tests/test-lint.sh`
- FOUND commits: `856b5bc` (Task 1), `7ca0e42` (Task 2), `616e7e7` (Task 3)
- `git status --short` before this SUMMARY's own commit: only this new file untracked, no other uncommitted changes.

---
*Phase: 02-linter-test-harness*
*Completed: 2026-09-25*
