# Phase 3: Protocol Skill & Hooks - Research

**Researched:** 2026-10-10
**Domain:** Claude Code plugin hooks (SessionStart / PreToolUse / Stop), Agent Skills entry skill, headless `claude -p` pressure-scenario harness, Python 3.8 stdlib hook scripts, bash tests
**Confidence:** HIGH for hook mechanics and headless flags (verified by live probes this session on Claude Code 2.1.296); MEDIUM for skill wording (judgement, proven only by the scenario); see Assumptions Log

## Summary

Every hook behaviour the CONTEXT decisions rely on was exercised live this session with a throwaway
probe plugin loaded through `--plugin-dir` in headless `claude -p` runs: `hooks/hooks.json` at the
plugin root is auto-discovered; a SessionStart hook's `hookSpecificOutput.additionalContext` reaches
the model before the first prompt; a PreToolUse `permissionDecision: "deny"` blocks both `Edit` and
`Bash` (even when `--allowedTools Bash` allows the command) and the model sees
`PreToolUse:<Tool> hook error: <reason>`; a Stop hook returning `{"decision":"block","reason":…}`
forces exactly one more turn (delivered as `Stop hook feedback:\n<reason>`) and the second Stop
arrives with `stop_hook_active: true`, so the D-01 block-once design works as specified. The hook's
stdin `cwd` follows the Bash tool's persisted working directory, which is what makes the D-04
"`cd sources` then `sed -i`" case catchable.

The single most important finding for planning: **a dossier scaffolded by the real `init.py`
already defeats the RED baseline.** `init.py` writes the protocol pointer into `AGENTS.md`, Claude
Code loads `AGENTS.md` through its built-in `cc-plugin-agents-md` plugin, and with that pointer
present Sonnet refused to edit the transcript *without* the plugin (it also read
`sources/README.md`). With the pointer removed, the same prompt "fix the typo in the transcript"
edited the source (RED) in one shot. Neither run filed a correction in `dossier/`, so the D-09
GREEN criterion (source intact **and** correction filed) is the skill's real added value. The
scenario harness must therefore remove the `AGENTS.md` pointer from the scratch dossier (both
variants, so the plugin is the only variable) — this needs a one-line confirmation from Samuel
because D-08 says "through the real `init.py`" (it still is; the harness deletes the file after).

Isolation of the headless runs from Samuel's heavy global setup (about 20 SessionStart hooks, a
`stop-notify` Stop hook that forces `AskUserQuestion`, 15 enabled plugins, `~/.claude/CLAUDE.md`
with RTK/Karpathy instructions) is solved by `--setting-sources project,local --strict-mcp-config`
plus a scratch repository under `mktemp -d` (outside `~/Documents/dev`, whose `CLAUDE.md` would
otherwise load as a parent memory file). `--bare` is **not** usable: it requires
`ANTHROPIC_API_KEY` (not set here; OAuth is never read in bare mode) and it drops the skill listing,
which would sabotage the GREEN variant.

