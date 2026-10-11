# Phase 7 — re-review of fix round 1 (revue-7b)

Range `c5a87ab..bca54e3`, HEAD d5fb23f, full regime, round 2 of 3; vf-reviewer, 2026-10-11; persisted
by the mission manager. Verdict: **passed** — R8-F1 (`L'Oréal`, `O'Brien`, `accord de l'intéressé`,
`|`/`;`/`$(…)` values arrive intact, `confidential_names` exact, no substitution executed), R8-F2 (22
heredoc `apply_patch` cases: Update/Delete/Move/Add under `sources/` denied incl. `..`, indentation,
CRLF, `<<-`, `bash -c`; `dossier/` and commit messages quoting headers allowed; 20 000 hunks 0.49 s;
no guard regression) and R8-F5 (tag failure → commit undone and tree restored; commit/prepare/
mid-replace failures leave nothing; branch check incl. detached HEAD and `origin/HEAD`; never pushes)
hold by reproduction. `tests/run.sh` 29/0; `git fsck` clean; linear history with trailers.

| ID | Sev. | Action | Ref | Finding |
|---|---|---|---|---|
| R9-1 | minor | auto-fix | skills/dossier-init/SKILL.md:77,117 | The quoting rule appears at step 6 but step 4 already runs `--target '<root>'`: move it before step 4. |
| R9-2 | minor | fix (03 D-16) | guard-sources.py:1328-1335 | `cd sources && apply_patch <<'EOF'` with `*** Update File: received/t.md` allowed: `patch_hit` judges relative to the initial cwd, not the `cd` targets the tokenizer tracks. |
| R9-3 | minor | fix (03 D-16) / D-04 | guard-sources.py:1328-1335 | One-line ANSI-C string with literal `\n` (`apply_patch $'*** Begin Patch\n*** Update File: sources/…'`) allowed — quoting, not D-04 → fix (split on literal `\n` too). `printf … | apply_patch` = pipe, D-04 class (accepted by 03 D-17). |
| R9-4 | minor | no-op | guard-sources.py:1331 | Safe-side false positives: a heredoc whose line starts with `*** Update File: sources/…` is denied. |

## Manager decision
R9-2 and the ANSI-C part of R9-3 are reproduced fail-open paths readable in the command's tokens →
fixed under Samuel's 03 D-16 in round 3 (the last review round of Phase 7); the `printf | apply_patch`
form is the accepted D-04 class (03 D-17) and is documented as such.
