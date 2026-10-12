---
phase: 01-scaffold-templates
verified: 2026-09-16T18:30:00Z
status: human_needed
score: 5/5 must-haves verified
behavior_unverified: 0
overrides_applied: 0
covered_files:
  - ".claude-plugin/plugin.json"
  - ".planning/REQUIREMENTS.md"
  - ".planning/ROADMAP.md"
  - ".planning/phases/01-scaffold-templates/01-01-PLAN.md"
  - ".planning/phases/01-scaffold-templates/01-01-SUMMARY.md"
  - ".planning/phases/01-scaffold-templates/01-02-PLAN.md"
  - ".planning/phases/01-scaffold-templates/01-02-SUMMARY.md"
  - ".planning/phases/01-scaffold-templates/01-03-PLAN.md"
  - ".planning/phases/01-scaffold-templates/01-03-SUMMARY.md"
  - ".planning/phases/01-scaffold-templates/01-04-PLAN.md"
  - ".planning/phases/01-scaffold-templates/01-04-SUMMARY.md"
  - ".planning/phases/01-scaffold-templates/01-05-PLAN.md"
  - ".planning/phases/01-scaffold-templates/01-05-SUMMARY.md"
  - ".planning/phases/01-scaffold-templates/01-06-PLAN.md"
  - ".planning/phases/01-scaffold-templates/01-06-SUMMARY.md"
  - "CLAUDE.md"
  - "docs/superpowers/specs/2026-09-16-client-dossier-design.md"
  - "skills/dossier-init/SKILL.md"
  - "skills/dossier-init/scripts/init.py"
  - "tests/fixtures/make-adopt-fixture.sh"
  - "tests/golden/adopt-proposal.txt"
  - "tests/lib.sh"
  - "tests/run.sh"
  - "tests/test-init-adopt.sh"
  - "tests/test-init-empty.sh"
  - "tests/test-init-fr.sh"
  - "tests/test-init-pointer.sh"
  - "tests/test-skill-shape.sh"
covered_digest: "v1:sha256:60de314bd76f3ef7717175da2817b47be2e46ef8bca2c5eb25b1e8d30d48abde"
human_verification:
  - test: "In a live Claude Code session with the plugin loaded via `claude --plugin-dir .`, invoke `/client-dossier:dossier-init` (or the equivalent conversational trigger) in a throwaway empty repo, answering the grouped question with a French counterpart."
    expected: "The skill asks exactly one grouped question (counterpart + language), infers/proposes the language, then produces French headings/comments/example lines with English paths and English protocol keywords; a second invocation reports everything as already present, adding nothing."
    why_human: "This exercises the skill's own judgement layer (grouped question wording, language inference/confirmation dialogue) which only exists as conversational behavior — it cannot be invoked headlessly. The bundled init.py mechanics behind it were independently verified by this verifier (see Behavioral Spot-Checks), but the skill-level conversational orchestration was not."
  - test: "In a live session, run the skill against a copy of `tests/fixtures/make-adopt-fixture.sh`'s throwaway origin-shaped repository, and (a) confirm the proposed renames, (b) on a second run, decline them."
    expected: "On confirm: the skill executes the exact `git mv -- <old> <new>` commands from the proposal, one at a time, then completes whatever scaffold pieces are still missing (D-08), and commits nothing itself. On decline: nothing is renamed or written."
    why_human: "The read-only `--propose-renames` proposal step is mechanically verified (byte-exact match against `tests/golden/adopt-proposal.txt`), but the confirm/decline branch and the subsequent `git mv` execution is conversational orchestration described in SKILL.md prose, not exercised by any automated test in this phase (the plan's own 01-06-SUMMARY.md documents this as intentionally interactive-only, `human_judgment: true`)."
audit_acknowledged:
  milestone: v1
  at: 2026-10-13
  status: human_needed
---

# Phase 1: Scaffold & Templates Verification Report

**Phase Goal:** Running `dossier-init` turns any repository (empty or pre-existing) into a
correctly laid-out dossier in one step.
**Verified:** 2026-09-16
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

All five ROADMAP success criteria were independently exercised against the actual codebase
(not inferred from SUMMARY.md), by running `skills/dossier-init/scripts/init.py` directly in
throwaway scratch repositories and inspecting the output byte-for-byte.

