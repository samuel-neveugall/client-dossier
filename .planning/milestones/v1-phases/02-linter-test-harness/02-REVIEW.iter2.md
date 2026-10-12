---
phase: 02-linter-test-harness
reviewed: 2026-09-24T21:30:00Z
depth: standard
iteration: 2
files_reviewed: 4
files_reviewed_list:
  - scripts/lint.py
  - skills/dossier-init/scripts/init.py
  - tests/test-lint.sh
  - tests/fixtures/make-lint-fixtures.sh
findings:
  critical: 3
  warning: 4
  info: 11
  total: 18
status: issues_found
---

# Phase 2: Code Review Report (iteration 2)

**Reviewed:** 2026-09-24T21:30:00Z
**Depth:** standard
**Files Reviewed:** 4
**Status:** issues_found

## Summary

This pass re-reviewed the fix diff `de59969..HEAD` (13 commits) against the four source files. `bash tests/run.sh` is green (6 files, 0 failed).

**Were the iteration-1 findings closed?** Each original scenario was rebuilt on a scratch dossier:

| Iter-1 | Original scenario reproduced | Result now | Verdict |
|---|---|---|---|
| CR-01 | col-0 block, multi-line flow, `\u` escape, value typo, quoted key, indent drift, duplicate key | col-0 is read (E5); every other case is C1 and exits 1 | **Partly closed.** An unreadable gate line that is *indented* still falls back to C0 and exit 0 (new CR-01) |
| CR-02 | `init.py --confidential-name $'Acme Corp' --confidential-name Beta`, Beta leaked | E5 on Beta, exit 1 | **Partly closed.** The line is no longer lost, but the name comes out fused (`AcmeCorp`), so "Acme Corp" leaks with exit 0 (new CR-02) |
| CR-03 | `Jane Doe` / `big-telco` slug, wrapped, double space, NBSP, tab | all fire | **Partly closed.** Names with letters NFKD cannot decompose (Ł, Ø, Æ, Œ, Đ) are still missed in slugs (new CR-03) |
| WR-01 | `[ 'O''Brien, Jr', Acme ]`, `'it''s # ok'` | read correctly | Closed |
| WR-02 | `consent_source: null` / `~` / `"-"` | E6 + E5 | Closed (`TODO` still counts as a source by decision D-FIX-4) |
| WR-03 | empty `outbound/mails/dossier.yaml` | subtree walked, E1 on the stray file, E5 fires | Closed |
| WR-04 | headerless `outbound/mails/README.md` | E1 | Closed |
| WR-05 | `.DS_Store` / `Thumbs.db` / `desktop.ini` | clean, still read by E5 | Closed (AppleDouble `._*` files remain, IN-08) |
| WR-06 | `PYTHONIOENCODING=latin-1`, name `Łukasz` | exit 1, `Ł` escaped | Closed |
| WR-07 | missing bait in `fr_none` / `no_w2_at` | FAIL recorded | Closed |
| WR-08 | ancestor `dossier.yaml` | SKIP line | Closed |
| WR-09 | block, JSON-armed/quoted/null-source | covered | Closed. One branch is still unpinned (WR-04 below) |

**Would the new tests fail without the fixes?** Yes, with one exception. I ran the current `tests/test-lint.sh` against `lint.py` and `init.py` from `de59969`: 32 of the new cases fail, and the only ones that pass are the WR-09 coverage cases, which the fixer labelled as coverage. Then I applied 19 targeted mutations to the fix lines, one at a time, and re-ran the suite. 18 were caught. One survived: the JSON-branch `gate_damaged = True` (WR-04).

**New findings.** The owning-key rule added for CR-01 attributes an unreadable indented line to the enclosing top-level key, even when that line carries `confidential_names` itself. That keeps the CR-01 fail-open alive for a common hand-editing mistake. The producer-side CR-02 fix deletes the separator instead of replacing it, which turns a lost line into a silently wrong name. The CR-03 ASCII folding misses a class of common European letters. All three exit 0 while a confidential name sits in `outbound/`.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: An indented, unreadable line holding `confidential_names` is still a C0 warning (exit 0)

**File:** `scripts/lint.py:531-533` (owner only updated at top level), `scripts/lint.py:582-584` (skip recorded with `owner`), `scripts/lint.py:827-838`
**Issue:** `owner` is recomputed only for top-level lines. A skipped *indented* line is charged to the enclosing top-level key, whatever key the line carries itself. When a user appends the names line after a `counterparts` block and indents it by mistake, the line lands under `counterparts`. It is reported as `WARNING [C0]`, `confidential_names` is absent, E5 is off, and the run exits 0. These are the same conditions iteration-1 CR-01 was raised for. Reproduced on scratch dossiers, each with a mail containing "Acme":

