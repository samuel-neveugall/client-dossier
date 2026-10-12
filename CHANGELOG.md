# Changelog

All notable changes to client-dossier are recorded here. The format follows
[Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/) and the project follows
[Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html). Each release is a git tag
`vX.Y.Z` made by `scripts/release.sh`.

## [Unreleased]

## [1.0.0] - 2026-10-13

### Added

- Six skills: the `dossier` entry skill that carries the protocol, and the task skills
  `dossier-init`, `dossier-ingest`, `dossier-draft`, `dossier-call` and `dossier-status`.
- Two read-only agents: `fact-extractor` (one source into proposed dated, sourced lines) and
  `doctrine-reviewer` (findings on a draft, never a rewrite).
- Three hooks: a SessionStart reminder when a `dossier.yaml` is found upward, a PreToolUse guard
  that denies writes under `sources/`, and a Stop check that blocks once when `outbound/` or
  `sources/` changed without the dossier.
- `scripts/lint.py`, a standard-library linter for the dossier layout and its invariants
  (exit 0 clean or warnings only, 1 errors, 2 no dossier found, 3 internal error).
- English and French templates for the dossier files, written by `dossier-init`.
- Claude Code and Codex plugin manifests, with a self-hosted marketplace listing for each.
- The `claude plugin eval` routing suite for the skill trigger descriptions.
- `scripts/release.sh`, which bumps both manifests, writes the changelog heading and creates a
  local annotated tag.
- The `/client-dossier:dossier-lint` command for Claude Code; the task skills are the slash commands.
