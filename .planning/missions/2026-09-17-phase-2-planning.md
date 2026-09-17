# Mission — Phase 2 "Linter & Test Harness", planning only

**Date:** 2026-09-17 · **Manager:** vf-dev-manager · **Repo:** `client-dossier`, branch `main`
**Range:** `241029f` → HEAD · **Mandate:** take Phase 2 to a plan-checked, ready-to-execute
state. **No execution.** Samuel offline throughout.

## Battle plan (DAG)

| Node | Worker | Status |
|------|--------|--------|
| `panel-yaml` — arbitrate the Phase 1 typing debt (producer vs consumer) | `gsd-advisor-researcher` | done |
| `discuss-02` — phase context | `vf-coder` (cadrage-only mandate) | done |
| `plan-02` — plans + plan-check | `vf-coder` (planning-only mandate) | done |
| `docs` — STATE / ROADMAP / context hygiene | manager | done |

`panel-yaml` and `discuss-02` ran in parallel (disjoint scopes: the panel wrote nothing, the
cadrage wrote only under `.planning/phases/02-linter-test-harness/`).

Driver lock held under owner `mission-phase2-planning`, generation
`DRIVER.lock.gen.1789639251.87804`, released at close.

## Produced

- `.planning/phases/02-linter-test-harness/02-CONTEXT.md` — 31 decisions (D-01…D-31),
  assumptions A-01…A-06
- `.planning/phases/02-linter-test-harness/02-DISCUSSION-LOG.md`
- `.planning/phases/02-linter-test-harness/02-RESEARCH.md`, `02-PATTERNS.md`, `02-VALIDATION.md`
- `.planning/phases/02-linter-test-harness/02-01-PLAN.md` … `02-06-PLAN.md` — 6 plans,
  5 waves, 17 tasks
- Tracking: `.planning/STATE.md`, `.planning/ROADMAP.md` (§Plans, progress table)

Wave map: **W1** 02-01 (root discovery, YAML-subset parser + per-field schema, pruned walk, E7,
report, exit codes 0/1/2, `lib.sh` helpers, fixture generator, `test-lint.sh`, config gate) ·
**W2** 02-02 ∥ 02-03 (outbound error classes E1–E5 · producer hardening, debts (a)/(b)) ·
**W3** 02-04 (E8, E9, generator contract, positive **and** negative nine-class sweep) ·
**W4** 02-05 (W1/W2 warnings, `LANGUAGE_WORDS`, committed French fixture) · **W5** 02-06
(zero-finding acceptance in `en` and `fr`, producer/consumer round trip, `CLAUDE.md` commands).

## Plan-check verdict (verbatim, 2 rounds)

- Round 1 — `## VERIFICATION — ISSUES FOUND`, 1 blocker, 0 warnings, 0 info. Dimension
  `context_compliance`: *"Plans must not silently override a locked CONTEXT.md Decision"*
  (D-28 contradicted without a surfaced deviation).
- Round 2 — `## VERIFICATION PASSED` — *"Plans verified. All checks pass — the previously
  reported BLOCKER is resolved"*, with the non-blocking note: *"the D-28 deviation is
  explicitly unarbitrated — `02-01-PLAN.md` § 'Deviation from locked decision D-28' needs your
  call"*.

Research: completed · Requirements 3/3 (LINT-01/02/03) · Decisions 31/31 · Gap analysis: none.

`estimate:` carried by the plans, relayed verbatim (`confidence: low` on all six): 02-01
78 000 tok / 3 tasks · 02-02 62 000 / 3 · 02-03 28 000 / 2 · 02-04 52 000 / 3 · 02-05 60 000 / 3
· 02-06 38 000 / 3. Total 318 000 tokens, 17 tasks.

## Manager arbitrations (Samuel offline, both reversible)