```
counterparts:
  - name: Jane
    role: CFO
  confidential_names: [ Acme ]     -> WARNING [C0] ... 0 error(s), 1 warning(s), exit 0

status_header: required
  confidential_names: [ Acme ]     -> WARNING [C0] ... 0 error(s), 1 warning(s), exit 0
```

A conforming YAML parser rejects both files. The subset's own contract in `load_config` ("a line that carries a gate key ... can never be a mere warning") is broken, and no fixture has an indented gate key.
**Fix:** When a line is skipped, also check the line's *own* key and record it if it is a gate key:

```python
except ValueError as exc:
    if skipped is not None:
        own = _LOOSE_KEY_RE.match(body) or _GATE_KEY_START_RE.match(body)
        key = own.group(1) if own is not None and own.group(1) in GATE_KEYS else owner
        skipped.append((number, key, str(exc)))
```

Add fixtures `gate-misindent-block` (the counterparts shape above) and `gate-misindent-scalar`. Each should assert exit 1, `[C1]` naming `confidential_names`, and no `[C0]`.

### CR-02: `init.py` fuses the words of a name when it strips a line break or tab, so E5 misses it

**File:** `skills/dossier-init/scripts/init.py:195`; test gap at `tests/test-lint.sh:400-401` and `tests/fixtures/make-lint-fixtures.sh:598-603`
**Issue:** `yaml_quote` *deletes* U+2028/U+2029/U+0085 and every C0 control, tab and newline included. For a name, those characters separate words, so `Acme<U+2028>Corp`, `Acme<TAB>Corp` and `Acme<LF>Corp` are all written as `confidential_names: [ "AcmeCorp" ]`. The single-token needle `AcmeCorp` matches neither the text `Acme Corp` nor the conforming slug `acme-corp`. Reproduced for all three separators: a mail saying "We met Acme Corp today." plus a file `2026-09-17_acme-corp.md` gives `0 error(s), 0 warning(s)`, exit 0. The CR-02 fix turned "every name on the line is dropped" into "this name is silently rewritten". The input is the one the iteration-1 review called realistic: a Word manual line break, or a tab from a spreadsheet cell. The `linebreak-name` fixture includes `Acme${LS}Corp` but only ever asserts on `Beta`, so this goes unnoticed.
**Fix:** Replace line breaks and controls with a space, collapse the whitespace, and trim:

```python
_NAME_BREAKS_RE = re.compile("[\x00-\x1f\x85  ]+")

def yaml_quote(value):
    cleaned = " ".join(_NAME_BREAKS_RE.sub(" ", value).split())
    cleaned = cleaned.replace("\\", "\\\\").replace('"', '\\"')
    return '"' + cleaned + '"'
```

(`.split()` also folds runs of other Unicode whitespace; if byte-exact output of the other fields matters, apply the collapse to names only.) In `linebreak-name`, leak `Acme Corp` in the body and add a `2026-09-17_acme-corp.md` file. Assert two `[E5]` lines for `Acme Corp`, not only the `Beta` one.

### CR-03: The E5 filename check misses names with letters that NFKD does not decompose (Ł, Ø, Æ, Œ, Đ, Þ, ı)

**File:** `scripts/lint.py:1133-1140` (`fold_ascii`), `scripts/lint.py:1143-1156`, `scripts/lint.py:1179`
**Issue:** `fold_ascii` relies on NFKD to strip diacritics. It works for `é`, but `Ł`, `Ø`, `Æ`, `Œ`, `Đ`, `Þ` and `ı` have no canonical or compatibility decomposition, so the needle stays non-ASCII (`łukasz`). E4 accepts only an ASCII slug, so the only conforming filename (`lukasz-nowak`) never matches. Reproduced: `Łukasz Nowak`/`lukasz-nowak`, `Øresund Bank`/`oresund-bank`, `Æther Labs`/`aether-labs`, `Œuvre SA`/`oeuvre-sa` and `Đorđe Petrović`/`djordje-petrovic` all exit 0 with the name in the filename. (`Société Exemple` and `Straße AG` are caught.) This is the gap iteration-1 CR-03 was about ("the filename half can never match a name in a file that passes E4"), still open for Polish, Nordic, Croatian/Serbian and French-ligature names. The fix report states "filenames are ASCII-folded", but these letters are not.
**Fix:** Transliterate the non-decomposable letters before NFKD, on both the needle and the path (both go through `fold_ascii`):

