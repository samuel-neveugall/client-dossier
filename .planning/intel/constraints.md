> Note (2026-10-10): snapshot of the 2026-09-16 ingestion; superseded by 03-CONTEXT D-01/D-03/D-04 and the amended spec §4.3. The body below is kept as ingested.

# Constraints

Source document for all entries below: `docs/superpowers/specs/2026-09-16-client-dossier-design.md`
(classified SPEC, confidence: high, locked: false, precedence: null → default SPEC precedence applies).

## Dossier folder structure: four folders, four regimes

- source: docs/superpowers/specs/2026-09-16-client-dossier-design.md (§2.1, §3.2)
- type: schema
- content:
  Fixed layout, English names, not configurable:
  ```
  dossier.yaml            config: counterparts, confidential names, language
  sources/                immutable: received/, transcripts/ (+ raw/), extractions next to PDFs
  dossier/                living: ACTORS.md HISTORY.md LEARNINGS.md TONE.md CHANNELS.md
                          OPEN-QUESTIONS.md RELATIONSHIP.md README.md
  knowledge/              CONTEXT.md DOCTRINE.md decisions/YYYY-MM-DD_slug.md watch/
  outbound/               deliverables/ mails/ calls/  (files named YYYY-MM-DD_slug.*)
  ```
  Regimes: `sources/` = Immutable (documents received, never modified/corrected, even when
  wrong). `dossier/` = Living (one fact per line, dated, sourced; correct a line rather than
  add a contradictory one). `knowledge/` = Internal knowledge (context, doctrine, dated
  decision logs, watch folder). `outbound/` = Outbound (deliverables, mails, calls, named
  `YYYY-MM-DD_slug`; every file opens with a status header; nothing leaves without a human).
  An existing repository with other folder names renames to adopt the plugin (`dossier-init`
  offers `git mv` renames). Dossier content stays in the configured language; only paths are
  English. A repository can hold several dossiers (one per counterpart) in subfolders, each
  with its own `dossier.yaml`.

## The seven files of the living dossier

- source: docs/superpowers/specs/2026-09-16-client-dossier-design.md (§2.2)
- type: schema
- content:
  `ACTORS.md` — who is who on every side (role, decision power, expectations, constraints,
  stated principles), grouped by side; updated when a new actor appears or a role clarifies.
  `HISTORY.md` — chronology by day/milestone, each line sourced, plus standing sections
  "commitments in progress" (ours/theirs) and "upcoming" (dated deadlines); updated after
  every call, mail or document sent.
  `LEARNINGS.md` — what exchanges teach about the counterpart (how they speak/think, what
  they expect of a document, pitfalls); updated when an exchange reveals a new trait or
  contradicts an old one.
  `TONE.md` — the voice in one sentence, what's established, what each exchange added,
  structure of long/short documents, and a "Refused" log of every reviewer comment on a
  draft with its date; updated every time a human reviews a draft.
  `CHANNELS.md` — how communication happens (video/recording etiquette, documents, mail
  addresses, call habits, repository confidentiality level); updated when a channel/access
  changes.
  `OPEN-QUESTIONS.md` — three tables: answered (question, answer, source), still open on the
  counterpart side (question, why it matters, when to ask), what we would ask the end
  client; updated after every call.
  `RELATIONSHIP.md` — one-line status, metrics table (duration, amount committed, contacts,
  deadlines, confidentiality), our view, their reconstructed view, concrete improvements,
  sales opportunities ranked by probability, points to keep in mind; updated at every
  milestone and at least weekly while the deal is open.

## `dossier.yaml` configuration schema

