# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## State of the repository

The single source of truth is `docs/superpowers/specs/2026-09-16-client-dossier-design.md`
(status: approved for implementation, 2026-09-16). Phase 1 (scaffold-templates) has landed a
`dossier-init` skill with its bundled script and templates, a minimal `.claude-plugin/plugin.json`,
and a bash test suite under `tests/`. Read the spec before any work; when this file and the spec
disagree, the spec wins and this file must be updated. Planning lives in `.planning/` (GSD):
ROADMAP, REQUIREMENTS, STATE.

Language: the plugin (skills, agents, scripts, docs, commit messages) is written in English.
Dossier *content* produced by the plugin is in the language configured in `dossier.yaml`.

## What is being built

`client-dossier`: a coding-agent plugin (Claude Code first, then Codex and any Agent Skills
harness) that turns a git repository into the memory of a relationship with an external party.
It scaffolds a fixed layout, teaches a read-before-act / update-before-handoff protocol through
skills, and enforces the mechanical rules with a linter and hooks. It never sends anything and
never renders documents.

### The dossier layout the plugin manages (not this repo's layout)

```
dossier.yaml   sources/ (immutable)   dossier/ (7 living files)   knowledge/   outbound/
```

Folder and file names are **fixed English names, never configurable**: skills, hooks, linter and
templates all hard-code them. Do not introduce a name mapping. Existing repositories adopt the
names via `git mv` proposed by `dossier-init`. Empty leaf folders get a `.gitkeep`.

**Protocol keywords are English too and never translated** (spec §3.2): the `Last updated:`
label, the status-header field names (`Status:`, `To:`, `Subject:`, `Deadline:`, `Written by:`,
`Rules:`) and the status values (`draft`, `reviewed by`, `sent`). Only headings, examples and
content are in the dossier's language. The linter greps these keywords; do not add a
per-language label table.

### Planned plugin architecture (spec §4)

Division of responsibility, which decides where any new behaviour goes:

- **Skills carry judgement** (`skills/*/SKILL.md`, Agent Skills frontmatter `name` + `description`).
  `dossier` is the protocol entry skill that routes to `dossier-init`, `dossier-ingest`,
  `dossier-draft`, `dossier-call`, `dossier-status`. Descriptions are written for triggering
  (situations, not features).
- **Scripts carry mechanics.** Anything a regex can check belongs in `scripts/lint.py`, not in
  skill prose. `lint.py` is Python 3 standard library only (tiny YAML-subset parser, JSON
  fallback); exit 1 on errors, 0 on warnings only. A skill's own *private* mechanics and
  resources are bundled inside its own folder instead: `skills/dossier-init/scripts/init.py`
  and `skills/dossier-init/templates/{en,fr}/`, referenced from `SKILL.md` as
  `${CLAUDE_SKILL_DIR}/…`, never by a relative path. A script shared by several skills stays at
  the repository-root `scripts/`, which is the rule that keeps `lint.py` where it is — see D-05
  and D-06 of `.planning/phases/01-scaffold-templates/01-CONTEXT.md`; spec §4's tree was amended
  in Phase 1 to match. Scripts target **Python 3.8 or newer**, standard library only.
- **Hooks carry reminders** (`hooks/hooks.json`): SessionStart injects a pointer when a
  `dossier.yaml` is found upward, PreToolUse denies writes under `sources/`, Stop warns (never
  blocks) when outbound/sources changed without the dossier. Hooks never do work, and every rule
  a hook enforces must also be stated in a skill so harnesses without hooks behave the same.
- **Agents isolate long reading and fresh-eyes review**, both read-only:
  `fact-extractor` (one source → proposed dated, sourced lines per living file, plus
  "contradicts" and "uncertain" lists) and `doctrine-reviewer` (reports findings on a draft,
  never rewrites). Skills must also contain the inline procedure for harnesses without subagents.
- Dual manifests: `.claude-plugin/{plugin,marketplace}.json` and `.codex-plugin/plugin.json` +
  `.agents/plugins/marketplace.json`. The version lives in both and is bumped together.

### Invariants that cut across every component

- Sources are immutable; corrections go in the living files.
- Every fact line: one sentence, absolute date, source in parentheses (`call @12:34`,
  `mail 2026-09-16 from Jane`, `brochure p. 4`). Correct a contradicted line instead of adding one.
- Every outbound file opens with a status header; a `sent` status needs a date and a sender;
  an optional `Deadline:` (absolute date) is what `dossier-status` reads for overdue drafts.
  The agent never marks a draft as sent.
- Confidential names from `dossier.yaml` never appear under `outbound/` unless
  `consent_recorded: true` **and** `consent_source` is filled in (true without a source is a
  lint error).
- `dossier.yaml` also carries `staleness_days` (default 7) for `dossier-status`.
- Skills locate the nearest `dossier.yaml` (cwd or parent); all skills except `dossier-init`
  stop if none is found.
- External dependencies have a stated fallback: `pdftotext` missing → PDF filed, extraction
  reported as skipped; `scripts/` absent (bare-skills install) → the skill says so and states
  the rule the script would have checked.

## Implementation order and testing (spec §7, §12)

Planned order: init → lint → protocol skill → ingest + extractor → draft + reviewer → call and
status → manifests and distribution.

- Skills follow `superpowers:writing-skills`: record the baseline failure of the pressure
  scenario (spec §7 lists five) *without* the skill, write the skill, rerun.
- Mechanical tests in `tests/`: fixture repositories (including a French-content one for the
  relative-date and opinion-marker word lists) and a bash runner asserting `lint.py` exit codes
  and messages. No test framework beyond bash and python3.
- Trigger descriptions validated with `claude plugin eval` once skills exist.

- Local loading during development: `claude --plugin-dir .` from the repository root. A
  minimal `.claude-plugin/plugin.json` exists from Phase 1 for that purpose; the full
  manifests come in Phase 7.

Commands that exist today: `bash tests/run.sh` (the full test suite), `claude plugin validate . --strict`
(the manifest), and `claude --plugin-dir .` (load the plugin from the working copy during
development). Add more here as they are created.

## Decisions (spec §11, settled 2026-09-16)

Name `client-dossier` (entry skill `dossier`), folders `dossier/` and `outbound/`, protocol
keywords in English. The only remaining open point is whether the Stop hook ships in v1: it is
decided during Phase 3 planning, with Samuel. Do not settle it unilaterally.
