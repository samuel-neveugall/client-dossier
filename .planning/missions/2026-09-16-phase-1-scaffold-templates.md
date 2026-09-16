# Mission: Phase 1 — Scaffold & Templates

**Date:** 2026-09-16
**Manager:** vf-dev-manager
**Brief:** run Phase 1 end to end — plan, execute, verify, review — to a verified, closed phase.
**Branch:** `main` (config `git.branching_strategy: "none"` — no branch, by project configuration)
**Range:** `fb18a9b..465452a`

## Plan of battle (DAG, 6 nodes)

| Node | Stage | Deps | Scope |
|---|---|---|---|
| `plan-01` | plan | — | `.planning/phases/01-scaffold-templates/**` |
| `exec-01` | build | plan-01 | `skills/**`, `tests/**`, `.claude-plugin/**`, `docs/**`, `CLAUDE.md` |
| `revue-01` | review | exec-01 | read-only |
| `verif-01` | acceptance | exec-01 | read-only |
| `audit-01` | audit | exec-01 | read-only |
| `docs-01` | doc hygiene | the three judges | `.planning/**` |

The three judges were dispatched in parallel (read-only, no collision risk).
`exec-01` was reopened twice; the review node carried the forced `review_regime=full`
(comblement guard — no lightening ever applies to a fix diff).

## Startup gates

- Driver lock acquired, generation `DRIVER.lock.gen.1789576467.18086`; `Fence:` trailer on
  the first commit of the run (`4b9d0d0`). Heartbeat held across every stage.
- Mission invariants: **INDETERMINATE** — no `.planning/MISSION-INVARIANTS.md` exists. No
  invariant was cited as proof anywhere in this mission.
- Chaining flags already disarmed (`workflow.auto_advance: false`, no `_auto_chain_active`).
  `gsd_run` not on PATH — reset was best-effort, recorded here.
- Two `[mission-watchdog] stall` signals fired during long single-node stages. Both are
  structural false positives: `progress_epoch` only advances on `dag.sh mark`, and the plan
  and judge nodes each ran ~45 min without a transition. No action taken.

## Delivered

- `skills/dossier-init/SKILL.md` — the init skill (judgement layer).
- `skills/dossier-init/scripts/init.py` — Python 3.8 stdlib-only, non-interactive.
- `skills/dossier-init/templates/{en,fr}/` — 24 templates (7 living files + CONTEXT +
  DOCTRINE + 3 READMEs + pointer, in two hand-maintained language variants).
- `tests/` — 5 bash files, 101+ assertions, bash + python3 only, no third-party dependency.
- `.claude-plugin/plugin.json` — minimal 3-key manifest (SCAF-08).
- `docs/superpowers/specs/2026-09-16-client-dossier-design.md` §4 amended per D-06.
- `CLAUDE.md` brought into agreement with the code and the amended spec.

6 plans, 5 waves, 31 commits.

## Verdicts

| Node | Round 1 | Round 2 | Round 3 (final) |
|---|---|---|---|
| plan-01 | `passed` (plan-checker: VERIFICATION PASSED, 25/25 at the post-planning gate) | — | — |
| exec-01 | `human_needed` (mechanical layer green) | `passed` | `passed` |
| revue-01 | `gaps_found` (2 major) | `gaps_found` (2 blocking, 2 major) | `gaps_found` (2 major, judged non-blocking by the manager) |
| verif-01 | `passed` | `passed` | `passed` |
| audit-01 | `gaps_found` (all no-op) | `gaps_found` (2 high) | `gaps_found` (all no-op) |
| docs-01 | `human_needed` (records the pending human gate) | — | — |

**Final state:** 5/5 ROADMAP success criteria and 8/8 SCAF-01…08 requirements reproduced
**independently** by the acceptance judge, including SCAF-06 replayed against the real origin
repository. Threat T-01-01 **CLOSED**. Confidentiality guarantee **D-13 CONFIRMED**.
`bash tests/run.sh` → 5 files, 0 failed. Nominal output byte-identical across all fixes.

## Correction loop (3 rounds, budget spent)

1. **Round 1** — `role` emitted into `dossier.yaml` without `yaml_quote()` (a role containing
   `:` produced an unparsable config); a false file-count claim in the bare-skills fallback.
2. **Round 2** — all three judges converged independently: the round-1 fix treated the symptom,
   not the cause. `language` and `status_header` still bypassed quoting, with `exit 0` on a
   corrupted file and a forgeable duplicate `consent_recorded: true` key. Plus two test-quality
   defects: a forbidden PyYAML import, and a regression test that was a **false green**.