**D-24 — YAML typing strategy.** Panel over four options; retained **option D**: per-field
schema in `lint.py` above a parser that returns raw strings only, plus a minimal typographic
hardening of `init.py`. `consent_recorded` is a strict YAML 1.2 Core boolean, unquoted only —
`yes`, `1`, `"true"` are errors, never coerced to true, because that field is the gate that
disables the confidential-name leak check. `--language no` becomes `language: "no"`. Closes
Phase 1 debts (a) and (b) in one move, as the ROADMAP asked. Measured regression cost on
Phase 1: ~4 lines in `init.py` (2 call sites), 0 golden to regenerate, no existing assertion
touched.

**D-28 — the clean lint fixture is generated at test time, not committed.** D-28 and D-31 were
both locked and not jointly satisfiable: git tracks no empty directory, so a committed scaffold
silently drops `sources/transcripts/` and stops matching `init.py`'s output — which would turn
ROADMAP criterion 1 into a tautology about the fixture instead of a statement about the
scaffolder. D-31's purpose wins; `tests/fixtures/lint/fr/` stays committed; the "readable
reference" role moves to that tree plus a documented header on `make-lint-fixtures.sh`. The
rejection path is a scoped edit to plan 02-05, fully written out in `02-01-PLAN.md` — no
replan, no wave moves.

## Assumptions to validate with Samuel (none blocks execution)

From the cadrage — A-01 exit 2 when no `dossier.yaml` is found · A-02 a "complete" header is
`Status:` + `To:` + `Written by:` (+ `Subject:` under `mails/`), `Rules:` unchecked in v1 ·
A-03 slug charset `[a-z0-9]+(-[a-z0-9]+)*` (most likely to be loosened in use) · A-04 a missing
living file is reported as E7 · A-05 the JSON fallback reuses the fixed name `dossier.yaml`
(content starting with `{`), no `dossier.json` · A-06 the exact v1 word lists.

From planning — Q-1…Q-6 settled on the research recommendation: `C1`/`C0` namespace for config
errors · `staleness_days: "7"` accepted · absent `version` = 1 · unconditional reporting with no
stop condition · README exemption limited to E1–E4, E5 stays active · `lint.py` a single file
with a declared size window.

## Open points, untouched by design

- Stop hook in v1 — Phase 3 decision, with Samuel (spec §11 #3).
- `allowed-tools` / `${CLAUDE_SKILL_DIR}` interpolation — left open, not settled by the
  Phase 1 recette.
- `claude plugin validate --strict` and the `author` field — Phase 7.
- One `unclassified` row from the edge probe on LINT-03, left `unresolved` rather than closed
  with an invented edge (LINT-03 is a harness requirement with no data-shape axis).

## Load-bearing finding surfaced during the cadrage

The Phase 1 template `README-outbound.md` quotes the status header verbatim (`Deadline:
YYYY-MM-DD`, `sent <date time> by <name>`). Without a README exemption, **a freshly scaffolded
dossier fails its own linter**. Phase 2's acceptance criterion is therefore "a scaffolded
dossier lints with 0 errors AND 0 warnings" (plans 02-01 and 02-06).

## Infrastructure notes

- `check-mission-invariants.sh` returned INDÉTERMINÉ (`.planning/MISSION-INVARIANTS.md` absent):
  no invariant was verified, none is cited as evidence anywhere in this mission.
- `gsd_run` is not on PATH, so the two auto-chaining flags could not be reset through it.
  Inspected directly instead: `.planning/config.json` has `workflow.auto_advance: false` and no
  `workflow._auto_chain_active` key — both triggers disarmed.
- Commit attribution follows the trailer in force for this session,
  `Co-Authored-By: Claude Opus 5 (1M context)`. The mission brief asked for a different
  co-author line; the session-level instruction takes precedence and history was not rewritten.

## Next step

Execute Phase 2 — `gsd-execute-phase` on plans 02-01…02-06, wave by wave. Before the first
wave, Samuel confirms (or reverses) the D-28 arbitration above; every other assumption can wait
for the end-of-phase recette.
