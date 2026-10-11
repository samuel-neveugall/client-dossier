# Phase 7: Manifests, Docs & Distribution - Research

**Researched:** 2026-10-11
**Domain:** Plugin packaging for Claude Code (`.claude-plugin/plugin.json` + self-hosted `marketplace.json`, `commands/`, `claude plugin eval`), Codex (`.codex-plugin/plugin.json` + `.agents/plugins/marketplace.json`, plugin-bundled hooks), bare Agent Skills installs (`skills` CLI), README / LICENSE / CHANGELOG, and a local-only `scripts/release.sh`
**Confidence:** HIGH for the install mechanics (every install path was run end to end in isolated configuration directories on Claude Code 2.1.296, codex-cli 0.150.1 and `skills` 1.7.2), the command/skill shadowing finding, the eval shape and cost, and the `release.sh` prototype; MEDIUM for Codex hook behaviour at run time (documented, not run: an isolated `CODEX_HOME` is not logged in) and for bare-skill behaviour on non-Claude harnesses

## Summary

All probes ran on throwaway copies (`git clone` of HEAD `f45f214` into the session scratchpad),
with `CLAUDE_CONFIG_DIR`, `CODEX_HOME` and `HOME` pointed at `mktemp -d` directories. Samuel's
own Claude Code and Codex configuration was never written. `claude plugin eval --trust-plugin`
did not persist a trust entry in `~/.claude.json` (checked). Paid model calls cost about
**0.18 USD in total**: nine Haiku `claude -p` probes (≈ 0.025 USD) and two one-run evals
(0.0102 USD on Haiku, 0.1411 USD on Sonnet).

**Blocking finding: a plugin command with the same name as a plugin skill shadows the skill,
for the model too.** DIST-04 and D-06 ask for `commands/dossier-init.md` … `commands/dossier-status.md`
next to `skills/dossier-init/` … `skills/dossier-status/`. Both resolve to `/client-dossier:dossier-draft`.
A live probe showed that the command wins in two places:
- When the user types the slash command, the command body runs.
- When the model calls the Skill tool with `client-dossier:dossier-draft`, the command body is
  returned instead of `SKILL.md`. A thin command saying "invoke the skill" then loops on
  itself: `Skill /client-dossier:dossier-draft is already loaded above; instructions unchanged.`

`SKILL.md` is never loaded. The six thin commands as specified would therefore **break the
five task skills in Claude Code**. Two controls confirm the cause. Without the same-named
command, the Skill tool returns `# dossier-draft`. A differently named command (`/client-dossier:draft`)
invokes the skill correctly. Plugin skills are already user-invocable as
`/client-dossier:<skill> <args>`, with the arguments passed through (probed). Recommendation:
ship **one** command, `commands/dossier-lint.md`, and amend DIST-04 / D-06 / spec §4 to say that
the five task skills *are* the slash commands. Add a free test that fails if any
`commands/<name>.md` matches a `skills/<name>/`. This is a manager decision (D-06 is tier 2,
reversible). Samuel should be informed. See Open Question 1.

**Claude Code install works headless, without authentication.** In an isolated config,
`claude plugin marketplace add <path>` then `claude plugin install client-dossier@client-dossier`
both exit 0. `claude plugin details` then lists 4 skills, 2 agents and 3 hooks. A `claude -p` in
that config reports the plugin in its `init` event and stops with `Not logged in`. The
install/load check is therefore free and needs no credential. Paid behaviour checks use the
existing `--plugin-dir` harness instead. `claude plugin validate .` with the full manifest leaves
exactly one warning, the root `CLAUDE.md` (D-03): exit 0, and `--strict` exits 1. Adding
`author` removes the other current warning.

Three things the planner must know:
1. With a `marketplace.json` present, `validate .` validates the marketplace and, through it,
   `plugin.json`. A broken `plugin.json` still fails it (probed).
2. A local-directory install **copies the working tree as-is** into the plugin cache: untracked
   files, `.claude/`, `.planning/` (6.4 MB), `tests/`, `evals/`. `export-ignore` is not honoured.
3. A `version` on the marketplace entry is ignored when `plugin.json` has one, and
   `validate`/`plugin tag` flag any mismatch. So the entry should carry no version.

**Codex.** `codex plugin marketplace add <path>` + `codex plugin add client-dossier@client-dossier`
work under an isolated `CODEX_HOME`, with no login. The plugin is cached at
`$CODEX_HOME/plugins/cache/client-dossier/client-dossier/<version>/`, again a full copy.
`codex debug prompt-input` (offline) lists the four skills as `client-dossier:dossier…` with
their `SKILL.md` paths. `.agents/plugins/marketplace.json` takes precedence over
`.claude-plugin/marketplace.json`, and Codex falls back to the latter when the former is
absent (probed). A `source.path` of `"./"` (the plugin at the marketplace root) is accepted.

Codex has the three hook events we use, with compatible I/O, and the existing `hooks/hooks.json`
is a valid Codex plugin hook file (CITED):
- `SessionStart` with `additionalContext`.
- `PreToolUse` with `permissionDecision: deny`.
- `Stop` with `decision: block` and `stop_hook_active`.

Codex loads `hooks/hooks.json` by default and sets `CLAUDE_PLUGIN_ROOT` "for compatibility". So
**the mirror is the same file**, with three caveats:
- Codex skips plugin hooks until the user trusts them in `/hooks`.
- Codex file edits go through `apply_patch`. Its `tool_input.command` holds patch text, and
  `guard-sources.py` ignores it (fail open). Only the Bash guard is effective on Codex until the
  guard learns the `*** Add/Update/Delete File:` / `*** Move to:` headers.
- OpenAI states that plugins with lifecycle hooks are not eligible for its public directory.

Codex does not consume plugin `agents/*.md`: its custom agents are TOML files under
`.codex/agents/`. The skills' inline fallback covers that. OpenAI now recommends a *root*
`plugin.json` ("Agent Plugins" schema), but `.codex-plugin/plugin.json` "remain[s] supported as a
compatibility fallback". DIST-02 names the latter, and it is what the official
`openai/plugins` examples still ship.

**Bare skills.** `npx skills@1.7.2 add <local path> --skill '*' --agent claude-code codex cursor --copy -y`
copied **whole skill folders**, private `scripts/` and `templates/` included, with executable
bits preserved. The copies went to `.claude/skills/` and `.agents/skills/`, plus a
`skills-lock.json`. Root `scripts/lint.py`, `hooks/` and `agents/` are not copied. Each skill
already degrades:
- `${CLAUDE_PLUGIN_ROOT}` is substituted only in plugin skills, so `test -f "${CLAUDE_PLUGIN_ROOT}/scripts/lint.py"`
  fails, and `dossier-draft` falls through to "Without the linter".
- `fact-extractor` and `doctrine-reviewer` are absent, so the inline procedures run.
- On non-Claude harnesses `${CLAUDE_SKILL_DIR}` is not substituted either, so the bundled
  `init.py` / `file_source.py` are treated as absent even though they were copied (ASSUMED for
  Cursor/Gemini/OpenCode; Codex shows the model the `SKILL.md` path only).

The `skills` package gets a **SUS (too-new)** legitimacy verdict, because its latest version was
published 2 days ago. It has 4.4 M weekly downloads and lives in the `vercel-labs/skills` repo.
Pin `skills@1.7.2` and gate the first run.

**Eval.** One case under `evals/routing/write-to-client/` passed with **0.0102 USD/run on Haiku and
0.1411 USD/run on Sonnet** (34 s). The case was:
- `prompt.md` + `case.yaml` with a `scaffold_script` that runs the plugin's own `init.py`;
- two `tool_used: Skill` graders: `dossier-draft` min 1, `dossier-ingest` min 0 max 0.

Each run starts in an empty workspace with no `CLAUDE.md` / `AGENTS.md` loaded. This is exactly
the description-only triggering DIST-06 wants. A seeded dossier needs `--scaffold`. Use
`--ablation none` for routing: the no-plugin arm can never invoke a plugin skill, so Δ carries
no information and only doubles the cost.

**Release.** A `release.sh` prototype was tested in a scratch repo (Pattern 6):
- the version is validated by Python `re.fullmatch` against the official semver.org regex;
- it refuses a dirty tree, an existing tag, diverged manifests, the same version, and
  injection strings (`1.0.0; touch PWNED`, `1.0.0$(touch PWNED)`: no file created);
- it bumps both manifests and any marketplace entry that carries a version;
- it turns `## [Unreleased]` into `## [Unreleased]` + `## [X] - YYYY-MM-DD`;
- it commits by pathspec and creates an **annotated** `vX` tag;
- a bare `origin` remote had no tag afterwards.

