# Requirements: client-dossier

**Defined:** 2026-09-16
**Core Value:** Every agent session in a dossier repository reads the living dossier before
acting and updates it before handing back — so a human never has to re-read everything to
know where things stand, and nothing reaches the counterpart without passing through a human
and the doctrine check.

**Source note:** No ADR or PRD documents were ingested for this project — a single SPEC
(`docs/superpowers/specs/2026-09-16-client-dossier-design.md`) is the sole source. Requirement
IDs and descriptions below are derived from that SPEC's v1-scope (§10) and architecture
(§2-§7) sections, not from pre-existing discrete requirement statements. Treat wording as
synthesized-for-tracking, not verbatim spec text.

## v1 Requirements

### Scaffold (dossier-init, templates, dossier.yaml)

- [x] **SCAF-01**: `dossier-init` writes `dossier.yaml` with version, language, counterparts
      (name/role/contacts), confidential_names, consent_recorded, consent_source, timestamps
      format, date_format, status_header setting, and staleness_days (default 7)
- [x] **SCAF-02**: `dossier-init` creates the four-folder layout (`sources/`, `dossier/`,
      `knowledge/`, `outbound/`) with their documented subfolders, each empty leaf folder
      holding a `.gitkeep` so the layout survives a git clone
- [x] **SCAF-03**: `dossier-init` scaffolds all seven living-dossier files from templates,
      each pre-filled with a `Last updated:` line and its "Updated when" rule as a comment
- [x] **SCAF-04**: `dossier-init` creates `knowledge/CONTEXT.md`, `knowledge/DOCTRINE.md`
      (with the "what we say" / "what we never say" lists to fill), and one README per
      top-level folder that needs one: `dossier/README.md`, `sources/README.md`,
      `outbound/README.md` (restating the status header, the naming rule and the role of the
      three outbound subfolders)
- [x] **SCAF-05**: `dossier-init` adds a short protocol-pointer section to the repository's
      `CLAUDE.md`/`AGENTS.md`
- [x] **SCAF-06**: On an existing repository, `dossier-init` detects same-role folders under
      other names and proposes `git mv` renames to the fixed English names before writing
      what is missing
- [x] **SCAF-07**: Templates are authored once in English structure; `dossier-init`
      translates title, headings, comments and example lines into the configured language at
      scaffold time, and leaves protocol keywords (`Last updated:`, status-header field names
      and values) in English
- [x] **SCAF-08**: A minimal `.claude-plugin/plugin.json` (name, version, description) exists
      so that `claude --plugin-dir .` loads the plugin from the working copy during development

### Linter (scripts/lint.py, fixtures, bash test runner)

- [x] **LINT-01**: `scripts/lint.py` (Python 3 standard library only) implements all 8
      mechanical checks from the design spec — status block present and complete on
      outbound files (a `sent` status has a date and a sender, a `Deadline:` is an absolute
      date), outbound filenames match `YYYY-MM-DD_slug`, no confidential name under
      `outbound/` unless `consent_recorded: true` with a non-empty `consent_source` (true
      without a source is an error), every living file has a `Last updated:` line (fixed
      English label) with an absolute date, relative-date words flagged as warnings, bullet
      lines without a parenthetical source flagged as warnings, no `.claude/` folder below
      repo root, and rendered deliverables have their source file next to them — exiting 1
      on any error and 0 on warnings-only, ignoring `.gitkeep` files
- [x] **LINT-02**: Fixture repositories exist for lint testing: a clean baseline layout, a
      French-language dossier fixture exercising the relative-date and opinion-marker word
      lists, and error fixtures that together trigger every error-class check at least once
- [x] **LINT-03**: A bash test runner executes `lint.py` against the fixtures and asserts
      exit codes and messages, with no test framework beyond bash and python3

### Protocol skill `dossier` + hooks

- [x] **PROTO-01**: The `dossier` skill triggers on any task in a repository containing
      `dossier.yaml`, or any mention of a client/counterpart/prospect/partner/call/message
      to someone outside the team, and is always loaded first
- [ ] **PROTO-02**: The `dossier` skill's content covers the four-folder layout, the
      read-before-act/update-before-handoff table, the fact-line format, the status-header
      format, the "what the agent never does" list, the "Name (Organisation)" rule on first
      mention of a person in a file, and one-sentence pointers to the other five skills
