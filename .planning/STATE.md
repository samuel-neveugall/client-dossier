---
gsd_state_version: "1.0"
current_phase: 05
current_phase_name: drafting-doctrine-review
status: ready_to_plan
stopped_at: Phase 4 closed (verification passed 5/5, UAT complete 6/6, agent-run)
last_updated: "2026-10-10T22:16:24.592Z"
last_activity: 2026-10-10
last_activity_desc: Phase 04 executed (5/5 plans), verifier human_needed
state_head: 7bc1bf3ddfadf492ab5dede67cc44af1d6c2db07
progress:
  total_phases: 7
  completed_phases: 4
  total_plans: 31
  completed_plans: 26
  percent: 57
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-09-16)

**Core value:** Every agent session in a dossier repository reads the living dossier before
acting and updates it before handing back — so nothing reaches the counterpart without a
human and a doctrine check.
**Current focus:** Phase 05 — Drafting & Doctrine Review (ready to plan)

## Current Position

Phase: 05 (drafting-doctrine-review) — READY TO EXECUTE
Status: Phase 4 done: `04-VERIFICATION.md` passed 5/5 (iter1 human_needed kept as `04-VERIFICATION.iter1.md`),
`04-UAT.md` complete 6/6 (agent-run, evidence `evidence/uat/`, 0.660 USD). Dispatch of `fact-extractor`
is mandatory and observed live (r2 runs + UAT). `tests/run.sh` 17 files, 0 failed; INGEST-01..06 complete.
Last activity: 2026-10-10 — Phase 4 closure (fix-4b, verification, recette)

Progress: [██████░░░░] 57%

## Performance Metrics

<!-- vf-archive: .planning/archives/state/racine-STATE-2026-10-10.md -->

## Accumulated Context

### Decisions

### Pending Todos

- Phase 3 executed 2026-10-10: Q6 settled by D-15 (pressured prompt, RED 3/3), Q7 by D-16 (guard hardened); GREEN 3/3 with the plugin. Phase 4 closed. Details: `.planning/missions/2026-10-10-v1-phases-3-7.md`, `03-REVIEW.md`, `03-SECURITY.md`.

### Blockers/Concerns

- Phase 2 is merged into `main` (`6fbd08d`); its planning assumptions and the D-24/D-28
  arbitrations were validated at the 2026-10-10 sign-off.
- The Stop-hook question (spec §11 #3) is settled by `03-CONTEXT.md` D-01 (ships, block-once);
  the spec, `CLAUDE.md`, PROJECT.md, ROADMAP and REQUIREMENTS were amended in Phase 3 (plans 03-03 and 03-06).
- `pdftotext` (poppler) is installed on the dev machine (`/opt/homebrew/bin/pdftotext`), checked
  2026-10-10 for Phase 4.
- Resolved in Phase 3 (03-06): `CLAUDE.md` now documents `claude plugin validate .` (exit 0 observed 2026-10-10); `--strict` stays at exit 1 on the two known warnings (plugin.json `author`, root `CLAUDE.md`) until Phase 7.
- 03-02 baseline gate resolved: D-15 pressured prompt gave RED 3/3 without the plugin (evidence/red-baseline/); plugin variant GREEN 3/3 (evidence/green-plugin/). P-01/P-02 stay provisional awaiting Samuel.

## Deferred Items

| Category | Item | Status | Deferred At | Milestone |
|----------|------|--------|-------------|-----------|
| Debt (Phase 1 → Phase 2) | (a) YAML 1.1 reserved words: `init.py`'s `_SAFE_PLAIN_SCALAR_RE` lets `yes/no/on/off/true/false/null/y/n` through unquoted; `--language no` writes `language: no`, read back as boolean `False` by a strict YAML parser. Not a vulnerability (no key injection; `consent_recorded` unreachable) — a typing-fidelity gap. Fix when writing `lint.py`'s YAML-subset parser, aligning producer and consumer in one move. | Resolved — 02-03 (`bd2ecd2`): `_YAML_RESERVED_SCALARS` routes reserved spellings to `yaml_quote()`; pinned by `tests/test-init-empty.sh` d14. Round-trip through the lint parser still due in 02-06 | 2026-09-16 (Phase 1 review, round 3) | v1 |
| Debt (Phase 1 → Phase 2) | (b) Regex anchoring: same regex's `$` also matches just before a trailing `\n` (vs. `\Z`/`re.fullmatch`); a value ending in a newline passes the allowlist and leaves a blank line. No key injection — cosmetic guard bypass. One-line fix, bundle with (a). | Resolved — 02-03 (`bd2ecd2`): `emit_scalar` uses `fullmatch`; pinned by `tests/test-init-empty.sh` d15 | 2026-09-16 (Phase 1 review, round 3) | v1 |
| Debt (Phase 2 review, iteration 3) | Three reproduced fail-open paths of the confidentiality gate (E5), each letting a confidential name under `outbound/` pass with exit 0; none introduced by the fix rounds: CR-01 `Outbound/` on a case-insensitive filesystem escapes every outbound check; CR-02 zero-width/BOM/soft-hyphen characters in a name survive `init.py` and defeat the text match; CR-03 HTML entities in an outbound `.html` hide names. Plus WR-01 (near-miss rule rejects legitimate extra keys like `consent_scope`), WR-02 (two untested lines), WR-03 (unreadable dir or `.git/` under `outbound/` skipped silently), WR-04 (name wrapped across `> ` quoted lines). Details: `02-REVIEW.md`. | Resolved — gap closure 2026-09-25 (02-07..02-09 + review-fix rounds, branch `feat/phase-02-gap-closure`); Samuel ordered the fix round in UAT item 4 | 2026-09-24 (Phase 2 review, iteration 3) | v1 |
| Debt (Phase 2 gap-closure review) | WR-01: E5 is blind only to Unicode category Cf, not the wider default-ignorable set (CGJ, variation selectors, Hangul fillers). OBS-01: no runtime rejection of a confidential name starting with `>`. CR-02 bis residual: a double typo landing inside the last word of a `confidential_names` misspelling beside the exact key stays ignored. Minor: `_osa_distance` has no internal length guard (safe only through its call sites). Details: `02-REVIEW-FIX.md`, `02-VERIFICATION.md`. | WR-01 resolved — `ce42a6a` (2026-10-10, every Default_Ignorable_Code_Point treated like Cf in `lint.py` and `init.py`). OBS-01, the CR-02 bis residual and the `_osa_distance` guard stay open as accepted v1 debt | 2026-09-25 (gap-closure review) | v1 |
| Accepted v1 debt (D-17) | Phase 3 Bash guard (D-04): it reads the command text only and does not see `eval`, `bash -c "$(...)"`, process substitution, `ssh h <<EOF`, interpreters (`python3 -c`...), variables, loops over globs, `bash -c` deeper than 2 levels or scripts over 64 KB; `cd $X; cd sources` and `cd /nonexistent` are guessed, not followed; a diff handed to `patch -p1` or a `cp dossier/*.txt sources/` onto an existing name is unseen. The skill's rule (never modify a source by any route) is the boundary; the skill states it. Past a bound (operand > 4096 chars, > 512 operands, > 4096 judged paths) the guard only refuses a visible `sources` component. Details: `03-REVIEW-FIX.iter3.md`. | Accepted — Samuel, AskUserQuestion main session, 2026-10-10 (D-17); README to state it (DIST-05) | 2026-10-10 (Phase 3 review, round 3) | v1 |

## Session Continuity

Last session: 2026-10-10
Stopped at: Phase 4 closed (verification passed, UAT complete)
Resume file: .planning/phases/04-ingest-fact-extraction/04-UAT.md