`claude plugin tag` exists. It creates `client-dossier--v1.0.0` (not D-01's `v1.0.0`) and its
dry run prints a `git push` line, so do not delegate to it.

**Primary recommendation:**
1. Write the manifests and marketplaces (plugin.json at `0.1.0`, no version on any marketplace
   entry).
2. Add `commands/dossier-lint.md` only, plus a collision test (DIST-04 amended).
3. Write `tests/test-manifests.sh`, `tests/test-commands.sh`, `tests/test-release.sh`,
   `tests/test-readme.sh` and `tests/test-evals-shape.sh`, all free and in `run.sh`.
4. Add `tests/dist/` install checks for Claude, Codex and `skills` (free, outside `run.sh`,
   isolated configs, recorded as evidence).
5. Add the `evals/` routing suite, with a paid recorded run on Sonnet: `--ablation none
   --runs 3`, budget stated.
6. Write README / LICENSE / CHANGELOG.
7. Write `scripts/release.sh`, run only in scratch until the milestone audit.
8. Optionally extend `guard-sources.py` with `apply_patch` parsing for the Codex mirror (D-05).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Asked to Samuel
- **D-01 (Q12) — version 1.0.0.** The first installable version is 1.0.0. The team creates the
  `v1.0.0` tag LOCALLY after the milestone audit; pushing the tag, publishing to any marketplace
  and making the repository public each need Samuel's explicit approval again.
  (arbitrage Samuel, AskUserQuestion session principale, 2026-10-10, option (a))
- **Phase 3 Q10 — git policy:** phase branch merged `--no-ff` into `main` and pushed with `main`
  after verification and UAT; no tags pushed, no publication.

#### Manager decisions (noted by Samuel 2026-10-10, reversible)
- **D-02 — MIT licence** in the name of "Samuel Neveu"; `author` added to both manifests.
- **D-03 — The root `CLAUDE.md` stays** (development instructions); the manifest gate is
  `claude plugin validate .` without `--strict`, and `CLAUDE.md`'s command list says why.
- **D-04 — Marketplace install tested from a local path** (the repository is private), in an
  isolated configuration that never touches Samuel's own Claude Code or Codex settings.

#### Manager decisions (tier 2, reversible)
- **D-05 — Codex.** `.codex-plugin/plugin.json` and `.agents/plugins/marketplace.json` follow the
  current Codex plugin format (researched, not guessed); install verified with the installed
  `codex` CLI under an isolated `CODEX_HOME`. The Phase 3 deferral (Codex mirror of the hooks)
  is settled by research: mirrored if Codex supports equivalent hooks, otherwise the README says
  the skills carry the same rules (CLAUDE.md doctrine).
- **D-06 — Commands.** Six thin files under `commands/`: five invoke their task skill with the
  arguments, `dossier-lint` runs `scripts/lint.py`; the `dossier` entry skill has no command.
- **D-07 — Eval.** `claude plugin eval` cases under `evals/`, at least the ambiguous "write to the
  client" → `dossier-draft` (not `dossier-ingest`), plus one positive trigger per task skill and
  the entry skill's step-aside outside a dossier; run by the team, results recorded, budget stated.
- **D-08 — README.** Installation for the four targets, what the bare-skills install loses
  (scripts, hooks, agents), the Bash guard's D-04 limits (Phase 3 D-17), versioning (semver,
  CHANGELOG, a tag per release), licence. English.
- **D-09 — `release.sh <version>`** bumps both manifests (and the marketplace entries if they
  carry a version), adds the CHANGELOG heading, creates a local annotated tag, refuses a dirty
  tree or a non-semver version, never pushes; tested in a scratch clone. The real 1.0.0 run
  happens after the milestone audit (D-01).
- **D-10 — Pre-publication checklist** (not executed in v1): scrub `/Users/…` paths and session
  ids from the scenario evidence before the repository is made public; recorded in STATE.

### Claude's Discretion
- Eval case layout, README structure, command argument hints.

### Deferred Ideas (OUT OF SCOPE)
- `07-CONTEXT.md` has no Deferred section. Its phase boundary states: "Publication (official
  marketplaces, public repository, pushed tags) is outside the phase: it needs Samuel's explicit
  approval."
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DIST-01 | `.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json` let a user install via `/plugin marketplace add` then `/plugin install` in Claude Code | Pattern 1 (manifest fields, entry without version, `"source": "./"`), probes C1-C4 (isolated add/install/details/validate), Pitfalls 2-4 |
| DIST-02 | `.codex-plugin/plugin.json` + `.agents/plugins/marketplace.json` provide the equivalent Codex CLI/app distribution path | Pattern 2 (Codex manifest + marketplace, `policy`, `category`), probes X1-X4 (isolated add/install/prompt-input, precedence), Pattern 8 (hooks mirror, `apply_patch`), Pitfalls 5-7 |
| DIST-03 | `skills/*/SKILL.md` alone installable on Agent-Skills harnesses via `skills` CLI or copy; behave without `scripts/`, hooks, agents; README says what is lost | Probe S1-S2 (what `skills add` copies), degradation table (Pattern 3), Package Legitimacy Audit (SUS), Pitfall 8 |
| DIST-04 | Six thin slash commands (amendment recommended: one) | Probes K1-K5 (shadowing, control, distinct name, direct skill slash, `${CLAUDE_PLUGIN_ROOT}` in a command), Pattern 4, Open Question 1, Pitfall 1 |
| DIST-05 | README for four targets + versioning + MIT + Bash guard D-04 limits | Pattern 7 (README checklist with the exact install commands probed), Phase 3 D-04/D-17 quoted |
| DIST-06 | `claude plugin eval` suites verify trigger descriptions ("write to the client" → `dossier-draft`, not `dossier-ingest`) | Pattern 5 (case layout, graders, scaffold, flags), probes E1-E2 (shape proven, cost), Pitfalls 9-11 |
| DIST-07 | `scripts/release.sh <version>` bumps both manifests, CHANGELOG heading, git tag | Pattern 6 (prototype tested: refusals, annotated tag, no push), Pitfalls 12-13 |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- The spec `docs/superpowers/specs/2026-09-16-client-dossier-design.md` is the single source of
  truth. When CLAUDE.md and the spec disagree, the spec wins and CLAUDE.md is updated. That means
  any change to DIST-04 / the §4 tree / §8 lands in the spec in the same commit.
- English everywhere in the plugin (skills, scripts, docs, README, commit messages).
- Folder and file names are fixed English names and never configurable. Protocol keywords
  (`Last updated:`, `Status:`, `To:`, `Subject:`, `Deadline:`, `Written by:`, `Rules:`, `draft`,
  `reviewed by`, `sent`) are never translated. The README quotes them as they are.
- Skills carry judgement, scripts carry mechanics, hooks carry reminders. Every rule a hook
  enforces is also stated in a skill. This is the basis of the "no hooks → skills carry the
  rules" README sentence (D-05).
- Scripts: Python 3.8 or newer, standard library only. `release.sh` is bash plus python3 (for
  JSON and the regex), with no `jq` or `node`.
- External dependencies have a stated fallback. `scripts/` absent → the skill says so and states
  the rule.
- Tests: bash plus python3 only. `bash tests/run.sh` runs every `tests/test-*.sh`. Paid runs
  (scenarios, `claude plugin eval`) are never part of `run.sh`.
- Commits are staged by pathspec, never `git add -A`, never `git stash`. The agent runs every
  check and paid run and records evidence. Samuel never runs them (memory: UAT delegated).
- Phase 4 lesson R4-M4: no `allowed-tools` in any skill frontmatter
  (`tests/test-skill-shape.sh`, cited from 06-RESEARCH). Apply the same rule to command
  frontmatter.
- Phase 4 lesson A4-F1: placeholders in bash blocks go inside single quotes, and a value holding
  `'` or a newline is refused. This applies to `commands/dossier-lint.md`'s path argument.
- `claude plugin validate .` is expected to exit 0 with known warnings, and `--strict` exits 1.
  CLAUDE.md currently lists two warnings (author, root CLAUDE.md). After `author` is added only
  the CLAUDE.md warning remains (probed), and CLAUDE.md's command list must be updated to say so
  (D-03).

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Plugin identity, version, author, licence (Claude) | `.claude-plugin/plugin.json` | marketplace entry (name + source only) | `plugin.json` wins on version; entry display fields override it, so keep them out [CITED: code.claude.com/docs/en/plugins/marketplace-reference] |
| Self-hosted catalog (Claude) | `.claude-plugin/marketplace.json` | — | Read by `claude plugin marketplace add <owner/repo or path>` |
| Plugin identity and catalog (Codex) | `.codex-plugin/plugin.json` + `.agents/plugins/marketplace.json` | `.claude-plugin/marketplace.json` (Codex fallback) | `.agents` takes precedence [VERIFIED: probe X4] |
| Skills discovery | `skills/*/SKILL.md` (default scan, both harnesses) | — | No manifest key needed on Claude; `"skills": "./skills/"` on Codex like the official examples |
| Agents | `agents/*.md` (Claude default scan) | Inline procedure in skills (Codex, bare) | Codex custom agents are TOML under `.codex/agents/`, not plugin-bundled [CITED: developers.openai.com/codex/subagents] |
| Hooks | `hooks/hooks.json` (one file, both harnesses) | Skills state every rule | Codex loads `hooks/hooks.json` by default, sets `CLAUDE_PLUGIN_ROOT` [CITED: developers.openai.com/codex/hooks] |
| User slash entry points | Skills themselves (`/client-dossier:dossier-<x>`) | `commands/dossier-lint.md` | Same-named commands shadow skills [VERIFIED: probes K1-K3] |
| Version bump, changelog, tag | `scripts/release.sh` (bash + python3) | — | Mechanics; D-09 |
| Trigger-description verification | `evals/` + `claude plugin eval` (paid) | `tests/test-evals-shape.sh` (free) | Paid runs never in `run.sh` |
| Install verification | `tests/dist/*.sh` (free, isolated config dirs) | `tests/test-manifests.sh` (free, static, in `run.sh`) | CLI-dependent and networked (`npx`) checks stay out of `run.sh` |
| User documentation | `README.md`, `LICENSE`, `CHANGELOG.md` | `CLAUDE.md` (dev only) | D-03, D-08 |

## Standard Stack

### Core
| Component | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Claude Code CLI | 2.1.296 | `plugin validate`, `plugin marketplace add`, `plugin install`, `plugin details`, `plugin eval` | All five subcommands exist and run headless [VERIFIED: `claude plugin --help`, probes C1-C4, E1-E2] |
| codex-cli | 0.150.1 (`/opt/homebrew/bin/codex`) | `codex plugin marketplace add`, `codex plugin add/list`, `codex debug prompt-input` | Offline, no login needed for install checks [VERIFIED: probes X1-X3] |
| bash + python3 | bash 3.2+ / python3 3.9.6 (system) and 3.14.6 | `release.sh`, tests | Project rule [VERIFIED: `python3 --version`] |
| git | 2.50.1 | annotated tags, porcelain status; `plugin eval` needs ≥ 2.31 | [VERIFIED: `git --version`; CITED: code.claude.com/docs/en/plugin-evals "Requirements"] |

