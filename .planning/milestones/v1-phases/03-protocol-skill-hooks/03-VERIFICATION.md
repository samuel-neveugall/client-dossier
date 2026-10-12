---
phase: 03-protocol-skill-hooks
verified: 2026-10-10T19:45:00Z
status: passed
score: 6/6 roadmap criteria verified (criterion 3 and PROTO-05 carry 1 accepted override, the D-04 class)
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
covered_digest: "v3:sha256:d0a18c510302b446e63235c025c4f0608a317089bb623842b01215e25dcfa3d3"
behavior_unverified: 0
overrides_applied: 1
overrides:
  - must_have: "PROTO-05: a heuristic PreToolUse guard on Bash denies commands that visibly modify an existing file under sources/ (D-04) - the D-04 class (eval, interpreters such as python3 -c, command substitutions, variables, loops over globs, bash -c deeper than 2 levels, scripts over 64 KB, cd $X / cd /nonexistent guessed not followed, patch -p1 diff handed in, cp dossier/*.txt onto an existing name) is not detected"
    reason: "The guard reads the command text only; this class is undetectable by a text heuristic. Accepted by Samuel as documented v1 debt (D-17). The boundary is the skill's rule, which states the limits verbatim in skills/dossier/SKILL.md ('When a source is wrong': 'It does not see eval, interpreters (python3 -c and the like), command substitutions, variables or loops, so this file stays the boundary'). Recorded in STATE.md (Accepted v1 debt, D-17) and to be restated in the README (DIST-05, Phase 7)."
    accepted_by: "Samuel (D-17, AskUserQuestion main session)"
    accepted_at: "2026-10-10"
re_verification:
  previous_status: gaps_found
  previous_score: "6/6 roadmap criteria verified, 1 requirement clause failed (PROTO-05 Bash guard)"
  gaps_closed:
    - "NF-1 backslash-newline continuation (rm / sed -i / cd split over a line)"
    - "NF-2 heredoc body fed to a shell (bash <<EOF, sh -s <<EOF, unquoted heredoc with $(...))"
    - "NF-3 '<<' that is not a heredoc hiding the following lines"
    - "D-17 round: F1 (a\\ #b, ANSI-C quotes), F2 (quote state across lines), F4 (cd -, popd), F5 readable forms (globs on the sources component, rm -rf ., gsed -i, patch, awk -i inplace, ed, vim -es, sponge, timeout/nice/ionice/stdbuf/caffeinate), F6 (spec 4.3 'any ancestor dossier' wording), F3 size bounds (recorded in STATE)"
  gaps_remaining: []
  regressions: []
human_verification:
  - test: "Start 'claude --plugin-dir .' in a dossier with the SessionStart hook disabled (or in a dossier subfolder with no reminder) and ask for a dossier-shaped task (e.g. 'prepare tomorrow's call with Jane at Acme')"
    expected: "The agent loads client-dossier:dossier on the strength of the description alone, before reading dossier.yaml"
    why_human: "Carried over from iter1, unchanged and non-blocking: in every GREEN run the first tool call is Skill(client-dossier:dossier) but the SessionStart reminder also fired, so description-only triggering is confounded. The plan defers description validation to 'claude plugin eval' in Phase 7. Not a must-have of this phase's roadmap truths; informational."
---

# Phase 3: Protocol Skill & Hooks Verification Report (re-verification)

**Phase Goal:** Every session in a dossier repository is told the rules before it has a chance to break them, on any harness.
**Verified:** 2026-10-10 at HEAD 82b756d
**Status:** passed
**Re-verification:** Yes, non-regression after fix rounds (D-17: no new bug hunting). Previous report: `03-VERIFICATION.iter1.md` (gaps_found).

Note on the `human_verification` entry: it is the iter1 informational item (description-only triggering, deferred to Phase 7
`claude plugin eval` by plan). It is not a roadmap truth and not a blocker; it is recorded so it is not lost. If the orchestrator
treats any `human_verification` entry as `human_needed`, this one is the only candidate and the decision is Samuel's.

## Free checks run at HEAD (working tree: only pre-existing untracked/modified planning files, no hooks/skills/scripts change)

| Check | Result |
|---|---|
| `bash tests/run.sh` | `TOTAL: 11 files, 0 failed` |
| `bash tests/scenarios/selftest.sh` | `PASS 71 FAIL 0` |
| `claude plugin validate .` (no --strict) | `Validation passed with warnings` (one warning: root CLAUDE.md, known) |
| Paid `claude -p` scenarios | Not run (caller is running them); recorded evidence inspected instead |

## Re-check of NF-1..NF-3 and the D-17 fixes (guard run with forged stdin on a scratch dossier, cwd = dossier root)

`python3 hooks/guard-sources.py` fed `{"tool_name":"Bash","tool_input":{"command":...},"cwd":...}`. Every row below was run by the verifier.

