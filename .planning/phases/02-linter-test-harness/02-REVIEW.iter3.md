---
phase: 02-linter-test-harness
reviewed: 2026-09-24T22:45:00Z
depth: standard
iteration: 3
files_reviewed: 5
files_reviewed_list:
  - scripts/lint.py
  - skills/dossier-init/scripts/init.py
  - tests/test-lint.sh
  - tests/test-init-empty.sh
  - tests/fixtures/make-lint-fixtures.sh
findings:
  critical: 3
  warning: 4
  info: 10
  total: 17
status: issues_found
---

# Phase 2: Code Review Report (iteration 3)

**Reviewed:** 2026-09-24T22:45:00Z
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found

## Summary

This pass re-reviewed the iteration-2 fix diff (`git diff 4947368..HEAD`, 8 code and test commits) against the five source files. `bash tests/run.sh` is green (6 files, 0 failed).

**Are the iteration-2 findings closed?** Each original scenario was rebuilt on a scratch dossier:

| Iter-2 | Scenario reproduced | Result now | Verdict |
|---|---|---|---|
| CR-01 | `  confidential_names: [ Acme ]` indented under a `counterparts` block and under a scalar. Also a counterpart-level key, and a column-0 list followed by a mis-indented item | Each one is `ERROR [C1]` naming `confidential_names`, exit 1, no `[C0]` | Closed |
| CR-02 | `init.py --confidential-name "Acme<sep>Corp"` for U+2028, TAB, LF, NEL, NBSP and U+3000, with the leak in a body and in `2026-09-17_acme-corp.md` | Written as `"Acme Corp"`, 2 × E5, exit 1 | Closed for whitespace and controls. Invisible *format* characters are still kept (new CR-02) |
| CR-03 | `Łukasz Nowak`, `Øresund Bank`, `Æther Labs`, `Œuvre SA`, `Đorđe Petrović` (both `dj` and `d`) in slugs | E5 on each, exit 1 | Closed |
| WR-01 | `confidential-names`, `Confidential_names`, `confidentialnames`, `confidential_name`, `  - - Acme`, a counterpart-nested key | C1 on each, exit 1 | Closed. The threshold now overshoots (new WR-01) |
| WR-02 | `outbound/` replaced by a symlink; `outbound/mails/archive` as a symlink | `ERROR [E1]` on the link, exit 1 | Closed. The same silent skip is still reachable through another route (new WR-03) |
| WR-03 | "Societe Exemple" and "Big-Telco" in a body | E5 on both | Closed |
| WR-04 | JSON with `consent_recorded` true then false | pinned by `gate-json-consent-dup` | Closed |

**Did the parser become too strict?** No regression found. 30,000 random `render_dossier_yaml()` configurations were fuzzed through `parse_yaml_subset()` + `apply_schema()`. The inputs mixed quotes, `: `, `#`, brackets, backslashes, controls, U+2028, NEL, NBSP, ZWSP and BOM in every field. Each run gave zero skipped lines and zero findings, and every name came back exactly as written. Fresh `en` and `fr` scaffolds, and the spec §3.2 example `dossier.yaml` verbatim, lint `0 error(s), 0 warning(s)`. The near-miss key rule does overreach on legitimate extension keys (WR-01), but it only fires on keys a user adds.

**Would the new tests fail without the fixes?** Yes. I ran the current `tests/test-lint.sh` against `lint.py` and `init.py` from `4947368`: 85 assertions fail. The 86th failure is a git-tracking check that only fails in my untracked copy. The failures span every new fixture except `gate-json-consent-dup` and `c0-dup`, which are coverage cases by design. I then applied 8 targeted mutations to the new lines. 6 were caught. 2 survived (WR-02): wiring `_misplaced_gate_keys()` into `gate_damaged`, and its recursion below the first nesting level.

**New findings.** None of the three Criticals below was introduced by the iteration-2 diff. All three are older fail-open paths that earlier passes did not report. Each one was reproduced end to end, and each exits 0 while a configured confidential name sits in an outbound file:
- A case variant of `outbound/` on macOS.
- An invisible format character in a name, which `init.py` keeps.
- HTML character references in an `.html` deliverable.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: On a case-insensitive filesystem (the macOS default), an `Outbound/` folder gets no outbound check at all, including files the agent writes to `outbound/`