### Supporting
| Component | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `skills` (npm, vercel-labs) | 1.7.2, pinned | Bare-skills install check (DIST-03) and the README's `npx skills add` line | `tests/dist/install-skills.sh` only, with `DISABLE_TELEMETRY=1 DO_NOT_TRACK=1`, after a human-verify checkpoint (SUS verdict) |
| `tests/lib.sh` | repo | `scratch_repo`, `assert_*`, `skip`, `finish`, `scrub_check` | Every new test file |
| `tests/scenarios/lib-scenario.sh` `scrub_check` | repo | Fails on `sk-ant-` / git email, warns on `/Users/` | Before copying eval JSON or install logs into `evidence/` |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `.codex-plugin/plugin.json` | Root `plugin.json` with `$schema: https://agent-plugins.org/schemas/1.0.0/plugin.schema.json` and `extensions.com.openai` | OpenAI's new recommended "portable" form, but DIST-02 names `.codex-plugin/`. The compat form is "remain[s] supported" and the official `openai/plugins` repo still ships it [CITED: developers.openai.com/codex/plugins/build]. A root `plugin.json` might also be read by Claude Code (the eval docs accept "a `plugin.json` or `.claude-plugin/plugin.json` manifest"), a two-manifest ambiguity worth avoiding [ASSUMED] |
| `scripts/release.sh` tagging with `git tag -a` | `claude plugin tag` | Built in and checks plugin.json vs entry, but the tag name is fixed to `client-dossier--v1.0.0` (D-01 says `v1.0.0`), it has a `--push` flag, its dry run prints a push command, it needs `claude` on PATH, and it knows nothing about Codex [VERIFIED: probe R2] |
| Six same-named commands | One `dossier-lint` command | See Pitfall 1. The five task skills are already slash commands |
| `claude plugin eval` with baseline arm | `--ablation none` | The baseline can never call a plugin skill, so routing Δ is meaningless and costs 2× [CITED: plugin-evals "Score against the no-plugin baseline"] |
| Codex marketplace `source` object | plain string `"./"` | Both accepted for local entries [CITED: codex/plugins/build "Marketplace metadata"]; the object form matches the official catalog |

**Installation:** nothing is installed into the repository. `skills@1.7.2` runs through
`npm exec --yes --package=skills@1.7.2 -- skills …` in `tests/dist/` only. Note: in this
environment a bare `npx -y skills@1.7.2` was rewritten by the rtk hook into `npm skills@1.7.2`
and failed, while `npm exec --yes --package=… --` works [VERIFIED: probe S1].

## Package Legitimacy Audit

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| `skills` | npm | created 2016-10-06; v1.7.2 published 2026-10-09 | 4,433,473 / week | github.com/vercel-labs/skills | [SUS] (`too-new`: latest version 2 days old) | Flagged: planner must add a checkpoint before the first `tests/dist/install-skills.sh` run. Pin `1.7.2`, never `latest` |

Seam output: `{"name":"skills","verdict":"SUS","signals":{"exists":true,"publishedAt":"2026-10-09T16:49:31.475Z","weeklyDownloads":4433473,"repoUrl":"git+https://github.com/vercel-labs/skills.git","deprecated":false,"postinstall":null},"reasons":["too-new"]}`.
No `postinstall` script. The package name comes from spec §8 and the vercel-labs README, not
from Context7, so it stays **`skills` [WARNING: flagged as suspicious — verify before using.]**,
not `[VERIFIED: npm registry]`.

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** `skills` (checkpoint:human-verify before the first install run)

## Architecture Patterns

### System Architecture Diagram

```
                         ┌──────────────── this repository (marketplace root = plugin root) ────────────────┐
user                     │ .claude-plugin/plugin.json ─┐   .codex-plugin/plugin.json ─┐                       │
 │                       │ .claude-plugin/marketplace.json  .agents/plugins/marketplace.json                 │
 │                       │ skills/  agents/  hooks/hooks.json  commands/dossier-lint.md  scripts/lint.py      │
 │                       └──────────────────────────────────────────────────────────────────────────────────┘
 ├─ Claude Code: /plugin marketplace add samuel-neveugall/client-dossier ─► reads .claude-plugin/marketplace.json
 │      └─ /plugin install client-dossier@client-dossier ─► entry "source": "./" ─► copy repo → plugins/cache/…/<version>/
 │             └─ loads skills/ (6) + agents/ (2) + hooks/hooks.json (3) + commands/ (1); ${CLAUDE_PLUGIN_ROOT} = cache dir
 ├─ Codex: codex plugin marketplace add … ─► .agents/plugins/marketplace.json (else .claude-plugin/marketplace.json)
 │      └─ codex plugin add client-dossier@client-dossier ─► copy → $CODEX_HOME/plugins/cache/…/<version>/
 │             └─ skills listed as client-dossier:<name>; hooks/hooks.json after /hooks trust; agents/ ignored
 ├─ Agent-Skills harness: npx skills add … ─► copies skills/<name>/ whole (scripts, templates) ─► .agents/skills or .claude/skills
 │             └─ no lint.py, no hooks, no agents ─► skills' "Without the linter" / inline extraction / rules-in-prose
 └─ No plugin: dossier-init wrote AGENTS.md pointer ─► any harness reads the protocol

maintainer: scripts/release.sh X.Y.Z ─► validate semver ─► clean tree? tag absent? manifests agree? ─►
            bump both manifests (+ entries with a version) ─► CHANGELOG "## [X.Y.Z] - date" ─► commit (pathspec) ─► git tag -a vX.Y.Z
            (never push; publication = Samuel's explicit approval, D-01)

verification: tests/run.sh (static, free) │ tests/dist/*.sh (isolated CLAUDE_CONFIG_DIR / CODEX_HOME / HOME, free)
              │ claude plugin eval . --scaffold --ablation none (paid, recorded under evidence/)
```

### Recommended Project Structure
```
.claude-plugin/plugin.json          # completed (author, homepage, repository, license, keywords); version stays 0.1.0 until release.sh 1.0.0
.claude-plugin/marketplace.json     # new: name, owner, description, one entry {name, source "./"}; no version, no display fields
.codex-plugin/plugin.json           # new: same identity + "skills": "./skills/" + interface
.agents/plugins/marketplace.json    # new: name, interface.displayName, one entry {name, source {local, "./"}, policy, category}
commands/dossier-lint.md            # new (the only command; see Open Question 1)
evals/routing/<case>/{prompt.md,case.yaml,scaffold.sh,graders/*.md}   # new
evals/results/                      # gitignored (.gitignore line "evals/results/")
scripts/release.sh                  # new, executable
README.md  LICENSE  CHANGELOG.md    # new
tests/test-manifests.sh tests/test-commands.sh tests/test-release.sh tests/test-readme.sh tests/test-evals-shape.sh   # new, in run.sh
tests/dist/install-claude.sh tests/dist/install-codex.sh tests/dist/install-skills.sh  # new, outside run.sh (like tests/scenarios/)
```
Optional (D-05 full mirror): `hooks/guard-sources.py` gains `apply_patch` parsing, plus cases
in `tests/test-hook-guard-sources.sh`.

### Pattern 1: Claude Code manifest and self-hosted marketplace (DIST-01)

The current file has three keys [VERIFIED: .claude-plugin/plugin.json:1-5]:
`"name": "client-dossier"`, `"description": "Turns a git repository into the memory and workbench of a relationship with an external party: immutable sources, a living dossier where every fact is dated and sourced, and an outbound folder where only a human sends a doctrine-checked draft."`, `"version": "0.1.0"`.

Target (validated in a scratch clone, only the root-`CLAUDE.md` warning left) [VERIFIED: probe C4]:
```json
{
  "name": "client-dossier",
  "version": "0.1.0",
  "description": "Turns a git repository into the memory and workbench of a relationship with an external party: immutable sources, a living dossier where every fact is dated and sourced, and an outbound folder where only a human sends a doctrine-checked draft.",
  "author": {
    "name": "Samuel Neveu"
  },
  "homepage": "https://github.com/samuel-neveugall/client-dossier",
  "repository": "https://github.com/samuel-neveugall/client-dossier",
  "license": "MIT",
  "keywords": [
    "client",
    "dossier",
    "relationship",
    "memory",
    "outbound",
    "transcript"
  ]
}
```
Field rules [CITED: code.claude.com/docs/en/plugins-reference "Fields"]:
- `name` is the only required key.
- `author` is an object with a required `name` and optional `email`/`url`.
- `homepage` "Must parse as a URL, or the plugin fails to load".
- `repository` is not validated.
- `license` is an SPDX id.
- `keywords` is an array.
- Unknown top-level keys are stripped with a warning.
- No `skills`/`agents`/`commands`/`hooks` keys are needed: the defaults `skills/`, `agents/`,
  `commands/`, `hooks/hooks.json` are scanned. Setting `commands` or `agents` would *replace* the
  default scan.

The repo owner `samuel-neveugall` comes from `git remote -v`. Leave the email out: commits use
the GitHub noreply address, and the manifest is public once published.

Marketplace (validated; add + install headless OK) [VERIFIED: probes C1-C3]:
```json
{
  "name": "client-dossier",
  "owner": {
    "name": "Samuel Neveu"
  },
  "description": "Self-hosted marketplace for the client-dossier plugin.",
  "plugins": [
    {
      "name": "client-dossier",
      "source": "./"
    }
  ]
}
```
- `"./"` is the marketplace root itself. A relative path "Must start with `./`", and `"."` also
  means the root [CITED: marketplace-reference "Plugin sources"].
- Without a `description` at the top level, `validate` warns.
- **No `version` and no display fields on the entry.**
  - Entry display fields (`description`, `author`, `keywords`, …) override `plugin.json`. The probe
    entry's shorter description replaced the manifest's in `claude plugin details`.
  - A relative-path entry shows `plugin.json`'s values even before install.
  - `version` on the entry is ignored when `plugin.json` has one. A mismatch produces
    `Entry declares version "x" but … plugin.json says "y". At install time, plugin.json wins`,
    and `claude plugin tag` refuses [VERIFIED: probe R2].
- The marketplace name `client-dossier` is not reserved, and spec §8's
  `client-dossier@client-dossier` works.
- Users pin with `claude plugin marketplace add samuel-neveugall/client-dossier@v1.0.0` (`owner/repo@ref`
  form) [CITED: marketplace-reference "Marketplace sources"].

**Isolated install check (free, no login)**:
```bash
cfg="$(mktemp -d)"
CLAUDE_CONFIG_DIR="$cfg" claude plugin marketplace add "$REPO_ROOT"          # exit 0
CLAUDE_CONFIG_DIR="$cfg" claude plugin install client-dossier@client-dossier # exit 0
CLAUDE_CONFIG_DIR="$cfg" claude plugin list                                  # Version, "Read from: <path>", ✔ enabled
CLAUDE_CONFIG_DIR="$cfg" claude plugin details client-dossier@client-dossier # Skills (n) Agents (2) Hooks (3)
```
Observed:
- `settings.json` gains `extraKnownMarketplaces.client-dossier.source = {"source":"directory","path":…}`
  and `enabledPlugins`.
