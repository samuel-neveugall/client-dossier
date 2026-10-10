---
phase: 02-linter-test-harness
verified: 2026-10-10T14:00:00Z
status: passed
score: "14/14 must-haves verified (4 ROADMAP criteria + 2 carried Phase 1 debts + 7 UAT gap-closure truths + WR-01 closure)"
covered_files: [".planning/REQUIREMENTS.md", ".planning/WINDOWS.md", ".planning/phases/02-linter-test-harness/02-01-PLAN.md", ".planning/phases/02-linter-test-harness/02-01-SUMMARY.md", ".planning/phases/02-linter-test-harness/02-02-PLAN.md", ".planning/phases/02-linter-test-harness/02-02-SUMMARY.md", ".planning/phases/02-linter-test-harness/02-03-PLAN.md", ".planning/phases/02-linter-test-harness/02-03-SUMMARY.md", ".planning/phases/02-linter-test-harness/02-04-PLAN.md", ".planning/phases/02-linter-test-harness/02-04-SUMMARY.md", ".planning/phases/02-linter-test-harness/02-05-PLAN.md", ".planning/phases/02-linter-test-harness/02-05-SUMMARY.md", ".planning/phases/02-linter-test-harness/02-06-PLAN.md", ".planning/phases/02-linter-test-harness/02-06-SUMMARY.md", ".planning/phases/02-linter-test-harness/02-07-PLAN.md", ".planning/phases/02-linter-test-harness/02-07-SUMMARY.md", ".planning/phases/02-linter-test-harness/02-08-PLAN.md", ".planning/phases/02-linter-test-harness/02-08-SUMMARY.md", ".planning/phases/02-linter-test-harness/02-09-PLAN.md", ".planning/phases/02-linter-test-harness/02-09-SUMMARY.md", ".planning/phases/02-linter-test-harness/02-CONTEXT.md", ".planning/phases/02-linter-test-harness/02-REVIEW-FIX.iter1.md", ".planning/phases/02-linter-test-harness/02-REVIEW-FIX.iter2.md", ".planning/phases/02-linter-test-harness/02-REVIEW-FIX.md", ".planning/phases/02-linter-test-harness/02-REVIEW.iter3.md", ".planning/phases/02-linter-test-harness/02-REVIEW.md", ".planning/phases/02-linter-test-harness/02-UAT.md", "CLAUDE.md", "scripts/lint.py", "skills/dossier-init/scripts/init.py", "tests/fixtures/make-adopt-fixture.sh", "tests/fixtures/make-lint-fixtures.sh", "tests/lib.sh", "tests/run.sh", "tests/test-init-adopt.sh", "tests/test-init-empty.sh", "tests/test-init-fr.sh", "tests/test-init-pointer.sh", "tests/test-lint.sh", "tests/test-skill-shape.sh"]
covered_digest: "v3:sha256:0f59d4f7c39f7acdd2316e3ae6b016e9ad81f1a580248a6d421261ea310cc27d"
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: passed
  previous_score: "13/13 truths verified on 01d1f67 (WR-01 still listed as residual tracked debt)"
  history:
    - round: "initial verification, 2026-09-24"
      status: human_needed
      score: "4/4 ROADMAP criteria + 2 carried Phase 1 debts"
      outcome: "UAT then surfaced 7 gaps (G-02-2, G-02-4a..4f) not caught by the initial pass"
    - round: "re-verification after gap closure, 2026-09-25, df7f9ea"
      status: human_needed
      score: "13/13 automated truths"
      outcome: "all 7 gaps independently reproduced as closed; waiting on a human recette of UAT items 2 and 4 and on sign-off of three tracked debts"
    - round: "re-verification after human-delegated UAT, 2026-10-10, 01d1f67"
      status: passed
      score: "13/13 truths"
      outcome: "agent-run recette (9 scenarios) green; WR-01, OBS-01 and the CR-02 bis residual left as tracked debt"
  gaps_closed:
    - "WR-01 (tracked debt, closed by ce42a6a, Samuel's choice before closing the phase): every Unicode Default_Ignorable_Code_Point, not only category Cf, is invisible to E5 and to init.py; VS16, CGJ, Hangul filler, VS17 and Mongolian FVS inside a confidential name all give E5 / exit 1"
    - "G-02-2 near-miss confidential_names gate key beside the exact key (replacement rule CR-02 bis): scenarios 1-2 of the recette re-run"
    - "G-02-4a case-variant Outbound/ folder: E1, exit 1 (recette scenario 3)"
    - "G-02-4b Unicode Cf characters in a confidential name: E5, exit 1 (recette scenario 4)"
    - "G-02-4c HTML entities in an outbound .html file: E5 x2, exit 1 (recette scenario 5)"
    - "G-02-4d gate_damaged / nested-key recursion pinned by tests: scenario 9 (C1 + E5) and PASS 1494 FAIL 0"
    - "G-02-4e unreadable folder / .git under outbound/: E1, exit 1 (recette scenarios 6 and 7)"
    - "G-02-4f name hard-wrapped across quoted '> ' lines: E5, exit 1 (recette scenario 8)"
  gaps_remaining: []
  regressions: []
  human_verification_resolved:
    - "UAT test 2 (re-test) and UAT test 4 (re-test): performed by the agent, not by Samuel. Samuel explicitly delegated the recette (2026-10-10, 'test tout toi meme, je ne teste pas moi'); recorded in 02-UAT.md tests 5 and 6 with source agent-run. This verifier re-ran the same 9 scenarios independently (see below)."
