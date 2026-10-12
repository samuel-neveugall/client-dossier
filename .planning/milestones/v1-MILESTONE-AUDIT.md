---
milestone: v1
audited: 2026-10-12
status: tech_debt
scores:
  requirements: 42/42
  phases: 7/7
  integration: 6/6
  flows: 1/1
gaps:
  requirements: []
  integration: []
  flows: []
tech_debt:
  - phase: 02-linter-test-harness
    items:
      - "OBS-01, the double typo in a key's last word, and the _osa_distance guard (carried, accepted)"
  - phase: 03-protocol-skill-hooks
    items:
      - "Bash guard class D-04 (eval, interpreters, substitutions, variables, loops, printf | apply_patch, cd chains beyond 32) accepted as v1 debt (D-17)"
      - "W3 (no change needed): each hook carries its own find_root copy of lint.py's upward search; tests/test-hooks-config.sh already fails on any divergence from lint.py"
  - phase: 05-drafting-doctrine-review
    items:
      - "Abbreviations and acronyms of confidential names caught only by doctrine-reviewer, not by E5 (D-09)"
  - phase: 06-calls-status
    items:
      - "W5 (kept by design): status.py exits 0 whenever a report is printed, since status is informational and not a gate; the lint verdict is in the report text and in the JSON lint field, and the skill maps any non-zero exit to a script failure"
  - phase: 07-manifests-docs-distribution
    items:
      - "W1: skills reach lint.py through ${CLAUDE_PLUGIN_ROOT}; on Codex or a bare-skills install the E5 gate reports 'not passed' (fails safe, check unavailable)"
      - "W2: no hooks in the Codex manifest; Codex hooks never run on a live Codex (no OpenAI key)"
      - "W4 (fixed in the cleanup): tests/test-script-modes.sh pins the shebang, the exec bit and git mode 100755 of every script a SKILL.md runs directly"
      - "Task-skill slash-command argument pass-through not smoked with an argument (07-VERIFICATION)"
      - "Marketplace install from samuel-neveugall/client-dossier testable only after publication; pre-publication checklist recorded in STATE, not executed"
      - "N1 (already fixed): CLAUDE.md Commands already describes the single validate warning"
      - "07-0x SUMMARY files carry no requirements-completed frontmatter (metadata only; 07-VERIFICATION maps DIST-01..07)"
nyquist:
  compliant_phases: []
  partial_phases: []
  not_validated_phases: ["02", "03", "04", "05", "06", "07"]
  missing_phases: ["01"]
  overall: not_validated
---

# Milestone v1 audit: client-dossier

Audited on 2026-10-12, on `main` at `7161abe`. Status: **tech_debt**. Nothing blocks the release.
The debt listed below is debt that was accepted or recorded during the phases.

## Phases

| Phase | VERIFICATION | UAT | Notes |
|---|---|---|---|
| 01 Scaffold & Templates | human_needed → closed after human verification on 2026-09-17 (5/5) | — | no VALIDATION.md |
| 02 Linter & Test Harness | passed 14/14 | complete | |
| 03 Protocol Skill & Hooks | passed 6/6 (D-04 override) | complete 8/8 | SECURITY.md |
| 04 Ingest & Fact Extraction | passed 5/5 | complete 6/6 | SECURITY.md |
| 05 Drafting & Doctrine Review | passed 5/5 | complete 6/6 | SECURITY.md |
| 06 Calls & Status | passed 5/5 | complete 3/3 | security covered by the code review |
| 07 Manifests, Docs & Distribution | passed 6/6 | complete 8/8 | |

## Requirements (cross-referenced from three sources)

All 42 requirements are checked in REQUIREMENTS.md, and each phase's VERIFICATION.md marks
them satisfied. No requirement is orphaned.

| Group | REQUIREMENTS | VERIFICATION | SUMMARY frontmatter | Final |
|---|---|---|---|---|
| SCAF-01..08 | [x] | passed (P1, human) | listed | satisfied |
| LINT-01..03 | [x] | passed | listed (02-06..09) | satisfied |
| PROTO-01..08 | [x] | passed | listed (03-0x, 06-0x) | satisfied |
| INGEST-01..06 | [x] | passed | listed | satisfied |
| DRAFT-01..05 | [x] | passed | listed | satisfied |
| CALL-01..05 | [x] | passed | listed (06-06) | satisfied |
| DIST-01..07 | [x] | passed | **missing** | satisfied: 07-VERIFICATION maps each DIST-ID to its evidence, verified by hand |

## Cross-phase integration (gsd-integration-checker)

All six wiring checks are connected:
1. The routing from the `dossier` skill reaches every skill and agent.
2. All `${CLAUDE_SKILL_DIR}` and `${CLAUDE_PLUGIN_ROOT}` paths resolve.
3. `hooks.json` points to the three hook scripts.
4. Every call to `lint.py` and `status.py` agrees on the 0/1/2/3 exit codes.
5. The two manifests agree.
6. No command shadows a skill.

The end-to-end flow ran with the scripts directly, in a scratch directory, with no paid runs:
- `init`, then ingest, then lint (exit 0).
- A draft, then status, which reports the overdue draft and embeds the lint line.
- Lint flags E5 on the confidential name.
- The guard denies a write under `sources/`, SessionStart injects its reminder, and Stop blocks once.

Results: `tests/run.sh` reported 30 files with 0 failures. `claude plugin validate .` exits 0 with one
known warning.

PROTO-06 and PROTO-07 rest on the paid RED/GREEN runs recorded in Phase 3. The checker did not re-run
them, by design.

## Nyquist

Every VALIDATION.md is still `status: draft`, because validate-phase never reconciled them.
Phases 03 to 07 carry `nyquist_compliant: true`. Phase 02 carries `false`. Phase 01 has no
VALIDATION.md. This is a coverage TODO, not a failure (#2117).

## Tech debt

See the frontmatter. Each item was accepted during its phase (D-17, D-09, the Phase 2 carry-overs) or
is a warning from the integration check (W1 to W5, N1). None of them blocks the release.

## Cleanup (2026-10-12, branch chore/v1-cleanup)

Samuel chose a short cleanup before closing v1.
- **W4** — fixed. The new `tests/test-script-modes.sh` runs 17 checks. A negative control shows
  that removing the exec bit from `status.py` makes 2 of them fail.
- **W3** — no change needed. The parity test on `find_root` already exists.
- **W5** — kept. The exit code contract is documented in `status.py` and relied on by the skill.
- **N1** — already fixed in CLAUDE.md before the audit.
- **W1, W2 and argument pass-through** — still debt. They depend on a live Codex or on publication.
- **Flaky watch**: one `tests/run.sh` run during the cleanup reported 1 of 31 files failed. The
  failing file was not captured. Five reruns in a row passed 31/31. Watch this; the shared
  `/tmp/gsd-test-output.$$` capture in `tests/run.sh` is not the cause, since it is per process.
