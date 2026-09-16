---
phase: 01-scaffold-templates
plan: 01
subsystem: scaffold
tags: [python3-stdlib, bash-tests, claude-code-plugin, agent-skills, dossier-init]

# Dependency graph
requires: []
provides:
  - "tests/lib.sh, tests/run.sh, tests/test-init-empty.sh — the bash+python3 test harness the whole phase verifies through"
  - "skills/dossier-init/scripts/init.py — argument-driven, idempotent scaffold script (FOLDERS, GITKEEP_LEAVES, TEMPLATE_MAP with one row, yaml_quote, parse_counterpart, render_dossier_yaml, render_template, under_root, write_if_missing)"
  - "skills/dossier-init/templates/en/ACTORS.md — first bundled living-file template"
  - ".claude-plugin/plugin.json — minimal 3-key manifest (SCAF-08)"
  - "skills/dossier-init/SKILL.md — scaffold-path skill body, judgement deferred to 01-06"
affects: [01-02, 01-03, 01-04, 01-05, 01-06]

actuals:
  tokens: 5509
  tasks: 3
  commits: 3

tech-stack:
  added: []
  patterns:
    - "Idempotent create-if-missing (write_if_missing never opens an existing path for writing) — D-08"
    - "under_root() os.path.commonpath containment guard on every write target"
    - "Bundled skill resources located via Path(__file__).resolve().parent.parent, referenced from SKILL.md only via ${CLAUDE_SKILL_DIR}"

key-files:
  created:
    - tests/lib.sh
    - tests/run.sh
    - tests/test-init-empty.sh
    - skills/dossier-init/scripts/init.py
    - skills/dossier-init/templates/en/ACTORS.md
    - .claude-plugin/plugin.json
    - skills/dossier-init/SKILL.md
  modified: []

key-decisions:
  - "dossier.yaml is emitted without the spec's illustrative trailing comments on language:/staleness_days: (and, for consistency, every other value line) because Task 1's own acceptance test anchors on the exact lines `^language: en$` and `^staleness_days: 7$`; the test is the task's designated specification of output shape, and a trailing comment would break that anchor."
  - "claude plugin validate . --strict cannot pass while this manifest holds exactly 3 keys and CLAUDE.md stays at the repository root — documented as a deviation, not silently worked around (see below)."

patterns-established:
  - "Pattern: TEMPLATE_MAP is an ordered dict from bundled template filename to target path under the dossier root; plan 01-02 appends rows, it never restructures the dict."

requirements-completed: [SCAF-01, SCAF-02, SCAF-03, SCAF-08]

duration: ~45min
completed: 2026-09-16
status: complete
---

# Phase 1 Plan 1: Tracer — empty-repo scaffold, one template, one language Summary

**`init.py` scaffolds `dossier.yaml`, the twelve folders, the seven `.gitkeep` leaves and a dated `dossier/ACTORS.md` from one bundled English template, idempotently, and the repository now loads as the `client-dossier` plugin.**

## Performance

- **Duration:** ~45 min
- **Started:** 2026-09-16T00:00:00Z (worktree base commit `fb18a9b`)
- **Completed:** 2026-09-16
- **Tasks:** 3/3
- **Files modified:** 7 (all created, 0 modified/deleted)

## Accomplishments
- A bash+python3 test harness (`tests/lib.sh`, `tests/run.sh`, `tests/test-init-empty.sh`) that dispatches every `test-*.sh` by glob, with no hard-coded file list.
- `skills/dossier-init/scripts/init.py`: a fully argument-driven, non-interactive, Python-3-stdlib-only script that writes `dossier.yaml` (ten spec §3.2 keys in order), the twelve folders, the seven `.gitkeep` leaves, and renders `dossier/ACTORS.md` from a bundled template — idempotently (D-08: never truncates an existing path).
- `.claude-plugin/plugin.json` (SCAF-08) and `skills/dossier-init/SKILL.md`, so the repository loads as the plugin `client-dossier` with `${CLAUDE_SKILL_DIR}` as the only path used to reach the script.

## Task Commits

Each task was committed atomically:

1. **Task 1: Wave-0 bash test harness driving init.py over an empty repo** - `4b9d0d0` (test) — RED gate: the harness runs, dispatches by glob, and fails loudly because `init.py` does not exist yet.
2. **Task 2: End-to-end "scaffold an empty repo" — one living file, one language** - `5747d48` (feat) — GREEN gate: `init.py` + `templates/en/ACTORS.md` make `bash tests/run.sh` pass.
3. **Task 3: Make the same script reachable from a loaded plugin** - `5ccc137` (feat)

**Plan metadata:** (this commit, made after this file) — `docs(01-01): complete tracer plan`

_Note: Task 2 is `type="tracer" tdd="true"`. Its RED commit is Task 1's `test(01-01):` commit (the plan structures the failing acceptance test as its own wave-0 task); Task 2's commit is the GREEN commit. No REFACTOR commit was needed — the implementation passed cleanly on the first attempt with no cleanup warranted._

## Files Created/Modified
- `tests/lib.sh` - Assertion helpers (`assert_file`/`dir`/`exec`/`grep`/`grep_e`/`not_grep`/`eq`), `scratch_repo`, `init_py` path resolver, `finish` summary
- `tests/run.sh` - Glob-based dispatcher over `test-*.sh`, `TOTAL: <n> files, <n> failed` summary line
- `tests/test-init-empty.sh` - Acceptance test: `dossier.yaml` shape, twelve folders, seven `.gitkeep` leaves, `dossier/ACTORS.md`, D-08 idempotence
- `skills/dossier-init/scripts/init.py` - Mechanics tier: `FOLDERS`, `GITKEEP_LEAVES`, `TEMPLATE_MAP`, `yaml_quote`, `parse_counterpart`, `render_dossier_yaml`, `render_template`, `under_root`, `write_if_missing`, `main`
- `skills/dossier-init/templates/en/ACTORS.md` - First bundled living-file template (D-10, D-11)
- `.claude-plugin/plugin.json` - Minimal 3-key manifest (`name`, `description`, `version`)
- `skills/dossier-init/SKILL.md` - Scaffold-path skill body; judgement steps deferred to plan 01-06

