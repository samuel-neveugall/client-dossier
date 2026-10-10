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

**Decisions settled 2026-09-16 (spec §11):** the plugin is `client-dossier`, the folders are
`dossier/` and `outbound/`, protocol keywords (`Last updated:`, status-header fields and
values) stay English and are never translated. The one remaining open point, whether the Stop
hook ships in v1, is decided during Phase 3 planning with Samuel; the spec ships it by default.

**Development loop:** the plugin is loaded from the working copy with `claude --plugin-dir .`
from Phase 1 onward (SCAF-08); no marketplace is needed before Phase 7.

## Phases

**Phase Numbering:**

- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

- [x] **Phase 1: Scaffold & Templates** - `dossier-init` scaffolds a full dossier repo from `dossier.yaml` and templates
- [x] **Phase 2: Linter & Test Harness** - `scripts/lint.py` mechanically enforces the shape of a dossier, proven by fixtures (completed 2026-10-10)
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
**Requirements**: SCAF-01, SCAF-02, SCAF-03, SCAF-04, SCAF-05, SCAF-06, SCAF-07, SCAF-08
**Success Criteria** (what must be TRUE):

  1. With the plugin loaded via `claude --plugin-dir .`, running `dossier-init` in an empty
     repo creates `dossier.yaml` (including `consent_source` and `staleness_days`), the four
     top-level folders with their subfolders (a `.gitkeep` in every empty leaf folder), and
     all seven living files pre-filled from templates with a `Last updated:` line and its
     "Updated when" comment.
  2. `knowledge/CONTEXT.md`, `knowledge/DOCTRINE.md` (with its two lists to fill),
     `dossier/README.md`, `sources/README.md` and `outbound/README.md` all exist after init.
  3. The repository's `CLAUDE.md`/`AGENTS.md` gains a short section pointing to the dossier
     protocol.
  4. Running `dossier-init` in an existing repo with differently-named folders proposes
     `git mv` renames instead of creating duplicate structure.
  5. In a dossier configured `language: fr`, titles, headings, comments and example lines
     are in French while every path and every protocol keyword (`Last updated:`, status
     header fields and values) stays English.
**Plans**: 6 plans (all executed; phase implementation complete and mechanically verified —
see note below)

Plans:
**Wave 1**

- [x] 01-01-PLAN.md — tracer: `init.py` scaffolds an empty repo (config, folders, `.gitkeep`, one living file) behind a loadable plugin manifest

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 01-02-PLAN.md — the eleven remaining English templates, the full template map and language-variant resolution

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 01-03-PLAN.md — the French template variant, English keywords intact
- [x] 01-04-PLAN.md — the marker-delimited protocol pointer in `AGENTS.md` and `CLAUDE.md`

**Wave 4** *(blocked on Wave 3 completion)*

- [x] 01-05-PLAN.md — adoption: rename detection and the read-only `git mv` proposal

**Wave 5** *(blocked on Wave 4 completion)*

- [x] 01-06-PLAN.md — the skill's judgement body, plus the spec §4 and `CLAUDE.md` amendments

**Status note (2026-09-16):** all 6 plans executed; independent acceptance re-verification
found SCAF-01…08 (8/8) and the phase's 5 ROADMAP success criteria (5/5) reproduced after 3
rounds of review/fix, including SCAF-06 replayed against the real origin repository under the
confidentiality protocol. Threat T-01-01 closed, confidentiality guarantee D-13 confirmed, no
safety regression. Human recette run on 2026-09-17 (live `--plugin-dir` sessions: conversational scaffold,
idempotent re-run, adoption confirm and decline) — all passed, see
`01-VERIFICATION.md` §Human Verification — Results. **Phase 1 closed 2026-09-17.**

### Phase 2: Linter & Test Harness

**Goal**: Anyone (human or agent) can mechanically verify a dossier obeys the plugin's rules
with zero setup beyond python3.
**Depends on**: Phase 1 (needs the folder layout and living-file shape to check against)
**Requirements**: LINT-01, LINT-02, LINT-03
**Carried-over debt from Phase 1** (found during the Phase 1 review loop, deferred rather than
fixed in a 4th correction round — resolve when writing `lint.py`'s YAML-subset parser, so
producer and consumer are aligned in one move):

  - **(a) YAML 1.1 reserved words.** `init.py`'s `_SAFE_PLAIN_SCALAR_RE`
    (`^[A-Za-z][A-Za-z0-9_-]*$`) lets `yes`, `no`, `on`, `off`, `true`, `false`, `null`, `y`,
    `n` through unquoted. Concretely: `no` is the ISO 639-1 code for Norwegian, so
    `--language no` writes `language: no`, which a strict YAML parser reads back as boolean
    `False`, not the string `"no"`. Not a vulnerability (no key injection possible;
    `consent_recorded` is out of reach) — a typing fidelity gap. Either tighten the producer's
    allowlist or have `lint.py`'s parser read these fields as strings regardless of spelling.
  - **(b) Regex anchoring.** Same regex: Python's `$` also matches just before a trailing
    `\n`, where `\Z` (or `re.fullmatch`) would be strict. A value ending in a newline passes
    the allowlist and leaves a blank line in the file. No key injection — cosmetic, but a real
    bypass of the guard. One-line fix, bundle with (a).

