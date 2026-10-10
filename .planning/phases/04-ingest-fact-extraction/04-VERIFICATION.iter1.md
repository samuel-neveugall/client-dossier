---
phase: 04-ingest-fact-extraction
verified: 2026-10-10T00:00:00Z
status: human_needed
score: 4/5 must-haves verified
covered_files:
  - .planning/phases/04-ingest-fact-extraction/04-01-PLAN.md
  - .planning/phases/04-ingest-fact-extraction/04-01-SUMMARY.md
  - .planning/phases/04-ingest-fact-extraction/04-02-PLAN.md
  - .planning/phases/04-ingest-fact-extraction/04-02-SUMMARY.md
  - .planning/phases/04-ingest-fact-extraction/04-03-PLAN.md
  - .planning/phases/04-ingest-fact-extraction/04-03-SUMMARY.md
  - .planning/phases/04-ingest-fact-extraction/04-04-PLAN.md
  - .planning/phases/04-ingest-fact-extraction/04-04-SUMMARY.md
  - .planning/phases/04-ingest-fact-extraction/04-05-PLAN.md
  - .planning/phases/04-ingest-fact-extraction/04-05-SUMMARY.md
  - agents/fact-extractor.md
  - skills/dossier-ingest/SKILL.md
  - skills/dossier-ingest/scripts/extract-text.sh
  - skills/dossier-ingest/scripts/file_source.py
  - tests/scenarios/ingest-pdf.sh
  - tests/scenarios/ingest-transcript.sh
  - tests/scenarios/selftest-ingest.sh
covered_digest: "v3:sha256:a4feaa353517e6d55a070fe92e562b24a83d74221dc3b357aa756d49088e4a85"
behavior_unverified: 1
overrides_applied: 0
behavior_unverified_items:
  - truth: "dossier-ingest dispatches the fact-extractor agent and applies its proposal (ROADMAP criterion 1, INGEST-02)"
    test: "In a real interactive Claude Code session with the plugin loaded (claude --plugin-dir .), ingest a multi-page source and watch whether the Agent tool is called with subagent_type client-dossier:fact-extractor"
    expected: "The agent is dispatched, returns the exact three-list markup (Read / Proposal / Contradicts / Uncertain), and the skill applies only lines citing the given source label; or Samuel confirms the inline path is acceptable when the agent is available"
    why_human: "In all 4 paid GREEN runs (3 transcript, 1 PDF) the Task/Agent tool and client-dossier:fact-extractor were registered in system/init, yet extractor_dispatched = no every time; the main agent extracted inline. Presence of the agent file and the skill instruction is verified, the dispatch itself has zero behavioural evidence, and a paid run is out of scope for this verification."
---

# Phase 4: Ingest & Fact Extraction Verification Report

**Phase Goal:** Any source that arrives gets filed exactly once, immutably, and its facts land in the right living files with a checkable citation.
**Verified:** 2026-10-10
**Status:** human_needed
**Re-verification:** No, initial verification

## Goal Achievement

Filing exactly once and immutably is proven by running the code. Facts landing in the right living files with checkable citations is proven by the recorded paid runs (their diffs, read independently). One path is not proven: the `fact-extractor` subagent has never been dispatched in any recorded live run.