```python
_FOLD_EXTRA = str.maketrans({"ł": "l", "Ł": "l", "ø": "o", "Ø": "o", "æ": "ae", "Æ": "ae",
                             "œ": "oe", "Œ": "oe", "đ": "d", "Đ": "d", "ð": "d", "Ð": "d",
                             "þ": "th", "Þ": "th", "ı": "i"})

def fold_ascii(text):
    decomposed = unicodedata.normalize("NFKD", text.translate(_FOLD_EXTRA))
    return "".join(ch for ch in decomposed if not unicodedata.combining(ch)).casefold()
```

(`Đ` is also transliterated `dj`. Emitting both spellings as alternatives in `filename_pattern` covers both.) Add `e5-slug-stroke` (`Łukasz Nowak` / `2026-09-17_lukasz-nowak-offer.md`) asserting `[E5]`.

## Warnings

### WR-01: A near-miss gate key, or a shape the subset misreads, still turns E5 off silently

**File:** `scripts/lint.py:402-414` (`parse_scalar`), `scripts/lint.py:558-567`, `scripts/lint.py:721-748` (unknown keys ignored)
**Issue:** Each of these exits 0 with a leak of "Acme" and prints nothing. All were reproduced:
- `confidential-names: [ Acme ]` and `Confidential_names: [ Acme ]`: plausible typos. They parse as unknown keys, which D-22 ignores.
- `confidential_names:` / `  - - Acme`: the subset reads the plain scalar `- Acme` (YAML reads a nested list). The needle then needs a literal `- Acme` and never matches.
- `confidential_names: [ Acme ]` indented to a counterpart item's column: this is read as `counterparts[0].confidential_names`. YAML reads it the same way, but the top-level key is missing and nothing says so.

The CR-01 fix already treats a quoted key and a missing colon as the gate key. A misspelt or misplaced key belongs in that same group, and here nothing is reported at all.
**Fix:**
1. In `apply_schema`, report C1 for any key whose normalised form (`key.casefold().replace("-", "_")`) is in `GATE_KEYS` but is not written exactly.
2. Report C1 when a `counterparts` entry carries a gate key.
3. In `parse_scalar`, reject a plain scalar that starts with a YAML indicator followed by a space or end of text (`- `, `? `, `: `, `-`).

### WR-02: A symlinked `outbound/` (or subfolder) is skipped silently, so E1-E5 never run on it

**File:** `scripts/lint.py:897` (`os.walk` with `followlinks=False`), `scripts/lint.py:881-918`
**Issue:** T-02-03 is right not to follow directory symlinks, but nothing reports the skipped directory. Reproduced: `outbound/` replaced by a symlink to a folder holding a headerless mail that names Acme gives `0 error(s), 0 warning(s)`, exit 0. A symlinked outbound folder (on a synced drive or a shared deliverables folder) is plausible. It hides the whole folder from every outbound check, which is the WR-03 failure through another route. A symlinked *file* is handled loudly (E1 "cannot be read"). A symlinked directory is not.
**Fix:** In `walk_tree`, collect each entry in `dirnames` for which `os.path.islink(os.path.join(dirpath, name))` is true. Under `outbound/` (or for `outbound` itself at the root), report `ERROR [E1] directory is a symlink, its files are not checked`. Elsewhere, print an `info:` line as for pruned sub-dossiers.

### WR-03: The E5 text check does not match spellings the filename check does

**File:** `scripts/lint.py:1111-1130` (`boundary_pattern`), `scripts/lint.py:1187-1191`
**Issue:** After CR-03, the filename half folds accents and accepts `-`, `_` or no separator between tokens. The text half accepts only whitespace, and only the NFC spelling. Reproduced: `Société Exemple` configured, "We met Societe Exemple." exits 0. `Big Telco` configured, "We met Big-Telco." exits 0. A body typed on a keyboard without accents, or a company name hyphenated in prose, is common. The fix report records the accent part as open decision D-FIX-3. The hyphen part is not mentioned there.
**Fix:** Run the text check twice: the current pattern on the NFC text, and `filename_pattern(name)` on `fold_ascii(norm)`. Take line numbers from the folded text. Both passes preserve `\n`, but NFKD can change the length of a line, so compute `newlines` on the string that was searched. Alternatively, have Samuel settle D-FIX-3 and record the gap in the skill prose.

### WR-04: The JSON duplicate-consent branch of the fail-closed gate is not pinned by any test

**File:** `scripts/lint.py:815-819`; `tests/fixtures/make-lint-fixtures.sh:502-512`; `tests/test-lint.sh:386-391`
**Issue:** Deleting `gate_damaged = True` from the JSON branch leaves the whole suite green (mutation M18; the other 18 targeted mutations were caught). `gate-json-dup` duplicates `confidential_names`, which affects the names list, not consent suppression. The case that needs `gate_damaged` is a JSON config with `"consent_recorded": true, "consent_recorded": false` and a filled source. Without the flag, first-wins reads `true` and E5 is suppressed (still exit 1 via C1, but the leak is not reported). On the YAML side, the same property is pinned by `gate-consent-dup-rev` alone.
**Fix:** Add `gate-json-consent-dup`: JSON with names `["Acme"]`, `consent_recorded` given `true` then `false`, a sourced `consent_source`, and a leaking mail. Assert exit 1, `[C1]` naming `consent_recorded`, and `[E5]`.

