---
phase: 06-calls-status
iteration: 1
review_path: .planning/phases/06-calls-status/06-REVIEW.md
node: fix-6a
---

# Phase 6 review fixes, round 1

## Fixed Issues

- R7-M1 `status.py`: `git diff --cached` now carries `--relative`; test: a nested dossier with a staged, never committed, old-mtime source is reported as filed today.
- R7-m2 `status.py`: a `Last updated:` after today is ignored for `last_reflected`, with a note; skill presentation order now ends with the notes; tests for both.
- R7-m3 `status.py`: `git log` failure or timeout after a successful `rev-parse` adds a note (test with a `git` shim).
- R7-m4 `status.py`: the default linter runs only from a root carrying `.claude-plugin/plugin.json` or `.codex-plugin/plugin.json`; three-case test.
- R7-m5 docstring and `dossier-status/SKILL.md`: a commitment citing a draft without `Deadline:` is not listed as due; pinned.
- R7-m8 tests: `"-I", "-B"` pinned; symlinked `HISTORY.md` pinned; nested-staged case added.
- R7-m9 `test-skill-call.sh`: the `[C1]` "gate NOT passed either" clause is pinned.
- R7-m10 `ROADMAP.md` criterion 5 and `REQUIREMENTS.md` CALL-05 reworded to "misses at least one of: a due commitment, an overdue draft, an unreflected source".
- R7-m11 `${CLAUDE_SKILL_DIR}` double-quoted in `dossier-status` and `dossier-ingest`; the pinned tests (`test-skill-status`, `test-skill-ingest`, `test-ingest-guard`) and the "no placeholder in double quotes" checks updated.

## Skipped Issues

- R7-m6, R7-m7: no-op by review decision.

## Decisions

- Mutation check: with the pre-fix `status.py`, 6 new assertions fail; restored afterwards.

## Follow-up

None. Re-review is the manager's node.

## Re-review round 2 (revue-6b, 2026-10-11) — passed

vf-reviewer, full regime, HEAD 77e8520; persisted by the mission manager. R7-M1, R7-m2..m5, R7-m8..m11
closed by reproduction (nested staged source, future `Last updated:`, failing `git log` shim, foreign
linter without plugin marker not executed, quoting). No regression: `status.py` read-only on 20 000
sources (tree and `.git` snapshot identical), 0.44 s, escaped output, exit 0/2; `tests/run.sh` 24/0;
selftests 412/532/189/71; `git fsck` clean. Paid replay `deal-status.sh --variant plugin --runs 1`:
GREEN 1/1 (0.0553 USD, evidence outside the repository). Notes for Phase 7: `dossier-init` still has an
unquoted `${CLAUDE_SKILL_DIR}`; `.codex-plugin/plugin.json` must exist for the linter marker on Codex.
