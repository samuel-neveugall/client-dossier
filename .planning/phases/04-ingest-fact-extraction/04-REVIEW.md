# Phase 4 — code review (revue-4)

Range `04f22e3..a7c6b3d` (verdicts also valid at 556c834: doc-only delta), full regime; vf-reviewer,
2026-10-10; persisted by the mission manager (read-only reviewer). Verdict: **gaps_found** — 0 blocker,
4 major, 6 minor. `tests/run.sh` 17/0; `selftest-ingest.sh` 165/0; `git fsck --full --strict` exit 0;
merges `ebd80b7`, `1ad1fc0`, `d0b9e4e` lossless (two lack trailers: no-op, no rewrite).

| ID | Sev. | Ref | Finding |
|---|---|---|---|
| R4-M1 | major | skills/dossier-ingest/SKILL.md:109-117 | Wording lets the model extract inline (observed 4/4: "the transcript is only 7 lines"): dispatch is a narrative step without "always" or the spec §4.1 reason; the rules header presents inline as normal; no "the source is short" rationalization row. Fix: mandatory dispatch whenever a subagent tool exists, whatever the length; inline only with no Agent/Task tool, agent not listed, or two failed dispatches, announced with the pinned sentence; same header change in skill and agent (parity test); "Before filing" peek limited (`head -30`); final report says whether fact-extractor ran. Carry D-12 amended into `ingest-transcript.sh` and `ingest-pdf.sh` (GREEN requires the dispatch) and re-run the paid runs. |
| R4-M2 | major | file_source.py:473-486 | Errors before HTTP headers (`RemoteDisconnected`, `BadStatusLine`, `TimeoutError`) exit 3 `internal` without the "download it manually" hint. Catch `socket.timeout`, `OSError`, `http.client.HTTPException` → `timeout`/`network` refusals with the hint. |
| R4-M3 | major | file_source.py:497-510 | Truncated download accepted (`Content-Length: 100`, 3 bytes → "fetched"); a truncated source would be filed permanently. Refuse when total != declared. `Content-Encoding: gzip` stored raw as `.html`: refuse or flag. |
| R4-M4 | major | skills/dossier-init/SKILL.md:4 | `allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/init.py *)` — the same key that made the ingest skill unloadable headless (29765f9). Remove and verify headless, or document. |
| R4-m5 | minor | file_source.py:365 | JSON gives root-relative paths only; from a subfolder `extract-text.sh sources/…` fails (64). Add `root`/`abs_path`; qualify the skill's commands. |
| R4-m6 | minor | file_source.py:333 | `sources/received` being a file → exit 3 `internal` instead of a clean refusal. |
| R4-m7 | minor | tests/scenarios/lib-scenario.sh | `jsonl_skill_invoked` (and `jsonl_agent_dispatched`) count a denied call as done; match `tool_use_id` to its `tool_result` and require `is_error` false. |
| R4-m8 | minor | tests/test-ingest-file.sh:369 | Surviving mutants: `folder` containment check removed (no test with `sources/received` symlinked outside), `inside()` prefix without separator (no sibling-prefix test), unsanitised extension (no hostile-extension test). `test-skill-ingest.sh` fails without `.git`. |
| R4-m9 | minor | SKILL.md:243 | Bare-skills fallback `pdftotext … -` has no `--- page N ---` markers; say pages are separated by form feeds and how to derive `p. N`. |
| R4-m10 | minor | SKILL.md:47 | The fetch staging folder is never removed; the skill must `rm -r` it after filing. |

`extract-text.sh`: no defect (spaces, `.PDF`, empty page, scan exit 65, non-PDF exit 1, dangling `.txt`
symlink, no args 64, missing `pdftotext` 69 with hint). `fact-extractor.md`: conforms to spec §4.2, rules
block byte-identical to the skill's.
