---
phase: 02-linter-test-harness
verified: 2026-09-25T00:00:00Z
status: human_needed
score: 13/13 must-haves verified (re-verification round: 4 ROADMAP criteria + 2 carried Phase 1
  debts + 7 UAT gap-closure truths, all independently re-checked against df7f9ea; see
  "Re-verification 2026-09-25 (gap closure)" below)
covered_files: [".planning/REQUIREMENTS.md", ".planning/WINDOWS.md", ".planning/phases/02-linter-test-harness/02-01-PLAN.md", ".planning/phases/02-linter-test-harness/02-01-SUMMARY.md", ".planning/phases/02-linter-test-harness/02-02-PLAN.md", ".planning/phases/02-linter-test-harness/02-02-SUMMARY.md", ".planning/phases/02-linter-test-harness/02-03-PLAN.md", ".planning/phases/02-linter-test-harness/02-03-SUMMARY.md", ".planning/phases/02-linter-test-harness/02-04-PLAN.md", ".planning/phases/02-linter-test-harness/02-04-SUMMARY.md", ".planning/phases/02-linter-test-harness/02-05-PLAN.md", ".planning/phases/02-linter-test-harness/02-05-SUMMARY.md", ".planning/phases/02-linter-test-harness/02-06-PLAN.md", ".planning/phases/02-linter-test-harness/02-06-SUMMARY.md", ".planning/phases/02-linter-test-harness/02-07-PLAN.md", ".planning/phases/02-linter-test-harness/02-07-SUMMARY.md", ".planning/phases/02-linter-test-harness/02-08-PLAN.md", ".planning/phases/02-linter-test-harness/02-08-SUMMARY.md", ".planning/phases/02-linter-test-harness/02-09-PLAN.md", ".planning/phases/02-linter-test-harness/02-09-SUMMARY.md", ".planning/phases/02-linter-test-harness/02-CONTEXT.md", ".planning/phases/02-linter-test-harness/02-REVIEW-FIX.iter1.md", ".planning/phases/02-linter-test-harness/02-REVIEW-FIX.iter2.md", ".planning/phases/02-linter-test-harness/02-REVIEW-FIX.md", ".planning/phases/02-linter-test-harness/02-REVIEW.iter3.md", ".planning/phases/02-linter-test-harness/02-REVIEW.md", ".planning/phases/02-linter-test-harness/02-UAT.md", "CLAUDE.md", "scripts/lint.py", "skills/dossier-init/scripts/init.py", "tests/fixtures/make-adopt-fixture.sh", "tests/fixtures/make-lint-fixtures.sh", "tests/lib.sh", "tests/run.sh", "tests/test-init-adopt.sh", "tests/test-init-empty.sh", "tests/test-init-fr.sh", "tests/test-init-pointer.sh", "tests/test-lint.sh", "tests/test-skill-shape.sh"]
covered_digest: "v1:sha256:a8986a2adf6e854052c810442ab933c8cd6817a7569b94a9345f1a04be9da7a0"
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: human_needed
  previous_score: 4/4 must-haves verified
  gaps_closed:
    - "G-02-2 — near-miss confidential_names gate key beside the exact key: re-scoped by Samuel's CR-02 / CR-02 bis arbitrage (OSA-distance dual-clause rule) rather than the original UAT wording; the new rule's ground-truth boundary independently reproduced (confidental_name, confidential_nam, confidentail_names, confidentialnames -> C1/exit 1 beside the exact key; confidential_notes, non_confidential_names -> clean/exit 0)"
    - "G-02-4a — case-variant outbound folder (Outbound/) on this case-insensitive filesystem: ERROR [E1], exit 1, name never escapes"
    - "G-02-4b — Unicode Cf format characters (ZWSP, BOM, soft hyphen, ZWNJ, word joiner) inside a confidential name in an outbound body: all 5 independently reproduced as ERROR [E5]"
    - "G-02-4c — HTML character references (&amp;, &#39;, &eacute;, decimal refs) in an outbound .html file: independently reproduced as ERROR [E5] for AT&T, O'Brien, Société Exemple"
    - "G-02-4d — gate_damaged / nested-key recursion pinned by tests: independently re-ran both WR-02 mutations (forcing gate_damaged to False, dropping visit() recursion) against the current scripts/lint.py and confirmed each is killed (4 and 2 test failures respectively), then confirmed the unmutated suite is clean again"
    - "G-02-4e — unreadable folder / .git under outbound/: independently reproduced ERROR [E1] for both a chmod-000 folder and a .git folder under outbound/mails/, and confirmed the same conditions outside outbound/ (sources/, knowledge/) downgrade to an info: line with exit 0, and a root .git stays silently pruned"
    - "G-02-4f — confidential name hard-wrapped inside a quoted mail reply (nested \"> > \" and bare \">\" prefixes): independently reproduced ERROR [E5] at the name's own line"
  gaps_remaining: []
  regressions: []
