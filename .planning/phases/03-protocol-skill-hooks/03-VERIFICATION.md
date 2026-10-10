---
phase: 03-protocol-skill-hooks
verified: 2026-10-10T00:00:00Z
status: gaps_found
score: 6/6 roadmap criteria verified, 1 requirement clause failed (PROTO-05 Bash guard)
covered_files:
  - .planning/phases/03-protocol-skill-hooks/03-01-PLAN.md
  - .planning/phases/03-protocol-skill-hooks/03-01-SUMMARY.md
  - .planning/phases/03-protocol-skill-hooks/03-02-PLAN.md
  - .planning/phases/03-protocol-skill-hooks/03-02-SUMMARY.md
  - .planning/phases/03-protocol-skill-hooks/03-03-PLAN.md
  - .planning/phases/03-protocol-skill-hooks/03-03-SUMMARY.md
  - .planning/phases/03-protocol-skill-hooks/03-04-PLAN.md
  - .planning/phases/03-protocol-skill-hooks/03-04-SUMMARY.md
  - .planning/phases/03-protocol-skill-hooks/03-05-PLAN.md
  - .planning/phases/03-protocol-skill-hooks/03-05-SUMMARY.md
  - .planning/phases/03-protocol-skill-hooks/03-06-PLAN.md
  - .planning/phases/03-protocol-skill-hooks/03-06-SUMMARY.md
  - hooks/guard-sources.py
  - hooks/hooks.json
  - hooks/session-start.py
  - hooks/stop-check.py
  - skills/dossier/SKILL.md
covered_digest: "v3:sha256:b12737443c6474d72843713dade3d50b07ac653efbdaec0677a198142ae0f03d"
behavior_unverified: 0
overrides_applied: 0
gaps:
  - truth: "PROTO-05: a heuristic PreToolUse guard on Bash denies commands that visibly modify an existing file under sources/ (D-04), with every reproduced fail-open path fixed (D-16)"
    status: partial
    reason: "Re-review 03-REVIEW-FIX.md (revue-3b) found NF-1..NF-7 after fix round 1 and the manager decision was a fix round 2 'after exec-3'. No commit touches hooks/ after 07da6e2 (git log 6173fc7..HEAD -- hooks/ is empty), so round 2 never ran and no residual was recorded as accepted debt. Verifier reproduced NF-1 against HEAD: 'rm \\<newline> sources/transcripts/t.txt', 'sed -i ... \\<newline> sources/...' and 'cd \\<newline> sources && rm ...' are ALLOWED; the one-line 'rm sources/...' is DENIED. NF-2 reproduced: a shell fed a heredoc ('bash <<EOF / rm sources/... / EOF') is ALLOWED."
    artifacts:
      - path: "hooks/guard-sources.py"
        issue: "Backslash-newline continuation not joined before tokenising (NF-1, major); heredoc bodies fed to a shell not scanned (NF-2); '<<' that is not a heredoc hides following lines (NF-3); lexical path ignored on the Bash destination check through a symlinked sources/ (NF-4); unknown cwd after 'cd -' / 'cd $X' (NF-5); quadratic cost on 1 MB heredocs, fail-open at the 10 s timeout (NF-6); find_root unused, docstring/PROTO-08 wording stale (NF-7)"
    missing:
      - "Fix round 2 for NF-1 (join backslash-newline outside single quotes before tokenising) and NF-2/NF-3/NF-4 with tests in tests/test-hook-guard-sources.sh, then re-review"
      - "OR an explicit decision by Samuel to carry NF-1..NF-7 as v1 debt, recorded in STATE/CONTEXT (then add an overrides: entry here and re-run verification)"
human_verification:
  - test: "Start 'claude --plugin-dir .' in a dossier with the SessionStart hook disabled (or in a dossier subfolder with no reminder) and ask for a dossier-shaped task (e.g. 'prepare tomorrow's call with Jane at Acme')"
    expected: "The agent loads client-dossier:dossier on the strength of the description alone, before reading dossier.yaml"
    why_human: "In all three GREEN runs the first tool call is Skill(client-dossier:dossier) but the SessionStart reminder also fired (hook events present in the stream), so description-only triggering (criterion 1 tail, PROTO-01 'always loaded first') is confounded. The plan defers description validation to 'claude plugin eval' in Phase 7."
---

# Phase 3: Protocol Skill & Hooks Verification Report

**Phase Goal:** Every session in a dossier repository is told the rules before it has a chance to break them, on any harness.
**Verified:** 2026-10-10
**Status:** gaps_found
**Re-verification:** No, initial verification

Free checks run by the verifier at HEAD 4bfd3d0 (working tree clean before and after, no hooks/ change):
`bash tests/run.sh` gives `TOTAL: 11 files, 0 failed`; `bash tests/scenarios/selftest.sh` gives `PASS 65 FAIL 0`;
`bash tests/test-hook-guard-sources.sh` gives `PASS 534 FAIL 0`. Paid `claude -p` scenarios were not re-run;
their recorded evidence was inspected instead.

