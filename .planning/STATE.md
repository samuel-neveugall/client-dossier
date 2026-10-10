---
gsd_state_version: "1.0"
current_phase: 03
current_phase_name: Protocol Skill & Hooks
status: executing
stopped_at: 03-02 blocked at baseline gate (Tasks 1-2 done, Task 3 RED 0/3)
last_updated: "2026-10-10T13:04:23.336Z"
last_activity: 2026-10-10
last_activity_desc: Phase 03 execution started
state_head: 525280573dbeca5edcb2901da8146ae266aeea67
progress:
  total_phases: 7
  completed_phases: 2
  total_plans: 21
  completed_plans: 16
  percent: 29
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-09-16)

**Core value:** Every agent session in a dossier repository reads the living dossier before
acting and updates it before handing back — so nothing reaches the counterpart without a
human and a doctrine check.
**Current focus:** Phase 03 — Protocol Skill & Hooks

## Current Position

Phase: 03 (Protocol Skill & Hooks) — EXECUTING
Plan: 2 of 6
Status: Ready to execute
Phase 2 closed 2026-10-10: recette delegated by Samuel to the agent and run green (`02-UAT.md`
complete, items 2 and 4 re-tested, 7 gaps resolved by 02-07..02-09); WR-01 (default-ignorable
characters outside Cf hid a confidential name) fixed by `ce42a6a` on Samuel's call before
sign-off; `02-VERIFICATION.md` passed 14/14 on `ce42a6a`; `tests/test-lint.sh` 1551 assertions,
`bash tests/run.sh` 6 files, 0 failed. Branch `feat/phase-02-gap-closure` is NOT merged into
`main` yet — merge awaits Samuel's go.
Last activity: 2026-10-10 — Phase 03 execution started

Progress: [███░░░░░░░] 29%

## Performance Metrics

**Velocity:**

- Total plans completed: 9 (Phase 1, waves 1-5)
- Average duration: -
- Total execution time: -

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 1 | 6/6 | - | - |
| 02 | 9 | - | - |

**Recent Trend:**

- Last 5 plans: 01-02, 01-03, 01-04, 01-05, 01-06 — all landed, all passed final
  acceptance re-verification
- Trend: on track; Phase 1 closed on the human gate 2026-09-17

*Updated after each plan completion*
**Per-Plan Metrics:**

| Plan | Duration | Tasks | Files |
|------|----------|-------|-------|
| Phase 02 P01 | 8min | 3 tasks | 4 files |
| Phase 02 P02 | 7min | 3 tasks | 3 files |
| Phase 02 P03 | 3min | 2 tasks | 2 files |
| Phase 02 P04 | 6min | 3 tasks | 3 files |
| Phase 02 P05 | 6min | 3 tasks | 25 files |
| Phase 02 P06 | 8min | 3 tasks | 3 files |
| Phase 03 P01 | 25 min | 2 tasks | 5 files |

## Accumulated Context

### Decisions

Two decisions taken by the mission manager during the Phase 2 planning mission (2026-09-17),
both with Samuel offline, both reversible, both recorded verbatim in
`.planning/phases/02-linter-test-harness/02-CONTEXT.md`:

- **D-24 — YAML typing: per-field schema in `lint.py` + minimal producer hardening.** Settled
  by a research panel over four options. The parser returns raw strings only (no implicit
  int/bool/null resolution); a per-field schema above it types `version`/`staleness_days` as
  ints and `consent_recorded` as a strict YAML 1.2 Core boolean (`true|True|TRUE` /
  `false|False|FALSE` unquoted only — `yes`, `1`, `"true"` are errors, never coerced to true,
  because that field is the gate that disables the confidential-name leak check). `init.py`
  keeps a pure serialisation rule: `re.fullmatch` (debt (b)) and quoting of YAML 1.1 reserved
  words (debt (a)), so `--language no` writes `language: "no"`. This closes both Phase 1 debts
  and aligns producer and consumer in one move, as the ROADMAP asked.
- **D-28 — the clean lint fixture is generated at test time, not committed.** D-28 and D-31
  were locked and not jointly satisfiable: git tracks no empty directory, so a committed
  scaffold silently drops `sources/transcripts/` and stops matching `init.py`'s output. D-31's
  purpose (producer and linter stay in sync) wins, because ROADMAP criterion 1 must assert
  something about the scaffolder. `tests/fixtures/lint/fr/` stays committed. The reversal is a
  scoped edit to plan 02-05, already written out in `02-01-PLAN.md`.

Earlier decisions are logged in PROJECT.md Key Decisions table. Four decisions from the Phase 1
mission, now validated by the phase's own delivery:

- Bootstrap: fixed English folder/file names, Markdown fact-lines over structured data, one
  router skill + five task skills, hooks-enforce-never-perform-work — all carried from the
  source spec's own alternatives-considered section (§9), validated by Phase 1's delivery.
