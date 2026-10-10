---
phase: 04-ingest-fact-extraction
verified: 2026-10-10T00:00:00Z
status: passed
score: 5/5 must-haves verified
covered_files:
  - .planning/phases/04-ingest-fact-extraction/04-01-PLAN.md
  - .planning/phases/04-ingest-fact-extraction/04-01-SUMMARY.md
  - .planning/phases/04-ingest-fact-extraction/04-02-PLAN.md
  - .planning/phases/04-ingest-fact-extraction/04-02-SUMMARY.md
  - .planning/phases/04-ingest-fact-extraction/04-03-PLAN.md
  - .planning/phases/04-ingest-fact-extraction/04-03-SUMMARY.md
  - .planning/phases/04-ingest-fact-extraction/04-04-PLAN.md
  - .planning/phases/04-ingest-fact-extraction/04-04-SUMMARY.md
  - .planning/phases/04-ingest-fact-extraction/04-05-PLAN.md
  - .planning/phases/04-ingest-fact-extraction/04-05-SUMMARY.md
  - .planning/phases/04-ingest-fact-extraction/04-FIX-4A-SUMMARY.md
  - .planning/phases/04-ingest-fact-extraction/04-FIX-4B-SUMMARY.md
  - agents/fact-extractor.md
  - skills/dossier-ingest/SKILL.md
  - skills/dossier-ingest/scripts/extract-text.sh
  - skills/dossier-ingest/scripts/file_source.py
  - tests/scenarios/ingest-pdf.sh
  - tests/scenarios/ingest-transcript.sh
  - tests/scenarios/lib-scenario.sh
  - tests/scenarios/selftest-ingest.sh
covered_digest: "v3:sha256:e0603ffe6c2ef1e479dcffa5b50891276801c86ff5c308954827501d89e0bd29"
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: human_needed
  previous_score: 4/5
  gaps_closed:
    - "dossier-ingest dispatches the fact-extractor agent and applies its proposal (ROADMAP criterion 1, INGEST-02): dispatch now mandatory in SKILL.md, observed in 4/4 paid r2 runs"
  gaps_remaining: []
  regressions: []
---

# Phase 4: Ingest & Fact Extraction Verification Report (re-verification)

**Phase Goal:** Any source that arrives gets filed exactly once, immutably, and its facts land in the right living files with a checkable citation.
**Verified:** 2026-10-10
**Status:** passed
**Re-verification:** Yes, after fix rounds 4a (mandatory dispatch, review and audit findings) and 4b (minors M1-M4). Previous report kept as `04-VERIFICATION.iter1.md`.

## Goal Achievement

The one open item of iter1 (the `fact-extractor` dispatch never observed) is closed by evidence I read myself in the raw jsonl streams, not from the summaries. Everything iter1 verified was re-checked against the current code, which changed in 4a and 4b.

### Observable Truths (ROADMAP success criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `dossier-ingest` on a PDF files it as `YYYY-MM-DD_slug`, extracts via `extract-text.sh`, reports the fact-extractor's proposal applied to the right living files with `Last updated:` refreshed | VERIFIED | `evidence/pdf-plugin-r2/pdf-1.jsonl` (parsed by my own script): `Agent` tool_use with `subagent_type` `client-dossier:fact-extractor` at event 22, async launch result, sub-agent events (parent_tool_use_id set) use only `Read` (9 calls, no error), sub-agent text with the three-list markup at 60, `task_notification` status `completed` (task a7685ce55c6ac9aac, matching tool_use_id) at 62, first main-agent `Edit` at 72. The dispatch prompt gave the PDF path, the `.txt` path, the label and the content date. `pdf-1.diff`: `sources/received/2026-10-06_onboarding-pack.pdf` + `.txt`, `### Priya Raman (Acme Consulting)` heading, an answered table row in `OPEN-QUESTIONS.md` (not a bullet), `p. N` locators, `Last updated: 2026-10-10, after the onboarding pack of 2026-10-06` in all 4 changed files, lint 0/0. Every applied line equals a Proposal line; the two Uncertain items were not written. |
| 2 | Re-ingesting the same file (same hash) is reported as already filed, not duplicated | VERIFIED | Own run on the current `file_source.py`: same bytes under another slug and date returned `already_filed` with the existing path, exit 0, still one file; different bytes under a taken name returned `name_taken`, exit 1; transcript re-filed with `--kind raw` and the same bytes also `already_filed`. SKILL.md "File it" reads `status` and files nothing again. `tests/test-ingest-file.sh` green. |
| 3 | A contradicting fact yields a corrected line annotated "(corrects a line dated <date>)", no second contradictory line | VERIFIED | `evidence/green-plugin-r2/plugin-1.diff`: the seeded `15,000 euros (mail 2026-10-01 ...)` line is replaced in place by `confirmed the phase one budget at 18,000 euros (call 2026-10-10 @00:19) (corrects a line dated 2026-10-01).` The sub-agent's Contradicts entry carried exactly that corrected line; the main agent applied it as a replacement. `corrected = yes` 3/3 in `green-plugin-r2/summary.tsv`. |
| 4 | "Given a transcript, what did we learn" moves RED to GREEN | VERIFIED | `red-baseline/summary.tsv` 3/3 RED (unchanged since iter1, commit order RED before skill checked in iter1). `green-plugin-r2/summary.tsv`: 3/3 GREEN under the stricter gate (GREEN now requires `ingest_skill = yes` and `extractor_dispatched = yes`, `ingest-transcript.sh` line 345-346). My own parse of each stream: Agent dispatch of `client-dossier:fact-extractor` at event 14 / 16 / 12, matching `task_notification` `completed` at 57 / 59 / 58, first `Edit` at 69 / 71 / 67, sub-agent tools `{Read, Glob}`, no tool_result in error, lint 0/0, 9-11 `@mm:ss` lines per run. |
| 5 | With `pdftotext` absent the PDF is still filed, extraction reported skipped with an install hint; the skill text holds the inline extraction procedure for a harness without subagents | VERIFIED | Own run with `PATH=/usr/bin:/bin`: `extract-text.sh` exit 69 and `Install poppler: macOS 'brew install poppler'; Debian/Ubuntu ...`, PDF still filed. SKILL.md carries the exit-69 branch, the pinned sentence `No subagent here: I am doing the fact-extractor's job myself`, the full `extraction-rules` block and a "Without the scripts" section (form-feed page rule added in 4a). |

