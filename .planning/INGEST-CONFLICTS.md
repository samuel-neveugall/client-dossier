## Conflict Detection Report

### BLOCKERS (0)

None detected.

### WARNINGS (0)

None detected.

### INFO (0)

None detected.

---

Notes:
- Classifications consumed: 1 (`docs/superpowers/specs/2026-09-16-client-dossier-design.md`,
  type SPEC, confidence high, locked: false). No ADR, PRD, or DOC classifications, and no
  UNKNOWN / low-confidence classifications, were present in this batch.
- Cross-ref graph: the classified document's `cross_refs` point to plugin artifacts that do
  not yet exist as ingested documents (`.claude-plugin/plugin.json`, `skills/*/SKILL.md`,
  `AGENTS.md`, `CLAUDE.md`, `README.md`, `LICENSE`, `CHANGELOG.md`, etc.) — none of these
  match another classified source, so the cross-ref graph has a single node with no edges
  into the classified set. Cycle detection ran; no cycle found.
- Because there is exactly one classified document and no existing `.planning/` context to
  check against (MODE=new), none of the seven conflict-detection passes (LOCKED-vs-LOCKED,
  ingest-vs-existing-locked, PRD-variant-overlap, SPEC-vs-ADR, lower-vs-higher precedence,
  UNKNOWN-low-confidence, cycle) produced any findings.
- The source document's own §11 ("Open decisions for the author") lists three items the
  author has not yet decided (plugin name; `dossier/` vs `relationship/` and `outbound/` vs
  `communication/`; whether the Stop hook ships in v1). These are NOT doc-to-doc precedence
  conflicts (there is only one document), so they do not populate this report's buckets.
  They are recorded verbatim, with their provisional defaults, in
  `.planning/intel/context.md` under "Open Decisions (unresolved by spec author)" for
  `gsd-roadmapper` to surface to the user before locking any of the three names.