- A copy lands in `$cfg/plugins/cache/client-dossier/client-dossier/<version>/`, and
  `plugin list` says `Read from: <the clone>` (local-path marketplaces load in place).
- `claude -p` in that config emits the `init` event with `plugins`, `skills`, `agents` and
  `slash_commands`, then `Not logged in · Please run /login` at cost 0.

So the load check is free. Behaviour checks need the authenticated `--plugin-dir` harness.

### Pattern 2: Codex manifest and marketplace (DIST-02)

Validated by install under isolated `CODEX_HOME` + `HOME` [VERIFIED: probes X1-X3]. Shape
follows the official `openai/plugins` examples (`build-web-apps/.codex-plugin/plugin.json` has
`name, version, description, author, homepage, repository, license, keywords, "skills": "./skills/", interface{…}`)
[VERIFIED: raw.githubusercontent.com/openai/plugins/main/plugins/build-web-apps/.codex-plugin/plugin.json]:
```json
{
  "name": "client-dossier",
  "version": "0.1.0",
  "description": "Turns a git repository into the memory and workbench of a relationship with an external party: immutable sources, a living dossier where every fact is dated and sourced, and an outbound folder where only a human sends a doctrine-checked draft.",
  "author": {
    "name": "Samuel Neveu"
  },
  "homepage": "https://github.com/samuel-neveugall/client-dossier",
  "repository": "https://github.com/samuel-neveugall/client-dossier",
  "license": "MIT",
  "keywords": [
    "client",
    "dossier",
    "relationship",
    "memory",
    "outbound",
    "transcript"
  ],
  "skills": "./skills/",
  "interface": {
    "displayName": "Client Dossier",
    "shortDescription": "The memory of a relationship with an external party, kept in git",
    "developerName": "Samuel Neveu",
    "category": "Productivity",
    "capabilities": ["Read", "Write"]
  }
}
```
```json
{
  "name": "client-dossier",
  "interface": {
    "displayName": "client-dossier"
  },
  "plugins": [
    {
      "name": "client-dossier",
      "source": {
        "source": "local",
        "path": "./"
      },
      "policy": {
        "installation": "AVAILABLE",
        "authentication": "ON_INSTALL"
      },
      "category": "Productivity"
    }
  ]
}
```
- "Always include `policy.installation`, `policy.authentication`, and `category` on each plugin
  entry" [CITED: developers.openai.com/codex/plugins/build "Marketplace metadata"].
- The entry carries no version. The cache directory takes the manifest version: probe X2
  installed to `…/cache/client-dossier/client-dossier/1.0.0/` with a 1.0.0 manifest.
- `hooks` is left out of the manifest on purpose. Codex reads `hooks/hooks.json` by default,
  and a manifest `hooks` key "uses those manifest entries instead of the default"
  [CITED: developers.openai.com/codex/hooks "Plugin-bundled hooks"].

**Isolated install check (free, no login; `codex login status` → `Not logged in`)**:
```bash
ch="$(mktemp -d)"; h="$(mktemp -d)"
CODEX_HOME="$ch" HOME="$h" codex plugin marketplace add "$REPO_ROOT"                 # Added marketplace `client-dossier`
CODEX_HOME="$ch" HOME="$h" codex plugin add client-dossier@client-dossier            # Installed plugin root: …/cache/…/<version>
CODEX_HOME="$ch" HOME="$h" codex plugin list --json                                  # installed/enabled
(cd "$(mktemp -d)" && CODEX_HOME="$ch" HOME="$h" codex debug prompt-input hi) \
  | grep -o 'client-dossier:[a-z-]*:' | sort -u                                      # one line per skill
```
`$CODEX_HOME/config.toml` gains `[marketplaces.client-dossier] source_type = "local"` and
`[plugins."client-dossier@client-dossier"] enabled = true` [VERIFIED: probe X2].

### Pattern 3: What each install loses, and how each skill already degrades (DIST-03, README)

| Component | Claude plugin | Codex plugin | Bare skills (`skills` CLI / copy) | AGENTS.md only |
|-----------|---------------|--------------|-----------------------------------|----------------|
| 6 skills | yes, `client-dossier:<name>` | yes, `client-dossier:<name>` [VERIFIED: X3] | yes, un-namespaced, whole folder copied [VERIFIED: S2] | no; the pointer tells the agent the protocol |
| Private scripts (`init.py`, `file_source.py`, `extract-text.sh`, `status.py`) | yes (`${CLAUDE_SKILL_DIR}` substituted) | copied, but `${CLAUDE_SKILL_DIR}` is not substituted → `test -x` fails → fallback [ASSUMED] | copied with exec bits; works in Claude Code `.claude/skills/` (substituted), falls back elsewhere [ASSUMED for non-Claude] | no |
| `scripts/lint.py` | yes | copied (whole repo) but referenced through `${CLAUDE_PLUGIN_ROOT}` in skill text, not substituted → "Without the linter" [ASSUMED] | **no** → "Without the linter" (E1-E5 stated) [VERIFIED: skills/dossier-draft/SKILL.md "Without the linter"] | no |
| Hooks (SessionStart, guard, Stop) | yes | yes after `/hooks` trust; guard covers Bash only unless `apply_patch` is parsed | **no** → rules are in the `dossier` skill | no |
| Agents (`fact-extractor`, `doctrine-reviewer`) | yes | **no** (Codex agents are TOML in `.codex/agents/`) → inline procedure | **no** → inline procedure ("No subagent here: …") | no |
| `commands/dossier-lint.md` | yes | no | no | no |

`${CLAUDE_PLUGIN_ROOT}` "Substituted only in plugin skills", and the variables "aren't present
in the environment of commands Claude runs through the Bash tool"
[CITED: code.claude.com/docs/en/skills; code.claude.com/docs/en/plugins-reference
"Environment variables"]. So in a bare install the literal expands to empty, and
`test -f "/scripts/lint.py"` fails, which is the intended route into the fallback.

Recommendation (optional, low cost): add one sentence near each `${CLAUDE_SKILL_DIR}` use. "If
`${CLAUDE_SKILL_DIR}` was not replaced by a path, it is the folder that holds this SKILL.md."
That lets Codex and Agent-Skills harnesses use the copied scripts instead of falling back. This
is a skill-text change in Phase 7, so the skill tests must be re-run.

### Pattern 4: Commands (DIST-04)

**Probe results** (Haiku, `--plugin-dir` scratch clone):

| Probe | Setup | Observed |
|-------|-------|----------|
| K1 | `commands/dossier-draft.md` body "Reply with exactly COMMANDWINS"; user types `/client-dossier:dossier-draft x` | `'COMMANDWINS'`: **command wins over the same-named skill** |
| K2 | thin command "Invoke the `client-dossier:dossier-draft` skill with the Skill tool…"; model calls Skill tool | tool result = the **command body**, then `Skill /client-dossier:dossier-draft is already loaded above; instructions unchanged.`; `SKILL.md` never loaded |
| K3 (control) | same, command renamed `draft.md` | Skill tool returns `# dossier-draft` (SKILL.md) |
| K4 | `/client-dossier:draft ZZARG …` (distinct name) | model calls `Skill client-dossier:dossier-draft`, SKILL.md loaded |
| K5 | no command; user types `/client-dossier:dossier-ingest ZZARG2 file this mail` | SKILL.md injected directly, the model starts the ingest procedure (searches `dossier.yaml`, `ls` of the substituted `${CLAUDE_SKILL_DIR}/scripts`) |
| K6 | `commands/dossier-lint.md` with `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/lint.py"` | substituted to the absolute plugin path; lint ran, `EXIT CODE: 2` relayed |

`slash_commands` in the `init` event listed each name once (`client-dossier:dossier-draft`
etc.) whether a command, a skill or both existed. `claude plugin validate` does not flag the
collision.

Docs agree on direction: "Custom commands have been merged into skills… Prefer a skill for new
work", and commands are "Flat Markdown command files. Prefer `skills/` for new plugins"
[CITED: code.claude.com/docs/en/skills; plugins-reference "Standard layout"].

**Recommended `commands/dossier-lint.md`** (no `allowed-tools`, single-quoted path, A4-F1):
```markdown
---
description: Lint the nearest client dossier with scripts/lint.py (read-only) and report every finding
argument-hint: "[path inside the dossier]"
---

Run the client-dossier linter and report its output and exit code verbatim. Fix nothing.

If an argument was given, it is a path: refuse it if it contains a single quote or a newline.
Otherwise run, with the path inside single quotes (or `.` when none was given):

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/lint.py" '<path>'
```

