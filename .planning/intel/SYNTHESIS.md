# Synthesis Summary

Ingest mode: `new`. Precedence order: ADR > SPEC > PRD > DOC (no per-doc overrides present).

## Doc counts by type

- Total classifications consumed: 1
- SPEC: 1 — `docs/superpowers/specs/2026-09-16-client-dossier-design.md` (confidence: high,
  locked: false)
- ADR: 0
- PRD: 0
- DOC: 0
- UNKNOWN / low-confidence: 0

## Cycle detection

Cross-ref graph built from the single classification's `cross_refs`. All referenced paths
(plugin manifests, `skills/*/SKILL.md`, `AGENTS.md`, `CLAUDE.md`, `README.md`, `LICENSE`,
`CHANGELOG.md`) are not-yet-created plugin artifacts, not other classified documents — no
edges into the classified set, no cycle. Traversal depth: 1 (well under the cap of 50).

## Decisions (decisions.md)

0 decisions extracted — no ADR-classified documents in this batch. See
`intel/decisions.md` for the empty-batch note and a pointer to the open-decisions content
in `context.md`.

## Requirements (requirements.md)

0 requirements extracted — no PRD-classified documents in this batch. See
`intel/requirements.md`.

## Constraints (constraints.md)

18 constraint entries extracted from the single SPEC, all sourced to
`docs/superpowers/specs/2026-09-16-client-dossier-design.md`:

- schema (4): dossier folder structure (four regimes), seven living dossier files,
  `dossier.yaml` config schema, plugin repository layout
- protocol (5): outbound status header format, fact line format, session protocol
  (read-before-act / update-before-handoff), hooks behavior, data flow
- api-contract (2): skills interface (six skills), agents interface (fact-extractor,
  doctrine-reviewer)
- nfr (7): what the agent never does, linter checks, error handling and edge cases,
  distribution mechanisms, scope of v1, alternatives considered (rejected designs)

## Context (context.md)

3 topics recorded, all sourced to the same SPEC document (plus one orchestrator note):

- Open Decisions (unresolved by spec author) — §11: final plugin name; `dossier/` vs
  `relationship/` and `outbound/` vs `communication/`; whether the Stop hook ships in v1.
  Recorded as OPEN, not locked, with the spec's provisional defaults noted separately.
- Implementation Order — §12: init → lint → protocol skill `dossier` → ingest +
  fact-extractor → draft + doctrine-reviewer → call and status → manifests and
  distribution. Preserve this ordering when building the roadmap.
- Testing approach (baseline scenarios) — §7.
- Note: repository root `CLAUDE.md` (derived from this spec) was explicitly excluded as an
  ingest source per orchestrator instruction; not read or synthesized here.

## Conflicts

0 blockers, 0 competing-variants, 0 auto-resolved. Single-document batch; no doc-to-doc
precedence conflicts possible. Full detail (including why each of the 7 detection passes
found nothing): `.planning/INGEST-CONFLICTS.md`.

## For gsd-roadmapper

- Read `intel/constraints.md` for the full plugin architecture, folder layout, skills/agents
  interfaces, hooks, linter, and distribution rules — this is the bulk of the design intent.
- Read `intel/context.md` first for the three open decisions before naming anything in
  PROJECT.md/ROADMAP.md; the plugin name and two folder names are NOT locked and must be
  confirmed with the user rather than assumed from the spec's provisional defaults.
- Preserve the implementation order recorded in `intel/context.md` when sequencing roadmap
  phases.
- `intel/decisions.md` and `intel/requirements.md` are empty for this batch (no ADR/PRD
  sources) — do not infer decisions or requirements that aren't present in
  `intel/constraints.md`.
- `.planning/INGEST-CONFLICTS.md` has 0 blockers and 0 warnings — safe to route without a
  user gate on conflicts, but the open-decisions gate above still applies independently.
