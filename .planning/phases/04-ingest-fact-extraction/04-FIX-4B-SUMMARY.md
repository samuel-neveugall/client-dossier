# Phase 4 fix 4b (micro-correctif, M1-M4 of 04-REVIEW-FIX.md)

2026-10-10, source: agent-run.

| ID | Fix | Assertion |
|---|---|---|
| M1 | `file_source.py`: Content-Length accepted only as ASCII digits, fewer than 20 characters; otherwise `network` refusal with the "download it manually" hint (never exit 3) | `tests/test-ingest-fetch.sh`: `/cl-unicode` and `/cl-huge` routes (exit 1, `network`, hint); mutation check: without the fix exit 3 `internal` |
| M2 | `SKILL.md`: `--kind '<kind>' --date '<YYYY-MM-DD>'` single-quoted | `tests/test-skill-ingest.sh`: whole-line check and the unquoted-placeholder exception removed; guard test still substitutes and passes |
| M3 | `lib-scenario.sh` `jsonl_agent_dispatched`: an async dispatch (`async_launched`) counts only with a `task_notification` of status `completed` matched by `tool_use_id` or `task_id` | `selftest-ingest.sh`: 5 async cases (launched only, completed, completed by task id, failed, other task) |
| M4 | `SKILL.md`: exit 64 of `extract-text.sh` ("not a filed copy: stop") in "Report from the exit code" | `tests/test-skill-ingest.sh` `has` check |

M3 re-evaluation of the existing r2 streams with the new criterion (no new paid run):
`evidence/green-plugin-r2/plugin-1..3.jsonl` GREEN (dispatch yes), `evidence/pdf-plugin-r2/pdf-1.jsonl` GREEN (dispatch yes).

Results: `bash tests/run.sh` 17 files / 0 failed; `selftest.sh` 71/0; `selftest-ingest.sh` 189/0.
