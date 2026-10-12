# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v1 — client-dossier v1

**Shipped:** 2026-10-13
**Phases:** 7 | **Plans:** 46 | **Sessions:** not tracked (single long-running mission driver from Phase 3 on)

### What Was Built
- `dossier-init`: fixed English layout, `dossier.yaml`, en/fr templates, `AGENTS.md` pointer,
  `git mv` adoption of an existing repository (Phase 1).
- `scripts/lint.py`: Python 3.8+ stdlib linter, E1-E9 and W1-W2, hardened confidential-name check,
  runtime-generated fixtures (Phase 2).
- The `dossier` entry skill and three hooks: sources guard, SessionStart reminder, block-once Stop
  check (Phase 3).
- `dossier-ingest` + `fact-extractor`, `dossier-draft` + `doctrine-reviewer`, `dossier-call` and
  `dossier-status` + `status.py` (Phases 4-6).
- Claude Code and Codex manifests, the `dossier-lint` command, README/LICENSE/CHANGELOG,
  `release.sh`, four isolated install checks, routing eval 1.0 on 8/8 (Phase 7).

### What Worked
- RED before GREEN on every behavioural skill: paid headless baselines (3 runs per variant)
  recorded before each SKILL.md, then GREEN 3/3 with the plugin. Every GREEN came on the first or
  second round, and a git-ancestry test pins the order.
- Fake-`claude` self-tests for each scenario harness (hundreds of assertions, free) caught harness
  bugs before any paid run.
- "Skills carry judgement, scripts carry mechanics, hooks carry reminders" decided where every new
  behaviour went without debate; private scripts in the skill folder made the bare-skills install
  work by plain copy.
- Settling open questions with Samuel through one grouped question (D-01, D-17, 05 D-09, D-18)
  kept phases moving; each answer became a numbered decision cited by tests.
- Agent-run UAT (Samuel delegates recette commands): 6 phases of UAT, 35 of 37 checks passed, the 2 Phase 2
  issues closed by gap-closure plans.

### What Was Inefficient
- The Phase 2 linter took three review/fix rounds (`02-REVIEW.iter1..3`) and four gap-closure
  plans (02-06..09). Each round found new evasions of E5 (markup, entities, format characters).
  An adversarial input list written up front would have saved rounds.
- The Phase 3 Bash guard went through three review rounds before the residual class was accepted
  as debt (D-17). A heuristic over command text has no natural end; the bound should have been set
  before the first round.
- Phases 3, 4 and 5 each needed a second verification pass (`*-VERIFICATION.iter1.md`), so the
  close required acknowledging history snapshots.
- At close, VERIFICATION fingerprints for phases 1-4, 6 and 7 read `stale` because later fix and
  cleanup rounds touched covered files after verification. Re-verifying after each late fix round
  would have given a verified closeout instead of an override.
- Phase 6 and 7 SUMMARY files carry no `one_liner` frontmatter, so the milestone tooling could not
  extract their accomplishments.

### Patterns Established
- A phase-level `CONTEXT.md` with numbered decisions (D-NN) that tests and docs cite by number.
- Scenario harness under `tests/scenarios/`: fixture builder, mechanical verdicts, fake-claude
  self-test, paid runs only by the agent and never in `tests/run.sh`.
- Accepted debt goes to the STATE Deferred Items table and to README "Limits", with the deciding
  session named.
- Every install check runs in a throwaway HOME / `CLAUDE_CONFIG_DIR`; Samuel's configuration is
  compared byte for byte before and after.
- Releases are local only: `scripts/release.sh` bumps both manifests and the CHANGELOG and creates
  an annotated tag; pushing and publishing are separate, approved steps.

### Key Lessons
1. Set the bound of a security heuristic (what it will and will not see) before the first review
   round, and send everything past it to the skill rule and the README.
2. For a name-matching check, write the adversarial corpus first (encodings, markup, homoglyphs,
   format characters) and test it before review.
3. Re-run verification after any fix round that touches covered files, so the milestone closes
   verified rather than by override.
4. Keep the SUMMARY frontmatter complete (`one_liner`, `requirements-completed`); the milestone
   tooling depends on it.
5. Tests that read `.planning/` files break when the milestone is archived. Pin them to archived
   paths, or keep such checks in the docs that ship.

### Cost Observations
- Model mix: not tracked per session; planning and execution ran on the `quality` profile (Opus),
  paid scenarios on Sonnet, command smoke on Haiku.
- Paid scenario spend: a few USD per phase (largest single runs about 2.3-2.5 USD; command smoke
  0.04 USD; Phase 7 UAT 0.024 USD).
- Notable: the free fake-claude self-tests kept the paid spend to baselines and GREEN runs only.

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Sessions | Phases | Key Change |
|-----------|----------|--------|------------|
| v1 | not tracked | 7 | RED-before-GREEN pressure scenarios for every skill; agent-run UAT |

### Cumulative Quality

| Milestone | Tests | Coverage | Zero-Dep Additions |
|-----------|-------|----------|-------------------|
| v1 | 31 files in `tests/run.sh`, 0 failed | not measured (bash + python3 only) | all (Python stdlib only) |

### Top Lessons (Verified Across Milestones)

1. (v1 only so far) Record the failure without the skill before writing the skill.
2. (v1 only so far) Bound every heuristic before reviewing it.