- source: docs/superpowers/specs/2026-09-16-client-dossier-design.md (§3.2)
- type: schema
- content:
  ```yaml
  version: 1
  language: fr                      # language of the dossier content
  counterparts:
    - name: "Acme Consulting"        # internal name, never in outbound
      role: ordering party
      contacts: [ "Jane Doe" ]
    - name: "Big Telco"
      role: end client
  confidential_names: [ "Acme", "Big Telco" ]   # linter fails if found under outbound/
  consent_recorded: false           # flip to true with a source when written consent exists
  timestamps: "@mm:ss"              # transcript citation format
  date_format: "YYYY-MM-DD"
  status_header: required           # outbound files must open with a status block
  ```
  The plugin locates a dossier by finding `dossier.yaml` in the working directory or a
  parent directory.

## Outbound status header format

- source: docs/superpowers/specs/2026-09-16-client-dossier-design.md (§3.3)
- type: protocol
- content:
  Every outbound file opens with a status block, in the file's own comment syntax
  (`<!-- -->` in HTML/Markdown, `#` lines in plain text):
  ```
  Status: draft | reviewed by <name> | sent <date time> by <name>
  To: <recipient>
  Subject: <subject>            (mails)
  Written by: <human or "agent session, YYYY-MM-DD">
  Rules: no confidential names; see knowledge/DOCTRINE.md
  ```
  The linter fails on an outbound file without a status block, and on a `sent` status
  without a date and a sender.

## Fact line format

- source: docs/superpowers/specs/2026-09-16-client-dossier-design.md (§2.3, §3.4)
- type: protocol
- content:
  ```
  - <fact, one sentence, absolute dates> (<source>, <locator>).
  ```
  One fact per line; every line carries a date and a source: a transcript timestamp
  (`@mm:ss`), a mail, a file and page. Example sources: `call @12:34`, `mail 2026-09-16
  from Jane`, `brochure p. 4`, `internal note p. 15`. A line without a source is an
  opinion and says so. A line whose source is a reconstruction says "reconstructed".
  Dates are absolute everywhere ("tomorrow" is converted before writing). Correct a line
  rather than add a contradictory one; each file starts with "Last updated: date, after
  which event." Transcripts are automatic and unreviewed — a quote is checked in context
  before reuse, and the source file is never corrected. Confidential names are written
  only in internal folders and never in outbound files, unless written consent is
  recorded. Typographic/register rules are project-specific and live in the tone file,
  not in the plugin.

## Session protocol (read-before-act / update-before-handoff)

- source: docs/superpowers/specs/2026-09-16-client-dossier-design.md (§2.4)
- type: protocol
- content:
  | Task | Read first | Update before handing back |
  |---|---|---|
  | Any session | context one-pager, history | nothing, unless something was learned |
  | Write a message/document for the counterpart | tone, learnings, doctrine, decisions | history (commitment taken, date), tone if a human gave feedback |
  | Prepare a call | open questions, previous call files | a call file in outbound with objectives, agenda, what we do not do |
  | Debrief a call | the transcript | history, open questions (answered, new), learnings, actors, channels, relationship at a milestone |
  | Check a fact | sources | the line that was wrong |
  | Ingest a source | nothing | sources (file plus text extraction), then every dossier file the source touches |
  "Update before handing back" means the same session, before its final message (§12).

## What the agent never does

- source: docs/superpowers/specs/2026-09-16-client-dossier-design.md (§2.5)
- type: nfr
- content:
  The agent never: sends a message or document (drafts go to outbound with a status
  header; humans send); modifies anything in `sources/`; names a confidential party in an
  outbound file; promises what the doctrine forbids (in the origin project: a deadline, a
  rate, a closed solution before scoping); leaves a `.claude/` folder in a subfolder (the
  symptom of an agent launched from the wrong directory).

## Plugin repository layout