| # | Truth (ROADMAP Success Criterion) | Status | Evidence |
|---|---|---|---|
| 1 | Empty repo → `dossier.yaml` (incl. `consent_source`, `staleness_days`), four folders + subfolders with `.gitkeep` in every empty leaf, all seven living files pre-filled with `Last updated:` + "Updated when" comment | ✓ VERIFIED | Ran `init.py --counterpart "Acme Consulting\|Lead\|jane@acme.com" --confidential-name Acme` in a scratch repo. Produced `dossier.yaml` with all 10 spec §3.2 keys in order (`version, language, counterparts, confidential_names, consent_recorded, consent_source, timestamps, date_format, status_header, staleness_days`), 7 `.gitkeep` files in the correct empty leaves (`sources/received`, `sources/transcripts/raw`, `knowledge/decisions`, `knowledge/watch`, `outbound/{calls,mails,deliverables}`), and all 7 `dossier/*.md` living files each opening with `Last updated: 2026-09-16` and an "Updated when" HTML comment. Second run reported `0 created, 20 kept` — idempotent (D-08). |
| 2 | `knowledge/CONTEXT.md`, `knowledge/DOCTRINE.md` (two lists to fill), `dossier/README.md`, `sources/README.md`, `outbound/README.md` all exist | ✓ VERIFIED | All 5 files present after the same run. `DOCTRINE.md` inspected directly: contains `## What we say`, `## What we never say`, `## Vocabulary, one sentence each` — the two lists plus vocabulary section per SCAF-04. `outbound/README.md` verified to restate the status header verbatim (`Status:`, `To:`, `Subject:`, `Deadline:`, `Written by:`). |
| 3 | Repository's `CLAUDE.md`/`AGENTS.md` gains a short protocol-pointer section | ✓ VERIFIED | Case A (neither file exists): `AGENTS.md` created with a marker-delimited (`<!-- client-dossier:start -->`...`<!-- client-dossier:end -->`) section; `CLAUDE.md` correctly skipped ("absent"). Case B (pre-existing `CLAUDE.md`): ran `init.py` against a scratch repo with a hand-written `CLAUDE.md`; the pointer section was appended below existing content, existing content preserved verbatim, matching D-16 exactly. |
| 4 | Existing repo with differently-named folders → `git mv` rename proposal instead of duplicate structure | ✓ VERIFIED | Built the disposable origin-shaped fixture via `tests/fixtures/make-adopt-fixture.sh` and ran `init.py --propose-renames` directly against it. Output: `13 proposed, 1 untracked, 0 unsafe, 3 ignored` — `client→dossier`, `communication→outbound`, `docs→knowledge`, all 7 living-file renames, `outbound/appels→calls`, `outbound/livrables→deliverables`; `pipeline`, `sources/internes`, `sources/plaquette` correctly listed as `ignored:` (no dossier role / source subfolders never renamed); `docs/veille` correctly flagged `untracked:`. Confirmed identical to `tests/golden/adopt-proposal.txt`. Confirmed the flag writes nothing (no `dossier.yaml`, no folders created). |
| 5 | `language: fr` → French titles/headings/comments/examples, English paths/protocol keywords | ✓ VERIFIED | Ran `init.py --language fr --counterpart "Acme Conseil\|Lead"`. `dossier/ACTORS.md` renders `# Acteurs`, `## Côté donneur d'ordre`, and a French "Mis à jour quand :" comment — while the `Last updated:` label itself and every path (`dossier/ACTORS.md`, `outbound/README.md`, etc.) stayed English. `outbound/README.md` (French prose) reproduces the English status-header fields/values (`Status: draft \| reviewed by <name> \| sent`, `To:`, `Subject:`, `Deadline:`, `Written by:`) verbatim, confirming protocol keywords are never translated (SCAF-07). |

**Score:** 5/5 truths verified (0 present-but-behavior-unverified)

