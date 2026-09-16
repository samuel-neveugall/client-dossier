# Roadmap: client-dossier

## Overview

Seven phases build the plugin in the exact order the design spec's self-review (§12)
prescribes: scaffold the structure first, then the mechanical linter that everything else
leans on, then the protocol skill and hooks that teach the rules, then the two write-paths
that actually touch the dossier (ingest, then draft, each paired with its own read-only
review agent), then the call/status workflow that ties them together, and finally the
manifests, docs and distribution plumbing that make the plugin installable. Each phase ships
one coherent, independently testable slice; nothing in a later phase is needed to verify an
earlier one.

**Before Phase 1 starts:** three naming decisions are still open (PROJECT.md § Open
Decisions) — the final plugin name, `dossier/` vs `relationship/` and `outbound/` vs
`communication/` for the two folders, and whether the Stop hook ships in v1. Folder names in
particular are fixed once `dossier-init`, the templates, and the linter hard-code them in
Phase 1 — resolve #1 and #2 before or during Phase 1 planning, not after.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

- [ ] **Phase 1: Scaffold & Templates** - `dossier-init` scaffolds a full dossier repo from `dossier.yaml` and templates
- [ ] **Phase 2: Linter & Test Harness** - `scripts/lint.py` mechanically enforces the shape of a dossier, proven by fixtures
- [ ] **Phase 3: Protocol Skill & Hooks** - the `dossier` skill and its three hooks teach and enforce the read-before-act contract
- [ ] **Phase 4: Ingest & Fact Extraction** - `dossier-ingest` files sources and turns them into dated, sourced facts
- [ ] **Phase 5: Drafting & Doctrine Review** - `dossier-draft` writes outbound content that a doctrine review has already checked
- [ ] **Phase 6: Calls & Status** - `dossier-call` and `dossier-status` close the loop on preparation, debrief, and "where are we"
- [ ] **Phase 7: Manifests, Docs & Distribution** - both manifests, commands, README/LICENSE/CHANGELOG, and trigger-description eval

## Phase Details

### Phase 1: Scaffold & Templates
**Goal**: Running `dossier-init` turns any repository (empty or pre-existing) into a
correctly laid-out dossier in one step.
**Depends on**: Nothing (first phase)
**Requirements**: SCAF-01, SCAF-02, SCAF-03, SCAF-04, SCAF-05, SCAF-06, SCAF-07
**Success Criteria** (what must be TRUE):
  1. Running `dossier-init` in an empty repo creates `dossier.yaml`, the four top-level
     folders with their subfolders, and all seven living files pre-filled from templates
     with a "Last updated" line and its "Updated when" comment.
  2. `knowledge/CONTEXT.md`, `knowledge/DOCTRINE.md` (with its two lists to fill),
     `outbound/README.md`, and `sources/README.md` all exist after init.
  3. The repository's `CLAUDE.md`/`AGENTS.md` gains a short section pointing to the dossier
     protocol.
  4. Running `dossier-init` in an existing repo with differently-named folders proposes
     `git mv` renames instead of creating duplicate structure.
  5. Living-file headings appear in the language configured in `dossier.yaml`, while every
     path stays English.
**Plans**: TBD

### Phase 2: Linter & Test Harness
**Goal**: Anyone (human or agent) can mechanically verify a dossier obeys the plugin's rules
with zero setup beyond python3.
**Depends on**: Phase 1 (needs the folder layout and living-file shape to check against)
**Requirements**: LINT-01, LINT-02, LINT-03
**Success Criteria** (what must be TRUE):
  1. Running `scripts/lint.py` against a clean fixture dossier exits 0.
  2. Running it against fixtures with a missing status header, a malformed outbound
     filename, a leaked confidential name, or a missing "Last updated" line exits 1 and
     names the violation.
  3. Running it against the French-language fixture correctly flags relative-date words and
     unsourced bullet lines as warnings (exit 0, not 1).
  4. A bash test runner in `tests/` runs every fixture and asserts `lint.py`'s exit codes
     and messages, and passes end to end.
**Plans**: TBD

### Phase 3: Protocol Skill & Hooks
**Goal**: Every session in a dossier repository is told the rules before it has a chance to
break them, on any harness.
**Depends on**: Phase 1 (layout to describe), Phase 2 (lint.py to reference from the skill
and from `dossier-status` later)
**Requirements**: PROTO-01, PROTO-02, PROTO-03, PROTO-04, PROTO-05, PROTO-06, PROTO-07
**Success Criteria** (what must be TRUE):
  1. Loading the `dossier` skill in a repo with `dossier.yaml` surfaces the layout, the
     read-before-act/update-before-handoff table, the fact-line and status-header formats,
     and the "what the agent never does" list; the skill triggers on dossier-shaped tasks
     even before `dossier.yaml` is read.
  2. A SessionStart hook injects the protocol reminder whenever `dossier.yaml` is found
     upward from the working directory, and says nothing otherwise.
  3. An attempt to Write/Edit/MultiEdit a file under the sources folder is denied with the
     immutability message.
  4. Changing files under outbound or sources without touching the dossier folder, then
     stopping, triggers a non-blocking Stop-hook warning pointing at `dossier-status`.
  5. The "fix the typo in the transcript" pressure scenario, run without the skill/hooks,
     edits the source (RED); run with them, the agent refuses and points to filing a
     correction instead (GREEN).
