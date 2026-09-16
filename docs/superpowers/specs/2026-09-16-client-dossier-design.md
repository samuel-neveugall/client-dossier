# client-dossier: design spec

Status: approved for implementation, 2026-09-16 (draft reviewed the same day; the decisions of
section 11 are settled). Author: Samuel Neveu, drafted with Claude Code.
Name: `client-dossier`. Repository: `samuel-neveugall/client-dossier` (to create).
Language of the plugin: English. Language of the dossier content: whatever the user works in.

## 1. What this is

`client-dossier` is a plugin for coding agents (Claude Code first, then Codex, Cursor,
Copilot CLI, Gemini CLI, OpenCode through the Agent Skills standard) that turns a git
repository into the **memory and the workbench of a relationship with an external party**:
a client, a partner, a prospect, an intermediary, a recruiter.

It codifies a method that was built by hand inside a live consulting engagement repository:
a folder of immutable sources, a living dossier where every fact is dated and sourced, an
outbound folder where every draft carries a status header and a human sends, and a doctrine
that every outgoing document is checked against. The method worked because the agent was told
exactly what to read before writing and what to update before handing back. The plugin makes
that contract portable.

The plugin does three things:

1. **Scaffolds** the structure with templates and a config file.
2. **Teaches** the agent, through skills, the read-before-act and update-before-handoff
   protocol, and the way facts, questions, commitments and drafts are written.
3. **Enforces** the mechanical parts (sources are immutable, drafts carry a status header,
   dates are absolute, confidential names never leave the internal folders) with a linter and,
   where the harness supports it, hooks.

It does not send anything, ever. It does not render documents (a rendering pipeline is a
separate concern, see section 11).

## 2. The logic, exactly as it exists today

This section describes the method as observed in the origin repository, so that the plugin
reproduces it faithfully and so that the generalisation in section 3 is traceable. The origin
repository used French folder and file names; they are given here under the English names the
plugin uses, since the plugin ships English names only.

### 2.1 Four folders, four regimes

| Folder | Regime | Rule |
|---|---|---|
| `sources/` | Immutable | Documents received (brochures, internal notes, transcripts with their raw JSON, `pdftotext` extractions next to PDFs). Never modified, never corrected, even when a transcript is wrong. |
| `dossier/` | Living | One fact per line, dated, with its source. A session that reads or writes a message, prepares a call or learns something updates the concerned file before handing back. Correct a line rather than add a contradictory one. |
| `knowledge/` | Internal knowledge | The one-page context, the doctrine (what we say, what we never say, the vocabulary), dated decision logs (one decision per line, who carried it, source timestamp), a watch folder. |
| `outbound/` | Outbound | Everything addressed to the counterpart or prepared for them: deliverables (source file next to the rendered file, same name), mails (one file per message), calls (preparation, then minutes). Named `YYYY-MM-DD_slug`. Every file opens with a status header. Nothing leaves without a human. |

### 2.2 The seven files of the living dossier

| File | Holds | Updated when |
|---|---|---|
| `ACTORS.md` | Who is who on every side: role, decision power, what they expect, their constraints, their stated principles. Grouped by side (ordering party, end client, us). | A new actor appears or a role becomes clearer. |
| `HISTORY.md` | Chronology by day or milestone, each line sourced. Then two standing sections: **commitments in progress** (ours, theirs) and **upcoming** (dated deadlines). | After every call, mail or document sent. |
| `LEARNINGS.md` | What the exchanges teach about the counterpart: how they speak and think (their words, their principles, what they react to), what they expect of a document, what the case teaches, known pitfalls. | An exchange reveals a new trait or contradicts an old one. |
| `TONE.md` | The voice in one sentence, what is established, what each exchange added, the structure of a long document and of a short message, and a **Refused** log where every reviewer comment on a draft is recorded with its date. | Every time a human reviews a draft. |
| `CHANNELS.md` | How we communicate: video and recording etiquette, documents, mail addresses, call habits, the repository itself and its confidentiality level. | A channel or an access changes. |
| `OPEN-QUESTIONS.md` | Three tables: answered (question, answer, source), still open on the counterpart side (question, why it matters, when to ask), and what we would ask the end client. | After every call. |
| `RELATIONSHIP.md` | One-line status, a metrics table (duration, amount committed, contacts, deadlines, confidentiality), our view, their view as we reconstruct it, concrete improvements, sales opportunities ranked by probability, points to keep in mind. | At every milestone and at least weekly while the deal is open. |