**File:** `scripts/lint.py:1131-1134` (`outbound_files`, exact `outbound/` prefix), `scripts/lint.py:1026-1049` (`walk_tree` reports the on-disk spelling), `skills/dossier-init/scripts/init.py` (`os.makedirs(..., exist_ok=True)` keeps an existing `Outbound/`)
**Issue:** Every outbound check (E1-E5, E9) selects files by the exact prefix `outbound/`. `os.walk` returns the spelling stored on disk. When the folder is `Outbound/` (or `OUTBOUND/`), nothing under it is ever checked, and nothing reports that. On APFS/HFS+ with default settings, `outbound/mails/x.md` and `Outbound/mails/x.md` are the same file. So a skill following the protocol writes into `outbound/`, and the linter sees `Outbound/...` and skips it. Reproduced on this Mac:

```
mkdir -p d/Outbound/mails && printf 'We met Acme.\n' > d/Outbound/mails/acme.md
init.py --target d --language en --confidential-name Acme   # keeps Outbound/ (makedirs exist_ok)
printf 'Status: draft\n...\nWe met Acme.\n' > d/outbound/mails/2026-09-17_x.md   # the agent's write
lint.py d   ->  0 error(s), 0 warning(s), exit 0
```

`d/Outbound/mails/` then holds a headerless, misnamed file and a draft, and both name Acme. `--propose-renames` does print `Outbound -> outbound`, but the linter is fail-open until someone applies it, and forever if the rename is declined. Adopting an existing repository is a spec feature, and a capitalised `Outbound/` is exactly what the rename proposal anticipates. The same applies to `Mails/`, `Deliverables/` and `Calls/` for E4 (E1-E3 and E5 still run on them).
**Fix:** Refuse a case variant of a fixed-layout name, fail closed. In `check_outbound_headers` (or a dedicated walk-level pass):

```python
for rel in tree.dirs:
    parent, _, name = rel.rpartition("/")
    expected = LAYOUT_DIRS if parent == "" else (OUTBOUND_SUBS if parent == OUTBOUND_DIR else ())
    for fixed in expected:
        if name != fixed and name.casefold() == fixed:
            findings.append(Finding(rel, 0, ERROR, "E1",
                "folder is spelt {} but the layout name is {}: none of its files is checked; "
                "rename it (git mv)".format(name, fixed)))
```

Add a fixture `case-outbound` (`Outbound/mails/…` naming Acme) that asserts exit 1 and `^Outbound:0: ERROR [E1]`. It is meaningful on case-sensitive filesystems too.

### CR-02: An invisible format character in a confidential name (ZWSP, BOM, soft hyphen, ZWNJ, word joiner) switches the body check off for that name

**File:** `skills/dossier-init/scripts/init.py:184` (`_SCALAR_BREAKS_RE` covers Cc and U+2028/2029 only), `scripts/lint.py:1254-1273` (`boundary_pattern`), `scripts/lint.py:1336` (`_TEXT_FOLDABLE_RE`), `scripts/lint.py:853`
**Issue:** `yaml_quote()` now turns controls and line breaks into spaces. Unicode *format* characters (category Cf) still pass through unchanged. `str.split()` does not treat them as whitespace, so the linter keeps them inside the needle:
- The exact pattern then needs a literal U+200B (or U+FEFF, U+00AD, and so on).
- `_TEXT_FOLDABLE_RE` (`[\w\s'.\-]+`) rejects the needle, so the folded pass is disabled.
- Only the filename half still works, because it tokenises on `[^\W_]+`.

A trailing or embedded invisible character is what copy-paste from web pages, chat apps and spreadsheets commonly carries. Reproduced end to end, `init.py --confidential-name <name>` then a mail saying "We met Acme Corp today.":

```
"Acme\u200bCorp", "Acme Corp\u200b", "\u200bAcme"   -> 0 error(s), 0 warning(s), exit 0
same with U+FEFF, U+00AD, U+200C, U+2060            -> 0 error(s), 0 warning(s), exit 0
```

