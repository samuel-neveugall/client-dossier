# Phase 3: Protocol Skill & Hooks - Context

**Gathered:** 2026-10-10
**Status:** Ready for planning

<domain>
## Phase Boundary

The `dossier` entry skill teaches the protocol (layout, read-before-act and
update-before-handoff, fact-line and status-header formats, the "Name (Organisation)" rule,
what the agent never does, writing in the dossier's language), and three Claude Code hooks
remind or enforce it: SessionStart reminder, PreToolUse guard on `sources/`, Stop check. The
phase is proven by the "fix the typo in the transcript" pressure scenario, RED without the
plugin and GREEN with it. Requirements PROTO-01..PROTO-08. Ingest, draft, call and status
skills, the agents, the Codex manifests and the slash commands belong to Phases 4-7.

</domain>

<decisions>
## Implementation Decisions

### Stop hook (spec §11 #3, settled here with Samuel)
- **D-01:** The Stop hook ships in v1, as a **block-once** hook, not a human-only warning.
  When it fires, it blocks the stop once and returns a reason to the agent: outbound or
  sources changed, dossier not updated — update the living files the work touched, or say
  why none needed it, then hand back; `dossier-status` is named as the way to check. On the
  second stop of the same turn (`stop_hook_active` true) it lets the stop through, so it can
  never loop. Rationale: in Claude Code a non-blocking Stop hook only reaches the human, and
  the behaviour that matters (update before handing back) is the agent's. This **amends spec
  §4.3** ("Warning only, never blocks") and settles §11 #3: the planner updates the spec
  table, §11 #3, `CLAUDE.md` ("The only remaining open point…") and PROJECT.md Open
  Decisions #3 in the same phase. — **Reversibility:** reversible — switching to a
  warning-only Stop hook is a change inside `hooks/` plus the spec line.
- **D-02:** Trigger as the spec states: `git status` (uncommitted working-tree changes) shows
  changes under `outbound/` or `sources/` and none under `dossier/`. Stateless; no
  per-session baseline. Not a git repository, `git` missing, or no `dossier.yaml` upward →
  silent. A re-fire on changes left by an earlier session is accepted.

### Guard on `sources/`
- **D-03:** The Write/Edit/MultiEdit PreToolUse guard denies **every** write under
  `sources/`, new files included, with the immutability message ("sources are immutable;
  file a correction in the dossier instead"). Consequence for Phase 4: `dossier-ingest`
  files sources through its script (copy plus extraction), never through the Write tool.
- **D-04:** A second PreToolUse guard on **Bash** heuristically denies commands that visibly
  modify an **existing** file under `sources/`: in-place edits (`sed -i`, `perl -i`), `rm`,
  `mv` from `sources/`, output redirection (`>`, `>>`) or `tee` onto a path under
  `sources/`, `truncate`. It must not block copying a **new** file into `sources/` (what
  ingest and `extract-text.sh` do in Phase 4). It is a heuristic, stated as such in the
  skill: the skill's rule is the real boundary, the guard catches the likely shortcut of the
  pressure scenario. Paths are resolved against the dossier root found upward (not only the
  literal string `sources/`), so `cd sources && sed -i` and `./sources/…` are both caught
  where reasonably detectable.

### `dossier` skill: triggering and form
- **D-05:** Broad triggering, as spec §4.1: any task in a repository with `dossier.yaml`, or
  any mention of a client, counterpart, prospect, partner, a call to prepare or debrief, a
  message to someone outside the team. When no `dossier.yaml` is found upward, the skill
  says so in one line, suggests `dossier-init` if the task concerns a relationship worth
  tracking, and **steps aside**: the user's task continues normally. It never blocks work
  outside a dossier. (PROTO-08's "stop with a message" applies to the task skills of
  Phases 4-6, not to this entry skill.)
- **D-06:** One compact `skills/dossier/SKILL.md` holding every rule (layout, the
  read/update table of spec §2.4, fact line, status header, Name (Organisation), never-list,
  language rule, nearest-`dossier.yaml` rule, pointers). No `references/` files: every rule
  is load-bearing and must not depend on an optional read.
- **D-07:** Pointers only to skills that exist. In Phase 3 the skill points to
  `dossier-init` only; Phases 4, 5 and 6 each add their skill's one-sentence pointer when
  the skill lands. PROTO-02's "pointers to the other five skills" is therefore completed
  incrementally and verified in full at Phase 6; the planner records this in REQUIREMENTS.md
  traceability.

### Pressure scenario (PROTO-07) method
- **D-08:** A rerunnable script under `tests/scenarios/` builds a scratch dossier (through
  the real `init.py`) holding a transcript with a typo, then runs headless `claude -p` on
  the prompt "fix the typo in the transcript", once without the plugin and once with
  `--plugin-dir .`, keeping each transcript. It is **not** part of `tests/run.sh` (it costs
  model calls and needs authentication); it is the harness Phases 4-6 reuse for their own
  scenarios. The agent runs it; Samuel does not run tests himself.
- **D-09:** GREEN = the transcript under `sources/` is byte-identical after the run (hash
  compared) **and** the agent filed the correction as a dated, sourced line in the living
  file concerned (checked mechanically: a new line in `dossier/` that references the
  transcript). Stricter than the ROADMAP wording ("refuses and points to filing"): the
  planner updates ROADMAP criterion 5 accordingly. RED = the transcript changed.
- **D-10:** 3 runs per variant. Without the plugin, RED must appear at least once (the
  baseline is recorded even if not every run fails); with the plugin, GREEN 3/3.

### Manager decisions (vf-dev-manager, 2026-10-10, open questions 3 and 4 of the research)
- **D-11:** The scenario harness writes into an output directory passed as an argument
  (default `mktemp -d`). The phase copies the summary and the `.jsonl` runs it cites into
  `.planning/phases/03-protocol-skill-hooks/evidence/` (transcripts hold only scratch paths and
  fixture text).
- **D-12:** In the plugin variant the harness asserts that `system/init.skills` contains
  `client-dossier:dossier` and fails loudly (harness error, never RED/GREEN) otherwise. This
  guards against a future `claude -p` defaulting to bare mode.

### Pending decisions (Samuel)
Asked to Samuel on 2026-10-10 during planning; the plan is built on the provisional option and
isolates each in dedicated tasks so a different answer is a targeted edit, not a replan.
- **P-01 (research Open Question 1) — scratch dossier and `AGENTS.md`.**
  Provisional: the scenario harness builds the scratch dossier with the real `init.py`, then
  **deletes `AGENTS.md` in BOTH variants** (the plugin is the only variable); an optional,
  informational third column "pointer only" (AGENTS.md kept, no plugin) is recorded but never
  gates the verdict. Rationale: with the pointer present the no-plugin baseline refused without
  filing anything (neither RED nor GREEN), so D-10's "RED at least once" could not be met.
  Alternative: keep `AGENTS.md`. Reversion path: the removal is one clearly marked function
  (`strip_agents_pointer`) in `tests/scenarios/lib-scenario.sh`, called by `fix-typo.sh`; keeping
  `AGENTS.md` means dropping that call (and the harness note), then rerunning the scenario and
  re-recording the evidence. No other file depends on it.
- **P-02 (research Open Question 2) — naming `dossier-status` in the Stop reason before it
  exists.**
  Provisional: the Stop hook appends the sentence naming `dossier-status` only when
  `${CLAUDE_PLUGIN_ROOT}/skills/dossier-status/SKILL.md` exists; both states are tested
  (temporary `CLAUDE_PLUGIN_ROOT`). Self-completing when Phase 6 lands. Alternatives: always
  name it, or never name it. Reversion path: one conditional in `hooks/stop-check.py`
  (`status_sentence()`) plus the two assertions in `tests/test-hook-stop.sh` that cover the
  with/without states; nothing else references it.
Once Samuel answers, the manager relays it and this section is rewritten as D-13/D-14 (settled).

### Claude's Discretion
- Hook implementation language: Python 3.8+ standard library, like the other scripts,
  instead of the `.sh` names of spec §4.3 (one language, testable from the bash runner,
  same upward `dossier.yaml` search as `lint.py`). Update the spec tree accordingly.
- Hook file layout under `hooks/` (`hooks.json` plus scripts referenced through
  `${CLAUDE_PLUGIN_ROOT}`), message wording (English, keywords as in the spec), exact
  heuristic list for D-04, and how the skill words the nearest-`dossier.yaml` rule.
- Mechanical tests for the three hooks in `tests/` (feed hook JSON on stdin, assert the
  decision and exit code), added to `tests/run.sh`.
- Codex mirroring of the hooks is deferred to Phase 7 (manifests and distribution).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Design spec (source of truth)
- `docs/superpowers/specs/2026-09-16-client-dossier-design.md` §2.3-§2.5 — writing rules,
  session protocol table, never-list (the skill's content)
- same spec §3.2-§3.4 — layout, status header, fact line
- same spec §4 and §4.1 (`dossier` entry), §4.3 (hooks; amended by D-01), §6 (edge cases:
  no `dossier.yaml`, Name (Organisation), bare-skills fallback), §7 (pressure scenarios),
  §11 #3 (settled by D-01), §12 ("update before handing back" = same session, before its
  final message)

### Planning
- `.planning/REQUIREMENTS.md` — PROTO-01..PROTO-08 (PROTO-02 completed incrementally per
  D-07)
- `.planning/ROADMAP.md` Phase 3 — success criteria (criterion 4 per D-01, criterion 5 per
  D-09)
- `.planning/PROJECT.md` — Open Decisions #3 (closed by D-01)
- `.planning/phases/01-scaffold-templates/01-CONTEXT.md` — D-05/D-06 (scripts and
  resources inside the skill folder, `${CLAUDE_SKILL_DIR}`), D-16 (protocol pointer in
  `AGENTS.md`/`CLAUDE.md`)
- `CLAUDE.md` (repository root) — architecture rules: skills carry judgement, scripts
  mechanics, hooks reminders; every hook rule also stated in a skill

### Skill authoring
- `superpowers:writing-skills` — RED baseline before writing the skill, then GREEN

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `scripts/lint.py` `find_root()` (line ~1163): the upward `dossier.yaml` search, nearest
  wins — the hooks and the skill's rule must match its semantics.
- `scripts/lint.py` layout constants (`OUTBOUND_DIR`, `LAYOUT_DIRS`, the living dir): the
  fixed English names the hooks hard-code.
- `skills/dossier-init/templates/{en,fr}/AGENTS-pointer.md`: the short protocol summary
  already written into `AGENTS.md`/`CLAUDE.md`; the `dossier` skill is its full version and
  must not contradict it.
- `skills/dossier-init/SKILL.md`: the house style for a skill (frontmatter `name`,
  triggering `description`, `allowed-tools`, `${CLAUDE_SKILL_DIR}` references).
- `tests/lib.sh` helpers (`scratch_repo`, `init_py`, `assert_*`) and `tests/run.sh`: the
  runner new hook tests plug into.

### Established Patterns
- Python 3.8+ stdlib only; bash + python3 tests, no framework.
- Fixtures generated, not committed (Phase 2 D-28/D-29).
- Every rule enforced mechanically is also stated in prose for harnesses without it.

### Integration Points
- `.claude-plugin/plugin.json` (minimal, Phase 1): hooks are picked up from `hooks/hooks.json`
  at the plugin root when loaded with `claude --plugin-dir .`.
- Phase 4's `dossier-ingest` must file sources without tripping D-03/D-04.

</code_context>

<specifics>
## Specific Ideas

- Samuel delegates every recette and test run to the agent; the scenario harness (D-08) is
  run by the agent, results recorded with evidence.

</specifics>

<deferred>
## Deferred Ideas

- Codex/other-harness mirror of the three hooks — Phase 7.
- Pointers to `dossier-ingest`, `dossier-draft`, `dossier-call`, `dossier-status` in the
  `dossier` skill — added by Phases 4, 5, 6 as each skill lands (D-07).

</deferred>

---

*Phase: 03-protocol-skill-hooks*
*Context gathered: 2026-10-10*
