---
phase: 02-linter-test-harness
fixed_at: 2026-09-24T20:44:33Z
review_path: /Users/samuel/Documents/dev/client-dossier/.planning/phases/02-linter-test-harness/02-REVIEW.md
iteration: 1
findings_in_scope: 12
fixed: 12
skipped: 0
status: all_fixed
---

# Phase 2: Code Review Fix Report

**Fixed at:** 2026-09-24T20:44:33Z
**Source review:** /Users/samuel/Documents/dev/client-dossier/.planning/phases/02-linter-test-harness/02-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 12 (3 critical, 9 warnings; the 7 Info findings are out of scope for `critical_warning`)
- Fixed: 12
- Skipped: 0

**Where the work and verification ran:** in the main checkout, branch `main`, as instructed. No worktree was created. Each fix was tested first: the new fixture and assertions went in before the code change, `bash tests/test-lint.sh` was run to confirm they failed, and then the code was fixed. Every commit was followed by a full `bash tests/run.sh`, which was green each time (6 files, 0 failed). The final `tests/test-lint.sh` run has 1111 assertions and 0 failures. Both Python files parse under `ast.parse(..., feature_version=(3, 8))` and compile under `-W error` without warnings. Python 3.8 itself is not installed on this machine, so the suite has not been run under 3.8 (see IN-04).

**Commit mechanics:** the commits were made with `git commit -F` rather than `gsd_run query commit`. That was the simplest reliable way to get multi-line bodies ending in the two required trailer lines. Each commit is atomic (one per finding) and lists only the files that finding touched.

## Fixed Issues

### CR-01: An unreadable `confidential_names` line silently disables E5 (fail-open, exit 0)

**Files modified:** `scripts/lint.py`, `tests/fixtures/make-lint-fixtures.sh`, `tests/test-lint.sh`
**Commit:** 0311379
**Status:** fixed: requires human verification (parser logic; the owning-key rule below is a design choice)
**Applied fix:**
- `parse_yaml_subset` now records `(line, owning key, reason)` for each skipped line. The owning key is kept even when its own line fails to parse. Indented lines and column-0 lines without a key belong to the key above them. A quoted key and a gate key with a missing colon also count.
- A skipped line that belongs to `confidential_names`, `consent_recorded` or `consent_source` is now `ERROR [C1]`. Other skipped lines stay `WARNING [C0]`.
- A duplicate top-level key is skipped and the first occurrence wins. This applies to the YAML branch and to the JSON branch (through `object_pairs_hook`). On a gate key it is C1.
- If any gate line is damaged, E5 stays armed whatever the consent flag says (`consent_is_recorded` returns False).
- Column-0 block sequences directly under their key are now read.
- Fixtures: `gate-col0`, `gate-multiline`, `gate-escape`, `gate-typo`, `gate-quoted-key`, `gate-nocolon`, `gate-indent`, `gate-dup`, `gate-consent-dup`, `gate-consent-dup-rev`, `gate-source-broken`, `gate-json-dup`. Every one of them exited 0 or lacked C1 before the fix.

### CR-02: A name `init.py` writes can make `lint.py` drop every confidential name (U+2028/U+2029/U+0085)

**Files modified:** `scripts/lint.py`, `skills/dossier-init/scripts/init.py`, `tests/fixtures/make-lint-fixtures.sh`, `tests/test-lint.sh`
**Commit:** a003ddb
**Status:** fixed
**Applied fix:**
- `lint.py`: the new `yaml_lines()` splits only on `\r\n`, `\r` and `\n`, which is YAML 1.2 behaviour.
- `init.py`: `yaml_quote()` also strips U+0085, U+2028 and U+2029.
- Fixtures:
  - `linebreak-name` is an `init.py` → `lint.py` round trip that leaks `Beta`. It checks that none of the three characters reach `dossier.yaml`, and that the run exits 1 with `[E5]` only.
  - `linebreak-yaml` is a hand-written names line containing U+2028 and U+0085. It exits 1 with `[E5]` only.

### CR-03: E5 misses every multi-word name in a conforming filename, and most whitespace variants in text

**Files modified:** `scripts/lint.py`, `tests/fixtures/make-lint-fixtures.sh`, `tests/test-lint.sh`
**Commit:** 7589825
**Status:** fixed: requires human verification (matching logic; see decisions D-FIX-2 and D-FIX-3)
**Applied fix:**
- `boundary_pattern` joins the needle's tokens with `\s+`. W1 and W2 use it too, so they now also accept runs of whitespace between the words of an entry.
- The E5 text half searches the whole normalised file. It reports the line where the match starts, once per (line, name).
- The new `filename_pattern` matches the name's ASCII-folded alphanumeric tokens, joined by any run of non-alphanumeric characters (possibly empty), against the ASCII-folded path.
- The `[^\W_]` boundary is unchanged on both halves.
- Fixtures: `e5-slug`, `e5-slug-joined`, `e5-slug-accent`, `e5-wrapped` and `e5-spacing` (three variants, three findings) all exit 1. `e5-slug-boundary` (`bigtelcom`, `Bigger Telco`, `Big Telcom`) exits 0.

