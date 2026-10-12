# Phase 4 — re-review of fix round 1 (revue-4b)

Range `2310b4d..901d439`, HEAD 6b9fbe5, full regime, round 2 of 3; vf-reviewer, 2026-10-10; persisted by
the mission manager. Verdict: **passed** — R4-M1..R4-m10 and A4-F1..A4-F10 all closed by reproduction
(55 SSRF URL forms, rebinding pinned to the validated address incl. via redirect, HTTPS SNI/Host kept on a
local self-signed server, global deadline 3.0 s, truncation/gzip/early-disconnect refusals with the hint,
symlinked `sources` refusals, 14 mutants killed, extract-text confinement and sanitised output, skill and
agent rules byte-identical, no `allowed-tools`). Paid evidence r2: each run has a successful
`client-dossier:fact-extractor` dispatch before the first Edit; sub-agent used Read/Glob only; lint clean.
`tests/run.sh` 17/0, `selftest.sh` 71/0, `selftest-ingest.sh` 184/0, `git fsck` clean; suites pass on
Python 3.9, 3.11, 3.14.

| ID | Sev. | Action | Ref | Finding |
|---|---|---|---|---|
| M1 | minor | auto-fix | file_source.py:723 | `isdigit()` accepts `²` and > 4300 digits → `int()` ValueError → exit 3 without the hint. Require ASCII digits, < 20 chars. |
| M2 | minor | auto-fix | SKILL.md:79 | `--kind`/`--date` values not single-quoted, contrary to the skill's own rule. |
| M3 | minor | auto-fix | lib-scenario.sh:364-410 | The Agent call is async: a non-error tool_result is only "launched"; require the matching `task_notification` with status `completed`. |
| M4 | minor | no-op→auto-fix | SKILL.md:108-116 | Exit 64 of `extract-text.sh` (not a filed copy) missing from "Report from the exit code". |