**Score:** 5/5 truths verified, 0 present-but-behavior-unverified.

### iter1 items re-checked

| iter1 item | Now |
|------------|-----|
| Human item: dispatch never observed in 4 GREEN runs | CLOSED. `SKILL.md` "The dispatch is mandatory": whenever an Agent or Task tool exists the agent is dispatched whatever the length; inline only with no subagent tool, agent not listed, or two failed dispatches, announced with the pinned sentence. The "source is short" rationalization row is present (observed 4/4). Rules header changed in skill and agent, byte-identical (my regex diff of the two `extraction-rules` blocks: equal). Paid r2 runs show 4/4 successful dispatches with the order dispatch, proposal returned, completed notification, first Edit. The 4 old runs (`green-plugin/`, `pdf-plugin/`) have no dispatch, which is what 4a was written to fix. |
| Advisory: `jsonl_skill_invoked` counts a denied call | CLOSED (R4-m7). `jsonl_agent_dispatched` (read in `lib-scenario.sh`) requires a non-error tool_result, and for an async launch a `task_notification` `completed` matched by tool_use_id or task_id (M3). `selftest-ingest.sh` 189/0 includes 5 async cases. |
| Advisory: `dossier-init` carries `allowed-tools` | CLOSED. `grep -rn allowed-tools skills` is empty. |
| Advisory: VALIDATION.md `draft`, one unticked box | UNCHANGED, honest (full suite is 90 s here against the 90 s target); left to `/gsd-validate-phase`. Not gating. |
| Advisory: single model, one fixture each | UNCHANGED (claude-sonnet-5-5, Claude Code 2.1.296, 3 transcript runs + 1 PDF run). Sampling plan of the phase; not gating. |