- [x] **PROTO-03**: The `dossier` skill sets the rule that the agent writes dossier content
      in the language configured in `dossier.yaml`
- [x] **PROTO-04**: A SessionStart hook injects the protocol reminder ("this repository is a
      client dossier, load the `dossier` skill") whenever `dossier.yaml` is found from the
      working directory upward, and stays silent otherwise
- [x] **PROTO-05**: A PreToolUse hook on Write/Edit/MultiEdit/NotebookEdit denies any write
      whose target path resolves under the sources folder of the nearest dossier, new files
      included, with the message that sources are immutable; a second, heuristic PreToolUse
      guard on Bash denies commands that visibly modify an existing file under sources
      (in-place edits, rm, mv out, cp, tee or redirection onto it, truncate, git rm) and
      allows copying a new file in (Phase 3 D-03, D-04)
- [x] **PROTO-06**: A Stop hook blocks the stop once when `git status` shows uncommitted
      changes under outbound or sources but none under the dossier folder, returning a
      reason to the agent (update the living files the work touched, or say why none needed
      it; `dossier-status` named once that skill exists); the second stop of the same turn
      (`stop_hook_active`) passes, so it never loops (settled with Samuel 2026-10-10,
      Phase 3 D-01)
- [x] **PROTO-07**: The "fix the typo in the transcript" baseline pressure scenario is
      recorded RED (agent edits the source) before the protocol skill/hooks exist, and
      re-run GREEN (the transcript stays byte-identical and the agent files the correction
      as a dated, sourced line in the living file concerned; Phase 3 D-09) after
- [ ] **PROTO-08**: Every skill locates the nearest `dossier.yaml` (working directory, then
      parents); every task skill (all except `dossier-init` and the `dossier` entry skill)
      stops with a message when none is found; the `dossier` entry skill says so in one line,
      suggests `dossier-init` when relevant, and steps aside (03-CONTEXT D-05); in a repository
      holding several dossiers, the nearest one wins

### Ingest (dossier-ingest, fact-extractor agent, extract-text.sh)

- [x] **INGEST-01**: `dossier-ingest <path or URL>` files the source under `sources/` as
      `YYYY-MM-DD_slug`, runs `extract-text.sh` (pdftotext wrapper) for PDFs, and keeps raw
      exports next to transcripts; when `pdftotext` is missing the script exits with an
      install hint, the PDF is still filed and the skill reports extraction as skipped
- [x] **INGEST-02**: `dossier-ingest` dispatches the `fact-extractor` agent and applies its
      proposal to the living files — appending under the right heading, correcting a
      contradicted line instead of adding a new one, updating "Last updated" — then reports
      what changed and what was left as uncertain
- [x] **INGEST-03**: The `fact-extractor` agent (read-only: Read, Grep, Glob) takes one
      source path, the dossier config, and the current living-file headings, and returns a
      structured proposal grouped by target file/heading with locators, a "contradicts" list
      (existing line, proposed correction, why), and an "uncertain" list — honoring one fact
      per line, absolute dates, quotes checked in context, never paraphrasing a number, never
      inventing a source
- [x] **INGEST-04**: Ingesting a source already filed (same hash) is reported as already
      filed, not duplicated
- [x] **INGEST-05**: The "given a transcript, what did we learn" baseline pressure scenario
      is recorded RED (summary only in chat, nothing filed, no timestamps) before
      `dossier-ingest` exists, and re-run GREEN (facts filed with sourced timestamps) after
- [x] **INGEST-06**: `dossier-ingest` contains the inline extraction procedure for harnesses
      without subagents, says when the main agent is doing the extractor's job itself, and
      checks that `extract-text.sh` exists before calling it (bare-skills install)

### Draft (dossier-draft, doctrine-reviewer agent)

- [ ] **DRAFT-01**: `dossier-draft <kind> <slug>` (kinds: mail, message, deliverable, note)
      reads tone, learnings, doctrine, decisions, and the last outbound files of the same
      kind, then writes the draft under the right outbound folder with a complete status
      header, in the dossier's language, following the tone file's recorded structure
- [ ] **DRAFT-02**: `dossier-draft` dispatches `doctrine-reviewer`, applies its findings or
      explicitly lists disagreements, runs `lint.py` on the resulting file, writes the
      deadline (when there is one) in the `Deadline:` field of the status header, and updates
      history with a commitment line — and never sets the draft's status to "sent"
- [ ] **DRAFT-03**: The `doctrine-reviewer` agent (read-only) takes a draft path, the
      doctrine, the tone file (including the Refused log), and the confidential names, and
      returns severity-ranked findings (confidential name, forbidden claim, refused pattern,
      unsourced promise, relative date, structural departure) without rewriting the draft
- [ ] **DRAFT-04**: The "write a quick reply to the client" baseline pressure scenario is
      recorded RED (writes inline, never reads tone, never updates history, may name the
      confidential party) before `dossier-draft` exists, and re-run GREEN after
- [ ] **DRAFT-05**: `dossier-draft` contains the inline review procedure for harnesses
      without subagents, says when the main agent is doing the reviewer's job itself, and
      when `lint.py` is absent (bare-skills install) says so and states the rules it would
      have checked

### Call & status (dossier-call, dossier-status)

- [ ] **CALL-01**: `dossier-call prepare <date> <slug>` writes a call file in
      `outbound/calls/` with context, objectives, a timed agenda, a "what we do not do"
      section, and open questions pulled from the open-questions file ordered by "when to
      ask," leaving an empty minutes section
- [ ] **CALL-02**: `dossier-call debrief <transcript>` ingests the transcript via
      `dossier-ingest`, fills the minutes section, moves answered questions to the answered
      table with timestamps, adds new commitments to history with owners and dates, and
      updates `RELATIONSHIP.md` when the call is a milestone
- [ ] **CALL-03**: `dossier-status` is read-only and prints the one-line status, commitments
      due with dates, sources ingested but not yet reflected in living files, outbound
      drafts still marked draft past the `Deadline:` of their status header, living files
      stale beyond `staleness_days` from `dossier.yaml` (7 by default), and lint findings
- [ ] **CALL-04**: The "prepare tomorrow's call" baseline pressure scenario is recorded RED
      (writes "tomorrow", skips open questions, no "what we do not do" section) before
      `dossier-call` exists, and re-run GREEN after
- [ ] **CALL-05**: The "where are we with this deal" baseline pressure scenario is recorded
      RED (re-reads everything, answers from memory, misses due commitments) before
      `dossier-status` exists, and re-run GREEN after

### Distribution (manifests, commands, README/LICENSE/CHANGELOG, plugin eval)

- [ ] **DIST-01**: `.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json` let a
      user install via `/plugin marketplace add` then `/plugin install` in Claude Code
- [ ] **DIST-02**: `.codex-plugin/plugin.json` + `.agents/plugins/marketplace.json` provide
      the equivalent Codex CLI/app distribution path
- [ ] **DIST-03**: `skills/*/SKILL.md` alone (no plugin installed) is installable on any
      Agent-Skills-standard harness (Cursor, Copilot CLI, Gemini CLI, OpenCode) via the
      `skills` CLI or by copying the folder in; the skills behave without `scripts/`, hooks
      or agents (INGEST-06, DRAFT-05) and the README says what that install loses
- [ ] **DIST-04**: Six thin slash commands exist under `commands/`: one per task skill
      (`dossier-init`, `dossier-ingest`, `dossier-draft`, `dossier-call`, `dossier-status`)
      invoking that skill, plus `dossier-lint` running `scripts/lint.py`; the `dossier`
      protocol skill has no command (it is loaded, not invoked)
- [ ] **DIST-05**: README documents installation for all four distribution targets
      (Claude Code, Codex, Agent-Skills-standard harnesses, plain `AGENTS.md`-only use),
      plus versioning (semver, `CHANGELOG.md`, git tag per release) and the MIT `LICENSE`;
      README states the Bash guard's D-04 limits (Phase 3 D-17)
- [ ] **DIST-06**: `claude plugin eval` suites verify the six skills' trigger descriptions —
      confirming, for example, that "write to the client" routes to `dossier-draft` and not
      `dossier-ingest`
- [ ] **DIST-07**: `scripts/release.sh <version>` bumps the version in both manifests
      (`.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`), updates the `CHANGELOG.md`
      heading and creates the git tag, so the two versions never diverge

## v2 Requirements

None identified. The source SPEC defines no v2 scope; deferred items are recorded as
permanent v1 exclusions in Out of Scope below, not as a future release.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Transcript fetchers for recording services (`fetchers/`) | Origin project had one shell fetcher for a single service; v1 accepts a local file only |
| Document rendering pipeline (HTML→PDF, design/CSS) | Brand-specific and Chrome-specific; plugin only enforces that a rendered deliverable has its source file next to it |
| A web UI | This is a CLI/coding-agent plugin, not a hosted product |
| Multi-user sync beyond git | Git is the sync mechanism; no additional service in v1 |
| Automatic sending of anything | A human always sends; the agent only ever produces drafts |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| SCAF-01 | Phase 1 | Complete (closed 2026-09-17) |
| SCAF-02 | Phase 1 | Complete (closed 2026-09-17) |
| SCAF-03 | Phase 1 | Complete (closed 2026-09-17) |
| SCAF-04 | Phase 1 | Complete (closed 2026-09-17) |
| SCAF-05 | Phase 1 | Complete (closed 2026-09-17) |
| SCAF-06 | Phase 1 | Complete (closed 2026-09-17) |
| SCAF-07 | Phase 1 | Complete (closed 2026-09-17) |
| SCAF-08 | Phase 1 | Complete (closed 2026-09-17) |
| LINT-01 | Phase 2 | Complete |
| LINT-02 | Phase 2 | Complete |
| LINT-03 | Phase 2 | Complete |
| PROTO-01 | Phase 3 | Complete (closed 2026-10-10) |
| PROTO-02 | Phase 3 (pointers completed incrementally as each task skill lands in Phases 4-6, verified in full at Phase 6; D-07) | Partial — Phase 3 part done 2026-10-10 (only `dossier-init` pointer exists) |
| PROTO-03 | Phase 3 | Complete (closed 2026-10-10) |
| PROTO-04 | Phase 3 | Complete (closed 2026-10-10) |
| PROTO-05 | Phase 3 | Complete (closed 2026-10-10) — Bash guard class D-04 accepted as documented v1 debt (D-17) |
| PROTO-06 | Phase 3 | Complete (closed 2026-10-10) |
| PROTO-07 | Phase 3 | Complete (closed 2026-10-10) |
| PROTO-08 | Phase 3 (rule and hooks; the task-skill stop completed incrementally in Phases 4-6, verified in full at Phase 6) | Partial — Phase 3 part done 2026-10-10 (rule, hooks, entry skill) |
| INGEST-01 | Phase 4 | Complete |
| INGEST-02 | Phase 4 | Complete |
| INGEST-03 | Phase 4 | Complete |
| INGEST-04 | Phase 4 | Complete |
| INGEST-05 | Phase 4 | Complete |
| INGEST-06 | Phase 4 | Complete |
| DRAFT-01 | Phase 5 | Pending |
| DRAFT-02 | Phase 5 | Pending |
| DRAFT-03 | Phase 5 | Pending |
| DRAFT-04 | Phase 5 | Pending |
| DRAFT-05 | Phase 5 | Pending |
| CALL-01 | Phase 6 | Pending |
| CALL-02 | Phase 6 | Pending |
| CALL-03 | Phase 6 | Pending |
| CALL-04 | Phase 6 | Pending |
| CALL-05 | Phase 6 | Pending |
| DIST-01 | Phase 7 | Pending |
| DIST-02 | Phase 7 | Pending |
| DIST-03 | Phase 7 | Pending |
| DIST-04 | Phase 7 | Pending |
| DIST-05 | Phase 7 | Pending |
| DIST-06 | Phase 7 | Pending |
| DIST-07 | Phase 7 | Pending |

**Coverage:**

- v1 requirements: 42 total
- Mapped to phases: 42
- Unmapped: 0 ✓

---
*Requirements defined: 2026-09-16*
*Last updated: 2026-09-16 after the spec review (decisions §11 settled; SCAF-08, PROTO-08,
INGEST-06, DRAFT-05, DIST-07 added; SCAF-01/02/04/07, LINT-01/02, PROTO-02, INGEST-01,
DRAFT-02, CALL-03, DIST-03/04 amended); 2026-10-10 Phase 3 planning: PROTO-05/06/07 amended
(D-01, D-03, D-04, D-09), PROTO-02/08 completed incrementally (D-07)*