---

# Phase 2: Linter & Test Harness Verification Report

**Phase Goal:** Anyone (human or agent) can mechanically verify a dossier obeys the plugin's
rules with zero setup beyond python3.
**Verified:** 2026-10-10T14:00:00Z
**Status:** passed
**Re-verification:** Yes, after the human-delegated UAT and the WR-01 fix (fourth round: initial
2026-09-24, gap closure 2026-09-25 on `df7f9ea`, delegated UAT on `01d1f67`, this round on HEAD
`ce42a6a`)
**Branch:** `feat/phase-02-gap-closure`

**Delegated recette notice.** The two human-verification items of the previous report (live
re-test of UAT items 2 and 4) were NOT performed by Samuel by hand. Samuel delegated the whole
recette to the agent. The recette was run by the agent (recorded in `02-UAT.md`, tests 5 and 6,
`source: agent-run`) and re-run independently by this verifier, with the results below. The
status `passed` therefore rests on an agent-run recette, by Samuel's explicit choice.

## Scope of this round

Between `df7f9ea` and `01d1f67` nothing changed in `scripts skills tests`; that round (delegated
recette) is unchanged and was re-run in full. This round adds exactly one code commit, `ce42a6a`
(WR-01: every `Default_Ignorable_Code_Point`, not only category Cf, is invisible to E5 and to
`init.py`), touching `scripts/lint.py`, `skills/dossier-init/scripts/init.py`,
`tests/fixtures/make-lint-fixtures.sh` and `tests/test-lint.sh`. All four files were already in the
covered set; only the digest changes. Samuel chose to fix WR-01 before closing the phase, so it
is no longer tracked debt.

### Review of ce42a6a (read, not edited)

