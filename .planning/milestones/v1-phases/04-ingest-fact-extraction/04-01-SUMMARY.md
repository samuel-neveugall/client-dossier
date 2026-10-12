---
phase: 04-ingest-fact-extraction
plan: 01
subsystem: ingest
tags: [python, stdlib, sources, dedup, ssrf, guard, tracer]
requires:
  - phase: 03-protocol-skill-hooks
    provides: hooks/guard-sources.py (Bash guard that lets a NEW file into sources/), tests/lib.sh helpers
  - phase: 01-scaffold-templates
    provides: init.py scaffold used as the fixture, scripts/lint.py find_root
provides:
  - skills/dossier-ingest/scripts/file_source.py, the only route a source takes into sources/
  - JSON contract (filed / already_filed / fetched / error) that plan 04-04's SKILL.md relies on
  - tests/test-ingest-file.sh and tests/test-ingest-fetch.sh
affects: [04-02, 04-04, 04-05]
tech-stack:
  added: []
  patterns:
    - "one guarded main: every failure is a JSON error, exit 0/1/2/3 (lint.py meaning of 2 and 3)"
    - "stage outside the dossier, hash the staged copy, O_EXCL copy into sources/"
    - "stateless dedup: sha256 against every regular file under sources/, size prefilter"
key-files:
  created:
    - skills/dossier-ingest/scripts/file_source.py
    - tests/test-ingest-file.sh
    - tests/test-ingest-fetch.sh
  modified: []
key-decisions:
  - "Date validated by shape + datetime.date(y, m, d), not fromisoformat (the import allowlist has no re module and 3.11+ fromisoformat accepts other shapes)"
  - "fetch checks the staging directory before the URL, so the TMPDIR-inside-dossier case needs no DNS"
  - "is_public unwraps IPv4-mapped and 6to4 addresses before is_global (version-independent)"
  - "3xx HTTPError from urllib (refused hop, too many hops, bad redirect scheme) all report redirect_refused"
  - "staged download is named <suggested_slug><ext> so the filing form's default slug is meaningful"
requirements-completed: [INGEST-01, INGEST-04]
duration: 55min
completed: 2026-10-10
status: complete
commits: 3
plan_head_before: e0b59cf9c1fedc2fe24a36b86eaff7cb04e83c11
plan_head_after: 85822da8599692ce4d80bd18766ffe2db94ed197
actuals:
  tokens: 14500
  tasks: 3
  commits: 3
---

# Phase 4 Plan 01: file_source.py, the only route into sources/ Summary

**Stdlib filing script that names, stages, hashes, dedups and O_EXCL-copies a source into `sources/`, plus a two-step SSRF-guarded URL download, with the phase tracer running the skill's exact command through the real Bash guard.**

## What was built

`skills/dossier-ingest/scripts/file_source.py` (mode 100755, Python 3.8+, stdlib only, 587 lines)
and two bash tests. Task 1 is the tracer: the command line the skill will issue,
`file_source.py --kind transcript --date 2026-10-10 --slug 'Kickoff call' "incoming/Call transcript.txt"`,
is fed to the real `hooks/guard-sources.py` as a Bash PreToolUse event (exit 0, empty stdout, empty
stderr), then executed in a dossier scaffolded by the real `init.py`; it files
`sources/transcripts/2026-10-10_kickoff-call.txt` byte-identical, JSON `filed`.

### Final JSON contract

- Filing form: `file_source.py --kind received|transcript|raw [--date YYYY-MM-DD] [--slug TEXT] PATH`
  - `{"status":"filed","path":"sources/...","sha256":"...","bytes":N,"warnings":[...]}`
  - `{"status":"already_filed","path":"sources/...","sha256":"..."}`
  - `{"status":"error","error":"<code>","message":"...","hint":"..."}` (`hint` only on download errors)
- Fetch form: `file_source.py fetch URL` ->
  `{"status":"fetched","path":"<absolute staged path>","ext":".pdf","bytes":N,"sha256":"...","final_url_host":"<host>","suggested_slug":"<slug>"}`
- Exit: 0 filed / already_filed / fetched; 1 refused or failed; 2 no `dossier.yaml` upward; 3 internal
  (JSON `internal`, no traceback). One ASCII-only JSON object on stdout in every path, stderr empty.
- Error codes actually emitted: `usage`, `no_dossier`, `bad_date`, `missing`, `not_a_regular_file`,
  `empty`, `url_argument`, `sources_outside_dossier`, `staging_inside_dossier`, `name_taken`,
  `internal`; fetch adds `bad_url`, `unresolvable`, `not_public`, `redirect_refused`,
  `http_<code>`, `too_large`, `timeout`, `network`. Every download error carries
  `hint: "Download it manually and re-run on the local file."`.
- Warnings: a `raw` export with no `sources/transcripts/<date>_<slug>.*` (names the stem); a file
  over 100 MB (`LARGE_FILE_WARNING_BYTES`, names Git LFS).

## Test results

| File | Result |
|---|---|
| `bash tests/test-ingest-file.sh` | PASS 284 FAIL 0 (RED before implementation: PASS 12 FAIL 40 after task 1's test, PASS 237 FAIL 47 after task 2's) |
| `bash tests/test-ingest-fetch.sh` | PASS 103 FAIL 0 (RED: PASS 5 FAIL 5 plus a crash before the assertions) |
| `bash tests/run.sh` | `TOTAL: 13 files, 0 failed` (four runs; see the flake note below) |
| fetch test with its python program run under `/usr/bin/python3` 3.9.6 | PASS 103 FAIL 0 |
| file test, tracer rerun under `/usr/bin/python3` | passes inside the test (not skipped) |

