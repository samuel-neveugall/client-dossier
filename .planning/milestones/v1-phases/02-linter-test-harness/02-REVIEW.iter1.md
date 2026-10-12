---
phase: 02-linter-test-harness
reviewed: 2026-09-24T12:00:00Z
depth: standard
files_reviewed: 7
files_reviewed_list:
  - scripts/lint.py
  - skills/dossier-init/scripts/init.py
  - tests/lib.sh
  - tests/fixtures/make-lint-fixtures.sh
  - tests/test-lint.sh
  - tests/test-init-empty.sh
  - CLAUDE.md
findings:
  critical: 3
  warning: 9
  info: 7
  total: 19
status: issues_found
---

# Phase 2: Code Review Report

**Reviewed:** 2026-09-24T12:00:00Z
**Depth:** standard
**Files Reviewed:** 7
**Status:** issues_found

## Summary

Reviewed `scripts/lint.py` in full, the `init.py` diff since `d958471` (the `emit_scalar` hardening), the test harness additions (`tests/lib.sh`, `tests/test-lint.sh`, `tests/fixtures/make-lint-fixtures.sh`, `tests/test-init-empty.sh`) and the `CLAUDE.md` command section. `bash tests/run.sh` is green (6 files, 0 failed). Both Python files parse under `ast.parse(..., feature_version=(3, 8))`, and a grep found no 3.9+ stdlib API (no `removeprefix`, no PEP 585/604 annotations, no `match` statement).

The `consent_recorded` typing (D-24) is correct and fails closed, and the JSON branch rejects a quoted `"true"` as it should (checked by hand). The problems are elsewhere in the **confidentiality gate**. `confidential_names` fails **open**: when the parser cannot read the line that carries the names, it drops the whole list, reports only a C0 *warning*, turns E5 off and exits 0. I reproduced this with seven inputs (CR-01), four of them valid YAML, and a file written by this repository's own `init.py` triggers it too (CR-02). E5 also cannot detect a multi-word name in any filename that passes E4, because E4 requires hyphenated slugs. The suite never exercises any of these paths, so it stays green.

## Critical Issues

### CR-01: An unreadable `confidential_names` line silently disables E5 (fail-open, exit 0)

**File:** `scripts/lint.py:437-492` (parser skip), `scripts/lint.py:689-693` (C0 is a WARNING), `scripts/lint.py:646-647`, `scripts/lint.py:970-971`
**Issue:** `parse_yaml_subset` drops any line outside the subset and `load_config` reports it as `WARNING [C0]`. If the dropped line is the `confidential_names` line, the key is absent, `_as_str_list` returns `[]`, `check_confidential_names` returns early, and the run exits 0 while a confidential name sits in `outbound/`. This goes against the fail-closed rule the file applies to `consent_recorded` (T-02-02). Each case below was run against a mail containing "Acme" and exited **0** with no E5:

- `confidential_names:` followed by `- Acme` at column 0. This is the most common block-sequence style in hand-written YAML.
- A multi-line flow list: `confidential_names: [` / `  Acme` / `]`
- A valid YAML escape the subset does not support: `[ "Acme", "Zoë" ]`. Every name on the line is lost, including the valid `Acme`.
- A typo: `[ "Acme" , "Beta" x ]`
- A quoted key: `"confidential_names": [ Acme ]`
- A block sequence whose item indentation changes partway through
- A duplicate key: `confidential_names: [ Acme ]` then `confidential_names: []`. The last one wins silently; a conforming YAML parser rejects duplicate keys.

**Fix:** Fail closed on the safety-relevant keys. If a skipped line, or any indented continuation of it, belongs to `confidential_names`, `consent_recorded` or `consent_source`, report `ERROR [C1]` and not `WARNING [C0]`. Report a duplicate key as C1 as well. A minimal version:

