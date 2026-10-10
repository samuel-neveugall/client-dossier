---
status: complete
phase: 04-ingest-fact-extraction
source: [04-VERIFICATION.md, 04-CONTEXT.md]
started: 2026-10-10
updated: 2026-10-10
---

# Phase 4 UAT (recette)

Every item was played by the agent (`source: agent-run`), Samuel runs no test. Evidence:
`evidence/uat/` (driver: `evidence/uat/uat-driver.sh`). Model `claude-sonnet-5-5`, Claude Code 2.1.296
headless (`claude -p --plugin-dir .`), harness isolation flags (`--setting-sources project,local
--strict-mcp-config --no-session-persistence`). HEAD at the replay: `c4d8bb3` plus the committed
verification iter1 rename (skill and scripts of fix-4a and fix-4b included). Scratch dossiers built by the
real `init.py`, outside the repository. Paid cost: **0.660 USD** of the 1 USD budget.

## Tests

### 1. Real session: local transcript is filed, facts applied, dispatch, lint
expected: filed under `sources/transcripts/` as `YYYY-MM-DD_slug` (content date), dated sourced facts applied,
`Last updated:` refreshed, `fact-extractor` dispatched, lint clean
source: agent-run
result: pass
evidence: `evidence/uat/transcript/` (`summary.tsv`, `plugin-1.jsonl`, `plugin-1.diff`): verdict GREEN, filed as
`sources/transcripts/2026-10-10_kickoff-call.txt`, 9 `@mm:ss` fact lines, `refreshed = yes`,
`extractor_dispatched = yes` (async launch plus `task_notification` completed, the M3 criterion), the seeded
15,000 euro line replaced in place with "(corrects a line dated 2026-10-01)", lint 0 error 0 warning. Cost 0.240 USD.

### 2. Re-ingest of the same file, from a sub-folder of the dossier
expected: `already_filed`, no duplicate, the dossier root is found from a sub-folder
source: agent-run
result: pass
evidence: `evidence/uat/reingest.jsonl`: session started in `<dossier>/incoming`; the agent located the root,
`cmp` showed the bytes equal the filed copy, the filing script returned `already_filed`, nothing written,
`sources/transcripts/` unchanged (`2026-10-10_kickoff-call.txt` and `raw`), lint 0/0. It did not re-dispatch the
extractor (nothing new). Cost 0.096 USD.

### 3. PDF with `pdftotext` hidden from PATH
expected: PDF filed, extraction reported skipped with the install hint
source: agent-run
result: pass, with a note
evidence: `evidence/uat/pdf-masked.jsonl`: PATH without `/opt/homebrew/bin` (`command -v pdftotext` empty);
PDF filed as `sources/received/2026-10-10_onboarding-pack.pdf`, no `.txt`; `extract-text.sh` exit 69 with
"extraction skipped" and the poppler install hint; no fact invented; lint 0/0. NOTE: the final chat message says
the PDF could not be read and that the facts will be filed once poppler is installed; it does not repeat the
word "skipped" (the script output the agent read does). Cost 0.112 USD.

### 4. URL on 127.0.0.1 is refused
expected: `not_public` refusal with the download-it-yourself message, no request made
source: agent-run
result: pass
evidence: `evidence/uat/url.jsonl` and `url-server.log`: a local `http.server` bound to 127.0.0.1 served a PDF;
`file_source.py fetch` returned `{"error": "not_public", "hint": "Download it manually and re-run on the local
file."}`, exit 1, nothing filed, the agent did not try `curl`. The server log holds exactly one GET, my own
`curl` self-check before the run; the skill made none. No request left the machine toward the Internet. A first
attempt (server port lost by my driver, URL without port) gave the same refusal and cost 0.077 USD, not kept as
evidence. Cost of the kept run 0.075 USD.

### 5. Outside a dossier
expected: the skill stops with a message
source: agent-run
result: pass
evidence: `evidence/uat/outside.jsonl`: empty scratch folder with `note.txt`; the `dossier-ingest` skill was
loaded, the agent searched upward, found no `dossier.yaml`, stopped ("no dossier to file it into"), suggested
`dossier-init`, created nothing (`ls -A` shows only `note.txt`). Cost 0.060 USD. The sub-folder case is test 2.

### 6. Suite, manifest, scrub
expected: `bash tests/run.sh` green, `claude plugin validate .` exit 0, evidence scrubbed
source: agent-run
result: pass
evidence: `bash tests/run.sh` TOTAL 17 files, 0 failed; `selftest.sh` 71/0; `selftest-ingest.sh` 189/0;
`claude plugin validate .` exit 0 (one known warning: root CLAUDE.md not loaded as plugin context);
`scrub_check` on every file of `evidence/uat/`: no `sk-ant-`, no git user email (home paths only, warning level).

## Summary

total: 6
passed: 6
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

None. Cosmetic note on test 3 only.
