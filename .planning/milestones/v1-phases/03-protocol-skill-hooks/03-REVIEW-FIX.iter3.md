# Phase 3 — re-review round 3 of 3 (revue-3d)

HEAD 232b39a (fix-3b e88e9c1, fix-3c 53c0192, c86ffcc), full regime; vf-reviewer, 2026-10-10; persisted by
the mission manager. Verdict: **gaps_found** — 0 blocker, 0 major, 6 minor. Review budget for Phase 3
exhausted (3/3).

Closed (cases replayed): NF-1..NF-7, S-M1, S-M2, S-m3..S-m6. No regression on new files copied into
`sources/`, reads, nested dossiers, malformed input; ~90 common dev commands, no false positive.
`git fsck --full --strict` clean; `tests/run.sh` 11/0; guard 831/0; skill 94/0; selftest 65/0.

| ID | Sev. | Action | Ref | Finding |
|---|---|---|---|---|
| F1 | minor | auto-fix | guard-sources.py:390-439 `prepare()` | Regression of fix-3b: `echo a\ #b; rm sources/a.txt`, ANSI-C `$'\''` quotes unbalance the reader → `rm` allowed (old guard denied). |
| F2 | minor | auto-fix | guard-sources.py:329-363 | Quote state not carried across lines: `echo "\ncat <<EOF\n"\nrm sources/a.txt\nEOF` allowed. |
| F3 | minor | ask-user | guard-sources.py:94-104,539-570,839-856 | Super-linear cost on deliberately pathological commands ≥ 35 KB (32 000-component path 12 s; 3 000-10 000 `cd` chain 6.5 s to >40 s; 150 000 operands ~9 s) → hook timeout (10 s) = fail-open. Fix: ignore operands > 4096 chars, cap operands per segment, no realpath for absent dirs. |
| F4 | minor | auto-fix (cd -/popd) | guard-sources.py:839-873 | `cd /; cd -; rm sources/a.txt` allowed (OLDPWD/dir stack not tracked); `pushd sources && popd; rm dossier/x.md` false positive. `cd $X; cd sources` and `cd /nonexistent;` remain D-04 class. |
| F5 | minor | ask-user | guard-sources.py:780-815 | D-04-class residuals: eval/`bash -c "$(cat <<EOF)"`/process substitution/`ssh h <<EOF`, depth ≥ 3 `bash -c`, >64 KB scripts, loops over globs, interpreters. Readable-in-tokens forms not covered: globs/braces on the `sources` component (`rm sour*/a.txt`), deleting/moving a parent (`rm -rf .`, `rm -rf *`, `mv . ../x`), verbs `gsed -i`, `patch`, `awk -i inplace`, `ed`, `vim -es`, `sponge`, wrappers `timeout`, `nice`, `ionice`, `stdbuf`, `caffeinate`; `cp dossier/*.txt sources/` onto an existing name. |
| F6 | minor | auto-fix | spec lines 357, 365 | Spec §4.3 still says "nearest dossier"/"nearest wins" for the guard; D-16 (2) is "under the `sources/` of any ancestor dossier". |
| F7 | minor | no-op | tests/test-hook-guard-sources.sh:349-358; tests/test-skill-dossier.sh:128-147 | Surviving mutations: guard 2/11 (`guessed()` unmarked, `popd` no-op), skill 4/11 (prepare-a-call read-first content, "only steps aside", stop-check sentence, `reconstructed`). |

The skill text changed after the GREEN evidence (description and wording): the UAT replays GREEN.
