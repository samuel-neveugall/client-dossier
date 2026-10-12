# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## State of the repository

The single source of truth is `docs/superpowers/specs/2026-09-16-client-dossier-design.md`
(status: approved for implementation, 2026-09-16). Phases 1-2 are delivered: the `dossier-init`
skill with its bundled script and templates, a minimal `.claude-plugin/plugin.json`, `scripts/lint.py`,
and a bash test suite under `tests/`. Phase 3 (protocol skill and hooks) is delivered: the
`dossier` entry skill (`skills/dossier/SKILL.md`), the hooks under `hooks/` (SessionStart,
PreToolUse guard, Stop check) and the pressure scenarios under `tests/scenarios/`. Phase 4
(ingest and fact extraction) adds the `dossier-ingest` skill (`skills/dossier-ingest/`) with its
two private scripts, `file_source.py` and `extract-text.sh`, and the read-only `fact-extractor`
agent (`agents/fact-extractor.md`). Phase 5 (drafting and doctrine review) adds the `dossier-draft`
skill (`skills/dossier-draft/SKILL.md`, no private scripts) and the read-only `doctrine-reviewer`
agent (`agents/doctrine-reviewer.md`). Phase 6 (calls and status) adds the `dossier-call` skill
(`skills/dossier-call/SKILL.md`, no private scripts; prepare and debrief) and the `dossier-status`
skill with its private, read-only `scripts/status.py`. Phase 7 (manifests, docs and distribution)
completes the Claude Code and Codex manifests with their marketplaces, adds the README, the MIT
LICENSE, the CHANGELOG, `scripts/release.sh`, the `evals/routing/` suite and the isolated install
checks under `tests/dist/`, extends the sources guard to Codex `apply_patch` edits, and settles the
slash-command set by D-18 (settled by Samuel; see Commands). Read the spec before any work; when this file and the spec
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
  and `skills/dossier-init/templates/{en,fr}/`, then `skills/dossier-ingest/scripts/{file_source.py,extract-text.sh}`
  (Phase 4 D-05, the second example; the shell script targets bash 3.2), referenced from
  `SKILL.md` as `${CLAUDE_SKILL_DIR}/…`, never by a relative path. A script shared by several skills stays at
  the repository-root `scripts/`, which is the rule that keeps `lint.py` where it is — see D-05
  and D-06 of `.planning/phases/01-scaffold-templates/01-CONTEXT.md`; spec §4's tree was amended
  in Phase 1, and again in Phase 4, to match. Scripts target **Python 3.8 or newer**, standard library only.
- **Hooks carry reminders** (`hooks/hooks.json`): SessionStart injects a pointer when a
  `dossier.yaml` is found upward, PreToolUse denies writes under `sources/`, Stop blocks once (the second stop of a
  turn passes) when outbound/sources changed without the dossier. The hook scripts are Python
  3.8+ standard library, fail open, and reuse `lint.py`'s upward `dossier.yaml` search. Hooks
  never do work, and every rule a hook enforces must also be stated in a skill so harnesses
  without hooks behave the same.
- **Agents isolate long reading and fresh-eyes review**, both read-only:
  `fact-extractor` (one source → proposed dated, sourced lines per living file, plus
  "contradicts" and "uncertain" lists) and `doctrine-reviewer` (reports findings on a draft,
  never rewrites). Skills must also contain the inline procedure for harnesses without subagents.
- **Commands** (`commands/`, Claude Code only): one, `dossier-lint.md`, which runs `scripts/lint.py`.
  The five task skills are themselves the slash commands (`/client-dossier:dossier-<name>`); a
  command file never takes a skill's name, because it would shadow the skill for the user and the
  model (Phase 7 D-18; `tests/test-commands.sh`).
- Dual manifests: `.claude-plugin/{plugin,marketplace}.json` and `.codex-plugin/plugin.json` +
  `.agents/plugins/marketplace.json`. The version lives in both and is bumped together.

### Invariants that cut across every component

- Sources are immutable; corrections go in the living files.
- Every fact line: one sentence, absolute date, source in parentheses (`call @12:34`,
  `mail 2026-09-16 from Jane`, `brochure p. 4`). Correct a contradicted line instead of adding one.
- Every outbound file opens with a status header; a `sent` status needs a date and a sender;
  an optional `Deadline:` (absolute date) is what `dossier-status` reads for overdue drafts.
  A call file under `outbound/calls/` never carries `Deadline:` (Phase 6 D-11: the call date is
  in its name). The agent never marks a draft as sent.
