---
gsd_state_version: "1.0"
current_phase: 07
current_phase_name: manifests-docs-distribution
status: phase_complete
stopped_at: Phase 6 executed (verification passed 5/5, UAT 3/3 agent-run); review pending
last_updated: "2026-10-11T09:15:16.646Z"
last_activity: 2026-10-11
last_activity_desc: Phase 05 closed - review fix round 3, re-verification passed, UAT complete
state_head: 12b12c281d72963fe84f3c8e46d30158780399f0
progress:
  total_phases: 7
  completed_phases: 6
  total_plans: 46
  completed_plans: 37
  percent: 80
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-09-16)

**Core value:** Every agent session in a dossier repository reads the living dossier before
acting and updates it before handing back — so nothing reaches the counterpart without a
human and a doctrine check.
**Current focus:** Phase 06 — Calls & Status (executed; review revue-6 pending, then Phase 7)

## Current Position

Phase: 07 (manifests-docs-distribution) — READY TO EXECUTE
Status: Phase 5 done: `05-VERIFICATION.md` passed 5/5 (iter1 kept as `05-VERIFICATION.iter1.md`), `05-UAT.md`
complete 6/6 (agent-run, evidence `evidence/uat/`, 0.774 USD), review fix rounds 1-3 recorded in
`05-REVIEW-FIX.md`. Dispatch of `doctrine-reviewer` is mandatory, foreground, and applied before lint and
history (harness gates handback_before_review, lint_after_last_draft_edit, history_edit_before_review).
`tests/run.sh` 20 files, 0 failed; test-lint 1728/0; DRAFT-01..05 complete, PROTO-02 pointer to `dossier-draft` added.
Last activity: 2026-10-11 — Phase 6 executed: plans 06-01..06-06, `06-VERIFICATION.md` passed 5/5, `06-UAT.md` 3/3 agent-run, `tests/run.sh` 24 files 0 failed. CALL-04 RED 3/3 -> GREEN 3/3; CALL-05 RED 3/3 -> GREEN 3/3 (D-16 fallback unused). Phase 6 paid spend 1.74 USD. Next: revue-6, then Phase 7.

Progress: [████████░░] 80%

## Performance Metrics

<!-- vf-archive: .planning/archives/state/racine-STATE-2026-10-10.md -->
<!-- vf-archive: .planning/archives/state/racine-STATE-2026-10-12.md (resolved debt rows and blockers) -->

## Accumulated Context

### Decisions

### Pending Todos

- Phase 7: D-18 settled (one command, `dossier-lint`); plans 07-01..07-09 executed, the engine closes the phase after verification and UAT.

### Blockers/Concerns

- `pdftotext` (poppler) is installed on the dev machine (`/opt/homebrew/bin/pdftotext`), checked
  2026-10-10 for Phase 4.
- Resolved in Phase 3 (03-06): `CLAUDE.md` now documents `claude plugin validate .` (exit 0 observed 2026-10-10); `--strict` stays at exit 1 on the two known warnings (plugin.json `author`, root `CLAUDE.md`) until Phase 7. Phase 7: author added; one warning remains (root CLAUDE.md, D-03), --strict exits 1 by design.

## Deferred Items