### Observable Truths (ROADMAP success criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `dossier-ingest` on a PDF files it as `YYYY-MM-DD_slug`, extracts via `extract-text.sh`, reports the fact-extractor's proposal applied to the right living files with `Last updated:` refreshed | PRESENT_BEHAVIOR_UNVERIFIED (dispatch part only) | Filing, extraction and apply VERIFIED: `evidence/pdf-plugin/pdf-1.diff` shows `sources/received/2026-10-06_onboarding-pack.pdf` + `.txt` (3 page markers), `p. N` lines in ACTORS/HISTORY/LEARNINGS, `### Priya Raman (Acme Consulting)` heading, `Last updated: 2026-10-10, after the onboarding pack of 2026-10-06`, lint 0/0; I re-ran the same filing and `extract-text.sh` lines myself (below). NOT verified: the fact-extractor was not dispatched (`extractor_dispatched` = no), the main agent did the extraction inline. See Human Verification. |
| 2 | Re-ingesting the same file (same hash) is reported as already filed, not duplicated | VERIFIED | Own run: filing `pack.pdf` twice with a different slug and date returned `{"status": "already_filed", "path": "sources/received/2026-03-02_price-list.pdf"}`, exit 0, one file in the folder. Also `tests/test-ingest-file.sh` and `tests/test-ingest-guard.sh` green in the suite; SKILL.md "File it" reads `status` and says to file nothing again. |
| 3 | A contradicting fact yields a corrected line annotated "(corrects a line dated <date>)", no second contradictory line | VERIFIED | `evidence/green-plugin/plugin-1.diff`: the seeded line `... set the phase one budget at 15,000 euros (mail 2026-10-01 ...)` is replaced in place by `... confirmed the phase one budget at 18,000 euros on 2026-10-10 (call 2026-10-10 @00:19) (corrects a line dated 2026-10-01).` `corrected = yes` in 3/3 rows of `green-plugin/summary.tsv`. Rule 9 and the SKILL.md "Apply the proposal / Correct" section carry the contract. |
| 4 | "Given a transcript, what did we learn" moves RED to GREEN | VERIFIED | `red-baseline/summary.tsv`: 3/3 RED (`filed_name` none, 0 timestamped lines, `refreshed` none, `ingest_skill` no). `green-plugin/summary.tsv`: 3/3 GREEN, same plain prompt, filed `sources/transcripts/2026-10-10_kickoff-call.txt`, 7/8/9 `@mm:ss` lines, `refreshed` yes, lint 0/0, `ingest_skill` yes. Git order is right: RED commit `1654c56` precedes the skill commit `2318b59`. The skill text has not changed since the GREEN round (`git diff 57ec04c HEAD -- skills agents` empty). I scanned the 4 GREEN streams for tool_result denials: none. |
| 5 | With `pdftotext` absent the PDF is still filed, extraction reported skipped with an install hint; the skill text holds the inline extraction procedure for a harness without subagents | VERIFIED | Own run with PATH hiding `pdftotext`: PDF stays in `sources/received/`, `extract-text.sh` exits 69 with `Install poppler: macOS 'brew install poppler'; Debian/Ubuntu ...`, nothing written. SKILL.md: exit-69 branch ("say extraction skipped and relay the poppler install hint"), "No subagent here: I am doing the fact-extractor's job myself" plus the full `extraction-rules` block, and a "Without the scripts" section. |

**Score:** 4/5 truths verified (1 present and wired, dispatch behaviour unexercised)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `skills/dossier-ingest/SKILL.md` | 260-line task skill | VERIFIED | Real procedure, not a stub; no `allowed-tools` (deliberate, 29765f9); `test -x` checks before both scripts; the `dossier` skill points to it (`skills/dossier/SKILL.md:146`) |
| `skills/dossier-ingest/scripts/file_source.py` | filing, sha256 dedup, no overwrite, containment, URL fetch with SSRF guards | VERIFIED | Read in full; O_EXCL (`xb`) writes, stateless dedup, 100 MiB cap, per-hop redirect check; behaviour confirmed by my runs and 153/0 guard test |
| `skills/dossier-ingest/scripts/extract-text.sh` | `.txt` next to the PDF, page markers, exit codes 0/64/65/69/1 | VERIFIED | Read in full; noclobber write; ran extracted/exists/69 myself |
| `agents/fact-extractor.md` | read-only (Read, Grep, Glob), fixed output markup | VERIFIED | `tools: Read, Grep, Glob`; rules block is byte-identical to the SKILL.md block (diff clean) |
| `tests/scenarios/ingest-transcript.sh`, `ingest-pdf.sh`, `selftest-ingest.sh`, `lib-scenario.sh` | pressure harness + PDF end-to-end | VERIFIED | selftest PASS 165 FAIL 0; paid scripts not run (as instructed) |
| `evidence/{red-baseline,green-plugin,pdf-plugin}` | recorded paid runs | VERIFIED | summary.tsv rows read; diffs and final messages read; counts 3 RED / 3 GREEN / 1 GREEN |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `dossier` skill | `dossier-ingest` | pointer sentence (D-11) | WIRED | line 146 |
| SKILL.md | `file_source.py` / `extract-text.sh` | `${CLAUDE_SKILL_DIR}/scripts/...` | WIRED | commands run through the real sources guard in `tests/test-ingest-guard.sh` |
| SKILL.md | `fact-extractor` | Agent tool, `client-dossier:fact-extractor` | PARTIAL | named correctly and the agent is registered in the live init event; never called in a recorded run |
| SKILL.md / agent | `dossier/*.md` | Edit tool, rule block | WIRED | live diffs show the edits and the lint-clean result |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| living-file lines | fact lines with `@mm:ss` / `p. N` | filed source text | Yes: locators in the diffs correspond to the fixture transcript and the 3-page PDF | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full mechanical suite | `bash tests/run.sh` | `TOTAL: 17 files, 0 failed` | PASS |
| Harness self-test | `bash tests/scenarios/selftest-ingest.sh` | `PASS 165 FAIL 0` | PASS |
| Plugin manifest | `claude plugin validate .` | passed (1 known CLAUDE.md warning) | PASS |
| Dedup by hash | `file_source.py` twice on the same bytes | `already_filed` | PASS |
| Name collision | same name, different bytes | `name_taken`, exit 1, original untouched | PASS |
| Extraction | `extract-text.sh` on a 2-page PDF | `--- page N ---` markers; second call prints `exists:` | PASS |
| Tool missing | PATH without `pdftotext` | exit 69 + poppler hint, PDF still filed | PASS |
| Lint on the scratch dossier | `python3 scripts/lint.py` | 0 errors, 0 warnings | PASS |