| Aspect | Finding |
|---|---|
| Regex set vs Unicode `DerivedCoreProperties` Default_Ignorable_Code_Point | Identical. Expanded the character class programmatically (4174 code points) and compared with the property's ranges: 00AD, 034F, 061C, 115F-1160, 17B4-17B5, 180B-180F, 200B-200F, 202A-202E, 2060-206F, 3164, FE00-FE0F, FEFF, FFA0, FFF0-FFF8, 1BCA0-1BCA3, 1D173-1D17A, E0000-E0FFF. Exactly equal (the reference list was written from memory of the Unicode data file, not read from a local copy of it). The 32 Cf code points outside the set stay covered by the `category() == "Cf"` branch of `is_invisible()`. |
| Two copies identical | `lint.py:_DEFAULT_IGNORABLE_RE.pattern == init.py:_DEFAULT_IGNORABLE_RE.pattern` is True (checked by importing both). Kept in step by hand, documented in both comments; no test asserts the equality, so a future edit of only one copy would not fail the suite (advisory). |
| Python 3.8 | No 3.8 interpreter on this machine. `ast.parse(..., feature_version=(3, 8))` accepts both files. The change uses only `re`, `unicodedata.category` and non-raw `\U` escapes in a character class, all valid since 3.3. |
| Line contract | No member of the set is `\n`, U+0085, U+2028 or U+2029 (checked programmatically), so `format_readings()` still neither adds nor removes a line break; line numbers in E5 messages are unaffected. |
| Coverage of call sites | `format_readings()` is the single choke point for body haystacks, the needle build and the filename pass (lint.py lines 1706, 1727, 1774); no direct `category(` call remains outside `is_invisible()` / `_is_invisible()`. Producer: `_fold_format_chars()` feeds both `yaml_quote()` and `_confidential_yaml_entries()`. |
| False-positive risk on FR/EN text | Negligible. A control body with `\u2764\ufe0f`, `\U0001f469\u200d\U0001f4bb` (ZWJ emoji sequence), "l'\u00e9lan" and an unrelated "Exemple de soci\u00e9t\u00e9 distincte" gives `0 error(s), 0 warning(s)`. Invisible characters are only removed or turned into a space before matching a confidential name, so the only added matches are names the author could not see. Ordinary FR/EN prose uses none of the newly added characters except emoji variation selectors. |
| Minor observations | (1) A name with an invisible character is registered in two readings (`Glo bex` and `Globex`), so one leak gives two E5 lines on the same line; pre-existing behaviour from CR-02, cosmetic. (2) The `yaml_quote` docstring still says "category Cf: ..." in places; cosmetic. (3) The set is hard-coded at today's Unicode ranges; a future Default_Ignorable assignment needs a manual update in both copies. |

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | ROADMAP SC1: `lint.py` on a clean fixture dossier exits 0 | VERIFIED | Fresh `init.py --language en` scaffold: `0 error(s), 0 warning(s)`, exit 0 (run now). |
| 2 | ROADMAP SC2: each of the nine error classes exits 1 and names the violation | VERIFIED | `bash tests/test-lint.sh`: `PASS 1551 FAIL 0`, includes the nine-class sweep; recette scenarios 3-9 additionally exit 1 with E1/E5/C1 as named. |
| 3 | ROADMAP SC3: French fixture gives warnings only (exit 0) and still finds `Last updated:` | VERIFIED | `lint.py tests/fixtures/lint/fr`: `0 error(s), 7 warning(s)` (W1/W2), exit 0, no E7. |
| 4 | ROADMAP SC4: bash runner in `tests/` runs every fixture and passes end to end | VERIFIED | `bash tests/run.sh`: 6 files `ok`, `TOTAL: 6 files, 0 failed`. |
| 5 | Phase 1 debt (a): reserved YAML spellings quoted by the producer and read back as strings | VERIFIED | `init.py --language no` writes `language: "no"`; `lint.py` on it: `info: language 'no' has no word list`, `0 error(s), 0 warning(s)`. |
| 6 | Phase 1 debt (b): plain-scalar allowlist anchored with `fullmatch` | VERIFIED | `init.py:303` `_SAFE_PLAIN_SCALAR_RE.fullmatch(value) is not None`; pinned by `tests/test-init-empty.sh` d15 (green in suite). |
| 7 | G-02-2: extension keys beside the gate keys lint clean; a typo of a gate key beside the exact key is C1 | VERIFIED | Recette 1: `consent_scope` + `confidential_notes` -> exit 0. Recette 2: `ERROR [C1] key 'confidental_names' looks like a misspelling of confidential_names`, exit 1. |
| 8 | G-02-4a: `Outbound/` case variant never escapes the outbound checks | VERIFIED | Recette 3: `ERROR [E1] folder is spelt Outbound but the layout name is outbound`, exit 1. |
| 9 | G-02-4b: Unicode format characters in a confidential name never hide it | VERIFIED | Recette 4 (ZWSP + soft hyphen in the name): `ERROR [E5]`, exit 1. |
| 10 | G-02-4c: HTML entities in an outbound .html file never hide a name | VERIFIED | Recette 5: `AT&amp;T` and `Soci&eacute;t&eacute; Exemple` -> two `ERROR [E5]`, exit 1. |
| 11 | G-02-4d: gate_damaged and nested-key recursion are pinned | VERIFIED | Recette 9: `Consent_recorded: false` beside a recorded consent gives `ERROR [C1]` AND `ERROR [E5]`. Mutation-tested in the earlier round on df7f9ea (4 and 2 test failures when mutated); ce42a6a does not touch `gate_damaged` or `visit()`; suite `PASS 1551 FAIL 0`. |
| 12 | G-02-4e: unreadable folder or `.git/` under `outbound/` is E1, not skipped | VERIFIED | Recette 6 (`outbound/mails/.git`): `ERROR [E1]`, exit 1. Recette 7 (chmod 000 folder): `ERROR [E1] folder cannot be read`, exit 1. |
| 13 | G-02-4f: name wrapped across quoted `> ` lines is found | VERIFIED | Recette 8: `ERROR [E5]` at line 9, exit 1. |
| 14 | WR-01 (closed by ce42a6a): a default-ignorable character outside Cf inside a confidential name never hides it from E5, in the body, in a hand-written config, or through the init.py round trip | VERIFIED | Probe run now, one outbound mail per character inside "Société Exemple": VS16 U+FE0F, CGJ U+034F (two positions), HANGUL CHOSEONG FILLER U+115F, VS17 U+E0100, Mongolian FVS U+180B, a pair of ZWJ between the words: each exit 1 with one `ERROR [E5]`. `init.py --confidential-name 'Glo<U+FE0F>bex'` then a body saying `Globex` gives E5 for both readings. Fixtures `ignorable-body`, `ignorable-name-yaml`, `ignorable-name-init` are asserted in `tests/test-lint.sh` (RED before the fix per the coordinator: 21 failures; green now). |

