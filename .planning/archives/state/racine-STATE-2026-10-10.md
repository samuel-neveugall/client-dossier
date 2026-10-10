**Velocity:**
- Total plans completed: 9 (Phase 1, waves 1-5)
- Average duration: -
- Total execution time: -

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 1 | 6/6 | - | - |
| 02 | 9 | - | - |

**Recent Trend:**

- Last 5 plans: 01-02, 01-03, 01-04, 01-05, 01-06 — all landed, all passed final
  acceptance re-verification
- Trend: on track; Phase 1 closed on the human gate 2026-09-17

*Updated after each plan completion*
**Per-Plan Metrics:**

| Plan | Duration | Tasks | Files |
|------|----------|-------|-------|
| Phase 02 P01 | 8min | 3 tasks | 4 files |
| Phase 02 P02 | 7min | 3 tasks | 3 files |
| Phase 02 P03 | 3min | 2 tasks | 2 files |
| Phase 02 P04 | 6min | 3 tasks | 3 files |
| Phase 02 P05 | 6min | 3 tasks | 25 files |
| Phase 02 P06 | 8min | 3 tasks | 3 files |
| Phase 03 P01 | 25 min | 2 tasks | 5 files |
| Phase 03 P03 | 2 min | 3 tasks | 5 files |
| Phase 03 P04 | 6 min | 3 tasks | 6 files |

Two decisions taken by the mission manager during the Phase 2 planning mission (2026-09-17),
both with Samuel offline, both reversible, both recorded verbatim in
`.planning/phases/02-linter-test-harness/02-CONTEXT.md`:

- **D-24 — YAML typing: per-field schema in `lint.py` + minimal producer hardening.** Settled
  by a research panel over four options. The parser returns raw strings only (no implicit
  int/bool/null resolution); a per-field schema above it types `version`/`staleness_days` as
  ints and `consent_recorded` as a strict YAML 1.2 Core boolean (`true|True|TRUE` /
  `false|False|FALSE` unquoted only — `yes`, `1`, `"true"` are errors, never coerced to true,
  because that field is the gate that disables the confidential-name leak check). `init.py`
  keeps a pure serialisation rule: `re.fullmatch` (debt (b)) and quoting of YAML 1.1 reserved
  words (debt (a)), so `--language no` writes `language: "no"`. This closes both Phase 1 debts
  and aligns producer and consumer in one move, as the ROADMAP asked.
- **D-28 — the clean lint fixture is generated at test time, not committed.** D-28 and D-31
  were locked and not jointly satisfiable: git tracks no empty directory, so a committed
  scaffold silently drops `sources/transcripts/` and stops matching `init.py`'s output. D-31's
  purpose (producer and linter stay in sync) wins, because ROADMAP criterion 1 must assert
  something about the scaffolder. `tests/fixtures/lint/fr/` stays committed. The reversal is a
  scoped edit to plan 02-05, already written out in `02-01-PLAN.md`.

Earlier decisions are logged in PROJECT.md Key Decisions table. Four decisions from the Phase 1
mission, now validated by the phase's own delivery:

- Bootstrap: fixed English folder/file names, Markdown fact-lines over structured data, one
  router skill + five task skills, hooks-enforce-never-perform-work — all carried from the
  source spec's own alternatives-considered section (§9), validated by Phase 1's delivery.
- **D-05/D-06 — embedded skill resources, assumed deviation.** `skills/dossier-init/scripts/init.py`
  and `skills/dossier-init/templates/{en,fr}/` live inside the skill's own folder (Agent
  Skills bundled resources), while `scripts/lint.py` stays at the repo root. Spec §4 and
  `CLAUDE.md` were amended during this phase per `CLAUDE.md`'s own precedence rule (spec wins,
  this file follows). Reversal would be costly — treat as settled unless a strong reason
  emerges.
- **Synthetic adoption fixture.** The SCAF-06 test relies on a disposable fixture rebuilt from
  a *redacted* structural audit, and never touches the confidential origin repository. This
  goes stricter than D-13 required; kept deliberately rather than loosened back to the letter
  of the guarantee.
- **`allowed-tools` is not a security control.** Backed by documentation research: this
  frontmatter field is a pre-approval valid for the skill's turn, not a restriction — a tool
  absent from the list is never blocked, it just falls back to the normal permission prompt.
  Do not count it as a mitigation in any future threat model.