### 2.3 The writing rules

- One fact per line. Every line carries a date and a source: a transcript timestamp
  (`@mm:ss`), a mail, a file and page. A line without a source is an opinion and says so.
- Dates are absolute in the dossier and the docs. "Tomorrow" is converted before writing.
- Correct a line rather than add a contradictory one. Each file starts with "Last updated:
  date, after which event".
- Transcripts are automatic and unreviewed: a quote is checked in context before it is
  reused, and the source file is never corrected.
- Confidential names (the counterpart organisation, the end client) are written in the
  internal folders and never in outbound files, unless written consent is recorded.
- Typographic and register rules are project-specific (the origin project bans the em dash
  and imposes a corporate register) and live in the tone file, not in the plugin.

### 2.4 The session protocol

| Task | Read first | Update before handing back |
|---|---|---|
| Any session | context one-pager, history | nothing, unless something was learned |
| Write a message or a document for the counterpart | tone, learnings, doctrine, decisions | history (commitment taken, date), tone if a human gave feedback |
| Prepare a call | open questions, previous call files | a call file in outbound with objectives, agenda, what we do not do |
| Debrief a call | the transcript | history, open questions (answered, new), learnings, actors, channels, relationship at a milestone |
| Check a fact | sources | the line that was wrong |
| Ingest a source | nothing | sources (file plus text extraction), then every dossier file the source touches |

### 2.5 What the agent never does

- Send a message or a document. Drafts go to outbound with a status header; humans send.
- Modify anything in sources.
- Name a confidential party in an outbound file.
- Promise what the doctrine forbids (in the origin project: a deadline, a rate, a closed
  solution before scoping).
- Leave a `.claude/` folder in a subfolder (the symptom of an agent launched from the wrong
  directory).

## 3. Generalised model

### 3.1 Vocabulary

| Term | Meaning |
|---|---|
| Dossier | The whole repository, or the part of a repository, that holds one relationship. |
| Counterpart | The external party the dossier is about. There may be several (an intermediary and an end client). |
| Source | A document received or recorded. Immutable. |
| Fact | One line in a living file, dated, sourced. |
| Commitment | Something one side said it would do, with an owner and a date. |
| Draft | An outbound file not yet sent. Carries a status header. |
| Doctrine | What we say, what we never say, the vocabulary we use, checked before anything leaves. |
| Decision | A dated internal choice with an owner and a source. |

### 3.2 Layout (fixed English names)

```
dossier.yaml            config: counterparts, confidential names, language
sources/                immutable: received/, transcripts/ (+ raw/), extractions next to PDFs
dossier/                living: ACTORS.md HISTORY.md LEARNINGS.md TONE.md CHANNELS.md
                        OPEN-QUESTIONS.md RELATIONSHIP.md README.md
knowledge/              CONTEXT.md DOCTRINE.md decisions/YYYY-MM-DD_slug.md watch/
outbound/               deliverables/ mails/ calls/  (files named YYYY-MM-DD_slug.*)
```

Folder and file names are fixed and English. They are not configurable: skills, hooks, the
linter and the templates all rely on the same names, and a dossier must look the same in every
repository so that any agent, on any harness, finds its way without reading a mapping. An
existing repository with other names renames its folders and files to adopt the plugin
(`dossier-init` offers to do the renames with `git mv`). The dossier content, headings included,
stays in the configured language; only paths and **protocol keywords** are English. Protocol
keywords are the labels the linter and the skills look for: the `Last updated:` line of a
living file, the field names of the status header (`Status:`, `To:`, `Subject:`, `Deadline:`,
`Written by:`, `Rules:`) and the status values (`draft`, `reviewed by`, `sent`). They are
never translated, for the same reason paths are not: a regex has to find them in every
dossier, and a per-language table would have to be kept in sync between the templates and
the linter. Section headings, example lines and everything the human reads are translated.