Review and security findings: `04-REVIEW-FIX.md` (re-review passed, M1-M4 minors) and `04-FIX-4B-SUMMARY.md`. I confirmed M1 (`file_source.py` Content-Length requires ASCII digits and fewer than 20 characters, otherwise `network` refusal), M2 (`--kind '<kind>' --date '<YYYY-MM-DD>'` single-quoted) and M4 (exit 64 bullet) in the current files, and the free suites below pass.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `skills/dossier-ingest/SKILL.md` | task skill with mandatory dispatch | VERIFIED | read in full; no stub; no `allowed-tools`; `test -x` before both scripts; pointer from the `dossier` skill |
| `skills/dossier-ingest/scripts/file_source.py` | filing, sha256 dedup, no overwrite, containment, SSRF-guarded fetch | VERIFIED | own runs: filed, already_filed, name_taken, `not_public` for 127.0.0.1, `bad_url` for `file://`; 55-URL SSRF, rebinding, truncation covered by the re-review and `tests/test-ingest-fetch.sh` |
| `skills/dossier-ingest/scripts/extract-text.sh` | `.txt` next to the PDF, markers, exit codes | VERIFIED | own runs: exit 69 with hint when `pdftotext` is hidden, exit 64 with a message on a path outside `sources/`, exit 1 on an invalid PDF |
| `agents/fact-extractor.md` | read-only (`Read, Grep, Glob`), fixed markup | VERIFIED | frontmatter `tools: Read, Grep, Glob`; runtime confirmation: sub-agent events hold only `Read`/`Glob` in the 4 r2 streams |
| `tests/scenarios/{ingest-transcript,ingest-pdf,selftest-ingest,lib-scenario}.sh` | harness whose GREEN needs the dispatch | VERIFIED | verdict logic read; `selftest.sh` 71/0, `selftest-ingest.sh` 189/0 |
| `evidence/{red-baseline,green-plugin,pdf-plugin,green-plugin-r2,pdf-plugin-r2}` | recorded paid runs | VERIFIED | streams parsed by my own script, not the summary rows |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `dossier` skill | `dossier-ingest` | pointer sentence | WIRED | unchanged since iter1 |
| SKILL.md | `file_source.py` / `extract-text.sh` | `${CLAUDE_SKILL_DIR}/scripts/...` | WIRED | executed in the 4 r2 streams (filing result JSON read back, `.txt` produced in the PDF run) |
| SKILL.md | `fact-extractor` | Agent tool, `client-dossier:fact-extractor` | WIRED (was PARTIAL) | dispatched and completed in 4/4 r2 runs, proposal returned, then applied |
| proposal | `dossier/*.md` | Edit tool | WIRED | diffs equal the sub-agent proposals, lint clean |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| living-file lines | fact lines with `@mm:ss` / `p. N` | sub-agent reading the filed source to its last line (`Read: 7 lines` / `Read: 3 pages`) | Yes | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full mechanical suite | `bash tests/run.sh` | `TOTAL: 17 files, 0 failed` (about 90 s) | PASS |
| Scenario harness self-test | `bash tests/scenarios/selftest.sh` | `PASS 71 FAIL 0` | PASS |
| Ingest harness self-test | `bash tests/scenarios/selftest-ingest.sh` | `PASS 189 FAIL 0` | PASS |
| Dedup / collision | `file_source.py` on a scratch dossier | `already_filed` / `name_taken` | PASS |
| Fetch refusals | `fetch 'http://127.0.0.1:1/x'`, `fetch 'file:///etc/passwd'` | `not_public`, `bad_url` (both with the manual-download hint) | PASS |
| Extraction exit codes | `extract-text.sh` with and without `pdftotext`, outside `sources/` | 1 / 69 + hint / 64 | PASS |
| Dispatch proof in streams | own jsonl parser on the 4 r2 streams | Agent before first Edit, completed notification, Read/Glob only, 0 errors | PASS |

### Probe Execution

No `probe-*.sh` is declared by the phase. SKIPPED.

### Requirements Coverage

| Requirement | Status | Evidence |
|-------------|--------|----------|
| INGEST-01 | SATISFIED | filing script, `--kind raw` to `sources/transcripts/raw/`, exit 69 hint, PDF GREEN r2 |
| INGEST-02 | SATISFIED | dispatch observed 4/4, proposal applied, correction in place, `Last updated:` refreshed, report |
| INGEST-03 | SATISFIED | read-only agent confirmed at runtime (Read/Glob only), three-list markup returned in all 4 runs, quote/number rules in the block |
| INGEST-04 | SATISFIED | own runs + tests |
| INGEST-05 | SATISFIED | 3/3 RED, 3/3 GREEN under the dispatch-gated criterion |
| INGEST-06 | SATISFIED | inline procedure, pinned sentence, scripts check, "Without the scripts" |

No orphaned requirement: INGEST-01..06 all appear in the plans. PROTO-02/08 stay incremental by the assignment.

### Anti-Patterns Found

None. `TBD|FIXME|XXX` hits in the phase files are `mktemp XXXXXX` templates only.

### Human Verification Required

None.

### Gaps Summary

No gap. Advisories, none gating:

- **Skill drift after the paid runs.** Commit `c4d8bb3` (4b) changed `SKILL.md` after the r2 runs (quoting of `--kind`/`--date`, an exit-64 bullet) and `file_source.py` (Content-Length). Neither touches the dispatch wording, but the paid evidence ran on the `e4dbed2` text, not on HEAD. The 4b changes are covered by free tests (`test-skill-ingest.sh`, `test-ingest-fetch.sh` with a mutation check).
- **Final report wording, 1 of 4.** SKILL.md asks the report to say whether `fact-extractor` ran. In `plugin-3` the final message does not mention it (the other three do); the stream proves the dispatch. Cosmetic.
- **Dispatch prompt in the PDF run** held a self-correcting label sentence (`` `brochure 2026-10-06` is wrong kind; use `onboarding pack 2026-10-06` ``). The sub-agent used the right label; no effect.
- **Bookkeeping, for the orchestrator.** ROADMAP Phase 4 checkbox and the INGEST-01..06 rows in `REQUIREMENTS.md` still read Pending; `04-VALIDATION.md` stays `draft`.
- **Sampling.** One model, one fixture per scenario, as planned.

---

_Verified: 2026-10-10_
_Verifier: Claude (gsd-verifier)_
