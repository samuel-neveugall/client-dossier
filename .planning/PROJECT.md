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
  pressure scenarios recorded for each skill (writing-skills RED→GREEN). Met at v1
  (2026-10-13); the next measure is adoption once published.
- **Strategy notes**: `docs/superpowers/specs/2026-09-16-client-dossier-design.md` (source
  spec, full design detail).

## Requirements

### Validated

All 42 v1 requirements shipped; IDs and traceability in `.planning/milestones/v1-REQUIREMENTS.md`.

- ✓ Scaffold (SCAF-01..08): `dossier-init` skill, fixed folder layout, `dossier.yaml`, en/fr
  living-file templates, `AGENTS.md` pointer, `git mv` adoption of an existing repo — v1
- ✓ Linter (LINT-01..03): `scripts/lint.py` (Python 3.8+ stdlib), E1-E9 and W1-W2, runtime-generated
  fixtures, bash test runner — v1
- ✓ Protocol (PROTO-01..08): `dossier` entry skill and the three hooks (SessionStart reminder,
  PreToolUse guard on `sources/`, Stop check that blocks once); RED 3/3 → GREEN 3/3 — v1
- ✓ Ingest (INGEST-01..06): `dossier-ingest` skill, read-only `fact-extractor` agent,
  `file_source.py`, `extract-text.sh` with the `pdftotext` fallback — v1
- ✓ Draft (DRAFT-01..05): `dossier-draft` skill, read-only `doctrine-reviewer` agent, lint gate
  on every draft — v1
- ✓ Call & status (CALL-01..05): `dossier-call` (prepare and debrief) and `dossier-status`
  backed by `status.py` — v1
- ✓ Distribution (DIST-01..07): Claude Code and Codex manifests and marketplaces, the
  `dossier-lint` command, README/LICENSE/CHANGELOG, `release.sh`, routing eval 1.0 on 8/8 — v1

### Active

No milestone is open. Candidates for the next one, from the v1 audit and the pre-publication
checklist (STATE.md):

- [ ] Publication: run the pre-publication checklist (scrub `.planning/` evidence paths and
      session ids, decide on `Claude-Session` history), then push `v1.0.0` and publish — each
      step needs Samuel's approval (D-01)
- [ ] Codex: run the hooks on a live Codex; decide on a hook-less variant for the public
      directory (D-13); give skills a way to reach `lint.py` outside Claude Code (W1)
- [ ] Transcript fetchers for recording services (`fetchers/`, deferred from v1)
- [ ] Nyquist: reconcile the draft VALIDATION.md files, add one for Phase 1

### Out of Scope

- Transcript fetchers for recording services — origin project had one shell fetcher; v1
  accepts a local file only, `fetchers/` deferred.
- Document rendering pipeline (HTML→PDF, design/CSS) — brand-specific and Chrome-specific; still out after v1;
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
- Shipped v1 on 2026-10-13 (7 phases, 46 plans, 400 commits since 2026-09-16): about 6,800 lines
  of Python 3.8+ stdlib (linter, skill scripts, hooks), six SKILL.md files, two agent files, one
  command, and 31 bash test files in `tests/run.sh` (0 failed at close). Released locally as
  `v1.0.0`; nothing pushed or published.
- Every behavioural skill was written after a recorded RED baseline (paid headless `claude -p`
  pressure scenarios) and proven GREEN with the plugin loaded; evidence lives under
  `.planning/milestones/v1-phases/*/evidence/`.
- Known debt, accepted at close (audit `tech_debt`, no blocker): the Bash guard reads command
  text only (D-17); E5 misses abbreviations and acronyms of confidential names (05 D-09); Codex
  hooks never ran live (W2); on Codex or a bare-skills install the E5 gate reports "not passed"
  because `lint.py` is unreachable (W1).
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