### WR-01: `''` inside a single-quoted scalar is mis-tokenised

**Files modified:** `scripts/lint.py`, `tests/fixtures/make-lint-fixtures.sh`, `tests/test-lint.sh`
**Commit:** 8ed3e95
**Status:** fixed
**Applied fix:**
- `strip_comment` and `_split_flow` keep a single quote open across `''` and copy both characters.
- Fixtures:
  - `gate-sq-names` (`[ 'O''Brien, Jr', Acme ]`) exits 1 with `[E5]` only.
  - `gate-sq-source` (a sourced consent written `'...it''s # ok'`) is clean.

### WR-02: `consent_source: null` / `~` / placeholder text suppresses E5 and E6

**Files modified:** `scripts/lint.py`, `tests/fixtures/make-lint-fixtures.sh`, `tests/test-lint.sh`
**Commit:** f895e78
**Status:** fixed: requires human verification (see decision D-FIX-4)
**Applied fix:**
- The new `source_is_empty()` treats the source as empty when it is absent, blank, an unquoted YAML null (`null`/`Null`/`NULL`/`~`), or text with no letter and no digit. `consent_is_recorded()` and E6 both read it.
- The value is still stored as the verbatim string (D-24.2).
- Fixtures: `source-null`, `source-tilde` and `source-punct` (`"-"`) each exit 1 with `[E6]` and `[E5]`.

### WR-03: A stray `dossier.yaml` anywhere under `outbound/` turns off every outbound check for that subtree

**Files modified:** `scripts/lint.py`, `tests/fixtures/make-lint-fixtures.sh`, `tests/test-lint.sh`
**Commit:** 0a2a290
**Status:** fixed
**Applied fix:**
- `sources/`, `dossier/`, `outbound/`, `knowledge/` and everything below them are never treated as D-03 boundaries (`LAYOUT_DIRS`).
- Under `outbound/`, a stray `dossier.yaml` is checked like any other outbound file, so it gets `[E1]`, plus `[E4]` in a subfolder.
- Each pruned real sub-dossier is now named on an `info:` line.
- Fixtures:
  - `stray-config` exits 1 and the leak's `[E5]` still fires.
  - `stray-config-knowledge`: W1 still fires in `knowledge/`.
  - `sub-dossier` now asserts the info line.

### WR-04: The `README.md` exemption applies at any depth under `outbound/`

**Files modified:** `scripts/lint.py`, `tests/fixtures/make-lint-fixtures.sh`, `tests/test-lint.sh`
**Commit:** 15f85cf
**Status:** fixed (partially adapted, see decision D-FIX-5)
**Applied fix:**
- E1-E3 now exempt the path `outbound/README.md` only (`EXEMPT_PATHS`).
- E4 keeps D-10's explicit exemption for `README.md` in the three subfolders. D-10 is a locked decision, so it was not removed as the review suggested.
- E9 still never counts a README as a render's source.
- Fixture `readme-nested` exits 1 with `[E1]` on `outbound/mails/README.md` and no `[E4]`.

### WR-05: Finder's `.DS_Store` (and other OS dotfiles) under `outbound/` produce two errors

**Files modified:** `scripts/lint.py`, `tests/fixtures/make-lint-fixtures.sh`, `tests/test-lint.sh`
**Commit:** db4f33a
**Status:** fixed
**Applied fix:**
- `OS_METADATA_NAMES` (`.DS_Store`, `Thumbs.db`, `desktop.ini`) are exempt from E1-E4.
- They deliberately stay in the walk, so E5 still reads them. This fails closed, unlike the review's suggestion to drop them.
- Fixtures:
  - `os-junk` (all three files) is clean.
  - `os-junk-leak` (a name inside `desktop.ini`) exits 1 with `[E5]` only.

### WR-06: Printing a non-ASCII finding to a non-UTF-8 stdout crashes the run (exit 3)

**Files modified:** `scripts/lint.py`, `tests/fixtures/make-lint-fixtures.sh`, `tests/test-lint.sh`
**Commit:** 454bb54
**Status:** fixed
**Applied fix:**
- `main()` reconfigures stdout and stderr with `errors="backslashreplace"` before any output. This needs Python 3.7+; a stream without `reconfigure` is left alone.
- Fixture `enc-leak`, run under `PYTHONIOENCODING=latin-1`, exits 1 (not 3). The `[E5]` line is printed with `Ł` escaped, and stderr is empty.

### WR-07: Negative location assertions pass vacuously when the bait line is missing

**Files modified:** `tests/test-lint.sh`, `tests/fixtures/make-lint-fixtures.sh`
**Commit:** 7dd3a56
**Status:** fixed
**Applied fix:**
- `fr_none` and `no_w2_at` record a FAIL when the bait is not found.
- The `## Chronologie` check could never fail, because a heading line cannot start with a bullet marker. It is replaced with a bullet-shaped heading (`## - Une rubrique en forme de puce`) added to `w2-fr` and asserted silent.
- Checked on a scratch copy: removing a bait from either helper's call now fails the suite.