Git does not track empty folders, so every leaf folder the scaffold creates and leaves
empty (`sources/received/`, `sources/transcripts/raw/`, `knowledge/decisions/`,
`knowledge/watch/`, `outbound/deliverables/`, `outbound/mails/`, `outbound/calls/`) gets a
`.gitkeep`. The linter ignores `.gitkeep` files.

```yaml
# dossier.yaml
version: 1
language: fr                      # language of the dossier content
counterparts:
  - name: "Acme Consulting"        # internal name, never in outbound
    role: ordering party
    contacts: [ "Jane Doe" ]
  - name: "Big Telco"
    role: end client
confidential_names: [ "Acme", "Big Telco" ]   # linter fails if found under outbound/
consent_recorded: false           # true only with consent_source filled in
consent_source: ""                # e.g. "mail 2026-09-16 from Jane"; required when true
timestamps: "@mm:ss"              # transcript citation format
date_format: "YYYY-MM-DD"
status_header: required           # outbound files must open with a status block
staleness_days: 7                 # dossier-status flags living files older than this
```

`consent_recorded: true` without a non-empty `consent_source` is a lint error: a consent
without a source is an opinion, like any other unsourced line.

The plugin locates a dossier by finding `dossier.yaml` in the working directory or a parent.
A repository can hold several dossiers (one per counterpart) in subfolders, each with its own
`dossier.yaml`; the skills operate on the nearest one.

### 3.3 The status header

Every outbound file opens with a status block, in the file's own comment syntax
(`<!-- -->` in HTML and Markdown, `#` lines in plain text):

```
Status: draft | reviewed by <name> | sent <date time> by <name>
To: <recipient>
Subject: <subject>            (mails)
Deadline: YYYY-MM-DD          (optional: when the draft has to be sent)
Written by: <human or "agent session, YYYY-MM-DD">
Rules: no confidential names; see knowledge/DOCTRINE.md
```

Field names and status values are protocol keywords (English, fixed, see 3.2); the values
after the colon are in the dossier's language. `Deadline:` is the single place
`dossier-status` reads to find overdue drafts; the history line written by `dossier-draft`
repeats the date for humans but is not parsed.

The linter fails on an outbound file without a status block, on a `sent` status without
a date and a sender, and on a `Deadline:` that is not an absolute date.

### 3.4 The fact line

```
- <fact, one sentence, absolute dates> (<source>, <locator>).
```

Sources: `call @12:34`, `mail 2026-09-16 from Jane`, `brochure p. 4`, `internal note p. 15`.
A line whose source is a reconstruction (their view as we reconstruct it) says "reconstructed".

## 4. Plugin architecture

```
client-dossier/
  .claude-plugin/plugin.json          Claude Code manifest
  .claude-plugin/marketplace.json     self-hosted marketplace (one plugin)
  .codex-plugin/plugin.json           Codex manifest
  .agents/plugins/marketplace.json    Codex marketplace listing
  skills/
    dossier/SKILL.md                  the protocol: layout, read-before-act, update-before-handoff
    dossier-init/                     scaffold a dossier
      SKILL.md                        judgement: the grouped question, language inference, rename proposal
      scripts/
        init.py                       mechanics tier, referenced as ${CLAUDE_SKILL_DIR}/scripts/init.py
      templates/
        en/                           twelve template files (seven living files, two knowledge
                                       stubs, three folder READMEs) plus AGENTS-pointer.md, the
                                       protocol-pointer body upserted into AGENTS.md/CLAUDE.md
        fr/                           the same thirteen files, French headings, English protocol keywords
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
    release.sh                        bumps the version in both manifests, tags
  tests/                              fixture dossiers and the bash runner for lint.py
  docs/                               this spec, the protocol reference, the fact-line reference
  README.md  LICENSE  CHANGELOG.md
```

`.claude-plugin/plugin.json` exists from the first commit that ships a skill, in its minimal
form (name, version, description), so that the plugin loads locally with
`claude --plugin-dir .` during development; the marketplace files and the Codex manifests
complete it at distribution time.

