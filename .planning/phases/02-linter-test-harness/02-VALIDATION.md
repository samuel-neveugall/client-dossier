---
phase: "02"
slug: "linter-test-harness"
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-09-17"
---

# Phase 02 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Seeded from `02-RESEARCH.md` § Validation Architecture. The Per-Task Verification Map is
> filled by `/gsd-validate-phase` once the plans' task IDs exist.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | bash 3.2 + python3 3.8+, hand-rolled assertions in `tests/lib.sh` — no third-party framework (spec §7, `CLAUDE.md`) |
| **Config file** | none — `tests/run.sh` is the dispatcher and needs no config |
| **Quick run command** | `bash tests/test-lint.sh` |
| **Full suite command** | `bash tests/run.sh` |
| **Estimated runtime** | ~5 seconds (Phase 1 suite is sub-second per file; fixture generation dominates) |

---

## Sampling Rate

- **After every task commit:** Run `bash tests/test-lint.sh` — and `bash tests/test-init-empty.sh`
  in addition for any task that touches `skills/dossier-init/scripts/init.py`.
- **After every plan wave:** Run `bash tests/run.sh` — must report every test file passing,
  Phase 1's five included.
- **Before `/gsd-verify-work`:** Full suite green **plus** `python3 scripts/lint.py` against a
  dossier freshly scaffolded by `init.py`, in `en` and in `fr`, both printing
  `0 error(s), 0 warning(s)`.
- **Max feedback latency:** 10 seconds.

### Coverage target (stated as counts, so a plan can be checked against it)

| Class | Positive assertion (it fires) | Negative assertion (it does not fire spuriously) |
|-------|-------------------------------|--------------------------------------------------|
| E1…E9 | 9 — one per error fixture | for each fixture, assert every *other* error identifier is absent |
| W1, W2 | 2 — on the French fixture | 2 — absent on both clean fixtures |
| C1 (config typing) | 3 — `consent_recorded: yes`, `consent_recorded: "true"`, `staleness_days: abc` | 1 — absent on both clean fixtures |
| exit codes | 3 — 0 (clean), 1 (each error fixture), 2 (no dossier found) | — |

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| TBD — filled by `/gsd-validate-phase` once plan task IDs exist | — | — | LINT-01 | — | — | integration | `bash tests/test-lint.sh` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

### Requirement → behaviour → command (pre-task map, from RESEARCH)

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| LINT-01 | Clean scaffold → exit 0, zero findings (ROADMAP crit. 1) | integration | `bash tests/test-lint.sh` | ❌ Wave 0 |
| LINT-01 | Each of E1…E9 fires, and **only** it (ROADMAP crit. 2) | integration | `bash tests/test-lint.sh` | ❌ Wave 0 |
| LINT-01 | French fixture → exit 0 with W1+W2, English `Last updated:` found (crit. 3) | integration | `bash tests/test-lint.sh` | ❌ Wave 0 |
| LINT-01 | No `dossier.yaml` upward → exit 2 + stderr text (D-02) | integration | `bash tests/test-lint.sh` | ❌ Wave 0 |
| LINT-01 | Sub-dossier is a boundary (D-03) | integration | `bash tests/test-lint.sh` | ❌ Wave 0 |
| LINT-01 | Output sorted by path then line, stable across two runs (D-04) | integration | `bash tests/test-lint.sh` (diff two runs) | ❌ Wave 0 |
| LINT-01 | `consent_recorded: yes` and `: "true"` → exit 1, config identifier, field named (D-24.4) | integration | `bash tests/test-lint.sh` | ❌ Wave 0 |
| LINT-01 | JSON fallback under the `dossier.yaml` name parses (D-25) | integration | `bash tests/test-lint.sh` | ❌ Wave 0 |
| LINT-01 | `init.py --language no` → `^language: "no"$` (debt (a)) | unit | `bash tests/test-init-empty.sh` (extended) | ✓ exists, extend |
| LINT-01 | `--language $'en\n'` → no blank line after the value (debt (b)) | unit | `bash tests/test-init-empty.sh` (extended) | ✓ exists, extend |
| LINT-01 | Round-trip `init.py --language no` → `lint.py` parser reads `"no"` (D-24.4) | integration | `bash tests/test-lint.sh` | ❌ Wave 0 |
| LINT-02 | Clean + French fixtures exist and are materialisable | integration | `bash tests/test-lint.sh` | ❌ Wave 0 |
| LINT-02 | Nine error fixtures generated at runtime under `mktemp -d` | integration | `bash tests/fixtures/make-lint-fixtures.sh` | ❌ Wave 0 |
| LINT-03 | The whole suite is green, Phase 1 included | integration | `bash tests/run.sh` | ✓ dispatcher exists |
| LINT-03 | `scripts/lint.py` is executable and shebanged (Phase 1 convention) | unit | `assert_exec` in `tests/test-lint.sh` | ❌ Wave 0 |

---

## Wave 0 Requirements

- [ ] `scripts/lint.py` — the subject under test; `scripts/` itself does not exist yet
- [ ] `tests/test-lint.sh` — covers LINT-01 and LINT-03
- [ ] `tests/fixtures/make-lint-fixtures.sh` — covers LINT-02
- [ ] `tests/fixtures/lint/fr/` — covers LINT-02 and ROADMAP criterion 3
- [ ] `tests/lib.sh` additive helpers (`lint_py`, plus lint assertion helpers) — covers LINT-03
- [ ] Framework install: **none required** — bash and python3 are already present

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| A dossier scaffolded interactively through the loaded plugin lints clean | LINT-01 | `human_verify_mode: end-of-phase`; the interactive scaffold path is only reachable in a live `claude --plugin-dir .` session | Scaffold a dossier in a scratch repo via the `dossier-init` skill, then run `python3 scripts/lint.py` inside it; expect `0 error(s), 0 warning(s)` |

---

## Blind spots the plan must close explicitly

A green suite with a broken linter is reachable through each of these; the plan has to forbid
them by construction, not by vigilance.

1. **Asserting only "exit 1" on an error fixture** — all nine exit 1 for *any* error. Pair every
   positive identifier assertion with the negative sweep over the other identifiers.
2. **A clean fixture that is not what `init.py` produces** — criterion 1 becomes a tautology if
   the tree was hand-edited until the linter passed.
3. **`consent_recorded: "true"` asserted only on exit code** — the correct behaviour (config
   error) and the bug (silent coercion to true, then a consent-source error) both exit 1.
   Assert the identifier *and* the field name.
4. **W1/W2 asserted only by count** — "4 warnings" passes when W1 fires 4 times and W2 never
   does. Assert each identifier, and the path/line where practical.
5. **No word-boundary bait in the French fixture** — without `fichier` / `hiérarchie`, a linter
   with no word boundaries passes every test and floods a real French dossier.
6. **The Phase 1 suite not re-run after the `init.py` edit** — `tests/test-lint.sh` alone cannot
   see a Phase 1 regression; `bash tests/run.sh` is a mandated, separate check.
7. **Output stability asserted by eyeballing** — diff two consecutive invocations.
8. **E5 tested only with a name in the body** — the filename match is a separate code path, and
   it is the one a naive `(?<!\w)` boundary breaks on a `YYYY-MM-DD_slug` name.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