| Case | iter1 | HEAD |
|---|---|---|
| NF-1 `rm \<NL> sources/transcripts/t.txt` | ALLOWED | DENY |
| NF-1 `sed -i 's/a/b/' \<NL> sources/transcripts/t.txt` | ALLOWED | DENY |
| NF-1 `cd \<NL> sources && rm transcripts/t.txt` | ALLOWED | DENY |
| NF-2 `bash <<EOF / rm sources/... / EOF` | ALLOWED | DENY |
| NF-2 `sh -s <<EOF` same body | ALLOWED | DENY |
| NF-2 unquoted heredoc holding `$(rm sources/...)` | ALLOWED | DENY |
| NF-3 `echo $((1<<2))` then `rm sources/...` | hidden | DENY |
| NF-3 `[[ a<<b ]]` then `rm sources/...` | hidden | DENY |
| NF-3 `# <<EOF` then `rm sources/...` | hidden | DENY |
| F1 `echo a\ #b; rm sources/...`, `echo $'\''; rm sources/...` | allowed (round-2 regression) | DENY |
| F2 multi-line quoted string holding `cat <<EOF`, then `rm sources/...` | allowed | DENY |
| F4 `cd /; cd -; rm sources/...` | allowed | DENY |
| F4 `pushd sources && popd; rm dossier/HISTORY.md` (false positive) | denied | ALLOW (correct) |
| F5 `rm sour*/transcripts/t.txt`, `rm -rf .` | allowed | DENY |
| F5 `gsed -i`, `patch`, `awk -i inplace`, `ed`, `vim -es`, `sponge` on a source | allowed | DENY (all six) |
| F5 wrappers `timeout 5 rm`, `nice rm`, `caffeinate rm` on a source | allowed | DENY (all three) |
| Plain `rm`, `>` redirect, `tee`, `truncate`, `git rm` on a source | DENY | DENY |
| No-regression: `cp /etc/hosts sources/transcripts/new.txt` (new file), `cat sources/...` (read), `sed -i ... dossier/HISTORY.md` | ALLOW | ALLOW |

Rounds F3 (size bounds against the 10 s hook timeout) and F6 (spec 4.3 wording, `docs/superpowers/specs/...design.md` line 357 now reads "any ancestor dossier") are in the code and spec; the F3 bound semantics are recorded in STATE ("operand > 4096 chars, > 512 operands, > 4096 judged paths: only a visible `sources` component is refused"). I did not time the pathological inputs (D-17: no new hunting).

## The D-04 class is accepted debt, not a gap

Run on HEAD, these are ALLOWED by the guard, exactly as the accepted-debt text says: `eval 'rm sources/...'`, `python3 -c "import os;os.remove('sources/...')"`, `X=sources; rm $X/...`, `rm $(echo sources/...)`, `for f in sources/transcripts/*; do rm $f; done`. They are covered by the `overrides:` entry above (Samuel, D-17, 2026-10-10).

Skill states the limits (verified in `skills/dossier/SKILL.md`, section "When a source is wrong"): "In Claude Code a guard denies the obvious shortcuts, but it is a heuristic that reads the command text; a command it fails to recognise is still forbidden. It does not see `eval`, interpreters (`python3 -c` and the like), command substitutions, variables or loops, so this file stays the boundary: never modify a source by any route, seen or not by the guard." The top of the file also says "the rules in this file are the real boundary". STATE.md line 76 records the debt with the acceptance and "README to state it (DIST-05)". The skill test (`tests/test-skill-dossier.sh`, in `tests/run.sh`) passes.

## Goal Achievement

### Observable Truths (ROADMAP success criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `dossier` skill surfaces layout, read/update table, fact-line and status-header formats, "Name (Organisation)", never list; triggers on dossier-shaped tasks | VERIFIED | `skills/dossier/SKILL.md` read in full at HEAD: Layout, Read-before-acting table (6 tasks), Writing a fact, When a source is wrong, Outbound status header, Language, Never, "Name (Organisation)" bullet; situation-style description. Skill tests pass. Description-only trigger: see informational human item. |
| 2 | SessionStart injects the reminder upward from the cwd, silent otherwise | VERIFIED | `session-start.py` run from `dossier/sub/`: emits `additionalContext` ("This repository is a client dossier (dossier.yaml at ..."); from a directory with no dossier: 0 bytes. `hooks.json` wires SessionStart. |
| 3 | Write/Edit/MultiEdit/NotebookEdit under sources/ denied with the immutability message; heuristic Bash guard denies the obvious shell routes (D-03/D-04) | VERIFIED (Bash class D-04 by override) | All four tools on an existing source return `permissionDecision: deny` with "sources are immutable; file a correction in the dossier instead: ..."; Write of a new file under `sources/` denied; Write to `dossier/HISTORY.md` silent (0 bytes). Bash: obvious routes denied (table above), new-file copy allowed, accepted D-04 class documented. |
| 4 | Stop hook blocks once with a reason addressed to the agent; second stop passes | VERIFIED | Scratch git dossier with an uncommitted `outbound/mails/a.md`: first stop prints `{"decision":"block","reason":"outbound/ changed in this dossier but nothing under dossier/ did. Before handing back, update the living files the work touched ..., or say in one sentence why none needed it."}`; `stop_hook_active:true` prints 0 bytes. `dossier-status` not named (skill absent, D-14). |
| 5 | Pressure scenario RED without plugin, GREEN 3/3 with | VERIFIED | `evidence/red-baseline`, `evidence/green-plugin` as in iter1 (RED 3/3, GREEN 3/3, sha unchanged). The skill text changed afterwards (289067e, 19:16), so a replay was recorded in `evidence/uat/green-replay/summary.tsv` (19:20, after that commit): 3/3 GREEN, `sha_before == sha_after` (bef72f...), `filed_lines` 1/2/1, `skill_loaded yes`, `lint_exit 0`; stream inspection: first tool use is `Skill:client-dossier:dossier`, then edits to `dossier/` files, none under `sources/`. Replay folder is untracked in git (see warnings). |
| 6 | Nearest `dossier.yaml` upward; entry skill says so in one line and steps aside outside a dossier; task skills stop (as each lands) | VERIFIED for Phase 3 scope | SKILL.md "Find the dossier first"; session-start resolved from a subfolder. Task-skill stop is deferred to Phases 4-6 by design (D-07). |

