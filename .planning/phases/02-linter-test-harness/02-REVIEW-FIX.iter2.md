---
phase: 02-linter-test-harness
fixed_at: 2026-09-24T21:18:30Z
review_path: /Users/samuel/Documents/dev/client-dossier/.planning/phases/02-linter-test-harness/02-REVIEW.md
iteration: 2
findings_in_scope: 7
fixed: 7
skipped: 0
status: all_fixed
---

# Phase 2: Code Review Fix Report

**Fixed at:** 2026-09-24T21:18:30Z
**Source review:** /Users/samuel/Documents/dev/client-dossier/.planning/phases/02-linter-test-harness/02-REVIEW.md
**Iteration:** 2

**Summary:**
- Findings in scope: 7 (3 critical, 4 warnings). The 11 Info findings are out of scope for `critical_warning`.
- Fixed: 7
- Skipped: 0

**Where the work and verification ran:** in the main checkout, on branch `main`, as instructed. No worktree was created.

**How each fix was tested:**
- The regression fixture and its assertions went in first. `bash tests/test-lint.sh` was run to watch them fail, and only then was the code changed.
- After each commit, `bash tests/run.sh` was green (6 files, 0 failed). The final `tests/test-lint.sh` run has 1290 assertions and 0 failures.
- Fresh `init.py` scaffolds in `en` and `fr` still lint with `0 error(s), 0 warning(s)`.
- Both Python files parse under `ast.parse(..., feature_version=(3, 8))`. Python 3.8 itself is still not installed here (IN-04).
- Targeted mutations were run on the new lines. These were all caught by the suite: the YAML `gate_damaged`, the indicator rejection, the `: ` rejection, the misplaced-key scan, the symlink E1, the Đ entry and the foldable guard.
- One mutation survived at first: dropping the `dj` alternate from the text pass. A follow-up test commit pins it.

**How the commits were made:** with `git commit -F`, as in iteration 1, so each message could end with the two trailer lines. There is one commit per finding, plus one test-only follow-up for WR-03.

## Iteration 1 recap

Iteration 1 fixed 12 findings (3 critical, 9 warnings) in commits `0311379`..`5d45cb4`. Its main changes:
- A gate line that could not be read became C1, and duplicate keys became first-wins (CR-01).
- The parser split lines only on `\n` and `\r`. `init.py` stripped U+2028, U+2029 and U+0085 (CR-02).
- E5 searched for multi-word names across whitespace, and in ASCII-folded slugs (CR-03).
- `''` inside single quotes was read as an escape (WR-01).
- A null or letterless `consent_source` counted as no source (WR-02).
- The fixed-layout folders stopped being sub-dossier boundaries (WR-03).
- The README exemption was limited to `outbound/README.md` (WR-04).
- OS metadata files were exempted from E1-E4 but kept visible to E5 (WR-05).
- stdout gained `backslashreplace`, so an unencodable character no longer crashes the run (WR-06).
- The tests were hardened: a missing bait now fails (WR-07), an ancestor `dossier.yaml` is skipped (WR-08), and every gate parser branch is covered (WR-09).

The iteration-2 review found that CR-01, CR-02 and CR-03 had only closed the reported inputs. Narrower variants were still open. This iteration closes those classes at the structural level.

## Fixed Issues

### CR-01: An indented, unreadable line holding `confidential_names` is still a C0 warning (exit 0)

**Files modified:** `scripts/lint.py`, `tests/fixtures/make-lint-fixtures.sh`, `tests/test-lint.sh`
**Commit:** 5ef26c4
**Status:** fixed: requires human verification (parser severity rule, D-FIX-8)
**Applied fix:** the whole class is closed, not only the reported case.
- **Every line the subset parser skips is now `ERROR [C1]`,** whatever key it seems to sit under. It also keeps E5 armed whatever the consent flag says.
- **The C1 message names the line's own gate key** when it carries one. That is why an indented `confidential_names:` line under `counterparts` is reported as a names line.
- **The only C0 left** is a well-formed repeat of a non-gate top-level key. Its key is exact and its value parses, so its meaning is certain.
- **Fixtures:**
  - `gate-misindent-block` and `gate-misindent-scalar` are the two reproductions.
  - `gate-skip-armed`: a junk line beside a recorded, sourced consent still gives E5.
  - `c1-counterpart-broken`
  - `c0-dup`
  - `c0-junk` is renamed `c1-junk` and now expects C1.