```python
GATE_KEYS = ("confidential_names", "consent_recorded", "consent_source")
_LOOSE_KEY_RE = re.compile(r"""^\s*["']?([A-Za-z_][A-Za-z0-9_-]*)["']?\s*:""")
# in parse_yaml_subset: track `last_top_key` (set even when the value fails to parse)
# and, on ValueError, record (number, last_top_key or loose-key match).
# in load_config:
for number, key in skipped:
    severity, ident = (ERROR, "C1") if key in GATE_KEYS else (WARNING, "C0")
    findings.append(Finding(CONFIG_NAME, number, severity, ident, ...))
# and in parse_yaml_subset, at indent 0:
if key in data:
    raise ValueError("duplicate key")   # surfaced as C1 when key in GATE_KEYS
```

Support column-0 block sequences (`- item` at indent 0 directly under an empty-valued key), since this is ordinary YAML. Add fixtures for each case above that assert exit 1.

### CR-02: A name `init.py` writes can make `lint.py` drop every confidential name (U+2028/U+2029/U+0085)

**File:** `skills/dossier-init/scripts/init.py:187` and `scripts/lint.py:437`
**Issue:** `yaml_quote` strips only characters below 0x20, so U+0085, U+2028 and U+2029 reach `dossier.yaml` unchanged inside a quoted scalar. `parse_yaml_subset` splits the file with `str.splitlines()`, which treats those three characters as line breaks. This happens to the entire `confidential_names: [ ... ]` line. The two halves are both outside the subset, both are skipped as C0 warnings, and **every** name on the line is dropped. Reproduced: `init.py --confidential-name $'Acme Corp' --confidential-name Beta`, then a mail containing "Beta", gives `0 error(s), 2 warning(s)` and exit 0. A Word manual line break pasted into a CLI argument yields U+2028, so this can happen in practice. The producer and the consumer in this repository disagree on what a line is. `sanitise_path` already treats U+2028/U+2029 as line breaks on output (line 809) but not on input.
**Fix:** Fix both sides.

```python
# lint.py parse_yaml_subset: split on real line terminators only
for number, raw in enumerate(text.replace("\r\n", "\n").replace("\r", "\n").split("\n"), 1):

# init.py yaml_quote: also drop the Unicode line/paragraph separators and NEL
_YAML_LINE_BREAKS = {"\x85", " ", " "}
cleaned = "".join(ch for ch in value if ord(ch) >= 0x20 and ch not in _YAML_LINE_BREAKS)
```

Add a round-trip test: `init.py --confidential-name $'A B' --confidential-name Beta`, then a leak of `Beta`, must exit 1.

### CR-03: E5 misses every multi-word name in a conforming filename, and most whitespace variants in text

**File:** `scripts/lint.py:944-957` (`boundary_pattern`), `scripts/lint.py:976-988`
**Issue:** The needle is `re.escape`d literally, so the single space in `Jane Doe` matches exactly one U+0020 and nothing else. Consequences, all reproduced with `confidential_names: [ "Jane Doe" ]`:
- **Filenames:** E4 requires the slug to be `[a-z0-9]+(-[a-z0-9]+)*`, so the only conforming spelling of the name in a filename is `jane-doe`. The E5 filename check can **never** match a multi-word name in a file that passes E4. The filename half of E5 only works for single-token names.
- **Text:** `Jane\nDoe` (hard-wrapped Markdown, which is normal in a mail body), `Jane  Doe`, `Jane Doe` and `Jane\tDoe` all pass silently. Only the exact-spacing case fired.

**Fix:** Build the pattern from tokens joined by a separator class, and search the whole normalised text instead of one line at a time. Derive the line number from the match offset:

```python
def boundary_pattern(needle, filename=False):
    tokens = normalise(needle).split()
    sep = r"[\s_\-.]+" if filename else r"\s+"   # \s covers NBSP under re.UNICODE
    body = sep.join(re.escape(t) for t in tokens)
    return re.compile(r"(?<![^\W_])" + body + r"(?![^\W_])", re.IGNORECASE)
# text half:
norm = normalise(text)
for m in pattern.finditer(norm):
    number = norm.count("\n", 0, m.start()) + 1
```

