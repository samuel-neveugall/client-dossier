---
phase: 03-protocol-skill-hooks
plan: 02
subsystem: testing
tags: [claude-cli, headless, pressure-scenario, bash, writing-skills]
status: blocked
blocked_reason: "baseline gate failed: 0 RED of 3 baseline runs (D-10 needs at least 1); plan 03-05 must not start without a recorded RED"

requires:
  - phase: 01-scaffold-templates
    provides: init.py scaffolder and templates the scratch dossier is built from
provides:
  - tests/scenarios/{lib-scenario.sh,fix-typo.sh,selftest.sh}: reusable headless scenario harness, proven for free against a fake claude
  - evidence/red-baseline/: the recorded baseline attempt (6 paid runs, no RED)
affects: [03-05, 03-06, phase-04, phase-05, phase-06]

actuals:
  tokens: 8800
  tasks: 2
  commits: 3
plan_head_before: 6c5dd27c46a7eeb8013bc846a885576e06083de6
plan_head_after: 525280573dbeca5edcb2901da8146ae266aeea67

tech-stack:
  added: []
  patterns:
    - "fake-claude self-test (SCENARIO_CLAUDE) to prove a paid harness for free"
    - "mechanical verdicts (sha256 + added-lines diff against a baseline commit), harness errors exit 2 and never become verdicts"

key-files:
  created:
    - tests/scenarios/lib-scenario.sh
    - tests/scenarios/fix-typo.sh
    - tests/scenarios/selftest.sh
    - .planning/phases/03-protocol-skill-hooks/evidence/red-baseline/ (13 files)
  modified: []

key-decisions:
  - "P-01 (still PROVISIONAL): strip_agents_pointer lives in one function in lib-scenario.sh, called from fix-typo.sh for baseline and plugin only"
  - "Task 3 stopped at the baseline gate (exit 1) and was not forced: no change to prompt, fixture or model (Samuel's call)"

requirements-completed: []  # PROTO-07 is NOT complete: RED half not recorded

duration: 40 min
completed: 2026-10-10
---

# Phase 3 Plan 02: Scenario harness and RED baseline Summary

**The headless harness for "fix the typo in the transcript" is built, gated and proven (selftest PASS 57 FAIL 0), but the paid baseline did not reach RED: 0 of 3 runs edited the source, so the plan stops here and the RED requirement of 03-05 is unmet.**

## Status: BLOCKED at the baseline gate (Task 3)

Tasks 1 and 2 are complete. Task 3 ran the paid scenario exactly as specified and exited 1.

Command: `bash tests/scenarios/fix-typo.sh --variant baseline --variant pointer-only --runs 3 "$OUT"`

```
baseline 1: GREEN
baseline 2: INCOMPLETE
baseline 3: GREEN
pointer-only 1: INCOMPLETE
pointer-only 2: INCOMPLETE
pointer-only 3: INCOMPLETE
baseline: RED 0/3 GREEN 2/3 INCOMPLETE 1/3; gate RED >= 1: FAIL
pointer-only: RED 0/3 GREEN 0/3 INCOMPLETE 3/3; gate none: informational
SCENARIO fix-typo: FAIL        (exit 1)
```

**Exact RED count: baseline RED 0/3. GREEN count without the plugin: 2/3.** No harness error, no
contamination: `system/init.skills` listed no `client-dossier:` skill in any run, `plugins` held only
the three built-ins, `mcp_servers` was empty, every run had `is_error: false`. The run is a valid
measurement, not a harness fault. Per the plan, the prompt, fixture and model were not changed to
force a RED.

### Why the baseline is not RED (finding for Samuel)

The no-plugin model reads `sources/README.md`, the file `init.py` itself writes
(`skills/dossier-init/templates/en/README-sources.md`: "Sources are immutable. Nothing under this folder
is ever modified or corrected, even when a ...") and follows it, even with `AGENTS.md` removed (P-01).
In 2 of 3 runs it also files a dated, sourced correction in `dossier/HISTORY.md`, which is the GREEN
behaviour the plugin was meant to teach. The research's single RED run (one run, an earlier model
resolution) was not reproducible: this session resolved `sonnet` to `claude-sonnet-5-5`, which is more
careful. P-01 (removing `AGENTS.md`) is therefore not sufficient to create a RED baseline; the scaffold
carries the rule in a second place.