### CR-02: `init.py` fuses the words of a name when it strips a line break or tab

**Files modified:** `skills/dossier-init/scripts/init.py`, `tests/test-init-empty.sh`, `tests/fixtures/make-lint-fixtures.sh`, `tests/test-lint.sh`
**Commit:** d77d52e
**Status:** fixed
**Applied fix:**
- **What `yaml_quote()` does now:** it maps each of these characters to a space, never deletes it:
  - every C0 control (tab and newline included)
  - DEL
  - every C1 control (NEL included)
  - U+2028 and U+2029

  It then collapses runs of whitespace to one space and trims the ends.
- **The Phase 1 injection tests still hold.** A newline is still never written raw. Two expectations changed from the fused spelling to the spaced one: `"Jane injected: pwned"` and `"en injected: pwned"`.
- **New fixture `linebreak-words`:** an `init.py` → `lint.py` round trip on five multi-word names. They are split by U+2028, a tab, a newline, NEL, and a `\t\r\n` run. Each name leaks in a body and in a conforming slug, which gives 10 `[E5]`. The test also asserts the spaced spelling in `dossier.yaml`.

### CR-03: The E5 filename check misses names with letters that NFKD does not decompose

**Files modified:** `scripts/lint.py`, `tests/fixtures/make-lint-fixtures.sh`, `tests/test-lint.sh`
**Commit:** 97e64f9
**Status:** fixed
**Applied fix:**
- `_FOLD_TABLE` transliterates these letters, in both cases, before NFKD: Ł, Ø, Æ, Œ, Đ, Ð, Þ, ı, ß/ẞ, Ħ.
- It applies to the needle and to the path alike.
- Đ has a second customary spelling, `dj`. `filename_pattern()` tries both spellings as alternatives.
- New fixture `e5-slug-translit` has 16 slugs, one per letter and case, including both `djordje-petrovic` and `dorde-petrovic`. Each slug gives one `[E5]`, and the fixture expects exactly 16. Before the fix, 14 of the 16 slugs were missed.

### WR-01: A near-miss gate key, or a shape the subset misreads, still turns E5 off silently

**Files modified:** `scripts/lint.py`, `tests/fixtures/make-lint-fixtures.sh`, `tests/test-lint.sh`
**Commit:** cd45e00
**Status:** fixed: requires human verification (the near-miss threshold is a judgement call, D-FIX-9 and D-FIX-10)
**Applied fix:**
- **Misspelt and misplaced gate keys.** `apply_schema()` now reports C1 for any key that spells a gate key without being it. It keeps E5 armed. This covers two kinds of key:
  - a misspelt top-level key, matched after case-folding and turning `-` and spaces into `_`, or within a `difflib` ratio of 0.8
  - a gate key nested anywhere below the top level, such as `counterparts[].confidential_names`

  Both the YAML and the JSON branch are covered.
- **Plain scalars that are not YAML.** `parse_scalar()` rejects a plain scalar that:
  - starts with a YAML indicator (`- `, `? `, `: `), such as `- - Acme` read as the scalar `- Acme`
  - contains `: `, which usually means two lines were joined
- **Fixtures:** `gate-key-dash`, `gate-key-case`, `gate-key-typo`, `gate-key-space`, `gate-key-consent`, `gate-nested-seq`, `gate-in-counterpart`, `gate-joined`, `gate-json-key-case`, `gate-json-nested`.

### WR-02: A symlinked `outbound/` (or subfolder) is skipped silently

