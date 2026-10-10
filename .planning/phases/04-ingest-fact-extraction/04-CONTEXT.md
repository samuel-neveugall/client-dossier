# Phase 4: Ingest & Fact Extraction - Context

**Gathered:** 2026-10-10 (manager cadrage, Pattern F; Samuel's answers relayed by the main session)
**Status:** Ready for planning

<domain>
## Phase Boundary

`dossier-ingest <path or URL>` files a source under `sources/` exactly once, immutably, with
a `YYYY-MM-DD_slug` name, extracts PDF text next to the PDF, and turns the source into dated,
sourced lines in the living files through the read-only `fact-extractor` agent (or the
inline procedure on a harness without subagents). Requirements INGEST-01..INGEST-06. The
`dossier` skill gains its one-sentence pointer to `dossier-ingest` (03 D-07). Drafting, calls,
status, manifests and slash commands belong to Phases 5-7.

</domain>

<decisions>
## Implementation Decisions

### Asked to Samuel
- **D-01 (Q3, file date):** the date in `YYYY-MM-DD_slug` is the content's date when known (call date for a transcript, mail date, document date), otherwise the filing date. (arbitrage Samuel, AskUserQuestion session principale, 2026-10-10, option (a))
- **D-02 (Q4, URL):** a URL is downloaded as-is by the filing script (Python stdlib, no cookies, no authentication) into `sources/received/`; on failure (protected page, login) a message asks the user to download it manually and re-run on the local file. (arbitrage Samuel, AskUserQuestion session principale, 2026-10-10, option (a))
- **D-03 (Q5, applying the proposal):** the fact-extractor's proposal is applied directly to the living files, except the "uncertain" list which is only reported; then the skill reports what changed. Git is the undo net. Matches spec §4.1. (arbitrage Samuel, AskUserQuestion session principale, 2026-10-10, option (a))

### Manager decisions (tier 2, reversible, Samuel offline for these)
- **D-04 — Filing goes through a script, never the Write tool.** Phase 3 D-03 denies every
  Write/Edit under `sources/`, so the skill files a source with a private script
  `skills/dossier-ingest/scripts/file_source.py` (Python 3.8+, stdlib): it computes the
  target name, refuses to overwrite, copies (or downloads, per D-02), and prints a JSON
  result (`filed`, `already_filed` with the existing path, or an error). The Phase 3 Bash
  guard must let this command through: the plan includes a test that runs the real filing
  command through `hooks/guard-sources.py` and asserts it is allowed. — Reversal: none
  needed unless Phase 3's guard changes.
- **D-05 — `extract-text.sh` lives in the skill folder** (`skills/dossier-ingest/scripts/`),
  per Phase 1 D-05/D-06 (a script used by one skill is private to it; `dossier-call debrief`
  goes through `dossier-ingest`, it does not call the script directly). The skill still
  checks that the script exists before calling it (INGEST-06). Spec §4 tree amended. A bare
  `skills/` copy then keeps the extraction script, which is strictly better for DIST-03. —
  Reversal: move the file to `scripts/` and change one `${CLAUDE_SKILL_DIR}` reference.
- **D-06 — Duplicate detection is stateless:** SHA-256 of the incoming file compared with
  every regular file under `sources/` at ingest time (no manifest to keep in sync).
  INGEST-04 message names the existing path. — Reversal: add a manifest later if dossiers
  grow large.
- **D-07 — Folder by kind, decided by the skill:** call recordings and transcripts →
  `sources/transcripts/`, a raw machine export of a transcript (JSON, VTT, SRT) →
  `sources/transcripts/raw/` with the same stem as its transcript, everything else →
  `sources/received/`. The script takes `--kind`; the skill asks when it cannot tell.
- **D-08 — `fact-extractor` agent:** `agents/fact-extractor.md`, tools `Read, Grep, Glob`
  only, output format fixed in the agent file (grouped by target file and heading, each line
  with its locator; `contradicts` and `uncertain` lists). The skill holds the same procedure
  inline for harnesses without subagents and says when the main agent does it itself.
- **D-09 — Corrections are traceable:** a contradicted line is replaced and the new line ends
  with "(corrects a line dated <date>)" per spec §6.
- **D-10 — Pressure scenario (INGEST-05)** reuses the Phase 3 harness (`tests/scenarios/`):
  a transcript with timestamps is left outside `sources/`, prompt "here is the transcript of
  today's call, what did we learn?". RED = no new sourced line under `dossier/`. GREEN = the
  transcript filed under `sources/transcripts/` with a dated name, at least one new line in a
  living file carrying an `@mm:ss` locator, `Last updated:` refreshed, `lint.py` no new
  error. 3 runs per variant; ≥ 1 RED without the plugin, 3/3 GREEN with it (Phase 3 D-10).
- **D-11 — `dossier` skill pointer:** the one-sentence pointer to `dossier-ingest` lands in
  this phase (03 D-07), and `tests/test-skill-dossier.sh` picks it up automatically.

### Claude's Discretion
- Exact slug derivation, JSON shape of `file_source.py`'s output, the extractor's proposal
  markup, and test file names.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `docs/superpowers/specs/2026-09-16-client-dossier-design.md` §2.1-§2.4 (sources regime, fact
  line, session protocol "Ingest a source"), §3.2 (layout: `received/`, `transcripts/` + `raw/`,
  extractions next to PDFs), §3.4 (fact line), §4.1 `dossier-ingest`, §4.2 `fact-extractor`, §5
  (data flow), §6 (same hash, contradicted line, `pdftotext` missing, bare skills, no
  timestamps, no subagents), §7 scenario 2.
- `.planning/REQUIREMENTS.md` INGEST-01..INGEST-06.
- `.planning/phases/03-protocol-skill-hooks/03-CONTEXT.md` D-03 (Write/Edit denied under
  `sources/`), D-04/D-16 (Bash guard: copying a NEW file into `sources/` stays allowed, writing an
  existing one is denied), D-07 (pointer added when the skill lands), D-08..D-10/D-13/D-15
  (scenario harness method: AGENTS.md stripped in both variants, pressured prompt when the plain
  one is already GREEN without the plugin).
- `hooks/guard-sources.py`, `skills/dossier/SKILL.md`, `tests/scenarios/lib-scenario.sh`,
  `skills/dossier-init/` (house style: private scripts under the skill, `${CLAUDE_SKILL_DIR}`).
- `scripts/lint.py` (`find_root`, living-file rules the applied lines must satisfy).

</canonical_refs>

<specifics>
## Specific Ideas

- Samuel never runs tests; the team runs the scenario and records evidence (Phase 3 harness).
- Phase 3 lesson: a plain prompt in an init-scaffolded dossier may already behave without the
  plugin; record the baseline honestly and add realistic pressure (writing-skills) if needed.
- `pdftotext` is installed on the dev machine (`/opt/homebrew/bin/pdftotext`); the missing-tool
  path is tested by hiding it from `PATH`.

</specifics>

<deferred>
## Deferred Ideas

- Transcript fetchers for recording services (spec §4.1 "Not in v1").
- Pointers to `dossier-draft`, `dossier-call`, `dossier-status` (Phases 5-6).

</deferred>

---

*Phase: 04-ingest-fact-extraction*
*Context gathered: 2026-10-10 (manager cadrage; Samuel's answers Q3-Q5 relayed by the main session)*