- **D-05/D-06 — embedded skill resources, assumed deviation.** `skills/dossier-init/scripts/init.py`
  and `skills/dossier-init/templates/{en,fr}/` live inside the skill's own folder (Agent
  Skills bundled resources), while `scripts/lint.py` stays at the repo root. Spec §4 and
  `CLAUDE.md` were amended during this phase per `CLAUDE.md`'s own precedence rule (spec wins,
  this file follows). Reversal would be costly — treat as settled unless a strong reason
  emerges.
- **Synthetic adoption fixture.** The SCAF-06 test relies on a disposable fixture rebuilt from
  a *redacted* structural audit, and never touches the confidential origin repository. This
  goes stricter than D-13 required; kept deliberately rather than loosened back to the letter
  of the guarantee.
- **`allowed-tools` is not a security control.** Backed by documentation research: this
  frontmatter field is a pre-approval valid for the skill's turn, not a restriction — a tool
  absent from the list is never blocked, it just falls back to the normal permission prompt.
  Do not count it as a mitigation in any future threat model.
- **Correction budget exhausted at 3 rounds.** Two residual findings (see Deferred Items
  below) were classified as tracked debt rather than fixed in a 4th round.
- [Phase 02]: 02-01: sanitise_path also escapes C1 controls, surrogate-escaped bytes and U+2028/2029 (T-02-01 hardening beyond 0x00-0x1F/0x7F)
- [Phase 02]: 02-01: an invalid JSON dossier.yaml is C1 (exit 1), not unreadable (exit 2); a nonexistent PATH exits 2 with its own message
- [Phase 02]: 02-01: forged-name end-to-end \x0a assertion deferred to 02-02 (needs E4); pinned meanwhile by a direct report() probe, tracked in WINDOWS.md
- [Phase 02]: 02-02: status-header lines are anchored -- only comment syntax may precede a protocol field, so prose mentioning Deadline: is not a header
- [Phase 02]: 02-02: an unreadable non-binary outbound file is E1, never silently skipped
- [Phase 02]: 02-02: E5 searches the whole path below outbound/ and ignores the README exemption; E1-E4 honour it
- [Phase 02]: 02-03: the producer quotes any value whose casefold is a YAML 1.1 reserved spelling (YES/No too), and the allowlist uses fullmatch
- [Phase 02]: 02-03: a bash payload that must end in a newline needs a sentinel, command substitution strips it
- [Phase 02]: 02-04: E8 reads Tree.dirs from the single walk (pruning decided in one place); E9 is scoped to direct children of outbound/deliverables/, the reverse (source without render) silent
- [Phase 02]: 02-04: the nine-class sweep checks each e1..e9 fixture against all twelve other identifiers (C0 included) plus an exact 1/0 summary; W1/W2 are already in ALL_IDS for 02-05
- [Phase 02]: 02-04: generator refusal is proven with a logging mktemp shim on PATH, because macOS mktemp -d ignores TMPDIR
- [Phase 02]: 02-05: W1/W2 keep the uniform check(root, tree, config, findings) signature; an unlisted language skips both W1 and W2 with one info: line (D-20)
- [Phase 02]: 02-05: D-28 as amended applied -- tests/fixtures/lint/fr/ is the only committed lint fixture; a test asserts no tests/fixtures/lint/clean/ is tracked
- [Phase 02]: 02-06: round-trip test matches ^info: language 'no' exactly (the info line always contains 'no word list')
- [Phase 02]: 02-06: lint.py file-size window recorded as WINDOWS row 4; single file kept, split is a Phase 7 conversation
- [Phase 02]: gap closure (2026-09-25): CR-02: a near-miss of `confidential_names` stays C1 beside the exact key (consent_* near-misses keep the presence exemption) — arbitrage Samuel, relayed by the main session via SendMessage, 2026-09-25, option (a)
- [Phase 02]: gap closure (2026-09-25): CR-02 bis: the rule is OSA <= 1, or OSA <= 2 with the last `_` word within 1 edit of "name"/"names", so `confidential_notes` and `non_confidential_names` stay clean — arbitrage Samuel, relayed by the main session via SendMessage, 2026-09-25, option (2), superseding the first answer's literal "<= 2" wording (confidential_notes is 2 edits away, not 4+); the "name" alternative is a manager precision, strict direction, reversible
- [Phase 02]: gap closure (2026-09-25): D-FIX-13 (manager arbitration, reversible): `init.py` writes both readings (space, deletion) of a Unicode format character in a confidential name as two list entries when they differ
- [Phase 02]: gap closure (2026-09-25): the iteration-3 review and the iteration-2 fix report were preserved as `02-REVIEW.iter3.md` / `02-REVIEW-FIX.iter2.md` before being superseded
- [Phase 03]: 03-01: Bash guard also scans command-substitution bodies visible to shlex; opaque constructs stay allowed (D-04 heuristic)

### Pending Todos