None remain open for v1. The last one, the Stop hook in v1 (spec section 11 #3), was settled with
Samuel on 2026-10-10 during Phase 3 planning and is listed in Key Decisions below, with the
former decisions #1 (name) and #2 (folder names) and the label-language question surfaced at
review.

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
- **Linter**: Python 3.8+ standard library only, no dependencies (tiny YAML-subset parser or
  JSON fallback), nine error checks (E1-E9) and two warnings (W1-W2); exit 0 no error, 1 error,
  2 no `dossier.yaml`, 3 internal error. Read-only, no fix mode.
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
| Fixed, non-configurable English folder/file names | Same layout works in every repo and every harness with no mapping file to read first | ✓ Good — skills, hooks, linter and templates hard-code one set of names; existing repos adopt them via `git mv` (v1) |
| Markdown fact-lines with a parenthetical source, not structured YAML/JSON per fact | Humans read and edit the dossier directly; prose is enough for an agent to correct and cite; linter checks the shape of a line, not a schema | ✓ Good — ingest GREEN runs corrected contradicted lines in place with sources (v1) |
| One thin router skill (`dossier`) plus five task skills, not one monolithic skill | Ingest/draft/call have different read sets and outputs; a single trigger description triggers poorly | ✓ Good — routing eval scored 1.0 on 8/8 cases (v1) |
| Hooks enforce, they never perform work (inject a sentence or refuse a write) | Keeps mechanical enforcement separate from the judgement that lives in skills; a harness without hooks still works from skill prose alone | ✓ Good — the Bash guard's limits are covered by the skill rule (D-17) (v1) |
| Document rendering pipeline excluded from v1 | Brand-specific and Chrome-specific; plugin only enforces source-next-to-rendered-file | ✓ Good — E9 enforces the source beside each rendered deliverable (v1) |
| Plugin named `client-dossier`, entry skill `dossier` | `dossier` alone is generic on a marketplace; the two names differ and read together | Settled 2026-09-16 |
| Folders `dossier/` and `outbound/` (not `relationship/`, `communication/`) | Spec defaults kept; names now hard-coded everywhere | Settled 2026-09-16 |
| Protocol keywords (`Last updated:`, status fields and values) stay English | A regex must find them in every dossier; a per-language table would have two places to keep in sync and would break on an unlisted language | Settled 2026-09-16 |
| One README per top-level folder + `.gitkeep` in empty leaf folders (not one README per outbound subfolder) | Smaller surface; `.gitkeep` is what actually keeps empty folders through a clone | Settled 2026-09-16 |
| `staleness_days`, `consent_source`, `Deadline:` added to the schema | Every value the linter or `dossier-status` reads needs a fixed home; a consent without a source is an opinion | Settled 2026-09-16 |
| Local development via `claude --plugin-dir .` with a minimal manifest from Phase 1 | Skills and hooks must be exercisable long before the marketplace files of Phase 7 | Settled 2026-09-16 |
| Stop hook ships in v1 and blocks once (`stop_hook_active` lets the second stop through) | In Claude Code a Stop hook that does not block only reaches the human; updating the dossier before handing back is the agent's behaviour | ✓ Good — settled 2026-10-10 (Phase 3 D-01), GREEN runs filed the dossier update before handing back |
| A skill's private script and templates live inside its own folder; shared scripts stay at the root `scripts/` (01 D-05, D-06) | A bare-skills install copies a skill folder whole; only `lint.py` is shared | ✓ Good — bare-skills install proven by copy and by the `skills` CLI (v1) |
| Linter error fixtures generated at runtime, assertions on exit code + identifier, not golden output (02 D-29, D-30) | Fixtures stay in step with `init.py`; message wording can change without breaking tests | ✓ Good |
| Every behavioural skill written after a recorded RED baseline under pressure (03 D-10, D-15) | writing-skills order; a skill that is not needed is not written | ✓ Good — RED 3/3 then GREEN 3/3 on every scenario; a git-ancestry test pins the order |
| Bash guard on `sources/` is a bounded heuristic, its residual class accepted as debt (03 D-04, D-17) | Command text cannot be fully parsed; the skill rule is the boundary | ⚠️ Revisit — stated in README Limits |
| Sources are filed by a script, never by the Write tool (04 D-04) | The guard denies every write under `sources/`; a script can hash, dedup and O_EXCL-copy | ✓ Good |
| Fact-extractor proposals applied directly, "uncertain" only reported; git is the undo net (04 D-03) | Avoids a confirmation round-trip per fact | ✓ Good |
| E5 hardened for every mechanical case; abbreviations and acronyms left to the doctrine-reviewer (05 D-09) | A regex cannot know that `BT` means `British Telecom` | ⚠️ Revisit — stated in README Limits |
| `dossier-status` mechanics in a read-only `status.py`; it exits 0 whenever a report prints (06 D-02, W5) | Status is informational, not a gate; the lint verdict is in the report | ✓ Good |
| Version 1.0.0, local annotated tag only; push, marketplace publication and visibility need Samuel's approval (07 D-01, D-09) | Publication is irreversible; the pre-publication checklist is not executed in v1 | — Pending (publication) |
| One slash command, `dossier-lint`; the five task skills are the slash commands (07 D-18) | A command named like a skill shadows it | ✓ Good — a test fails if a command shares a skill's name |
| No hooks in the Codex manifest for the public directory question (07 D-13) | OpenAI's public directory refuses plugins with lifecycle hooks | — Pending (publication-time decision) |

---
*Last updated: 2026-10-13 after v1 milestone*
