# Mission 2026-09-25: Phase 2 gap closure (Linter & Test Harness)

Manager: vf-dev-manager · Mode: autonomous (explicit go-ahead from Samuel on 2026-09-25, relayed
by vibeflow-head) · Branch: `feat/phase-02-gap-closure` (from `main@8c2ed0f`, not merged: there is
no remote, so no PR) · Driver lock: owner `vf-dev-manager-phase2-gapclosure-2026-09-25`, acquired
and then released.

## Verdict

Partial by design: all automated work is green, and the phase stops at **awaiting human recette**.
Phase 2 is NOT marked complete.

## Battle plan (DAG)

The DAG file is in the session scratchpad, not the repository, to keep the working tree clean for
the executors.

- `exec-02gaps`: `gsd-execute-phase 02 --gaps-only`, running 02-07 → 02-08 → 02-09 serially,
  all three on `scripts/lint.py`.
- `revue-02gaps`: vf-reviewer, called directly on the range. `verif-02gaps`: gsd-verifier on the
  final SHA. `tracking`: the manager updates STATE and ROADMAP. `docs`: a read-only audit, since
  `[doc-drift]` was active (69 code commits since the last doc update).
- Added during the mission: `cr02-human` and `cr02-threshold-human` (the two escalations to
  Samuel), `fix-cr02`, `fix-cr02-bis`, and `revue-cr02` (review turn 3).

Startup gates: lock `acquired: true`. `check-mission-invariants.sh` returned **4 = INDETERMINATE**,
because `.planning/MISSION-INVARIANTS.md` is absent: no invariant was verified, and none is cited
as evidence. `workflow._auto_chain_active` and `workflow.auto_advance` were reset to false (both
were already false). The untracked `.gsd/` was out of scope and was never touched.

## Per plan

| Plan | Gaps | Commits |
|---|---|---|
| (pre) | preserve the iteration-3 review | 34f3214 |
| 02-07 | G-02-2, G-02-4d | b224542, 91581ea, f116a8d, 288c730 |
| 02-08 | G-02-4a, G-02-4e | 6f881ac, d50c3a2, 52d1d85 |
| 02-09 | G-02-4f, G-02-4c, G-02-4b | 856b5bc, 7ca0e42, 616e7e7, 2aa8b69 |
| engine code review | turn 1: 3 critical, 2 warnings, 2 info | e198d4b (`02-REVIEW.md`) |
| fix round 1 | CR-01, CR-03, WR-02, IN-01, IN-02 | cca05d2, a777086, 66f9464, 9019a26, 9b6cf7d, 45983c2, 0bd363a |
| fix round 2 | CR-02 option (a) | b51b670, b7c8b5f |
| fix round 3 | CR-02 bis option (2) | c1ed6bb, df7f9ea |
| re-verification | 13/13, human_needed | c2a7f29 |

Calibration, copied verbatim from the plans and SUMMARYs (estimate / actuals):
02-07 `{tokens: 45000, raw_tokens: 45000, tasks: 2, confidence: low}` / `{tokens: 3583, tasks: 2, commits: 2}`;
02-08 `{tokens: 50000, raw_tokens: 50000, tasks: 2, confidence: low}` / `{tokens: 4742, tasks: 2, commits: 2}`;
02-09 `{tokens: 70000, raw_tokens: 70000, tasks: 3, confidence: low}` / `{tokens: 6870, tasks: 3, commits: 3}`.

Engine hook verdicts, copied verbatim from the executor: `code_review: fail` (turn 1, the findings
below), `nyquist: absent`, `secure: absent`. The executor deliberately stopped the engine pipeline
before nyquist, secure and the verifier once the review found critical gate regressions.

## Review

- **Turn 1** (engine gsd-code-reviewer, e198d4b): gaps_found. The fixes had introduced three
  critical regressions of the confidentiality gate:
  - CR-01: an `Outbound/` holding its own `dossier.yaml` was pruned as a sub-dossier before the
    new E1 could fire.
  - CR-02: a misspelt `confidential_names` next to the exact key was ignored.
  - CR-03: `init.py` mapped each format character to a space and lost names containing `&` or `+`.
- **Turn 2** (vf-reviewer, 0bd363a): passed, full regime. `git fsck --full --strict` was clean.
  The range was linear (20 commits), with exact trailers and no `.gsd/` file committed.
  1479 assertions. One minor no-op (OBS-01).
- **Turn 3** (vf-reviewer, df7f9ea): passed, full regime. The truth table was reproduced
  independently; mutations "drop the last-word clause" and "drop the OSA <= 1 clause" are both
  killed, and no mutation survives. Three minor no-op findings, recorded as debt:
  - the OSA <= 1 clause also flags a one-letter substitution anywhere in the key;
  - `_fold_key` is computed twice;
  - `_osa_distance` has no internal length guard and is safe only through its call sites.
- Budget: 3 review turns used out of 3, and 3 fix rounds. Two of the fix rounds were driven by
  Samuel's arbitrations on the same finding (CR-02).
