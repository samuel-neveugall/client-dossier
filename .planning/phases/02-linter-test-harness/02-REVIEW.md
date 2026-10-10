---
phase: 02-linter-test-harness
reviewed: 2026-09-25T13:49:34Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - scripts/lint.py
  - skills/dossier-init/scripts/init.py
  - tests/fixtures/make-lint-fixtures.sh
  - tests/test-lint.sh
findings:
  critical: 3
  warning: 2
  info: 2
  total: 7
status: issues_found
---

# Phase 02: Code Review Report (iteration 4, gap-closure plans 02-07, 02-08, 02-09)

**Reviewed:** 2026-09-25T13:49:34Z
**Depth:** standard
**Files Reviewed:** 4
**Status:** issues_found

## Summary

Scope: only the diff `8c2ed0f..HEAD` (commits b224542, 91581ea, 6f881ac, d50c3a2, 856b5bc, 7ca0e42, 616e7e7), meaning the presence-aware gate near-miss rule, case-variant/unreadable/`.git` walk-level E1, and the E5 haystack stages (quote strip, HTML decode, Cf readings) plus `init.py`'s Cf mapping. `bash tests/run.sh` is green (`TOTAL: 6 files, 0 failed`). Every finding below was reproduced against the real `scripts/lint.py` / `init.py` in a scratch dossier. None of them depends on a hostile writer. Each one is a plausible accident that makes the linter exit 0 while a confidential name sits under `outbound/`.

Most of the new code does what its commits claim. Three holes remain, and each lets a leak exit 0:

1. The case-variant fix (G-02-4a) is bypassed when the case-variant folder holds a `dossier.yaml`. The walk prunes it as a sub-dossier before the E1 check ever sees it.
2. The presence rule (G-02-2) regresses a case the linter caught at `8c2ed0f`. A misspelt `confidential_name:` holding the real names, placed next to an empty exact `confidential_names: []`, is now silently ignored.
3. `init.py`'s new Cf→space mapping drops the deletion reading on the producer side. After the round trip, a name that holds a soft hyphen and a `&` is never matched. The docstring claim that "the folded pass still matches the word run together" is false for exactly those names.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: A case-variant layout folder holding a `dossier.yaml` is pruned as a sub-dossier, so its leak exits 0 (G-02-4a bypass)

**File:** `scripts/lint.py:1113`, `scripts/lint.py:1120-1123`, `scripts/lint.py:1298-1307`
**Issue:** The new case-variant E1 loop iterates `tree.dirs`. `walk_tree` decides "inside the fixed layout" with exact, case-sensitive membership:
`in_layout = prefix.split("/", 1)[0] in LAYOUT_DIRS` (1113), and the root-level sub-dossier exemption is `not (prefix == "" and name in LAYOUT_DIRS)` (1120). `Outbound` is not in `LAYOUT_DIRS`. If `Outbound/` holds a `dossier.yaml` (the case WR-03 already said must never be a boundary), it is therefore pruned as a D-03 sub-dossier. It never reaches `dirs`, so the new E1 never fires and only an info line is printed. Linting it "separately", as the info line suggests, does not help either: its files sit at `mails/…`, not under `outbound/`, so E5 never runs there. Reproduced:

```
$ mv outbound ob-tmp && mv ob-tmp Outbound && cp dossier.yaml Outbound/
$ python3 scripts/lint.py .      # Outbound/mails/2026-09-17_relance.md says "We met Acme."
info: sub-dossier Outbound/ skipped: it holds its own dossier.yaml (lint it separately)
0 error(s), 0 warning(s)          # exit 0
```

On a case-insensitive filesystem this is the very folder the agent writes into, so this closes neither G-02-4a nor WR-03 when both conditions hold together. The same applies to `Sources/`, `Knowledge/` and `Dossier/`. `.git` pruning inside a case variant is also silent (`in_layout` False), although the folder's own E1 would cover that once it is reached.

**Fix:** Make the layout membership in `walk_tree` case-insensitive, so a case variant is walked, never pruned, and reaches the E1 loop:

```python
_LAYOUT_FOLDED = frozenset(d.casefold() for d in LAYOUT_DIRS)
...
in_layout = prefix.split("/", 1)[0].casefold() in _LAYOUT_FOLDED
...
if (not in_layout and not (prefix == "" and name.casefold() in _LAYOUT_FOLDED)
        and os.path.isfile(os.path.join(dirpath, name, CONFIG_NAME))):
```