Add fixtures `e5-slug` (`2026-09-17_jane-doe-offer.md`) and `e5-wrapped` (name split across lines) that assert E5.

## Warnings

### WR-01: `''` inside a single-quoted scalar is mis-tokenised, so a valid entry drops the whole line

**File:** `scripts/lint.py:319` (`strip_comment`), `scripts/lint.py:386` (`_split_flow`)
**Issue:** A quote opens only when the previous character is in `_QUOTE_OPENERS`. After the first `'` of a doubled `''` closes the quote, the second `'` follows a `'` and is not treated as reopening it. Everything after it is then read as unquoted: a `#` starts a comment and a `,` splits the item. Checked with the module imported: `confidential_names: [ 'O''Brien, Jr', Acme ]`, `confidential_names: 'O''Brien # 2'` and `consent_source: 'it''s # ok'` are all skipped. All three are valid YAML. Through CR-01, the first one disables E5.
**Fix:** In both scanners, when a single quote is open and the current character is `'` and the next one is also `'`, append both and advance by two without closing:

```python
if quote == "'" and ch == "'" and line[i + 1:i + 2] == "'":
    out.append("''"); skip_next = True; continue
```

### WR-02: `consent_source: null` / `~` / placeholder text suppresses E5 and E6

**File:** `scripts/lint.py:657-663`, `scripts/lint.py:991-996`
**Issue:** `consent_source` is read as a verbatim string (D-24.2), so `consent_recorded: true` combined with `consent_source: null`, `~` or `TODO` counts as a recorded, sourced consent. E5 is suppressed, E6 does not fire, and the run exits 0 (reproduced for all three). In YAML, `null`/`~` mean "no value", which is exactly the case the spec calls a lint error ("true without a source"). Since D-24 decides every ambiguity on the strict side for this gate, the empty-source test should include the null spellings.
**Fix:** For the gate check only (the value is still stored as a string), treat an unquoted `null`/`Null`/`NULL`/`~` as empty:

```python
_NULL_SCALARS = frozenset(("null", "Null", "NULL", "~"))
def _source_is_empty(raw_value):
    return (raw_value is None or not isinstance(raw_value, Scalar) or raw_value.text.strip() == ""
            or (not raw_value.quoted and raw_value.text in _NULL_SCALARS))
```

Keep the raw `Scalar` in `config` so that `consent_is_recorded` and `check_consent_source` both call it.

### WR-03: A stray `dossier.yaml` anywhere under `outbound/` turns off every outbound check for that subtree

**File:** `scripts/lint.py:745-749`
**Issue:** Any child directory that contains a `dossier.yaml` file is pruned (D-03), and this includes the fixed-layout folders. An empty `outbound/mails/dossier.yaml` hides the whole `mails/` folder from E1-E5. Reproduced: a headerless, badly named mail containing a confidential name produced `0 error(s), 0 warning(s)`, exit 0. Nothing is printed, so nobody learns the subtree was skipped. It takes one misplaced write by an agent.
**Fix:** Do not treat `sources/`, `dossier/`, `outbound/`, `knowledge/` or anything under them as sub-dossier boundaries, since a nested dossier cannot legitimately live inside the fixed layout. At minimum, print one `info:` line for each pruned directory. Report a `dossier.yaml` found under `outbound/` as an error.

### WR-04: The `README.md` exemption applies at any depth under `outbound/`, which is wider than D-06

**File:** `scripts/lint.py:86`, `scripts/lint.py:841-846`, `scripts/lint.py:935`, `scripts/lint.py:1060`
**Issue:** D-06 exempts `README.md` at the root of `outbound/`. The code tests only the basename, so `outbound/mails/README.md` and `outbound/deliverables/README.md` also skip E1-E4, and E9 in `deliverables/`. Reproduced: a headerless `outbound/mails/README.md` raises no finding. A draft saved under that name bypasses the status-header protocol.
**Fix:** Compare the relative path, not the basename: `EXEMPT_PATHS = frozenset(("outbound/README.md",))`, and drop `README.md` from the E4 and E9 exemptions.

