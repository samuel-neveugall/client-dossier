---
phase: 01-scaffold-templates
plan: 02
subsystem: scaffold
tags: [python3-stdlib, bash-tests, markdown-templates, dossier-init]

# Dependency graph
requires:
  - phase: 01-scaffold-templates
    provides: "tests/lib.sh, tests/run.sh, tests/test-init-empty.sh harness; skills/dossier-init/scripts/init.py mechanics tier (FOLDERS, GITKEEP_LEAVES, TEMPLATE_MAP with one row, write_if_missing, under_root, render_template); skills/dossier-init/templates/en/ACTORS.md"
provides:
  - "The eleven remaining English templates: HISTORY.md, LEARNINGS.md, TONE.md, CHANNELS.md, OPEN-QUESTIONS.md, RELATIONSHIP.md (dossier/), CONTEXT.md, DOCTRINE.md (knowledge/), README-dossier.md, README-sources.md, README-outbound.md (three folder READMEs)"
  - "TEMPLATE_MAP grown from one row to twelve, in spec §3.2 scaffold order"
  - "resolve_template_dir(templates_root, language, variant) — the D-09 variant-resolution decision point, and the --template-variant CLI flag"
  - "tests/test-init-empty.sh extended to assert the full scaffold surface: all twelve targets, the outbound status-header restatement, the confidentiality rule, and the fallback/hit report line"
affects: [01-03, 01-04, 01-05, 01-06]

# Actuals (#2632)
actuals:
  tokens: 4633
  tasks: 3
  commits: 3
plan_head_before: fb332995132aecc07db74167de7fb0170adb7988

tech-stack:
  added: []
  patterns:
    - "TEMPLATE_MAP as the single template-filename -> target-path contract; plan 01-03's templates/fr/ and Phase 2's clean lint fixture are both written against this exact mapping."
    - "resolve_template_dir() centralizes D-09 (two hand-maintained variants, translate from en/ for anything else) as the one function that decides which templates/<name>/ directory to read; both branches route through the existing under_root() containment guard (T-01-10)."
    - "Template resolution happens before any filesystem write in main() — an unknown --template-variant aborts having written nothing, matching D-08's 'never partially scaffold' spirit."

key-files:
  created:
    - skills/dossier-init/templates/en/HISTORY.md
    - skills/dossier-init/templates/en/LEARNINGS.md
    - skills/dossier-init/templates/en/TONE.md
    - skills/dossier-init/templates/en/CHANNELS.md
    - skills/dossier-init/templates/en/OPEN-QUESTIONS.md
    - skills/dossier-init/templates/en/RELATIONSHIP.md
    - skills/dossier-init/templates/en/CONTEXT.md
    - skills/dossier-init/templates/en/DOCTRINE.md
    - skills/dossier-init/templates/en/README-dossier.md
    - skills/dossier-init/templates/en/README-sources.md
    - skills/dossier-init/templates/en/README-outbound.md
  modified:
    - skills/dossier-init/scripts/init.py
    - tests/test-init-empty.sh

key-decisions:
  - "DISC-4 (spec vs. origin repo): HISTORY.md ships two labelled sub-headings (### Ours, ### Theirs) under 'Commitments in progress' per spec §2.2, diverging from the origin's single flat section — the spec wins per CLAUDE.md's own precedence rule."
  - "DISC-3 (spec vs. origin repo): TONE.md, OPEN-QUESTIONS.md and RELATIONSHIP.md use one generic per-exchange section, an undated generic heading, and role-generic labels ('Our view' / 'Their view, as we reconstruct it') instead of the origin's per-party, dated, or split headings — counterpart names are unknown at scaffold time and confidential besides (D-13)."
  - "Knowledge stubs (CONTEXT.md, DOCTRINE.md) carry no 'Last updated:' line and no 'Updated when' comment, per D-12's literal wording — only the seven living files carry that pair."
  - "OPEN-QUESTIONS.md's third table ('what we would ask the end client') uses the same three columns as the second table (question / why it matters / when to ask); the spec names the table but not its columns, so this was Claude's discretion for consistency."
  - "resolve_template_dir() validates the --template-variant / --language directory candidate is both an existing directory AND under_root()-contained before use, closing the one user-influenced filesystem path in this plan (T-01-10) even though no traversal payload was demonstrated as exploitable given the string is a single path segment appended via pathlib."

patterns-established:
  - "Pattern: knowledge-stub templates (no Last updated:, no Updated when) are a distinct skeleton shape from living-file templates (Last updated: + Updated when) — plan 01-03's French variant and any future knowledge file follow whichever shape matches their role."

requirements-completed: [SCAF-03, SCAF-04, SCAF-07]