Two items from the ROADMAP/plan's own scope are conversational/interactive orchestration that
cannot be exercised headlessly (the grouped-question dialogue, and the live confirm/decline
branch of the adoption rename flow). The plan authors themselves flagged these as
`human_judgment: true` in 01-06-SUMMARY.md's own coverage table, with no headless equivalent.
This verifier reached the same conclusion independently and lists them under Human
Verification below — they do not indicate a functional gap in the mechanical layer, which was
fully exercised and passed.

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `.claude-plugin/plugin.json` | Minimal 3-key manifest (name, description, version) | ✓ VERIFIED | Exactly 3 keys present; `claude plugin validate .` (non-strict) passes with only two advisory warnings (missing `author`, root `CLAUDE.md` not loaded as plugin context) — no schema/path-traversal errors. `--strict` fails on those two warnings only, a documented, tracked, non-blocking deviation (WINDOWS.md id 1). |
| `skills/dossier-init/SKILL.md` | Frontmatter + full judgement body (language inference, grouped question, confidential-name derivation, rename confirm/execute flow, D-07 inline fallback, D-09 translation guidance) | ✓ VERIFIED | 176 lines; frontmatter has `name`, `description`, `allowed-tools`; body contains all seven judgement steps; inline fallback names all 7 `.gitkeep` leaves and all 10 `dossier.yaml` keys (confirmed by `tests/test-skill-shape.sh`, 30 assertions, passing). No debt markers, no reference to Phase 2/3/7 material (lint.py, hooks.json, marketplace.json, commands/) found by direct grep. |
| `skills/dossier-init/scripts/init.py` | Python3-stdlib-only mechanics tier | ✓ VERIFIED | 844 lines, no imports beyond stdlib (confirmed by direct read of import block during ad-hoc execution — script ran with plain `python3`, no venv/deps). Contains `FOLDERS`, `GITKEEP_LEAVES`, `TEMPLATE_MAP` (12 rows), `RENAME_TABLE`, `resolve_template_dir`, `upsert_marker_section`, `propose_renames` — all exercised directly above. |
| `skills/dossier-init/templates/{en,fr}/*` (13 files each) | Living files, knowledge stubs, READMEs, AGENTS-pointer | ✓ VERIFIED | `diff <(ls .../en) <(ls .../fr)` — identical 13-name lists. Content spot-checked for both languages above (Truths #1, #2, #5). |
| `tests/{lib.sh,run.sh,test-*.sh}` | Bash+python3 harness, no other framework | ✓ VERIFIED | `bash tests/run.sh` executed directly by this verifier: `ok` on all 5 files, `TOTAL: 5 files, 0 failed`. |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `skills/dossier-init/SKILL.md` | `skills/dossier-init/scripts/init.py` | `allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/init.py *)`, invoked via `${CLAUDE_SKILL_DIR}` (never a repo-relative path) | ✓ WIRED | Confirmed by direct grep of SKILL.md and independently by running `init.py` from its actual bundled location with no path adjustment. |
| `init.py` | `templates/{en,fr}/*.md` | `resolve_template_dir()` → `render_template()` | ✓ WIRED | Verified end-to-end: both language variants render correctly (Truths #1, #5); an out-of-scope variant falls back to `en/` per plan 01-02 (not independently re-tested here, but covered by `tests/test-init-empty.sh`, which passed). |
| `init.py --propose-renames` | `tests/golden/adopt-proposal.txt` | Byte-exact contract | ✓ WIRED | Reproduced the exact golden output directly against a freshly-built fixture (Truth #4). |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Empty-repo scaffold produces full surface | `python3 init.py --counterpart "..." --confidential-name Acme` in scratch dir | 20 files created, all present on disk, correct content | ✓ PASS |
| Idempotence (D-08) | Re-run the same command | `done: 0 created, 20 kept` | ✓ PASS |
| French variant | `python3 init.py --language fr ...` | French headings, English paths/keywords confirmed | ✓ PASS |
| Adoption proposal matches golden | `python3 init.py --propose-renames` against fresh fixture | Byte-identical to `tests/golden/adopt-proposal.txt` | ✓ PASS |
| Pointer: CLAUDE.md appended only when pre-existing | Run against scratch repo with hand-written `CLAUDE.md` | `pointer: appended CLAUDE.md`; original content preserved, marker section appended | ✓ PASS |
| Full test suite | `bash tests/run.sh` | `TOTAL: 5 files, 0 failed` | ✓ PASS |
| Confidentiality guarantee | `grep -rc 'Project-POC-RELATION-CLIENT' skills/ tests/ .claude-plugin/ CLAUDE.md` | Every matched file: `0` | ✓ PASS |
| No debt markers | `grep -rnE "TBD|FIXME|XXX|TODO|HACK" skills/ tests/ .claude-plugin/ CLAUDE.md docs/.../design.md` | No matches | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|---|---|---|---|---|
| SCAF-01 | 01-01 | `dossier.yaml` with all fields incl. `consent_source`, `staleness_days` | ✓ SATISFIED | Direct execution, Truth #1 |
| SCAF-02 | 01-01 | Four-folder layout + subfolders + `.gitkeep` | ✓ SATISFIED | Direct execution, Truth #1 |
| SCAF-03 | 01-01, 01-02 | Seven living files from templates, `Last updated:` + comment | ✓ SATISFIED | Direct execution, Truth #1 |
| SCAF-04 | 01-02 | `CONTEXT.md`, `DOCTRINE.md` (two lists), three READMEs | ✓ SATISFIED | Direct execution, Truth #2 |
| SCAF-05 | 01-04 | Protocol pointer in `CLAUDE.md`/`AGENTS.md` | ✓ SATISFIED | Direct execution, Truth #3 (both branches tested) |
| SCAF-06 | 01-05, 01-06 | Detect same-role folders, propose `git mv` before writing what's missing | ✓ SATISFIED (proposal mechanism); confirm/execute branch → human verification | Direct execution, Truth #4; live confirm/execute flow not headlessly testable — see Human Verification |
| SCAF-07 | 01-02, 01-03 | English-authored templates, translated per language, protocol keywords stay English | ✓ SATISFIED | Direct execution, Truth #5 |
| SCAF-08 | 01-01 | Minimal `.claude-plugin/plugin.json`, loads via `--plugin-dir .` | ✓ SATISFIED (with documented non-strict-only caveat, WINDOWS.md id 1) | `claude plugin validate .` passes with warnings only; `--strict` fails on two advisory-only warnings unrelated to schema validity |

**Note:** `.planning/REQUIREMENTS.md`'s checkboxes and traceability table (lines 19–41, 199–206)
still show SCAF-01…08 as unchecked/"Pending". This is a bookkeeping gap (the file was not
updated to reflect completed work), not a functional gap — every requirement's actual
implementation was independently verified above. Flagging for the ship step to update the
tracking file; not a phase-goal blocker.

### Anti-Patterns Found

None. Scanned all files touched by this phase (`skills/dossier-init/**`, `tests/**`,
`.claude-plugin/plugin.json`, `CLAUDE.md`, the design spec) for `TBD|FIXME|XXX|TODO|HACK`,
`placeholder|coming soon|not yet implemented`, empty-return stubs — zero matches except two
uses of the word "placeholder" in `SKILL.md` prose that describe what the skill must *avoid*
producing ("hand the user a scaffold that is only placeholders"), which is the opposite of a
stub.

### Scope Discipline Check

Confirmed absent from the repository (all correctly out of Phase 1 scope, reserved for later
phases per ROADMAP): `scripts/lint.py`, `hooks/hooks.json`, `commands/`,
`.claude-plugin/marketplace.json`, `.codex-plugin/`, `skills/dossier/`, `skills/dossier-ingest/`,
`skills/dossier-draft/`, `skills/dossier-call/`, `skills/dossier-status/`, `agents/`. Only
`skills/dossier-init/` exists under `skills/`, and `.claude-plugin/plugin.json` is the only
manifest present, holding exactly the 3 keys SCAF-08 specifies. No scope creep found.

### Confidentiality Guarantee

`grep -rc 'Project-POC-RELATION-CLIENT' skills/ tests/ .claude-plugin/ CLAUDE.md` was run
directly by this verifier: every one of the 37 matched files reports `0`. A broader
case-sensitive search for `POC-RELATION` across all tracked `.md/.py/.sh/.json` files (excluding
`.planning/`) also returned zero matches. The origin repository
(`/Users/samuel/Documents/dev/Project-POC-RELATION-CLIENT`) was not opened during this
verification, per the task's instruction.

### Human Verification Required

### 1. End-to-end conversational scaffold via a live `--plugin-dir` session

**Test:** Load the plugin with `claude --plugin-dir .`, trigger `dossier-init` conversationally
in an empty throwaway repo, and answer the grouped question with a French counterpart.
**Expected:** Exactly one grouped question is asked; the skill proposes/confirms the language;
the resulting scaffold has French headings and English paths/keywords; a second invocation
reports everything as already present.
**Why human:** This is the skill's own judgement layer (conversational question-asking,
language inference dialogue) — it has no headless equivalent. The underlying mechanics
(`init.py`) were independently verified directly by this verifier and are sound; what remains
unverified is the skill's live conversational orchestration around them.

### 2. Live confirm/decline of the adoption rename proposal

**Test:** In a live session, point the skill at a copy of the `make-adopt-fixture.sh` output,
let it show the rename proposal, confirm it, and separately (on a fresh copy) decline it.
**Expected:** On confirm — the exact `git mv -- <old> <new>` commands run, then whatever scaffold
pieces are still missing get completed, and nothing is committed. On decline — nothing is
renamed or written.
**Why human:** The read-only proposal step (`--propose-renames`) is mechanically verified byte-
for-byte against `tests/golden/adopt-proposal.txt`; the confirm/execute branch is conversational
(the skill decides, in dialogue, whether to proceed) and is explicitly documented by the
phase's own plan (01-06-SUMMARY.md) as interactive-only with no headless equivalent.

### Gaps Summary

No gaps found in the mechanical layer: every ROADMAP success criterion, every SCAF-01…08
requirement, and the confidentiality/scope-discipline constraints from the verification
brief were independently reproduced against the live codebase (not inferred from SUMMARY.md
prose) and passed. The two items above are the phase's own explicitly-scoped interactive
behaviors (conversational grouped-question dialogue, and confirm/decline of a destructive
`git mv` operation) that cannot be exercised without a live chat session — the plan authors
flagged this themselves, and this verifier's independent analysis reaches the same conclusion.
The `claude plugin validate . --strict` non-pass and the `REQUIREMENTS.md` checkbox staleness
are both pre-existing, documented, non-blocking bookkeeping items (WINDOWS.md id 1, and the
Requirements Coverage note above) — not gaps in what the phase goal required to be built.

---

_Verified: 2026-09-16_
_Verifier: Claude (gsd-verifier)_

---

## Human Verification — Results (2026-09-17)

Both live checks were run on 2026-09-17 through `claude -p --plugin-dir .` sessions resumed
turn by turn (`--session-id` / `--resume`) in throwaway repositories under the session
scratchpad, with the human answers scripted as the second turn. Nothing was committed by the
skill in any run; every repository was inspected with `git status` after each turn.

### 1. Conversational scaffold — PASS

- Empty repo holding only a French `CLAUDE.md`. Prompt: "Mets en place un dossier pour ce
  client." Turn 1: exactly one grouped question (counterparts + role + contacts, language),
  French proposed as default from the conversation and the repository, nothing written,
  adoption scan reported empty.
- Turn 2 (answer: Acme Conseil, client; Marie Dupont, directrice produit, contact; French):
  20 files created, `dossier.yaml` with the ten keys in order, `confidential_names` derived
  with short forms (`Acme`, `Dupont`), `.gitkeep` in the seven leaf folders, `AGENTS.md`
  created, marker section appended to the existing `CLAUDE.md`. French headings, English
  paths and `Last updated:` label. Working tree left uncommitted.
- Turn 3 (re-run): reports nothing missing, no file created or modified, settings reused
  without asking again. Working tree unchanged (6 status entries before and after).

### 2. Adoption rename — confirm PASS, decline PASS

Two fresh copies of `tests/fixtures/make-adopt-fixture.sh` output.

- Both turn 1s printed the proposal matching `tests/golden/adopt-proposal.txt` (13 renames in
  order, `docs/veille` reported untracked, `pipeline/` and the two `sources/` subfolders
  ignored), asked one explicit confirmation plus a separate question for the untracked
  folder, and wrote nothing (`git status`: only the pre-existing untracked `docs/veille/`).
- Copy A, confirm: the 13 `git mv` ran top to bottom (all staged as renames, contents
  identical), `docs/veille` moved with plain `mv` after separate consent, then the missing
  pieces were completed (`dossier.yaml`, `sources/README.md`, seven `.gitkeep`, `AGENTS.md`,
  `CLAUDE.md` section); the 11 pre-existing files were kept byte-for-byte (`placeholder`).
  Commit count unchanged (1).
- Copy B, decline: nothing renamed, moved or created; tree identical to the fixture.

### Observations (non-blocking)

- Copy B's session described `docs/veille/` as a nested git repository with its own `.git/`.
  It is not (it holds a single `README.md`); the behaviour was still correct. Worth a
  clarifying sentence on the `untracked:` line in SKILL.md step 4 when the skill is next
  touched.
- With identical `placeholder` contents, `git status` pairs some renames arbitrarily
  (cosmetic, a fixture artefact); the session noticed and explained it.
- `allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/init.py *)` was not exercised as a
  permission gate: runs used `--dangerously-skip-permissions`. The interpolation question
  (open point 2 of the mission report) stays open.