### WR-05: Finder's `.DS_Store` (and any other OS dotfile) under `outbound/` produces two errors

**File:** `scripts/lint.py:841-846`, `scripts/lint.py:924-941`
**Issue:** `.gitkeep` is the only dotfile skipped. On macOS (this project's platform), opening `outbound/mails/` in Finder creates `.DS_Store`. It then gets `E1 no status header` (or `cannot be read`) plus `E4 filename does not match`, and the run exits 1 (reproduced). Tools that call the linter will then report a "malformed dossier" for a folder that was only viewed. `Thumbs.db` and `desktop.ini` on Windows cause the same problem.
**Fix:** Add a small `IGNORED_BASENAMES = frozenset((".gitkeep", ".DS_Store", "Thumbs.db", "desktop.ini"))`, drop those names in `walk_tree`, and add a fixture for it. Keep E5's filename check on every other file.

### WR-06: Printing a non-ASCII finding to a non-UTF-8 stdout crashes the run (exit 3)

**File:** `scripts/lint.py:1213-1214`, `scripts/lint.py:1269-1275`
**Issue:** Findings include confidential names and word-list entries (`'récemment'`). If stdout is not UTF-8, `print` raises `UnicodeEncodeError`. That happens with a Windows console or pipe under Python 3.8 (cp1252), with Codex on Windows, or with a legacy locale. `main` catches the error and exits 3 after a partial report. Reproduced with `PYTHONIOENCODING=latin-1` and a name `Łukasz`: `internal linter failure: UnicodeEncodeError`, exit 3, and the E5 finding is lost.
**Fix:** At the start of `main`:

```python
for stream in (sys.stdout, sys.stderr):
    try:
        stream.reconfigure(errors="backslashreplace")   # 3.7+
    except AttributeError:
        pass
```

### WR-07: Negative location assertions pass vacuously when the bait line is missing

**File:** `tests/test-lint.sh:506-508` (`no_w2_at`), `tests/test-lint.sh:560-565` (`fr_none`), `tests/test-lint.sh:516`
**Issue:** `fr_none` replaces a missing line with `n='missing'`, and `no_w2_at` passes an empty `line_of` result into the regex. Either way the "zero matching lines" assertion passes when the fixture no longer contains the bait. A template or fixture edit that removes `gelé jusqu'`, `Probablement un budget` or `Une piste non vérifiée` makes those negative checks meaningless with no failure. `no_w2_at '## Chronologie'` is vacuous in any case: a heading can never start with `- `, so the assertion cannot fail.
**Fix:** Make a missing bait a failure:

```bash
fr_none() { local n; n="$(line_of "$FR/$1" "$2")"
  if [ -z "$n" ]; then echo "FAIL: $3 (bait '$2' not found in $1)" >&2; TESTS_FAILED=$((TESTS_FAILED+1)); return; fi
  assert_eq 0 "$(count_out_lines "^$(printf '%s' "$1" | sed 's/\./\\./g'):$n: ")" "$3"; }
```

Do the same in `no_w2_at`, and for the heading case, test a bullet-shaped heading line instead.

### WR-08: The "no dossier → exit 2" test depends on the machine's directory tree

**File:** `tests/test-lint.sh:670-677`
**Issue:** `find_root` walks upward with no stop condition (D-01). If any ancestor of `$TMPDIR` contains a `dossier.yaml`, the linter lints that tree, exits 0 or 1, and the test fails. That can be a CI workspace or a user's home directory once they adopt this plugin. The outcome depends on the environment, not on the code.
**Fix:** Before the assertion, check that no ancestor of `$EMPTY` has a `dossier.yaml`. If one does, skip the case with a message instead of failing, or set `TMPDIR` to a known-clean root for the whole suite.

### WR-09: The suite has no fixture for any fail-open path of the gate

**File:** `tests/fixtures/make-lint-fixtures.sh:377-451`, `tests/test-lint.sh:280-281`
**Issue:** Every E5 fixture gets `confidential_names` from `init.py`, which always writes a single-line flow list of double-quoted names. The JSON fixture (`json-config`) has an empty list, and no JSON consent case exists. The parser branches that matter for the gate have no tests: block sequences, column-0 items, `''` escapes, a skipped names line, duplicate keys, JSON names with a quoted consent flag, and null `consent_source`. This is why CR-01, CR-02, WR-01 and WR-02 exist while the suite stays green.
**Fix:** Add hand-written `dossier.yaml` variants (via `replace_line`) for each of those shapes. Each should assert exit 1 and `[E5]`, or `[C1]` where the input is malformed. Add a JSON case with `"confidential_names": ["Acme"]` and `"consent_recorded": "true"` that asserts `[C1]` and `[E5]`.

## Info

### IN-01: Rendered binaries under `outbound/` are never scanned for names

**File:** `scripts/lint.py:93-97`, `scripts/lint.py:981-983`
**Issue:** `.docx`/`.odt`/`.pptx`/`.xlsx` fail to decode, so E5 checks only their filenames (P-07, accepted by design). E9 covers `deliverables/` only through the sibling source, which may be older than the render. A `.docx` under `mails/` or `calls/` is never content-checked. These Office formats are zip archives, so the standard library can read them.
**Fix:** Optionally read `word/document.xml` / `content.xml` / `ppt/slides/*.xml` with `zipfile` and search the text with the tags stripped. Otherwise, document the gap in the skill prose.

### IN-02: W1 matches inside HTML comments, W2 does not

**File:** `scripts/lint.py:1111` vs `scripts/lint.py:1171`
**Issue:** `check_relative_dates` iterates `normalise(text).splitlines()`, while `check_bullet_sources` uses `visible_lines()`. A commented example line containing "tomorrow" raises W1. Today's templates happen to avoid those words.
**Fix:** Iterate `visible_lines(normalise(text))` in W1 too, so the two checks agree.

### IN-03: `.gitkeep` files are dropped from the walk before E5

**File:** `scripts/lint.py:755`
**Issue:** A non-empty `.gitkeep` under `outbound/` is never read, so text written into one bypasses E5.
**Fix:** Drop `.gitkeep` from E1-E4 and E9 only; keep it visible to E5, as `README.md` already is.

### IN-04: The Python 3.8 target is never executed

**File:** `tests/lib.sh:123`
**Issue:** The suite runs whatever `python3` is on PATH (3.14 here). Both scripts pass a 3.8 grammar check and a grep found no 3.9+ API, but nothing enforces this.
**Fix:** Add an opt-in `PYTHON=${PYTHON:-python3}` to `lib.sh` and run the suite once under `uv run --python 3.8`.

### IN-05: stderr messages print the raw path, unsanitised

**File:** `scripts/lint.py:1250`, `scripts/lint.py:1254`, `scripts/lint.py:1259`
**Issue:** The T-02-01 sanitisation covers stdout only. A PATH argument with control characters is echoed raw on stderr.
**Fix:** Wrap `start` and the root path in `sanitise_path()`.

### IN-06: The fixture generator relies on `set -e` to stop on an empty `$parent`

**File:** `tests/fixtures/make-lint-fixtures.sh:74`
**Issue:** If `mktemp -d` failed and errexit were ever disabled, `$parent` would be empty and `cp -R "$clean" "/e7"` would write at the filesystem root.
**Fix:** `parent="$(mktemp -d)" && [ -n "$parent" ] && [ -d "$parent" ] || usage "mktemp failed"`.

### IN-07: CLAUDE.md does not say that exit 2 also means an argparse usage error

**File:** `CLAUDE.md` (Commands section)
**Issue:** The `--help` epilog says so, but the documented contract for future consumers lists exit 2 only as "no dossier.yaml found upward or unreadable". A consumer that passes a bad flag would read that as "not a dossier".
**Fix:** Add "(argparse usage errors also exit 2)" to the CLAUDE.md line.

---

_Reviewed: 2026-09-24T12:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
