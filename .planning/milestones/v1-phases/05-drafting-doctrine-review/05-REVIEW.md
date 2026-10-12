# Phase 5 — code review (revue-5)

Range `e1be8da..34feaca`, full regime; vf-reviewer, 2026-10-11; persisted by the mission manager.
Verdict: **gaps_found** — 0 blocker, 1 major, 3 minor. `tests/run.sh` 20/0; selftests 71/189/477;
17/17 mutations killed; `git fsck` clean; 5 merges lossless, trailers on every commit, no stray worktree;
dispatch mandatory, `review-rules` byte-identical, agent tools `Read, Grep, Glob`, D-05 consent clause,
EN/FR heading positions, single-quoted commands, no `allowed-tools`.

| ID | Sev. | Action | Ref | Finding |
|---|---|---|---|---|
| R5-M1 | major | auto-fix | skills/dossier-draft/SKILL.md:126-138,189-212,218-250 | Order not guaranteed: the reviewer runs async; in plugin-1/2/3 the HISTORY edit precedes the completion notification; in plugin-1/3/fr-1 a first `result` hands back before the findings ("reviewer has not answered yet"); fr-1 lint ran before 3 findings were applied and was not re-run. Probable trigger: the Stop hook blocks the first stop and pushes the history write during the wait. Fix: dispatch in the foreground (no `run_in_background`); if launched in background, the review is pending — no report, no HISTORY edit, no lint until findings return; fixed order review → apply → lint → history → report; lint after the last draft edit; in "Apply the findings": applied or listed before lint and history. Pin in `tests/test-skill-draft.sh`. |
| R5-m2 | minor | auto-fix | tests/scenarios/draft-reply.sh:380-400; draft-deadline-fr.sh; lib-draft.sh | Harness does not check the order: add `handback_before_review` and `lint_after_last_draft_edit` columns, proven in `selftest-draft.sh`, gating after the fix and a new GREEN run. |
| R5-m3 | minor | no-op | lib-draft.sh `draft_signoff_applied` | Whitespace folding accepts a sign-off split over two lines (documented choice). |
| R5-m4 | minor | no-op | SKILL.md:205,211 | `${CLAUDE_PLUGIN_ROOT}` unquoted in the lint command, same as `dossier` and `dossier-ingest` (pinned by a test). |
