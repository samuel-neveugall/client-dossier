# Phase 2: Linter & Test Harness - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-09-17
**Phase:** 2-Linter & Test Harness
**Areas discussed:** Invocation and root discovery, Error/warning boundary and error classes,
Language word lists, `dossier.yaml` parsing and the Phase 1 debt, Test harness and fixtures

> **No user in the loop.** Samuel was offline. Every option marked ✓ was selected from the
> spec, the ROADMAP, REQUIREMENTS.md, `CLAUDE.md` or the Phase 1 code; where no source
> settled the question, the conservative option was taken and recorded as an assumption
> (A-01…A-06) in `02-CONTEXT.md`. None of these selections is Samuel's answer.

---

## Invocation and root discovery

| Option | Description | Selected |
|--------|-------------|----------|
| Optional `PATH`, walk upward to nearest `dossier.yaml` | Mirrors spec §3.2 root discovery for every component | ✓ |
| Root must be passed explicitly | No upward walk | |
| Lint the whole repository tree | Every dossier at once | |

| Option | Description | Selected |
|--------|-------------|----------|
| Exit 2 when no dossier is found | Keeps exit 1 == "this dossier has errors" | ✓ (A-01) |
| Exit 1 when no dossier is found | Conflates "not a dossier" with "malformed" | |
| Exit 0 and say nothing | Silent no-op | |

| Option | Description | Selected |
|--------|-------------|----------|
| `path:line: LEVEL [ID] message`, sorted, plus a summary line | Grep-able, stable for tests | ✓ |
| Free prose findings | | |
| JSON output | Not in the spec; no consumer yet | |

**Selected from:** spec §3.2 / §4.4, ROADMAP criteria 1–3.
**Notes:** stable identifiers `E1…E9`, `W1`, `W2` become the assertion surface of the test
file (D-05) — renaming one later is costly.

---

## Error/warning boundary and error classes

| Option | Description | Selected |
|--------|-------------|----------|
| Nine error IDs mapped 1:1 onto ROADMAP criterion 2, warnings for the two language heuristics | Spec §4.4 checks 5 and 6 are explicitly warnings | ✓ |
| All eight spec checks as errors | Would make exit 1 mean "this prose looks suspicious" | |
| Configurable severity per check | New surface, no requirement asks for it | |

| Option | Description | Selected |
|--------|-------------|----------|
| `README.md` under `outbound/` exempt from the outbound checks | Phase 1's own `README-outbound.md` quotes `Deadline: YYYY-MM-DD` verbatim | ✓ |
| No exemption | Every scaffolded dossier would fail its own linter | |

| Option | Description | Selected |
|--------|-------------|----------|
| Complete header = `Status:` + `To:` + `Written by:` (+ `Subject:` for mails) | Narrow set; `Rules:` unchecked in v1 | ✓ (A-02) |
| All six fields of spec §3.3 required | Makes `Rules:` mandatory everywhere | |

| Option | Description | Selected |
|--------|-------------|----------|
| Absent living file reported under E7 | Layout is fixed; `init.py` creates all seven | ✓ (A-04) |
| Silent on absent living files | | |

**Selected from:** spec §3.3, §4.4; ROADMAP criterion 2; `templates/en/README-outbound.md`.
**Notes:** the seven E7 files are exactly the seven `dossier/` templates that carry
`Last updated:`; `knowledge/CONTEXT.md` and `DOCTRINE.md` do not, verified in the Phase 1
templates.

---

## Language word lists

| Option | Description | Selected |
|--------|-------------|----------|
| One `LANGUAGE_WORDS` constant in `lint.py`, `en` + `fr` | Language data, physically separate from the protocol keywords | ✓ |
| External data file per language | Extra file for a stdlib-only single-script check | |
| Per-language label table | **Forbidden** by `CLAUDE.md` and spec §3.2 | |

| Option | Description | Selected |
|--------|-------------|----------|
| Short high-precision v1 lists | A warning that fires too often gets ignored | ✓ (A-06) |
| Exhaustive lists | False positives on ordinary prose | |