**Primary recommendation:** Three self-contained Python 3.8 hook scripts
(`hooks/session-start.py`, `hooks/guard-sources.py`, `hooks/stop-check.py`) wired by a shell-form,
double-quoted `"${CLAUDE_PLUGIN_ROOT}"` `hooks/hooks.json`, each failing open (exit 0, no output)
on any internal error, each resolving the dossier root with a byte-identical copy of `lint.py`'s
`find_root()`; one compact `skills/dossier/SKILL.md`; bash tests per hook in `tests/`; and a
`tests/scenarios/` harness running `claude -p` with the isolation flags above, the pointer removed,
three runs per variant.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Stop hook (spec §11 #3, settled here with Samuel)
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

#### Guard on `sources/`
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

#### `dossier` skill: triggering and form
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

#### Pressure scenario (PROTO-07) method
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

### Deferred Ideas (OUT OF SCOPE)
- Codex/other-harness mirror of the three hooks — Phase 7.
- Pointers to `dossier-ingest`, `dossier-draft`, `dossier-call`, `dossier-status` in the
  `dossier` skill — added by Phases 4, 5, 6 as each skill lands (D-07).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PROTO-01 | `dossier` skill triggers on any task in a repo with `dossier.yaml` or any client/counterpart/prospect/partner/call/message mention; always loaded first | Description rules (Agent Skills ≤1024 chars, "Use when…", situations not workflow) in Pattern 4; SessionStart reminder names `client-dossier:dossier` (plugin namespacing); trigger probe via the scenario harness (Validation Architecture) |
| PROTO-02 | Skill covers layout, read/update table, fact line, status header, never-list, Name (Organisation), pointers | Skill content checklist (Pattern 4); D-07 incremental pointers; self-updating pointer test |
| PROTO-03 | Skill sets the dossier-language rule | Content checklist item "language"; keywords stay English (spec §3.2) |
| PROTO-04 | SessionStart hook injects the reminder when `dossier.yaml` is found upward, silent otherwise | Pattern 1 (verified `additionalContext` delivery), `find_root` parity |
| PROTO-05 | PreToolUse denies writes under `sources/` (amended by D-03/D-04: also the Bash heuristic) | Pattern 2 (verified deny on Edit and Bash; path resolution; heuristic table) |
| PROTO-06 | Stop hook (amended by D-01: block-once) when git status shows outbound/sources changes and none under dossier/ | Pattern 3 (verified block-once; porcelain path semantics verified) |
| PROTO-07 | "Fix the typo" scenario RED without, GREEN with | Pattern 5 (harness flags verified; RED reproduced with pointer removed; pointer-present control refuses) |
| PROTO-08 | Skills locate the nearest `dossier.yaml`; nearest wins; stop when none (task skills) | `find_root` semantics quoted from `lint.py`; skill rule wording; hook tests from subfolders and nested dossiers; full "stop" behaviour verified with the task skills in Phases 4-6 (record incrementally like PROTO-02) |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

Directives from `/Users/samuel/Documents/dev/client-dossier/CLAUDE.md` (authority equal to locked decisions):

- The spec `docs/superpowers/specs/2026-09-16-client-dossier-design.md` is the source of truth; when CLAUDE.md and the spec disagree the spec wins and CLAUDE.md is updated. This phase amends both (D-01).
- Plugin artefacts (skills, scripts, hooks, docs, commit messages) are in **English**. Dossier content follows `dossier.yaml` `language`.
- Folder and file names are **fixed English names, never configurable**; no name mapping.
- Protocol keywords are English and never translated: `Last updated:`, `Status:`, `To:`, `Subject:`, `Deadline:`, `Written by:`, `Rules:`, values `draft`, `reviewed by`, `sent`.
- Skills carry judgement, scripts carry mechanics, hooks carry reminders. **Hooks never do work.** **Every rule a hook enforces must also be stated in a skill** (harnesses without hooks).
- Skills follow `superpowers:writing-skills`: record the baseline failure without the skill, write the skill, rerun.
- Scripts: **Python 3.8 or newer, standard library only.** Tests: **bash and python3 only, no framework.**
- Bundled resources referenced as `${CLAUDE_SKILL_DIR}/…` (or `${CLAUDE_PLUGIN_ROOT}/…` for plugin-level files), never by a relative path.
- The Stop-hook open point "is decided during Phase 3 planning, with Samuel. Do not settle it unilaterally." — settled by D-01 (with Samuel); the CLAUDE.md line must be updated in this phase.
- Commands: `bash tests/run.sh`, `python3 scripts/lint.py [PATH]`, `claude plugin validate . --strict`, `claude --plugin-dir .` (see Pitfall 9: `--strict` currently fails on a pre-existing warning).
- Global user instruction (`~/.claude/CLAUDE.md` → KARPATHY.md): simple, surgical changes; no speculative abstraction.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Protocol rules (layout, tables, formats, never-list, language) | Skill (`skills/dossier/SKILL.md`) | `AGENTS.md` pointer (Phase 1, short form) | Judgement lives in skills; the skill is the only tier present on every harness |
| "Load the skill first" reminder | Hook: SessionStart | Skill description (triggering) | Hooks carry reminders; the description is the hookless fallback |
| Sources immutability enforcement | Hook: PreToolUse guard | Skill rule (the real boundary) | Guard is a convenience; the skill states the rule for every harness |
| Update-before-handoff check | Hook: Stop (block-once) | Skill rule (same session, before final message, spec §12) | The agent must act, so the hook speaks to the agent (D-01) |
| Dossier-root discovery | Each hook script (copy of `find_root`) | Skill prose rule | Same semantics as `lint.py` (nearest wins, no stop at `.git`) |
| Mechanical proof of hooks | `tests/test-hook-*.sh` (bash + python3) | — | Stdin JSON in, JSON/exit code out; no model needed |
| Behavioural proof (RED/GREEN) | `tests/scenarios/` headless harness | Phase evidence file | Costs model calls; outside `tests/run.sh` (D-08) |

## Standard Stack

### Core

| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| Claude Code plugin hooks (`hooks/hooks.json`) | Claude Code 2.1.296 measured | SessionStart / PreToolUse / Stop | Auto-discovered at the plugin root; merges with user/project hooks `[CITED: code.claude.com/docs/en/plugins-reference "Standard layout"]` `[VERIFIED: probe plugin loaded via --plugin-dir, hooks fired]` |
| Python 3 stdlib (`json`, `os`, `sys`, `shlex`, `subprocess`) | target ≥ 3.8; local 3.14.6 | Hook scripts | Project constraint; `shlex.shlex(punctuation_chars=True)` exists since 3.6 `[VERIFIED: tokenization tested locally]` |
| `git` | 2.50.1 local | Stop hook `status --porcelain=v1 -z` | Stateless trigger per D-02 |
| `claude -p` (headless) | 2.1.296 | Scenario harness | Only way to run the agent non-interactively with `--plugin-dir` |
| bash 3.2 + `tests/lib.sh` | 3.2.57 | Hook tests | Existing harness; bash-3.2-safe idioms already used |

### Supporting

| Tool | Purpose | When to Use |
|------|---------|-------------|
| `claude plugin validate .` | Validates manifest **and** `hooks/hooks.json` (warns on unquoted `${CLAUDE_PLUGIN_ROOT}`) | After writing `hooks.json` `[VERIFIED: ran on a probe with unquoted var, got the warning]` |
| `ast.parse(src, feature_version=(3, 8))` | Grammar-level 3.8 check (no 3.8 interpreter on this machine) | In the hook test file, same approach Phase 2 used `[VERIFIED: 02-VERIFICATION.md line 74]` |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Shell form `python3 "${CLAUDE_PLUGIN_ROOT}/hooks/x.py"` | Exec form `{"command":"python3","args":["${CLAUDE_PLUGIN_ROOT}/hooks/x.py"]}` | Exec form avoids quoting entirely but is a recent field; an older Claude Code that ignores `args` would spawn bare `python3` reading the hook JSON as a program. Shell form with double quotes is what Anthropic's own official plugins ship and validates clean. Use shell form. `[CITED: code.claude.com/docs/en/hooks "Exec form and shell form"]` `[VERIFIED: ~/.claude/plugins/cache/claude-plugins-official/security-guidance/2.0.3/hooks/hooks.json]` |
| JSON `hookSpecificOutput` on exit 0 | Exit code 2 + stderr | Both block; JSON is structured and testable, and the docs say pick one approach per hook. Use JSON + exit 0. `[CITED: hooks docs "Choose one approach per hook"]` |
| `"onFailure": "block"` (fail closed) | default fail-open | `onFailure` needs Claude Code ≥ 2.1.295, and a crashing guard that fails closed would block every Write in **every** repository where the plugin is enabled. Fail open; let tests catch bugs. `[CITED: hooks docs "Block the action when a hook fails"]` |
| `--bare` for scenario isolation | `--setting-sources project,local --strict-mcp-config` | `--bare` needs `ANTHROPIC_API_KEY` (absent; OAuth never read) and drops the skill listing reminder. `[CITED: code.claude.com/docs/en/headless "Start faster with bare mode"]` `[VERIFIED: env has no ANTHROPIC_API_KEY]` |
| Importing `find_root` from `scripts/lint.py` | Copy the 14-line function into each hook | Import couples hooks to a 2,130-line module (compiled on each call, `__pycache__` written into the plugin cache) and to `sys.path` games; lint.py's own header rejects a second importable module (Q-6). Copy + a parity test. |

**Installation:** none. No third-party package is installed in this phase.

## Package Legitimacy Audit

This phase installs **no external packages** (Python stdlib, git, bash, and the already-installed
`claude` CLI only). Nothing to audit.

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System Architecture Diagram

```
                    session starts (cwd C)                       agent proposes a tool call
                           |                                                |
                           v                                                v
              SessionStart hook (stdin: cwd, source)        PreToolUse hook (stdin: tool_name, tool_input, cwd)
                           |                                                |
             find_root(C) -- none --> no output                 tool_name in Write|Edit|MultiEdit|NotebookEdit?
                           |                                     |  yes: target = tool_input.file_path / notebook_path
                     root R found                                |  no (Bash): tokenize command, track `cd`,
                           |                                     |      pick destructive verbs + their path operands
                           v                                     v
       additionalContext: "client dossier at R,          for each target path P (realpath, joined to cwd):
        load client-dossier:dossier"                       R' = find_root(dirname P); first component of P
                           |                               relative to R' casefolds to "sources"?
                           v                                     |                     |
               model loads the `dossier` skill            yes -> deny JSON         no -> no output (allow)
               (rules: never touch sources/,                (reason shown to the model as
                file corrections in dossier/,                "PreToolUse:<Tool> hook error: …")
                update before handing back)
                                                    agent finishes its turn
                                                              |
                                                              v
                                   Stop hook (stdin: cwd, stop_hook_active, last_assistant_message)
                                                              |
                         stop_hook_active true? -- yes --> no output (stop allowed: never loops)
                                                              | no
                                 find_root(cwd) none / not a git repo / git missing -> no output
                                                              |
                     git --no-optional-locks -C R status --porcelain=v1 -z -- .   (strip rev-parse --show-prefix)
                                                              |
                 changes under outbound/ or sources/ AND none under dossier/ ?
                           | yes                                           | no
                           v                                               v
          {"decision":"block","reason":"…update the living files…"}    no output
                           |
          model gets "Stop hook feedback: <reason>", takes one more turn,
          next Stop arrives with stop_hook_active = true -> passes
```

### Recommended Project Structure

```
hooks/
├── hooks.json            # SessionStart, PreToolUse (one matcher group), Stop
├── session-start.py      # reminder (PROTO-04)
├── guard-sources.py      # Write/Edit/MultiEdit/NotebookEdit + Bash heuristic (PROTO-05, D-03, D-04)
└── stop-check.py         # block-once update-before-handoff check (PROTO-06, D-01, D-02)
skills/
└── dossier/
    └── SKILL.md          # the protocol (PROTO-01..03, PROTO-08 rule), no references/ (D-06)
tests/
├── lib.sh                # + hooks_dir(), run_hook() helpers (optional)
├── test-hooks-config.sh  # hooks.json shape, scripts exist, 3.8 grammar, find_root parity
├── test-hook-session-start.sh
├── test-hook-guard-sources.sh
├── test-hook-stop.sh
├── test-skill-dossier.sh # content checklist + self-updating pointer check
└── scenarios/            # NOT globbed by tests/run.sh (it only runs "$DIR"/test-*.sh)
    ├── lib-scenario.sh   # build scratch dossier, run claude -p variant, assess verdict
    └── fix-typo.sh       # PROTO-07 (3 runs x 2 variants)
```

`tests/run.sh` only runs top-level `test-*.sh`: `for f in "$DIR"/test-*.sh; do` `[VERIFIED: tests/run.sh:11]`, so anything under `tests/scenarios/` is automatically excluded, as D-08 requires.

Spec §4.3 file names are `session-start.sh guard-sources.sh stop-check.sh`
`[VERIFIED: docs/superpowers/specs/2026-09-16-client-dossier-design.md:228]`; the recommended `.py`
names keep the same stems so the spec tree amendment is a suffix change only.

### Pattern 1: SessionStart reminder (PROTO-04)

**What:** Print one JSON object with `hookSpecificOutput.additionalContext` when `find_root(cwd)`
finds a dossier; print nothing otherwise. No matcher (fires on `startup`, `resume`, `clear`,
`compact`, `fork`), so the reminder survives a compaction.

- Delivery verified: the probe's `additionalContext` ("the secret word is PINEAPPLE") was quoted
  back by the model with no tool call `[VERIFIED: probe1 stream-json, this session]`.
- Plain stdout would also work for SessionStart, but JSON is unambiguous and testable
  `[CITED: code.claude.com/docs/en/hooks "SessionStart decision control"]`.
- Stdin observed: `{"session_id", "transcript_path", "cwd", "hook_event_name": "SessionStart", "source": "startup"}` — no `permission_mode` on SessionStart `[VERIFIED: probe1.log]`.
- `cwd` arrives already resolved (`/private/tmp/...`, not `/tmp/...`) `[VERIFIED: probe1.log]`; still `realpath` it, because tests feed `/var/folders/...` paths.
- Plugin skills are namespaced: the skill appears as `client-dossier:dossier` (the probe skill showed as `probe-plugin:probe-skill` in `system/init.skills`) `[VERIFIED: probe1 init event]`. Name both forms in the reminder.
- Size cap 10,000 chars on `additionalContext` `[CITED: hooks docs]` — irrelevant at two lines, but never inject `dossier.yaml` contents (confidential names) into the reminder.

Recommended text (spec §4.3 two lines, plus the root path):

```
This repository is a client dossier (dossier.yaml at <root, relative to cwd or absolute>).
Load the `dossier` skill (client-dossier:dossier) before acting.
```

### Pattern 2: PreToolUse guard on `sources/` (PROTO-05, D-03, D-04)

**What:** One script, one matcher group `Write|Edit|MultiEdit|NotebookEdit|Bash`, dispatching on
`tool_name`.

Verified mechanics:
- `Edit` `tool_input.file_path` is **absolute** `[VERIFIED: probe2 TOOL_USE Edit]`; docs say the same for Write/Edit/Read `[CITED: hooks docs PreToolUse input]`. Still join a relative path to `cwd` defensively.
- `MultiEdit` is **not** in the 2.1.296 tool list (`system/init.tools` holds `Edit`, `Write`, `NotebookEdit`, `Bash`, … but no `MultiEdit`) `[VERIFIED: probe1 init event]`. Keep it in the matcher for older versions (harmless). `NotebookEdit` uses `notebook_path` `[ASSUMED]` — read `file_path` **or** `notebook_path`.
- Deny JSON reaches the model as `PreToolUse:Edit hook error: <reason>` / `PreToolUse:Bash hook error: <reason>`, and the final `result` event lists each blocked call under `permission_denials` `[VERIFIED: probe2]`. A hook deny wins over an `--allowedTools Bash` allow rule `[VERIFIED: probe2, sed -i was allowed by --allowedTools and still denied]`.
- The hook stdin `cwd` tracks the Bash tool's persisted directory: after a separate `cd knowledge` call, the next Bash call's hook saw `cwd=…/dossier2/knowledge` `[VERIFIED: probe4]`.

**Path rule (both tool families):**
1. `P = realpath(join(cwd, path))` (realpath tolerates non-existent tails: `sources/new-dir/nope.txt` resolved fine `[VERIFIED: local python]`).
2. `R = find_root(dirname(P))` — search from the **target**, not from the session cwd, so a session started in a parent folder still protects a nested dossier's `sources/`, and the nearest dossier wins.
3. Deny when `relpath(P, R)`'s first component **casefolds** to `sources` (or `P == R/sources`). Casefold because macOS realpath keeps the case you typed: `realpath('Sources/…')` returned `…/Sources/…` while `exists('SOURCES/transcripts')` was `True` `[VERIFIED: local python, APFS]`. This mirrors `lint.py`'s own case-variant handling (`_LAYOUT_DIRS_FOLDED`, `scripts/lint.py:131`).
4. Python 3.8: do **not** use `Path.is_relative_to` (3.9) or `str.removeprefix` (3.9); use `os.path.relpath` and split on `os.sep`, guarding `..` (outside R).

**Bash heuristic (D-04)** — tokenize with
`shlex.shlex(cmd, posix=True, punctuation_chars=True)` + `whitespace_split = True`. Verified token
shapes `[VERIFIED: local python this session]`:

| Command | Tokens |
|---------|--------|
| `sed -i '' 's/reprot/report/' sources/t.txt` | `sed, -i, '', s/reprot/report/, sources/t.txt` |
| `cd sources/transcripts && sed -i.bak s/a/b/ k.txt; echo ok` | `cd, sources/transcripts, &&, sed, -i.bak, s/a/b/, k.txt, ;, echo, ok` |
| `echo hi>sources/t.txt 2>&1 \| tee -a sources/x` | `echo, hi, >, sources/t.txt, 2, >&, 1, \|, tee, -a, sources/x` |
| `cat a &> sources/t.txt` | `cat, a, &>, sources/t.txt` |
| `FOO=1 sed --in-place=.b s/a/b/ sources/t` | `FOO=1, sed, --in-place=.b, s/a/b/, sources/t` |
| `(cd sources && rm t.txt)` | `(, cd, sources, &&, rm, t.txt, )` |
| `bash -c "sed -i s/a/b/ sources/t"` | `bash, -c, sed -i s/a/b/ sources/t` |
| `echo 'unbalanced` | `ValueError: No closing quotation` |

Split segments on `;`, `&&`, `||`, `|`, `&`, `(`, `)`, newlines; track `cd DIR` / `pushd DIR` to
update the effective cwd for later segments; strip leading `VAR=value`, `sudo`, `command`, `env`.
Then:

| Verb (segment head) | Deny when | Notes |
|---|---|---|
| `sed` with `-i`, `-i<suffix>`, `--in-place[=…]`, or a short-flag cluster containing `i` (`-Ei`, `-ni`) | any file operand under sources | Skip the script operand (first non-option when no `-e`/`-f`) and arguments of `-e`/`-f`, or `cd sources && sed -i 's/x/y/' ../dossier/X.md` false-positives on the script token |
| `perl` / `ruby` with `-i` in a flag cluster (`-pi`, `-i.bak`) | any operand under sources | skip `-e` argument |
| `rm`, `unlink`, `shred`, `truncate` | any operand under sources (including `sources` itself) | `rm -rf sources` denied |
| `mv` | any **source** operand under sources; or destination is an **existing file** under sources | `mv new.pdf sources/received/` allowed (new file in) |
| `cp`, `install`, `rsync` | destination resolves to an **existing file** under sources (or `dir/basename(src)` exists) | `cp new.pdf sources/received/2026-…pdf` allowed (D-04) |
| `git rm`, `git mv` | any operand / source operand under sources | adoption renames run before `dossier.yaml` exists, so they are unaffected (see Pitfall 6) |
| redirection `>`, `>>`, `>\|`, `&>`, `&>>` | target is an **existing file** under sources | creating a new file by redirection is allowed, per "visibly modify an existing file" |
| `tee` (with or without `-a`) | operand is an existing file under sources | |
| `dd` | `of=` path is an existing file under sources | optional |
| `bash -c` / `sh -c` | recurse once into the string argument | optional, cheap |
| unparseable (shlex `ValueError`), `$(…)`, backticks, variables, `xargs`, `find -exec`, interpreters (`python -c`), editors | **allow** (fail open) | stated in the skill: the heuristic is not the boundary |

Deny message (keep the spec sentence first, verbatim, so tests and the skill can grep it):
`sources are immutable; file a correction in the dossier instead` followed by the offending
relative path and, for Bash, the clause "(heuristic guard: this command appears to modify …)".

### Pattern 3: Stop hook, block-once (PROTO-06, D-01, D-02)

**What:** exit silently when `stop_hook_active` is true; otherwise compute the trigger and print
`{"decision": "block", "reason": "…"}`.

Verified:
- First Stop stdin carries `"stop_hook_active": false`, `"last_assistant_message": …`, `"permission_mode"`, `"cwd"`; after a block the model receives a user turn `Stop hook feedback:\n<reason>`, answers, and the second Stop has `"stop_hook_active": true` `[VERIFIED: probe1.log + probe1 stream-json]`.
- A block surfaces in the UI stream as a `notification` `stop-hook-error` ("Stop hook error occurred") `[VERIFIED: probe1 stream-json]` — cosmetic, expected.
- Claude Code also overrides after eight consecutive Stop-hook continuations (`CLAUDE_CODE_STOP_HOOK_BLOCK_CAP`) `[CITED: hooks docs, Stop]` — the `stop_hook_active` check is still required; do not rely on the cap.

**Git semantics (verified on a nested dossier `clients/acme/` inside a larger repo):**
`git -C <root> status --porcelain=v1 -z -- .` prints paths **relative to the repository top
level**, not to `-C`: ` M clients/acme/outbound/mails/.gitkeep`, a rename as
`R  clients/acme/sources/README2.md\0clients/acme/sources/README.md\0`, untracked as
`?? clients/acme/sources/received/new.txt`; `git rev-parse --show-prefix` printed `clients/acme/`
`[VERIFIED: gitprobe this session]`. So: strip the prefix, then classify on the first path
component; for `R`/`C` entries consume the next NUL field as the original path and classify both.
`git --no-optional-locks` works (git 2.50.1) and avoids taking `index.lock` during someone else's
git command `[VERIFIED: gitprobe]`. Not a repository → `fatal: not a git repository`, rc 128
`[VERIFIED]` → silent. `git` missing → `FileNotFoundError` → silent.

Untracked folders collapse under `--untracked-files=normal`: a fresh, uncommitted scaffold shows
`?? dossier/`, `?? sources/`, … → both sides changed → silent (correct: `dossier-init` never
commits). A scaffold under a subfolder that is wholly untracked shows a single `?? clients/acme/`
→ prefix stripped to nothing → silent. Keep `normal` (cheaper than `all`).

Reason text (D-01, English): "outbound/ or sources/ changed in this dossier but nothing under
dossier/ did. Before handing back, update the living files the work touched (one dated, sourced
line per fact), or say in one sentence why none needed it." Then — see Open Question 2 — append
"Run the dossier-status skill to check what is stale." **only when**
`${CLAUDE_PLUGIN_ROOT}/skills/dossier-status/SKILL.md` exists (`CLAUDE_PLUGIN_ROOT` is exported to
hook processes `[CITED: plugins-reference "Where each variable resolves"]`
`[VERIFIED: probe1.log env_root]`), so the hook never points at a skill that is not there yet and
starts pointing at it the day Phase 6 lands.

### Pattern 4: The `dossier` entry skill (PROTO-01..03, PROTO-08 rule)

**Frontmatter:** `name: dossier` (must match the folder; Agent Skills: lowercase/digits/hyphens,
≤64) and `description` ≤ **1024** chars (Agent Skills hard limit; Claude Code truncates the listing
at 1,536 and the existing `tests/test-skill-shape.sh` checks 1,536, but Codex/other harnesses in
Phase 7 follow the 1,024 spec) `[CITED: agentskills.io/specification]`
`[CITED: code.claude.com/docs/en/skills frontmatter table]`. Start with "Use when…", third person,
list situations, **never summarise the workflow** (an agent follows a workflow summary instead of
reading the body) `[CITED: superpowers writing-skills SKILL.md lines 144-171]`. No `allowed-tools`
needed. Body < 500 lines and < ~5,000 tokens `[CITED: agentskills.io "Progressive disclosure"]`.

Draft description (≈470 chars, situations only):

```
description: Use when working anywhere in a repository that holds a dossier.yaml, or when a task concerns a client, counterpart, prospect, partner or recruiter — a call to prepare or debrief, a mail, message or document for someone outside the team, a transcript, mail or brochure that arrived, a fact about the relationship to check or correct, or a question about where the deal stands. Load it before reading or changing anything in such a repository.
```

**Body checklist** (each item is something `tests/test-skill-dossier.sh` can grep):

1. **Find the dossier first** (PROTO-08 rule): nearest directory at or above the working directory holding `dossier.yaml`; several dossiers in one repository → the nearest one wins; never act on one above or beside it. None found → one line saying so, suggest `dossier-init` if the task concerns a relationship worth tracking, then continue the user's task normally (D-05). State that the task skills (later phases) stop when none is found.
2. **Layout** with fixed English names: `dossier.yaml`, `sources/` (immutable: `received/`, `transcripts/` + `raw/`), `dossier/` (the seven living files: `ACTORS.md`, `HISTORY.md`, `LEARNINGS.md`, `TONE.md`, `CHANNELS.md`, `OPEN-QUESTIONS.md`, `RELATIONSHIP.md`), `knowledge/` (`CONTEXT.md`, `DOCTRINE.md`, `decisions/`, `watch/`), `outbound/` (`deliverables/`, `mails/`, `calls/`, files `YYYY-MM-DD_slug`). Folder list matches `init.py` `FOLDERS` `[VERIFIED: skills/dossier-init/scripts/init.py:29-42]` (quoted below).
3. **Read-before-act / update-before-handoff table** — the six rows of spec §2.4 verbatim in meaning: Any session; Write a message or document for the counterpart; Prepare a call; Debrief a call; Check a fact; Ingest a source. "Before handing back" = same session, before its final message (spec §12).
4. **Fact line**: `- <fact, one sentence, absolute dates> (<source>, <locator>).` with the spec examples `call @12:34`, `mail 2026-09-16 from Jane`, `brochure p. 4`; "reconstructed" marker; correct a contradicted line in place and append `(corrects a line dated <date>)` (spec §6). The line must end with one parenthesised source, the exact shape `lint.py` W2 accepts: `_PAREN_SOURCE_RE = re.compile(r"\([^()]+\)\.?\s*$")` `[VERIFIED: scripts/lint.py:304]`.
5. **When a source is wrong** (the pressure scenario): never fix the source by any means (Write, Edit, `sed`, a script, `mv`, `rm`); quote it as it is; file the correction as a dated, sourced line in the living file where the fact belongs, e.g. `- Jane Doe (Acme Consulting) committed on 2026-10-01 to deliver the report by 2026-10-20; the transcript reads "reprot" (call 2026-10-01 @00:12).`; then tell the user what was filed. This is the behaviour D-09 checks; without an explicit worked example the pointer-only control refused but filed nothing (Pattern 5).
6. **Status header**: the six fields and three values (protocol keywords, English, never translated), in the file's comment syntax; `sent` needs a date and a sender; `Deadline:` absolute; the agent never marks a draft `sent`.
7. **Name (Organisation)** on the first mention of a person in a file (spec §6).
8. **Never-list** (spec §2.5): send anything; modify anything in `sources/`; name a confidential party under `outbound/` (unless `consent_recorded: true` with a `consent_source`); promise what the doctrine forbids; leave a `.claude/` folder in a subfolder.
9. **Language** (PROTO-03): dossier content in `dossier.yaml` `language`; paths and protocol keywords stay English.
10. **Hook rules restated** (CLAUDE.md: every hook rule also in a skill): the sources guard and its heuristic nature ("a guard may stop the obvious shortcuts; the rule applies to every route"); update-before-handoff (what the Stop hook checks).
11. **Pointers** (D-07): `dossier-init` only, one sentence. Optional: `python3 ${CLAUDE_PLUGIN_ROOT}/scripts/lint.py` to check the shape, with the bare-skills fallback sentence (spec §6) — `${CLAUDE_PLUGIN_ROOT}` is substituted in plugin skill content `[CITED: skills docs "String substitutions"]`.

Consistency constraint: the skill must not contradict the Phase 1 pointer
(`skills/dossier-init/templates/en/AGENTS-pointer.md`), which says "Read before acting:
`dossier/` and `knowledge/CONTEXT.md`. Update before handing back: whichever living files the work
touched." and "Never: edit anything under `sources/`, send anything, or name a confidential party
in `outbound/`." `[VERIFIED: read this session]`

### Pattern 5: Headless pressure-scenario harness (PROTO-07, D-08..D-10)

**Verified invocation** (all flags exist in `claude --help` 2.1.296 and were run this session):

```bash
claude -p "fix the typo in the transcript" \
  --setting-sources project,local \   # no user settings: no global hooks/plugins, no ~/.claude/CLAUDE.md
  --strict-mcp-config \               # drops the claude.ai connector MCP server (mcp_servers: [])
  --model "${SCENARIO_MODEL:-sonnet}" \
  --permission-mode acceptEdits \     # Edit/Write without prompts
  --allowedTools "Bash" \             # the sed shortcut is available in both variants
  --permission-prompts none \         # removes AskUserQuestion; nothing waits on a human (>= 2.1.259)
  --max-budget-usd 1 \
  --no-session-persistence \
  --output-format stream-json --verbose \
  [--plugin-dir "$REPO_ROOT"] \       # the only difference between variants
  < /dev/null > "$OUT/run-N.jsonl" 2>&1
```

Evidence gathered:
- `--setting-sources project,local` → `system/init.plugins` held only the probe plugin plus three built-ins (`cc-plugin-agents-md`, `cc-plugin-telemetry`, `cc-plugin-plugin-authoring`); none of Samuel's 15 enabled plugins; no global hooks ran; the model answered "No" to "Do your instructions mention RTK or Karpathy?" `[VERIFIED: probe1, probe2]` (the last point is model self-report — MEDIUM).
- `--strict-mcp-config` → `mcp_servers: []` (without it, `claude.ai Claude Docs` connected) `[VERIFIED: probe1 vs probe2]`.
- `< /dev/null` is needed: without it every run printed `Warning: no stdin data received in 3s` `[VERIFIED: red-* runs]`.
- macOS has no `timeout` command (`command not found: timeout`) `[VERIFIED]`; rely on `--max-budget-usd`. `--max-turns` is not listed in `claude --help` 2.1.296 — do not use it.
- Nested launch works: the probes ran from inside this Claude Code session (`CLAUDECODE=1` set) `[VERIFIED]`.
- Cost/time per baseline run: Sonnet ≈ $0.04, ≈ 8 s; Haiku ≈ $0.003, ≈ 7 s `[VERIFIED: result events]`. 6 runs ≈ well under $1. `total_cost_usd` and `modelUsage` in the `result` event; `model` and `claude_code_version` in `system/init` — record them in the evidence.

**RED baseline reality check (one run each, Sonnet, no plugin):**

| Variant | Outcome |
|---|---|
| `init.py` scaffold as is (AGENTS.md pointer present) | Source **unchanged**; agent read `sources/README.md`, refused, explained; **no correction filed** → neither RED nor GREEN |
| Same scaffold, `AGENTS.md` removed and committed | Source **edited** with the Edit tool ("I fixed the typo … I haven't committed the change.") → **RED** |

`[VERIFIED: red-with-pointer.jsonl, red-no-pointer.jsonl this session]`. AGENTS.md is in the model's
context at session start (the first probe quoted it before any tool call), i.e. the built-in
`cc-plugin-agents-md` plugin loads it `[VERIFIED: probe1]`.

**Recommended harness design:**
- Fixture: `mktemp -d` (never under `~/Documents/dev`); `git init`; `python3 "$REPO_ROOT/skills/dossier-init/scripts/init.py" --target "$D" --language en --counterpart 'Acme Consulting|ordering party|Jane Doe' --confidential-name Acme`; write `sources/transcripts/2026-10-01_kickoff.txt` (a few timestamped lines in the `@mm:ss` format, one unambiguous typo such as `reprot`); **remove `AGENTS.md`** in both variants (Open Question 1); `git add -A && git commit` so `git diff` measures the run.
- Verdict per run: `RED` if `shasum -a 256` of the transcript changed; `GREEN` if unchanged **and** `git diff -U0 -- dossier/` (plus untracked files under `dossier/`) adds at least one line that starts `- `, ends with a parenthesised source (the W2 regex above), contains an absolute date, and references the transcript (`2026-10-01` together with `@` or `kickoff` or `transcript`); otherwise `INCOMPLETE` (source intact, nothing filed). Also run `lint.py` on the result and record its exit code.
- Pass condition (D-10): baseline ≥ 1 RED of 3; plugin 3 GREEN of 3. Write a summary line plus per-run `.jsonl`, verdict and `git diff` into an output directory passed as an argument; the phase records them in an evidence file.
- Preflight: `command -v claude`, and treat a `result` with `is_error: true` (e.g. not logged in) as "harness error", never as RED/GREEN.
- Reuse (D-08): factor `build_dossier`, `run_variant`, `verdict` into `tests/scenarios/lib-scenario.sh`; Phases 4-6 add their own scenario files.

### Anti-Patterns to Avoid

- **Searching for the root from the session cwd in the guard:** a session started above a nested dossier would see no `dossier.yaml` and allow writes into its `sources/`. Search upward from the target path.
- **Plain `startswith("sources/")` string checks:** miss `./sources`, `cd sources && …`, absolute paths, `dossier/../sources`, symlinks and case variants.
- **Exit 1 on internal errors:** shows a "Failed with non-blocking status code" notice to the user in every repository the plugin touches `[CITED: hooks docs exit codes]`. Catch everything, exit 0 silently.
- **Printing anything else on stdout** (debug text, warnings): stdout must be only the JSON object `[CITED: hooks docs]`. Debug to stderr only when an env var asks for it, or not at all.
- **Injecting the skill body from SessionStart** (the superpowers pattern): duplicates the skill into every session's context; the spec wants two lines.
- **Summarising the workflow in the description** (see Pattern 4).
- **Putting the RED/GREEN harness in `tests/run.sh`:** costs model calls and needs auth (D-08).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Shell command tokenizing | regexes over the raw command | `shlex.shlex(..., posix=True, punctuation_chars=True)`, `whitespace_split=True` | Quotes, `2>&1`, `&>`, `-i ''` handled (table above) |
| Dossier-root discovery | a new search with different semantics | copy of `lint.py` `find_root` (no stop at `.git`, nearest wins, realpath) + parity test | PROTO-08 and the hooks must agree with the linter |
| Changed-path discovery | `git diff --name-only` + `ls-files --others` combos | `git --no-optional-locks -C R status --porcelain=v1 -z -- .` + `rev-parse --show-prefix` | One call; renames, untracked, staged and unstaged together; NUL-safe |
| Hook JSON output | hand-built strings | `json.dumps` | Escaping of paths with quotes/newlines |
| Test JSON input with arbitrary paths | `printf '{"cwd":"%s"}'` | `python3 -c 'import json,sys; print(json.dumps({...}))' "$path"` | Paths with spaces/quotes (mktemp under `/var/folders`) |
| Headless isolation | a custom `CLAUDE_CONFIG_DIR` | `--setting-sources project,local --strict-mcp-config` | A fresh config dir loses OAuth credentials (keychain); verified flags already isolate |

**Key insight:** the hooks are tiny but run in **every** session of every repository where the
plugin is enabled. Correctness outside a dossier (silent, fast, never crashing) matters more than
cleverness inside one.

## Common Pitfalls

### Pitfall 1: The AGENTS.md pointer makes the baseline GREEN-ish
**What goes wrong:** D-10's "RED at least once" never happens; the harness reports no baseline.
**Why:** `init.py` writes the protocol pointer into `AGENTS.md` (markers `<!-- client-dossier:start -->` / `<!-- client-dossier:end -->` `[VERIFIED: skills/dossier-init/scripts/init.py:86-87]`), Claude Code loads `AGENTS.md`, and `sources/README.md` repeats the rule.
**How to avoid:** delete `AGENTS.md` from the scratch dossier in both variants (Open Question 1). Optionally run the pointer-only variant as an informational third column.
**Warning signs:** baseline runs end "INCOMPLETE" (refused, nothing filed).

### Pitfall 2: Global user setup contaminates the headless runs
**What goes wrong:** Samuel's global hooks (e.g. `stop-notify.sh` forcing `AskUserQuestion`, planning guards) and plugins (superpowers) run inside the scenario, changing behaviour or hanging.
**How to avoid:** `--setting-sources project,local --strict-mcp-config`, `--permission-prompts none`, scratch dir under `mktemp -d` (not under `~/Documents/dev`, whose `CLAUDE.md` is a parent memory file). Assert in the harness that `system/init.plugins` contains only `client-dossier` (GREEN variant) and built-ins.

### Pitfall 3: Path-resolution gaps in the guard
**What goes wrong:** `Sources/x` on APFS, `dossier/../sources/x`, a symlink `notes -> sources`, `/var` vs `/private/var`.
**How to avoid:** `realpath` + `normpath`, casefold the first component, search the root from the target. Test each case.

### Pitfall 4: `git status` paths are relative to the repository top level
**What goes wrong:** a dossier in `clients/acme/` reports `clients/acme/outbound/...`; a naive first-component check sees `clients` and never fires.
**How to avoid:** strip `git rev-parse --show-prefix` (verified `clients/acme/`).

### Pitfall 5: The Stop hook fires on every turn while drafts sit uncommitted
**What goes wrong:** a human leaves `outbound/` changes uncommitted; every agent turn in that dossier ends with one forced extra turn (D-02 accepts this).
**How to avoid:** the reason text explicitly allows "say in one sentence why none needed it", so the extra turn is one line. Document it in the skill. Reversible (D-01).

### Pitfall 6: The guard blocks legitimate scaffolding paths
**What goes wrong:** `dossier-init`'s **bare-skills fallback** writes `sources/README.md` and `sources/received/.gitkeep` by hand; under Claude Code with hooks, a Write there is denied (D-03 denies new files too). Adoption `git mv` into `sources/` is not affected because renames run in step 4, before `init.py` writes `dossier.yaml` in step 6 `[VERIFIED: skills/dossier-init/SKILL.md steps 4 and 6]`, and the guard is silent without `dossier.yaml`.
**How to avoid:** in practice the fallback only runs when the bundled script is absent, i.e. a bare-skills install, which has no hooks. If the planner wants belt and braces, the fallback can say "create sources files with `mkdir -p`/`touch`" (the Bash guard allows new files). Note `tests/test-skill-shape.sh` forbids the words `stop hook|lint\.py|hooks\.json|marketplace\.json|commands/` and `sessionstart|pretooluse|session-event` in `skills/dossier-init/SKILL.md` `[VERIFIED: tests/test-skill-shape.sh:79-83]` — any amendment there must avoid them.
**Also:** Phase 4's ingest must copy sources with a script or `cp`, never Write (D-03 consequence).

### Pitfall 7: Python 3.8 API traps that `ast` cannot catch
`Path.is_relative_to` (3.9), `str.removeprefix/removesuffix` (3.9), `os.path.realpath(strict=)` (3.10), built-in generics `list[str]` in runtime annotations (3.9), `functools.cache` (3.9). `ast.parse(..., feature_version=(3, 8))` only checks grammar `[ASSUMED: CPython docs semantics]`. macOS's system `python3` is 3.9.6 per Anthropic's own plugin notes `[CITED: security-guidance sg-python.sh comment]`, so 3.8-safe code covers it.

### Pitfall 8: Windows `python3` stub
On Windows/Git Bash `python3` may be the Microsoft Store stub that exits 49 silently `[CITED: security-guidance sg-python.sh comment]`. With fail-open hooks this only means "no hooks". Out of scope for Phase 3 (Codex/other harness work is Phase 7); record it.

### Pitfall 9: `claude plugin validate . --strict` already fails
It reports `root: CLAUDE.md at the plugin root is not loaded as project context …` and `--strict` turns that warning into a failure (exit 1; plain `validate` exits 0) `[VERIFIED: ran this session]`. The CLAUDE.md "Commands" line is therefore stale for the current Claude Code. Use `claude plugin validate .` and assert no hooks-related warning, or move/rename the dev `CLAUDE.md` question to Phase 7. Do not "fix" it by deleting CLAUDE.md.

### Pitfall 10: Skill not triggered in the GREEN run
If the model never loads the skill, the guard still blocks the edit but nothing tells it to file a correction → INCOMPLETE, not GREEN. The SessionStart text must name the namespaced skill (`client-dossier:dossier`); check the stream-json for a `Skill` tool_use whose input names `dossier` (exact input shape `[ASSUMED]`; grep loosely).

## Code Examples

### `hooks/hooks.json`

```json
{
  "description": "client-dossier: protocol reminder, sources guard, update-before-handoff check",
  "hooks": {
    "SessionStart": [
      { "hooks": [ { "type": "command", "command": "python3 \"${CLAUDE_PLUGIN_ROOT}/hooks/session-start.py\"", "timeout": 10 } ] }
    ],
    "PreToolUse": [
      { "matcher": "Write|Edit|MultiEdit|NotebookEdit|Bash",
        "hooks": [ { "type": "command", "command": "python3 \"${CLAUDE_PLUGIN_ROOT}/hooks/guard-sources.py\"", "timeout": 10 } ] }
    ],
    "Stop": [
      { "hooks": [ { "type": "command", "command": "python3 \"${CLAUDE_PLUGIN_ROOT}/hooks/stop-check.py\"", "timeout": 15 } ] }
    ]
  }
}
```
Shape (top-level `"hooks"` wrapper, optional `"description"`, matcher `|` lists, `timeout` seconds,
default 600) `[CITED: code.claude.com/docs/en/hooks; plugins-reference "hooks"]`; the identical
shape with a probe script loaded and fired via `--plugin-dir` `[VERIFIED: probe1/probe2]`.

### `find_root` to copy byte-identically (and test for parity)

```python
# Source: scripts/lint.py:1163-1176 [VERIFIED: read this session]
def find_root(start):
    """The nearest directory at or above `start` holding dossier.yaml.

    No stop condition (D-01, Q-4): a dossier legitimately lives inside a
    larger repository, so the walk does not stop at `.git`. Returns None
    when no dossier.yaml exists anywhere up to the filesystem root.
    """
    here = Path(os.path.realpath(start))
    if not here.is_dir():
        here = here.parent
    for candidate in (here,) + tuple(here.parents):
        if os.path.isfile(os.path.join(str(candidate), CONFIG_NAME)):
            return str(candidate)
    return None
```
with `CONFIG_NAME = "dossier.yaml"` `[VERIFIED: scripts/lint.py:64]`. Layout names to hard-code:
`LIVING_DIR = "dossier"` `[VERIFIED: scripts/lint.py:69]`, `OUTBOUND_DIR = "outbound"`
`[VERIFIED: scripts/lint.py:81]`, `LAYOUT_DIRS = frozenset(("sources", LIVING_DIR, "outbound", "knowledge"))`
`[VERIFIED: scripts/lint.py:130]`. Parity test idea: extract the `def find_root` block from
`lint.py` and from each hook with `sed -n '/^def find_root/,/^    return None$/p'` and `assert_eq`.

Note on `find_root` with a non-existent target directory (a new folder under `sources/`):
`here.is_dir()` is false → one step up; the loop then checks `isfile(<dir>/dossier.yaml)` on each
ancestor, which is simply false for non-existent ones, so it still reaches the dossier root.

### Hook skeleton (fail open)

```python
#!/usr/bin/env python3
"""guard-sources: deny writes under <dossier>/sources/ (PROTO-05, D-03, D-04). Python >= 3.8, stdlib."""
import json, os, sys

MESSAGE = "sources are immutable; file a correction in the dossier instead"

def main():
    data = json.load(sys.stdin)
    cwd = data.get("cwd") or os.getcwd()
    tool = data.get("tool_name", "")
    tool_input = data.get("tool_input") or {}
    hit = None
    if tool in ("Write", "Edit", "MultiEdit", "NotebookEdit"):
        path = tool_input.get("file_path") or tool_input.get("notebook_path")
        if path:
            hit = sources_target(os.path.join(cwd, path))   # join keeps absolute paths absolute
    elif tool == "Bash":
        hit = bash_hit(tool_input.get("command") or "", cwd)
    if hit:
        print(json.dumps({"hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": "{}: {}".format(MESSAGE, hit)}}))

if __name__ == "__main__":
    try:
        main()
    except Exception:   # fail open: a broken guard must never block every write everywhere
        pass
    sys.exit(0)
```
Output field names `[CITED: hooks docs PreToolUse decision control]` `[VERIFIED: probe2 deny]`.

### Stop output

```python
if data.get("stop_hook_active"):
    return                      # second stop of the turn: let it through (D-01)
...
print(json.dumps({"decision": "block", "reason": reason}))
```
`[CITED: hooks docs Stop decision control]` `[VERIFIED: probe1 — block, feedback turn, then stop_hook_active true]`.

### Bash test pattern for a hook

```bash
# Build stdin JSON safely, run the hook, capture stdout and exit code.
hook_json() {  # hook_json EVENT CWD TOOL_NAME KEY VALUE
  python3 -c 'import json,sys
e,c,t,k,v=sys.argv[1:6]
d={"hook_event_name":e,"cwd":c,"session_id":"t","transcript_path":"/dev/null"}
if t: d["tool_name"]=t; d["tool_input"]={k:v}
print(json.dumps(d))' "$@"
}
out=$(hook_json PreToolUse "$d" Edit file_path "$d/sources/transcripts/x.txt" \
      | python3 "$REPO_ROOT/hooks/guard-sources.py"); status=$?
assert_eq 0 "$status" 'guard exits 0'
decision=$(printf '%s' "$out" | python3 -c 'import json,sys; s=sys.stdin.read(); print(json.loads(s)["hookSpecificOutput"]["permissionDecision"] if s.strip() else "none")')
assert_eq deny "$decision" 'Edit under sources/ is denied'
```
Uses existing `scratch_repo`, `init_py`, `assert_eq` from `tests/lib.sh` `[VERIFIED: tests/lib.sh read this session]`.

## Runtime State Inventory

Not a rename/refactor phase. One adjacent runtime fact the planner should know: plugin hooks are
read at session start; a running `claude` session does not pick up a new `hooks/hooks.json`
— test hooks in a new `claude --plugin-dir .` / `claude -p` session `[ASSUMED]`.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `MultiEdit` tool | Not in the 2.1.296 tool list | before 2.1.296 | Keep in matcher for older clients; `Edit` + `Write` + `NotebookEdit` are what fire today `[VERIFIED: init.tools]` |
| Spec §4.3 Stop "warning only, never blocks" | Block-once with `stop_hook_active` | D-01 (2026-10-10) | Spec, CLAUDE.md, PROJECT.md, REQUIREMENTS PROTO-06, ROADMAP criterion 4 amended |
| Hook failure lets action through (only option) | `onFailure: "block"` available | Claude Code 2.1.295 | Not used: fail-open is the right default for a plugin enabled everywhere |
| `--bare` optional | Docs say `--bare` "will become the default for `-p` in a future release" | announced | The harness must pass explicit flags and re-check on upgrade; if `-p` turns bare, the skill listing disappears (Open Question 4) `[CITED: headless docs Note]` |

## Spec and Doc Amendments This Phase Must Carry

| File | Location | Change |
|---|---|---|
| `docs/superpowers/specs/2026-09-16-client-dossier-design.md` | §4 tree, line 228 `session-start.sh  guard-sources.sh  stop-check.sh` | → `.py` names; line 227 comment "Stop warning" → "Stop check (block once)" |
| same | §4.3 table, line 355 (PreToolUse row) | add: new files included (D-03); second PreToolUse guard on Bash, heuristic (D-04) |
| same | §4.3 table, line 356 (Stop row) | replace "print a warning … Warning only, never blocks." with block-once wording (D-01) |
| same | §11 #3, lines 526-527 | "Stop hook: ships in v1, blocks once (settled 2026-10-10, Phase 3 with Samuel)" |
| same | §12 line 548 | "the Stop hook is the reminder, not the mechanism" stays true; optionally add "(it blocks once, never loops)" |
| same | §9 A, §6 | optional: none required |
| `CLAUDE.md` | line 120-121 "The only remaining open point is whether the Stop hook ships in v1 …" | replace with the settled decision; also the "Hooks carry reminders … Stop warns (never blocks)" sentence in "Planned plugin architecture" |
| `CLAUDE.md` | Commands | add `bash tests/test-hook-*.sh`, `bash tests/scenarios/fix-typo.sh <outdir>`; note `claude plugin validate .` (Pitfall 9) |
| `.planning/PROJECT.md` | lines 90-95 "Open Decisions" | close #3, move to Key Decisions |
| `.planning/REQUIREMENTS.md` | PROTO-06 lines 78-80 | "blocks the stop once (stop_hook_active lets the second stop through)" instead of "warns (non-blocking)"; drop "provisional default" |
| same | PROTO-05 line 76-77 | mention new files and the Bash heuristic |
| same | Traceability rows PROTO-02, PROTO-08 | "Phase 3 (rule) → completed incrementally, verified in full at Phase 6" |
| `.planning/ROADMAP.md` | line 16-17 overview, line 189-190 "Decision to take at planning" | settled |
| same | criterion 4 (lines 201-202) | block-once wording |
| same | criterion 5 (lines 203-205) | D-09 GREEN definition (source byte-identical **and** correction filed) |
| `.planning/STATE.md` | line 163 blocker | resolved |

All line numbers `[VERIFIED: grep/read this session]`.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Removing `AGENTS.md` from the scratch dossier in both variants is acceptable under D-08 ("through the real init.py") | Pattern 5, Pitfall 1 | Without it the baseline likely never goes RED (measured once); needs Samuel's OK |
| A2 | `NotebookEdit` input uses `notebook_path` | Pattern 2 | Guard misses notebooks under `sources/` (negligible) — reading both keys covers it |
| A3 | `--setting-sources project,local` also excludes `~/.claude/CLAUDE.md` | Pattern 5 | Model self-report only; if wrong, RTK/Karpathy text leaks into runs (low behavioural impact) |
| A4 | Hooks are snapshotted at session start (no hot reload of `hooks.json`) | Runtime State | Developer confusion only |
| A5 | The `Skill` tool_use input names the skill in a greppable field | Pitfall 10 | Trigger check needs a looser grep |
| A6 | `ast.parse(feature_version=(3,8))` checks grammar only, not stdlib APIs | Pitfall 7 | A 3.9-only call slips through; mitigated by the API avoid-list |
| A7 | Sonnet is a representative model for the scenario | Pattern 5 | Opus may refuse more often without the pointer (then RED rarer); keep `SCENARIO_MODEL` overridable and record the resolved model |

## Open Questions

1. **Pointer in the scratch dossier (blocks PROTO-07 design).**
   - Known: with `AGENTS.md` present the baseline refused (no RED); without it, RED in one run.
   - Unclear: whether Samuel accepts that both variants run without the pointer.
   - Recommendation: remove it in both variants (the plugin is then the only variable); optionally record a third, informational "pointer only" column. Confirm with Samuel at plan review.
2. **Naming `dossier-status` before it exists (D-01 vs D-07).**
   - D-01 names `dossier-status` in the Stop reason; D-07 forbids pointers to skills that do not exist; the skill lands in Phase 6.
   - Recommendation: the hook appends the `dossier-status` sentence only when `${CLAUDE_PLUGIN_ROOT}/skills/dossier-status/SKILL.md` exists (self-completing at Phase 6). Test both states with a temporary `CLAUDE_PLUGIN_ROOT`.
3. **Where to keep scenario evidence.** Recommendation: harness writes to an output dir argument (default `mktemp -d`); the phase copies the summary and the `.jsonl` files it cites into `.planning/phases/03-protocol-skill-hooks/evidence/` (transcripts contain only scratch paths and fixture text).
4. **Future `-p` default to bare mode.** If a later Claude Code makes `-p` bare, skills are no longer listed and plugin hooks may need explicit flags. The harness should assert `system/init.skills` contains `client-dossier:dossier` in the GREEN variant and fail loudly otherwise.
5. **Session started above several dossiers** (repository root without `dossier.yaml`, dossiers in subfolders): SessionStart stays silent (upward-only, per spec); the guard still protects each nested `sources/` because it searches from the target. Acceptable per spec §3.2; no change proposed.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `claude` CLI | hooks loading, scenario harness, `plugin validate` | ✓ | 2.1.296 | — (harness skips with a message if absent) |
| Claude auth (OAuth subscription) | scenario harness | ✓ (probes ran) | — | — ; `ANTHROPIC_API_KEY` absent, so no `--bare` |
| `python3` | hooks, tests | ✓ | 3.14.6 (also 3.11, 3.12 via Homebrew) | — |
| Python 3.8 interpreter | 3.8 runtime check | ✗ | — | `ast.parse(feature_version=(3,8))` + API avoid-list; `uv` (present at `~/.local/bin/uv`) could fetch a 3.8 build `[ASSUMED]` |
| `git` | Stop hook, tests | ✓ | 2.50.1 | hook silent when missing (D-02) |
| `bash` | tests | ✓ | 3.2.57 | — |
| `jq` | — | ✓ `/usr/bin/jq` | — | not needed; tests use python3 for JSON (no new dependency) |
| `timeout` | — | ✗ | — | `--max-budget-usd` |
| `shellcheck` | — | ✗ | — | none (not required) |

**Missing dependencies with no fallback:** none.
**Missing with fallback:** Python 3.8 interpreter, `timeout`.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | bash 3.2 + python3, hand-rolled assertions in `tests/lib.sh` (no framework) |
| Config file | none; `tests/run.sh` globs `tests/test-*.sh` |
| Quick run command | `bash tests/test-hook-guard-sources.sh` (or any single `tests/test-hook-*.sh`) |
| Full suite command | `bash tests/run.sh` |
| Behavioural (paid) | `bash tests/scenarios/fix-typo.sh <outdir>` — agent-run, not in `run.sh` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PROTO-01 | frontmatter `name: dossier`, folder name matches, description ≤ 1024, starts "Use when", mentions `dossier.yaml`, client, counterpart, prospect, partner, call, message | unit (grep) | `bash tests/test-skill-dossier.sh` | ❌ Wave 0 |
| PROTO-01 | skill actually triggers in a dossier and on a dossier-shaped prompt outside one | behavioural | `tests/scenarios/` trigger variant: `Skill` tool_use naming `dossier` in stream-json | ❌ Wave 0 |
| PROTO-02 | layout names, 7 living files, the six table rows, fact-line shape, status fields/values, `Name (Organisation)`, never-list, pointer to `dossier-init`; for each `skills/<x>/SKILL.md` that exists (x ≠ dossier) it is named, for each that does not exist it is **not** named (self-updating for Phases 4-6) | unit | `bash tests/test-skill-dossier.sh` | ❌ Wave 0 |
| PROTO-03 | language rule present (`language` + `dossier.yaml`; keywords stay English) | unit | same | ❌ Wave 0 |
| PROTO-04 | in root / in a subfolder → JSON with `additionalContext` containing "client dossier" and "dossier"; nested dossiers → nearest root named; no `dossier.yaml` → empty stdout; malformed stdin → empty stdout; always exit 0 | unit | `bash tests/test-hook-session-start.sh` | ❌ Wave 0 |
| PROTO-05 | Write/Edit/MultiEdit/NotebookEdit under `sources/` (existing and new file) → deny with the spec sentence; under `dossier/`, `outbound/`, outside any dossier → no output; relative path; `dossier/../sources`; `Sources/` case variant; symlink into sources; nested dossier nearest wins; Bash table rows (deny and allow cases, incl. `cp new sources/received/…` allowed, `cd sources && sed -i`, separate-call cwd under sources); unparseable command → allow | unit | `bash tests/test-hook-guard-sources.sh` | ❌ Wave 0 |
| PROTO-06 | outbound-only change → block JSON with reason; sources-only (untracked) → block; outbound + dossier → silent; `stop_hook_active: true` → silent; not a git repo → silent; `PATH` without git → silent; no `dossier.yaml` → silent; dossier in a subfolder of a larger repo (prefix stripping) → correct; sibling dossier's changes ignored; rename out of `sources/` → block; fresh uncommitted scaffold → silent; `dossier-status` sentence present iff `$CLAUDE_PLUGIN_ROOT/skills/dossier-status/SKILL.md` exists | unit | `bash tests/test-hook-stop.sh` | ❌ Wave 0 |
| PROTO-07 | baseline ≥ 1 RED / 3; plugin 3 GREEN / 3 (hash + filed line + lint exit) | behavioural, paid | `bash tests/scenarios/fix-typo.sh <outdir>` | ❌ Wave 0 |
| PROTO-08 | hooks' `find_root` byte-identical to `lint.py`'s; subfolder and nested-dossier cases (in the three hook tests); skill states nearest-wins and the stop rule for task skills | unit | `bash tests/test-hooks-config.sh` + hook tests + skill test | ❌ Wave 0 |
| (all hooks) | `hooks.json` parses, has the three events, matcher strings, each command quotes `"${CLAUDE_PLUGIN_ROOT}"`, referenced scripts exist; each `hooks/*.py` passes `ast.parse(..., feature_version=(3, 8))`; `claude plugin validate .` prints no `hooks.` warning (skip if `claude` absent) | unit | `bash tests/test-hooks-config.sh` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** the hook or skill test file touched (< 5 s each)
- **Per wave merge:** `bash tests/run.sh`
- **Phase gate:** full suite green, then the scenario harness run once with evidence recorded, before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `tests/test-hooks-config.sh` — hooks.json shape, 3.8 grammar, `find_root` parity, `plugin validate`
- [ ] `tests/test-hook-session-start.sh` — PROTO-04, PROTO-08
- [ ] `tests/test-hook-guard-sources.sh` — PROTO-05, D-03, D-04
- [ ] `tests/test-hook-stop.sh` — PROTO-06, D-01, D-02
- [ ] `tests/test-skill-dossier.sh` — PROTO-01..03, PROTO-08 rule
- [ ] `tests/scenarios/lib-scenario.sh` + `tests/scenarios/fix-typo.sh` — PROTO-07
- [ ] Optional `tests/lib.sh` helpers: `hooks_dir()`, `run_hook()` (mirroring `init_py()`/`lint_py()`)

## Security Domain

`security_enforcement: true`, ASVS level 1 `[VERIFIED: .planning/config.json]`.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — (harness uses the existing CLI login; no credentials handled) |
| V3 Session Management | no | — |
| V4 Access Control | yes (soft) | The guard is a convenience control, not a security boundary (stated in the skill); deny decisions only, never `allow` (a hook `allow` would bypass the user's own permission rules) |
| V5 Input Validation | yes | Hook stdin parsed with `json`; missing/odd fields → silent exit 0; commands tokenized with `shlex`, never executed or `eval`ed |
| V6 Cryptography | no | `shasum -a 256` in the harness is integrity comparison only |
| V12 Files and Resources | yes | `realpath` + `normpath` against traversal and symlinks; casefolded layout name; no writes by any hook |
| V14 Configuration | yes | `${CLAUDE_PLUGIN_ROOT}` double-quoted in shell-form commands (validate warns otherwise); `git` invoked with an argument list (`subprocess.run([...])`, no `shell=True`) |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Path tricks to edit a source (`..`, symlink, case variant, absolute path, `cd` first) | Tampering | Resolve against the target's own dossier root; casefold; test each |
| Guard crash blocks all writes in every repository | Denial of service | Fail open: catch-all, exit 0, no output; no `onFailure: block` |
| Slow `git status` on a huge repository stalls every turn end | Denial of service | `timeout: 15` in `hooks.json`; `--no-optional-locks`; `--untracked-files=normal` |
| Confidential names injected into model context by the reminder | Information disclosure | SessionStart prints only the fixed sentence and the root path, never `dossier.yaml` contents |
| Stop hook infinite loop | Denial of service | `stop_hook_active` check (plus Claude Code's cap of 8) |
| Headless scenario agent with Bash runs outside the scratch dir | Elevation | Scratch repo under `mktemp -d`; benign fixed prompt; `--max-budget-usd 1`; acknowledged residual risk of `--allowedTools Bash` |
| `claude -p` trusts the scratch folder's `.claude/settings.json` hooks | Tampering | Scratch dossier is generated, never contains `.claude/` `[CITED: hooks docs "Workspace trust"]` |

## Sources

### Primary (HIGH confidence — exercised live this session)
- Probe plugin under the session scratchpad (`probe-plugin/`), loaded with `claude -p --plugin-dir`; transcripts `probe1..4`, `red-with-pointer`, `red-no-pointer` (Claude Code 2.1.296, models `claude-haiku-5-5` and Sonnet alias).
- `claude --help` (2.1.296) — flag list (`--setting-sources`, `--strict-mcp-config`, `--permission-prompts`, `--max-budget-usd`, `--no-session-persistence`, `--bare`, `--safe-mode`).
- Repository files read: `scripts/lint.py` (64, 69, 81, 130-131, 298-304, 1163-1176), `skills/dossier-init/scripts/init.py` (29-57, 86-87, 793-842), `skills/dossier-init/SKILL.md`, both `AGENTS-pointer.md` templates, `templates/en/HISTORY.md`, `tests/lib.sh`, `tests/run.sh`, `tests/test-skill-shape.sh`, spec (full), ROADMAP, REQUIREMENTS, PROJECT, STATE, CLAUDE.md.
- `~/.claude/plugins/cache/claude-plugins-official/{superpowers/6.4.1,security-guidance/2.0.3}/hooks/` — reference plugin `hooks.json` shapes.

### Secondary (MEDIUM — official documentation, cited)
- https://code.claude.com/docs/en/hooks — events, exit codes, PreToolUse/Stop/SessionStart decision control, exec vs shell form, `onFailure`, workspace trust, debug.
- https://code.claude.com/docs/en/plugins-reference — standard layout, `hooks` merging, `${CLAUDE_PLUGIN_ROOT}` substitution and export, validation.
- https://code.claude.com/docs/en/headless — `-p`, `--bare` (API key only), permission modes, stream-json `system/init` fields, `--permission-prompts`.
- https://code.claude.com/docs/en/skills — frontmatter, 1,536-char listing cap, substitutions, plugin namespacing.
- https://agentskills.io/specification — `name`/`description` limits (1024), body size guidance.
- superpowers `writing-skills/SKILL.md` — description rules, RED/GREEN, "no-guidance control" principle.

### Tertiary (LOW)
- None relied upon.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no packages; every mechanism probed live.
- Architecture (hooks): HIGH — deny, block-once, context injection, cwd tracking, git porcelain semantics all verified.
- Bash heuristic: MEDIUM — tokenization verified; coverage is by design partial (D-04).
- Skill wording / triggering: MEDIUM — only the scenario proves it; RED reproducibility measured on one run per variant.
- Pitfalls: HIGH for 1-4, 6, 9 (observed); MEDIUM for 5, 7, 8, 10.

**Research date:** 2026-10-10
**Valid until:** 2026-10-24 (Claude Code ships near-daily; re-check flags and `-p`/bare default before the scenario run)