A skill's own directory may bundle its own `scripts/` and other resources under the Agent
Skills standard, and that is where a skill's *private* mechanics and assets live — `dossier-init`
above is the only skill that needs any today. A script shared by several skills, such as
`lint.py`, stays at the repository-root `scripts/` instead. A bundled resource is referenced
from `SKILL.md` as `${CLAUDE_SKILL_DIR}/…`, never by a relative path, because a skill's working
directory at invocation is the user's dossier repository, not the plugin. `dossier.yaml` is
emitted by `init.py` from the block in section 3.2 rather than copied from a template file,
which is why no `dossier.yaml` template appears in the tree above.

Principle: **skills carry the judgement, scripts carry the mechanics, hooks carry the
reminders.** Anything a regex can check is in `lint.py`, not in prose. Anything that needs
reading and judgement is in a skill. Hooks never do work; they inject a sentence or refuse a
write.

### 4.1 Skills

All skills follow the Agent Skills standard (`SKILL.md` with `name` and `description`
frontmatter) so that every harness that reads `skills/` can load them. Descriptions are
written for triggering: they name the situations, not the features.

**`dossier`** (the protocol, always loaded first)
- Triggers: any task in a repository that has a `dossier.yaml`, or any mention of a client,
  counterpart, prospect, partner relationship, a call to prepare or debrief, a message to
  write to someone outside the team.
- Content: the layout, the read-before-act table, the
  update-before-handoff rule, the fact line, the status header, what the agent never does,
  and the one-sentence pointers to the other five skills.
- Sets the rule that the agent writes in the dossier's language.

**`dossier-init`**
- Asks (or reads from arguments): counterpart names and roles, confidential names, language,
  whether the repository already has folders to rename.
- Writes `dossier.yaml`, the folders (with a `.gitkeep` in every empty leaf folder), the
  seven living files from templates (each with a "Last updated" line and its "Updated when"
  rule in a comment), `knowledge/CONTEXT.md`, `knowledge/DOCTRINE.md` with the two lists
  (what we say, what we never say) to fill, and one README per top-level folder:
  `dossier/README.md`, `sources/README.md`, `outbound/README.md` (the latter restates the
  status header, the naming rule and what each of the three subfolders holds).
- Adds a short section to the repository's instructions file (`CLAUDE.md`, `AGENTS.md`)
  pointing to the protocol, so that a session without the plugin still finds the rules.
- On an existing repository: detects folders that play the same role under other names,
  proposes the `git mv` renames to the fixed English names, then writes only what is missing.

**`dossier-ingest <path or URL>`**
- Files the source under `sources/` with the `YYYY-MM-DD_slug` name, runs the text extraction
  for PDFs (`extract-text.sh`, which needs `pdftotext` from poppler; when it is missing the
  script exits with an install hint, the PDF is still filed and the skill reports that
  extraction was skipped), keeps raw exports next to transcripts.
- Dispatches `fact-extractor` on the source (one agent per source, so the long text stays
  out of the main context). Receives a proposal: lines grouped by target file, each with its
  locator.
- Applies the proposal to the living files: appends under the right heading, corrects a
  contradicted line instead of adding, updates "Last updated".
- Reports what changed and what was left out as uncertain.
- Optional integration: a `fetchers/` folder for transcript services (the origin project had
  a shell fetcher for one recording service). Not in v1; the skill accepts a local file.

**`dossier-draft <kind> <slug>`** (kinds: mail, message, deliverable, note)
- Reads tone, learnings, doctrine, decisions, and the last outbound files of the same kind.
- Writes the draft under the right outbound folder, with the status header, in the dossier's
  language, following the structure recorded in the tone file for that kind.
- Dispatches `doctrine-reviewer` on the draft. Applies the findings or lists the ones it
  disagrees with.
- Runs `lint.py` on the file.
- Writes the deadline, when there is one, in the `Deadline:` field of the status header, and
  updates history: "draft written, to be sent by <human>, deadline <date>".
- Never marks a draft as sent. The human edits the status line after sending; the next
  `dossier-status` picks it up.