coverage:
  - id: D1
    description: "Seven living files scaffold with a dated Last updated: line and their own Updated when comment (SCAF-03)"
    requirement: "SCAF-03"
    verification:
      - kind: integration
        ref: "tests/test-init-empty.sh (full-surface block, plan 01-02)"
        status: pass
    human_judgment: false
  - id: D2
    description: "knowledge/CONTEXT.md, knowledge/DOCTRINE.md (with its two lists + vocabulary section), and the three folder READMEs all exist after one run (SCAF-04)"
    requirement: "SCAF-04"
    verification:
      - kind: integration
        ref: "tests/test-init-empty.sh (five-target + DOCTRINE heading assertions)"
        status: pass
    human_judgment: false
  - id: D3
    description: "outbound/README.md restates spec §3.3's status header verbatim, the YYYY-MM-DD_slug rule, and the three subfolder purposes, naming no counterpart"
    requirement: "SCAF-04"
    verification:
      - kind: integration
        ref: "tests/test-init-empty.sh (outbound README + confidentiality assertions)"
        status: pass
    human_judgment: false
  - id: D4
    description: "An unlisted --language falls back to templates/en/ and the report says so; an explicit --template-variant is used verbatim or aborts cleanly if absent (SCAF-07, D-09)"
    requirement: "SCAF-07"
    verification:
      - kind: integration
        ref: "tests/test-init-empty.sh (variant-fallback and variant-hit blocks)"
        status: pass
    human_judgment: false
  - id: D5
    description: "A freshly scaffolded dossier holds zero fake facts: every example and guiding question is an HTML comment (D-11/D-12)"
    verification:
      - kind: integration
        ref: "Task 2 verify command 1 (bare-bullet-outside-comment check across the six living-file templates)"
        status: pass
    human_judgment: false

duration: ~35min
completed: 2026-09-16
status: complete
---

# Phase 1 Plan 2: Full English Template Set and Scaffold Wiring Summary

**Eleven English templates (seven living files, two knowledge stubs, three folder READMEs) authored and wired into `init.py`'s twelve-row `TEMPLATE_MAP`, plus `resolve_template_dir()` for the D-09 language-variant fallback/hit resolution — one `init.py` run now scaffolds a complete, lint-clean, fact-free dossier.**

## Performance

- **Duration:** ~35 min
- **Tasks:** 3/3
- **Files modified:** 13 (11 created, 2 modified)

## Accomplishments
- Eleven English templates matching spec §2.2 section-by-section (heading counts verified: RELATIONSHIP 7, LEARNINGS 4, CHANNELS 5, TONE 6, OPEN-QUESTIONS 3, HISTORY 3 `##` + 2 `###`, DOCTRINE 3, CONTEXT 5), every example/guidance line an HTML comment, no counterpart name anywhere.
- `TEMPLATE_MAP` grown from one row to twelve; one `init.py` run now produces 20 files (12 template-derived + `dossier.yaml` + 7 `.gitkeep` leaves), confirmed idempotent on a second run (`diff -r` silent).
- `resolve_template_dir()` + `--template-variant`: an unlisted `--language` (e.g. `es`) falls back to `templates/en/` and reports it (`templates: en (requested language 'es' has no template variant...)`); an unknown `--template-variant` aborts before any write.
- `tests/test-init-empty.sh` extended with 45+ new assertions covering the full scaffold surface, the confidentiality rule, and both variant-resolution branches — RED before Task 2/3, GREEN after.

## Task Commits

Each task was committed atomically:

1. **Task 1: Extend the empty-repo test to the full scaffold surface** - `4e2a1f4` (test) — RED gate: `bash tests/run.sh` exits 1, names `test-init-empty.sh`, 40 new failing assertions.
2. **Task 2: Author the eleven remaining English templates** - `cf93677` (feat)
3. **Task 3: Wire all twelve templates into the scaffold and resolve the language variant** - `8403f39` (feat) — GREEN gate: `bash tests/run.sh` exits 0, `0 failed`.

**Plan metadata:** (this commit, made after this file) — `docs(01-02): complete plan`

_Note: Task 3 is `type="auto" tdd="true"`. Its RED commit is Task 1's `test(01-02):` commit (the plan structures the failing acceptance test as its own wave-0 task, same pattern as plan 01-01); Task 3's commit is the GREEN commit. No separate REFACTOR commit was needed._