- **Correction budget exhausted at 3 rounds.** Two residual findings (see Deferred Items
  below) were classified as tracked debt rather than fixed in a 4th round.
- [Phase 02]: 02-01: sanitise_path also escapes C1 controls, surrogate-escaped bytes and U+2028/2029 (T-02-01 hardening beyond 0x00-0x1F/0x7F)
- [Phase 02]: 02-01: an invalid JSON dossier.yaml is C1 (exit 1), not unreadable (exit 2); a nonexistent PATH exits 2 with its own message
- [Phase 02]: 02-01: forged-name end-to-end \x0a assertion deferred to 02-02 (needs E4); pinned meanwhile by a direct report() probe, tracked in WINDOWS.md
- [Phase 02]: 02-02: status-header lines are anchored -- only comment syntax may precede a protocol field, so prose mentioning Deadline: is not a header
- [Phase 02]: 02-02: an unreadable non-binary outbound file is E1, never silently skipped
- [Phase 02]: 02-02: E5 searches the whole path below outbound/ and ignores the README exemption; E1-E4 honour it
- [Phase 02]: 02-03: the producer quotes any value whose casefold is a YAML 1.1 reserved spelling (YES/No too), and the allowlist uses fullmatch
- [Phase 02]: 02-03: a bash payload that must end in a newline needs a sentinel, command substitution strips it
- [Phase 02]: 02-04: E8 reads Tree.dirs from the single walk (pruning decided in one place); E9 is scoped to direct children of outbound/deliverables/, the reverse (source without render) silent
- [Phase 02]: 02-04: the nine-class sweep checks each e1..e9 fixture against all twelve other identifiers (C0 included) plus an exact 1/0 summary; W1/W2 are already in ALL_IDS for 02-05
- [Phase 02]: 02-04: generator refusal is proven with a logging mktemp shim on PATH, because macOS mktemp -d ignores TMPDIR
- [Phase 02]: 02-05: W1/W2 keep the uniform check(root, tree, config, findings) signature; an unlisted language skips both W1 and W2 with one info: line (D-20)
- [Phase 02]: 02-05: D-28 as amended applied -- tests/fixtures/lint/fr/ is the only committed lint fixture; a test asserts no tests/fixtures/lint/clean/ is tracked
- [Phase 02]: 02-06: round-trip test matches ^info: language 'no' exactly (the info line always contains 'no word list')
- [Phase 02]: 02-06: lint.py file-size window recorded as WINDOWS row 4; single file kept, split is a Phase 7 conversation
- [Phase 02]: gap closure (2026-09-25): CR-02: a near-miss of `confidential_names` stays C1 beside the exact key (consent_* near-misses keep the presence exemption) — arbitrage Samuel, relayed by the main session via SendMessage, 2026-09-25, option (a)
- [Phase 02]: gap closure (2026-09-25): CR-02 bis: the rule is OSA <= 1, or OSA <= 2 with the last `_` word within 1 edit of "name"/"names", so `confidential_notes` and `non_confidential_names` stay clean — arbitrage Samuel, relayed by the main session via SendMessage, 2026-09-25, option (2), superseding the first answer's literal "<= 2" wording (confidential_notes is 2 edits away, not 4+); the "name" alternative is a manager precision, strict direction, reversible
- [Phase 02]: gap closure (2026-09-25): D-FIX-13 (manager arbitration, reversible): `init.py` writes both readings (space, deletion) of a Unicode format character in a confidential name as two list entries when they differ
- [Phase 02]: gap closure (2026-09-25): the iteration-3 review and the iteration-2 fix report were preserved as `02-REVIEW.iter3.md` / `02-REVIEW-FIX.iter2.md` before being superseded
- [Phase 03]: 03-01: Bash guard also scans command-substitution bodies visible to shlex; opaque constructs stay allowed (D-04 heuristic)
- [Phase 03]: Stop hook ships in v1 and blocks once (stop_hook_active lets the second stop through) — In Claude Code a non-blocking Stop hook only reaches the human; updating the dossier before handing back is the agent's behaviour (D-01)
- [Phase 03]: 03-04: P-02 stays provisional - the Stop reason names dossier-status only when CLAUDE_PLUGIN_ROOT/skills/dossier-status/SKILL.md exists (status_sentence())