**`dossier-call prepare <date> <slug>` and `dossier-call debrief <transcript>`**
- Prepare: writes a call file in `outbound/calls/` with context, what we want to obtain,
  a timed agenda, what we do not do in this call, and the open questions to ask (pulled from
  the open questions file, ordered by "when to ask"). Leaves an empty minutes section.
- Debrief: ingests the transcript through `dossier-ingest`, then fills the minutes section,
  moves answered questions to the answered table with their timestamp, adds new
  commitments to history with owners and dates, and updates the relationship file if the
  call was a milestone.

**`dossier-status`**
- Prints: the one-line status, commitments due with their dates, sources ingested but not
  reflected (a source newer than every living file), outbound drafts still marked draft past
  the `Deadline:` of their status header, living files not updated for more than
  `staleness_days` (7 by default), lint findings.
- Read-only. This is the "where are we" a human asks at the start of a session.

### 4.2 Agents

Agents exist so that long reading and fresh-eyes review happen outside the main context.
They are Claude Code subagents (`agents/*.md`); on harnesses without subagents the skills say
to perform the same steps inline.

**`fact-extractor`** (read-only: Read, Grep, Glob)
- Input: one source path, the dossier config, the current headings of the living files.
- Output: a structured proposal, grouped by target file and heading, each line with its
  locator, plus a "contradicts" list (existing line, proposed correction, why) and an
  "uncertain" list.
- Rules baked in: one fact per line, absolute dates, quote checked in context, never
  paraphrase a number, do not invent a source.

**`doctrine-reviewer`** (read-only)
- Input: a draft path, the doctrine, the tone file (including the Refused log), the
  confidential names.
- Output: findings ranked by severity: a confidential name, a forbidden claim from the
  "what we never say" list, a refused pattern from the tone log, a promise without a source,
  a relative date, a departure from the recorded structure for that kind of document.
- Does not rewrite. It reports; the drafting skill decides.

### 4.3 Hooks (Claude Code; mirrored for harnesses that support hooks)

| Event | Behaviour |
|---|---|
| SessionStart | If a `dossier.yaml` is found from the working directory upward, inject two lines: "This repository is a client dossier. Load the `dossier` skill before acting." Nothing otherwise. |
| PreToolUse on Write, Edit, MultiEdit | If the target path is under the sources folder, deny with the message "sources are immutable; file a correction in the dossier instead". |
| Stop | If `git status` shows changes under outbound or sources and none under the dossier folder, print a warning: "outbound or sources changed, dossier not updated; run dossier-status". Warning only, never blocks. |

Hooks are a convenience. The skills state the same rules so that a harness without hooks
gets the same behaviour from prose.

### 4.4 The linter (`scripts/lint.py`)

Python 3 standard library only. Reads `dossier.yaml` (a tiny YAML subset parser, or JSON as
a fallback, to avoid a dependency). Checks:

1. Every outbound file opens with a status block; a `sent` status has a date and a sender;
   a `Deadline:` field, when present, is an absolute date.
2. Outbound file names match `YYYY-MM-DD_slug`.
3. No confidential name appears under outbound, unless `consent_recorded: true` with a
   non-empty `consent_source`; `true` without a source is itself an error.
4. Every living file has a `Last updated:` line (fixed English label) with an absolute date.
5. No relative date words in the dossier and knowledge folders (a small per-language list:
   "tomorrow", "next week", "demain", "la semaine prochaine"), reported as warnings.
6. Every bullet line in the living files ends with a source in parentheses; lines without
   one are warnings, not errors (a bilingual list of allowed "opinion" markers).
7. No `.claude/` folder below the repository root.
8. Deliverables: a rendered file (`.pdf`, `.docx`) has its source (`.html`, `.md`) next to it
   with the same stem.

Exit code 1 on errors, 0 on warnings only. `dossier-lint` command and `dossier-status` call it.
The linter looks for protocol keywords only (section 3.2); it never needs to know the
dossier's language except for the two warning word lists of checks 5 and 6.

### 4.5 Templates

One template per living file, containing: the title, the `Last updated:` line, the "Updated
when" rule as a comment, the headings, and one example line in the fact format. Templates
exist in English; `dossier-init` translates the title, the headings, the comment and the
example line into the configured language at scaffold time (the skill does the translation,
the template is the source of structure). Protocol keywords (section 3.2) are left as they
are.