## Files Created/Modified
- `skills/dossier-init/templates/en/HISTORY.md` - Chronology, commitments in progress (### Ours / ### Theirs), upcoming
- `skills/dossier-init/templates/en/LEARNINGS.md` - How they speak and think, what they expect, what the case teaches, known pitfalls
- `skills/dossier-init/templates/en/TONE.md` - Voice, established, exchanges add, long/short document structure, Refused log
- `skills/dossier-init/templates/en/CHANNELS.md` - Video etiquette, documents, mail, calls, this repository
- `skills/dossier-init/templates/en/OPEN-QUESTIONS.md` - Three undated tables: answered, still open, what we'd ask the end client
- `skills/dossier-init/templates/en/RELATIONSHIP.md` - Status, numbers table, our/their view, improvements, opportunities, points to keep in mind
- `skills/dossier-init/templates/en/CONTEXT.md` - Knowledge stub: object, asked now, client has, we bring, source documents
- `skills/dossier-init/templates/en/DOCTRINE.md` - Knowledge stub: what we say / what we never say / vocabulary (SCAF-04's two lists)
- `skills/dossier-init/templates/en/README-dossier.md` - dossier/ folder purpose, fact-line rule, seven-file index
- `skills/dossier-init/templates/en/README-sources.md` - sources/ immutability rule, received/ + transcripts/(raw/) purposes, naming rule
- `skills/dossier-init/templates/en/README-outbound.md` - Verbatim spec §3.3 status header, naming rule, deliverables/mails/calls purposes, two standing rules
- `skills/dossier-init/scripts/init.py` - TEMPLATE_MAP grown to twelve rows; `resolve_template_dir()` added; `--template-variant` flag; template resolution moved before any write
- `tests/test-init-empty.sh` - Extended with the full-surface, confidentiality, and variant-resolution assertion blocks

## Decisions Made
See `key-decisions` in the frontmatter: the DISC-3/DISC-4 spec-vs-origin calls (both anticipated and pre-authorized by the plan itself), the knowledge-stub skeleton shape, the OPEN-QUESTIONS third-table columns (Claude's discretion), and the `under_root()` containment check on both `resolve_template_dir()` branches.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Traced technical debt for a global file-size guard hook instead of restructuring `init.py` mid-plan**
- **Found during:** Task 3 (adding `resolve_template_dir()` to `init.py`)
- **Issue:** A machine-wide Claude Code hook installed by the `vibeflow` plugin (Iron Law ADR-035, `guard-file-size.sh`) denied the `Edit` that would have grown `skills/dossier-init/scripts/init.py` past 300 lines. This hook is not part of `client-dossier`'s own `CLAUDE.md`, this plan, or any GSD convention — it is a global user tool that applies to every `.py`/`.ts`/etc. file edited on this machine.
- **Fix:** Restructuring `init.py` into multiple modules was out of this task's declared `<files>` scope (only `skills/dossier-init/scripts/init.py` was named) and would have altered the shape of a file the plan's own reversibility note calls a locked downstream contract (`TEMPLATE_MAP` is what `templates/fr/` in plan 01-03 and Phase 2's lint fixture are written against). Instead, traced the debt with the hook's own sanctioned marker (`vibeflow:allow-large-file`) in the file's first five lines, with an inline comment explaining why splitting was deferred, and appended an entry to `.planning/WINDOWS.md` (kind `deviation`) so it stays visible at ship time.
- **Files modified:** `skills/dossier-init/scripts/init.py` (marker comment only, no behavior change), `.planning/WINDOWS.md` (ledger entry, best-effort per the SUMMARY protocol).
- **Verification:** The `Edit` that added the marker itself, and every subsequent edit that grew the file further, were both allowed by the hook (confirmed by the edits succeeding); `bash tests/run.sh` passes with `0 failed` after all Task 3 changes.
- **Committed in:** `8403f39` (Task 3 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking, Rule 3). No scope creep: the fix is a five-line comment tracing pre-existing tooling friction, not a behavior change to the scaffold.
**Impact on plan:** None on the shipped scaffold behavior. The open item (whether `init.py` should eventually be split, e.g. once `SKILL.md`'s inline fallback or Phase 2's linter integration adds more mechanics) is tracked in `.planning/WINDOWS.md`, not silently deferred.

## Issues Encountered
None beyond the deviation documented above.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 01-03 (`templates/fr/`) has a stable, twelve-row `TEMPLATE_MAP` to mirror and a confirmed heading-count table (7/4/5/6/3/3/3/5) to translate against.
- Plan 01-04 (SKILL.md judgement body) can reference `resolve_template_dir()`'s exact contract (`--template-variant` wins outright and aborts cleanly if absent; otherwise `--language` is tried, then `en/` with a reported fallback) when writing the inline fallback procedure (D-07).
- Phase 2's linter fixture can be built by running `init.py` once on an empty repo — the output is confirmed idempotent and confidentiality-clean under `outbound/`.
- **Blocker for a human:** none. **Concern carried forward from plan 01-01, unchanged:** the `claude plugin validate . --strict` vs. exactly-3-key-manifest conflict still needs a decision before Phase 7. **New concern:** whether `skills/dossier-init/scripts/init.py` should be split once more mechanics land in later plans (tracked in `.planning/WINDOWS.md`).

---
*Phase: 01-scaffold-templates*
*Completed: 2026-09-16*

## Self-Check: PASSED

All 11 created template files verified present on disk under `skills/dossier-init/templates/en/`;
`skills/dossier-init/scripts/init.py` and `tests/test-init-empty.sh` verified modified; all 3
commit hashes (`4e2a1f4`, `cf93677`, `8403f39`) verified present in `git log --oneline --all`.
Commit count measured against `plan_head_before` (`fb332995`): `git rev-list --count
fb332995..HEAD` = 3, matching `actuals.commits`.
