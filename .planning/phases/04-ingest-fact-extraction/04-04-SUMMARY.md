---
phase: 04-ingest-fact-extraction
plan: 04
subsystem: ingest
tags: [skill, agent, fact-extractor, guard, writing-skills]
requires:
  - phase: 04-ingest-fact-extraction
    provides: file_source.py (04-01), the RED baseline and rationalizations (04-02), extract-text.sh (04-03)
provides:
  - "agents/fact-extractor.md: read-only agent (tools Read, Grep, Glob), shared rules block, fixed Proposal / Contradicts / Uncertain markup"
  - "skills/dossier-ingest/SKILL.md: find, peek, file, extract, dispatch or inline, apply, lint, report, bare-skills route"
  - "one-sentence pointer to dossier-ingest in skills/dossier/SKILL.md (D-11)"
  - "tests/test-agent-fact-extractor.sh, tests/test-skill-ingest.sh, tests/test-ingest-guard.sh"
affects: [04-05]
key-files:
  created:
    - agents/fact-extractor.md
    - skills/dossier-ingest/SKILL.md
    - tests/test-agent-fact-extractor.sh
    - tests/test-skill-ingest.sh
    - tests/test-ingest-guard.sh
  modified:
    - skills/dossier/SKILL.md
key-decisions:
  - "The extractor's output opens with a `Read: <n> lines or pages of <source label>` line before `## Proposal`, so the 'say how many lines or pages you read' rule has a place in the fixed markup."
  - "The `test -x` check of file_source.py sits in the 'Find the dossier' section, before the first fetch or filing line, so the existence check always precedes the first run."
requirements-completed: [INGEST-01, INGEST-02, INGEST-03, INGEST-04, INGEST-06]
status: complete
commits: 3
plan_head_before: d0b9e4ea67d26caa53e95f1b28cf13540cc96615
plan_head_after: a47a481fdf7b332193420c2af4b33d443d7eea53
actuals:
  tokens: 21000
  tasks: 3
  commits: 3
duration: 45min
completed: 2026-10-10
---

# Phase 4 Plan 04: fact-extractor agent, dossier-ingest skill and the guard test Summary

**A read-only `fact-extractor` agent and the `dossier-ingest` skill share one byte-identical extraction-rules block, the `dossier` skill points to the new skill, and a test runs the skill's own bash lines through the real Phase 3 guard and the real scripts.**

## Commits

| Task | Commit | Message |
|------|--------|---------|
| 1 | `e03f8a3` | feat(04-04): add the read-only fact-extractor agent |
| 2 | `2318b59` | feat(04-04): add the dossier-ingest skill and its pointer in the dossier skill |
| 3 | `a47a481` | test(04-04): run the ingest skill's commands through the real sources guard |

Task 2 holds `skills/dossier-ingest/SKILL.md` and the `skills/dossier/SKILL.md` pointer in the same
commit (RESEARCH Pitfall 11). The commit descends from `1654c56`, the commit that added
`evidence/red-baseline/summary.tsv` (checked with `git merge-base --is-ancestor`).

## Test results

| Test | Before the artefact (RED) | After |
|---|---|---|
| `tests/test-agent-fact-extractor.sh` | PASS 9 FAIL 43 | PASS 52 FAIL 0 after task 1; PASS 57 FAIL 0 once the skill exists (parity assertions) |
| `tests/test-skill-ingest.sh` | PASS 14 FAIL 68 | PASS 82 FAIL 0 (one transient failure fixed on the way, see below) |
| `tests/test-skill-dossier.sh` | n/a | PASS 128 FAIL 0 |
| `tests/test-skill-shape.sh` | n/a | PASS 30 FAIL 0 |
| `tests/test-ingest-guard.sh` | not red (see below) | PASS 153 FAIL 0 |
| `bash tests/run.sh` | 16 files before task 3 | `TOTAL: 17 files, 0 failed` |
| `bash tests/scenarios/selftest-ingest.sh` | n/a | PASS 165 FAIL 0 |
| `bash tests/scenarios/selftest.sh` | n/a | PASS 71 FAIL 0 |
| `claude plugin validate .` | n/a | exit 0, the two known warnings (author, root CLAUDE.md) |

Task 3's test was green on its first run: the artefacts it exercises (skill, guard, both scripts) all
existed already, so there was no red state to record. To show the test is not vacuous, one placeholder
in SKILL.md was temporarily changed to `<mystery>`: the test failed with "every placeholder of the
skill is in the substitution map" (PASS 152 FAIL 1), and the file was restored.

## Sizes

- `skills/dossier-ingest/SKILL.md`: 259 lines (under the 500 gate), description 301 characters.
- `agents/fact-extractor.md`: 64 lines; frontmatter keys exactly name, description, tools, model.