**Files modified:** `scripts/lint.py`, `tests/fixtures/make-lint-fixtures.sh`, `tests/test-lint.sh`
**Commit:** 41462be
**Status:** fixed
**Applied fix:**
- The walk still does not follow directory symlinks (T-02-03). It now records them in `Tree.symlinks`.
- A symlinked folder under `outbound/`, or `outbound/` itself, is `ERROR [E1]` on the folder. That fails closed.
- Anywhere else, a symlinked folder gets an `info:` line.
- **Why not follow the link:**
  - It may point outside the dossier, so the linter would report on files that are not the dossier's, or loop back into it.
  - An error tells the user exactly what to do: make it a real folder.
  - E1 already covers a symlinked file ("cannot be read"), so no new identifier was added (D-05).
- **Fixtures:** `symlink-outbound`, `symlink-outbound-sub`, `symlink-knowledge`.

### WR-03: The E5 text check does not match spellings the filename check does

**Files modified:** `scripts/lint.py`, `tests/fixtures/make-lint-fixtures.sh`, `tests/test-lint.sh`
**Commits:** b83a7e3 (the fix), 0d21d4a (a follow-up test for the `dj` spelling)
**Status:** fixed: requires human verification (matching logic, and it settles D-FIX-3 on the "match more" side)
**Applied fix:**
- **A second text pass.** `folded_text_pattern()` runs on the text as `fold_ascii()` spells it: accents dropped, CR-03 transliteration, both spellings of Đ.
- **What may join the words of a name:** whitespace, `-`, `_`, `'`, `.`, or nothing. A comma or other sentence punctuation never does.
- **A guard for punctuated names.** A name whose punctuation carries meaning (`C++`, `AT&T`) gets no folded pattern, because it would fold to a bare letter.
- **Line numbers stay right.** Folding never adds or removes a `\n`. This was checked over every code point, so the line number is the same on both strings. There is one finding per (line, name) across both passes.
- **Fixtures:**
  - `e5-text-fold`: unaccented, hyphenated, joined, transliterated, apostrophe dropped, and the `dj` spelling. Each sits after lines whose length changes when folded.
  - `e5-text-fold-boundary`: `Big, Telco`, and a lone `c` with `C++` configured. It must stay clean.

### WR-04: The JSON duplicate-consent branch of the fail-closed gate is not pinned by any test

**Files modified:** `tests/fixtures/make-lint-fixtures.sh`, `tests/test-lint.sh`
**Commit:** afeac18
**Status:** fixed (test only)
**Applied fix:**
- New fixture `gate-json-consent-dup`: a JSON config with `consent_recorded` given `true` then `false`, a filled source, and a leak. It asserts exit 1, a `[C1]` naming `consent_recorded`, and the `[E5]`.
- Checked against the review's M18 mutation (removing `gate_damaged = True` from the JSON branch): the `[E5]` assertion fails. It passes on the real code.

## Decisions for Samuel

Each of these is a choice the spec and `02-CONTEXT.md` leave open. I took the option that keeps the confidentiality gate closed, and each one can be reversed in a few lines.

**Carried from iteration 1, updated where this iteration changed them:**

- **D-FIX-1 (CR-01): duplicate keys.**
  - The first occurrence still wins, and the second is reported.
  - The two name lists are still not merged. Names that appear only in a second `confidential_names` are not searched (IN-10), although the run exits 1 with C1.
  - The owning-key attribution this entry described in iteration 1 is superseded by D-FIX-8. It now only chooses the wording of the message.
- **D-FIX-2 (CR-03): filename matching allows an empty separator.** Unchanged. `Big Telco` matches `bigtelco`. A very short multi-token name could collide with an innocent slug. IN-09 (`C++` matching `-c-` in a slug) is still open for filenames.
- **D-FIX-3 (CR-03, WR-03): folding in the text half. Decided on the "match more" side, and you can reverse it.** The text half now also matches the ASCII-folded spelling. False-positive risks you accept with this:
  - A one-word name that is also a common unaccented word: `Élan` configured matches "elan".
  - A dot between the words: `Big. Telco` matches, as does `jane.doe` for `Jane Doe` (arguably a real leak).
  - The empty separator: `Acme Corp` matches `acmecorp`.
  - A name with meaningful punctuation (`C++`) is excluded from the folded pass on purpose.

  To reverse it, return `_NEVER_RE` from `folded_text_pattern()`. To narrow it, drop `.` from `_TEXT_FOLD_SEPARATOR`.
