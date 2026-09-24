---
gsd_state_version: "1.0"
current_phase: 02
current_phase_name: Linter & Test Harness
status: verifying
stopped_at: Phase 2 executed and verified (4/4 criteria); human recette pending (02-UAT.md)
last_updated: "2026-09-24T20:17:08.097Z"
last_activity: 2026-09-24
last_activity_desc: Phase 02 executed (6/6 plans), 3 review iterations, verification human_needed
state_head: 87c5f26c4011c530e36047422254c879a7f73ef1
progress:
  total_phases: 7
  completed_phases: 1
  total_plans: 12
  completed_plans: 12
  percent: 14
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-09-16)

**Core value:** Every agent session in a dossier repository reads the living dossier before
acting and updates it before handing back — so nothing reaches the counterpart without a
human and a doctrine check.
**Current focus:** Phase 02 — Linter & Test Harness

## Current Position

Phase: 02 (Linter & Test Harness) — EXECUTED, VERIFIED, AWAITING HUMAN RECETTE
Plan: 6 of 6 complete (02-01 … 02-06)
Status: all six plans landed on 2026-09-24. `02-VERIFICATION.md` reports `human_needed` with the
four ROADMAP criteria and both Phase 1 debts verified independently (`bash tests/run.sh`:
6 files, 0 failed; `tests/test-lint.sh`: 1290 assertions). The code review ran its full
3-iteration budget (`02-REVIEW.iter1.md`, `02-REVIEW.iter2.md`, `02-REVIEW.md`): 12 then 7
findings fixed with regression tests (`02-REVIEW-FIX.iter1.md`, `02-REVIEW-FIX.md`);
iteration 3 found 3 older critical paths plus 4 warnings, kept as tracked debt below.
The phase is NOT marked complete: `02-UAT.md` holds four items for Samuel.
Last activity: 2026-09-24 — phase 2 execution, review/fix loop, verification.

Progress: [█░░░░░░░░░] 14%

## Performance Metrics

**Velocity:**

- Total plans completed: 6 (Phase 1, waves 1-5)
- Average duration: -
- Total execution time: -

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 1 | 6/6 | - | - |

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

### Pending Todos

- **Phase 2 recette** — `/gsd-verify-work 02` walks the four items of `02-UAT.md`: three
  design calls taken by the fixer (D-FIX-8 narrows locked D-22; D-FIX-9/10 near-miss key
  threshold; D-FIX-3 broadened name matching) and the fate of the iteration-3 residuals.
- **Validate the planning assumptions** A-01…A-06 (`02-CONTEXT.md` § Assumptions) and Q-1…Q-6
  (`02-01-PLAN.md`) at the end-of-phase recette; none of them blocks execution.
- **Review two manager arbitrations** taken with Samuel offline: D-24 (typing strategy) and
  D-28 (clean fixture generated, not committed). Both are reversible; D-28's reversal path is
  written out in `02-01-PLAN.md`.

### Blockers/Concerns

- **A freshly scaffolded dossier would fail its own linter** unless the README exemption is
  implemented: the Phase 1 template `README-outbound.md` quotes the status header verbatim
  (`Deadline: YYYY-MM-DD`, `sent <date time> by <name>`). Phase 2's acceptance criterion is
  therefore "a scaffolded dossier lints with 0 errors AND 0 warnings" (plans 02-01, 02-06).
- **Phase 3 planning must decide** whether the Stop hook ships in v1 (spec §11 #3), with
  Samuel — not unilaterally.
- `pdftotext` (poppler) is an external dependency of Phase 4 with a defined fallback; check
  it is installed on the dev machine before Phase 4.

## Deferred Items

| Category | Item | Status | Deferred At | Milestone |
|----------|------|--------|-------------|-----------|
| Debt (Phase 1 → Phase 2) | (a) YAML 1.1 reserved words: `init.py`'s `_SAFE_PLAIN_SCALAR_RE` lets `yes/no/on/off/true/false/null/y/n` through unquoted; `--language no` writes `language: no`, read back as boolean `False` by a strict YAML parser. Not a vulnerability (no key injection; `consent_recorded` unreachable) — a typing-fidelity gap. Fix when writing `lint.py`'s YAML-subset parser, aligning producer and consumer in one move. | Resolved — 02-03 (`bd2ecd2`): `_YAML_RESERVED_SCALARS` routes reserved spellings to `yaml_quote()`; pinned by `tests/test-init-empty.sh` d14. Round-trip through the lint parser still due in 02-06 | 2026-09-16 (Phase 1 review, round 3) | v1 |
| Debt (Phase 1 → Phase 2) | (b) Regex anchoring: same regex's `$` also matches just before a trailing `\n` (vs. `\Z`/`re.fullmatch`); a value ending in a newline passes the allowlist and leaves a blank line. No key injection — cosmetic guard bypass. One-line fix, bundle with (a). | Resolved — 02-03 (`bd2ecd2`): `emit_scalar` uses `fullmatch`; pinned by `tests/test-init-empty.sh` d15 | 2026-09-16 (Phase 1 review, round 3) | v1 |
| Debt (Phase 2 review, iteration 3) | Three reproduced fail-open paths of the confidentiality gate (E5), each letting a confidential name under `outbound/` pass with exit 0; none introduced by the fix rounds: CR-01 `Outbound/` on a case-insensitive filesystem escapes every outbound check; CR-02 zero-width/BOM/soft-hyphen characters in a name survive `init.py` and defeat the text match; CR-03 HTML entities in an outbound `.html` hide names. Plus WR-01 (near-miss rule rejects legitimate extra keys like `consent_scope`), WR-02 (two untested lines), WR-03 (unreadable dir or `.git/` under `outbound/` skipped silently), WR-04 (name wrapped across `> ` quoted lines). Details: `02-REVIEW.md`. | Open — review budget spent; Samuel decides (UAT item 4) between a gap-closure round and deferral | 2026-09-24 (Phase 2 review, iteration 3) | v1 |

## Session Continuity

Last session: 2026-09-24T20:17:08.077Z
Stopped at: Phase 2 verified (human_needed); recette pending
Resume file: .planning/phases/02-linter-test-harness/02-UAT.md