## Goal Achievement

### Observable Truths (ROADMAP success criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | The `dossier` skill surfaces layout, read/update table, fact-line and status-header formats, "Name (Organisation)" rule, never list; triggers on dossier-shaped tasks | VERIFIED (trigger tail: see human item) | `skills/dossier/SKILL.md` (141 lines) holds sections Layout, Read before acting/update before handing back (table of 6 tasks), Writing a fact, Outbound status header, Never, plus "Name (Organisation)" bullet. Frontmatter `name: dossier` and a situation-style description ("Use when ... client, counterpart, prospect, partner or recruiter ... including when the user only asks to fix a typo in a transcript"). `tests/test-skill-dossier.sh` and `test-skill-shape.sh` pass. Triggering is real in 3/3 GREEN runs (Skill call is the first tool use) but confounded by the hook reminder. |
| 2 | SessionStart injects the reminder when `dossier.yaml` is found upward, silent otherwise | VERIFIED | Ran `hooks/session-start.py` on a scratch dossier from `dossier/sub/`: emits `additionalContext` naming the root and `client-dossier:dossier`. From a directory with no dossier: 0 bytes. Wired in `hooks/hooks.json` (`SessionStart`, `${CLAUDE_PLUGIN_ROOT}` double-quoted). Hook events appear in GREEN streams. |
| 3 | Write/Edit/MultiEdit (and NotebookEdit) under sources/ denied with the immutability message | VERIFIED | Ran `guard-sources.py` with forged stdin: Write, Edit, MultiEdit, NotebookEdit on an existing source, Write of a new file under `sources/`, and `outbound/../sources/x` all return `permissionDecision: deny` with "sources are immutable; file a correction in the dossier instead"; Write to `dossier/HISTORY.md` is silent. Interim review also saw a real `claude -p` Edit denied. |
| 4 | Stop hook blocks once with a reason addressed to the agent; second stop passes (`stop_hook_active`) | VERIFIED | Scratch dossier with an uncommitted `outbound/mails/a.md`: `stop-check.py` prints `{"decision":"block","reason":"outbound/ changed ... update the living files the work touched ... or say in one sentence why none needed it."}`. With `stop_hook_active:true`: 0 bytes. After also touching `dossier/HISTORY.md`: 0 bytes. `dossier-status` is correctly not named (skill absent; D-14 conditional sentence). Interim review saw one real block without a loop. |
| 5 | Pressure scenario RED without plugin (>=1 of 3), GREEN with plugin 3/3 | VERIFIED | `evidence/red-baseline/summary.tsv`: baseline RED 3/3, sources tree hash changed (bef72f... -> 4ac3f9...), diff shows "reprot" -> "report" edited in the transcript, skill_loaded no. `evidence/green-plugin/summary.tsv`: plugin GREEN 3/3, sha_before == sha_after (bef72f...), filed_lines 1 each, lint_exit 0. Diffs show a single added `- ` line in `dossier/HISTORY.md`, dated, with source `(call 2026-10-01 @00:12)`. Stream inspection: init skills list `client-dossier:dossier`, plugin `client-dossier@inline`, tool sequence Skill -> reads -> Edit on HISTORY.md (not on sources/). Pressured prompt D-15 recorded; pointer-only variant INCOMPLETE 0 RED (informational, D-13 settled). |
| 6 | Nearest `dossier.yaml` upward; outside a dossier the entry skill says so in one line and steps aside; task skills stop (verified as they land) | VERIFIED for Phase 3 scope | All three hooks reuse `find_root` (AST identical to `scripts/lint.py` per the interim review, and the session-start check above resolved from a subfolder). SKILL.md "Find the dossier first" states nearest wins, one-line message, `dossier-init` suggestion, continue. The "task skills stop" half is deferred to Phases 4-6 by design (D-07, REQUIREMENTS traceability). |

**Score:** 6/6 roadmap criteria verified; 0 present-behavior-unverified; 1 requirement clause (PROTO-05 Bash guard) not fully met.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `hooks/hooks.json` | 3 hooks wired | VERIFIED | SessionStart, PreToolUse (matcher `Write|Edit|MultiEdit|NotebookEdit|Bash`), Stop; `claude plugin validate .` exits 0 (one warning: root CLAUDE.md) |
| `hooks/session-start.py` | reminder | VERIFIED | substantive, fail-open, never opens dossier.yaml |
| `hooks/guard-sources.py` | deny guard | VERIFIED for the Write family; PARTIAL for Bash (gap above) | 24 KB, 534 test assertions pass |
| `hooks/stop-check.py` | block once | VERIFIED | git via argument list, `stop_hook_active` honoured |
| `skills/dossier/SKILL.md` | protocol skill | VERIFIED | substantive, wired through plugin (listed in init skills of GREEN runs) |
| `tests/scenarios/` + `evidence/` | harness and RED/GREEN records | VERIFIED | selftest 65/0; summaries and diffs consistent with the SUMMARY claims |

