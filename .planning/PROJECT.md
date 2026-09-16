# client-dossier

## What This Is

`client-dossier` is a plugin for
coding agents (Claude Code first, then Codex, Cursor, Copilot CLI, Gemini CLI, OpenCode via
the Agent Skills standard) that turns a git repository into the memory and workbench of a
relationship with an external party: a client, partner, prospect, or intermediary. It
codifies a method built by hand inside a live consulting engagement — immutable sources, a
living dossier where every fact is dated and sourced, an outbound folder where every draft
carries a status header and only a human sends it, and a doctrine every outgoing document is
checked against — and makes that contract portable across repositories and harnesses.

## Core Value

Every agent session in a dossier repository reads the living dossier before acting and
updates it before handing back — so a human never has to re-read everything to know where
things stand, and nothing reaches the counterpart without passing through a human and the
doctrine check.

## Business Context

- **Customer**: Developers and consultants who run coding agents against a client/prospect
  relationship repository (starting with the plugin author's own consulting practice).
- **Revenue model**: None — MIT-licensed, distributed via plugin marketplaces (Claude Code,
  Codex) and the Agent Skills standard.
- **Success metric**: v1 scope of spec §10 fully delivered — six skills, two agents, three
  hooks, `lint.py`, templates, both manifests (`.claude-plugin/`, `.codex-plugin/`), a README
  with per-harness install instructions, fixtures + bash lint tests passing, and baseline
  pressure scenarios recorded for each skill (writing-skills RED→GREEN).
- **Strategy notes**: `docs/superpowers/specs/2026-09-16-client-dossier-design.md` (source
  spec, full design detail).

## Requirements

### Validated

(None yet — no code written, nothing shipped.)

### Active

v1 scope, drawn from the design spec (full detail and IDs in REQUIREMENTS.md):

- [ ] Scaffold: `dossier-init` skill, folder layout, `dossier.yaml`, seven living-file templates
- [ ] Linter: `scripts/lint.py` (stdlib-only, 8 checks), fixtures, bash test runner
- [ ] Protocol: `dossier` skill (always-first, layout + protocol + fact/status formats) and
      the three hooks (SessionStart, PreToolUse guard, Stop warning)
- [ ] Ingest: `dossier-ingest` skill, `fact-extractor` agent, `extract-text.sh`
- [ ] Draft: `dossier-draft` skill, `doctrine-reviewer` agent
- [ ] Call & status: `dossier-call` (prepare/debrief) and `dossier-status` skills
- [ ] Distribution: both manifests, `commands/*.md`, README/LICENSE/CHANGELOG, plugin eval
      of trigger descriptions

### Out of Scope

- Transcript fetchers for recording services — origin project had one shell fetcher; v1
  accepts a local file only, `fetchers/` deferred.
- Document rendering pipeline (HTML→PDF, design/CSS) — brand-specific and Chrome-specific;
  the plugin only enforces that a rendered deliverable has its source file next to it.
- A web UI — this is a CLI/agent-harness plugin, not a hosted product.
- Multi-user sync beyond git — git is the sync mechanism; no additional service.
- Automatic sending of anything — a human always sends; the agent only ever produces drafts.

## Context

- Origin: the method was built by hand inside a live consulting engagement repository
  (French folder/file names originally); this plugin generalizes and ports it, shipping
  English paths only while dossier *content* stays in whatever language `dossier.yaml`
  configures.
- Bootstrapped 2026-09-16 via `gsd-ingest-docs` from a single SPEC document
  (`docs/superpowers/specs/2026-09-16-client-dossier-design.md`). No ADRs or PRDs existed in
  this batch, so no locked decisions or discrete requirement IDs were inherited —
  REQUIREMENTS.md derives its requirement IDs from the SPEC's v1-scope and architecture
  sections instead.
- Spec reviewed and approved 2026-09-16 (status "approved for implementation"): the §11
  decisions were settled, four internal contradictions resolved (README count, staleness
  key, consent source, draft deadline), and the planning resynchronised (42 requirements).
- A repository-root `CLAUDE.md` derived from this same spec exists and is kept in step with it.
- No code exists yet. Next step: `/gsd-discuss-phase 1` then `/gsd-plan-phase 1`.
- Development loop: `claude --plugin-dir .` loads the plugin from the working copy; a
  minimal `.claude-plugin/plugin.json` exists from Phase 1 for that purpose.
- Target runtimes: Claude Code first (full plugin: skills + agents + hooks + commands),
  Codex via `.codex-plugin/`, other harnesses (Cursor, Copilot CLI, Gemini CLI, OpenCode) via
  the plain Agent Skills standard (`skills/*/SKILL.md`), and any harness at all via a
  protocol pointer written into `AGENTS.md`/`CLAUDE.md` by `dossier-init`.
- Design principle carried through every phase: "skills carry the judgement, scripts carry
  the mechanics, hooks carry the reminders." Anything a regex can check lives in `lint.py`;
  anything needing judgement lives in a skill; hooks never do work, they only inject a
  sentence or refuse a write.

## Open Decisions

One remains, scoped to Phase 3 and decided at its planning with Samuel:

- **Stop hook in v1.** Ship the Stop-hook warning now, or wait for user feedback before
  adding it? The spec ships it (provisional default). Affects: Phase 3 scope only (PROTO-06).

The former decisions #1 (name) and #2 (folder names), plus the label-language question
surfaced at review, are settled and listed in Key Decisions below.

## Constraints

- **Fixed layout**: Four top-level folders (`sources/`, `dossier/`, `knowledge/`,
  `outbound/`), each with one regime (immutable / living / internal-knowledge / outbound),
  and seven named living files. Names are fixed English and not configurable — skills,
  hooks, linter, and templates all rely on the same names across every repository.
- **Fact-line format**: `- <fact, one sentence, absolute dates> (<source>, <locator>).` — one
  fact per line, always dated, always sourced or explicitly marked opinion/reconstructed.
- **Status header**: every outbound file opens with a status block (`Status/To/Subject/
  Deadline/Written by/Rules`) in the file's comment syntax; a `sent` status requires a date
  and sender; `Deadline:` is optional and must be an absolute date.
- **Protocol keywords are English**: the `Last updated:` label, the status-header field names
  and the status values are never translated; only headings, examples and content follow
  `dossier.yaml`'s `language`. The linter greps the keywords.
- **Agent never**: sends anything, modifies `sources/`, names a confidential party in
  outbound, promises what doctrine forbids, or leaves a stray `.claude/` in a subfolder.
- **Linter**: Python 3 standard library only, no dependencies (tiny YAML-subset parser or
  JSON fallback), 8 mechanical checks, exit 1 on errors / 0 on warnings-only.
- **Hooks are a convenience, not the mechanism**: every rule a hook enforces is also stated
  in skill prose, so a harness without hooks gets the same behavior.
- **Agents are read-only**: `fact-extractor` (Read/Grep/Glob) and `doctrine-reviewer` never
  write; they report, the dispatching skill decides.
- **License**: MIT. **Versioning**: semver, `CHANGELOG.md`, a git tag per release, version
  lives in both manifests, bumped together by a release script.
- **Testing**: skills tested per `superpowers:writing-skills` (RED pressure scenario before
  the skill exists, GREEN after); mechanical tests are fixture repos + a bash runner
  asserting `lint.py` exit codes/messages — no test framework beyond bash and python3.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Fixed, non-configurable English folder/file names | Same layout works in every repo and every harness with no mapping file to read first | — Pending |
| Markdown fact-lines with a parenthetical source, not structured YAML/JSON per fact | Humans read and edit the dossier directly; prose is enough for an agent to correct and cite; linter checks the shape of a line, not a schema | — Pending |
| One thin router skill (`dossier`) plus five task skills, not one monolithic skill | Ingest/draft/call have different read sets and outputs; a single trigger description triggers poorly | — Pending |
| Hooks enforce, they never perform work (inject a sentence or refuse a write) | Keeps mechanical enforcement separate from the judgement that lives in skills; a harness without hooks still works from skill prose alone | — Pending |
| Document rendering pipeline excluded from v1 | Brand-specific and Chrome-specific; plugin only enforces source-next-to-rendered-file | — Pending |
| Plugin named `client-dossier`, entry skill `dossier` | `dossier` alone is generic on a marketplace; the two names differ and read together | Settled 2026-09-16 |
| Folders `dossier/` and `outbound/` (not `relationship/`, `communication/`) | Spec defaults kept; names now hard-coded everywhere | Settled 2026-09-16 |
| Protocol keywords (`Last updated:`, status fields and values) stay English | A regex must find them in every dossier; a per-language table would have two places to keep in sync and would break on an unlisted language | Settled 2026-09-16 |
| One README per top-level folder + `.gitkeep` in empty leaf folders (not one README per outbound subfolder) | Smaller surface; `.gitkeep` is what actually keeps empty folders through a clone | Settled 2026-09-16 |
| `staleness_days`, `consent_source`, `Deadline:` added to the schema | Every value the linter or `dossier-status` reads needs a fixed home; a consent without a source is an opinion | Settled 2026-09-16 |
| Local development via `claude --plugin-dir .` with a minimal manifest from Phase 1 | Skills and hooks must be exercisable long before the marketplace files of Phase 7 | Settled 2026-09-16 |

---
*Last updated: 2026-09-16 after the spec review*