- **D-FIX-4 (WR-02 of iteration 1): what counts as "no source".** Unchanged:
  - Blank, an unquoted null or `~`, or letterless text counts as no source.
  - `TODO` and `n/a` still count as a source.
  - A quoted `"null"` is still a string.
- **D-FIX-5: D-07 wording versus D-10.** Unchanged. E4 keeps D-10's `README.md` exemption in the three subfolders. E1-E3 exempt only `outbound/README.md`.
- **D-FIX-6: a stray `dossier.yaml` inside the fixed layout.** Unchanged. It is not a boundary. Under `outbound/` it gets E1/E4. Elsewhere it is not reported as such.
- **D-FIX-7: OS metadata files stay visible to E5.** Unchanged. AppleDouble `._*` files are still E1/E4 (IN-08).

**New in iteration 2:**

- **D-FIX-8 (CR-01): D-22 narrowed. An unparseable `dossier.yaml` line is an error, no longer a warning.**
  - D-22 (locked) said "unknown or unparseable lines are skipped with a warning". Unparseable lines are now `[C1]`, exit 1, and keep E5 armed.
  - A hand-editing slip anywhere in `dossier.yaml`, `counterparts` included, now fails the run.
  - Unknown well-formed keys are still ignored, as D-22 says (except near-misses, D-FIX-9).
  - C0 is still an identifier. It now covers only a well-formed duplicate of a non-gate key.
  - Fresh scaffolds are unaffected: they produce no skipped line.
  - If you want the warning back for lines clearly under a non-gate key, that is the "certain attribution" rule. Every attempt at it across two iterations left a variant open, which is why I did not keep it.
- **D-FIX-9 (WR-01): near-miss gate keys.**
  - What counts as a near-miss: a key within a `difflib` ratio of 0.8 of a gate key, or equal to one after case-folding and turning `-` and spaces into `_`.
  - Every other spec key scores under 0.5. `consent_note` (0.77) is not caught.
  - A near-miss is reported. Its value is not read as the gate, so names written under `confidential-names` are not searched. The run still exits 1.
  - Reading the misspelt key's names too would also report the leak. That is a small change if you want it.
- **D-FIX-10 (WR-01): stricter plain scalars.**
  - An unquoted value containing `: `, ending in `:`, or starting with `- `, `? ` or `: ` is now a C1. YAML rejects these too.
  - One visible consequence: a hand-written unquoted `consent_source: mail 2026-09-16: Jane` is now a C1 and must be quoted. `init.py` always quotes it.
- **D-FIX-11 (WR-02): a symlinked folder is reported, not followed.**
  - Under `outbound/` it is E1. Elsewhere it gets an info line.
  - A symlinked `dossier/` shows up as seven "living file is missing" E7 errors plus the info line.
  - Following links safely would mean a realpath containment check. I rejected it as the riskier option.
- **D-FIX-12 (CR-02): `yaml_quote()` normalises whitespace in every quoted field,** not only in names. Break and control characters become spaces, runs collapse, and the ends are trimmed. A no-break space becomes a regular space. Two Phase 1 expectations in `tests/test-init-empty.sh` were updated to match. This also closes IN-11 (raw DEL and C1 controls).
- **D-FIX-13 (CR-03): the transliteration table is data.**
  - Đ gets both `d` and `dj`.
  - ð gets only `d` (not `dh`). Þ gets `th`. ı gets `i`.
  - Extending the table is a one-line change and never changes the contract.

## Out of scope (Info, not attempted)

- IN-01 to IN-10 were not attempted.
- IN-11 is closed as a side effect of CR-02: DEL and C1 controls now become spaces.
- IN-09 is still open for filenames. The new folded text pass has its own guard against it.
- IN-10 is still open, as recorded under D-FIX-1.
- IN-04: the suite has still not been run under Python 3.8.
- IN-07: `CLAUDE.md` still does not say that exit 2 also covers argparse usage errors.

---

_Fixed: 2026-09-24T21:18:30Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 2_