Exit codes: 0 no error (warnings allowed), 1 at least one error, 2 no `dossier.yaml` found
upward or unreadable, 3 internal error. The path argument was: $ARGUMENTS
```
`description` and `argument-hint` are the documented command/skill frontmatter fields
[CITED: code.claude.com/docs/en/skills "Frontmatter reference"]. Exit codes are quoted from
CLAUDE.md "Commands": "Exit codes: 0 no error (warnings allowed), 1 at least one error, 2 no
`dossier.yaml` found upward or unreadable, 3 internal error."

**Guard test (free):** for every `commands/*.md`, the stem must not equal any `skills/*/`
directory name. With option (a), `commands/` holds exactly `dossier-lint.md`.

### Pattern 5: Eval suite (DIST-06)

Layout and grader schema [CITED: code.claude.com/docs/en/plugin-evals "Eval suite reference"]:
- A case is a directory under `evals/` with `prompt.md` (frontmatter: `description, tags, max_turns,
  timeout_seconds, allowed_tools, model, runs, env…`; an unknown key is an error), an optional
  `case.yaml` (`schema_version: "1.1"`, `name`, `context.scaffold_script|history_file|add_dirs`),
  and `graders/*.md` (one grader per file).
- Grader types: `regex`, `tool_used`, `tool_order`, `file_exists`, `llm`, `baseline`.
- Nesting under a non-case directory groups cases, e.g. `evals/routing/<case>/`.

**Proven case (E1 Haiku 0.0102 USD / 25 s, E2 Sonnet 0.1411 USD / 34 s, both score 1.0)**:
```
evals/routing/write-to-client/prompt.md
---
description: Ambiguous "write to the client" must route to dossier-draft, never dossier-ingest
tags: [routing, draft]
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Glob, Grep, Skill]
---

Write to the client to say we can deliver the audit on 2026-11-02 instead of 2026-10-28.
```
```yaml
# evals/routing/write-to-client/case.yaml
schema_version: "1.1"
name: write-to-client
context:
  scaffold_script: scaffold.sh
```
```bash
#!/bin/bash
# evals/routing/write-to-client/scaffold.sh — seed a minimal dossier with the plugin's own init.py
set -eu
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../../.." && pwd)"
git init -q .
python3 "$root/skills/dossier-init/scripts/init.py" --target . --language en \
  --counterpart 'Jane Doe|Head of IT|jane@example.com' --confidential-name 'Globex' >/dev/null
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -qm seed
```
```markdown
<!-- graders/draft-fired.md -->
---
type: tool_used
tool: Skill
input_match: '"skill"\s*:\s*"(?:[\w-]+:)?dossier-draft"'
---
<!-- graders/ingest-not-fired.md -->
---
type: tool_used
tool: Skill
input_match: '"skill"\s*:\s*"(?:[\w-]+:)?dossier-ingest"'
min: 0
max: 0
---
```
The `init.py` flags `--target --language --counterpart NAME|ROLE|CONTACT --confidential-name`
come from `python3 skills/dossier-init/scripts/init.py --help` [VERIFIED: probe E0].

**Run command (recorded run):**
```bash
claude plugin eval . --scaffold --trust-plugin --ablation none --model sonnet --runs 3 \
  --no-publish --max-cost-usd 4 --json .planning/phases/07-manifests-docs-distribution/evidence/eval-routing.json
```
(target `.` first, then the list-taking flags; `--json` with a `.json` path.)

**Case set for D-07** (each: scaffold as above unless stated; allowed_tools `[Read, Glob, Grep, Skill]`;
no Write is granted, so runs route and stop. That is cheap and side-effect free.)

| Case | Prompt (user phrasing, never the skill name) | Graders |
|------|------|---------|
| `write-to-client` | the proven one | `dossier-draft` ≥1; `dossier-ingest` =0 |
| `init-new-client` | scaffold = `git init` only; "Set up a dossier in this repository for our new client Acme, contact Jane Doe." | `dossier-init` ≥1 |
| `ingest-transcript` | scaffold also writes `call-2026-10-10.txt` at the workspace root; "Here is the transcript of today's call with Jane in call-2026-10-10.txt. What did we learn?" | `dossier-ingest` ≥1; `dossier-draft` =0 |
| `draft-reply` | "Draft a short reply to Jane confirming Tuesday's meeting." | `dossier-draft` ≥1 |
| `call-prepare` | "Prepare tomorrow's call with Jane." | `dossier-call` ≥1 (needs Phase 6) |
| `deal-status` | "Where are we with this deal?" | `dossier-status` ≥1 (needs Phase 6); `dossier-draft` =0 |
| `outside-dossier` | no scaffold (empty workspace); "Write a short thank-you note to our client for yesterday's workshop." | `regex` on `last_message` `/dossier-init/`; `regex` `/dossier\.yaml\|no dossier/` flags `i` (entry skill steps aside, suggests init) |
| `unrelated` (optional false-positive guard) | "Write a Python function that reverses a string." | `tool_used Skill` with `input_match: 'dossier'` min 0 max 0 |

Budget: about 0.14 USD × 7-8 cases × 3 runs ≈ **3-3.5 USD on Sonnet** with `--ablation none`,
or ≈ 0.25 USD on Haiku for iteration. The measured per-run figure is E2. Multiplying it out is
an estimate, because cases differ [ASSUMED]. Iterate with `--case <name> --runs 1 --model haiku`.

### Pattern 6: `scripts/release.sh` (DIST-07), prototype tested

Tested behaviour (scratch repo with a bare `origin`) [VERIFIED: probe R1]:

| Input / state | Result |
|---------------|--------|
| `1.0`, `v1.0.0`, `01.0.0`, `1.0.0; touch PWNED`, `1.0.0$(touch PWNED)` | exit 1, no `PWNED` file |
| dirty tree (untracked file) | `release: working tree is not clean…`, exit 1 |
| `1.0.0` on clean 0.1.0 tree | both manifests `"version": "1.0.0"`, CHANGELOG `## [Unreleased]` + blank + `## [1.0.0] - 2026-10-11`, commit, `git cat-file -t v1.0.0` = `tag`, tree clean, bare remote has 0 tags |
| `1.0.0` again | `tag v1.0.0 already exists`, exit 1 |
| existing `v1.1.0` tag | refused |
| manifests disagree (1.0.0 vs 0.9.0) | `the two manifests disagree`, exit 1, tree restored clean |

Core of the prototype (the full script is ~60 lines; keep `set -euo pipefail`, pass the version
to Python through `argv`, never interpolate it into code):
```bash
python3 - "$version" <<'PY' || die "not a semver version: $1"
import re, sys
SEMVER = r"(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?"
sys.exit(0 if re.fullmatch(SEMVER, sys.argv[1]) else 1)
PY
[ -z "$(git status --porcelain --untracked-files=normal)" ] || die "working tree is not clean; commit first"
git rev-parse -q --verify "refs/tags/v$version" >/dev/null && die "tag v$version already exists"
# python3: load both manifests, refuse if they differ or already equal $version, set version,
# set plugins[].version only where an entry already has one, json.dump(indent=2, ensure_ascii=False)+"\n",
# re.subn(r"^## \[Unreleased\][ \t]*$", "## [Unreleased]\n\n## [X] - DATE", count=1, flags=re.M) — refuse if n != 1
git add -- "${files[@]}"
git commit -q -m "chore(release): v$version" -- "${files[@]}"
git tag -a "v$version" -m "client-dossier $version"
echo "release: tagged v$version locally. Nothing was pushed."
```
The regex is the official one [VERIFIED: semver.org FAQ, extracted from the page]. Keep a
Changelog heading format `## [1.1.1] - 2023-03-05`, an `Unreleased` section at the top, and the
types `Added, Changed, Deprecated, Removed, Fixed, Security`
[CITED: keepachangelog.com/en/1.1.0/]. Write the manifests in `json.dumps(indent=2)` form from
the start, so the release round trip changes only the version line. Add a test for that.

### Pattern 7: README / LICENSE / CHANGELOG checklist (DIST-05, D-08)

README sections (English), each with a `test-readme.sh` grep:
1. What it is: one paragraph from spec §1, with "never sends anything, never renders documents".
2. The dossier layout (`dossier.yaml  sources/  dossier/  knowledge/  outbound/`) and the
   untranslated protocol keywords.
3. **Install: Claude Code.** `/plugin marketplace add samuel-neveugall/client-dossier` then
   `/plugin install client-dossier@client-dossier`; shell equivalents
   `claude plugin marketplace add …` / `claude plugin install …`; pin a release with
   `…/client-dossier@v1.0.0`. Note that a local clone path also works.
4. **Install: Codex.** `codex plugin marketplace add samuel-neveugall/client-dossier` (`--ref v1.0.0`
   to pin) then `codex plugin add client-dossier@client-dossier`. Hooks must be trusted in `/hooks`.
   On Codex the two agents are not used: the skills run their inline procedure.
5. **Install: Agent-Skills harnesses** (Cursor, Copilot CLI, Gemini CLI, OpenCode, others).
   `npx skills add samuel-neveugall/client-dossier` (or copy `skills/` into the harness's skills
   folder). Then **what this install loses**: `scripts/lint.py` (the skills state the rules E1-E5
   instead), the three hooks (the `dossier` skill states every rule they enforce), the two agents
   (inline extraction and review), the `dossier-lint` command.
6. **No plugin at all.** `dossier-init` writes an `AGENTS.md` pointer, and any harness that reads
   `AGENTS.md` follows the protocol.
7. Usage: the six skills (`/client-dossier:dossier-init` … `dossier-status`), `/client-dossier:dossier-lint`,
   `python3 scripts/lint.py`, and the five pressure behaviours in one line each.
8. **Limits of the Bash guard** (Phase 3 D-04 / D-17), in prose, with the class quoted. The guard
   denies the visible modifications listed in D-04: `sed -i`, `perl -i`, `rm`, `mv` from
   `sources/`, `>`/`>>`/`tee` onto a path under `sources/`, `truncate`, plus the D-17 verbs and
   wrappers. It is a heuristic that does **not** catch `eval`, interpreters (`python -c`, …),
   command substitutions, variables or loops. "the skill's rule is the real boundary". On Codex,
   file edits through `apply_patch` are not covered unless Pattern 8 lands.
9. Requirements: python3 ≥ 3.8, git; optional `pdftotext` (missing → PDF filed, extraction
   skipped).
10. Versioning: semver, `CHANGELOG.md`, one git tag `vX.Y.Z` per release, both manifests always
    at the same version (`scripts/release.sh`).
11. Licence: MIT, © Samuel Neveu (link `LICENSE`).
12. Privacy: everything stays in your git repository; nothing is sent.

`LICENSE`: the standard MIT text, `Copyright (c) 2026 Samuel Neveu` [ASSUMED: year = first
release year]. `CHANGELOG.md`: `# Changelog`, a one-line pointer to Keep a Changelog and semver,
then `## [Unreleased]` with `### Added` listing the v1 surface (six skills, two agents, three
hooks, linter, templates en/fr, manifests). No `## [1.0.0]` heading yet: `release.sh 1.0.0`
creates it after the audit. No compare-link footer while the repository is private
[ASSUMED: links optional].

D-04 / D-17 source text [VERIFIED: .planning/phases/03-protocol-skill-hooks/03-CONTEXT.md D-04,
D-17], quoted: D-04 "in-place edits (`sed -i`, `perl -i`), `rm`, `mv` from `sources/`, output
redirection (`>`, `>>`) or `tee` onto a path under `sources/`, `truncate`. It must not block
copying a **new** file into `sources/`"; D-17 "explicitly accept the D-04 class (eval,
interpreters, substitutions, variables, loops) as documented v1 debt in the skill and the README
(README lands in Phase 7)."

### Pattern 8: Codex hooks mirror (D-05)

Current file, quoted [VERIFIED: hooks/hooks.json:8,16,20,31]:
- `"command": "python3 \"${CLAUDE_PLUGIN_ROOT}/hooks/session-start.py\""`
- `"matcher": "Write|Edit|MultiEdit|NotebookEdit|Bash"`
- `"command": "python3 \"${CLAUDE_PLUGIN_ROOT}/hooks/guard-sources.py\""`
- `"command": "python3 \"${CLAUDE_PLUGIN_ROOT}/hooks/stop-check.py\""`

Codex compatibility, event by event [CITED: developers.openai.com/codex/hooks]:

| Our hook | Codex | Compatible? |
|----------|-------|-------------|
| SessionStart → JSON `hookSpecificOutput.additionalContext` | same shape; "That `additionalContext` text is added as extra developer context" | yes |
| PreToolUse Bash → `permissionDecision: "deny"` | same shape; `Bash` uses `tool_input.command` | yes |
| PreToolUse Write/Edit/MultiEdit/NotebookEdit → reads `tool_input.file_path`/`notebook_path` | edits go through `apply_patch`; "`matcher` values can use `apply_patch`, `Edit`, or `Write`; hook input still reports `tool_name: "apply_patch"`"; `tool_input.command` holds the patch | **no**: `WRITE_TOOLS = ("Write", "Edit", "MultiEdit", "NotebookEdit")` [VERIFIED: hooks/guard-sources.py:43] has no `apply_patch`, so the guard falls through and allows (fail open) |
| Stop → `{"decision": "block", "reason": …}`, passes on `stop_hook_active` | same fields; block "creates a new continuation prompt… using your `reason`"; "Stop expects JSON on stdout when it exits 0" (empty output = success) | yes |
| `${CLAUDE_PLUGIN_ROOT}` in `command` | "Codex also sets `CLAUDE_PLUGIN_ROOT` and `CLAUDE_PLUGIN_DATA` for compatibility" (env, expanded by the shell) | yes [ASSUMED: shell expansion of the env var; not run] |
| Trust | "Codex skips plugin-bundled hooks until you review and trust the current hook definition" (`/hooks`) | README step |

Mirror option (recommended if D-05 is read as "full mirror"): add an `apply_patch` branch to
`guard-sources.py`. It takes every path after `*** Add File: `, `*** Update File: `,
`*** Delete File: ` and `*** Move to: ` in `tool_input.command`, resolves each against `cwd`,
and applies `sources_target`. The grammar is
`add_hunk: "*** Add File: " filename LF add_line+`, `delete_hunk: "*** Delete File: " filename LF`,
`update_hunk: "*** Update File: " filename LF change_move? change?`,
`change_move: "*** Move to: " filename LF`
[VERIFIED: github.com/openai/codex codex-rs/apply-patch/src/parser.rs:7-18]. The matcher stays
unchanged, since Codex maps `apply_patch` onto `Edit|Write`, and `tests/test-hooks-config.sh:17`
pins `PRETOOLUSE_MATCHER='Write|Edit|MultiEdit|NotebookEdit|Bash'`. The deny message stays
`MESSAGE = "sources are immutable; file a correction in the dossier instead"`
[VERIFIED: hooks/guard-sources.py:41]. Without this branch the README must say that on Codex
only the Bash guard and the skill rule protect `sources/`.

### Anti-Patterns to Avoid
- **A command named like a skill.** It silently replaces the skill for the user and the model
  (Pitfall 1).
- **`version` on a marketplace entry.** It is ignored and only creates a mismatch warning.
- **Display fields on the marketplace entry.** They override `plugin.json` and drift.
- **`release.sh` that pushes, or calls `claude plugin tag --push`.** D-01 forbids it.
- **Building the eval workspace with `add_dirs`.** Those are read-only. Use `scaffold_script`
  + `--scaffold` instead.
- **Granting `Write`/`Bash` in routing evals.** It adds cost and side effects, and routing only
  needs `Skill`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Manifest schema checks | a custom JSON-schema validator | `claude plugin validate .` (+ `--json`) and a tiny python3 equality test | Authoritative, covers marketplace → plugin.json, paths, reserved names [CITED: plugins-reference] |
| Semver check | a hand-written regex / bash `=~` | the semver.org regex via `python3 re.fullmatch` | ERE has no `\d` or `(?:`; the official regex is tested |
| Trigger testing harness | another `claude -p` loop for routing | `claude plugin eval` (`tool_used: Skill` graders, isolation, cost report) | Isolated temp home, no CLAUDE.md, per-run cost, JSON result [CITED: plugin-evals] |
| Install verification | parsing settings by hand | `claude plugin list/details`, `codex plugin list --json`, `codex debug prompt-input` | Free, offline, observed output |
| Bare-skills installer | a copy script | `skills` CLI (pinned) or a plain `cp -R skills/<name>` documented in README | Agent-path table maintained upstream |
| Changelog format | an ad-hoc format | Keep a Changelog 1.1.0 | Recognised, simple heading regex |

**Key insight:** every distribution surface already has an official CLI that validates and
installs offline. The phase's own code is the glue (`release.sh`) and the tests that pin
the decisions (no command/skill collision, equal versions, no push).

## Common Pitfalls

### Pitfall 1: Same-named command shadows the skill
**What goes wrong:** with `commands/dossier-draft.md` present, `/client-dossier:dossier-draft` and
the model's Skill-tool call both get the command body. A thin "invoke the skill" command loops,
and `SKILL.md` is never read.
**Why:** a plugin command and a plugin skill share one namespace, and the command wins
[VERIFIED: probes K1-K3].
**How to avoid:** no command stem equal to a skill name. Ship `dossier-lint` only (or distinct
names, Open Question 1).
**Warning signs:** "already loaded above; instructions unchanged" in a transcript.

### Pitfall 2: The local install ships the whole working tree
**What goes wrong:** `claude plugin install` from a directory marketplace copied untracked
files, `.claude/` (VibeFlow memory), `.planning/` (6.4 MB, evidence with `/Users/` paths) and
`evals/results/`. `.gitattributes export-ignore` had no effect [VERIFIED: probe C5]. Codex
copies the same tree [VERIFIED: probe X2].
**How to avoid:** run `tests/dist/install-*.sh` against a fresh `git clone` of HEAD (tracked
files only), not the working copy, and delete the temp dirs afterwards. GitHub-source installs
copy tracked files: `.planning/` will ship to every user once public, so D-10's checklist must
cover all of `.planning/`, not just `evidence/` (Open Question 3).

### Pitfall 3: `validate .` reports the marketplace, not the plugin
**What goes wrong:** once `marketplace.json` exists, `claude plugin validate .` prints
`Validating marketplace manifest`. `plugin.json` errors still appear as `plugins[0] plugin.json → …`
and fail the run [VERIFIED: probe C4].
**How to avoid:** in tests, run both `claude plugin validate .` and
`claude plugin validate .claude-plugin/plugin.json`, and assert exit 0 on each plus exactly one
warning (root CLAUDE.md) via `--json`.

### Pitfall 4: Entry fields override plugin.json silently
**What goes wrong:** the entry's `description` replaced the manifest's in `plugin details`
[VERIFIED: probe C3]. An entry `version` is ignored [CITED].
**How to avoid:** the entry holds `name` + `source` only. Test it.

### Pitfall 5: Codex guard gap on `apply_patch`
**What goes wrong:** Codex edits are `apply_patch`, and the guard only reads `file_path`.
**How to avoid:** Pattern 8 branch plus tests with a patch touching `sources/`; or a README
sentence.

### Pitfall 6: Codex plugin hooks need trust and block public listing
**What goes wrong:** hooks are skipped until the user trusts them in `/hooks`. "Plugins
containing lifecycle hooks aren't eligible for the public plugin directory"
[CITED: developers.openai.com/codex/plugins/build "Bundled MCP servers and lifecycle hooks"].
**How to avoid:** add a README step. A future OpenAI directory submission (spec §8) needs a
hook-less variant, which is a publication-time question (Open Question 4).

### Pitfall 7: Isolated `CODEX_HOME` alone is not enough
**What goes wrong:** Codex also reads `~/.agents/plugins/marketplace.json` (personal marketplace)
[CITED]. The `skills` CLI writes global installs under `~`.
**How to avoid:** set **both** `CODEX_HOME` and `HOME` to `mktemp -d` dirs in `tests/dist/`.

### Pitfall 8: `${CLAUDE_SKILL_DIR}` outside Claude Code
**What goes wrong:** on Codex and Agent-Skills harnesses the placeholder is not substituted. The
private scripts are copied but the skill reports them as absent.
**How to avoid:** the one-sentence hint in Pattern 3, or accept it and document it in the README.

### Pitfall 9: Eval workspaces are empty and isolated
**What goes wrong:** no dossier → task skills stop. No `CLAUDE.md`/`AGENTS.md` is loaded, even
one the scaffold wrote. `scaffold_script` runs only with `--scaffold`, with a minimal environment
and 120 s [CITED: plugin-evals "Seed the workspace"].
**How to avoid:** the scaffold calls the repo's `init.py` through a path relative to
`BASH_SOURCE` (proven).

### Pitfall 10: Skill graders are unscored in two-arm runs; default threshold 1.0
**What goes wrong:** with the default `with-without` ablation, `tool_used: Skill` graders become
"plugin-fired indicators" (`scored: false`), unless every grader in the case is one. Exit 1 if
any case < `--threshold` (default 1.0) [CITED].
**How to avoid:** `--ablation none`, and an explicit `--threshold` chosen in the plan (1.0 for the
`write-to-client` case).

### Pitfall 11: `--json` swallows the target
**What goes wrong:** `claude plugin eval --json .` reads `.` as the output path.
**How to avoid:** target first (`claude plugin eval . … --json path.json`) [CITED].

### Pitfall 12: `release.sh` vs the working copy's gitignored eval results
**What goes wrong:** `evals/results/` written by a run makes the tree dirty if not ignored, so
`release.sh` refuses.
**How to avoid:** add `evals/results/` to `.gitignore` in the same commit as the first eval
case.

### Pitfall 13: Version state during Phase 7
**What goes wrong:** setting the manifests to 1.0.0 now makes `release.sh 1.0.0` refuse ("already
at") and breaks D-01's "tag after the audit" order.
**How to avoid:** both manifests stay at `0.1.0` (Codex starts at `0.1.0`), and the CHANGELOG
has only `## [Unreleased]`. `release.sh 1.0.0` runs after the milestone audit.

## Code Examples

All in the Patterns above, each with its provenance: `plugin.json` / `marketplace.json`
(Pattern 1, validated), Codex manifest + marketplace (Pattern 2, installed), `dossier-lint.md`
(Pattern 4, K6 shape), eval case (Pattern 5, run twice), `release.sh` core (Pattern 6, tested),
`apply_patch` grammar (Pattern 8, from the Codex parser).

`tests/dist/install-skills.sh` core (probe S2):
```bash
proj="$(mktemp -d)"; h="$(mktemp -d)"; src="$(mktemp -d)/repo"
git clone -q "$REPO_ROOT" "$src"
(cd "$proj" && HOME="$h" DISABLE_TELEMETRY=1 DO_NOT_TRACK=1 \
  npm exec --yes --package=skills@1.7.2 -- skills add "$src" --skill '*' \
  --agent claude-code codex cursor gemini-cli opencode github-copilot --copy -y)
# assert: .claude/skills/<each>/SKILL.md and .agents/skills/<each>/SKILL.md exist;
# [ -x .claude/skills/dossier-ingest/scripts/file_source.py ]; no lint.py, no hooks/, no agents/ anywhere under $proj
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `commands/*.md` as the slash-command mechanism | Skills are slash commands; commands are "the older format" | Claude Code docs, current | Same-named command shadows skill (Pitfall 1) |
| `.codex-plugin/plugin.json` as the Codex manifest | Root `plugin.json` ("Agent Plugins" schema) + `extensions.com.openai`; `.codex-plugin/` = compat fallback | OpenAI build docs, current | DIST-02 form still supported; revisit at publication [CITED] |
| Codex plugin hooks behind a feature flag | `codex features list` shows `hooks stable true`, `plugin_hooks removed false` | codex-cli 0.150.1 | The `removed` stage reads as "flag retired", consistent with the docs describing plugin hooks as loaded by default [ASSUMED] |
| Manual trigger checks with `claude -p` | `claude plugin eval` (GA ≥ 2.1.269) | Claude Code 2.1.269+ | DIST-06 tool exists and runs headless |

**Deprecated/outdated:** spec §4's tree lists six command files. Recommend amending it to
`commands/dossier-lint.md` (see Open Question 1).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Codex does not substitute `${CLAUDE_SKILL_DIR}` / `${CLAUDE_PLUGIN_ROOT}` in skill text, so bundled scripts fall back | Pattern 3, Pitfall 8 | Low: if it does substitute, the scripts simply work |
| A2 | Codex expands `${CLAUDE_PLUGIN_ROOT}` in hook `command` via the shell environment | Pattern 8 | Hooks would fail to start on Codex (they fail open, so no harm, but no guard) |
| A3 | Non-Claude Agent-Skills harnesses (Cursor, Gemini CLI, OpenCode, Copilot) leave `${…}` placeholders literal | Pattern 3 | Low |
| A4 | A root `plugin.json` could be read by Claude Code too | Alternatives | Only matters if the portable Codex form is adopted |
| A5 | Full eval suite ≈ 3-3.5 USD on Sonnet (0.1411 × cases × 3) | Pattern 5 | Budget over/under-stated |
| A6 | LICENSE year 2026; no compare links in CHANGELOG while private | Pattern 7 | Cosmetic |
| A7 | `plugin_hooks: removed` means the flag was retired, not the feature | State of the Art | If removed, Codex ignores the hooks: README already says skills carry the rules |
| A8 | GitHub-source installs (`owner/repo`) copy tracked files only | Pitfall 2 | `.claude/`-style local files would leak only from local-path installs, which are dev-only |

## Open Questions

1. **DIST-04: six same-named commands break the skills. Which amendment?** (manager decision
   under D-06, inform Samuel)
   - What we know: the probes K1-K3 are conclusive. Skills are already `/client-dossier:<name>`
     slash commands with argument pass-through (K5).
   - Options: (a) **recommended**: `commands/dossier-lint.md` only, amend DIST-04 / D-06 / spec
     §4 / CLAUDE.md, and add the collision test; (b) six commands with distinct stems
     (`init.md`, `ingest.md`, `draft.md`, `call.md`, `status.md`, `dossier-lint.md` →
     `/client-dossier:draft` …) that invoke the skills. This works (K4) but doubles every entry
     in the `/` menu.
2. **Eval budget.** D-07 says "budget stated". The recorded Sonnet run is ≈ 3-3.5 USD for 7-8
   cases × 3 runs (`--max-cost-usd 4`). Higher than earlier phases' scenario runs. Confirm, or
   use `--runs 1` (≈ 1.1 USD).
3. **D-10 scope.** Evidence holds `/Users/` paths and session ids: 03 has 23/49 files with paths
   and 23 with session ids, 04 has 17/54 and 16, 05 has 19/62 and 17. Outside `evidence/`, 21
   tracked files contain `/Users/` (01-*-PLAN/CONTEXT/PATTERNS/RESEARCH/VERIFICATION, 02-*,
   03-RESEARCH/REVIEW/SECURITY, 04-RESEARCH, 05-SECURITY, 07-CONTEXT, `.planning/intel/…json`,
   `tests/scenarios/lib-scenario.sh:570-571`, a scrub pattern, harmless). 7 commit messages carry
   `Claude-Session` URLs. And `.planning/` ships inside every install (Pitfall 2). The
   pre-publication checklist in STATE should name all four surfaces: evidence, other
   `.planning` files, commit history, and the shipped `.planning/`, or the option of removing
   `.planning/` from the public tree. Not executed in v1.
4. **Codex public directory vs hooks** (publication-time, not v1): hooks make the plugin
   ineligible for OpenAI's public directory. Spec §8 plans a PR there. A hook-less Codex variant
   would be needed then.
5. **Codex hook run-time check.** It needs a logged-in Codex. An isolated `CODEX_HOME` is
   `Not logged in`, and Samuel's real Codex uses an API key (`codex login status`: "Logged in
   using an API key"). A live hooks test would need that key exported into the isolated run
   (`codex exec --dangerously-bypass-hook-trust …`) and costs OpenAI tokens. Ask Samuel, or
   verify the hooks on Codex by documentation only and say so in the VERIFICATION.
6. **Spec §4 tree items not covered by any requirement:** "docs/: the protocol reference, the
   fact-line reference" do not exist (`docs/` holds only the spec). Either the README covers
   them, or the tree is amended. This is a planner choice, not a DIST requirement.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `claude` CLI | DIST-01/04/06, validate | ✓ | 2.1.296 | none (dev machine) |
| Claude auth (for paid evals/probes) | DIST-06, K-probes | ✓ (normal config) / ✗ in isolated `CLAUDE_CONFIG_DIR` | — | load checks need no auth |
| `codex` CLI | DIST-02 | ✓ | codex-cli 0.150.1 | none |
| Codex auth | Codex hooks run-time (optional) | ✗ in isolated `CODEX_HOME`; real config uses an API key | — | documentation-only verification (OQ5) |
| node / npm (`npm exec`) | DIST-03 install check | ✓ | node v26.5.0, npm 11.17.0 | `cp -R skills/*` copy check |
| `skills` npm package | DIST-03 | ✓ via npm (network) | 1.7.2 | copy check |
| python3 | release.sh, tests | ✓ | 3.14.6 (`python3`), 3.9.6 (`/usr/bin/python3`) | — |
| git ≥ 2.31 | eval, release | ✓ | 2.50.1 | — |
| `timeout` (GNU) | — | ✗ (macOS) | — | don't use it in tests/dist scripts |

**Missing dependencies with no fallback:** none for the phase's requirements.
**Missing with fallback:** Codex auth (documentation-backed hook verification), `timeout`.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | bash + python3 (`tests/lib.sh`), no framework |
| Config file | none: `tests/run.sh` globs `tests/test-*.sh` |
| Quick run command | `bash tests/test-manifests.sh` (or the file under change) |
| Full suite command | `bash tests/run.sh` (≈ 100 s today, 20 files) |
| Free install checks (outside run.sh) | `bash tests/dist/install-claude.sh`, `bash tests/dist/install-codex.sh`, `bash tests/dist/install-skills.sh` |
| Paid | `claude plugin eval . --scaffold --trust-plugin --ablation none --model sonnet --runs 3 --no-publish --max-cost-usd 4 --json <evidence>.json`; one `/client-dossier:dossier-lint` smoke (`claude -p --plugin-dir . --model haiku`, ≈ 0.002 USD) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DIST-01 | `plugin.json` has name, version, description, `author.name == "Samuel Neveu"`, `license == "MIT"`, http(s) `homepage`/`repository`, `keywords` list; `marketplace.json` has name `client-dossier`, owner.name, description, exactly one entry `{name: client-dossier, source: "./"}` with **no** `version` and no display fields; both files byte-equal to `json.dumps(indent=2)+"\n"` | static | `bash tests/test-manifests.sh` | ❌ W0 |
| DIST-01 | `claude plugin validate .` and `… .claude-plugin/plugin.json` exit 0, `--json` warnings == [root CLAUDE.md] only; `--strict` exit 1 (D-03); `skip` when `claude` is absent | static (CLI) | `bash tests/test-manifests.sh` | ❌ W0 |
| DIST-01 | isolated add + install exit 0; `plugin list` shows the version + enabled; `plugin details` shows Skills (6), Agents (2), Hooks (3); `init` event lists `client-dossier:dossier-lint` | integration (free) | `bash tests/dist/install-claude.sh` | ❌ W0 |
| DIST-02 | `.codex-plugin/plugin.json` identity fields == Claude's (name, version, description, author, license, homepage, repository, keywords); `"skills": "./skills/"`; `.agents/plugins/marketplace.json` entry `source {local, "./"}`, `policy.installation/authentication`, `category`, no version | static | `bash tests/test-manifests.sh` | ❌ W0 |
| DIST-02 | isolated `CODEX_HOME`+`HOME`: marketplace add, plugin add exit 0; `plugin list --json` installed; `debug prompt-input` lists every `skills/*` as `client-dossier:<name>` | integration (free) | `bash tests/dist/install-codex.sh` | ❌ W0 |
| DIST-02 (D-05 mirror) | `apply_patch` input with `*** Update File: sources/…`, `*** Add File:`, `*** Delete File:`, `*** Move to:` into sources → deny JSON; outside sources → allow; malformed patch → allow, exit 0 | unit | `bash tests/test-hook-guard-sources.sh` (new cases) | ✅ file, cases ❌ W0 (if Pattern 8 chosen) |
| DIST-03 | `skills@1.7.2 add <clone> --copy` for six agents: every skill folder copied with SKILL.md, private scripts executable, no `lint.py`/`hooks`/`agents` | integration (free, network) | `bash tests/dist/install-skills.sh` | ❌ W0 (checkpoint first: SUS) |
| DIST-03 | every SKILL.md that references `${CLAUDE_PLUGIN_ROOT}` has the `test -f` guard + a "Without the linter" fallback; every `${CLAUDE_SKILL_DIR}/scripts/…` use is preceded by a `test -x` guard and a stated fallback | static | `bash tests/test-skill-shape.sh` (extend) | ✅ file, case ❌ W0 |
| DIST-04 | `commands/` = exactly `{dossier-lint.md}` (option a); no `commands/<stem>.md` with a `skills/<stem>/`; frontmatter has `description` + `argument-hint`, no `allowed-tools`; body has `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/lint.py"` and a single-quoted path placeholder | static | `bash tests/test-commands.sh` | ❌ W0 |
| DIST-04 | `/client-dossier:dossier-lint` in a fixture dossier relays lint output + exit code; `/client-dossier:dossier-draft …` loads SKILL.md (no collision) | paid smoke (≈ 0.005 USD) | recorded in `07-UAT.md` | manual-only (paid) |
| DIST-05 | README contains: the four target headings; `/plugin marketplace add samuel-neveugall/client-dossier`, `/plugin install client-dossier@client-dossier`, `codex plugin marketplace add`, `codex plugin add client-dossier@client-dossier`, `npx skills add`; "loses" + scripts + hooks + agents; Bash-guard limits naming eval, interpreters, substitutions, variables, loops; semver + CHANGELOG + tag; MIT; `/hooks` trust | static | `bash tests/test-readme.sh` | ❌ W0 |
| DIST-05 | `LICENSE` matches the MIT text + "Samuel Neveu"; `CHANGELOG.md` has `## [Unreleased]` and no released heading before the audit | static | `bash tests/test-readme.sh` | ❌ W0 |
| DIST-06 | every `evals/**/prompt.md` has frontmatter keys from the allowed set, ≥1 grader; each `tool_used` Skill grader names an existing `skills/<name>`; `evals/results/` in `.gitignore`; scaffold scripts executable, `set -eu` | static | `bash tests/test-evals-shape.sh` | ❌ W0 |
| DIST-06 | routing suite passes (threshold stated in the plan; `write-to-client` 3/3) | paid | `claude plugin eval . --scaffold --trust-plugin --ablation none --model sonnet --runs 3 --no-publish --max-cost-usd 4 --json …` | ❌ W0 |
| DIST-07 | scratch repo: refusals (non-semver incl. injection strings, dirty, existing tag, diverged manifests, same version, missing `## [Unreleased]`) leave files and tags unchanged; success → both manifests + entries with a version bumped, heading `## [X] - <today>` under `## [Unreleased]`, annotated tag, one commit, clean tree, bare `origin` has no tag | unit | `bash tests/test-release.sh` | ❌ W0 |

