# Phase 7: Manifests, Docs & Distribution - Context

**Gathered:** 2026-10-10 (manager cadrage, Pattern F; Samuel's answers relayed by the main session)
**Status:** Ready for planning

<domain>
## Phase Boundary

Someone outside this repository can install and trust the plugin on the harness of their choice:
complete Claude Code manifests and self-hosted marketplace, Codex manifests and marketplace listing,
a bare `skills/` install for Agent-Skills harnesses, six thin slash commands, README / MIT LICENSE /
CHANGELOG, `claude plugin eval` suites for the trigger descriptions, and `scripts/release.sh`.
Requirements DIST-01..DIST-07. Publication (official marketplaces, public repository, pushed tags)
is outside the phase: it needs Samuel's explicit approval.

</domain>

<decisions>
## Implementation Decisions

### Asked to Samuel
- **D-01 (Q12) — version 1.0.0.** The first installable version is 1.0.0. The team creates the
  `v1.0.0` tag LOCALLY after the milestone audit; pushing the tag, publishing to any marketplace
  and making the repository public each need Samuel's explicit approval again.
  (arbitrage Samuel, AskUserQuestion session principale, 2026-10-10, option (a))
- **Phase 3 Q10 — git policy:** phase branch merged `--no-ff` into `main` and pushed with `main`
  after verification and UAT; no tags pushed, no publication.

### Manager decisions (noted by Samuel 2026-10-10, reversible)
- **D-02 — MIT licence** in the name of "Samuel Neveu"; `author` added to both manifests.
- **D-03 — The root `CLAUDE.md` stays** (development instructions); the manifest gate is
  `claude plugin validate .` without `--strict`, and `CLAUDE.md`'s command list says why.
- **D-04 — Marketplace install tested from a local path** (the repository is private), in an
  isolated configuration that never touches Samuel's own Claude Code or Codex settings.

### Manager decisions (tier 2, reversible)
- **D-05 — Codex.** `.codex-plugin/plugin.json` and `.agents/plugins/marketplace.json` follow the
  current Codex plugin format (researched, not guessed); install verified with the installed
  `codex` CLI under an isolated `CODEX_HOME`. The Phase 3 deferral (Codex mirror of the hooks)
  is settled by research: mirrored if Codex supports equivalent hooks, otherwise the README says
  the skills carry the same rules (CLAUDE.md doctrine).
- **D-06 — Commands.** Six thin files under `commands/`: five invoke their task skill with the
  arguments, `dossier-lint` runs `scripts/lint.py`; the `dossier` entry skill has no command.
  **Amended 2026-10-12 by D-18 (settled by Samuel):** one command, `commands/dossier-lint.md`; the five task skills are the slash commands. See D-18 below.
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

### Manager decisions after research (2026-10-11, reversible)
- **D-11 — Eval suite (DIST-06).** `claude plugin eval` suite under `evals/`, about 7-8 cases
  x 3 runs on Sonnet, `--ablation none`, about 3-3.5 USD (budget accepted, `--max-cost-usd 4`).
  It includes the ambiguous "write to the client" -> `dossier-draft` and never `dossier-ingest`,
  one positive trigger per task skill, the entry skill's step-aside outside a dossier and an
  unrelated-prompt false-positive guard. Free shape test in `tests/run.sh`; the paid run is
  recorded under `evidence/` and never part of `run.sh`.
- **D-12 — Pre-publication checklist (D-10 refined).** A checklist in STATE.md names four
  surfaces: (1) scenario evidence (`/Users/...` paths, session ids); (2) the other `.planning/`
  files that carry `/Users/...`; (3) `Claude-Session` URLs in commit history; (4) `.planning/`
  shipped inside every installation (or the option of excluding it from the public tree).
  NOT executed in v1.
- **D-13 — Codex public directory.** OpenAI's public directory refuses plugins with lifecycle
  hooks; noted in the README and STATE for publication time, out of v1.
- **D-14 — `.codex-plugin/plugin.json` must exist** (the marker `scripts/status.py` requires to
  locate the linter).
- **D-15 — Harmonise the `"${CLAUDE_SKILL_DIR}"` quoting** in `skills/dossier-init/SKILL.md`
  with the other skills (found in the Phase 6 review); skill tests re-run.
- **D-16 — `release.sh` tests.** `scripts/release.sh <version>` is tested in a scratch clone,
  never pushes, refuses a dirty tree, a non-semver version and an existing tag. The real
  1.0.0 run plus the LOCAL `v1.0.0` tag happen after the milestone audit, outside this phase;
  both manifests stay at `0.1.0` and CHANGELOG holds only `## [Unreleased]` until then.
- **D-17 — Isolation.** Every install check (Claude, Codex, `skills`) sets `CLAUDE_CONFIG_DIR`,
  `CODEX_HOME` and `HOME` to `mktemp -d` directories, installs from a fresh `git clone` of HEAD,
  and never touches Samuel's real configuration.

## Settled by Samuel (formerly P-01)

- **D-18 (was P-01, Q15) — one slash command.** Ship ONE command, `commands/dossier-lint.md`; the
  five task skills serve as the slash commands (`/client-dossier:dossier-<x>`), because a plugin
  command with the same name as a plugin skill shadows the skill (research, 07-RESEARCH.md).
  DIST-04, spec section 4, D-06 and `CLAUDE.md` are amended, and a test fails when a command shares
  a skill's name. The v1.0.0 tag stays local; push, marketplace and public each need Samuel's
  explicit approval. (arbitrage Samuel, AskUserQuestion session principale, 2026-10-12, option (a))

## Canonical References

- Spec `docs/superpowers/specs/2026-09-16-client-dossier-design.md` §4 (tree), §8 (distribution), §10.
- `.planning/REQUIREMENTS.md` DIST-01..DIST-07 (DIST-05 note: README states the D-04 limits).
- Phase 3 D-17, Phase 4/5/6 CONTEXT files (skills that the manifests, commands and eval reference).

</canonical_refs>
