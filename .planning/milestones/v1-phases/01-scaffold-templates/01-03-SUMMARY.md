---
phase: 01-scaffold-templates
plan: 03
subsystem: scaffold
tags: [markdown-templates, dossier-init, i18n, bash-tests]

# Dependency graph
requires:
  - phase: 01-scaffold-templates
    provides: "tests/lib.sh, tests/run.sh harness; skills/dossier-init/scripts/init.py's twelve-row TEMPLATE_MAP and resolve_template_dir() (D-09 variant resolution, unchanged by this plan); the full templates/en/ set as the structural sibling every fr/ file mirrors"
provides:
  - "The twelve French templates under skills/dossier-init/templates/fr/, same filenames as templates/en/, French titles/headings/comments/example lines, English protocol keywords"
  - "tests/test-init-fr.sh — the acceptance test for ROADMAP criterion 5 (SCAF-07), proving both halves: French content and surviving English protocol keywords"
affects: [01-04, 01-05, 01-06]

# Actuals (#2632)
actuals:
  tokens: 2678
  tasks: 3
  commits: 3
plan_head_before: c160ea5b1b6f94f43b43fc768b47d40aaca222ae

tech-stack:
  added: []
  patterns:
    - "French heading wording is sourced exclusively from 01-RESEARCH.md's already-redacted heading audit table, never from the origin repository directly (D-13) — the same discipline plan 01-02 established for the English set."
    - "Confidentiality checks that need case-insensitivity are inlined in the test body rather than adding a flag to tests/lib.sh (matching the precedent tests/test-init-empty.sh already set), since lib.sh was out of this plan's declared file scope."

key-files:
  created:
    - tests/test-init-fr.sh
    - skills/dossier-init/templates/fr/ACTORS.md
    - skills/dossier-init/templates/fr/HISTORY.md
    - skills/dossier-init/templates/fr/LEARNINGS.md
    - skills/dossier-init/templates/fr/TONE.md
    - skills/dossier-init/templates/fr/CHANNELS.md
    - skills/dossier-init/templates/fr/OPEN-QUESTIONS.md
    - skills/dossier-init/templates/fr/RELATIONSHIP.md
    - skills/dossier-init/templates/fr/CONTEXT.md
    - skills/dossier-init/templates/fr/DOCTRINE.md
    - skills/dossier-init/templates/fr/README-dossier.md
    - skills/dossier-init/templates/fr/README-sources.md
    - skills/dossier-init/templates/fr/README-outbound.md
  modified: []

key-decisions:
  - "CHANNELS.md's fifth French heading is the short `## Ce dépôt`, not a literal translation of the English sibling's longer 'This repository and its confidentiality level' — the plan's own task text specified this exact wording, so the shorter French heading is deliberate, not a fidelity gap."
  - "No init.py change was needed: resolve_template_dir() from plan 01-02 already treats any templates/<language>/ directory generically, so shipping templates/fr/ was sufficient to make `--language fr` pick it up without a code change."

patterns-established: []

requirements-completed: [SCAF-07]

coverage:
  - id: D1
    description: "`--language fr` scaffolds a dossier whose titles, headings, comments and example lines are French, while every path and every protocol keyword stays English (ROADMAP criterion 5, SCAF-07, D-09)"
    requirement: "SCAF-07"
    verification:
      - kind: integration
        ref: "tests/test-init-fr.sh (full run, 34 assertions across headings, Last updated:, status-header fields/values, path/filename checks, and the two anchored negative-translation checks)"
        status: pass
    human_judgment: false
  - id: D2
    description: "templates/fr/ carries the same twelve filenames as templates/en/, so TEMPLATE_MAP needs no per-language branch"
    requirement: "SCAF-07"
    verification:
      - kind: integration
        ref: "diff <(ls skills/dossier-init/templates/en/) <(ls skills/dossier-init/templates/fr/) — silent"
        status: pass
    human_judgment: false
  - id: D3
    description: "Every French heading is role-generic; no counterpart name, fictional or real, appears in any of the twelve templates or leaks into a scaffolded outbound/README.md"
    requirement: "SCAF-07"
    verification:
      - kind: integration
        ref: "tests/test-init-fr.sh case-insensitive 'acme' check on outbound/README.md; grep -ric -E 'acme|jane doe|big telco' over README-outbound.md and README-sources.md (both 0)"
        status: pass
    human_judgment: false