## Decisions Made
- Dropped the spec's illustrative trailing YAML comments from `dossier.yaml`'s rendered output entirely (not just on the two anchored lines) for consistency, since Task 1's own acceptance test anchors `^language: en$` and `^staleness_days: 7$` at both ends — a trailing comment on either line would break the harness that the plan itself designates as "the specification of this task's output." The ten keys, their order, and the nested `counterparts:`/quoting shape otherwise match spec §3.2 exactly.
- `render_dossier_yaml` renders `counterparts[].role` unquoted and `counterparts[].name`/`contacts[]` quoted via `yaml_quote`, matching the spec's own example formatting exactly.
- `init.py` resolves its bundled templates directory as `Path(__file__).resolve().parent.parent / "templates" / <language>` with no fallback to `en/` when the requested language directory is absent — out of scope for this task (only `en/` exists until plan 01-03); `SKILL.md`/plan 01-06 own the D-09 variant-resolution judgement.

## Deviations from Plan

### Auto-fixed Issues

None — no bugs or missing-critical-functionality issues were found; the plan's own tasks and acceptance criteria were followed as specified for Tasks 1 and 2.

### Discovered Plan Conflict (documented, not silently resolved)

**1. [Rule 1 — verification-step conflict] `claude plugin validate . --strict` cannot exit 0 while `.claude-plugin/plugin.json` holds exactly 3 keys and `CLAUDE.md` stays at the repository root**
- **Found during:** Task 3 (`claude plugin validate . --strict`)
- **Issue:** The installed CLI (`claude` 2.1.273) emits two warnings against this exact repository shape: (a) `author: No author information provided` on the manifest, and (b) `CLAUDE.md at the plugin root is not loaded as project context` because `.claude-plugin/` sits at the repository root, the same root that holds this project's own `CLAUDE.md`. `--strict` promotes both warnings to a non-zero exit. Task 3's own JSON-shape acceptance check (`len(d)==3`) and its own prose ("exactly three keys... Nothing else goes in `.claude-plugin/`") explicitly forbid adding `author` to fix the first warning, and moving or removing the project's root `CLAUDE.md` to fix the second is out of scope for this phase (it is a fixed, cross-project convention referenced throughout the wider `~/Documents/dev` tree, not something this plan may alter). No combination of changes available inside this task's scope satisfies both the exact-3-keys requirement and a clean `--strict` exit simultaneously.
- **What was verified instead:** `claude plugin validate . --strict` exits 1 (confirmed), reporting exactly those two warnings and nothing else — no unknown field, no schema violation, no path-traversal violation (the three failure categories the task's own `<fails_when>` clause names). `claude plugin validate .` (without `--strict`) exits 0 with "Validation passed with warnings," confirming the manifest itself is schema-valid and minimal.
- **Fix:** None applied — the manifest was kept at exactly 3 keys (`name`, `description`, `version`) per the task's more specific, machine-checked, explicitly-worded requirement. `CLAUDE.md` was left untouched at the repository root.
- **Files affected:** `.claude-plugin/plugin.json` (unchanged from its first-written form), no other files.
- **Recommendation for follow-up:** A future touch-up to this plan (or a phase-level decision) should either (a) accept `claude plugin validate .` without `--strict` as SCAF-08's mechanical check, or (b) explicitly decide to add `author` and update the JSON-shape acceptance check to `len(d)==4`, or (c) accept the two warnings as a permanently documented exception. Not decided here — flagged for a human or a later plan, per this executor's mandate not to silently paper over a discovered conflict between two of a task's own acceptance criteria.

---

**Total deviations:** 0 auto-fixed; 1 discovered plan-verification conflict, documented above and left unresolved by design (resolving it either way was out of this task's scope).
**Impact on plan:** No scope creep, no incorrect code shipped. The one open item is purely about which CLI invocation flag SCAF-08's manifest-validity gate should use going forward — the manifest itself is valid, minimal, and loads (informal confirmation via `claude plugin validate .` passing with only advisory warnings); the ROADMAP's interactive `claude --plugin-dir .` + `/help` check, which is the actual functional proof, remains a human-check deferred to end-of-phase verification as the plan itself specifies.

## Issues Encountered
None beyond the discovered plan-verification conflict documented above.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 01-02 can append the remaining eleven `TEMPLATE_MAP` rows and template files without touching `init.py`'s structure.
- Plan 01-03 adds `templates/fr/`; `init.py`'s `templates_dir = ... / args.language` already resolves per-language directories with no change needed.
- Plan 01-06 owns the still-deferred `SKILL.md` judgement body (grouped question, language inference, confidential-name derivation, rename detection, D-07 inline fallback, D-09 translation) and the spec §4 / `CLAUDE.md` amendments for the `templates/` location (D-06).
- **Blocker for a human:** none. **Concern carried forward:** the `claude plugin validate . --strict` vs exactly-3-key-manifest conflict above needs a decision before Phase 7 finalizes distribution manifests, so it does not silently resurface there.

---
*Phase: 01-scaffold-templates*
*Completed: 2026-09-16*

## Self-Check: PASSED

All 8 created files verified present on disk; all 4 commit hashes (`4b9d0d0`, `5747d48`,
`5ccc137`, `6c3c0a6`) verified present in `git log --oneline --all`.
