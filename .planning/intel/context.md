> Note (2026-10-10): snapshot of the 2026-09-16 ingestion; superseded by 03-CONTEXT D-01/D-03/D-04 and the amended spec §4.3. The body below is kept as ingested.

# Context

No DOC-classified documents were present in this ingest batch. The topics below are carried
over from the SPEC-classified document per explicit routing instruction from the ingest
orchestrator (the spec itself flags these as unresolved / sequencing information, not as
constraints or decisions).

## Open Decisions (unresolved by spec author)

- source: docs/superpowers/specs/2026-09-16-client-dossier-design.md (§11, "Open decisions
  for the author")
- status: OPEN — explicitly not decided by the source document. Do NOT treat as locked
  decisions. Do NOT auto-resolve downstream.
- items (verbatim from source):
  1. Final name. `client-dossier` is the working name; `dossier` alone is shorter but
     generic on a marketplace search.
  2. Folder names: `dossier/` versus `relationship/` for the living folder, `outbound/`
     versus `communication/`. The spec uses `dossier/` and `outbound/`. Whatever is chosen
     is fixed (i.e., once picked, not reconfigurable per-repository).
  3. Whether the Stop hook warning ships in v1 or waits for feedback (the spec ships it).
- provisional defaults currently in the spec text (NOT decisions — placeholders only,
  pending author resolution): working name `client-dossier`; folder names `dossier/` and
  `outbound/`; Stop hook shipped in v1.

## Implementation Order (spec §12 self-review)

- source: docs/superpowers/specs/2026-09-16-client-dossier-design.md (§12, "Spec
  self-review")
- content: "one implementation plan covers it; the plan will order init, lint, protocol
  skill, then ingest with the extractor, then draft with the reviewer, then call and
  status, then manifests and distribution." Verbatim ordering to preserve when the roadmap
  is produced: init → lint → protocol skill `dossier` → ingest + fact-extractor → draft +
  doctrine-reviewer → call and status → manifests and distribution.

## Testing approach (baseline scenarios)

- source: docs/superpowers/specs/2026-09-16-client-dossier-design.md (§7)
- content: skills are tested per `superpowers:writing-skills` — a pressure scenario is run
  without the skill, the failure recorded, the skill written to address it, the scenario
  rerun. Five baseline scenarios recorded before writing each skill: (1) "write a quick
  reply to the client" — expected failure without skill: writes inline, never reads tone,
  never updates history, may name the confidential party; (2) given a transcript, "what
  did we learn" — expected failure: summary in chat, nothing filed, no timestamps; (3)
  "fix the typo in the transcript" — expected failure: edits the source; (4) "where are we
  with this deal" — expected failure: re-reads everything, answers from memory, misses due
  commitments; (5) "prepare tomorrow's call" — expected failure: writes "tomorrow", does
  not pull open questions, no "what we do not do" section. Mechanical tests: fixture
  repositories (clean layout + one French-language dossier fixture for relative-date/
  opinion-marker word lists) with a bash test runner asserting `lint.py` exit codes and
  messages; no test framework beyond bash and python3. Plugin-level: `claude plugin eval`
  suites for trigger descriptions once skills exist.

## Note on repository root CLAUDE.md

- source: (orchestrator instruction, not an ingest source)
- content: the repository root already has a `CLAUDE.md` derived from this spec. It was
  explicitly excluded from this ingest batch and was not read or synthesized as a source
  document here.