This is iteration-2 CR-02's class (the producer keeps a character that stops the name from matching), reached through a character set the fix did not cover. The same characters inside the *body* (`Ac\u00adme`) also hide a name.
**Fix:** Make both sides blind to Cf. In `lint.py`, before building the needles and the haystacks:

```python
def _drop_format(text, repl):
    return "".join(repl if unicodedata.category(ch) == "Cf" else ch for ch in text)

# needles: a format char may separate words -> space, then collapse
names = [" ".join(_drop_format(n, " ").split()) for n in config["confidential_names"]]
# haystack: delete (Cf never contains "\n", so line numbers are unchanged)
norm = _drop_format(normalise(text), "").replace("\r\n", "\n").replace("\r", "\n")
```

The folded pass allows an empty separator, so `Acme Corp` then also matches `Acme\u200bCorp` written in a body. As a producer-side safeguard, add Cf to `_SCALAR_BREAKS_RE` in `init.py`, for example by filtering on `unicodedata.category(ch) == "Cf"` before the regex. Add a fixture `linebreak-format` (an init round trip with `Acme Corp\u200b` and `Acme\u00adCorp`) that asserts E5 in the body.

### CR-03: HTML character references in an `.html` outbound file hide names containing `&`, `'` or accented letters

**File:** `scripts/lint.py:1386-1409` (`check_confidential_names` searches the raw text), `scripts/lint.py:134` (`.html` is an accepted render source)
**Issue:** `.html` is a sanctioned outbound text format: E9 accepts it as the source beside a PDF. The file uses an HTML-comment status header, so E1-E3 pass. Standard HTML serialisation escapes `&` as `&amp;` (`html.escape`, pandoc, every templating engine). Python's `html.escape` and Jinja autoescape also write `'` as `&#39;`, and older tooling writes accents as named references. E5 searches the raw text, so none of these spellings match. Reproduced on `outbound/deliverables/2026-09-17_proposal.html` with a valid comment header:

```
confidential_names: [ "Johnson & Johnson", "AT&T", "Société Exemple", "O'Brien" ]
<p>Prepared for Johnson &amp; Johnson and AT&amp;T.</p>
<p>Soci&eacute;t&eacute; Exemple, Soci&#233;t&#233; Exemple</p>
<p>Dear Mr O&#39;Brien, Mr O&rsquo;Brien</p>
-> 0 error(s), 0 warning(s), exit 0
```

For names with `&` the folded pass cannot help: `_TEXT_FOLDABLE_RE` disables it for those names on purpose.
**Fix:** Add a third haystack that decodes the character references, line by line so line numbers survive. Run the exact and the folded passes on it as well:

```python
import html
decoded = "\n".join(normalise(html.unescape(line)).replace("\n", " ")
                    for line in norm.split("\n"))
if decoded != norm:
    haystacks["decoded"] = decoded
    haystacks["decoded_folded"] = fold_ascii(decoded)
```

This is cheap enough to apply to every text file, not only `.html`, since `&amp;` also appears in Markdown and mail drafts pasted from HTML. Add a fixture `e5-html-entities` with the four spellings above, asserting four `[E5]` lines.

## Warnings

### WR-01: The near-miss rule reports distinct, legitimate keys as misspelt gate keys, and its message asks for a gate-weakening edit

**File:** `scripts/lint.py:226` (`GATE_KEY_CUTOFF = 0.8`), `scripts/lint.py:513-524`, `scripts/lint.py:821-828`
**Issue:** A difflib ratio of 0.8 also catches keys that mean something else. Measured with `gate_key_for()`:
- `consent_scope`, `consent_sources`, `consent_source_url` and `content_source` map to `consent_source`.
- `consent_required`, `consent_revoked` and `consent_recorded_at/_on/_by` map to `consent_recorded`.
- `confidential`, `confidential_notes`, `confidential_terms`, `confidential_name_notes` and `non_confidential_names` map to `confidential_names`.