Add a fixture `case-outbound-config` (`Outbound/` + `Outbound/dossier.yaml` + a leak) asserting `Outbound:0: ERROR [E1]` and exit 1.

### CR-02: The presence rule silently ignores a misspelt `confidential_names` that carries the names (regression against 8c2ed0f)

**File:** `scripts/lint.py:862-869`, `scripts/lint.py:876-881`
**Issue:** `near not in raw` exempts every difflib-only near-miss once the exact key is present, whatever it holds. The motivating cases were extension keys (`consent_scope`, `confidential_notes`). The rule also swallows plain misspellings of `confidential_names` sitting next to the template's own `confidential_names: []`, and those misspellings hold the names E5 should use. The linter at `8c2ed0f` reported these as C1. HEAD exits 0:

```
confidential_names: []
confidential_name: [ "Acme" ]      # also: confidentail_names, Confidential_name, confidential_namess
# outbound mail: "We met Acme."
base 8c2ed0f: dossier.yaml:6: ERROR [C1] key 'confidential_name' is not confidential_names ... exit 1
HEAD:         0 error(s), 0 warning(s)                                                 exit 0
```

This is a realistic edit. The scaffold always writes `confidential_names: []`, and a user adding a line by hand types the singular. Ignoring a consent_* near-miss cannot open the gate, because the exact consent keys still decide it. Ignoring a `confidential_names` near-miss drops data and turns E5 off for those names. D-GAP-1 did not weigh this asymmetry. Samuel should re-confirm the rule before it ships.

**Fix:** Keep the presence exemption for consent_* near-misses, but do not let it silently drop a near-miss of `confidential_names` that is only a small edit away. For example, near-misses within an edit distance of 2 stay C1 even when the exact key is present. That still exempts `non_confidential_names` and `confidential_notes`, which are 4+ edits away, so `gate-key-extras` stays clean:

```python
def _small_edit(a, b):
    m = difflib.SequenceMatcher(None, a, b)
    return sum(max(i2 - i1, j2 - j1) for op, i1, i2, j1, j2 in m.get_opcodes() if op != "equal") <= 2

if near is not None and (near not in raw
                         or (near == "confidential_names" and _small_edit(_fold_key(key), near))):
    ...report C1...
```

Add fixtures for `confidential_name` and `confidentail_names` beside `confidential_names: []`, both expecting C1 + exit 1.

### CR-03: `init.py` maps every Cf character to a space, so the init round trip loses the deletion reading and a name holding `&`/`+` is never matched

**File:** `skills/dossier-init/scripts/init.py:206` (and the claim at `init.py:198-202`); consumer side `scripts/lint.py:1561-1588` (`_build_needle`)
**Issue:** D-GAP-6's premise is that neither reading alone is enough. `lint.py` builds both readings when the config holds the raw Cf character, but `init.py` now writes only the space reading into `dossier.yaml`, so the linter never sees the deletion reading of a scaffolded name. The docstring says this is "cosmetic only: scripts/lint.py's folded pass still matches the word run together". That is false for every name `folded_text_pattern()` refuses (`_TEXT_FOLDABLE_RE` rejects `&`, `+`, `#` …), because only the exact pass remains and it now requires the spurious space. A soft hyphen is exactly what text copied from a hyphenated web page carries. Reproduced:

```
$ init.py --confidential-name $'Pro\u00adcter & Gamble' --confidential-name $'AT\u00ad&T'
confidential_names: [ "Pro cter & Gamble", "AT &T" ]
# mail body: "We met Procter & Gamble and AT&T."
0 error(s), 0 warning(s)           # exit 0 -- both leaks missed
# same names hand-written with the raw U+00AD in dossier.yaml: 2 x ERROR [E5], exit 1
```

The `format-name-init` fixture does not catch this because all five of its names pass the folded pass. It also pins the lossy `"Glo bex"` output as expected.

**Fix:** Keep both readings on the producer side. For `confidential_names` only, emit the deletion reading as an extra list entry whenever it differs from the space reading, and keep the space reading for every other scalar. A simpler alternative is to delete U+00AD (by definition an intra-word hyphenation point) and map the other Cf characters to a space:

