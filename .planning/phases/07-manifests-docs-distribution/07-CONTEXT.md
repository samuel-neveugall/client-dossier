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

</decisions>

<canonical_refs>
## Canonical References

- Spec `docs/superpowers/specs/2026-09-16-client-dossier-design.md` §4 (tree), §8 (distribution), §10.
- `.planning/REQUIREMENTS.md` DIST-01..DIST-07 (DIST-05 note: README states the D-04 limits).
- Phase 3 D-17, Phase 4/5/6 CONTEXT files (skills that the manifests, commands and eval reference).

</canonical_refs>