- source: docs/superpowers/specs/2026-09-16-client-dossier-design.md (§4)
- type: schema
- content:
  ```
  client-dossier/
    .claude-plugin/plugin.json          Claude Code manifest
    .claude-plugin/marketplace.json     self-hosted marketplace (one plugin)
    .codex-plugin/plugin.json           Codex manifest
    .agents/plugins/marketplace.json    Codex marketplace listing
    skills/
      dossier/SKILL.md                  the protocol: layout, read-before-act, update-before-handoff
      dossier-init/SKILL.md             scaffold a dossier
      dossier-ingest/SKILL.md           file a source, extract facts into the living files
      dossier-draft/SKILL.md            write an outbound message or document
      dossier-call/SKILL.md             prepare a call, debrief a call
      dossier-status/SKILL.md           where we are, what is due, what is stale
    agents/
      fact-extractor.md                 reads one long source, returns dated sourced lines per file
      doctrine-reviewer.md              fresh-eyes review of a draft against doctrine, tone, confidentiality
    commands/                           thin slash commands that invoke the skills (Claude Code)
      dossier-init.md  dossier-ingest.md  dossier-draft.md  dossier-call.md  dossier-status.md  dossier-lint.md
    hooks/
      hooks.json                        SessionStart reminder, PreToolUse guard on sources/, Stop warning
      session-start.sh  guard-sources.sh  stop-check.sh
    scripts/
      lint.py                           mechanical checks (python3, no dependencies)
      extract-text.sh                   pdftotext wrapper, writes .txt next to the PDF
    templates/                          one file per living file, plus outbound headers, plus dossier.yaml
    docs/                               this spec, the protocol reference, the fact-line reference
    README.md  LICENSE  CHANGELOG.md
  ```
  Design principle: "skills carry the judgement, scripts carry the mechanics, hooks carry
  the reminders." Anything a regex can check is in `lint.py`, not prose. Hooks never do
  work; they inject a sentence or refuse a write.

## Skills interface (six skills)