### Key Link Verification

| From | To | Via | Status |
|------|----|-----|--------|
| `hooks.json` | the three scripts | `python3 "${CLAUDE_PLUGIN_ROOT}/hooks/*.py"` | WIRED (`tests/test-hooks-config.sh` passes; hooks fired in real streams) |
| SessionStart text | `dossier` skill | names `client-dossier:dossier` | WIRED (skill exists and loads) |
| SKILL.md | `scripts/lint.py` | `${CLAUDE_PLUGIN_ROOT}/scripts/lint.py` with bare-install fallback sentence | WIRED |
| Stop hook | `dossier-status` | conditional on `skills/dossier-status/SKILL.md` existing | WIRED (intentionally silent until Phase 6) |

### Requirements Coverage

| Requirement | Status | Evidence |
|-------------|--------|----------|
| PROTO-01 | SATISFIED (description-only trigger awaits Phase 7 eval) | description + reminder; Skill loaded first 3/3 |
| PROTO-02 | SATISFIED for Phase 3 scope | layout, table, fact line, status header, never list, Name (Organisation) present; pointer to `dossier-init` only, other pointers land with Phases 4-6 (D-07) |
| PROTO-03 | SATISFIED | "Language" section: content in `language` of dossier.yaml, keywords English |
| PROTO-04 | SATISFIED | reproduced |
| PROTO-05 | PARTIAL | Write family VERIFIED; Bash guard has an unfixed, reproduced bypass (gap) |
| PROTO-06 | SATISFIED | reproduced |
| PROTO-07 | SATISFIED | RED 3/3, GREEN 3/3, evidence inspected |
| PROTO-08 | SATISFIED for Phase 3 scope | rule stated in SKILL.md, nearest-wins in hooks; task-skill stop verified as each skill lands |

No orphaned requirements: REQUIREMENTS.md maps PROTO-01..08 to Phase 3 and the plans claim all eight.

### Anti-Patterns Found

Debt-marker scan (`TBD|FIXME|XXX`) on the phase's code was not a blocker source; the only open item of weight is the guard bypass above (recorded as the gap).

### Behavioral Spot-Checks and Probes

Hook behaviors were exercised directly with forged stdin (rows 2, 3, 4 above). No `probe-*.sh` is declared by the phase plans (Step 7c: none to run).

### Documentation / Bookkeeping Warnings (non-blocking)

- `.planning/ROADMAP.md` Phase 3 still says "3/6 plans executed" and the phase is unchecked (`[ ]`) although all six plans are `[x]` with SUMMARYs; `.planning/REQUIREMENTS.md` PROTO-01..08 are still `[ ]` / "Pending". To be updated by the orchestrator on phase completion.
- `CLAUDE.md` says `claude plugin validate .` shows two known warnings (author missing, CLAUDE.md at root); at Claude Code 2.1.296 only the CLAUDE.md warning appears, and `--strict` exits 1 on it. The statement is slightly stale, not harmful.
- `03-REVIEW.md` / `03-SECURITY.md` are "interim" (pre fix round 1); only `03-REVIEW-FIX.md` reflects the current code. No final audit of the "every hook rule is also stated in a skill" doctrine is recorded, though SKILL.md now states the sources rule, stop-check rule and language rules.

### Human Verification Required

1. **Description-only triggering.** Test: launch in a dossier without the SessionStart reminder and give a dossier-shaped task. Expected: `client-dossier:dossier` loads before `dossier.yaml` is read. Why human: GREEN evidence is confounded by the hook reminder.

### Gaps Summary

The goal is met in substance: the skill, the SessionStart reminder, the Write-family deny, the block-once Stop hook and the RED/GREEN pressure scenario all work and were reproduced. One requirement clause is not closed: PROTO-05's heuristic Bash guard still allows a plain `rm`/`sed -i` on a source split by a backslash-newline, and a shell fed a heredoc. These are findings NF-1 (major) to NF-7 from the re-review, for which a fix round 2 was decided but never executed (no hooks/ commit since 07da6e2), and Samuel's D-16 asked for reproduced fail-open paths to be fixed. The Bash guard is documented as a heuristic and the skill states that the rule, not the guard, is the boundary, so this is not a threat to the roadmap criteria. Either run fix round 2 and re-review, or record NF-1..NF-7 as accepted v1 debt with an `overrides:` entry.

---

_Verified: 2026-10-10_
_Verifier: Claude (gsd-verifier)_