Task 1 acceptance: `head -1` is `#!/usr/bin/env python3`, `git ls-files -s` shows `100755`, the test
greps `guard-sources.py`, the script contains `open(target, "xb")` and `ensure_ascii=True`.
Task 3 acceptance: `OpenerDirector`, `is_global`, exactly one `MAX_REDIRECTS = 5`, the hint sentence,
and `is_public|getaddrinfo` six times in the fetch test.

## D-02 delivery

D-02 says a URL is downloaded into `sources/received/`. It is delivered in two calls:
`file_source.py fetch URL` downloads the URL as-is into a staging folder outside the dossier
(`client-dossier-fetch-*` under the system temp dir), then the skill (plan 04-04) peeks at the staged
file and files it with `--kind received`. Nothing lands under `sources/` before the filing call. The
reason: the content date of D-01 and the kind of D-07 are only known after reading the downloaded
bytes, a filed name can never be changed (the guard denies `mv` under `sources/`), and a login or
consent page that answered 200 must be refused before filing. The filing form refuses a URL
argument (`url_argument`) and points to `fetch`. The staged directory is not deleted by the script
(the skill reads it after the call); it lives under the OS temp directory.

## Deviations from Plan

### Auto-fixed / adapted

**1. [Rule 3 - Blocking] Worktree base behind the phase branch.** The worktree was created at
`e0b59cf` (phase 3 merge), five docs-only commits before `feat/phase-04-ingest-fact-extraction`, so
`04-01-PLAN.md` and `04-PATTERNS.md` were absent on disk. Read them with `git cat-file -p
feat/phase-04-ingest-fact-extraction:<path>` (read-only, no merge, no branch change as instructed).
04-CONTEXT.md and 04-RESEARCH.md were present. Impact: none on the code; the final merge of this
worktree onto the phase branch is the orchestrator's.

**2. [Rule 3 - Blocking] Global hook refuses `rtk git` porcelain in a worktree.** `git add`/`git
commit` were rewritten to `rtk git ...` and refused; used `/usr/bin/git` run from the worktree
(the plan allows the plumbing route). The per-plan commit ledger (`.git/worktrees/...`) could not
be written from this agent, so the base SHA is recorded in `plan_head_before` above from the start
HEAD instead.

**3. [Rule 3 - Blocking] Iron Law ADR-035 file-size guard (300 lines).** The script is 587 lines.
Added the `# vibeflow:allow-large-file -- ...` marker after the shebang as the plan foresaw, naming
the bare-skills reason (DIST-03). The debt-register entry in `.planning/WINDOWS.md` was NOT added
from this worktree, to avoid a merge conflict with the parallel plans' worktrees; the orchestrator
should append one `deviation` row for `skills/dossier-ingest/scripts/file_source.py` ("one file on
purpose; tracked in 04-01-SUMMARY.md"), the way `init.py` and `lint.py` have theirs.

**4. [Rule 1 - Bug avoidance] Date validation without `re`.** The plan's import allowlist has no
`re`, so the exact `YYYY-MM-DD` shape is checked character by character, then
`datetime.date(int, int, int)` rejects non-calendar days. Same contract (`2026-02-30`, `10/10/2026`,
`2026-1-5`, `20261010` all `bad_date`), and no 3.11 `fromisoformat` leniency.

**5. [Rule 2 - Missing critical] IPv4-mapped and 6to4 unwrapping in `is_public`.** `is_global` of
`::ffff:127.0.0.1` differs across Python versions; the embedded IPv4 address is checked instead,
so the refusal does not depend on the interpreter.

**6. [Rule 1] Redirect error mapping.** urllib raises a 3xx `HTTPError` for a too-long chain and
for a non-http(s) redirect scheme as well as for our refused hops; all three report
`redirect_refused` with a fixed message (urllib's own message can carry the URL and its query).

**7. Check order for `fetch`:** root, then staging directory, then the URL checks, so the
TMPDIR-inside-dossier test needs no DNS or network.

**8. Test scaffolding:** `sources/README.md` (scaffolded by init.py) is a regular file under
`sources/`, so it takes part in dedup like any other (a file with README's exact bytes would be
`already_filed`); the tests' `count_sources` excludes it. Behaviour is per plan ("every regular
file under sources/").

### Unexplained transient

One `bash tests/run.sh` run, right after I edited `tests/test-ingest-fetch.sh` and ran the three
test files in one chained command, ended `TOTAL: 13 files, 1 failed`. The failing file was not
captured. Four later full runs and five repeated runs of both new test files were all green. Not
reproduced; flagged for the orchestrator's wave verification.

## Authentication gates

None.

## Known Stubs

None.

## Threat Flags

None beyond the plan's register. Mitigations T-04-01..T-04-13 each have a passing test; T-04-14
(DNS rebinding) stays accepted and is named in the module docstring.

## Self-Check: PASSED

- FOUND: skills/dossier-ingest/scripts/file_source.py (mode 100755), tests/test-ingest-file.sh, tests/test-ingest-fetch.sh
- FOUND commits: 177deb4, 6208c26, 85822da