### Probe Execution

No `probe-*.sh` is declared by the phase. SKIPPED.

### Requirements Coverage

| Requirement | Description (short) | Status | Evidence |
|-------------|---------------------|--------|----------|
| INGEST-01 | file under `sources/` as `YYYY-MM-DD_slug`, `extract-text.sh`, raw exports next to transcripts, missing pdftotext hint | SATISFIED | filing script, `--kind raw` to `sources/transcripts/raw/`, exit 69 hint, PDF GREEN run |
| INGEST-02 | dispatch `fact-extractor`, apply proposal, correct contradictions, refresh `Last updated`, report | NEEDS HUMAN | apply, correct, refresh and report verified live; dispatch never observed |
| INGEST-03 | read-only agent, structured proposal, contradicts / uncertain lists, quote and number discipline | SATISFIED (static) | agent file, tools line, rules 1-11 and output markup present; its runtime behaviour is part of the unverified dispatch item |
| INGEST-04 | same hash reported as already filed | SATISFIED | own run + tests |
| INGEST-05 | RED baseline before the skill, GREEN after | SATISFIED | 3/3 RED then 3/3 GREEN, commit order checked |
| INGEST-06 | inline procedure, says when main agent does the job, checks `extract-text.sh` exists | SATISFIED | SKILL.md lines 83, 115-117, rules block, "Without the scripts" |

No orphaned requirements: REQUIREMENTS.md maps INGEST-01..06 to Phase 4 and all six appear in the plans.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| (phase files) | - | TBD / FIXME / XXX | none | the only `XXXXXX` hits are `mktemp` templates |

### Human Verification Required

#### 1. fact-extractor subagent dispatch

**Test:** In an interactive session with `claude --plugin-dir .`, hand `dossier-ingest` a PDF or transcript in a dossier and watch for an Agent call with `subagent_type` `client-dossier:fact-extractor`.
**Expected:** The agent returns the three-list markup; the skill applies only lines citing the given source label and reports the Contradicts and Uncertain lists. Or Samuel decides that inline extraction by choice is acceptable (D-12 made the dispatch non-gating, spec section 6 allows inline).
**Why human:** 0 of 4 recorded paid runs dispatched it although `Task` and the agent were available. The model ignored the "dispatch the fact-extractor agent" sentence and said it extracted itself. The skill only allows the inline route when dispatch is impossible; the observed behaviour is outside that wording. A paid run was not permitted here.

### Gaps Summary

No blocking gap: filing, dedup, immutability, extraction, correction, RED to GREEN and the missing-tool path are all proven by running code or by independently read evidence. The single open item is the subagent path, held at human_needed rather than failed because the outcome (facts filed with locators and corrections, lint clean) is achieved through the inline route the manager explicitly allowed (D-12). If Samuel wants INGEST-02 to mean "the agent really runs", the options are to reword the skill so inline is the stated exception (and re-run one paid scenario), or to amend the requirement.

Advisories (not gating):

- `ingest_skill` in `lib-scenario.sh` (`jsonl_skill_invoked`) counts a denied `Skill` call as yes. I checked the 4 GREEN streams for denials myself: none. A result check would harden the shared harness (a later phase touching it).
- `skills/dossier-init/SKILL.md` carries the same `allowed-tools` frontmatter that made the ingest skill unloadable in a headless session (04-05 round 1). Phase 2 artefact, untouched; worth a follow-up.
- `04-VALIDATION.md` keeps `status: draft` and one unticked box (full suite 103 s against the 90 s target); both are honest and left for `/gsd-validate-phase`.
- Evidence rests on a single model (`claude-sonnet-5-5`, Claude Code 2.1.296) and one fixture each, per the phase's own sampling plan.

---

_Verified: 2026-10-10_
_Verifier: Claude (gsd-verifier)_