**Score:** 14/14 truths verified, 0 present-but-behavior-unverified. No truth is
coincidental-reliance: every behaviour above is exercised by an executed command or test, and
the confidential-name checks are asserted against the actual `outbound/` content, not a fixture
precondition.

### Behavioral Spot-Checks (re-run now)

| Behavior | Command | Result | Status |
|---|---|---|---|
| Delegated recette, 9 scenarios | `bash <scratchpad>/recette-02.sh /Users/samuel/Documents/dev/client-dossier` | exit codes 0,1,1,1,1,1,1,1,1 matching the "Attendu" line of every scenario | PASS |
| Full suite | `bash tests/run.sh` | `TOTAL: 6 files, 0 failed` | PASS |
| Lint assertions | `bash tests/test-lint.sh` | `PASS 1551 FAIL 0` (1494 before ce42a6a) | PASS |
| WR-01 probe | `bash <scratchpad>/probe-wr01.sh <repo>` | 7 variants, each exit 1 with one E5; false-positive control exit 0, 0 errors | PASS |
| Recette on ce42a6a | `recette-02.sh` re-run after the fix | same exit codes 0,1,1,1,1,1,1,1,1 | PASS |
| Clean EN scaffold | `init.py --language en` then `lint.py` | `0 error(s), 0 warning(s)`, exit 0 | PASS |
| French fixture | `lint.py tests/fixtures/lint/fr` | 7 warnings, 0 errors, exit 0 | PASS |
| Reserved word round trip | `init.py --language no` then `lint.py` | `language: "no"`, 0 errors | PASS |
| Diff since the delegated-recette round | `git diff --name-only 01d1f67 HEAD -- scripts skills tests` | exactly the 4 files of ce42a6a | PASS |

### Probe Execution

