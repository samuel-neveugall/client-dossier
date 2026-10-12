# Phase 3 — interim security audit (audit-3a)

Audited: `hooks/hooks.json`, `hooks/guard-sources.py`, `hooks/session-start.py`, `hooks/stop-check.py`,
`tests/scenarios/`, `evidence/red-baseline/` @ 4b17e79. Auditor: vf-auditer (via gsd-security-auditor:
SECURED, 15 threats verified, 0 open, T-03-05/07/19 accepted in the plans), 2026-10-10. Persisted by the
mission manager from the auditor's typed report (read-only auditor). Verdict: **gaps_found** — 0 blocker,
2 major, 7 minor.

## Conforming
- No `shell=`, `eval`, `exec` or `subprocess` in the guard; the inspected command is only tokenised.
  `stop-check.py` calls git with an argument list, `--no-optional-locks`, `--` before pathspecs, `-z`.
- `hooks.json` double-quotes `"${CLAUDE_PLUGIN_ROOT}"` in all three commands; the guard only ever emits
  `deny`; malformed stdin → exit 0, no output.
- Write-family guard denies 28 path variants (absolute, relative, `..`, `Sources/`, symlinks into
  `sources/`, new file, nested dossier, NotebookEdit, MultiEdit).
- Stop: no loop, fixed reason without file names, 0.13 s on 120 000 files.
- SessionStart never opens `dossier.yaml`. No secret (`sk-ant-`, emails, tokens) in the evidence.
- `test-hook-guard-sources.sh` PASS 325; `test-hook-stop.sh` PASS 125.

## Fail-open paths
| ID | Sev. | Action | Ref | Path (reproduced) |
|---|---|---|---|---|
| A-F1 | major | ask-user | hooks/guard-sources.py:41-74 | A `dossier.yaml` under `sources/` (planted, or inside an old dossier export received from a client) makes that subtree a root, so Write on existing files there is allowed. Fix: deny if the target is under the `sources/` of ANY ancestor root. |
| A-F2 | major | ask-user | hooks/guard-sources.py:121-131,446-448 | An unmatched `'` or `"` (French apostrophes, heredocs, `# it's` comments) makes `tokenize` return None and the WHOLE command is allowed, including a visible `rm sources/a.txt`. Fix: strip heredoc bodies; on ValueError fall back to per-line/per-segment tokenising instead of allowing all. |
| A-F3 | minor | ask-user | hooks/guard-sources.py:400-416 | Shell reserved words not stripped: `if …; then rm sources/a; fi`, `for … do rm …`, `{ rm …; }`, `! rm …`, functions; `cd -`, `builtin cd`. |
| A-F4 | minor | ask-user | hooks/guard-sources.py:66-74,364-397 | `sources/` symlinked outside the repository; hard links (`ln` not a covered verb). |
| A-F5 | minor | no-op | hooks/guard-sources.py:77-87 | Doctrinal D-04 limits (interpreters, xargs, find -delete, unzip/tar, git clean, rsync --delete, ln -sf, 3-level `sh -c`). |
| A-F6/F7 | minor | no-op | hooks/guard-sources.py:121-147 | `shlex` quadratic on a >1.2 MB token (timeout, non-blocking); NUL in `file_path`; MCP write tools outside the matcher. |

## Other observations (no decision needed)
- The "every hook rule is also stated in a skill" doctrine is not yet met: `skills/dossier/` lands in 03-05; recheck at the final audit.
- `/Users/samuel` path in evidence `memory_paths` (not a secret); optional scrub pattern.
- `git status` honours a booby-trapped `core.fsmonitor` (needs write access to `.git/config` already); option `-c core.fsmonitor=false`.
- Stop envelope: two git calls at 10 s each vs 15 s timeout in `hooks.json` (fail-open anyway).
- Anti-loop depends on the `stop_hook_active` field name (documented).
- `.planning/codebase/CONCERNS.md` absent: no cross-check possible.