## Bash lines the guard test read from SKILL.md (11)

```
test -x ${CLAUDE_SKILL_DIR}/scripts/file_source.py
${CLAUDE_SKILL_DIR}/scripts/file_source.py fetch "<url>"
${CLAUDE_SKILL_DIR}/scripts/file_source.py --kind <kind> --date <YYYY-MM-DD> --slug "<slug>" "<path>"
test -x ${CLAUDE_SKILL_DIR}/scripts/extract-text.sh
${CLAUDE_SKILL_DIR}/scripts/extract-text.sh "<filed pdf>"
grep -n '^#' dossier/*.md
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/lint.py
find sources -type f ! -name .gitkeep -exec shasum -a 256 {} +
shasum -a 256 "<path>"
cp -n "<path>" "sources/<folder>/<YYYY-MM-DD>_<slug><ext>"
[ ! -e "<txt>" ] && pdftotext -enc UTF-8 "<filed pdf>" - > "<txt>"
```

Each is silent through `hooks/guard-sources.py` in its literal form and in its absolute form. Denied
and still denied: `cp -n` and the pdftotext redirection onto the existing brochure `.txt`, `cp` over
the existing PDF, Write on a new `.txt`, Edit on the existing `.txt`. Guard blind, script refuses:
the extraction line on a PDF whose `.txt` exists prints `exists:`, and a filing line naming the
existing brochure `.txt` gives `name_taken`; both leave the existing file byte-identical. Real runs:
`filed`, then `already_filed` with the same path; `extracted:` with the page marker; `fetch` of a
loopback URL gives `not_public`; with pdftotext hidden from PATH the new PDF is filed and the
extraction line exits 69 with the poppler hint, the PDF unchanged and no `.txt` written.

## Deviations from Plan

### Auto-fixed

**1. [Rule 1 - Bug] Existence check after the first run.** `tests/test-skill-ingest.sh` caught that
the first draft of SKILL.md ran `file_source.py fetch` (line 41) before the `test -x` line (line 57).
Moved the `test -x ${CLAUDE_SKILL_DIR}/scripts/file_source.py` block into "Find the dossier" and made
"File it" refer to it. Commit: `2318b59` (never committed in the wrong order).

**2. Parity assertions already in task 1's test.** The plan adds the byte-parity assertion to
`tests/test-agent-fact-extractor.sh` in task 2. The assertion was written in task 1, guarded by
`[ -f skills/dossier-ingest/SKILL.md ]`, so it is skipped silently until the skill exists and then
runs. Same result, one fewer edit; the test file is in the task 1 commit.

**3. Added a `Read:` line to the extractor's markup.** The rules ask the extractor to say how many
lines or pages it read; the plan's fixed markup had no slot for that. The markup now opens with
`Read: <n> lines or pages of <source label>`. The skill treats it as report material, not a line to apply.

### Environment notes (no rule fired)

- The worktree was created from a stale base (`e0b59cf`); `git merge --ff-only
  feat/phase-04-ingest-fact-extraction` succeeded as authorised, and both scripts were present
  afterwards. The phase branch itself was not touched.
- The sandbox refuses compound git commands and loops over git-adjacent commands; commits used single
  `/usr/bin/git` calls with `-F <message file>`. The per-plan commit ledger file was not written
  (same as plans 04-01 and 04-02); `plan_head_before` is the phase branch tip `d0b9e4e`.
- `.planning/WINDOWS.md` was not touched. `STATE.md`, `ROADMAP.md`, `hooks/` and
  `.planning/phases/05-*` were not touched, and no paid `claude -p` run was made (Phase 4 spend stays 0.097 USD).

## Behavioural proof still owed

None of these tests proves that a model follows the skill. That is plan 04-05's GREEN run
(`ingest-transcript.sh --variant plugin --prompt plain`), which also checks the `dossier-ingest`
Skill call (D-12). The skill answers the 04-02 baseline rationalizations by name in its last section
("a summary in chat is enough", the unnoticed contradiction).

## Known Stubs

None.

## Threat Flags

None beyond the plan's register. T-04-25/26 (agent tools and frontmatter tested), T-04-27 (rules
parity tested), T-04-28 (skill lines run through the guard), T-04-29 (Write/Edit denials re-asserted),
T-04-30 (fixture tokens absent from skill and agent, with a drift guard), T-04-31 (manual-download
sentence tested) each have a passing check.

## Self-Check: PASSED

- FOUND: agents/fact-extractor.md, skills/dossier-ingest/SKILL.md, tests/test-agent-fact-extractor.sh, tests/test-skill-ingest.sh, tests/test-ingest-guard.sh
- FOUND commits: e03f8a3, 2318b59, a47a481