No probes are declared by the phase plans and none exist under `scripts/*/tests/`. Skipped.

### Required Artifacts and Key Links

Unchanged in role since the previous round (ce42a6a only changes invisible-character handling inside them): `scripts/lint.py` (stdlib-only, all of
E1-E9, C0/C1, W1/W2 wired in `CHECKS`), `skills/dossier-init/scripts/init.py` (producer
hardened), `tests/run.sh` + `tests/lib.sh` + `tests/test-lint.sh`, `tests/fixtures/make-lint-fixtures.sh`,
`tests/fixtures/lint/fr/`, `CLAUDE.md` Commands section. Key links `init.py` -> `lint.py`
(reserved-word round trip), `CLAUDE.md` -> `lint.py`, `tests/run.sh` -> `tests/test-*.sh` all
confirmed by the runs above.

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
|---|---|---|---|---|
| LINT-01 | 02-01..02-09 (all nine declare it) | `lint.py` implements the mechanical checks, exit 1 on error, 0 on warnings only | SATISFIED | Truths 1-3, 5-13; REQUIREMENTS.md `[x]` and traceability row `Complete`. |
| LINT-02 | 02-01, 02-02, 02-04..02-09 | Fixture repositories: clean, French, error fixtures per class | SATISFIED | `make-lint-fixtures.sh` + committed `fr` fixture; truths 1-3. |
| LINT-03 | 02-01..02-09 | Bash runner asserting exit codes and messages | SATISFIED | Truth 4; `PASS 1494 FAIL 0`; bash and python3 only. |

Orphaned requirements: none. REQUIREMENTS.md maps only LINT-01/02/03 to Phase 2 and every ID is
claimed by at least one PLAN `requirements:` field. (02-03 declares LINT-01, LINT-03 only; the
two carried Phase 1 debts, also tracked as ROADMAP items, are truths 5 and 6.)

### Anti-Patterns Found

`grep -nE "TBD|FIXME|XXX|TODO|HACK"` (re-run on ce42a6a) over `scripts/lint.py`, `skills/dossier-init/scripts/init.py`
and `tests/*.sh`, `tests/lib.sh`, `tests/fixtures/*.sh`: no match. None.

### Human Verification Required

None. The two items of the previous report (live re-test of UAT items 2 and 4) are discharged by
the delegated, agent-run recette (see the notice above and `02-UAT.md` tests 5 and 6).

### Tracked Debt (advisory, not a gap, not a must-have)

WR-01 is no longer debt: it is closed by `ce42a6a` (truth 14). Two residuals stay as noted,
documented, reversible debt, outside every ROADMAP criterion and must-have, so they do not change
the verdict; their acceptance remains a decision of Samuel's:

1. OBS-01: no runtime rejection of a `confidential_names` entry starting with `>`.
2. CR-02 bis residual: a double typo inside the last word itself of a gate-key misspelling,
   beside the exact key, stays silent.

Bookkeeping note: `.planning/STATE.md` (Deferred Items, "Debt (Phase 2 gap-closure review)" row)
still lists WR-01 as open debt and should be updated to "Resolved by ce42a6a".

### Deferred Items

None filtered against later phases. WINDOWS.md row 4 (`lint.py` exceeds the 300-line guard,
deliberate single-file layout for DIST-03) stays a documented, visibility-only item for
Phase 7.

### Gaps Summary

No gaps. All four ROADMAP success criteria, both carried-over Phase 1 debts, the seven
gap-closure truths and the WR-01 closure hold on HEAD `ce42a6a`; the suite (`PASS 1551 FAIL 0`,
6 files, 0 failed), the nine recette scenarios and the WR-01 probe are green when re-run by this
verifier. The ce42a6a diff review found no defect. The only reservations are procedural: the human
recette was performed by the agent by Samuel's delegation, and the two remaining tracked debts
(OBS-01, CR-02 bis residual) remain open for his explicit acceptance.

---

_Verified: 2026-10-10T14:00:00Z_
_Verifier: Claude (gsd-verifier)_