**Plans**: TBD

### Phase 4: Ingest & Fact Extraction
**Goal**: Any source that arrives gets filed exactly once, immutably, and its facts land in
the right living files with a checkable citation.
**Depends on**: Phase 1 (folders to file into), Phase 3 (protocol rules the skill must obey:
never touches sources, updates before handoff)
**Requirements**: INGEST-01, INGEST-02, INGEST-03, INGEST-04, INGEST-05
**Success Criteria** (what must be TRUE):
  1. Running `dossier-ingest` on a PDF files it under `sources/` as `YYYY-MM-DD_slug`,
     extracts its text via `extract-text.sh`, and reports the `fact-extractor`'s proposal
     applied to the correct living files with "Last updated" refreshed.
  2. Re-ingesting the same file (same hash) is reported as already filed, not duplicated.
  3. A fact that contradicts an existing line produces a corrected line annotated
     "(corrects a line dated <date>)" instead of a new contradictory line.
  4. The "given a transcript, what did we learn" pressure scenario moves from RED (summary
     only in chat, nothing filed, no timestamps) to GREEN (facts filed with sourced
     timestamps, nothing left only in chat).
**Plans**: TBD

### Phase 5: Drafting & Doctrine Review
**Goal**: A draft addressed to the counterpart is never one unreviewed step away from going
out.
**Depends on**: Phase 3 (tone/doctrine/status-header rules the skill applies), Phase 4
(history and learnings the draft skill reads before writing)
**Requirements**: DRAFT-01, DRAFT-02, DRAFT-03, DRAFT-04
**Success Criteria** (what must be TRUE):
  1. Running `dossier-draft mail <slug>` produces a file under `outbound/mails/` with a
     complete status header, written in the dossier's language, following the tone file's
     recorded structure.
  2. The `doctrine-reviewer`'s findings (confidential name, forbidden claim, refused
     pattern, unsourced promise, relative date) are applied or explicitly listed as
     disagreements before the draft is left for a human.
  3. `lint.py` runs against every draft `dossier-draft` produces, history gains a commitment
     line, and the draft's status is never set to "sent" by the skill itself.
  4. The "write a quick reply to the client" pressure scenario moves from RED (inline reply,
     tone/history never touched, confidential name possibly leaked) to GREEN.
**Plans**: TBD

### Phase 6: Calls & Status
**Goal**: A human always knows what's due, and walks into every call already prepared.
**Depends on**: Phase 4 (ingest, used by call debrief), Phase 5 (outbound conventions call
prep reuses)
**Requirements**: CALL-01, CALL-02, CALL-03, CALL-04, CALL-05
**Success Criteria** (what must be TRUE):
  1. `dossier-call prepare <date> <slug>` produces a call file with context, objectives, a
     timed agenda, a "what we do not do" section, and open questions ordered by urgency,
     with an empty minutes section.
  2. `dossier-call debrief <transcript>` ingests the transcript, fills the minutes, moves
     answered questions to the answered table with timestamps, adds owned/dated commitments
     to history, and updates `RELATIONSHIP.md` when the call is a milestone.
  3. `dossier-status` prints, read-only, the one-line status, due commitments, unreflected
     sources, overdue drafts, stale living files, and lint findings.
  4. The "prepare tomorrow's call" scenario moves from RED (writes "tomorrow", skips open
     questions) to GREEN.
  5. The "where are we with this deal" scenario moves from RED (re-reads everything, misses
     due commitments) to GREEN (uses `dossier-status`).
**Plans**: TBD

### Phase 7: Manifests, Docs & Distribution
**Goal**: Someone outside this repository can install and trust the plugin on the harness of
their choice.
**Depends on**: Phases 1-6 (all six skills and both agents must exist for manifests,
commands, and trigger-description eval to have something to reference)
**Requirements**: DIST-01, DIST-02, DIST-03, DIST-04, DIST-05, DIST-06
**Success Criteria** (what must be TRUE):
  1. `/plugin marketplace add` followed by `/plugin install` installs the plugin end to end
     in Claude Code from `.claude-plugin/plugin.json` + `marketplace.json`.
  2. The Codex manifests (`.codex-plugin/plugin.json`, `.agents/plugins/marketplace.json`)
     and a bare copy of `skills/*/SKILL.md` each install correctly on their respective
     harnesses.
  3. README documents installation for all four distribution targets plus versioning and
     license; `CHANGELOG.md` and an MIT `LICENSE` exist.
  4. Each of the six slash commands under `commands/` invokes its corresponding skill in
     Claude Code.
  5. `claude plugin eval` runs against the trigger descriptions and confirms an ambiguous
     input such as "write to the client" routes to `dossier-draft`, not `dossier-ingest`.
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6 → 7

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Scaffold & Templates | 0/TBD | Not started | - |
| 2. Linter & Test Harness | 0/TBD | Not started | - |
| 3. Protocol Skill & Hooks | 0/TBD | Not started | - |
| 4. Ingest & Fact Extraction | 0/TBD | Not started | - |
| 5. Drafting & Doctrine Review | 0/TBD | Not started | - |
| 6. Calls & Status | 0/TBD | Not started | - |
| 7. Manifests, Docs & Distribution | 0/TBD | Not started | - |