human_verification:
  - test: "Live re-test of UAT test 2 (G-02-2) against the current code: exercise the CR-02 bis OSA-distance dual-clause rule (CONFIDENTIAL_NAMES_TYPO_CUTOFF=1, CONFIDENTIAL_NAMES_TYPO_CUTOFF_WORD=2, CONFIDENTIAL_NAMES_WORD_CUTOFF=1) on a few of Samuel's own real dossier.yaml-shaped inputs, not just the fixture set and the arbitrage relayed over SendMessage."
    expected: "Samuel confirms the boundary (confidental_name / confidential_nam / confidentail_names / confidentialnames forced to C1 beside the exact key; confidential_notes / non_confidential_names left silent) matches intent on real content, and explicitly accepts the documented residual limit (a double typo landing inside the last word itself, beyond CONFIDENTIAL_NAMES_WORD_CUTOFF of both \"name\" and \"names\", still reads as a different legitimate key and stays silent — see 02-CONTEXT.md's \"Gap closure decisions, round 3\" and 02-REVIEW-FIX.md's CR-02 bis entry)."
    why_human: "This is a security/precision policy tradeoff (which typos of a confidentiality-gate key get caught vs. which legitimate extension keys stay silent), arbitraged by Samuel via a relayed SendMessage exchange rather than a hands-on session against the running linter. The task brief is explicit that Samuel's own re-test of UAT items 2 and 4 is required and does not belong to this verifier."
  - test: "Live re-test of UAT test 4 (G-02-4a..f) against the current code: drive scripts/lint.py by hand against a real Outbound/ folder, a name pasted with an invisible Unicode character, an outbound .html file with entity-encoded names, and a quoted mail reply, rather than only trusting the fixtures and this verifier's own scripted reproductions above."
    expected: "Samuel confirms each of the six fixes (case-variant folders, Cf format characters, HTML entities, gate_damaged/nested-key mutation coverage, unreadable-folder/.git reporting, quoted-reply wrapping) behaves as expected on content shaped like a real dossier, and that no fix introduces an unwanted false positive on legitimate content."
    why_human: "Same class as UAT test 2: these were reported and closed as a batch (\"tout\") without Samuel re-running the fixed linter by hand yet. Mechanically correct and covered by fixtures/mutation testing (see gaps_closed above), but the acceptance itself is Samuel's, not a mechanical fact."
  - test: "Confirm the three items of accepted, tracked debt should stay open debt rather than block or require a further fix round: WR-01 (format_readings()/yaml_quote() cover Unicode category Cf only, not the wider Default_Ignorable_Code_Point set — CGJ, variation selectors, Mongolian free variation selectors, Hangul fillers); OBS-01 (no runtime rejection of a confidential_names entry starting with '>', same class as the now-fixed WR-04); and CR-02 bis's own documented residual limit (a double typo landing inside the last word itself, beyond the word-cutoff, stays silent beside the exact key)."
    expected: "Samuel accepts these three as tracked debt for a future round (as 02-REVIEW-FIX.md's Follow-up section and 02-CONTEXT.md's CR-02 bis entry already frame them), or orders a further fix round."
    why_human: "Explicitly named as open, self-flagged debt by the executor/reviewer rather than settled gaps — a scope decision, not a defect this verifier can resolve by inspection."
---

# Phase 2: Linter & Test Harness Verification Report