3. **Round 3** — cause fixed structurally (single `emit_scalar()` emission path + allowlist,
   `--status-header` constrained by `choices`). Judges confirmed closure; two residual items
   remained (below).

## Decisions taken by the manager

- **Deviation D-05/D-06 assumed.** `init.py` and `templates/{en,fr}/` live inside the skill
  folder; `scripts/lint.py` stays at the root. Spec §4 and `CLAUDE.md` amended in the same
  phase, per `CLAUDE.md`'s own precedence rule. Reversibility: costly.
- **`branching_strategy: "none"` respected as configured** — committed on `main`, no branch,
  no PR. This overrides the default team rule, on the project's own configuration.
- **Synthetic adoption fixture accepted over my own instruction.** I had asked for the SCAF-06
  test to run against a disposable copy of the origin repository; the planner instead built a
  synthetic fixture from a redacted structural audit, so nothing in `tests/` ever touches the
  confidential repository. Stricter than D-13 required — accepted. The real-repository run was
  kept as a manager-side acceptance check (copy → blank every file → run → delete), never
  committed.
- **`allowed-tools` is not a security control.** Settled by documentary research after the
  reviewer and the auditor contradicted each other: it is a **pre-approval** scoped to the
  skill's turn, not a restriction — an unlisted tool is never blocked, it falls back to the
  normal permission prompt. Neither judge was right. Not to be counted as a mitigation in any
  future threat model.
- **Correction budget stopped at 3 rounds.** Two residual items were carried as tracked debt
  rather than fixed in a fourth round (see below). Two of three judges — including the security
  auditor whose own threat was at stake — classified them non-blocking; neither breaks a
  ROADMAP criterion or a SCAF requirement.

## Debt carried to Phase 2

Recorded in `.planning/STATE.md` (Deferred Items) and in the Phase 2 section of
`.planning/ROADMAP.md`.

- **(a) YAML 1.1 reserved words.** `_SAFE_PLAIN_SCALAR_RE` (`^[A-Za-z][A-Za-z0-9_-]*$`) lets
  `yes`, `no`, `on`, `off`, `true`, `false`, `null`, `y`, `n` through unquoted. Concrete, not
  theoretical: `no` is the ISO 639-1 code for Norwegian, so `--language no` writes
  `language: no`, which a faithful parser reads as boolean `False`. Not a vulnerability (no key
  injection; `consent_recorded` is out of reach) — a type-fidelity defect. Found independently
  by all three judges. Fix it when writing `lint.py`'s YAML-subset parser, so producer and
  consumer are aligned in one move.
- **(b) Regex anchor.** Same expression: Python's `$` also matches just before a trailing `\n`,
  where `\Z` / `re.fullmatch` would be strict. A value ending in a newline passes the allowlist.
  No key injection possible — cosmetic, but a real bypass of the guard. One-line fix, to be done
  with (a).

## Open points for Samuel

1. **Human verification gate — the real blocker.** Config is `human_verify_mode: end-of-phase`.
   Two behaviours cannot be exercised outside a live session, and both are listed in
   `.planning/phases/01-scaffold-templates/01-VERIFICATION.md` §Human Verification:
   - the conversational grouped question and language inference of `dossier-init`, run in a
     real `claude --plugin-dir .` session in a throwaway repo;
   - the confirm/decline branch of the adoption `git mv`.
   Phase 1 is **not** ticked complete in the ROADMAP until these pass.
2. **`allowed-tools` frontmatter.** Left untouched on purpose. The live session above is the
   experiment that settles whether `${CLAUDE_SKILL_DIR}` interpolates inside the pattern
   (research confidence 85% that it does not, which would make the field inert).
3. **`claude plugin validate . --strict`** fails on two advisory warnings only (missing
   `author`, root `CLAUDE.md` not loaded as plugin context). Non-blocking; `author` belongs to
   the Phase 7 full manifests. Decide there which invocation is the permanent SCAF-08 gate.
4. **`SECURITY.md` absent** — the accepted risk (stdlib only, no dependency manifest) is true
   and verified but never formalised.
5. **Process note.** A global `rtk hook claude` blocked `git status/add/commit` inside the
   executors' isolated worktrees; they worked around it with git plumbing. The reviewer audited
   the range specifically for this: `git fsck` clean, trees coherent, no lost or phantom blobs,
   the single merge lossless.

## Next step

Run the two live-session checks of §Open points 1 in a throwaway repo with
`claude --plugin-dir .`. On green: tick Phase 1 in the ROADMAP, then plan **Phase 2 — Linter &
Test Harness**, attaching debt items (a) and (b) to its plan, since `lint.py`'s parser is where
both are properly settled.