duration: ~20min
completed: 2026-09-16
status: complete
---

# Phase 1 Plan 3: The French Template Variant Summary

**Twelve French templates under `skills/dossier-init/templates/fr/` — same filenames, same section structure as `templates/en/`, French titles/headings/comments/example lines, and every protocol keyword (`Last updated:`, the six outbound status-header fields, the three status values) kept byte-identical to English — plus `tests/test-init-fr.sh`, the acceptance test for ROADMAP criterion 5.**

## Performance

- **Duration:** ~20 min
- **Tasks:** 3/3
- **Files modified:** 13 (13 created, 0 modified)

## Accomplishments
- `tests/test-init-fr.sh` written and run RED first (`bash tests/run.sh` exited 1, naming the new file, before any `fr/` template existed), then GREEN after Task 3 (`bash tests/run.sh` exits 0, `0 failed`).
- Seven French living-file templates authored, matching their English siblings' section counts exactly (ACTORS 3, HISTORY 3 `##` + 2 `###`, LEARNINGS 4, TONE 6, CHANNELS 5, OPEN-QUESTIONS 3, RELATIONSHIP 7); every example line stays inside an HTML comment (zero bare bullets outside a comment across all seven).
- Five remaining French templates authored (two knowledge stubs, three folder READMEs); `README-outbound.md` reproduces the spec §3.3 status header verbatim in English inside French prose.
- `diff <(ls templates/en/) <(ls templates/fr/)` is silent — identical twelve-filename lists, so `TEMPLATE_MAP` needed no code change to pick up the new variant (`resolve_template_dir()` from plan 01-02 already handles it generically).
- No occurrence of the confidential origin-repo path, and no counterpart name (real or the spec's fictional "Acme"/"Jane Doe"/"Big Telco") anywhere in `templates/fr/` or under a scaffolded `outbound/`.

## Task Commits

Each task was committed atomically:

1. **Task 1: The French-variant acceptance test** - `9c9a1c8` (test) — RED gate: `bash tests/run.sh` exits 1, names `test-init-fr.sh`, 10 failing assertions (PASS 30 FAIL 10).
2. **Task 2: The seven French living-file templates** - `473b8a1` (feat) — narrows the failure to the five knowledge/README targets (PASS 26 FAIL 14; the `init.py` run itself now fails with exit 1 because `DOCTRINE.md`/`CONTEXT.md` are still missing from `templates/fr/`, which is expected mid-plan).
3. **Task 3: The five French knowledge and README templates** - `9c54fa1` (feat) — GREEN gate: `bash tests/run.sh` exits 0, `0 failed`.

**Plan metadata:** (this commit, made after this file) — `docs(01-03): complete plan`

_Note: this plan is structured as its own RED→GREEN arc across three tasks, the same pattern plan 01-02 used: Task 1 is the RED commit, Task 3 is the GREEN commit. No separate REFACTOR commit was needed._

## Files Created/Modified
- `tests/test-init-fr.sh` - 34 assertions: variant selection (`templates: fr`, `language: fr`), 9 anchored French headings, 7 `Last updated:` survivals, 9 outbound status-header field/value checks, 9 English-path/filename checks, one case-insensitive confidentiality check, 2 anchored negative-translation checks (`Statut:`, `Échéance:`)
- `skills/dossier-init/templates/fr/ACTORS.md` - Acteurs: Côté donneur d'ordre / Le client final / De notre côté, with a `###` per-person placeholder
- `skills/dossier-init/templates/fr/HISTORY.md` - Historique: Chronologie, Engagements en cours (Les nôtres / Les leurs), À venir
- `skills/dossier-init/templates/fr/LEARNINGS.md` - Apprentissages: comment ils parlent et pensent, ce qu'ils attendent, ce que le dossier apprend, pièges connus
- `skills/dossier-init/templates/fr/TONE.md` - Ton: en une phrase, ce qui est établi, ce que les échanges ajoutent, structure longue/courte, Refusé
- `skills/dossier-init/templates/fr/CHANNELS.md` - Canaux: visioconférence, documents, mail, appels, ce dépôt
- `skills/dossier-init/templates/fr/OPEN-QUESTIONS.md` - Questions ouvertes: trois tables undated — réponses obtenues, toujours ouvertes côté contrepartie, ce qu'on poserait au client final
- `skills/dossier-init/templates/fr/RELATIONSHIP.md` - Relation: état, chiffres, notre/leur point de vue, améliorations, ventes possibles, points à garder en tête
- `skills/dossier-init/templates/fr/CONTEXT.md` - Knowledge stub: l'objet, ce qui est demandé maintenant, ce que le client a déjà, ce que nous apportons, les documents sources
- `skills/dossier-init/templates/fr/DOCTRINE.md` - Knowledge stub: ce qu'on dit / ce qu'on ne dit pas / le vocabulaire, une phrase chacun
- `skills/dossier-init/templates/fr/README-dossier.md` - Le dossier vivant: fact-line rule, correct-not-duplicate rule, seven-file index by English filename
- `skills/dossier-init/templates/fr/README-sources.md` - Sources: immutability rule, received/ + transcripts/(raw/) purposes, naming rule
- `skills/dossier-init/templates/fr/README-outbound.md` - Sortant: verbatim English status header inside French prose, naming rule, deliverables/mails/calls purposes, two standing rules

## Decisions Made
See `key-decisions` in the frontmatter: `CHANNELS.md`'s shortened fifth heading (`## Ce dépôt`, matching the plan's task text rather than a literal translation of the longer English heading), and the confirmation that no `init.py` change was required because `resolve_template_dir()` already generalizes over any `templates/<language>/` directory.