### WR-08: The "no dossier → exit 2" test depends on the machine's directory tree

**Files modified:** `tests/test-lint.sh`
**Commit:** 5c53beb
**Status:** fixed
**Applied fix:**
- The test first walks the scratch folder's ancestors. If one holds a `dossier.yaml`, the case prints a `SKIP:` line naming it and asserts nothing.
- Checked in isolation: with a `dossier.yaml` above the scratch folder, the case skips and records no failure.

### WR-09: The suite has no fixture for any fail-open path of the gate

**Files modified:** `tests/fixtures/make-lint-fixtures.sh`, `tests/test-lint.sh`
**Commit:** 5d45cb4
**Status:** fixed
**Applied fix:**
- Most of the shapes the finding lists already landed as regression fixtures with CR-01, CR-02, WR-01 and WR-02 (`gate-*`, `linebreak-*`, `source-*`).
- This commit adds the remaining branches:
  - `gate-block`: an indented block sequence of plain and quoted names.
  - `gate-json-armed`.
  - `gate-json-quoted`: a JSON `"true"` string gives `[C1]` and `[E5]`, nothing else.
  - `gate-json-nullsource`: gives `[E6]` and `[E5]`.
  - `gate-json-ok`: clean.
- These pass because the underlying fixes are already in place. They are coverage, not a new behaviour change.

## Decisions for Samuel

Each point below is a choice the spec and `02-CONTEXT.md` do not settle. I took the more conservative option for the confidentiality gate, and each one is reversible in a few lines.

- **D-FIX-1 (CR-01): which key an unreadable line belongs to, and duplicate keys.**
  - A skipped line counts as a gate line in four cases: its own (loosely matched) key is a gate key; it starts with a gate key name even without a colon; it is an indented continuation of a gate key; or it is a column-0 line with no key of its own that directly follows a gate key.
  - Any of these is C1 and keeps E5 armed.
  - For duplicates, the first occurrence wins and the second is reported. The union of the two name lists is not taken, so names that only appear in the second occurrence are not searched. The run still exits 1 with C1, so this never fails silently.
  - A YAML escape the subset does not support (`\x..`, `\u....`) is C1 on a gate line. The subset was not widened to accept it.
- **D-FIX-2 (CR-03): filename matching allows an empty separator.** `Big Telco` matches `bigtelco` as well as `big-telco`, and `O'Brien` matches `obrien`. The boundary still refuses `bigtelcom`. The cost is that a very short multi-token name could collide with an innocent slug.
- **D-FIX-3 (CR-03): filenames are ASCII-folded, text is not.**
  - E4 only accepts an ASCII slug, so filename matching folds accents: `Société Exemple` matches `societe-exemple`.
  - The text half still matches only the NFC spelling. A body that writes the name without its accents (`Societe Exemple`) is not caught. Whether the text half should fold as well is open.
- **D-FIX-4 (WR-02): what counts as "no source".**
  - Implemented: blank, an unquoted `null`/`Null`/`NULL`/`~`, and text with no letter and no digit (`-`, `?`, `...`).
  - Not implemented:
    - placeholder words such as `TODO`, `TBD` or `n/a`. Recognising them means guessing at natural language, which D-16 puts on the warning side.
    - a quoted `"null"`, which is a string under D-24.2.
  - If you want placeholder words to be E6 errors, that is a word list to add.
- **D-FIX-5 (WR-04): D-07 wording versus D-10.**
  - The review asked to drop `README.md` from the E4 and E9 exemptions. D-10 (locked) explicitly exempts `README.md` from E4 in the three subfolders, so E4 keeps that exemption.
  - E1-E3 now follow D-06: only the root `outbound/README.md` is exempt. This reads D-07's "except `README.md`" as meaning that root README.
  - If D-10's E4 exemption should also go, it is a one-line change in `check_outbound_names`.
- **D-FIX-6 (WR-03): what happens to a stray `dossier.yaml` inside the fixed layout.**
  - The four fixed folders are never sub-dossier boundaries, which narrows D-03.
  - Under `outbound/`, the stray file is reported through the existing E1/E4 rather than a new identifier. No new ID was added to the assertion surface (D-05).
  - A stray `dossier.yaml` in `sources/`, `dossier/` or `knowledge/` is walked through, but it is not reported as such.
- **D-FIX-7 (WR-05): OS metadata files stay visible to E5.** The review suggested dropping them from the walk. I kept them in the walk and exempted them only from E1-E4, so a name written into one is still caught.

## Out of scope (Info, not attempted)

IN-01 to IN-07 were not in scope for `critical_warning`. Two of them intersect this run:
- **IN-04:** the suite has still never been run under Python 3.8 (`uv python find 3.8` finds nothing on this machine).
- **IN-07:** `CLAUDE.md` still does not say that exit 2 also covers argparse usage errors.

---

_Fixed: 2026-09-24T20:44:33Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