- A commitment that is done is corrected in place with the English marker `done <YYYY-MM-DD>`
  and its source; `dossier-status` stops reporting it (Phase 6 D-13).
- Confidential names from `dossier.yaml` never appear under `outbound/` unless
  `consent_recorded: true` **and** `consent_source` is filled in (true without a source is a
  lint error).
- `dossier.yaml` also carries `staleness_days` (default 7) for `dossier-status`.
- Skills locate the nearest `dossier.yaml` (cwd or parent); every task skill (all except
  `dossier-init` and the `dossier` entry skill) stops with a message if none is found; the
  `dossier` entry skill says so in one line, suggests `dossier-init` when relevant, and steps
  aside (03-CONTEXT D-05).
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
- Trigger descriptions validated with `claude plugin eval` (the `evals/routing/` suite, Phase 7;
  paid, agent-run, recorded under the phase evidence).

- Local loading during development: `claude --plugin-dir .` from the repository root. A
  minimal `.claude-plugin/plugin.json` exists from Phase 1 for that purpose; Phase 7 completed
  the manifests.

### Commands

- `python3 scripts/lint.py [PATH]` — lint the dossier holding `PATH` (default: the current
  directory; the linter walks upward to the nearest `dossier.yaml`). Exit codes: 0 no error
  (warnings allowed), 1 at least one error, 2 no `dossier.yaml` found upward or unreadable,
  3 internal error. The linter is read-only and takes no other flag in v1: there is no fix or
  repair mode.
- `bash tests/run.sh` — the full test suite; every `tests/test-*.sh` file, one summary line.
- `bash tests/test-lint.sh` — the lint tests alone.
- `claude plugin validate .` — the manifest and `hooks/hooks.json`; exit 0 expected, with one
  known warning (the root `CLAUDE.md` is not loaded as plugin context), kept on purpose because
  this file holds the development instructions (Phase 7 D-03). `--strict` exits 1 because of it,
  by design. Never delete CLAUDE.md to silence it. validate writes into the configuration it runs
  with, so `tests/test-manifests.sh` runs it with temporary config and home folders.
- `bash tests/test-hooks-config.sh` — `hooks/hooks.json` shape and wiring.
- `bash tests/test-hook-guard-sources.sh` — the PreToolUse guard on `sources/`, Codex
  `apply_patch` edits included.
- `bash tests/test-hook-session-start.sh` — the SessionStart reminder.
- `bash tests/test-hook-stop.sh` — the block-once Stop check.
- `bash tests/test-skill-dossier.sh` — frontmatter and content checklist of the `dossier` skill.
- `bash tests/test-ingest-file.sh` — `file_source.py`: naming, dedup, no overwrite, refusals.
- `bash tests/test-ingest-fetch.sh` — the URL download and its guard-rails, against a local server.
- `bash tests/test-ingest-extract.sh` — the `extract-text.sh` exit contract.
- `bash tests/test-ingest-guard.sh` — the ingest skill's own commands through the real sources guard and scripts.
- `bash tests/test-agent-fact-extractor.sh` — agent frontmatter, rules, parity with the skill.
- `bash tests/test-skill-ingest.sh` — the `dossier-ingest` skill checklist.
- `bash tests/test-agent-doctrine-reviewer.sh` — agent frontmatter, review rules, heading positions, parity with the skill.
- `bash tests/test-skill-draft.sh` — the `dossier-draft` skill checklist.
- `bash tests/test-draft-shapes.sh` — the skill's status block and history line through the real linter.
- `bash tests/scenarios/selftest.sh` — free self-test of the scenario harness against a fake `claude`.
- `bash tests/scenarios/selftest-ingest.sh` — free self-test of the ingest scenario harness.
- `bash tests/scenarios/selftest-draft.sh` — free self-test of the two draft scenario harnesses.
- `bash tests/scenarios/fix-typo.sh [--variant baseline|plugin|pointer-only]... [--runs N] [OUTDIR]`
  — the PROTO-07 pressure scenario: paid headless `claude -p` runs, run by the agent, never part
  of `tests/run.sh`. Exit 0 pass, 1 gate not met, 2 harness error.
- `bash tests/scenarios/ingest-transcript.sh [--variant baseline|plugin|plugin-pointer]... [--runs N] [--prompt plain|pressured] [OUTDIR]`
  — the INGEST-05 pressure scenario: paid headless `claude -p` runs, run by the agent, never part
  of `tests/run.sh`. Exit 0 pass, 1 gate not met, 2 harness error.
