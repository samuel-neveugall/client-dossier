---
phase: 02-linter-test-harness
fixed_at: 2026-09-25T14:10:16Z
review_path: /Users/samuel/Documents/dev/client-dossier/.planning/phases/02-linter-test-harness/02-REVIEW.md
iteration: 3
findings_in_scope: 5
fixed: 5
skipped: 2
status: partial_by_mandate
amended_at: 2026-09-25
amended_status: cr02_closed_follow_up
cr02_status: fixed
---

# Phase 2: Code Review Fix Report (iteration 3)

**Fixed at:** 2026-09-25T14:10:16Z
**Source review:** /Users/samuel/Documents/dev/client-dossier/.planning/phases/02-linter-test-harness/02-REVIEW.md
("iteration 4" by that report's own internal numbering of the review round;
this file continues the fix-round numbering of 02-REVIEW-FIX.iter1.md /
02-REVIEW-FIX.iter2.md)

**Summary:**
- Findings in scope of the mandate: 5 of the review's 7 (2 critical of 3,
  both warnings, both info). CR-02 was explicitly out of scope -- gated by
  Samuel's arbitrage. WR-01 was explicitly deferred as tracked debt, not a
  mandate item.
- Fixed: 5 (CR-01, CR-03, WR-02, IN-01, IN-02)
- Skipped: 2 (CR-02 frozen, WR-01 deferred)
- **Amended 2026-09-25 (follow-up mandate `fix-cr02`, after Samuel's arbitrage arrived):** CR-02
  is now fixed too, commit b51b670. 6 of 7 findings closed; only WR-01 stays deferred. See its
  entry under Fixed Issues (moved out of Skipped Issues) and the Review round 2 section below.

**Where the work and verification ran:** in the main checkout, on branch
`feat/phase-02-gap-closure`, as instructed. No worktree was created.

**How each fix was tested:**
- `bash tests/test-lint.sh` was green after every commit (`PASS 1479 FAIL 0`
  by the end, up from `PASS 1470 FAIL 0` before this round -- the review's
  own reproductions became fixtures).
- `bash tests/run.sh` was green after every commit (`TOTAL: 6 files,
  0 failed`).
- After CR-01 and CR-03, a fresh `init.py --language en` and `--language fr`
  scaffold was linted directly (not through a fixture) and stayed
  `0 error(s), 0 warning(s)`, confirming neither fix regresses the ordinary
  scaffold path.
- CR-01's and CR-03's review reproductions were re-run by hand against the
  fixed `scripts/lint.py` / `init.py` before being turned into fixtures, to
  confirm the fix actually closes what the review reported, not only what
  the new fixture happens to assert.

**How the commits were made:** with `git commit -F -` (a heredoc), one
commit per finding except the mechanical rename, so each message could end
with the two trailer lines the session's attribution reminder specifies.

## Fixed Issues

### CR-01: A case-variant layout folder holding a `dossier.yaml` is pruned as a sub-dossier, so its leak exits 0 (G-02-4a bypass)

**Files modified:** `scripts/lint.py`, `tests/fixtures/make-lint-fixtures.sh`, `tests/test-lint.sh`
**Commit:** cca05d2
**Status:** fixed
**Applied fix:** `walk_tree`'s layout-membership test (`in_layout`) and the
root-level sub-dossier exemption both case-fold now, against a new
`_LAYOUT_DIRS_FOLDED` set, instead of comparing case-sensitively against
`LAYOUT_DIRS`. A folder like `Outbound/` is therefore always walked, never
pruned as a D-03 sub-dossier boundary, whether or not it holds its own
`dossier.yaml`. The existing case-variant E1 loop (untouched) then reports
it exactly as it already reports `Outbound/` without a `dossier.yaml`.
**Fixture:** `case-outbound-config` -- `Outbound/` with a leak under
`Outbound/mails/` *and* its own `Outbound/dossier.yaml` copy -- asserting
`Outbound:0: ERROR [E1]` and exit 1, plus a check that every existing clean
fixture and both fresh scaffolds are unaffected.

### CR-03: `init.py` maps every Cf character to a space, so the init round trip loses the deletion reading and a name holding `&`/`+` is never matched

**Files modified:** `skills/dossier-init/scripts/init.py`, `tests/fixtures/make-lint-fixtures.sh`, `tests/test-lint.sh`
**Commit:** a777086
**Status:** fixed: applies the review's option A, a reversible arbitrage (see Decisions below)
**Applied fix:** a new `_confidential_yaml_entries(name)` computes both the
space reading and the deletion reading of a name's Unicode format
characters (via a shared `_fold_format_chars(value, delete=...)` extracted
out of `yaml_quote()`), and returns both as separate quoted list entries
whenever they still differ once each side's whitespace is collapsed the
same way -- one entry otherwise, byte-identical to what `yaml_quote()`
already produced. `render_dossier_yaml()` calls it for `confidential_names`
only; every other scalar field is untouched and keeps the single space
reading. `yaml_quote()`'s docstring, which claimed the folded lint pass
alone covers the deletion reading, is corrected: that is only true for
names `_TEXT_FOLDABLE_RE` accepts, never for one holding `&`, `+`, or
similar punctuation next to the format character.
**Fixture:** `format-name-init` gains two names, `Pro<SHY>cter & Gamble`
and `AT<SHY>&T`, found in a mail body via their deletion reading (the only
reading they can ever match on, since `&` defeats the folded pass). The
existing `Glo<SHY>bex` case, which used to pin the single lossy `"Glo bex"`
line, now pins both `"Glo bex"` and `"Globex"` -- the new, correct output.
The round trip's expected finding count moved from 10 to 14: five original
names still give one filename + one body finding each, except
`Glo<SHY>bex`, which fires twice on the filename and twice on the body line
(both readings independently match the plain "Globex" text/slug, since
deleting and spacing a soft hyphen strictly inside one contiguous word
produce two different, both-matching spellings), plus the two new names'
body findings.

### WR-02: The G-02-4e unreadable-folder assertions skip silently under root, so CI coverage disappears without a failure

**Files modified:** `tests/lib.sh`, `tests/test-lint.sh`
**Commit:** 66f9464
**Status:** fixed
**Applied fix:** a small shared `skip()` helper in `tests/lib.sh` prints
`SKIP: ...` to stdout (not stderr) and counts it in a new `TESTS_SKIPPED`,
kept fully separate from `TESTS_PASSED`/`TESTS_FAILED`. `finish()` names the
skip count in its summary line only when at least one occurred, so every
other test file's output is byte-identical to before. The two
`unreadable-outbound`/`unreadable-knowledge` sites in `tests/test-lint.sh`
call `skip()` instead of echoing to stderr directly. `tests/run.sh`'s
pass/fail decision is untouched -- it still only reads the exit code.

### IN-01: Dead condition in the nested near-miss branch

**File modified:** `scripts/lint.py`
**Commit:** 9019a26
**Status:** fixed
**Applied fix:** `elif key not in GATE_KEYS:` replaced with a plain
`else:`, exactly the review's suggested fix. No behaviour change --
verified by the full `tests/test-lint.sh` suite staying green, including
every gate/near-miss fixture. CR-02's frozen presence rule in the same
function (the `if near is not None and near not in raw:` branch a few lines
below) was not touched.

### CR-02: The presence rule silently ignores a misspelt `confidential_names` that carries the names (regression against 8c2ed0f)

**Files modified:** `scripts/lint.py`, `tests/fixtures/make-lint-fixtures.sh`, `tests/test-lint.sh`
**Commit:** b51b670
**Status:** fixed (commit) -- option (a), arbitrage Samuel, relayed by the main session via
SendMessage, 2026-09-25
**Applied fix:** the presence exemption stays unconditional for `consent_recorded`/
`consent_source` near-misses (a legitimate extension key such as `consent_scope` beside
`consent_source` stays a different, known key, per D-22's original intent) but is now
overridden for a `confidential_names` near-miss that scores as a probable typo: a new
`_osa_distance()` (Optimal String Alignment -- Levenshtein plus one adjacent-transposition edit)
and `_forces_c1_despite_presence()` helper, applied identically at both call sites in
`_misplaced_gate_keys()` (the top-level loop and `visit()`'s nested branch). Plain Levenshtein
was tried first and rejected: it cannot separate a typo (`confidentail_names`) from a genuinely
different key (`confidential_notes`) sitting beside the exact one, since both land at edit
distance 2. OSA scores the transposition in `confidentail_names` as one edit, not two, dropping
it to distance 1 while `confidential_notes` (two straight substitutions) stays at distance 2.
`CONFIDENTIAL_NAMES_TYPO_CUTOFF = 1` is the resulting threshold. Full rationale and the
DP-verification of the Levenshtein/OSA distinction: `02-CONTEXT.md` § Gap closure decisions
(2026-09-25).
**Fixture:** `gate-key-beside-names-drop` (`confidential_name`, missing the trailing `s`) and
`gate-key-beside-names-swap` (`confidentail_names`, the "ia"/"ai" transposition) -- both beside
`confidential_names: []` -- assert `[C1]` with the "looks like a misspelling of
confidential_names" message and exit 1. The existing `gate-key-extras` fixture (its top-level
and counterpart-level `confidential_notes`, at OSA distance 2) needed no change and keeps
asserting 0 findings / exit 0.

### CR-02 bis: `CONFIDENTIAL_NAMES_TYPO_CUTOFF <= 1` still let a DOUBLE typo of `confidential_names` through unflagged beside the exact key

**Files modified:** `scripts/lint.py`, `tests/fixtures/make-lint-fixtures.sh`, `tests/test-lint.sh`
**Commit:** c1ed6bb
**Status:** fixed (commit) -- option (2), arbitrage Samuel, relayed by the main session via
SendMessage, 2026-09-25
**Applied fix:** `_forces_c1_despite_presence()` gained a second clause. A `confidential_names`
near-miss also forces C1 when its whole-key OSA distance is `<= CONFIDENTIAL_NAMES_TYPO_CUTOFF_
WORD` (2) AND its last `_`-separated word is within `CONFIDENTIAL_NAMES_WORD_CUTOFF` (1) OSA
edits of `"name"` **or** `"names"` -- checking both words, not `"names"` alone, because
`confidential_nam`'s last word `nam` is OSA distance 2 from `"names"` but only 1 from `"name"`;
`"names"` alone would have missed it. `confidential_name` and `confidential_nam` were previously
missed because their whole-key OSA distance (2) is the same as the legitimate
`confidential_notes` extension key's -- the two are told apart only by looking at the last word.
Full rationale, the ground-truth table, and the residual limit (a double typo landing inside the
last word itself is only caught when it happens to stay within the cutoff): `02-CONTEXT.md` §
Gap closure decisions, round 3 -- CR-02 bis (2026-09-25).
**Fixture:** `gate-key-beside-names-double` (`confidental_name`), `gate-key-beside-names-double2`
(`confidential_nam`) and `gate-key-beside-names-nounderscore` (`confidentialnames`, already
covered by the plain single-keystroke clause) -- each beside `confidential_names: []` -- assert
`[C1]` with the "looks like a misspelling of confidential_names" message and exit 1. The existing
`gate-key-extras` fixture keeps pinning `confidential_notes` beside the exact key at 0 findings /
exit 0, unmodified; `02-CONTEXT.md` notes it rather than duplicating a fixture for it.

### IN-02: `LOCKED_DIRS` relies on unquoted word splitting

**File modified:** `tests/test-lint.sh`
**Commit:** 9b6cf7d
**Status:** fixed
**Applied fix:** `LOCKED_DIRS` is now newline-separated instead of
space-separated. A new `unlock_locked_dirs()` function reads it back with
`while IFS= read -r _d`, one path per line, and the EXIT trap calls that
function instead of inlining an unquoted `for _d in $LOCKED_DIRS` loop.
Chosen over a bash array (the review's alternative) because this script
targets bash 3.2 and `"${LOCKED_DIRS[@]}"` on an empty array under `set -u`
is unbound-variable-fatal on bash < 4.4; the newline/`read -r` form has no
such edge case.

## Skipped Issues

### WR-01: `format_readings` covers category Cf only, so other invisible default-ignorable characters still hide a name

**Status:** deferred, tracked debt
**Why:** not named in the mandate's "À CORRIGER" list; the mandate's file
scope for this round is limited to `walk_tree`/layout membership (IN-01
only), `init.py`, `make-lint-fixtures.sh`, `test-lint.sh`, and this report.
Widening `format_readings`'/`yaml_quote()`'s Cf-only predicate to the full
Default_Ignorable_Code_Point set (CGJ, variation selectors, Mongolian free
variation selectors, the Hangul fillers) is a real, reproducible gap the
review demonstrated, but it touches `scripts/lint.py`'s `format_readings()`
and `_is_invisible()`-shaped logic beyond the CR-01/CR-03 lines this round
is scoped to, and it was not flagged as frozen or in-scope either --
raising it here for the next planning pass rather than folding it in
silently.

## Decisions

- **D-FIX-13** (CR-03, reversible): for `confidential_names` only,
  `init.py` now emits both the space and the deletion reading of a Unicode
  format character as separate list entries when they differ after
  whitespace normalisation, applying option A of the review's two
  proposals. Reverting to the single space reading is the inverse edit to
  `_confidential_yaml_entries()`/its call site in `render_dossier_yaml()`
  alone -- no other file depends on the two-entry shape.
- **CR-02 (option (a), arbitrage Samuel, relayed by the main session via SendMessage,
  2026-09-25):** the presence exemption now has one carve-out, not two competing rules --
  `confidential_names` near-misses are judged on OSA distance (typo vs. legitimate different
  key), `consent_recorded`/`consent_source` near-misses keep the original unconditional
  exemption. See `02-CONTEXT.md` § Gap closure decisions (2026-09-25) for the full rationale,
  including why plain Levenshtein was rejected in favour of OSA distance.
- **CR-02 bis (option (2), arbitrage Samuel, relayed by the main session via SendMessage,
  2026-09-25):** replaces the literal wording of CR-02's first answer, which rested on a wrong
  distance measurement. The carve-out gains a second, looser clause scoped to the near-miss's
  last `_`-separated word (checked against both `"name"` and `"names"`), so a double typo that
  still obviously says "the names" (`confidental_name`, `confidential_nam`) stays C1 beside the
  exact key, while a genuinely different word (`confidential_notes`'s `"notes"`) keeps the
  exemption. See `02-CONTEXT.md` § Gap closure decisions, round 3 -- CR-02 bis (2026-09-25) for
  the full rationale, the ground-truth table, and the documented residual limit.

## Follow-up

- WR-01 (the wider Default_Ignorable_Code_Point set) is open debt for the
  next planning pass on this phase or a follow-up gap-closure round.

## Review round 2 (vf-reviewer, HEAD 0bd363a)

- **Verdict:** passed.
- `git fsck --full --strict`: clean.
- Range `8c2ed0f..0bd363a`: linear, 20 commits, every commit's trailers exact
  (`Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` /
  `Claude-Session: https://claude.ai/code/session_01GWGsAe34jLEPP8p4e45qD9`), no `.gsd/` path
  committed anywhere in the range.
- Lint assertions: 1479 PASS.
- **Observation OBS-01** (minor, no-op): no runtime rejection of a `confidential_name` starting
  with `>` -- same class as WR-04, already accepted. No action taken this round; tracked as open
  debt alongside WR-01.

---

_Fixed: 2026-09-25T14:10:16Z_
_Fixer: Claude (vf-coder, targeted correction mandate)_
_CR-02 closed: 2026-09-25, targeted correction mandate (fix-cr02)_
_CR-02 bis closed: 2026-09-25, targeted correction mandate (fix-cr02-bis)_