**Phase Goal:** Anyone (human or agent) can mechanically verify a dossier obeys the plugin's
rules with zero setup beyond python3.
**Current status:** human_needed (unchanged across both rounds — see "Re-verification
2026-09-25 (gap closure)" below for what changed and what remains for Samuel).

---

## Initial Verification — 2026-09-24T21:30:00Z

*(Preserved verbatim from the original verification pass. Superseded in points 5 and 6 of its
own Human Verification list — items 1 and 3 there correspond to UAT tests 1 and 3, which
Samuel passed; item 2 corresponds to UAT test 2, on which Samuel reported "corrige" and which
this round's gap closure addresses — see the new section below.)*

**Verified:** 2026-09-24T21:30:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

### Goal Achievement

### Observable Truths

| # | Truth (ROADMAP Phase 2 success criteria) | Status | Evidence |
|---|---|---|---|
| 1 | Running `scripts/lint.py` against a clean fixture dossier exits 0 | ✓ VERIFIED | Fresh `python3 skills/dossier-init/scripts/init.py --language en --target $TMPD/clean` piped into `python3 scripts/lint.py $TMPD/clean` printed `0 error(s), 0 warning(s)` and exited 0 (run directly by this verifier, not taken from SUMMARY). Also asserted as three committed cases in `tests/test-lint.sh` (`scaffold_lints_clean` for `en`, `fr`, and a fully-flagged scaffold). |
| 2 | Running it against error fixtures exits 1 and names the violation, for each of the nine error classes (missing status header, `sent` w/o date/sender, non-absolute `Deadline:`, malformed outbound filename, leaked confidential name, `consent_recorded: true` with empty `consent_source`, missing `Last updated:`, nested `.claude/`, rendered deliverable w/o source) | ✓ VERIFIED | `scripts/lint.py` implements `check_outbound_headers` (E1/E2/E3), `check_outbound_names` (E4), `check_confidential_names` (E5), `check_consent_source` (E6), `check_living_files` (E7), `check_claude_dirs` (E8), `check_renders` (E9). `tests/test-lint.sh`'s nine-class sweep (`SWEEP='e1:E1 e2:E2 ... e9:E9'`) asserts each fixture exits 1, fires only its own identifier, and reports at the correct location (D-07..D-15). Confirmed by running `bash tests/test-lint.sh` directly: `PASS 1290 FAIL 0`. |
| 3 | French-language fixture flags relative-date words and unsourced bullet lines as warnings (exit 0), and still finds the English `Last updated:` label | ✓ VERIFIED | Ran `python3 scripts/lint.py tests/fixtures/lint/fr` directly: output is 7 `WARNING [W1]`/`[W2]` lines (relative-date words `demain`, `la semaine prochaine`, `aujourd'hui`, `récemment`; unsourced bullets), `0 error(s), 7 warning(s)`, exit 0. No `[E7]` (missing `Last updated:`) fired, confirming the English label is found in French-content files. |
| 4 | A bash test runner in `tests/` runs every fixture and asserts `lint.py`'s exit codes and messages, and passes end to end | ✓ VERIFIED | `bash tests/run.sh` run directly by this verifier: `ok tests/test-init-adopt.sh`, `ok tests/test-init-empty.sh`, `ok tests/test-init-fr.sh`, `ok tests/test-init-pointer.sh`, `ok tests/test-lint.sh`, `ok tests/test-skill-shape.sh`, `TOTAL: 6 files, 0 failed`. No framework beyond bash/python3 (`#!/usr/bin/env bash` shebangs only, no `jq`/`node`/`perl` calls in `tests/`). |
| 5 (carried Phase 1 debt a) | YAML 1.1 reserved spellings (`no`, `yes`, `true`, ...) fed to `--language` are written quoted by `init.py`, and read back by `lint.py` as the literal string | ✓ VERIFIED | `skills/dossier-init/scripts/init.py` has `_YAML_RESERVED_SCALARS` (frozenset of `y n yes no on off true false null ~`) and `emit_scalar` quotes any value whose `.casefold()` is in that set. `scripts/lint.py`'s config schema reads the `language` field "verbatim ... `no` stays `\"no\"`" (line 707). `tests/test-lint.sh`'s round-trip case (from 02-06) scaffolds `--language no`, lints, and asserts a clean run with `info: language 'no' ...`, plus an unreserved `it` control. Verified passing inside the full `1290/1290` run above. |
| 6 (carried Phase 1 debt b) | `_SAFE_PLAIN_SCALAR_RE` anchors with `fullmatch` (not `match`), so a value ending in a newline is quoted/stripped rather than leaving a blank line | ✓ VERIFIED | `skills/dossier-init/scripts/init.py` line 254: `_SAFE_PLAIN_SCALAR_RE.fullmatch(value) is not None`. `tests/test-init-empty.sh` case d15 (trailing-newline payload built via sentinel to survive command substitution) is part of the green 6/6 suite run. |

**Score:** 4/4 ROADMAP success criteria verified (criteria 1–4), plus both carried-over Phase 1
debts (a) and (b) independently confirmed resolved in both producer (`init.py`) and consumer
(`lint.py`) code.

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `scripts/lint.py` | Python 3 stdlib-only linter implementing all 8(→9) mechanical checks + 2 warning classes | ✓ VERIFIED | 1728 lines; `CHECKS` tuple wires all 9 error-producing functions (E1–E9) plus C0/C1 config gate and W1/W2 warning functions; no non-stdlib imports found (`import` lines are `argparse, os, re, sys, json, unicodedata, difflib, ...` — verified by grep, all stdlib). |
| `skills/dossier-init/scripts/init.py` | Producer, hardened per Phase 1 debts (a)/(b) | ✓ VERIFIED | `_YAML_RESERVED_SCALARS`, `.fullmatch` confirmed present (see truths 5–6 above). |
| `tests/run.sh`, `tests/lib.sh`, `tests/test-lint.sh` | Bash test runner + harness + lint-specific assertions | ✓ VERIFIED | Ran directly: `bash tests/run.sh` → 6/6 files pass; `bash tests/test-lint.sh` → 1290/1290 assertions pass. |
| `tests/fixtures/make-lint-fixtures.sh` | Generates clean + nine error fixtures from a real `init.py` scaffold at test time | ✓ VERIFIED | Script reads `$1` (a clean tree from a real `init.py` run), never hand-writes the clean fixture, emits one throwaway subdir per case (`e1`..`e9`, `c0-*`, `c1-*`, `gate-*`, `symlink-*`, etc.). Confirmed by reading the script and by the sweep passing in `test-lint.sh`. |
| `tests/fixtures/lint/fr/` | Committed French-language fixture exercising W1/W2 and the English `Last updated:` label | ✓ VERIFIED | Directory exists with `dossier.yaml`, all 7 living files under `dossier/`, `knowledge/`, `outbound/`, `sources/` folders with `.gitkeep`; linted directly with expected W1/W2-only, exit-0 result (truth 3 above). |
| `CLAUDE.md` Commands section | Documents `python3 scripts/lint.py [PATH]` and `bash tests/run.sh` | ✓ VERIFIED | Lines 105/110/111 contain the documented invocations and exit-code notes. |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `skills/dossier-init/scripts/init.py` | `scripts/lint.py` | producer/consumer agreement on YAML reserved spellings (`language`) | ✓ WIRED | Confirmed end-to-end via the round-trip test and by reading both sides' code (see truth 5). |
| `CLAUDE.md` | `scripts/lint.py` | documented invocation | ✓ WIRED | `python3 scripts/lint.py [PATH]` literal string present in CLAUDE.md. |
| `tests/run.sh` | `tests/test-*.sh` | dispatcher globs and runs every test file, no per-file registration needed | ✓ WIRED | Confirmed by reading `tests/run.sh` (`for f in "$DIR"/test-*.sh`) and observing all 6 current test files execute. |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Clean scaffold lints 0/0, exit 0 | `init.py --language en --target $TMPD` then `lint.py $TMPD` | `0 error(s), 0 warning(s)`, exit 0 | ✓ PASS |
| French fixture warns only, exit 0, finds `Last updated:` | `lint.py tests/fixtures/lint/fr` | 7 warnings (`W1`/`W2`), 0 errors, exit 0, no `E7` | ✓ PASS |
| Full bash suite | `bash tests/run.sh` | `TOTAL: 6 files, 0 failed` | ✓ PASS |
| Lint-specific assertion count | `bash tests/test-lint.sh` | `PASS 1290 FAIL 0` | ✓ PASS |
| No debt markers in core files | `grep -rnE "TBD|FIXME|XXX|TODO|HACK|PLACEHOLDER" scripts/lint.py skills/dossier-init/scripts/init.py tests/*.sh` | Only hits are `PLACEHOLDER.md` filenames written by `make-adopt-fixture.sh` (a Phase 1 fixture-file naming convention, not a debt marker) | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan(s) | Description | Status | Evidence |
|---|---|---|---|---|
| LINT-01 | 02-01, 02-02, 02-03, 02-04, 02-05, 02-06 | `scripts/lint.py` implements all mechanical checks, exits 1 on error / 0 on warnings-only, ignores `.gitkeep` | ✓ SATISFIED | All 9 error + 2 warning checks present and independently exercised; `.gitkeep` dropped from the walk (line 102, 1017, 1132 in lint.py); REQUIREMENTS.md marks it Complete. |
| LINT-02 | 02-01, 02-02, 02-04, 02-05 | Fixture repositories: clean baseline, French-language fixture, error fixtures covering every class | ✓ SATISFIED | `make-lint-fixtures.sh` generates clean + e1..e9 + gate/symlink fixtures from a real `init.py` run; `tests/fixtures/lint/fr/` committed; REQUIREMENTS.md marks it Complete. |
| LINT-03 | 02-01 through 02-06 | Bash test runner asserting exit codes/messages, no framework beyond bash+python3 | ✓ SATISFIED | `tests/run.sh` + `tests/test-lint.sh`, 1290 assertions, 0 non-bash/python3 dependencies found; REQUIREMENTS.md marks it Complete. |

No orphaned requirements: REQUIREMENTS.md's Phase 2 row (LINT-01/02/03) matches exactly what all
six 02-0N-PLAN.md files declare in their `requirements:` frontmatter.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---|---|---|---|
| — | — | None found in `scripts/lint.py`, `skills/dossier-init/scripts/init.py`, or `tests/*.sh` | — | Clean |

### Open Item Outside This Phase's Blocking Scope

`.planning/WINDOWS.md` row 4 (open, phase 02): `scripts/lint.py` is 1279 lines, over the
project's global 300-line file-size guard hook. This is a **deliberate, documented** deviation
(single-file layout required for a bare-skills install to copy `scripts/` wholesale and run
`lint.py` by path — DIST-03), explicitly deferred to the Phase 7 manifests/distribution
conversation per the plan's own Q-6 decision. Not a gap against this phase's goal (mechanical
verification works correctly regardless of file length); listed here for visibility only, not
as a blocking finding.

### Human Verification Required (as of 2026-09-24)

Three items, all inherited from `02-REVIEW-FIX.md`'s own "Decisions for Samuel" section, where
the executor itself marked the underlying fix `status: fixed: requires human verification`.
Behaviour is mechanically correct and covered by regression tests in every case — what needs a
human is a **policy/design judgement**, not a defect:

1. **D-FIX-8 — narrows locked decision D-22**
   **Test:** Review whether an unparseable/misindented line anywhere in `dossier.yaml`
   (including nested under `counterparts`) should hard-fail the lint run (`[C1]`, exit 1) as it
   now does, versus D-22's original "unknown or unparseable lines are skipped with a warning."
   **Expected:** Samuel confirms the narrower, fail-closed behaviour is the intended reading of
   D-22 for the confidentiality gate specifically, or requests a revert/refinement.
   **Why human:** Explicit deviation from a locked spec decision; a policy call the executor
   flagged rather than settled unilaterally.
   **Resolved 2026-09-25:** UAT test 1 — Samuel: pass.

2. **D-FIX-9 / D-FIX-10 — near-miss gate-key threshold and stricter plain-scalar rejection**
   **Test:** Review the `difflib` ratio-0.8 threshold for flagging a misspelt/misplaced gate
   key (`confidential_names` variants) as `[C1]`, and the new plain-scalar rejection rules
   (values containing `: `, or starting with `- `/`? `/`: `).
   **Expected:** Samuel agrees these thresholds avoid false positives on real dossiers, or asks
   for tuning.
   **Why human:** Explicitly flagged by the executor as "a judgement call" — not verifiable by
   inspecting code correctness alone.
   **Resolved 2026-09-25:** UAT test 2 — Samuel: issue ("corrige" — apply the WR-01 fix). This
   drove the CR-02 / CR-02 bis gap-closure work; see the new section below — a fresh human
   sign-off is requested on the replacement rule, not the original 0.8-ratio one.

3. **D-FIX-3 / WR-03 — E5 text-match broadened to ASCII-folded spellings**
   **Test:** Review the "match more" tradeoff: the confidential-name text check now also
   matches accent-dropped/punctuation-joined spellings in prose (e.g. `jane.doe` matches
   `Jane Doe`), with named false-positive risks (e.g. `Élan` matching common word "elan").
   **Expected:** Samuel accepts broader matching as the safer default for a confidentiality
   linter, or asks to narrow the separator set.
   **Why human:** Explicitly flagged by the executor as settling an open design question "on
   the match more side" — a security/precision tradeoff, not a bug.
   **Resolved 2026-09-25:** UAT test 3 — Samuel: pass.

### Gaps Summary (as of 2026-09-24)

No gaps found at the time. All 4 ROADMAP success criteria for Phase 2, both carried-over Phase
1 debts, and LINT-01/02/03 were verified directly against the codebase. Status was
`human_needed` solely for the three design judgements above. UAT (2026-09-24 to 2026-09-25)
subsequently surfaced 7 further gaps (G-02-2, G-02-4a..f) not caught by this initial pass — see
the new section below for their closure and current state.

---

## Re-verification 2026-09-25 (gap closure)

**Verified:** 2026-09-25 (session date; repository "today" is 2026-09-25 per system context)
**Branch / HEAD:** `feat/phase-02-gap-closure` @ `df7f9ea`
**Status:** human_needed (unchanged from the initial round — the reason has shifted, not
disappeared)
**Re-verification:** Yes — after gap-closure round (plans 02-07, 02-08, 02-09; review-fix
rounds CR-01, CR-02, CR-02 bis, CR-03, WR-02, IN-01, IN-02)

### What changed since 2026-09-24

Samuel's UAT (`02-UAT.md`) ran against the initial verification and reported:
- Test 1 (D-FIX-8): pass.
- Test 2 (D-FIX-9/D-FIX-10, near-miss threshold): issue — "corrige" (apply the WR-01 fix).
- Test 3 (D-FIX-3/WR-03): pass.
- Test 4 (iteration-3 residual findings CR-01/CR-02/CR-03/WR-02..04): issue — "tout" (fix all
  in the same round as WR-01).

This produced 7 gaps (G-02-2, G-02-4a, G-02-4b, G-02-4c, G-02-4d, G-02-4e, G-02-4f), closed by
plans 02-07 (near-miss gate-key rule), 02-08 (case-variant folders, unreadable/`.git`
reporting), and 02-09 (quoted replies, HTML entities, Unicode format characters), then by
review-fix rounds CR-01/CR-02/CR-02 bis/CR-03/WR-02/IN-01/IN-02 recorded in `02-REVIEW-FIX.md`.
**Important scoping note:** G-02-2's originally-reported truth ("a near-miss is ignored as soon
as the exact key is present") was explicitly superseded by Samuel's own CR-02 and CR-02 bis
arbitrage, recorded in `02-CONTEXT.md`'s two "Gap closure decisions" sections — the correct
target for re-verification is that replacement rule, not the original wording. This report
verifies against the replacement rule.

### Mechanics run fresh by this verifier (not taken from any SUMMARY.md)

| Check | Command | Result |
|---|---|---|
| Full test suite | `bash tests/run.sh` | `ok tests/test-init-adopt.sh` / `ok tests/test-init-empty.sh` / `ok tests/test-init-fr.sh` / `ok tests/test-init-pointer.sh` / `ok tests/test-lint.sh` / `ok tests/test-skill-shape.sh` — **`TOTAL: 6 files, 0 failed`, exit 0** |
| Lint-specific assertion count | `bash tests/test-lint.sh` | **`PASS 1494 FAIL 0`** (up from 1290 at the initial verification, 1479→1494 across the gap-closure and CR-02 bis commits) |
| Fresh `en` scaffold | `init.py --language en --target $TMPD/clean-en` then `lint.py $TMPD/clean-en` | `0 error(s), 0 warning(s)`, exit 0 |
| Fresh `fr` scaffold | `init.py --language fr --target $TMPD/clean-fr` then `lint.py $TMPD/clean-fr` | `0 error(s), 0 warning(s)`, exit 0 |
| Debt markers in changed files | `grep -nE "TBD\|FIXME\|XXX\|TODO\|HACK\|PLACEHOLDER" scripts/lint.py skills/dossier-init/scripts/init.py tests/lib.sh tests/test-lint.sh tests/fixtures/make-lint-fixtures.sh` | No matches |

### G-02-2 (superseded target: CR-02 bis) — independently reproduced

Built a throwaway dossier from a real `init.py` scaffold, inserted each near-miss key beside
the untouched `confidential_names: []`, and ran `scripts/lint.py` directly (not the fixture
suite) against Samuel's own ground-truth list from `02-CONTEXT.md`:

| Key beside `confidential_names: []` | Expected | Observed |
|---|---|---|
| `confidental_name` | C1, exit 1 | `dossier.yaml:6: ERROR [C1] key 'confidental_name' looks like a misspelling of confidential_names: ...`, exit 1 |
| `confidential_nam` | C1, exit 1 | Same pattern, exit 1 |
| `confidentail_names` | C1, exit 1 | Same pattern, exit 1 |
| `confidentialnames` | C1, exit 1 | Same pattern, exit 1 |
| `confidential_notes` | clean, exit 0 | No C1 finding, exit 0 |
| `non_confidential_names` | clean, exit 0 | No C1 finding, exit 0 |

All six match Samuel's arbitrage exactly. Also confirmed the C1 message no longer says "rename
the key to..." (`grep -c "rename the key\|rename it to" scripts/lint.py` → 0 matches) — the
02-07 must-have on message wording holds.

### G-02-4a — independently reproduced

Scaffolded a clean dossier, `mv`'d `outbound/` to `Outbound/`, added a leaking name under
`Outbound/mails/`. This filesystem is case-insensitive (confirmed: creating `CaseTest` and
`casetest` in the same directory collided). Result: `Outbound:0: ERROR [E1] folder is spelt
Outbound but the layout name is outbound: ...`, exit 1 — the leak never reaches exit 0. Also
confirmed the non-case-variant lookalikes `outbound-old/` and `Outbounds/` raise nothing (exit
0) on a fresh scaffold, matching the 02-08 must-have's negative case.

### G-02-4b — independently reproduced

Scaffolded with `--confidential-name Globex`, wrote one line per Cf character (U+200B ZWSP,
U+FEFF BOM, U+00AD soft hyphen, U+200C ZWNJ, U+2060 word joiner) splitting "Globex" mid-word in
an outbound mail body. All 5 lines fired `ERROR [E5] confidential name 'Globex' under
outbound/` at their own correct line number.

### G-02-4c — independently reproduced

Scaffolded with three confidential names (`AT&T`, `O'Brien`, `Société Exemple`), wrote an
outbound `.html` file with each name HTML-entity-encoded (`AT&amp;T`, `O&#39;Brien`,
`Soci&eacute;t&eacute; Exemple`). All three fired `ERROR [E5]` on the same line.

### G-02-4d — independently mutation-tested (not just re-read)

Rather than trusting that the `gate-key-beside-consent` and `gate-json-deep` fixtures exist
(confirmed present, 7 and 3 references respectively across `make-lint-fixtures.sh` /
`test-lint.sh`), this verifier reproduced both WR-02 mutations against the current
`scripts/lint.py` and reverted them:
- Forcing `config["gate_damaged"] = False` at its assignment site → `PASS 1490 FAIL 4` (the
  four failures are exactly `gate-consent-dup-rev`, `gate-json-consent-dup`,
  `gate-key-beside-consent`, `gate-skip-armed` — all expecting E5 to stay armed).
- Replacing the nested `visit(entry, where + "." + key)` recursive call with `pass` →
  `PASS 1492 FAIL 2` (`gate-json-deep`'s exit-code and C1-naming assertions).
- Both mutations reverted; `bash tests/test-lint.sh` returned to `PASS 1494 FAIL 0` afterward,
  confirming the revert left no residue.

### G-02-4e — independently reproduced

- `chmod 000` on a folder under `outbound/mails/` → `ERROR [E1] folder cannot be read: ...`,
  exit 1 (this shell is not running as root, so the permission actually blocked the walk).
- A `.git/` folder created under `outbound/mails/` → `ERROR [E1] folder is a .git folder, never
  walked: ...`, exit 1.
- The same two conditions (`chmod 000`, a `.git/` folder) placed under `sources/received/` and
  `knowledge/` instead → `info:` lines only (`info: folder sources/received/locked/ cannot be
  read: ...`, `info: folder knowledge/.git/ is a .git folder, never walked: ...`), exit 0 — the
  02-08 must-have's outbound-vs-elsewhere distinction holds exactly.
- A real `git init` at the dossier root produced no finding at all (root `.git` stays silently
  pruned, as required so ordinary git-tracked dossiers are unaffected).

### G-02-4f — independently reproduced

Wrote an outbound mail reply with a nested `> > ` prefix, a mid-word wrap crossing a `> `
prefix, and a bare `>` (no space) continuation, all wrapping the confidential name `Jane Doe`
across lines. Result: `ERROR [E5] confidential name 'Jane Doe' under outbound/` fired at the
line where the name's first token appears, exit 1.

### 02-09 producer-side truth — independently reproduced

`skills/dossier-init/scripts/init.py`'s `yaml_quote("Glo<U+200B>bex")` (imported and called
directly, not via a fixture) returns `'"Glo bex"'` — the Cf character is written as a literal
space, confirming the must-have "init.py writes every format character of a quoted field as a
space."

### Known accepted debt (listed, not counted as a gap)

Per the task brief, these three items are **tracked debt**, explicitly self-flagged by the
executor/reviewer as out of this round's scope, not silent gaps:

1. **WR-01 residual** — `format_readings()`/`yaml_quote()` cover Unicode category **Cf** only.
   The wider `Default_Ignorable_Code_Point` set (Combining Grapheme Joiner, variation
   selectors, Mongolian free variation selectors, Hangul fillers) can still hide a name.
   Documented in `02-REVIEW-FIX.md`'s "Follow-up" section as open debt for the next planning
   pass.
2. **OBS-01** — no runtime rejection of a `confidential_names` entry starting with `>` (same
   class as the now-fixed WR-04, the quoted-reply case). Documented in `02-REVIEW-FIX.md`'s
   "Review round 2" section as a no-op observation, tracked alongside WR-01.
3. **CR-02 bis's documented residual limit** — a double typo landing *inside* the last word
   itself (beyond `CONFIDENTIAL_NAMES_WORD_CUTOFF` of both `"name"` and `"names"`) is, by
   design, still read as a legitimate different key and stays silent beside the exact
   `confidential_names` key. Documented in `02-CONTEXT.md`'s "Gap closure decisions, round 3"
   section as a deliberate, reversible boundary, not an oversight.

None of these three block the phase goal; all are visible, cross-referenced, and reversible per
their own documentation.

### Requirements / Artifacts / Key Links (re-check)

No change to the Phase 2 requirement set (LINT-01/02/03) or to the artifacts/key-links table of
the initial verification — `scripts/lint.py`, `skills/dossier-init/scripts/init.py`,
`tests/run.sh`/`tests/test-lint.sh` all still exist, are still substantive, and are still
wired exactly as described above; the gap-closure round only changed their internal contents.
The 02-07/02-08/02-09 `must_haves.artifacts` patterns (`"looks like a misspelling of"`,
`gate-key-beside-consent`, `gate-json-deep`, `onerror`, `case-outbound`, `unreadable-outbound`,
`html.unescape`, `unicodedata`, `e5-html-entities`, `format-body`) were each grepped directly
and found present in their declared files.

### Anti-Patterns Found (re-check)

None. `grep -nE "TBD|FIXME|XXX|TODO|HACK|PLACEHOLDER"` across every file touched by this
gap-closure round (`scripts/lint.py`, `skills/dossier-init/scripts/init.py`, `tests/lib.sh`,
`tests/test-lint.sh`, `tests/fixtures/make-lint-fixtures.sh`) returns no matches.

### Gaps Summary (re-verification)

All 7 gaps from `02-UAT.md` are independently confirmed closed against the current codebase
(`df7f9ea`), using reproductions built by this verifier rather than the fixture suite alone, and
including a live mutation-and-revert of the two WR-02 test-coverage mutations. `bash
tests/run.sh` and `bash tests/test-lint.sh` are green (`TOTAL: 6 files, 0 failed`; `PASS 1494
FAIL 0`), and fresh `en`/`fr` scaffolds still lint completely clean. **No automated truth
failed** — there is no `gaps:` block in this report.

Status stays `human_needed`, per the task brief's explicit instruction, because:
- The CR-02 bis boundary (the rule that now governs G-02-2) is a security/precision policy
  tradeoff Samuel arbitraged by a relayed message exchange, not by driving the fixed linter
  himself — the same category of judgement that made the initial verification `human_needed`.
- UAT test 4's six fixes were accepted as a batch ("tout") before they existed; Samuel has not
  yet re-run his own UAT tests 2 and 4 against the code that actually implements them.
- Three items of debt (WR-01, OBS-01, CR-02 bis's residual limit) are open by design and need
  Samuel's sign-off to stay deferred rather than trigger a further fix round.

See the `human_verification` list in this report's frontmatter for the exact items Samuel needs
to check by hand.

---

_Initial verification: 2026-09-24T21:30:00Z — Claude (gsd-verifier)_
_Re-verification (gap closure): 2026-09-25 — Claude (gsd-verifier), branch
`feat/phase-02-gap-closure` @ `df7f9ea`_
