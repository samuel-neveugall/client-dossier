# Phase 3 — re-review of fix round 1 (revue-3b)

Range `2e0502a..07da6e2` (fix-3a: 5612baa, 7bac617, 3fba565, 07da6e2), full regime (gap-closure diff).
Reviewer: vf-reviewer, 2026-10-10; persisted by the mission manager (read-only reviewer).
Verdict: **gaps_found** — 0 blocker, 1 major, 7 minor. Review budget: round 2 of 3 for Phase 3.

## Closure of round-1 findings (reproduced with forged stdin)
R-F1 closed for Write/Edit/NotebookEdit (Bash residual NF-4); R-F2, R-F3, R-F5, R-F6 closed; R-F4 unchanged
(no-op, resolved by 03-05); A-F1, A-F2 closed; A-F3 and A-F4 partly closed (NF-4, NF-5). The booby-trapped
`core.fsmonitor` no longer runs. No regression on: new files copied into `sources/` (cp, mv, rsync, install,
git mv, curl -o, tee, `python3 …/file_source.py … sources/received/…`), reads, nested dossiers outside
`sources/`, fail-open on malformed input. Tests @07da6e2: guard 534/0, stop 125/0, hooks-config 59/0,
selftest 65/0, `tests/run.sh` 10 files 0 failed.

## Findings
| ID | Sev. | Ref | Finding |
|---|---|---|---|
| NF-1 | major | guard-sources.py:243-249 | Backslash-newline splits the command: `rm \<NL> sources/a.txt`, `sed -i … \<NL> sources/a.txt`, `cd \<NL> sources && rm a.txt` all allowed (pre-existing). Fix: join `\<NL>` before tokenising, outside single quotes. |
| NF-2 | minor | guard-sources.py:143-186 | Regression: heredoc bodies fed to a shell (`bash <<EOF … EOF`, `sh -s <<EOF`) or containing `$(…)` in an unquoted heredoc are no longer scanned. Fix: scan the body when the verb is a shell or the delimiter is unquoted. |
| NF-3 | minor | guard-sources.py:121-186 | Regression: a `<<` that is not a heredoc (`$((1<<X))`, `[[ a<<b ]]`, `# <<EOF`) hides the following lines. |
| NF-4 | minor | guard-sources.py:300-312 | Bash side of R-F1: `cp/mv/install/rsync x sources/e.txt` through a symlinked `sources/` allowed (`destination_hit` uses only realpath). Fix: also test the lexical path. |
| NF-5 | minor | guard-sources.py:462-470 | Unknown cwd after `cd -`, `cd $X`, `cd "$(pwd)"`; `function f { … }` not parsed. |
| NF-6 | minor | guard-sources.py:143-186,221-241 | Quadratic cost worse than before on 1 MB pathological heredoc shapes (>20 s, hook timeout 10 s = fail-open). Fix: index terminators once, incremental quote parity, join-based segments, size cap. |
| NF-7 | minor | guard-sources.py:14-82 | `find_root` now unused in the guard (kept for AST identity test); docstring and PROTO-08 wording stale. |
| NF-8 | minor | guard-sources.py:166 | Residual false positive (apostrophe inside a double-quoted string cancels heredoc stripping), same as before. No-op. |

## Manager decision
NF-1..NF-7 fall inside Samuel's D-16 (fix every reproduced fail-open path, 2026-10-10) or are regressions
introduced by fix round 1: fixed in round 2 (`fix-3b`) after exec-3 completes, then re-reviewed; no new
question to Samuel unless a residual is to be accepted as debt.