## Info

### IN-01: Rendered binaries under `outbound/` are never scanned for names (carried forward)

**File:** `scripts/lint.py:107-111`, `scripts/lint.py:1184-1186`
**Issue:** `.docx`/`.odt`/`.pptx`/`.xlsx` fail to decode, so E5 checks only their filenames.
**Fix:** Optionally read the zip members' XML with `zipfile` and search the text with the tags stripped. Otherwise, document the gap in the skill.

### IN-02: W1 matches inside HTML comments, W2 does not (carried forward)

**File:** `scripts/lint.py:1322` vs `scripts/lint.py:1382`
**Fix:** Iterate `visible_lines(normalise(text))` in `check_relative_dates`.

### IN-03: `.gitkeep` files are dropped from the walk before E5 (carried forward)

**File:** `scripts/lint.py:916`
**Fix:** Keep `.gitkeep` in the walk for E5, and exempt it from E1-E4 and E9 the way `OS_METADATA_NAMES` already is.

### IN-04: The Python 3.8 target is still never executed (carried forward)

**File:** `tests/lib.sh:123`
**Fix:** `PYTHON=${PYTHON:-python3}` in `lib.sh`, and one run under a 3.8 interpreter.

### IN-05: stderr messages print the raw path, unsanitised (carried forward)

**File:** `scripts/lint.py:1461`, `scripts/lint.py:1465`, `scripts/lint.py:1470-1471`
**Fix:** Wrap the interpolated paths in `sanitise_path()`.

### IN-06: The fixture generator relies on `set -e` to stop on an empty `$parent` (carried forward)

**File:** `tests/fixtures/make-lint-fixtures.sh:74`
**Fix:** `parent="$(mktemp -d)" && [ -n "$parent" ] && [ -d "$parent" ] || usage "mktemp failed"`.

### IN-07: CLAUDE.md does not say that exit 2 also covers an argparse usage error (carried forward)

**File:** `CLAUDE.md:105-108`
**Fix:** Append "(argparse usage errors also exit 2)", as the `--help` epilog already does.

### IN-08: macOS AppleDouble `._*` files still raise E1 and E4

**File:** `scripts/lint.py:100`
**Issue:** On exFAT, SMB and other non-HFS volumes, macOS writes `._<name>` beside every file. Reproduced: `outbound/mails/._2026-09-17_relance.md` gives E1 and E4, exit 1. This is WR-05's problem through a filename pattern that `OS_METADATA_NAMES` cannot express.
**Fix:** Also exempt basenames that start with `._` from E1-E4, and keep them visible to E5.

### IN-09: Punctuation-only tokens collapse, so `C++` matches any `-c-` slug

**File:** `scripts/lint.py:1152`
**Issue:** `filename_pattern` keeps only `[^\W_]+` tokens, so `C++`, `C#` and `F#` all become `c`/`f`. Reproduced: `C++` configured and `2026-09-17_plan-c.md` gives an E5 error. This is a false positive, not a leak, but it forces the file to be renamed.
**Fix:** Apply the filename half only when the needle has at least one token of two or more characters, or when its folded, punctuation-free form still has the same length as the original's alphanumerics.

### IN-10: A duplicated `confidential_names` keeps only the first list, so leaks of the second list's names are not reported

**File:** `scripts/lint.py:541-542`, `scripts/lint.py:795-804`
**Issue:** The run exits 1 (C1), so this is not silent. But `confidential_names: []` followed by `confidential_names: [ Acme ]` reports no E5 for an actual Acme leak. The C1 message says "the leak check cannot trust it" while the leak is sitting there (decision D-FIX-1).
**Fix:** For `confidential_names` only, merge the two occurrences into one list instead of keeping the first.

### IN-11: `yaml_quote` still writes raw DEL and C1 control characters, which YAML 1.2 does not allow unescaped

**File:** `skills/dossier-init/scripts/init.py:195`
**Issue:** YAML 1.2 `c-printable` excludes U+007F-U+0084 and U+0086-U+009F. `lint.py` accepts them, but a conforming YAML reader (another harness) rejects the whole `dossier.yaml`.
**Fix:** Also route `0x7F <= ord(ch) <= 0x9F` through the separator replacement proposed in CR-02.

---

_Reviewed: 2026-09-24T21:30:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
_Iteration: 2_