### Sampling Rate
- **Per task commit:** the test file of the artefact under change (`test-manifests.sh`,
  `test-commands.sh`, `test-release.sh`, `test-readme.sh`, `test-evals-shape.sh`).
- **Per wave merge:** `bash tests/run.sh` + `claude plugin validate .`.
- **Phase gate:** full suite green; `tests/dist/*.sh` run and logged (after `scrub_check`);
  the eval JSON recorded; then `/gsd-verify-work`.

### Wave 0 Gaps
- [ ] `tests/test-manifests.sh`: DIST-01/02 static + validate
- [ ] `tests/test-commands.sh`: DIST-04 collision + shape
- [ ] `tests/test-release.sh`: DIST-07 (scratch repo copies the real manifests/CHANGELOG, so it also checks their round-trip stability)
- [ ] `tests/test-readme.sh`: DIST-05
- [ ] `tests/test-evals-shape.sh`: DIST-06 static
- [ ] `tests/dist/install-claude.sh`, `install-codex.sh`, `install-skills.sh`: free, outside run.sh, clone-of-HEAD source, temp dirs removed
- [ ] `.gitignore` gains `evals/results/`
- [ ] `tests/test-skill-shape.sh` / `test-hook-guard-sources.sh` extensions (DIST-03 guards; Pattern 8 if chosen)

