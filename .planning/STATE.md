---
gsd_state_version: "1.0"
current_phase: 02
current_phase_name: Linter & Test Harness
status: ready-to-execute
stopped_at: Phase 2 planned and plan-checked; execution awaits Samuel's go
last_updated: "2026-09-17T11:17:54.350Z"
last_activity: 2026-09-17
last_activity_desc: Phase 02 discussed, planned (6 plans / 5 waves) and plan-checked — ready to execute
state_head: 0e6c0ec2f67ebbb6d7b526db9dcaa3ed5b62e3dc
progress:
  total_phases: 7
  completed_phases: 1
  total_plans: 12
  completed_plans: 6
  percent: 14
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-09-16)

**Core value:** Every agent session in a dossier repository reads the living dossier before
acting and updates it before handing back — so nothing reaches the counterpart without a
human and a doctrine check.
**Current focus:** Phase 02 — Linter & Test Harness (planned, plan-checked, ready to execute)

## Current Position

Phase: 02 (Linter & Test Harness) — PLANNED, READY TO EXECUTE
Plan: 02-01 … 02-06 (6 plans, 5 waves, 17 tasks) — none executed yet
Status: planning-only mission run 2026-09-17 (context → plans → plan-check). `gsd-plan-checker`
passed on its second pass. Carried-over debts (a) and (b) are absorbed by plan 02-03 under the
D-24 arbitration below. Execution is deliberately NOT started: it is a separate mandate Samuel
must green-light.
Last activity: 2026-09-17 — Phase 1 closed. Before that, 2026-09-16 — independent acceptance re-verification passed after 3
review/fix rounds; SCAF-01…08 (8/8) and the 5 ROADMAP success criteria reproduced
independently, including SCAF-06 replayed against the real origin repository under the
confidentiality protocol. REQUIREMENTS.md (42 reqs), ROADMAP.md, PROJECT.md and CLAUDE.md
resynchronised with the delivered code.

Progress: [░░░░░░░░░░] 0%

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

### Pending Todos

- **Phase 2 execution** — plans 02-01…02-06 are ready; awaiting Samuel's go.
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
| Debt (Phase 1 → Phase 2) | (a) YAML 1.1 reserved words: `init.py`'s `_SAFE_PLAIN_SCALAR_RE` lets `yes/no/on/off/true/false/null/y/n` through unquoted; `--language no` writes `language: no`, read back as boolean `False` by a strict YAML parser. Not a vulnerability (no key injection; `consent_recorded` unreachable) — a typing-fidelity gap. Fix when writing `lint.py`'s YAML-subset parser, aligning producer and consumer in one move. | Planned — plan 02-03 (D-24 rule), not yet executed | 2026-09-16 (Phase 1 review, round 3) | v1 |
| Debt (Phase 1 → Phase 2) | (b) Regex anchoring: same regex's `$` also matches just before a trailing `\n` (vs. `\Z`/`re.fullmatch`); a value ending in a newline passes the allowlist and leaves a blank line. No key injection — cosmetic guard bypass. One-line fix, bundle with (a). | Planned — plan 02-03 (`re.fullmatch`), not yet executed | 2026-09-16 (Phase 1 review, round 3) | v1 |

## Session Continuity

Last session: 2026-09-17 — Phase 2 planning mission (context, plans, plan-check).
Stopped at: Phase 2 planned and verified; execution not started, awaiting Samuel's go.
Resume file: .planning/phases/02-linter-test-harness/02-01-PLAN.md
