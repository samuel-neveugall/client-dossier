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

## Round 3 (the last of the review budget) - fixed by vf-coder, 2026-10-11

Cadre: 05 D-09 (Samuel, AskUserQuestion in the main session, 2026-10-11: harden E5 for every
mechanical case). No further review round; the tests below and the phase verification stand in.

| ID | Fix |
|---|---|
| R6-1 | `scripts/lint.py`: a third, tolerant reading (`gap_reading()`): every tag, link target, styling mark and invisible character becomes one private-use `_GAP`; the tolerant patterns (`boundary_pattern/folded_text_pattern(gap=True)`) accept `_GAP` or nothing between letters and words and read it as a word boundary. `Hello<br>Big Tel<wbr>co`, `Big Tel<wbr>co<br>Corp`, `Hello<ZWSP>Big Tel<ZWSP>co` now hit. |
| R6-2 | Link targets with a title in `'t'` or `(t)`, `<url>`, `( url )`, parentheses nested three levels deep; tags with a `>` inside a quoted attribute (the plain tag form stays as fallback for an unbalanced quote). |
| R6-3 | U+2010..U+2015 and U+2212 are separators in the folded pass (U+2011 reaches U+2010 through NFKD); U+FF40 folds to an apostrophe before NFKD. |
| R6-4 | A non-empty `.gitkeep` under outbound/ that E5 cannot read (UTF-16, Latin-1, over 5 MB, symlink, failed stat) is an `[E5]` error "is unreadable" (fail closed). |
| R6-5 | `skills/dossier-draft/SKILL.md`: exit 1 with a `[C1]` error line means E5 did not run: the gate is NOT passed, as for an exit code outside 0 and 1; pinned in `tests/test-skill-draft.sh`. |
| R6-6 | `tests/scenarios/lib-draft.sh` `draft_history_edit_before_review`, column `history_edit_before_review` (reply col 33, fr col 25), a GREEN criterion of both plugin scenarios, proven in `selftest-draft.sh` (Edit, Bash redirection, async, read-only `2>/dev/null` negative, no dispatch, baseline, fr). |

Found on the way: the R5-M1/A5-F1 pins of `tests/test-skill-draft.sh` and the mirrored pins of
`tests/test-skill-ingest.sh` sat after `finish` (which exits), so they never ran. Moved before it;
all pass.

Replay of the existing r2 flows against R6-6 (no new paid run): `green-plugin-r2/plugin-1..3` and
`fr-deadline-r2/fr-1` have 0 edits of `dossier/HISTORY.md` before the reviewer's completion, so they
stay GREEN. `green-plugin-r2/plugin-2` edited the history (events 43, 45) before running the linter
(event 47): that departs from the documented order review, apply, lint, history, report. The new
criterion does not invalidate it (the edit follows the review, and the lint, run after the last draft
edit, covered the history lines too), and the documented order is not a gate of the harness; recorded
here, not gated.

Performance (4.9 MB outbound file, best of 3, before -> after): plain prose 0.44 -> 0.32 s, Markdown
0.92 -> 0.70 s, HTML 0.86 -> 0.64 s, invisible characters 2.12 -> 1.55 s (the left word boundary now
sits after the first literal, `B(?<![^\W_]B)ig`, which lets the regex engine skip ahead). Pathological
5 MB shapes (`](a` x N, unbalanced tags and quotes, tag/ZWSP spam): within +45 % worst case
(`<a it's ` x N, 0.48 -> 0.62 s), most faster.

False positives: a differential fuzz of about 60,000 random mixes of the old and new linter (names `Big
Telco`, `O'Brien`, `Al`, `Bob`, `L'Oréal`, `Ed Co`; words containing them, markup, dashes, invisibles)
found 0 finding lost and only legitimate new ones (a dash or a tag between the words of a name).
