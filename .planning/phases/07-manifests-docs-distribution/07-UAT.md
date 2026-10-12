---
status: complete
phase: 07-manifests-docs-distribution
source: [07-VERIFICATION.md, 07-CONTEXT.md]
started: 2026-10-12
updated: 2026-10-12
---

# Phase 7 UAT (recette)

Every item was played by the agent (`source: agent-run`), Samuel runs no test. Evidence:
`evidence/uat/` (logs, `rerun/`, `draft-slash.jsonl`). Install checks ran in ISOLATED configurations
(`CLAUDE_CONFIG_DIR`, `CODEX_HOME`, `HOME` in `mktemp -d`, installed from a fresh clone of HEAD), and each
log proves the real Claude Code / Codex configuration byte-identical. Paid headless runs (Haiku,
`--plugin-dir` on a clone) use the real Claude login: an isolated config loses the login
(`claude auth status` reports loggedIn false, probed in 07-09), so they run with
`--setting-sources project,local --no-session-persistence` and the script proves the real settings
and plugin files unchanged. Paid cost of this UAT: 0.0236 USD (rerun lint 0.0024, status 0.0042,
draft slash 0.0171), far under the 1 USD budget.

## Tests

### 1. Claude Code marketplace add + install (DIST-01)
expected: local-clone marketplace added and `client-dossier@client-dossier` installed; 6 skills, 2 agents, 3 hooks, 1 command
source: agent-run
result: pass
evidence: `evidence/uat/install-claude.log` (`DIST install-claude: PASS`): Skills (7) = the 6 skills plus
the `dossier-lint` command (Claude Code lists a plugin command under Skills), Agents (2) fact-extractor and
doctrine-reviewer, Hooks (3) SessionStart, PreToolUse, Stop; installed copy holds `hooks/hooks.json` and
`commands/dossier-lint.md`; real configuration unchanged.

### 2. /client-dossier:dossier-lint runs the linter (DIST-04, D-18)
expected: the command is listed, runs `scripts/lint.py` through Bash in a scratch dossier, relays finding ids and exit code, changes nothing
source: agent-run
result: pass
evidence: `evidence/uat/rerun/smoke-summary.tsv` (run from a fresh clone of HEAD, headless Haiku): lint-smoke
PASS: command-listed, bash-ran-lint.py, relays finding id E1, relays exit 1, dossier unchanged.

### 3. /client-dossier:dossier-draft loads its SKILL.md, no shadowing (DIST-04)
expected: the task skill answers as a slash command with its argument; no `already loaded above` sign
source: agent-run
result: pass
evidence: `evidence/uat/draft-slash.jsonl`: prompt `/client-dossier:dossier-draft a two-line mail to Jane
saying the pilot kickoff moves to next Tuesday`; the model wrote `outbound/mails/2026-10-12_pilot-kickoff-moved.md`
with the full status header (`Status: draft`, To, Subject, Written by, Rules), absolute date 2026-10-20, then
`scripts/lint.py` on the scratch dossier: 0 errors, 0 warnings; zero `already loaded above`. The argument was
passed through (closes the verifier's one warning). Same for `dossier-status`: `rerun/smoke-summary.tsv`
status-smoke PASS (expanded skill-folder path used, no shadowing sign, dossier unchanged).

### 4. Codex isolated install (DIST-02)
expected: skills listed by Codex
source: agent-run
result: pass
evidence: `evidence/uat/install-codex.log` (`DIST install-codex: PASS`): `codex debug prompt-input` lists
`client-dossier:dossier`, `-call`, `-draft`, `-ingest`, `-init`, `-status`, equal to the 6 `skills/` folders.
Limit, stated honestly: Codex hooks were never run for real (no OpenAI login); the `apply_patch` guard is
proven only with Codex-shaped stdin.

### 5. Bare copy of skills/ (DIST-03)
expected: each skill says what it loses without scripts, hooks, agents
source: agent-run
result: pass
evidence: `evidence/uat/install-skills-copy.log` (`DIST install-skills: PASS`, `lint.available` false for a bare
copy). SKILL.md fallbacks present: `dossier-ingest` "Without the scripts", `dossier-status` "Without the
script" and "Without the linter", `dossier-call` and `dossier-draft` "Without the linter", `dossier-ingest`
and `dossier-draft` "No subagent here" inline procedure, `dossier` "a bare-skills install has no scripts",
`dossier-init` bundles `scripts/init.py` in its folder.

### 6. scripts/release.sh in a scratch clone (DIST-07)
expected: `9.9.9-test` bumps both manifests, CHANGELOG heading and a local tag, no push; refuses a dirty tree
source: agent-run
result: pass
evidence: `evidence/uat/release-rehearsal.log`: `--allow-branch 9.9.9-test` exit 0, "tagged v9.9.9-test locally.
Nothing was pushed.", both plugin.json diffs and CHANGELOG `## [9.9.9-test]` under `## [Unreleased]`, bare
origin 0 refs; dirty tree refused (exit 1), existing tag refused, non-default branch refused. This repository:
no `v*` tag, manifests 0.1.0.

### 7. README commands are exact (DIST-05)
expected: every command cited exists as written
source: agent-run
result: pass
evidence: `evidence/uat/suite-validate-ref.log`; `claude plugin marketplace add`/`install`, `codex plugin
marketplace add`/`add` and `skills add` checked against the CLIs' `--help`; the `owner/repo@ref` source form
is accepted by `claude plugin marketplace add` (tried live with `anthropics/claude-plugins-official@main`,
recorded as `GitHub (...@main)`). Still unproven until publication: installing `samuel-neveugall/client-dossier`
itself (private repository, D-04). The slash commands and `python3 scripts/lint.py [PATH]` are covered by
tests 2, 3 and `tests/test-readme.sh`.

### 8. Suite and manifest gate
expected: `bash tests/run.sh` green; `claude plugin validate .` exit 0 with one warning (root CLAUDE.md)
source: agent-run
result: pass
evidence: `TOTAL: 30 files, 0 failed`; validate exit 0, one warning (root CLAUDE.md, D-03); see
`evidence/uat/suite-validate-ref.log`.

## Summary

total: 8
passed: 8
issues: 0
pending: 0
skipped: 0
blocked: 0