- source: docs/superpowers/specs/2026-09-16-client-dossier-design.md (§4.1)
- type: api-contract
- content:
  All skills follow the Agent Skills standard (`SKILL.md` with `name`/`description`
  frontmatter written for triggering).
  `dossier` — always loaded first; triggers on any task in a repo with `dossier.yaml` or
  any mention of a client/counterpart/prospect/partner/call/message-to-someone-outside-team;
  content = layout, read-before-act table, update-before-handoff rule, fact line, status
  header, what the agent never does, pointers to the other five skills; sets the rule that
  the agent writes in the dossier's language.
  `dossier-init` — asks/reads counterpart names+roles, confidential names, language,
  whether folders need renaming; writes `dossier.yaml`, folders, seven living files from
  templates, `knowledge/CONTEXT.md`, `knowledge/DOCTRINE.md` (two lists to fill),
  `outbound/README.md`, `sources/README.md`; adds a section to `CLAUDE.md`/`AGENTS.md`
  pointing to the protocol; on existing repos, detects same-role folders under other names
  and proposes `git mv` renames.
  `dossier-ingest <path or URL>` — files the source under `sources/` as `YYYY-MM-DD_slug`,
  runs text extraction for PDFs, keeps raw exports next to transcripts; dispatches
  `fact-extractor`; applies the proposal to living files (append, correct contradicted
  line, update "Last updated"); reports changes and uncertain items; `fetchers/` for
  transcript services explicitly not in v1.
  `dossier-draft <kind> <slug>` (kinds: mail, message, deliverable, note) — reads tone,
  learnings, doctrine, decisions, last outbound files of the same kind; writes the draft
  with status header in the dossier's language following the tone-file structure;
  dispatches `doctrine-reviewer`; applies or lists disagreements with findings; runs
  `lint.py`; updates history; never marks a draft as sent (the human edits the status
  line).
  `dossier-call prepare <date> <slug>` / `dossier-call debrief <transcript>` — prepare
  writes a call file in `outbound/calls/` (context, objectives, timed agenda, "what we do
  not do," open questions ordered by "when to ask," empty minutes section); debrief
  ingests the transcript via `dossier-ingest`, fills minutes, moves answered questions,
  adds commitments to history with owners/dates, updates relationship file if a milestone.
  `dossier-status` — read-only; prints one-line status, commitments due, sources ingested
  but not reflected, outbound drafts past deadline, living files stale beyond configured
  threshold (7 days default), lint findings.

## Agents interface (fact-extractor, doctrine-reviewer)

- source: docs/superpowers/specs/2026-09-16-client-dossier-design.md (§4.2)
- type: api-contract
- content:
  Agents exist so long reading and fresh-eyes review happen outside the main context; they
  are Claude Code subagents (`agents/*.md`); on harnesses without subagents the skills
  describe performing the same steps inline.
  `fact-extractor` (read-only: Read, Grep, Glob) — input: one source path, the dossier
  config, current headings of the living files; output: a structured proposal grouped by
  target file/heading, each line with its locator, plus a "contradicts" list (existing
  line, proposed correction, why) and an "uncertain" list. Rules baked in: one fact per
  line, absolute dates, quote checked in context, never paraphrase a number, do not invent
  a source.
  `doctrine-reviewer` (read-only) — input: a draft path, the doctrine, the tone file
  (including the Refused log), the confidential names; output: findings ranked by
  severity (confidential name, forbidden claim from "what we never say," a refused
  pattern from the tone log, a promise without a source, a relative date, a departure from
  the recorded structure for that kind of document); does not rewrite — reports only, the
  drafting skill decides.

## Hooks behavior

- source: docs/superpowers/specs/2026-09-16-client-dossier-design.md (§4.3)
- type: protocol
- content:
  | Event | Behaviour |
  |---|---|
  | SessionStart | If `dossier.yaml` is found from the working directory upward, inject: "This repository is a client dossier. Load the `dossier` skill before acting." Nothing otherwise. |
  | PreToolUse on Write, Edit, MultiEdit | If target path is under the sources folder, deny with "sources are immutable; file a correction in the dossier instead." |
  | Stop | If `git status` shows changes under outbound or sources and none under the dossier folder, print a warning: "outbound or sources changed, dossier not updated; run dossier-status." Warning only, never blocks. |
  Hooks are a convenience; the skills state the same rules so a harness without hooks gets
  the same behavior from prose. Claude Code primary; mirrored for harnesses that support
  hooks. NOTE: whether the Stop hook ships in v1 is listed by the spec author as an open
  decision (§11.3) — see `INTEL_DIR/context.md`.

## Linter checks (`scripts/lint.py`)

- source: docs/superpowers/specs/2026-09-16-client-dossier-design.md (§4.4)
- type: nfr
- content:
  Python 3 standard library only; reads `dossier.yaml` (tiny YAML subset parser, or JSON
  fallback, to avoid a dependency). Checks:
  1. Every outbound file opens with a status block; a `sent` status has a date and sender.
  2. Outbound file names match `YYYY-MM-DD_slug`.
  3. No confidential name appears under outbound, unless `consent_recorded: true`.
  4. Every living file has a "Last updated" line with an absolute date.
  5. No relative date words in the dossier and knowledge folders (small per-language list:
     "tomorrow", "next week", "demain", "la semaine prochaine"), reported as warnings.
  6. Every bullet line in living files ends with a source in parentheses; lines without one
     are warnings, not errors (a bilingual list of allowed "opinion" markers).
  7. No `.claude/` folder below the repository root.
  8. Deliverables: a rendered file (`.pdf`, `.docx`) has its source (`.html`, `.md`) next
     to it with the same stem.
  Exit code 1 on errors, 0 on warnings only. `dossier-lint` command and `dossier-status`
  call it.

## Data flow

- source: docs/superpowers/specs/2026-09-16-client-dossier-design.md (§5)
- type: protocol
- content:
  ```
  source received ──► dossier-ingest ──► sources/ (immutable)
                            │
                            └─► fact-extractor ──► proposal ──► living files updated
                                                                     │
  human asks for a message ──► dossier-draft ◄───────────────────────┘ (reads tone, learnings,
                                    │                                   doctrine, decisions)
                                    ├─► outbound/<kind>/YYYY-MM-DD_slug (status: draft)
                                    ├─► doctrine-reviewer ──► findings applied
                                    ├─► lint.py
                                    └─► history: commitment line
  human sends, edits status ──► dossier-status sees "sent", flags nothing
  call happens ──► dossier-call debrief ──► ingest transcript ──► minutes, questions, history, relationship
  ```

## Error handling and edge cases

- source: docs/superpowers/specs/2026-09-16-client-dossier-design.md (§6)
- type: nfr
- content:
  No `dossier.yaml` found: every skill except `dossier-init` stops and says so. A source
  already filed (same hash): ingest reports it, does not duplicate. A fact contradicts an
  existing line: the extractor proposes a correction; ingest applies it and appends
  "(corrects a line dated <date>)". Two counterparts with the same first name: actors file
  disambiguates with the organisation; skills always write "Name (Organisation)" on first
  mention in a file. A draft must name the counterpart (consent recorded): the linter reads
  `consent_recorded` and the source of consent from config; the reviewer still flags the
  name as informational. Transcript timestamps absent (mail thread, PDF): locator becomes
  page, paragraph, or the mail date and sender. Harness has no subagents: the skills
  contain the inline procedure and say when the main agent is doing the extractor's or
  reviewer's job itself.

## Distribution mechanisms

- source: docs/superpowers/specs/2026-09-16-client-dossier-design.md (§8)
- type: nfr
- content:
  | Target | Mechanism | Action |
  |---|---|---|
  | Claude Code | `.claude-plugin/plugin.json` + `marketplace.json` in the repository | Users run `/plugin marketplace add samuel-neveugall/client-dossier` then `/plugin install client-dossier@client-dossier`. Submit to the official Anthropic marketplace once v1 is stable. |
  | Codex CLI and app | `.codex-plugin/plugin.json` + `.agents/plugins/marketplace.json` | Submit a PR to the OpenAI plugins repository. |
  | Cursor, Copilot CLI, Gemini CLI, OpenCode, others | Agent Skills standard: `skills/*/SKILL.md` | Installable with the `skills` CLI (`npx skills add samuel-neveugall/client-dossier`) or by copying `skills/` into the harness's skills directory. Listed on the skills directory. |
  | Any harness | `AGENTS.md` at the repository root of the dossier (written by init) | Works with no plugin installed: the instructions file points to the protocol. |
  Submission processes of the two official marketplaces must be checked at submission time.
  Versioning: semver, `CHANGELOG.md`, a git tag per release; version lives in both
  manifests; a release script bumps them together. License: MIT.

## Scope of v1

- source: docs/superpowers/specs/2026-09-16-client-dossier-design.md (§10)
- type: nfr
- content:
  In: the six skills, the two agents, the three hooks, the linter, the templates, the two
  manifests, the README with per-harness installation, the fixtures and lint tests, the
  baseline scenarios recorded for each skill.
  Out: transcript fetchers for recording services, document rendering, a web UI,
  multi-user sync beyond git, automatic sending of anything.

## Alternatives considered (rejected designs, retained for constraint traceability)

- source: docs/superpowers/specs/2026-09-16-client-dossier-design.md (§9)
- type: nfr
- content:
  A. Skills only, no agents/hooks/linter — rejected as the whole design (the two most
  important behaviours — never edit sources, update dossier before handoff — are exactly
  the ones an agent rationalises away); kept as fallback behavior on harnesses without
  hooks.
  B. A single monolithic `dossier` skill — rejected because ingest/draft/call have
  different read sets and outputs and a single description triggers poorly; kept the idea
  of one entry skill that routes to the others.
  C. Structured data (YAML/JSON per fact) instead of Markdown lines — rejected: humans
  read/edit the dossier and prose lines with a parenthetical source are enough for an
  agent to correct and cite; the linter checks the shape of a line, not a schema.
  D. Bundling the document rendering pipeline — rejected for v1 (brand-specific,
  Chrome-specific); the plugin keeps only the rule that a rendered deliverable has its
  source next to it; a rendering plugin can hook into `outbound/deliverables/` later.