**Success Criteria** (what must be TRUE):

  1. Running `scripts/lint.py` against a clean fixture dossier (with `.gitkeep` files in its
     empty folders) exits 0.
  2. Running it against error fixtures exits 1 and names the violation for each error-class
     check: missing status header, `sent` without date or sender, non-absolute `Deadline:`,
     malformed outbound filename, leaked confidential name, `consent_recorded: true` with an
     empty `consent_source`, missing `Last updated:` line, a `.claude/` folder below the
     root, and a rendered deliverable without its source file next to it.
  3. Running it against the French-language fixture correctly flags relative-date words and
     unsourced bullet lines as warnings (exit 0, not 1), and still finds the English
     `Last updated:` label.
  4. A bash test runner in `tests/` runs every fixture and asserts `lint.py`'s exit codes
     and messages, and passes end to end.
**Plans**: 9/9 plans complete (3 gap-closure plans added after the 2026-09-25 UAT, executed
and re-verified the same day on branch `feat/phase-02-gap-closure`; recette and sign-off 2026-10-10)

Plans:
**Wave 1**

- [x] 02-01-PLAN.md — tracer: `lint.py` finds the root, parses `dossier.yaml` through a
  quotedness-preserving schema, walks the tree, runs E7, reports, and returns 0/1/2 — with the
  bash harness, the fixture generator and the config gate (E6, C1, C0) around it

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 02-02-PLAN.md — the five outbound error classes: status block (E1, E2, E3), filename
  convention (E4), confidential-name leak in text and in filename (E5), plus the consent gate
  and the README exemption boundary
- [x] 02-03-PLAN.md — producer hardening (Phase 1 debts (a) and (b)): reserved YAML spellings
  quoted, the plain-scalar allowlist anchored end to end, with the Phase 1 suite proven green

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 02-04-PLAN.md — E8 and E9, the fixture generator's stated contract, and the nine-class
  positive-plus-negative isolation sweep

**Wave 4** *(blocked on Wave 3 completion)*

- [x] 02-05-PLAN.md — the two warning classes W1 and W2, the single `LANGUAGE_WORDS` data
  block, and the committed French fixture (criterion 3)

**Wave 5** *(blocked on Wave 4 completion)*

- [x] 02-06-PLAN.md — the zero-findings acceptance test in both languages, the
  producer/consumer round trip, and the commands recorded in `CLAUDE.md`

**Wave 6** *(gap closure, UAT 2026-09-25: G-02-2, G-02-4d)*

- [x] 02-07-PLAN.md — tracer: extension keys beside the exact gate keys are ignored (D-22),
  certain misspellings stay C1 with E5 armed, the C1 message says "looks like a misspelling of";
  the two gate lines WR-02 found unpinned are pinned

**Wave 7** *(gap closure: G-02-4a, G-02-4e; blocked on Wave 6 completion)*

- [x] 02-08-PLAN.md — tracer: a case variant of a layout folder (`Outbound/`, `outbound/Mails/`)
  fails closed with E1; unreadable folders and `.git` folders under `outbound/` are E1, never
  skipped in silence

**Wave 8** *(gap closure: G-02-4f, G-02-4c, G-02-4b; blocked on Wave 7 completion)*

- [x] 02-09-PLAN.md — tracer: E5 searches line-preserving haystack variants, so quoted-reply
  wraps, HTML character references and Unicode format characters hide no name; `init.py` never
  writes a format character

### Phase 3: Protocol Skill & Hooks