```python
def _confidential_entries(name):
    deleted = "".join(ch for ch in name if unicodedata.category(ch) != "Cf")
    spaced = "".join(" " if unicodedata.category(ch) == "Cf" else ch for ch in name)
    return [deleted] if " ".join(deleted.split()) == " ".join(spaced.split()) else [spaced, deleted]

quoted_names = ", ".join(yaml_quote(e) for n in confidential_names for e in _confidential_entries(n))
```

Correct the docstring. Add a `format-name-init` case with `Pro<SHY>cter & Gamble` / `AT<SHY>&T` expecting E5.

## Warnings

### WR-01: `format_readings` covers category Cf only, so other invisible default-ignorable characters still hide a name

**File:** `scripts/lint.py:1498-1517`
**Issue:** G-02-4b is closed only for `unicodedata.category(ch) == "Cf"`. Several Default_Ignorable_Code_Point characters are not Cf and have combining class 0, so `fold_ascii()` keeps them too: U+034F COMBINING GRAPHEME JOINER (Mn), variation selectors U+FE00–FE0F (Mn; VS16 routinely follows pasted emoji), Mongolian free variation selectors U+180B–180D (Mn), and the Hangul fillers U+115F/U+1160/U+3164/U+FFA0 (Lo). Reproduced: `Ac\u034fme`, `Ac\ufe0fme`, `Ac\u180bme` and `Ac\u3164me` in a mail body against the configured name `Acme` give `0 error(s), 0 warning(s)`, exit 0.
**Fix:** Widen the predicate to an explicit default-ignorable set (the standard library exposes no property API), and share it with `init.py`'s `yaml_quote()`:

```python
_IGNORABLE_RE = re.compile("[\u00ad\u034f\u061c\u115f\u1160\u17b4\u17b5\u180b-\u180f\u200b-\u200f"
                           "\u202a-\u202e\u2060-\u206f\u3164\ufe00-\ufe0f\ufeff\uffa0￰-￸"
                           "\U0001bca0-\U0001bca3\U0001d173-\U0001d17a\U000e0000-\U000e0fff]")
def _is_invisible(ch):
    return unicodedata.category(ch) == "Cf" or _IGNORABLE_RE.match(ch) is not None
```

Extend `format-body` with CGJ, VS16 and U+3164 lines.

### WR-02: The G-02-4e unreadable-folder assertions skip silently under root, so CI coverage disappears without a failure

**File:** `tests/test-lint.sh:686-706`
**Issue:** When `chmod 000` does not take effect (CI containers usually run as root), both `unreadable-*` cases only print `SKIP:` to stderr. `tests/run.sh` still reports `ok tests/test-lint.sh`. G-02-4e's only end-to-end coverage then vanishes from the summary, and a regression in `_onerror` or in the `tree.unreadable` E1 loop would pass CI unnoticed.
**Fix:** Also cover the path without file modes. Add a Python-level test that calls `walk_tree()` with `os.scandir` patched to raise `PermissionError` for one path and asserts that `tree.unreadable` holds it. Alternatively, count skips and print them in the final `PASS n FAIL m` line, or fail when `CI=true` and a skip occurred.

## Info

### IN-01: Dead condition in the nested near-miss branch

**File:** `scripts/lint.py:862`
**Issue:** `elif key not in GATE_KEYS:` is always true when reached. An exact gate key is `_fold_key`-equal to itself, so `_certain_gate_key_for()` has already returned it in the `if` branch. This dead check misleads a reader into thinking an exact nested gate key can fall through to the near-miss branch.
**Fix:** Replace it with a plain `else:`.

### IN-02: `LOCKED_DIRS` relies on unquoted word splitting

**File:** `tests/test-lint.sh:34` (and the appends at the chmod sites)
**Issue:** `for _d in $LOCKED_DIRS` splits on whitespace and globs. If `$TMPDIR` or the fixture parent contains a space, the unlock runs on fragments, the mode-000 folder stays locked, and the trap's `rm -rf` leaks it. This is the exact failure the variable exists to prevent.
**Fix:** Use a newline-separated list read with `while IFS= read -r _d`, or unlock the two known paths explicitly in the trap. Bash 3.2 has arrays, so `LOCKED_DIRS+=("$dir")` with `"${LOCKED_DIRS[@]}"` also works.

---

_Reviewed: 2026-09-25T13:49:34Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
