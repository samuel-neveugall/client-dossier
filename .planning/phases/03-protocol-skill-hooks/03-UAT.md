---
status: complete
phase: 03-protocol-skill-hooks
source: [03-VERIFICATION.md, 03-CONTEXT.md]
started: 2026-10-10
updated: 2026-10-10
---

# Phase 3 UAT (recette)

Every item was played by the agent (`source: agent-run`), Samuel runs no test. Evidence:
`evidence/uat/`. Model `claude-sonnet-5-5`, Claude Code headless (`claude -p`), isolation flags of
the harness (`--setting-sources project,local --strict-mcp-config --no-session-persistence`).
HEAD at the replay: `82b756d` (skill text of fix-3c/3d included).

## Tests

### 1. GREEN replay after the skill changed (fix-3c, fix-3d)
expected: plugin variant GREEN 3/3, `sources/` hash unchanged, correction filed in `dossier/`
source: agent-run
result: pass
evidence: `evidence/uat/green-replay/summary.tsv` (GREEN 3/3; the script's closing tally crashed
because the harness file was edited while it ran, rows are intact) and
`evidence/uat/gate-and-pointer/summary.tsv` (`plugin: GREEN 3/3, gate PASS`, `SCENARIO fix-typo: PASS`).
Six GREEN of six across the two invocations; lint exit 0 on each scratch dossier.

### 2. Real-user case: plugin + AGENTS.md present (informational, does not gate)
expected: recorded
source: agent-run
result: pass (informational)
evidence: new variant `plugin-pointer` (commit `82b756d`, selftest 71/0):
`evidence/uat/gate-and-pointer/summary.tsv`, GREEN 3/3, skill loaded 3/3. For reference the
iter-1 `pointer-only` variant (no plugin, AGENTS.md) was INCOMPLETE 3/3.

### 3. SessionStart reminder received in a real session
expected: `additionalContext` naming the dossier root and `client-dossier:dossier`; silent outside a dossier
source: agent-run
result: pass
evidence: `evidence/uat/real-session/s1-edit-denied.jsonl`, `s3-stop-block.jsonl` (hook_response
SessionStart with the reminder, then `Skill(client-dossier:dossier)` as first tool call);
`s4-outside.jsonl` (outside a dossier: SessionStart output empty, Stop output empty, no skill call).

### 4. Edit on `sources/` refused with the immutability message
expected: the PreToolUse guard denies, file unchanged
source: agent-run
result: pass, with a note
evidence: `evidence/uat/real-session/s1c-edit-denied-hooks-only.jsonl`: `PreToolUse:Edit` deny,
"sources are immutable; file a correction in the dossier instead: sources/transcripts/t.txt";
sources hash unchanged. NOTE: with the full plugin the skill makes the agent refuse before it ever
calls Edit (`s1-edit-denied.jsonl`, `s1b-edit-denied.jsonl`: no Edit call, even when told it is a
guard test), so the guard cannot be observed in a real session with the skill loaded. The
hooks-only run (a scratch copy of `hooks/` + `.claude-plugin/`, skill absent) exposes the guard
by itself. The Write/Edit/MultiEdit/NotebookEdit denials are also covered by the 1558-assertion
guard test.

### 5. Stop blocks once when outbound/ changes without dossier/
expected: one block with a reason addressed to the agent, then the stop passes
source: agent-run
result: pass
evidence: `evidence/uat/real-session/s3-stop-block.jsonl`: Write of `outbound/mails/hello.md`,
first Stop output `{"decision":"block","reason":"outbound/ changed in this dossier but nothing under
dossier/ did. ..."}`, the agent answers in one sentence, second Stop output empty (no loop).

### 6. Silence outside a dossier
expected: no reminder, no block
source: agent-run
result: pass
evidence: `evidence/uat/real-session/s4-outside.jsonl` (see item 3).

### 7. Suite and manifest
source: agent-run
result: pass
evidence: `bash tests/run.sh` -> `TOTAL: 11 files, 0 failed`; `bash tests/scenarios/selftest.sh` ->
`PASS 71 FAIL 0`; `claude plugin validate .` (no --strict) exit 0 (one warning: root CLAUDE.md).

### 8. Evidence scrub
source: agent-run
result: pass
evidence: `grep` of `evidence/uat/` for `sk-ant-`, the git user email and `@gmail`: no hit.
Scratch paths (`/private/var/folders/...`) remain, as in iter-1 evidence.

## Cost

Paid runs total 0.83 USD (budget 1.5): green-replay 0.20, gate-and-pointer 0.41, real sessions
about 0.22 (summed from `total_cost_usd` of every result event under `evidence/uat/`).

## Summary

total: 8, passed: 8, issues: 0, pending: 0

## Gaps

none