- **Phase 3 planning** — mission `v1-phases-3-7` (2026-10-10) drives Phases 3-7 on per-phase
  branches; Phase 3 plans await Samuel's answers on the scenario pointer (research Q1) and the
  `dossier-status` sentence of the Stop hook (research Q2).

### Blockers/Concerns

- Phase 2 is merged into `main` (`6fbd08d`); its planning assumptions and the D-24/D-28
  arbitrations were validated at the 2026-10-10 sign-off.
- The Stop-hook question (spec §11 #3) is settled by `03-CONTEXT.md` D-01 (ships, block-once);
  the spec, `CLAUDE.md` and PROJECT.md are amended during Phase 3.
- `pdftotext` (poppler) is installed on the dev machine (`/opt/homebrew/bin/pdftotext`), checked
  2026-10-10 for Phase 4.
- `claude plugin validate . --strict` fails on a pre-existing warning about the root `CLAUDE.md`;
  without `--strict` it passes. `CLAUDE.md`'s command line is stale; fix in Phase 3 or 7.
- 03-02 Task 3: baseline gate FAILED (RED 0/3, GREEN 2/3 without the plugin; init.py's sources/README.md already prevents the edit). 03-05 cannot start without a recorded RED; Samuel to choose: extend P-01, harder prompt, weaker model, or relax D-10 (see 03-02-SUMMARY.md).

## Deferred Items

| Category | Item | Status | Deferred At | Milestone |
|----------|------|--------|-------------|-----------|
| Debt (Phase 1 → Phase 2) | (a) YAML 1.1 reserved words: `init.py`'s `_SAFE_PLAIN_SCALAR_RE` lets `yes/no/on/off/true/false/null/y/n` through unquoted; `--language no` writes `language: no`, read back as boolean `False` by a strict YAML parser. Not a vulnerability (no key injection; `consent_recorded` unreachable) — a typing-fidelity gap. Fix when writing `lint.py`'s YAML-subset parser, aligning producer and consumer in one move. | Resolved — 02-03 (`bd2ecd2`): `_YAML_RESERVED_SCALARS` routes reserved spellings to `yaml_quote()`; pinned by `tests/test-init-empty.sh` d14. Round-trip through the lint parser still due in 02-06 | 2026-09-16 (Phase 1 review, round 3) | v1 |
| Debt (Phase 1 → Phase 2) | (b) Regex anchoring: same regex's `$` also matches just before a trailing `\n` (vs. `\Z`/`re.fullmatch`); a value ending in a newline passes the allowlist and leaves a blank line. No key injection — cosmetic guard bypass. One-line fix, bundle with (a). | Resolved — 02-03 (`bd2ecd2`): `emit_scalar` uses `fullmatch`; pinned by `tests/test-init-empty.sh` d15 | 2026-09-16 (Phase 1 review, round 3) | v1 |
| Debt (Phase 2 review, iteration 3) | Three reproduced fail-open paths of the confidentiality gate (E5), each letting a confidential name under `outbound/` pass with exit 0; none introduced by the fix rounds: CR-01 `Outbound/` on a case-insensitive filesystem escapes every outbound check; CR-02 zero-width/BOM/soft-hyphen characters in a name survive `init.py` and defeat the text match; CR-03 HTML entities in an outbound `.html` hide names. Plus WR-01 (near-miss rule rejects legitimate extra keys like `consent_scope`), WR-02 (two untested lines), WR-03 (unreadable dir or `.git/` under `outbound/` skipped silently), WR-04 (name wrapped across `> ` quoted lines). Details: `02-REVIEW.md`. | Resolved — gap closure 2026-09-25 (02-07..02-09 + review-fix rounds, branch `feat/phase-02-gap-closure`); Samuel ordered the fix round in UAT item 4 | 2026-09-24 (Phase 2 review, iteration 3) | v1 |
| Debt (Phase 2 gap-closure review) | WR-01: E5 is blind only to Unicode category Cf, not the wider default-ignorable set (CGJ, variation selectors, Hangul fillers). OBS-01: no runtime rejection of a confidential name starting with `>`. CR-02 bis residual: a double typo landing inside the last word of a `confidential_names` misspelling beside the exact key stays ignored. Minor: `_osa_distance` has no internal length guard (safe only through its call sites). Details: `02-REVIEW-FIX.md`, `02-VERIFICATION.md`. | WR-01 resolved — `ce42a6a` (2026-10-10, every Default_Ignorable_Code_Point treated like Cf in `lint.py` and `init.py`). OBS-01, the CR-02 bis residual and the `_osa_distance` guard stay open as accepted v1 debt | 2026-09-25 (gap-closure review) | v1 |

## Session Continuity

Last session: 2026-10-10T13:04:23.305Z
Stopped at: 03-02 blocked at baseline gate (Tasks 1-2 done, Task 3 RED 0/3)
Resume file: .planning/phases/03-protocol-skill-hooks/03-02-SUMMARY.md