- The plumbing workaround for the rtk hook was used in round 1: isolated worktrees, followed by
  `--ff-only` merges. The integrity audit came back clean on both ranges.

## Verification

`02-VERIFICATION.md` was re-verified on df7f9ea: `status: human_needed`, 13/13 automated truths
(4 ROADMAP criteria, 2 Phase 1 debts, 7 UAT gap truths). `bash tests/run.sh`: `TOTAL: 6 files,
0 failed`. `tests/test-lint.sh`: 1494 assertions. Fresh `en`/`fr` scaffolds lint with
`0 error(s), 0 warning(s)`. Three human_verification items remain for Samuel:
1. re-test UAT item 2 with the CR-02 bis rule;
2. re-test UAT item 4 by hand;
3. accept or reject the residual debts.

## Documentation

This was a read-only audit (autonomous regime, docs-flow D-04). Result: passed. Nothing is stale
in `CLAUDE.md`, spec §3.2, §4.4 or §6, or `skills/dossier-init/SKILL.md`. The new mechanics are
**silent** in those docs, which is acceptable before the Phase 7 docs. No generation was run.

## Decisions

- **Samuel (relayed by the main session via SendMessage, 2026-09-25)**: CR-02 option (a). A
  near-miss of `confidential_names` stays C1 beside the exact key; consent_* near-misses keep the
  presence exemption.
- **Samuel (same channel, 2026-09-25)**: CR-02 bis option (2). This superseded (a)'s literal
  "<= 2" wording, which relied on a wrong distance claim: `confidential_notes` is 2 edits away,
  not 4+.
- **Manager, reversible**:
  - the CR-02 bis last word is compared to "name" OR "names", in the strict direction, so that
    `confidential_nam` is C1 as Samuel expected;
  - the rule applies at the top level and nested alike;
  - D-FIX-13: `init.py` writes both readings of a format character as two list entries;
  - the superseded review and fix reports were preserved as `.iter3` / `.iter2`;
  - the DAG was kept in the scratchpad.
- **Manager error, caught by the reviewer**: the turn-3 mandate cited `confidential_nmes` as an
  example of the residual limit. It is OSA 1 and is caught. The code docstring and `02-CONTEXT.md`
  are correct.

## Debt carried to the recette

- WR-01: E5 ignores Cf only, not the wider default-ignorable set.
- OBS-01: a name starting with `>` is not rejected at runtime.
- CR-02 bis residual: a double typo inside the last word stays ignored beside the exact key.
- `_osa_distance` has no length guard.
- CI skip visibility: WR-02 is now visible as a SKIP line.

## Cost

8 minds dispatched: vf-coder ×5 (execution, fix r1, fix CR-02, fix CR-02 bis, re-verification),
vf-reviewer ×2, general-purpose ×1 (docs audit). Subagent tokens reported by the harness:
224679 + 201455 + 190940 + 159181 + 124342 (vf-coder), 129945 + 107016 (vf-reviewer), 86637
(docs), for a total of 1224195.

## Preuves E6

Copied verbatim from the typed worker blocks, plus the manager's own final run. Omitted: three
`{"verdict": "recette", "preuve": "amont"}` entries that the fix-round coders emitted. No recette
ran, because the recette is Samuel's and still pending, so relaying those entries would claim a
verdict nobody gave.

```json
{"preuves": [
  {"verdict": "gate:tests", "commande": "bash tests/run.sh", "exit_code": 0, "sha": "2aa8b69"},
  {"verdict": "gate:tests", "commande": "bash tests/run.sh", "exit_code": 0, "sha": "0bd363a9254481edd30fd11d06169256adef49e0"},
  {"verdict": "revue", "commande": "git fsck --full --strict", "exit_code": 0, "sha": "0bd363a9254481edd30fd11d06169256adef49e0"},
  {"verdict": "revue", "commande": "bash tests/test-lint.sh", "exit_code": 0, "sha": "0bd363a9254481edd30fd11d06169256adef49e0"},
  {"verdict": "gate:tests", "commande": "bash tests/run.sh", "exit_code": 0, "sha": "df7f9eae2b295db1c52ca003eb91d6355338b62f"},
  {"verdict": "revue", "commande": "git fsck --full --strict", "exit_code": 0, "sha": "df7f9eae2b295db1c52ca003eb91d6355338b62f"},
  {"verdict": "revue", "commande": "bash tests/run.sh", "exit_code": 0, "sha": "df7f9eae2b295db1c52ca003eb91d6355338b62f"},
  {"verdict": "revue", "preuve": "amont"},
  {"verdict": "gate:tests", "commande": "bash tests/run.sh", "exit_code": 0, "sha": "c2a7f29bdde402dcfee9a6a26863691503d6e95f"}
]}
```

## Next step

Samuel runs the recette: `/gsd-verify-work 02`, on branch `feat/phase-02-gap-closure`. If it
passes, fast-forward merge into `main`, then close Phase 2 and open Phase 3 planning. The Stop hook
question is still open there, with Samuel.