- `bash tests/scenarios/ingest-pdf.sh [--runs N] [OUTDIR]` — the end-to-end PDF ingest of
  ROADMAP criterion 1: a paid headless run with the plugin, run by the agent, never part of
  `tests/run.sh`. Same exit codes.
- `bash tests/scenarios/draft-reply.sh [--variant baseline|plugin|plugin-pointer]... [--runs N] [--prompt plain|pressured] [OUTDIR]`
  — the DRAFT-04 pressure scenario: paid headless `claude -p` runs, run by the agent, never part
  of `tests/run.sh`. Exit 0 pass, 1 gate not met, 2 harness error.
- `bash tests/scenarios/draft-deadline-fr.sh [--runs N] [OUTDIR]` — the French deadline draft of
  ROADMAP criterion 1: a paid headless run with the plugin, run by the agent, never part of
  `tests/run.sh`. Same exit codes.
- `python3 skills/dossier-status/scripts/status.py [--json] [--today YYYY-MM-DD] [--lint PATH] [PATH]`
  — the read-only status of the dossier holding `PATH`. Exit 0 report printed, 2 no `dossier.yaml`
  upward or a usage error, 3 internal error.
- `bash tests/test-status-script.sh` — `status.py` on scratch git dossiers.
- `bash tests/test-skill-status.sh` — the `dossier-status` skill checklist and the
  scenario-fixture parity.
- `bash tests/test-skill-call.sh` — the `dossier-call` skill checklist, its call file and history
  lines through the real linter and `status.py`.
- `bash tests/test-skills-task.sh` — PROTO-02 pointers and PROTO-08 stop over every skill.
- `bash tests/scenarios/selftest-call.sh` — free self-test of the two call and status scenario
  harnesses.
- `bash tests/scenarios/call-prepare.sh [--variant baseline|plugin|plugin-pointer]... [--runs N] [--prompt plain|pressured] [OUTDIR]`
  — the CALL-04 pressure scenario: paid headless `claude -p` runs, run by the agent, never part
  of `tests/run.sh`. Exit 0 pass, 1 gate not met, 2 harness error.
- `bash tests/scenarios/deal-status.sh [--variant baseline|plugin|plugin-pointer]... [--runs N] [--prompt plain|pressured] [OUTDIR]`
  — the CALL-05 pressure scenario (pressured prompt by default, D-16): paid headless `claude -p`
  runs, run by the agent, never part of `tests/run.sh`. Same exit codes.
- `bash tests/test-manifests.sh` — the four manifests and the validate gate.
- `bash tests/test-release.sh` — `scripts/release.sh` in scratch repositories.
- `bash tests/test-readme.sh` — README, LICENSE, CHANGELOG and version coherence.
- `bash tests/test-evals-shape.sh` — the eval cases' shape and free scaffold runs.
- `bash tests/dist/install-claude.sh`, `bash tests/dist/install-codex.sh` and
  `bash tests/dist/install-skills.sh [--via skills-cli|copy] [--registry-only]` — free isolated
  install checks from a clone of HEAD, run by the agent, never part of `tests/run.sh`. Exit 0
  pass, 1 gate not met, 2 harness error.
- `scripts/release.sh <version>` — bumps both manifests, adds the CHANGELOG heading and creates a
  local annotated tag, never pushes. Run only in scratch clones until the milestone audit (D-01).
- `claude plugin eval . --scaffold --trust-plugin --ablation none --model sonnet --runs 3 --no-publish --max-cost-usd 4 --threshold 0.66 --json <file>`
  — the paid DIST-06 routing eval, run by the agent, never part of `tests/run.sh`.
- `bash tests/test-commands.sh` — `commands/` holds exactly `dossier-lint.md`, no command named
  like a skill, the command's frontmatter and quoting.
- `/client-dossier:dossier-lint [PATH]` — in Claude Code with the plugin loaded: runs the linter
  on the dossier holding PATH and relays its output and exit code.
- `claude --plugin-dir .` — load the plugin from the working copy during development.

Add more here as they are created.

## Decisions (spec §11, settled 2026-09-16 and 2026-10-10)

Name `client-dossier` (entry skill `dossier`), folders `dossier/` and `outbound/`, protocol
keywords in English. Spec §11 #3 was settled with Samuel on 2026-10-10 (Phase 3 D-01): the
Stop hook ships in v1 and blocks once.