**Goal**: Every session in a dossier repository is told the rules before it has a chance to
break them, on any harness.
**Depends on**: Phase 1 (layout to describe), Phase 2 (lint.py to reference from the skill
and from `dossier-status` later)
**Requirements**: PROTO-01, PROTO-02, PROTO-03, PROTO-04, PROTO-05, PROTO-06, PROTO-07,
PROTO-08
**Decision to take at planning**: whether the Stop hook (PROTO-06, criterion 4) ships in v1
(spec §11 #3, with Samuel).
**Success Criteria** (what must be TRUE):

  1. Loading the `dossier` skill in a repo with `dossier.yaml` surfaces the layout, the
     read-before-act/update-before-handoff table, the fact-line and status-header formats,
     the "Name (Organisation)" rule, and the "what the agent never does" list; the skill
     triggers on dossier-shaped tasks even before `dossier.yaml` is read.
  2. A SessionStart hook injects the protocol reminder whenever `dossier.yaml` is found
     upward from the working directory, and says nothing otherwise.
  3. An attempt to Write/Edit/MultiEdit a file under the sources folder is denied with the
     immutability message.
  4. Changing files under outbound or sources without touching the dossier folder, then
     stopping, triggers a non-blocking Stop-hook warning pointing at `dossier-status`.
  5. The "fix the typo in the transcript" pressure scenario, run without the skill/hooks,
     edits the source (RED); run with them, the agent refuses and points to filing a
     correction instead (GREEN).
  6. Invoked from a subfolder of a dossier, a skill finds the nearest `dossier.yaml` upward;
     invoked outside any dossier, every skill except `dossier-init` stops with a message.
**Plans**: TBD

### Phase 4: Ingest & Fact Extraction

**Goal**: Any source that arrives gets filed exactly once, immutably, and its facts land in
the right living files with a checkable citation.
**Depends on**: Phase 1 (folders to file into), Phase 3 (protocol rules the skill must obey:
never touches sources, updates before handoff)
**Requirements**: INGEST-01, INGEST-02, INGEST-03, INGEST-04, INGEST-05, INGEST-06
**Success Criteria** (what must be TRUE):

  1. Running `dossier-ingest` on a PDF files it under `sources/` as `YYYY-MM-DD_slug`,
     extracts its text via `extract-text.sh`, and reports the `fact-extractor`'s proposal
     applied to the correct living files with `Last updated:` refreshed.
  2. Re-ingesting the same file (same hash) is reported as already filed, not duplicated.
  3. A fact that contradicts an existing line produces a corrected line annotated
     "(corrects a line dated <date>)" instead of a new contradictory line.
  4. The "given a transcript, what did we learn" pressure scenario moves from RED (summary
     only in chat, nothing filed, no timestamps) to GREEN (facts filed with sourced
     timestamps, nothing left only in chat).
  5. With `pdftotext` absent from PATH, the PDF is still filed and the skill reports the
     extraction as skipped with an install hint; the skill text contains the inline
     extraction procedure for a harness without subagents.
**Plans**: TBD

### Phase 5: Drafting & Doctrine Review

**Goal**: A draft addressed to the counterpart is never one unreviewed step away from going
out.
**Depends on**: Phase 2 (`lint.py`, run on every draft), Phase 3 (tone/doctrine/status-header
rules the skill applies), Phase 4 (history and learnings the draft skill reads before writing)
**Requirements**: DRAFT-01, DRAFT-02, DRAFT-03, DRAFT-04, DRAFT-05
**Success Criteria** (what must be TRUE):

  1. Running `dossier-draft mail <slug>` produces a file under `outbound/mails/` with a
     complete status header (including `Deadline:` when a deadline was given), written in
     the dossier's language, following the tone file's recorded structure.
  2. The `doctrine-reviewer`'s findings (confidential name, forbidden claim, refused
     pattern, unsourced promise, relative date) are applied or explicitly listed as
     disagreements before the draft is left for a human.
  3. `lint.py` runs against every draft `dossier-draft` produces, history gains a commitment
     line, and the draft's status is never set to "sent" by the skill itself.
  4. The "write a quick reply to the client" pressure scenario moves from RED (inline reply,
     tone/history never touched, confidential name possibly leaked) to GREEN.
  5. The skill text contains the inline review procedure for a harness without subagents,
     and says what it does when `lint.py` is absent.
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
     sources, overdue drafts (read from the `Deadline:` field), living files older than
     `staleness_days`, and lint findings.
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
**Requirements**: DIST-01, DIST-02, DIST-03, DIST-04, DIST-05, DIST-06, DIST-07
**Success Criteria** (what must be TRUE):

  1. `/plugin marketplace add` followed by `/plugin install` installs the plugin end to end
     in Claude Code from the completed `.claude-plugin/plugin.json` + `marketplace.json`.
  2. The Codex manifests (`.codex-plugin/plugin.json`, `.agents/plugins/marketplace.json`)
     and a bare copy of `skills/*/SKILL.md` each install correctly on their respective
     harnesses; the README states what the bare-skills install loses (scripts, hooks, agents).
  3. README documents installation for all four distribution targets plus versioning and
     license; `CHANGELOG.md` and an MIT `LICENSE` exist.
  4. The six slash commands under `commands/` work in Claude Code: five invoke their task
     skill, `dossier-lint` runs `scripts/lint.py`.
  5. `claude plugin eval` runs against the trigger descriptions and confirms an ambiguous
     input such as "write to the client" routes to `dossier-draft`, not `dossier-ingest`.
  6. `scripts/release.sh <version>` leaves both manifests at the same version, a matching
     `CHANGELOG.md` heading and a git tag.
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6 → 7

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Scaffold & Templates | 6/6 | Complete — human recette passed | 2026-09-17 |
| 2. Linter & Test Harness | 9/9 | Complete    | 2026-10-10 |
| 3. Protocol Skill & Hooks | 0/TBD | Not started | - |
| 4. Ingest & Fact Extraction | 0/TBD | Not started | - |
| 5. Drafting & Doctrine Review | 0/TBD | Not started | - |
| 6. Calls & Status | 0/TBD | Not started | - |
| 7. Manifests, Docs & Distribution | 0/TBD | Not started | - |
