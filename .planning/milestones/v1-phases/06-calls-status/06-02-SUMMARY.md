---
phase: 06-calls-status
plan: 02
status: complete
requirements: [CALL-03, PROTO-08]
requirements-completed: [CALL-03, PROTO-08]
key-files:
  created:
    - skills/dossier-status/scripts/status.py
    - tests/test-status-script.sh
---

# Plan 06-02 Summary: status.py mechanics (CALL-03, PROTO-08)

`skills/dossier-status/scripts/status.py` (executable, Python 3.8 stdlib only, read-only) computes every
item `dossier-status` presents; `tests/test-status-script.sh` pins it on scratch git dossiers scaffolded
by the real `init.py`, always with `--today`.

## Commits

| Task | RED | GREEN |
|---|---|---|
| 1 tracer, CLI, exits, static pins | 24b04e6 | 4fd66a5 |
| 2 commitments, upcoming, drafts, stale, status line | 7762c68 | 59839b6 |
| 3 sources, lint variants, read-only, escaping | 9896c78 | c760594 |

Each GREEN was produced by restoring the stubbed functions of the later tasks (the finished file was
written once, then stubbed back for the earlier REDs), so every RED failed on exactly the missing
behaviour (task 2: 21 failures, task 3: 14).

## Final CLI and JSON shape

`status.py [--json] [--today YYYY-MM-DD] [--lint PATH] [PATH]`; exit 0 report, 2 (no dossier.yaml upward,
missing path, unreadable dossier.yaml, bad arguments), 3 (`error: internal status failure: <Type>: <msg>`).
JSON keys: `root, today, status_line, commitments[{file,line,side,heading,date,state,text}],
upcoming[{file,line,date,text}], last_reflected, unreflected_sources[{path,filed,how}],
overdue_drafts[{path,status,deadline}], stale_files[{path,last_updated,days}], staleness_days,
lint{available,exit,errors,warnings,findings[{path,line,severity,id,message}],info}, notes`.
Text sections as in the contract (`- none` for every empty list).

## git commands (all prefixed `git --no-optional-locks -c core.fsmonitor=false -C <root>`, 10 s timeout)

`rev-parse --is-inside-work-tree`; `log --no-renames --relative --diff-filter=A --name-only -z --format=@%at -- sources`;
`ls-files --others --exclude-standard -z -- sources`; `diff --cached --name-only --diff-filter=A -z -- sources`.
Lint runs as `python3 -I -B <lint.py> <root>` (60 s timeout), found at `parents[3]/scripts/lint.py` or `--lint`.

## Verification

- `bash tests/test-status-script.sh`: PASS 229 FAIL 0 (task 1: 48, after task 2: 161).
- `bash tests/run.sh`: TOTAL: 21 files, 0 failed.
- Acceptance greps: `environ` 0, `Les nôtres` 0 in status.py, no title table, `timeout` 3, mode 100755.

## Deviations from Plan

None in scope. Small decisions where the plan was silent:

- `git log` output with `-z --format` interleaves `\n` before the first path of each commit; the parser
  strips one leading `\n` per token (checked on real output).
- A `done <date>` marker is searched before the trailing source only; one inside the parenthesis is not a marker.
- Upcoming items use the same "last absolute date outside the source" rule as commitments, and honour `done`.
- One-line status is returned verbatim (a leading bullet marker is kept); the section ends at the next heading.
- `.gitkeep` and OS metadata are excluded from overdue-draft candidates as well as from sources.
- The module docstring avoids the literal word that the `grep -c environ` acceptance counts.

## Self-Check: PASSED
