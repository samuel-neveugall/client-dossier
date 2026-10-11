# Phase 5 — re-review of fix round 1 (revue-5b)

Range `5368745..98840b7` (E5 hardening 1267548, skills/harness ecd9edf, evidence fcad1f5), full regime,
round 2 of 3; vf-reviewer, 2026-10-11; persisted by the mission manager. Verdict: **gaps_found** — 0
blocker, 0 major, 6 minor. Closed by reproduction: R5-M1, R5-m2, A5-F1, A5-F2, A5-F3 (except
abbreviations, D-09 debt), A5-F4, A5-F5, A5-F8 (31/31 bypasses caught). No new false positive
(names contained in words, 2-3 letter names, `L'Oréal`, `O'Brien`, ordinary Markdown/HTML/links);
line numbers exact on a 300-file fuzz; no exit 3 or loop on ~5 MB pathological inputs; 13/13 lint
mutations killed; `git fsck` clean after the concurrent stash/pop; `tests/run.sh` 20/0, test-lint
1647/0, selftests 71/510/189. r2 evidence honest (foreground dispatch, completion before any HISTORY edit).

| ID | Sev. | Action | Ref | Finding |
|---|---|---|---|---|
| R6-1 | minor | fix (D-09) | scripts/lint.py:1759-1782 | Mixed readings: `Hello<br>Big Tel<wbr>co` escapes (deleted reading loses the word boundary, spaced reading splits `Tel co`); same with ZWSP. Third reading with a tolerant boundary. |
| R6-2 | minor | fix (D-09) | scripts/lint.py:1753-1755 | Markup long tail: Markdown link titles `'t'`/`(t)`, `<url>`/`( url )`, nested parentheses, `>` inside a quoted attribute. |
| R6-3 | minor | auto-fix | scripts/lint.py:1540-1552,1599 | U+2010/U+2011 not separators; U+FF40 not folded (`_FOLD_TABLE` before NFKD). |
| R6-4 | minor | fix (D-09) | scripts/lint.py:1936,1948-1950 | Unreadable non-empty `.gitkeep` (UTF-16, Latin-1, > 5 MB, symlink) silently skipped: emit an "unreadable" error. |
| R6-5 | minor | auto-fix | skills/dossier-draft/SKILL.md (confidential-name gate) | Exit 1 with a C1 config error (e.g. misspelt `confidential_name:`) means E5 did not run: also "gate not passed". |
| R6-6 | minor | auto-fix | tests/scenarios/lib-draft.sh | Harness does not gate "no HISTORY edit before the reviewer's completion"; in plugin-2 history preceded lint. |

## Manager decision
R6-1, R6-2 and R6-4 are mechanical cases, so they fall inside Samuel's 05 D-09 ("harden E5 for every
mechanical case", 2026-10-11): fixed in round 3 (the last), with R6-3, R6-5 and R6-6; then verification
and UAT, no new hunting round. No question to Samuel unless a residual is to be accepted as debt.