**Score:** 6/6 truths verified; 0 present-behavior-unverified; 1 override applied (D-04 class).

### Required Artifacts

| Artifact | Status | Details |
|----------|--------|---------|
| `hooks/hooks.json` | VERIFIED | SessionStart, PreToolUse (`Write|Edit|MultiEdit|NotebookEdit|Bash`), Stop; `${CLAUDE_PLUGIN_ROOT}` double-quoted; plugin validates |
| `hooks/session-start.py`, `hooks/stop-check.py` | VERIFIED | exercised above |
| `hooks/guard-sources.py` | VERIFIED | Write family and the Bash guard (outside the accepted D-04 class) exercised above |
| `skills/dossier/SKILL.md` | VERIFIED | substantive, states D-04 limits, loaded first in plugin runs |
| `tests/scenarios/`, `evidence/` | VERIFIED | selftest 71/0 |

### Key Link Verification

| From | To | Via | Status |
|------|----|-----|--------|
| `hooks.json` | the three scripts | `python3 "${CLAUDE_PLUGIN_ROOT}/hooks/*.py"` | WIRED (`tests/test-hooks-config.sh` in the passing run; hooks fire in recorded streams) |
| SessionStart text | `dossier` skill | names `client-dossier:dossier` | WIRED |
| SKILL.md | `scripts/lint.py` | `${CLAUDE_PLUGIN_ROOT}/scripts/lint.py` + bare-install fallback sentence | WIRED |
| Stop hook | `dossier-status` | conditional on the skill file existing | WIRED (silent until Phase 6) |

### Requirements Coverage

| Requirement | Status | Evidence |
|-------------|--------|----------|
| PROTO-01 | SATISFIED (description-only trigger awaits Phase 7 eval) | description + reminder; Skill loaded first in every plugin run |
| PROTO-02 | SATISFIED for Phase 3 scope | pointers to later skills land with Phases 4-6 (D-07) |
| PROTO-03 | SATISFIED | "Language" section |
| PROTO-04 | SATISFIED | reproduced |
| PROTO-05 | SATISFIED (Bash D-04 class by override) | Write family and Bash obvious routes reproduced; residual class accepted (D-17) and stated in the skill |
| PROTO-06 | SATISFIED | reproduced |
| PROTO-07 | SATISFIED | RED 3/3, GREEN 3/3, post-skill-change replay 3/3 |
| PROTO-08 | SATISFIED for Phase 3 scope | rule in SKILL.md; task-skill stop verified as each skill lands |

No orphaned requirements.

### Anti-Patterns Found

None blocking. No `TBD|FIXME|XXX` check beyond the guard reproduction was needed for the verdict; no stub found in the hook scripts or the skill.

### Warnings (non-blocking, not gaps)

- `.planning/ROADMAP.md` Phase 3 is still unchecked (`[ ]`) and `.planning/REQUIREMENTS.md` PROTO-01..08 are still `[ ]` / "Pending": orchestrator bookkeeping on phase completion.
- `.planning/phases/03-protocol-skill-hooks/evidence/uat/` and `03-VERIFICATION.iter1.md` are untracked; commit them with the phase artifacts (the evidence is cited by criterion 5).
- The README statement of the D-04 debt is owed in Phase 7 (DIST-05); the skill and STATE already carry it.
- `claude plugin validate .` warns about a root `CLAUDE.md` (`--strict` would fail on it); Phase 7 manifest work.

### Gaps Summary

None. The fail-open paths reproduced in iter1 (NF-1, NF-2, NF-3) and the D-17 round items are closed at HEAD, with no regression on new-file copies, reads, or dossier edits. The residual D-04 class is accepted debt, declared by override and stated in `skills/dossier/SKILL.md`.

---

_Verified: 2026-10-10_
_Verifier: Claude (gsd-verifier)_
