# Phase 6 — code review with security pass (revue-6)

Range `8c5c331..8366ff2`, full regime; vf-reviewer, 2026-10-11; persisted by the mission manager.
Verdict: **gaps_found** — 0 blocker, 1 major, 10 minor. `tests/run.sh` 24/0; selftest-call 412/0;
`git fsck` clean; 30 linear commits with both trailers; no stray worktree. `status.py` read-only proven
(tree and `.git` snapshot identical, `--no-optional-locks`, `core.fsmonitor=false`, lint `-I -B`),
21 500 sources in 0.54 s, escaped output, exit codes 0/2/3, 22/25 mutations killed. `dossier-call`
prepare and debrief cover every mandated point; security lessons of Phases 4-5 applied; no fail-open of
the confidentiality gate.

| ID | Sev. | Action | Ref | Finding |
|---|---|---|---|---|
| R7-M1 | major | auto-fix | status.py:628 | `git diff --cached --name-only` lacks `--relative`: in a dossier nested in a larger repo a staged, never-committed source with an old mtime is not reported. Add `--relative` + nested-staged test. |
| R7-m2 | minor | auto-fix | status.py:837 | A future `Last updated:` becomes `last_reflected` and empties "unreflected sources". Ignore future dates. |
| R7-m3 | minor | auto-fix | status.py:584-587 | `git log` failure/timeout returns `{}` silently (all sources fall back to mtime). Add a note. |
| R7-m4 | minor | auto-fix | status.py:681 | Linter found at `parents[3]/scripts/lint.py` without identity check (a bare install under `~/.claude/skills/` could run a foreign `~/.claude/scripts/lint.py`). Require a plugin marker at that root. |
| R7-m5 | minor | no-op | status.py:332-336 | A commitment citing a draft without `Deadline:` is dropped even with a past date on the line (by design, 06-02-PLAN). Document. |
| R7-m6 | minor | no-op | status.py misc | No output cap; huge `staleness_days` → exit 3 on Py ≥ 3.11; nested parentheses in a source; bidi/zero-width not escaped. |
| R7-m7 | minor | no-op | dossier-call/SKILL.md:175 | Debrief assumes git (`git diff -- dossier`); debrief-created file slug unspecified. |
| R7-m8 | minor | auto-fix | tests/test-status-script.sh | Pin `-I -B`, symlinked `HISTORY.md` in `read_text_safe`, nested+staged case. |
| R7-m9 | minor | auto-fix | tests/test-skill-call.sh:258-268 | The `[C1]` "gate NOT passed" clause is not pinned. |
| R7-m10 | minor | manager decision | ROADMAP.md:344; REQUIREMENTS.md:162 | CALL-05 RED wording says "misses due commitments"; the measured RED (per D-08: any of the three) missed a source (2) or a draft (1), the commitment was reported 3/3. |
| R7-m11 | minor | no-op | dossier-status/SKILL.md:31,37 | `${CLAUDE_SKILL_DIR}` unquoted (same convention as dossier-ingest). |

## Manager decisions
- R7-m10: tier 2, reversible — ROADMAP criterion 5 and CALL-05 are reworded to "misses at least one of:
  a due commitment, an overdue draft, an unreflected source", matching 06 D-08 (manager decision of
  2026-10-10) and the measured RED; Samuel's D-16 fallback is not involved (the baseline was RED).
- R7-m11 and the same pattern in `dossier-ingest`: quoted in the fix round (cheap hardening).