## Security Domain

`security_enforcement: true`, ASVS level 1, block on high (`.planning/config.json`).

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | No credentials in manifests (no `userConfig`, no MCP servers, no `headers`) |
| V3 Session Management | no | — |
| V4 Access Control | yes (light) | Hooks fail open but never widen permissions. No `allowed-tools` in skills or the command. Eval grants only read-only tools + `Skill` |
| V5 Input Validation | yes | `release.sh`: semver via `re.fullmatch` on `argv`, all expansions quoted, no `eval`. `dossier-lint` command: single-quoted path, refuse `'`/newline (A4-F1) |
| V6 Cryptography | no | — |
| V10 Malicious Code / supply chain | yes | Pin `skills@1.7.2` behind a human-verify checkpoint. Users pin the plugin with `@v1.0.0` / `--ref v1.0.0`. Eval `--scaffold` runs only our own scripts. `--trust-plugin` only on this repo |
| V14 Configuration | yes | Manifest URLs are https. Hook commands quote `"${CLAUDE_PLUGIN_ROOT}/…"` (validate warns on unquoted). `release.sh` never pushes. Tests never touch the real `~/.claude`, `~/.codex` or `~` |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Command injection through the version argument of `release.sh` | Tampering / EoP | Validate before use; pass via `argv`; quoted; tested with `1.0.0; touch PWNED` and `$(…)` [VERIFIED: probe R1] |
| Accidental publication (pushed tag, public marketplace) | Information disclosure | No `git push`/`--push` anywhere; test asserts the bare remote has no tags; D-01 approval gate |
| Leaking `/Users/…` paths, session ids, the git email in shipped files | Information disclosure | `scrub_check` before evidence lands; D-10 checklist covering `.planning/` (shipped in installs), commit messages; no email in manifests |
| Tests writing into Samuel's real Claude/Codex config | Tampering | `CLAUDE_CONFIG_DIR`, `CODEX_HOME` **and** `HOME` set to `mktemp -d`; assert the real `~/.claude/settings.json` / `~/.codex/config.toml` mtime unchanged (optional) |
| Malicious/compromised `skills` CLI release | Tampering | Pinned 1.7.2, `npm exec` (no global install), isolated `HOME`, telemetry off, checkpoint |
| Marketplace source drift (unpinned `owner/repo`) | Tampering | README shows the pinned form (`@v1.0.0`, `--ref v1.0.0`) next to the default |
| Hook bypass on Codex through `apply_patch` | Tampering (of sources) | Pattern 8 branch, or a documented limitation; the skill rule is the boundary |