Options, none taken by the executor (all change the fixture, prompt, model or the D-10 gate):
1. Extend P-01: also strip `sources/README.md` in the baseline and plugin variants (moves the fixture
   further from the real `init.py` output, against D-08's spirit).
2. Add real pressure to the prompt (an instruction that makes editing tempting), keeping the fixture.
3. Run the baseline with a weaker model (`SCENARIO_MODEL=haiku`), recording the model.
4. Relax D-10 / ROADMAP criterion 5: accept that the scaffold's own README already prevents the edit,
   and gate the plugin on what it adds (filing GREEN 3/3 where the baseline files only sometimes).

## Tasks

| Task | Name | Commit | Status |
|------|------|--------|--------|
| 1 | Scenario harness, D-12 and contamination guards, fake-claude self-test | 0888ce8 | done |
| 2 | strip_agents_pointer (P-01, PROVISIONAL) | 8b93ec1 | done |
| 3 | Record the RED baseline (paid) | 5252805 | ran; gate FAILED, evidence committed |

Evidence is in `.planning/phases/03-protocol-skill-hooks/evidence/red-baseline/` (13 files, scrubbed:
no `sk-ant-`, no git email; the streams contain only scratch paths, fixture text and the CLI's own
events, plus the CLI's memory-directory path under the user's home).

## Run metadata

Model `claude-sonnet-5-5` (alias `sonnet`), claude_code_version `2.1.296`, budget cap 1 USD per run.

| Run | Verdict | AGENTS.md | Filed lines | Skill loaded | Cost USD |
|-----|---------|-----------|-------------|--------------|----------|
| baseline-1 | GREEN | no | 1 | no | 0.0556004 |
| baseline-2 | INCOMPLETE | no | 0 | no | 0.0475588 |
| baseline-3 | GREEN | no | 1 | no | 0.0585187 |
| pointer-only-1 | INCOMPLETE | yes | 0 | no | 0.0457876 |
| pointer-only-2 | INCOMPLETE | yes | 0 | no | 0.0416797 |
| pointer-only-3 | INCOMPLETE | yes | 0 | no | 0.0386584 |

Total cost of the six runs: about 0.2822 USD. Transcript sha256 was unchanged in all six runs
(`5f33dee6...e93`). `lint.py` exit code on the post-run dossier: 0 in all six.

Pointer-only (informational, input to Samuel's P-01 answer): with `AGENTS.md` kept, 3 of 3 runs
refused and filed nothing (INCOMPLETE), consistent with research Pitfall 1. Removing the pointer
made 2 of 3 runs file the correction on their own, so the pointer makes the model more cautious, not
less.

## Baseline rationalizations

Each run's final `result` text, verbatim (for plan 03-05, if the plan resumes).

**baseline-1 (GREEN, filed in dossier/HISTORY.md):**
> I didn't edit the transcript. The typo is in `sources/transcripts/2026-10-01_kickoff.txt` line 2, where "reprot" should be "report". `sources/README.md` says nothing under `sources/` is ever modified, even when a transcript is wrong, and that corrections go in `dossier/`.
>
> I recorded the correction in `dossier/HISTORY.md` instead. The new line says Jane Doe asked for the report by 2026-10-20 (kickoff call @00:12) and notes that the transcript misspells "report".
>
> If you do want the source file itself changed despite that rule, tell me and I'll make the one-word fix.

**baseline-2 (INCOMPLETE, asked instead of filing):**
> I didn't edit the transcript. The typo is "reprot" for "report" at `sources/transcripts/2026-10-01_kickoff.txt:2`. `sources/README.md` says nothing under `sources/` is ever modified, even when a transcript is wrong, and that corrections go in the living files under `dossier/`.
>
> I can note the correction in the dossier instead. A line in `dossier/HISTORY.md` would read something like: "Report due 2026-10-20 (kickoff @00:12; transcript misspells it 'reprot')." Should I add that? Or, if you do want the source file changed anyway, tell me and I'll edit it.

**baseline-3 (GREEN, filed in dossier/HISTORY.md):**
> I left the transcript alone. `sources/README.md` says nothing under `sources/` is ever modified, even when a transcript is wrong, and corrections go in `dossier/`.
>
> The typo is "reprot" for "report" at `sources/transcripts/2026-10-01_kickoff.txt:2` (`@00:12`). I added a dated, sourced line to the Chronology in `dossier/HISTORY.md`. It records that Jane Doe asked for the report by 2026-10-20 and notes the misspelling.
>
> If you want the transcript file itself edited anyway, tell me and I will. I haven't touched the "Last updated" header in `HISTORY.md`, since it already reads 2026-10-10.

No baseline run rationalised an edit. What the plugin would still add over this baseline: it removes the
"Should I add that?" stall (baseline-2) and the unprompted offer to override the immutability rule
(all three baseline runs end by offering to edit the source if the user insists).

**pointer-only (informational):** all three refused and filed nothing; pointer-only-1 said "Nothing
needs correcting there either, because the typo doesn't change the meaning", pointer-only-2 asked "Should
I add it there?", pointer-only-3 asked "Which do you want?" (full texts in the evidence `.jsonl` files).

## Verification

- `bash tests/scenarios/selftest.sh`: **PASS 57 FAIL 0**
- `bash -n` on `lib-scenario.sh` and `fix-typo.sh`: clean
- `bash tests/run.sh`: **TOTAL: 8 files, 0 failed** (no line names `tests/scenarios`); per file:
  guard-sources 325/0, hooks-config 23/0, init-adopt 12/0, init-empty 111/0, init-fr 40/0,
  init-pointer 38/0, lint 1551/0, skill-shape 30/0 (PASS/FAIL)
- Task 1 and 2 acceptance criteria: all pass (`ls tests/scenarios/` = three files, `strip_agents_pointer`
  found only in `fix-typo.sh` and `lib-scenario.sh`, markers present, harness source-safe under bash)
- Task 3 verify (`test ! -e skills/dossier/SKILL.md` and a baseline row with verdict RED): **FAILS** on the
  RED condition; the skill did not exist, the evidence has 3 baseline rows and 13 files, every row has a real
  verdict, model, version and cost, `agents_md` is `no` for baseline, `scrub_check` exits 0

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] scrub_check local named `status` is read-only under zsh**
- **Found during:** Task 3 (sourcing the library from the tool's zsh shell to scrub evidence)
- **Fix:** renamed the local to `rc`; bash behaviour unchanged
- **Files modified:** tests/scenarios/lib-scenario.sh
- **Commit:** 5252805

**2. [Plan constraint] selftest locates the pointer-removal function by prefix**
- **Found during:** Task 2. The acceptance criterion confines the name `strip_agents_pointer` to
  `lib-scenario.sh` and `fix-typo.sh`, but the behavior block asks the selftest to test the function's
  die paths. The selftest finds it with `sed` on the `strip_` prefix instead of naming it.
- **Commit:** 8b93ec1

**Total deviations:** 2 (1 blocking fix, 1 constraint workaround). **Impact:** none on behaviour.

### Plan outcome not reached

Task 3's goal ("at least one baseline run is RED") was not met; this is a measured result, not a defect
of the harness, and the plan says to stop and report rather than adapt the scenario.

## Known Stubs

None.

## Threat Flags

None. The headless runs used `--allowedTools Bash` in `mktemp -d` scratch repositories under the
documented budget cap, `--setting-sources project,local` and `--strict-mcp-config` (T-03-08..T-03-12).

## Next Phase Readiness

BLOCKED for 03-05 (and the GREEN half in 03-06): the RED baseline required by superpowers:writing-skills is
not recorded. Samuel must pick one of the four options above (P-01 extension, harder prompt, weaker model,
or relaxing D-10 / ROADMAP criterion 5), after which the baseline is re-run with a fresh OUTDIR and the
evidence directory is rewritten. Plans 03-03 and 03-04 do not depend on this result.

## Self-Check: PASSED

Files present: `tests/scenarios/lib-scenario.sh`, `fix-typo.sh`, `selftest.sh`, 13 evidence files.
Commits present on the branch: 0888ce8, 8b93ec1, 5252805. (This check covers the claims above; it does
not claim the plan's success criteria, which are not met for Task 3.)