Three README templates, one per top-level folder that needs one (`dossier/`, `sources/`,
`outbound/`); the outbound README restates the status header, the naming rule and the role of
its three subfolders. A `.gitkeep` template is not needed: the file is empty.

## 5. Data flow

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

## 6. Error handling and edge cases

- No `dossier.yaml` found: every skill except `dossier-init` stops and says so.
- A source already filed (same hash): ingest reports it and does not duplicate.
- A fact contradicts an existing line: the extractor proposes a correction; the ingest skill
  applies it and appends "(corrects a line dated <date>)" so the change is traceable.
- Two counterparts with the same first name: actors file disambiguates with the
  organisation; the skills always write "Name (Organisation)" on first mention in a file.
- A draft must name the counterpart (consent recorded): the linter reads
  `consent_recorded` and `consent_source` from config; the reviewer still flags the
  name as informational.
- `pdftotext` is not installed: `extract-text.sh` exits non-zero with an install hint, the
  PDF is filed anyway and `dossier-ingest` reports the extraction as skipped; the facts can be
  extracted later by re-running the ingest on the filed PDF.
- The plugin was installed as bare skills (no `scripts/`): the skills that call `lint.py` or
  `extract-text.sh` check that the script exists first and, when it does not, say so and state
  the rule the script would have checked, so the session still behaves.
- Transcript timestamps absent (a mail thread, a PDF): locator becomes page, paragraph or
  the mail date and sender.
- The harness has no subagents: the skills contain the inline procedure and say when the
  main agent is doing the extractor's or reviewer's job itself.

## 7. Testing

Skills are tested the way `superpowers:writing-skills` prescribes: a pressure scenario is
run without the skill, the failure is recorded, the skill is written to address it, the
scenario is rerun.

Baseline scenarios to record before writing each skill:

1. Agent is asked to "write a quick reply to the client" in a repository with a dossier.
   Expected failure without the skill: writes inline, never reads tone, never updates
   history, may name the confidential party.
2. Agent is given a transcript and asked "what did we learn". Expected failure: summary in
   chat, nothing filed, no timestamps.
3. Agent is asked to "fix the typo in the transcript". Expected failure: edits the source.
4. Agent is asked "where are we with this deal". Expected failure: re-reads everything,
   answers from memory, misses due commitments.
5. Agent is asked to prepare tomorrow's call. Expected failure: writes "tomorrow", does not
   pull open questions, no "what we do not do" section.

Mechanical tests (`tests/`): fixture repositories (a clean layout that exits 0, one with
French-language dossier content to check the relative-date and opinion-marker word lists, and
error fixtures that together trigger every error-class check of section 4.4 at least once) and
a shell test runner that runs `lint.py` and asserts exit codes and messages. No test framework
beyond bash and python3.

During development the plugin is loaded from the working copy with `claude --plugin-dir .`;
this is how the skills, the hooks and the pressure scenarios are exercised before any
marketplace exists.

Plugin-level: `claude plugin eval` suites for the trigger descriptions once the skills exist
(verify that "write to the client" triggers `dossier-draft` and not `dossier-ingest`).

## 8. Distribution

| Target | Mechanism | Action |
|---|---|---|
| Claude Code | `.claude-plugin/plugin.json` + `marketplace.json` in the repository | Users run `/plugin marketplace add samuel-neveugall/client-dossier` then `/plugin install client-dossier@client-dossier`. Submit to the official Anthropic marketplace once v1 is stable. |
| Codex CLI and app | `.codex-plugin/plugin.json` + `.agents/plugins/marketplace.json` | Submit a PR to the OpenAI plugins repository. |
| Cursor, Copilot CLI, Gemini CLI, OpenCode, others | Agent Skills standard: `skills/*/SKILL.md` | Installable with the `skills` CLI (`npx skills add samuel-neveugall/client-dossier`) or by copying `skills/` into the harness's skills directory. Listed on the skills directory. |
| Any harness | `AGENTS.md` at the repository root of the dossier (written by init) | Works with no plugin installed: the instructions file points to the protocol. |

