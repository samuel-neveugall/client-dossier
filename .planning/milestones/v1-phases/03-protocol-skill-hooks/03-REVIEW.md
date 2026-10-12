# Phase 3 — interim code review (revue-3a)

Reviewed: `git diff ca8f62c..HEAD -- hooks/ tests/ .gitignore` @ 4b17e79, full regime (fail-open guard).
Reviewer: vf-reviewer, 2026-10-10. Persisted by the mission manager from the reviewer's typed report
(the reviewer is read-only). Verdict: **gaps_found** — 0 blocker, 1 major, 5 minor.

## Evidence
- `bash tests/run.sh` @4b17e79: exit 0, 10 files, 0 failed.
- One real `claude -p --plugin-dir .` run on a scratch dossier (0.054 USD): SessionStart fired; `Edit`
  under `sources/` denied with the doctrine message; source hash unchanged; Stop blocked once, no loop.
- `git fsck --full --strict` exit 0 (7 dangling commits, all before the range); 17 commits, none empty,
  linear. The three hooks' `find_root` ASTs are identical to `scripts/lint.py`'s.

## Findings
| ID | Sev. | Action | Ref | Finding |
|---|---|---|---|---|
| R-F1 | major | ask-user | hooks/guard-sources.py:57-74 | `sources/` itself a symlink to a folder outside the dossier: `realpath` leaves the dossier, the Write-family guard allows writes to existing and new files (D-03 defect). Fix: also resolve lexically (`normpath(join(cwd,path))`) and deny if either path is under `sources/`. |
| R-F2 | minor | auto-fix | hooks/guard-sources.py:121-147 | Heredoc bodies are tokenised as commands: false positive (`rm sources/x` inside a heredoc body denied) and bypass (an apostrophe in the body makes `shlex` fail, the whole command is then allowed). Fix: strip heredoc bodies before tokenising. |
| R-F3 | minor | auto-fix | hooks/guard-sources.py:94-95 | `cmd >& sources/file` not treated as a write redirect. |
| R-F4 | minor | no-op | hooks/session-start.py:53-56 | The reminder names `client-dossier:dossier`, which does not exist until plan 03-05 lands; do not merge without 03-05. |
| R-F5 | minor | auto-fix | tests/scenarios/fix-typo.sh:155,191-199 | `R_SHA_BEFORE` never compared with `MISSING` (a failed fixture write could yield GREEN); only the transcript's hash is checked. Should be a harness error (exit 2). |
| R-F6 | minor | no-op | evidence/red-baseline/*.jsonl:1 | `memory_paths.auto` holds `/Users/samuel/...`; `scrub_check` only checks `sk-ant-` and the git email. |

Checked and fine: Stop silent outside git/dossier, on `stop_hook_active`, on a sibling dossier; subfolder
prefix stripping; Python 3.8 grammar (`ast.parse(feature_version=(3,8))`, no real 3.8 interpreter);
copying a NEW file into `sources/` is never blocked; harness errors exit 2 and never become verdicts.