## Deviations from Plan

None. The plan's own task text specified the confidentiality check as `assert_not_grep -i 'acme' ...`, but `tests/lib.sh`'s `assert_not_grep` takes exactly two positional arguments (no `-i` flag) — the same constraint `tests/test-init-empty.sh` already documents and works around. Rather than treat this as a deviation, Task 1 was written using the established inline case-insensitive pattern (`grep -qi` with manual `TESTS_PASSED`/`TESTS_FAILED` bookkeeping) that the existing test file already uses for the identical situation — the intended behavior (case-insensitive confidentiality check) is what the plan's own acceptance criteria and threat model (T-01-14) require, and `tests/lib.sh` was correctly out of this plan's declared file scope.

## Issues Encountered
None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The French variant is complete at twelve files and lints clean under the phase's own test suite; Phase 2's linter fixtures can be built by running `init.py --language fr` exactly as `tests/test-init-fr.sh` does.
- Plan 01-04 (SKILL.md judgement body, running concurrently in a separate worktree) touches `templates/*/AGENTS-pointer.md` and `scripts/init.py` — neither of which this plan modified, so the twelve-filename parity this plan established stays intact for that plan's own parity check.
- **Blocker for a human:** none. **Concerns carried forward unchanged from plan 01-02:** the `claude plugin validate . --strict` vs. exactly-3-key-manifest conflict (Phase 7), and whether `skills/dossier-init/scripts/init.py` should eventually be split (tracked in `.planning/WINDOWS.md`) — this plan did not touch `init.py` at all, so that concern is unaffected either way.

---
*Phase: 01-scaffold-templates*
*Completed: 2026-09-16*

## Self-Check: PASSED

All twelve French template files verified present on disk under
`skills/dossier-init/templates/fr/`; `tests/test-init-fr.sh` verified present; `diff` against
`templates/en/`'s file list confirmed silent (identical twelve names). All 3 commit hashes
(`9c9a1c8`, `473b8a1`, `9c54fa1`) verified present in `git log --oneline`. Commit count measured
against `plan_head_before` (`c160ea5b`): `git rev-list --count c160ea5b..HEAD` = 3, matching
`actuals.commits`. `bash tests/run.sh` exits 0 with `0 failed` as the final state.