## Sources

### Primary (HIGH confidence)
- Live probes in this session (Claude Code 2.1.296, codex-cli 0.150.1, `skills` 1.7.2), scratch
  clone of `f45f214`:
  - C1-C5: isolated Claude marketplace add/install/details/validate, and cache contents;
  - K1-K6: command/skill precedence, Skill tool, direct skill slash, `${CLAUDE_PLUGIN_ROOT}` in a command;
  - X1-X4: isolated Codex marketplace/plugin add, list, prompt-input, `.agents` vs `.claude-plugin` precedence;
  - S1-S2: `skills add --list` / `--copy`;
  - E0-E2: `init.py --help` and two eval runs;
  - R1-R2: release prototype, `claude plugin tag --dry-run`.
- https://code.claude.com/docs/en/plugins-reference: manifest fields, path rules, default
  scans, env variables, root CLAUDE.md warning
- https://code.claude.com/docs/en/plugins/marketplace-reference: marketplace fields, entry vs
  plugin.json precedence, sources, validation messages
- https://code.claude.com/docs/en/plugin-evals: eval layout, graders, ablation, scaffold,
  isolation, flags, exit codes
- https://code.claude.com/docs/en/skills: commands merged into skills, substitutions
- https://developers.openai.com/codex/plugins/build.md: Codex manifest, marketplace,
  cache, hooks eligibility
- https://developers.openai.com/codex/hooks.md: events, I/O shapes, plugin-bundled hooks,
  trust, `apply_patch` matcher aliases
- https://raw.githubusercontent.com/openai/plugins/main/plugins/build-web-apps/.codex-plugin/plugin.json
  and `.agents/plugins/marketplace.json`: official examples
- github.com/openai/codex `codex-rs/apply-patch/src/parser.rs`: patch grammar
- https://semver.org: official regex; https://keepachangelog.com/en/1.1.0/: format
- Repository files read this session: `.claude-plugin/plugin.json:1-5`, `hooks/hooks.json:1-39`,
  `hooks/guard-sources.py:38-45,1269-1302`, `tests/test-hooks-config.sh:14-19`,
  `03-CONTEXT.md` D-04/D-17, `07-CONTEXT.md`, spec §4/§4.3/§7/§8/§10/§11, REQUIREMENTS DIST-01..07

### Secondary (MEDIUM confidence)
- https://github.com/vercel-labs/skills README (via WebFetch summary): sources, flags, agent
  paths, telemetry opt-out
- https://developers.openai.com/codex/subagents.md: custom agents as TOML in `.codex/agents/`

### Tertiary (LOW confidence)
- None used for recommendations.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH. Every CLI was run, and the versions were read from the binaries.
- Architecture: HIGH for Claude Code and the installs; MEDIUM for Codex hook run-time behaviour
  (documented, not executed).
- Pitfalls: HIGH. Pitfalls 1-4, 9 and 12-13 were reproduced; 5-7 are cited.

**Research date:** 2026-10-11
**Valid until:** 2026-10-25 (plugin CLIs ship weekly; re-check `claude plugin validate` messages and Codex manifest docs before publication)