| Option | Description | Selected |
|--------|-------------|----------|
| Unknown language → skip the two warning checks with a note | Never an error, never a crash | ✓ |
| Unknown language → fall back to English | Nonsense warnings on foreign text | |

**Selected from:** spec §4.4 closing sentence, `CLAUDE.md`.
**Notes:** text is NFC-normalised before matching so accented French words written NFD (macOS)
still match.

---

## `dossier.yaml` parsing and the Phase 1 debt

| Option | Description | Selected |
|--------|-------------|----------|
| Parse only the seven keys the linter needs, ignore the rest | `counterparts` is never used by lint | ✓ |
| Full YAML-subset object model | Larger surface for no requirement | |

| Option | Description | Selected |
|--------|-------------|----------|
| String-valued keys read as strings whatever the spelling (`language: no` → `"no"`) | Consumer-side half of Phase 1 debt (a) | ✓ |
| Apply YAML 1.1 boolean coercion | Reintroduces the Norwegian bug | |

| Option | Description | Selected |
|--------|-------------|----------|
| Tighten `init.py`'s producer allowlist as well (debts (a) + (b)) | **NOT SELECTED HERE** | — |
| Consumer-only fix | **NOT SELECTED HERE** | — |

| Option | Description | Selected |
|--------|-------------|----------|
| JSON fallback reuses the fixed `dossier.yaml` filename (content starting with `{`) | Keeps the fixed-name invariant every component depends on | ✓ (A-05) |
| Separate `dossier.json` file | Forks root discovery across the plugin | |

**Selected from:** spec §3.2, §4.4; ROADMAP "Carried-over debt from Phase 1"; `init.py`.
**Notes:** the producer-vs-consumer question is a **decision in progress, arbitrated by the
manager** (a panel is running in parallel) — deliberately left unselected above and recorded
as D-24 in CONTEXT.md. D-23 holds whichever way it lands.

---

## Test harness and fixtures

| Option | Description | Selected |
|--------|-------------|----------|
| New `tests/test-lint.sh`, dispatcher untouched, `lib.sh` extended additively | `run.sh` states adding a test file needs no edit — verified | ✓ |
| Rewrite the harness around the linter | Phase 1's five test files must keep passing | |

| Option | Description | Selected |
|--------|-------------|----------|
| Clean + French fixtures committed; error fixtures generated at runtime, one per class | `.claude/` is gitignored at any depth, so E8 cannot be committed; per-class isolation catches false positives | ✓ |
| All fixtures committed | E8 impossible without fighting `.gitignore` | |
| One mega error fixture | A crashing check would hide the others | |

| Option | Description | Selected |
|--------|-------------|----------|
| Assert exit code + finding identifier | Message prose can be tuned freely | ✓ |
| Golden output files | A diff would fail on wording alone | |

| Option | Description | Selected |
|--------|-------------|----------|
| Build the clean fixture by running `init.py` | Keeps producer and linter in sync | ✓ |
| Hand-write the clean fixture | Drifts from the templates | |

**Selected from:** `tests/run.sh`, `tests/lib.sh`, `tests/fixtures/make-adopt-fixture.sh`,
`.gitignore`, spec §7, ROADMAP criteria 1–4.
**Notes:** a freshly scaffolded dossier must produce zero errors **and** zero warnings — the
sharpest acceptance test of the phase.

---

## Claude's Discretion

- Internal structure of `lint.py` (function decomposition, check ordering, single walk vs
  per-check walk).
- Exact message wording after each `[ID]` token.
- Internal shape of `tests/fixtures/make-lint-fixtures.sh` and how the clean fixture is
  materialised from `init.py`.

## Deferred Ideas

- `dossier-lint` command and the `dossier-status` call into the linter — Phases 6/7.
- Bare-skills fallback prose for skills that call `lint.py` — Phases 3/5/6.
- `--fix` / `--format json` modes — not in the spec, no consumer.
- Word lists beyond `en`/`fr` — driven by a real third-language dossier.
- Git-aware linting of changed files only — out of scope.