The submission processes of the two official marketplaces have to be checked at submission
time; the repository layout above mirrors a plugin already published on both.

Versioning: semver, `CHANGELOG.md`, a git tag per release. The version lives in both
manifests; `scripts/release.sh <version>` bumps them together, updates the changelog heading
and creates the tag.

The bare-skills path (third row) ships `skills/` only: no `scripts/`, no hooks, no agents.
The skills are written for that case (section 6, last two items).

License: MIT.

## 9. Alternatives considered

**A. Skills only, no agents, no hooks, no linter.** Smallest surface, fully portable. Rejected
as the whole design because the two behaviours that matter most (never edit sources, update
the dossier before handing back) are exactly the ones an agent rationalises away; a guard
and a warning cost almost nothing. Kept as the fallback behaviour on harnesses without hooks.

**B. A single monolithic `dossier` skill.** One file, one trigger. Rejected because ingest,
draft and call have different read sets and different outputs, and a single description
triggers poorly. Kept the idea of one entry skill that routes to the others.

**C. Structured data (YAML or JSON per fact) instead of Markdown lines.** Easier to lint and
query. Rejected: humans read and edit the dossier, and the origin repository showed that
prose lines with a source in parentheses are enough for an agent to correct and cite. The
linter checks the shape of a line, not a schema.

**D. Bundling the document rendering pipeline (design file, CSS, HTML to PDF).** Rejected for
v1: it is brand-specific and Chrome-specific. The plugin keeps only the rule that a rendered
deliverable has its source next to it. A rendering plugin can come later and hook into
`outbound/deliverables/`.

## 10. Scope of v1

In: the six skills, the two agents, the three hooks, the linter, the templates, the two
manifests, the README with per-harness installation, the fixtures and lint tests, the
baseline scenarios recorded for each skill.

Out: transcript fetchers for recording services, document rendering, a web UI, multi-user
sync beyond git, automatic sending of anything.

## 11. Decisions (settled 2026-09-16)

1. **Name: `client-dossier`.** The plugin is `client-dossier`, the entry skill is `dossier`;
   the two names differ and read naturally together (`client-dossier@client-dossier`, skill
   `dossier`). `dossier` alone was rejected as generic on a marketplace search.
2. **Folder names: `dossier/` and `outbound/`.** `relationship/` and `communication/` were
   rejected; the names are now fixed and hard-coded everywhere.
3. **Stop hook: decided during Phase 3 planning.** The spec ships it by default; the decision
   only affects that phase and is deferred to it.
4. **Protocol keywords stay English.** The `Last updated:` label, the status-header field
   names and the status values are never translated (section 3.2). Alternatives rejected: a
   per-language label table in the linter (two places to keep in sync, breaks on an unlisted
   language); an English machine-readable comment next to a translated label (two labels for
   one fact).
5. **Contradictions of the draft resolved** in favour of the smaller surface: one README per
   top-level folder rather than one per outbound subfolder, plus `.gitkeep` files;
   `staleness_days` added to `dossier.yaml`; `consent_source` added next to
   `consent_recorded`; `Deadline:` added to the status header as the single place the
   overdue-draft check reads.

## 12. Spec self-review

- No placeholder: every skill, agent, hook and script has inputs, outputs and rules.
- Consistency: folder and file names are English everywhere (sections 2, 3.2, 4, 5) and match
  the linter, the hooks and the data flow; nothing is remappable.
- Scope: one implementation plan covers it; the plan will order init, lint, protocol skill,
  then ingest with the extractor, then draft with the reviewer, then call and status, then
  manifests and distribution.
- Ambiguity resolved: "update before handing back" means the same session, before its final
  message; the Stop hook is the reminder, not the mechanism.
- Second pass (2026-09-16): every value the linter reads has a home (`staleness_days`,
  `consent_source`, `Deadline:`) and a fixed English spelling; every external dependency
  (`pdftotext`, `scripts/` in a bare-skills install) has a stated fallback; the plugin can be
  loaded and tested from the first skill onward (`--plugin-dir`).