| Category | Item | Status | Deferred At | Milestone |
|----------|------|--------|-------------|-----------|
| Debt (Phase 2 gap-closure review) | WR-01: E5 is blind only to Unicode category Cf, not the wider default-ignorable set (CGJ, variation selectors, Hangul fillers). OBS-01: no runtime rejection of a confidential name starting with `>`. CR-02 bis residual: a double typo landing inside the last word of a `confidential_names` misspelling beside the exact key stays ignored. Minor: `_osa_distance` has no internal length guard (safe only through its call sites). Details: `02-REVIEW-FIX.md`, `02-VERIFICATION.md`. | WR-01 resolved — `ce42a6a` (2026-10-10, every Default_Ignorable_Code_Point treated like Cf in `lint.py` and `init.py`). OBS-01, the CR-02 bis residual and the `_osa_distance` guard stay open as accepted v1 debt | 2026-09-25 (gap-closure review) | v1 |
| Accepted v1 debt (D-17) | Phase 3 Bash guard (D-04): it reads the command text only and does not see `eval`, `bash -c "$(...)"`, process substitution, `ssh h <<EOF`, interpreters (`python3 -c`...), variables, loops over globs, `bash -c` deeper than 2 levels or scripts over 64 KB; `cd $X; cd sources` and `cd /nonexistent` are guessed, not followed; a diff handed to `patch -p1` or a `cp dossier/*.txt sources/` onto an existing name is unseen. The skill's rule (never modify a source by any route) is the boundary; the skill states it. Past a bound (operand > 4096 chars, > 512 operands, > 4096 judged paths) the guard only refuses a visible `sources` component. Details: `03-REVIEW-FIX.iter3.md`. | Accepted — Samuel, AskUserQuestion main session, 2026-10-10 (D-17); README to state it (DIST-05); stated in README.md ## Limits (Phase 7, plan 07-06) | 2026-10-10 (Phase 3 review, round 3) | v1 |
| Accepted v1 debt (05 D-09) | E5 (`scripts/lint.py`) does not cover abbreviations, acronyms, nicknames or translations of a confidential name (`BT` for `British Telecom`), nor homoglyphs outside the small `_HOMOGLYPHS` table; the doctrine-reviewer is the only net for these. Hardened instead in fix-5b: markup between words, apostrophe look-alikes, end-of-line hyphen inside a word, percent-encoded file names, double HTML encoding, Cyrillic/Greek homoglyphs, non-empty `.gitkeep`; round 3 (2026-10-11) added the tolerant mixed-markup reading, link/tag long tail, Unicode dashes and an unreadable `.gitkeep` error. Details: `05-SECURITY.md` A5-F2, A5-F3, A5-F8. | Accepted - Samuel, AskUserQuestion main session, 2026-10-11 (05 D-09, option a); stated in README.md ## Limits (Phase 7, plan 07-06) | 2026-10-11 (Phase 5 audit) | v1 |

## Pre-publication checklist (D-12, NOT executed in v1)

Publication needs Samuel's explicit approval (D-01). Measure each item at publication time. The paid
command smoke (Haiku, about 0.05 USD) is planned in 07-09 task 3 and recorded in `evidence/uat/`.

- [ ] 1. Scenario evidence under `.planning/phases/*/evidence/` (`/Users/...` paths, session ids):
  `git grep -l '/Users/' -- '.planning/phases/*/evidence'`; `git grep -lE 'session_id|sessionId' -- '.planning/phases/*/evidence'`
- [ ] 2. The other `.planning/` files carrying `/Users/...`:
  `git grep -l '/Users/' -- .planning ':!.planning/phases/*/evidence'`
- [ ] 3. `Claude-Session` URLs in commit history: `git log --format=%H --grep='Claude-Session' | wc -l`;
  a history rewrite or a fresh public repository is Samuel's decision
- [ ] 4. `.planning/` ships inside every installation (a GitHub-source install copies tracked files):
  scrub it, or exclude it from the public tree
- [ ] 5. Codex public directory (D-13): plugins with lifecycle hooks are not listed; a hook-less variant
  is a publication-time decision. Codex hooks were never run for real (no OpenAI login): documentation-backed
- [ ] 6. D-01 gates: pushing `v1.0.0`, publishing to a marketplace, making the repository public each
  need explicit approval; `scripts/release.sh 1.0.0` and the LOCAL tag come after the milestone audit
- [ ] 7. Re-check `claude plugin validate` messages and the Codex manifest format (research valid until 2026-10-25)

## Session Continuity

Last session: 2026-10-11
Stopped at: Phase 6 executed (verification passed 5/5, UAT 3/3)
Resume file: .planning/phases/06-calls-status/06-VERIFICATION.md