Reproduced: a dossier with the exact gate keys plus `consent_scope: "mails only"` and `confidential_notes: "ask Jane first"` gives two `ERROR [C1]`, exit 1. D-22 says unknown keys are ignored, and D-FIX-9 only claims that the *spec's* keys score under 0.5. The message is also actively misleading: "key 'consent_scope' is not consent_source: write the key exactly". If `consent_source` is absent, following that advice turns a scope note into the consent source. With `consent_recorded: true`, that suppresses E5.
**Fix:** Keep C1 for the certain near-misses: equal after `_fold_key` (case, `-`, space). Also keep it for a difflib near-miss while the exact gate key is **absent** at the top level. When the exact key is present, a difflib-only sibling is a different key: ignore it (D-22), or at most emit a `WARNING [C0]` that does not name a replacement. Reword the message to "looks like a misspelling of X" instead of "write the key exactly". Add a fixture with `consent_scope` + `confidential_notes` beside the exact keys, asserting exit 0.

### WR-02: Two new gate lines are not pinned by any test (surviving mutations)

**File:** `scripts/lint.py:841` (`config = {"gate_damaged": _misplaced_gate_keys(raw, findings)}`), `scripts/lint.py:816` (`visit(entry, where + "." + key)`)
**Issue:** Both mutations leave `tests/test-lint.sh` fully green:
1. Replacing the `gate_damaged` value with `False`, so a misplaced or misspelt key no longer keeps E5 armed. It matters when the exact consent pair is filled in and a second, misspelt consent key sits beside it. Reproduced on the real code: `consent_recorded: true` + a sourced `consent_source` + `Consent_recorded: false` gives C1 **and** E5. With the mutation, only C1 remains and the leak goes unreported. No fixture combines a recorded, sourced consent with a near-miss key: `gate-key-consent` has no exact `consent_recorded`, so it reads false anyway.
2. Dropping the recursion in `visit()`, so a gate key nested two levels deep is never seen. The YAML subset cannot express that depth, but JSON can: `{"counterparts":[{"meta":{"confidential_names":["Acme"]}}]}`.

This is the same gap iteration-2 WR-04 closed for the JSON duplicate branch.
**Fix:** Add a `gate-key-beside-consent` fixture: exact `consent_recorded: true`, a sourced `consent_source`, `Consent_recorded: false`, and a leaking mail. Assert exit 1, `[C1]` naming `consent_recorded`, and `[E5]`. Also add `gate-json-deep`, with the JSON above, asserting `[C1]` naming `confidential_names`.

### WR-03: An unreadable folder under `outbound/` (or an `outbound/**/.git/` folder) is still skipped in silence, exit 0

**File:** `scripts/lint.py:1026` (`os.walk(root, topdown=True)` with no `onerror`), `scripts/lint.py:1034-1035` (`PRUNED_DIRS` applied inside the layout too)
**Issue:** WR-02 of iteration 2 set the rule that "a leak check that did not run must not exit 0". Two routes still break it:
- `os.walk` drops a directory it cannot list and calls no handler. Reproduced: `chmod 000 outbound/mails` with a leaking `2026-09-17_acme.md` gives `0 error(s), 0 warning(s)`, exit 0.
- `.git` is pruned everywhere, including below `outbound/`. Reproduced: `outbound/mails/.git/2026-09-17_acme.md` holding "Acme" also exits 0.

Both are rarer than the symlink case, but they are the same failure, and the folder is gone from every outbound check.
**Fix:** Pass `onerror=lambda err: unreadable.append(err.filename)` to `os.walk`. Carry the list on `Tree`, and in `check_outbound_headers` report `ERROR [E1] folder cannot be read: none of its files is checked` for any entry under `outbound/`, with an info line elsewhere. Prune `.git` only outside `LAYOUT_DIRS`. Below `outbound/`, report it as E1 like a symlink.

### WR-04: A name wrapped inside a quoted reply (`> `) is not found

**File:** `scripts/lint.py:1272` (`\s+` between tokens), `scripts/lint.py:1344` (`_TEXT_FOLD_SEPARATOR`)
**Issue:** Mail drafts under `outbound/mails/` routinely quote the previous message, hard-wrapped at about 72 columns with a `> ` prefix on every line. The exact pattern joins tokens only with `\s+`, and the folded separator is `[\s_'.\-]*`. Neither crosses the `> ` that starts the next line. Reproduced: `confidential_names: [ "Big Telco" ]` and a body of `> On Monday you wrote: we should meet Big` / `> Telco next week.` gives `0 error(s), 0 warning(s)`, exit 0. CR-03 of iteration 1 fixed exactly this for unquoted wrapping.
**Fix:** Strip quote markers from the E5 haystack without touching newlines, before both passes: `norm = re.sub(r"(?m)^[ \t]*(?:>[ \t]?)+", "", norm)`. Line numbers are unchanged. Add a `> ` wrapped case to `e5-wrapped`.

## Info

### IN-01: Rendered binaries under `outbound/` are never scanned for names (carried forward)

**File:** `scripts/lint.py:108-112`, `scripts/lint.py:1382-1384`
**Issue:** `.docx`/`.odt`/`.pptx`/`.xlsx` fail to decode, so E5 checks only their filenames.
**Fix:** Read the zip members' XML with `zipfile` and search the text with tags stripped (and `html.unescape`, see CR-03), or document the gap in the skill.

### IN-02: W1 matches inside HTML comments, W2 does not (carried forward)

**File:** `scripts/lint.py:1537` (`normalise(text).splitlines()`) vs `scripts/lint.py:1589` (`visible_lines`)
**Fix:** Iterate `visible_lines(normalise(text))` in `check_relative_dates`.

### IN-03: `.gitkeep` files are dropped from the walk before E5 (carried forward)

**File:** `scripts/lint.py:1047`
**Fix:** Keep `.gitkeep` in the walk for E5, and exempt it from E1-E4 and E9 the way `OS_METADATA_NAMES` is.

### IN-04: The Python 3.8 target is still never executed (carried forward)

**File:** `tests/lib.sh:123`
**Fix:** `PYTHON=${PYTHON:-python3}` in `lib.sh`, and one run under a 3.8 interpreter.

### IN-05: stderr messages print the raw path, unsanitised (carried forward)

**File:** `scripts/lint.py:1673`, `scripts/lint.py:1677`, `scripts/lint.py:1682-1683`
**Fix:** Wrap the interpolated paths in `sanitise_path()`.

### IN-06: The fixture generator relies on `set -e` to stop on an empty `$parent` (carried forward)

**File:** `tests/fixtures/make-lint-fixtures.sh:74`
**Fix:** `parent="$(mktemp -d)" && [ -n "$parent" ] && [ -d "$parent" ] || usage "mktemp failed"`.

### IN-07: CLAUDE.md does not say that exit 2 also covers an argparse usage error (carried forward)

**File:** `CLAUDE.md:105-107`
**Fix:** Append "(argparse usage errors also exit 2)", as the `--help` epilog already does.

### IN-08: macOS AppleDouble `._*` files still raise E1 and E4 (carried forward)

**File:** `scripts/lint.py:101`, `scripts/lint.py:1142`, `scripts/lint.py:1241`
**Fix:** Also exempt basenames starting with `._` from E1-E4, and keep them visible to E5.

### IN-09: Punctuation-only tokens collapse in the filename half, so `C++` matches any `-c-` slug (carried forward)

**File:** `scripts/lint.py:1306-1318`
**Issue:** The folded text pass now has a guard (`_TEXT_FOLDABLE_RE`), but `filename_pattern` does not: `C++` configured still flags `2026-09-17_plan-c.md`.
**Fix:** Reuse the `_TEXT_FOLDABLE_RE` guard in `filename_pattern`, or require a token of two or more characters.

### IN-10: A duplicated `confidential_names` keeps only the first list (carried forward, D-FIX-1)

**File:** `scripts/lint.py:610-615`, `scripts/lint.py:908-917`
**Issue:** The run exits 1 (C1), but `confidential_names: []` followed by `confidential_names: [ Acme ]` reports no E5 for an actual Acme leak.
**Fix:** For `confidential_names` only, merge the occurrences instead of keeping the first.

_Iteration-2 IN-11 (raw DEL/C1 controls from `yaml_quote`) is closed by the CR-02 fix and is not carried._

---

_Reviewed: 2026-09-24T22:45:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
_Iteration: 3_
